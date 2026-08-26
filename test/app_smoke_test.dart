import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/performance_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';

/// file_pickerは実機のプラットフォーム実装（PlatformInterfaceの
/// singletonインスタンス）を必要とするプラグインで、flutter test環境には
/// 何も登録されていない。未登録のまま`FilePicker.platform`へアクセスすると
/// LateInitializationErrorになり、しかもそれはボタンのonPressedのような
/// fire-and-forgetな非同期コールバック内で投げられるためtester側の
/// 例外捕捉（takeException）を経由せずテスト全体を落としてしまう
/// （path_providerと同じ「テスト環境側の制約」だが、こちらは
/// 捕捉不能なので事前にモックしておく必要がある）。「ファイルが
/// 選択されなかった（キャンセル）」と同じnullを返すことで、実際の
/// ファイル選択ダイアログを介さずに以降の分岐（何もしない）を検証できる。
class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      null;
}

/// アプリを実際に起動し、主要画面を人手を介さず自動で巡回して、
/// 例外が発生しないことを確認するスモークテスト群。
/// `main()`と同じ`buildAppProviders()`でサービス一式を初期化するため、
/// 起動時の配線ミス・providerの取り違え・画面遷移時の実行時エラーを
/// 見た目のチェックなしで検知できる。
///
/// `testWidgets`のテスト本体は既定でFlutterの仮想時計（fake clock）が
/// 支配するゾーンで動く。`buildAppProviders()`内部で使われる本物の
/// Timer/Future.delayed（プラグイン呼び出しの内部実装等）は、
/// `tester.pump()`で仮想時計を明示的に進めるまで発火しないため、
/// pumpWidget前にawaitすると永久にハングする。これを避けるため、
/// `tester.runAsync()`で本物の非同期ゾーンへ逃がしてから実行する。
///
/// 各ステップの後に`tester.takeException()`でFlutter側が捕捉した
/// 例外（レンダリングオーバーフロー・null参照・providerが見つからない
/// 等）が無いことを確認する。UIの見た目の良し悪しではなく、
/// 「クラッシュせずに動くか」を検証するためのテスト。
/// `pumpAndSettle()`は無限に繰り返すアニメーション・タイマーがあると
/// タイムアウトするため使わず、固定時間の`pump()`を都度呼ぶ。
///
/// テストケースごとにアプリを起動し直す（1テスト1起動）ことで、
/// 前のケースの状態が次のケースへ漏れないようにしている。
///
/// 各画面へ到達した後は`probeAllControls`（下記）により、その画面上に
/// 見えている操作可能な要素（ボタン・アイコンボタン・リストタイル・
/// チェックボックス・スイッチ・チップ・カード等のInkWell/GestureDetector）
/// を実際に自動で1つずつ操作し、その都度例外が起きないことまで確認する。
/// 単に画面が描画できるかだけでなく、そこにある操作を実際に一通り試す
/// ところまでを自動化することで、この仕組み自体が本セッション中に実際の
/// 不具合（ダイアログを閉じた直後にTextEditingControllerを破棄する処理が
/// 閉じるアニメーション中の再ビルドと競合してクラッシュする不具合、複数
/// 画面に存在）を発見・修正するきっかけになった。ただし、画面に見えている
/// 操作を1段階分自動で試す仕組みであり、起こりうる操作の組み合わせを
/// すべて網羅する状態空間探索ではない点に留意（詳細は`probeAllControls`の
/// ドキュメントコメントを参照）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // appRouterはモジュールレベルのシングルトンのため、前のテストケースで
    // 遷移した先のルートが残ったままになる。各テストを必ず起動画面から
    // 始められるよう、テストごとに明示的にリセットする。
    appRouter.go('/');
    FilePicker.platform = _FakeFilePicker();
  });

  /// path_providerのメソッドチャンネルをモックし、実際のファイル
  /// システム上の一時ディレクトリを返すようにする。テスト実行環境には
  /// path_providerの実装が登録されておらず未モック状態では
  /// MissingPluginExceptionになるため、保存データ変更画面・作品一覧タブ
  /// のように実際にディスクへ書き込む処理を経由しないと到達できない
  /// 画面のテストでのみ使う（他のテストへ影響しないよう、テスト終了時に
  /// 必ずモックを解除する）。
  void mockPathProvider(WidgetTester tester) {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('niarim_smoke_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
  }

  /// テスト用の描画領域を、既定の800x600（デスクトップブラウザ相当の
  /// 横長サイズ）からスマートフォン相当の縦長サイズへ広げる。既定サイズ
  /// のままだと、画面下部から出るボトムシートの内容が描画領域の外に
  /// はみ出し、tap()がヒットテストに失敗することがあるため。
  void setPhoneViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// アプリを起動し、起動画面の「作品をつくる」ボタンでホーム画面へ
  /// 遷移した上で、初回起動時の案内ダイアログが出ていれば閉じる。
  /// 以降の各テストケースの共通の出発点。
  Future<void> bootToHome(WidgetTester tester) async {
    setPhoneViewSize(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '起動画面の描画で例外');

    final createButtonFinder = find.byIcon(Icons.brush_outlined);
    expect(createButtonFinder, findsOneWidget);
    await tester.tap(createButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ホーム画面への遷移で例外');
    expect(find.byType(Scaffold), findsWidgets);

    final firstLaunchDialogButton = find.text('はじめる');
    if (firstLaunchDialogButton.evaluate().isNotEmpty) {
      await tester.tap(firstLaunchDialogButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '初回起動ダイアログを閉じる際に例外');
    }
  }

  // ─── 画面内の操作可能な要素を自動で一通り試す汎用プローブ ──────────────
  //
  // 「画面が例外なく描画できるか」だけでなく、「その画面に見えている
  // 操作可能な要素（ボタン・アイコンボタン・リストタイル・チェックボックス・
  // スイッチ・チップ等）を実際に1回ずつ操作しても例外・レンダリング
  // エラーが起きないか」まで自動で確認するためのヘルパー群。
  //
  // 完全な状態空間の網羅（発生しうる全ての操作の組み合わせを試す）を
  // 保証するものではない点に注意：あくまで「今その瞬間に画面上へ見えて
  // いる操作可能要素」を、見つかった順に1段階だけ自動操作する（操作した
  // 結果ダイアログ等が開けば、それも対象に含めて続けて操作する）。
  // スクロールしないと出てこない要素や、テキスト入力・ドラッグ操作を
  // 要するもの（TextField・Slider等）は対象外。

  /// 要素の部分木から最初に見つかったTextウィジェットの文字列を返す
  /// （ボタン・リストタイル等の「見た目のラベル」を汎用的に拾うため）。
  String? firstDescendantText(Element root) {
    String? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w is Text && (w.data?.isNotEmpty ?? false)) {
        found = w.data;
        return;
      }
      e.visitChildren(visit);
    }
    root.visitChildren(visit);
    return found;
  }

  /// テキストラベルが無いアイコンのみのボタン（IconButton等）向けに、
  /// 最初に見つかったIconウィジェットのコードポイントをラベル代わりに使う。
  String? firstDescendantIconLabel(Element root) {
    String? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w is Icon && w.icon != null) {
        found = 'icon${w.icon!.codePoint}';
        return;
      }
      e.visitChildren(visit);
    }
    root.visitChildren(visit);
    return found;
  }

  bool isDisabledControl(Widget w) {
    if (w is ElevatedButton) return w.onPressed == null;
    if (w is OutlinedButton) return w.onPressed == null;
    if (w is TextButton) return w.onPressed == null;
    if (w is IconButton) return w.onPressed == null;
    if (w is FloatingActionButton) return w.onPressed == null;
    if (w is ListTile) return w.onTap == null;
    if (w is CheckboxListTile) return w.onChanged == null;
    if (w is SwitchListTile) return w.onChanged == null;
    if (w is RadioListTile) return w.onChanged == null;
    if (w is ActionChip) return w.onPressed == null;
    if (w is FilterChip) return w.onSelected == null;
    if (w is ChoiceChip) return w.onSelected == null;
    if (w is InputChip) return w.onPressed == null && w.onSelected == null;
    if (w is Checkbox) return w.onChanged == null;
    if (w is Switch) return w.onChanged == null;
    if (w is InkWell) return w.onTap == null;
    if (w is GestureDetector) return w.onTap == null;
    return false;
  }

  const tapCandidateTypes = <Type>{
    ElevatedButton,
    OutlinedButton,
    TextButton,
    IconButton,
    FloatingActionButton,
    ListTile,
    CheckboxListTile,
    SwitchListTile,
    RadioListTile,
    ActionChip,
    FilterChip,
    ChoiceChip,
    InputChip,
    Checkbox,
    Switch,
    // カード等、独自にInkWell/GestureDetectorでタップ領域を作っている
    // 箇所（プロジェクトカード等）も対象に含める。上記の標準ボタン類は
    // いずれも内部実装にInkWellを持つため、判定時に「候補型の祖先を
    // 持つ要素は除外する」ことで、同じ見た目の操作を二重にタップして
    // しまわないようにしている。
    InkWell,
    GestureDetector,
  };

  // メニュー・ドロップダウンは開いた後に選択肢を選ぶ追加操作が必要で
  // 汎用プローブの単純な「タップ→戻る」だけでは扱えないため対象外とする。
  // 課金・退会・完全削除等の破壊的/プラットフォーム依存操作は、通常時は
  // onPressed:nullで無効化されている設計（例：ストア未接続時の購入ボタン）
  // だが、常時有効なもの（完全削除の確認ボタン等）もラベルで明示的に除外し、
  // テストデータの意図しない破棄や未モックのプラットフォームチャンネル
  // 呼び出しによる誤検知を避ける。
  const defaultSkipLabelSubstrings = <String>{
    '完全削除',
    '完全に削除',
    'ゴミ箱を空',
    '購入',
    'ログアウト',
    '退会',
  };

  /// file_picker等、実機のプラットフォーム実装（PlatformInterfaceの
  /// singletonインスタンス登録）を必要とするプラグインは、flutter test
  /// 環境には登録されていない。呼び出すとMissingPluginExceptionか
  /// （PlatformInterfaceパッケージ経由の実装では）「_instance...has not
  /// been initialized」というLateInitializationErrorになる。いずれも
  /// アプリの不具合ではなくテスト環境側の制約のため区別する。
  bool isPlatformUnavailableInTestEnv(Object? exception) {
    if (exception == null) return false;
    if (exception is MissingPluginException) return true;
    if (exception is Error) {
      final s = exception.toString();
      if (s.contains('LateInitializationError') && s.contains('_instance')) {
        return true;
      }
    }
    return false;
  }

  /// 画面上（ツリー全体）から、まだ試していない操作可能な要素を1つ探して
  /// タップし、例外が起きないことを確認する処理を、新しい要素が見つから
  /// なくなるかmaxStepsに達するまで繰り返す。
  ///
  /// タップの結果ダイアログ・ボトムシート・新しい画面が開いた場合は、
  /// Scaffold数の増加・Dialog/BottomSheetウィジェットの出現を目印に
  /// 自動でNavigator.pop()して元の状態へ戻してから次の要素を試す
  /// （最大5回までしか戻らないため、想定外に深く遷移した場合はそこで
  /// 打ち切り、以降のプローブはスキップする＝以降の巡回テストの安定性を
  /// 優先する）。
  Future<void> probeAllControls(
    WidgetTester tester, {
    int maxSteps = 20,
    Set<String> extraSkipLabelSubstrings = const {},
  }) async {
    final skipLabels = {...defaultSkipLabelSubstrings, ...extraSkipLabelSubstrings};
    final tried = <String>{};

    // 現在アクティブな（ModalRoute.isCurrentがtrueの）ルートを取得する。
    // ダイアログ・ボトムシートを開いた直後はそれ自身のルートが返る。
    Route<dynamic>? currentRoute() {
      for (final e in tester.allElements) {
        if (e.widget is Scaffold || e.widget is Dialog || e.widget is BottomSheet) {
          final r = ModalRoute.of(e);
          if (r != null && r.isCurrent) return r;
        }
      }
      return null;
    }

    final baseRoute = currentRoute();
    // ダイアログ等が開いて別ルートへ移った状態かどうかを、Scaffold数の
    // 増減という間接的な指標ではなく「元居たルートが今もisCurrentか」で
    // 直接判定する。前者はダイアログの閉じるアニメーションが完全に収まる
    // 前に判定すると、閉じかけのダイアログをまだ「開いている」と誤認して
    // 余分にpop()してしまい、画面自体まで戻しすぎることがあった。
    bool isElevated() => baseRoute != null && currentRoute() != baseRoute;

    // 候補型の祖先を持つ要素（＝標準ボタン内部のInkWell等）を除外する。
    bool hasCandidateAncestor(Element e) {
      var found = false;
      e.visitAncestorElements((ancestor) {
        if (tapCandidateTypes.contains(ancestor.widget.runtimeType)) {
          found = true;
          return false;
        }
        return true;
      });
      return found;
    }

    // まだ試していない候補を、今アクティブなルート上から1件探す
    // （見つからなければnull）。呼び出し側でスクロール後に再度呼び、
    // スクロールしないと見えない要素も拾えるようにする。
    ({Element element, String label})? scanForCandidate() {
      var index = 0;
      for (final e in tester.allElements) {
        final w = e.widget;
        if (!tapCandidateTypes.contains(w.runtimeType)) continue;
        if (isDisabledControl(w)) continue;
        if (hasCandidateAncestor(e)) continue;
        // GoRouterのpush等で前の画面がツリーに残ったままになっている場合、
        // find.byElementPredicateはその隠れた要素も見つけてしまう。
        // ModalRoute.isCurrentで「今アクティブな画面に属する要素か」を
        // 確認し、そうでなければ対象外にする（隠れた前画面を誤って
        // 操作しないようにするため）。
        final route = ModalRoute.of(e);
        if (route == null || !route.isCurrent) continue;

        final label = firstDescendantText(e) ?? firstDescendantIconLabel(e) ?? '';
        final skip = skipLabels.any((s) => s.isNotEmpty && label.contains(s));
        final id = '${w.runtimeType}:${label.isNotEmpty ? label : '#$index'}';
        index++;
        if (!skip && tried.add(id)) {
          return (element: e, label: label.isNotEmpty ? label : w.runtimeType.toString());
        }
      }
      return null;
    }

    // 今アクティブなルート上にあるScrollableを下方向へドラッグする。
    // 実際にスクロール位置が動いたかどうかを返す（既に最下部などで
    // 動かなければfalse）。複数のScrollableがある場合、最初に見つかった
    // ものだけを対象にする単純な実装（ネストしたリストの内側だけが動く
    // ケースはあるが、それでも隠れた要素を見つけられる分には有用）。
    Future<bool> tryScrollDown() async {
      for (final e in tester.allElements) {
        if (e.widget is! Scrollable) continue;
        final route = ModalRoute.of(e);
        if (route == null || !route.isCurrent) continue;
        final finder = find.byElementPredicate((el) => el == e);
        ScrollableState state;
        try {
          state = tester.state<ScrollableState>(finder);
        } catch (_) {
          continue;
        }
        final before = state.position.pixels;
        if (before >= state.position.maxScrollExtent) continue;
        try {
          await tester.drag(finder, const Offset(0, -300), warnIfMissed: false);
        } catch (_) {
          continue;
        }
        await tester.pump(const Duration(milliseconds: 200));
        return state.position.pixels != before;
      }
      return false;
    }

    for (var step = 0; step < maxSteps; step++) {
      var candidate = scanForCandidate();
      if (candidate == null) {
        // 見えている範囲に新しい候補が無ければ、スクロールして隠れている
        // 要素が無いか確認する（最大8回。無限スクロールコンテンツ等での
        // 無限ループを避けるため上限を設ける）。
        for (var scrollAttempt = 0; scrollAttempt < 8; scrollAttempt++) {
          final moved = await tryScrollDown();
          if (!moved) break;
          candidate = scanForCandidate();
          if (candidate != null) break;
        }
      }
      if (candidate == null) break;
      final targetElement = candidate.element;
      final targetLabel = candidate.label;

      final finder = find.byElementPredicate((el) => el == targetElement);
      try {
        await tester.tap(finder, warnIfMissed: false);
      } catch (_) {
        // 別要素の裏に隠れている等でヒットテストに失敗した場合は、
        // 「操作不可能だった」として次の候補へ進む（クラッシュ扱いしない）。
        continue;
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final exception = tester.takeException();
      if (isPlatformUnavailableInTestEnv(exception)) {
        // file_picker等、実機のプラットフォーム実装が必要なプラグインは
        // flutter test環境には登録されておらず、呼び出すと
        // LateInitializationError/MissingPluginExceptionになる
        // （path_providerと同種の、テスト環境側の制約でありアプリの
        // 不具合ではない）。アプリ側の不具合を隠さないよう、既知の
        // シグネチャに一致する場合のみ許容し、それ以外は通常どおり
        // テスト失敗として扱う。
        continue;
      }
      expect(exception, isNull, reason: '"$targetLabel" を操作した際に例外: $exception');

      if (isElevated()) {
        var guard = 0;
        while (isElevated() && guard < 5) {
          NavigatorState navigator;
          try {
            navigator = Navigator.of(tester.element(find.byType(Scaffold).first));
          } catch (_) {
            break;
          }
          if (!navigator.canPop()) break;
          navigator.pop();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 200));
          tester.takeException(); // 戻る操作自体の例外はここでは対象外
          guard++;
        }
        if (isElevated()) {
          // 想定した範囲では元の状態へ戻せなかった。それ以上の操作は
          // 予期しない画面遷移を積み重ねるだけになるため打ち切る。
          break;
        }
      }
    }
  }

  /// 指定したルートへ順番に遷移して戻ってくることを繰り返し、途中で
  /// 例外が発生しないかを確認する。プロジェクトIDを必要としない設定・
  /// ヘルプ系の画面など、UIタップより直接遷移の方が経路が安定する
  /// 画面のために使う共通処理（新規プロジェクト作成テストで既に
  /// 使っている「経路の妥当性よりも画面自体の描画確認を優先する」方針を
  /// 複数画面へ拡張したもの）。到達した画面ではprobeAllControlsで
  /// 見えている操作可能要素も一通り試す。
  Future<void> visitRoutesAndPop(
    WidgetTester tester,
    List<String> routes, {
    Duration settleDelay = const Duration(milliseconds: 300),
  }) async {
    for (final route in routes) {
      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).push(route);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(settleDelay);
      expect(tester.takeException(), isNull, reason: '$route への遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);

      await probeAllControls(tester);

      // probeAllControls内の自動リカバリで想定外に遷移してしまっている
      // 可能性があるため、routerContextを使い回さず、その時点で実際に
      // 画面上にあるScaffoldから改めてGoRouterを取得して戻る。想定外の
      // 画面（スタック丸ごと置き換え等）に着地して戻れない場合でも、
      // これ自体はprobeAllControls側で既に例外なしを確認済みのため、
      // 以降のルート巡回を継続できるよう例外を握りつぶす。
      if (find.byType(Scaffold).evaluate().isNotEmpty) {
        try {
          final popContext = tester.element(find.byType(Scaffold).first);
          GoRouter.of(popContext).pop();
          await tester.pump(const Duration(milliseconds: 300));
        } catch (_) {
          // 戻れない状態になっていた場合は、次のルートは改めてホームから
          // 遷移し直す形になる（GoRouter.pushは現在地に関わらず機能する）。
        }
      }
      expect(tester.takeException(), isNull, reason: '$route から戻る際に例外');
    }
  }

  testWidgets('起動→ホーム→設定→ショートカット設定まで例外なく遷移できる', (WidgetTester tester) async {
    await bootToHome(tester);

    // ドロワーを開いて設定画面へ遷移する。
    final scaffoldState = tester.state<ScaffoldState>(
      find.byType(Scaffold).first,
    );
    scaffoldState.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ドロワー表示で例外');

    final settingsTileFinder = find.byIcon(Icons.settings_outlined);
    expect(settingsTileFinder, findsOneWidget);
    await tester.tap(settingsTileFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '設定画面への遷移で例外');

    // 設定一覧画面自体（各設定項目への入口一覧）も一通り操作してみる。
    await probeAllControls(tester);

    // 設定一覧から、ショートカット設定画面まで開いてみる。
    final shortcutEntryFinder = find.byIcon(Icons.keyboard);
    if (shortcutEntryFinder.evaluate().isNotEmpty) {
      // 直前のprobeAllControlsが設定一覧を一通り操作した後のため、Hero
      // アニメーション等の影響で厳密なヒットテスト判定が不安定になりうる。
      await tester.tap(shortcutEntryFinder.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'ショートカット設定画面への遷移で例外');
      await probeAllControls(tester);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
    '起動→ホーム→新規プロジェクト作成→キャンバス→タイムラインまで例外なく遷移できる',
    (WidgetTester tester) async {
      await bootToHome(tester);

      // 「＋」FAB→「新規プロジェクト」のボトムシート操作は、テスト環境の
      // 描画領域サイズに応じてヒットテストが不安定になりやすいため、
      // 実際に到達する先のルートへ直接遷移する（遷移経路自体の妥当性より、
      // 各画面が例外なく描画できるかの確認を優先する）。
      final routerContext1 = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext1).push('/new-project');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規プロジェクト画面への遷移で例外');

      // 既定値のまま「作成」を押すとキャンバスモードへ遷移する。
      final createFinder = find.text('作成');
      expect(createFinder, findsOneWidget);
      await tester.tap(createFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'キャンバスモードへの遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);

      // 作成されたプロジェクトのIDでタイムラインモードへ直接遷移する
      // （フレーム帯の切り替えUIはジェスチャーが複雑なため、経路の妥当性
      // より画面自体が例外なく描画できるかの確認を優先する）。
      final projectId = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>()
          .projects
          .first
          .id;
      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).go('/timeline/$projectId');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'タイムラインモードへの遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    '起動→新規プロジェクト作成→キャンバス→タイムラインの各種パネルを'
    '例外なく操作できる',
    (WidgetTester tester) async {
      // キャンバス・タイムライン画面本体は、実際の描画入力（onPointerDown等の
      // 生のPointerイベント）を独自Listenerで受けているため、probeAllControls
      // の対象型（ボタン・ListTile・onTapを持つGestureDetector等）には
      // そもそも一致せず、誤って「描画」してしまう心配は無い。ドラッグ専用の
      // ハンドル（定規操作・メッシュ変形・パネル区切り線等）もonTapを
      // 持たないためisDisabledControlで除外される。ただし念のため、この
      // シナリオは既存の主要遷移テストとは独立させ、万一不安定になっても
      // 他のテストへ影響しないようにしている。
      await bootToHome(tester);

      final routerContext1 = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext1).push('/new-project');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規プロジェクト画面への遷移で例外');

      final createFinder = find.text('作成');
      expect(createFinder, findsOneWidget);
      await tester.tap(createFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'キャンバスモードへの遷移で例外');

      await probeAllControls(tester, maxSteps: 40);

      final projectId = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>()
          .projects
          .first
          .id;
      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).go('/timeline/$projectId');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'タイムラインモードへの遷移で例外');

      await probeAllControls(tester, maxSteps: 40);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  testWidgets(
    '起動→新規プロジェクト作成→タイムライン再生：ループOFFなら最終フレームで自動停止する',
    (WidgetTester tester) async {
      await bootToHome(tester);

      final routerContext1 = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext1).push('/new-project');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final createFinder = find.text('作成');
      expect(createFinder, findsOneWidget);
      await tester.tap(createFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'キャンバスモードへの遷移で例外');

      final ps = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>();
      final projectId = ps.projects.first.id;

      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).go('/timeline/$projectId');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'タイムラインモードへの遷移で例外');

      // 新規プロジェクトは既定で百数十フレームあるため、まず最終フレーム
      // 付近まで一気に移動しておく（最初から全フレーム分再生し続けると
      // テストが長時間化する）。「最終フレームへ」→「1つ前へ戻る」で
      // 最終フレームの手前（total-2）に位置させ、そこから再生することで
      // 「途中から最終フレームに到達して自動停止する」経路を検証する。
      final skipToEndButton = find.byIcon(Icons.skip_next);
      expect(skipToEndButton, findsOneWidget);
      await tester.tap(skipToEndButton);
      await tester.pump();
      final stepBackButton = find.byIcon(Icons.fast_rewind);
      expect(stepBackButton, findsOneWidget);
      await tester.tap(stepBackButton);
      await tester.pump();

      // ループトグルをOFFにする（既定はON）。
      final loopButton = find.byIcon(Icons.repeat);
      expect(loopButton, findsOneWidget, reason: 'ループトグルボタンが見つからない');
      await tester.tap(loopButton);
      await tester.pump();

      // 再生開始。
      final playButton = find.byIcon(Icons.play_arrow);
      expect(playButton, findsOneWidget);
      await tester.tap(playButton);
      await tester.pump();
      expect(
        find.byIcon(Icons.pause),
        findsOneWidget,
        reason: '再生中はpauseアイコンに切り替わるはず',
      );

      // 最終フレームに到達するまで十分な時間を進める（開始位置は
      // 最終フレームの1つ手前なので、既定fps=12でも300msあれば
      // 「最終フレームへ進む」「最終フレームで停止判定」の2回分の
      // Timer.periodicが確実に発火する）。
      await tester.pump(const Duration(milliseconds: 300));

      // ループOFFのため、最終フレームで自動停止してplay_arrowアイコンへ
      // 戻っているはず（ループONなら先頭へ戻ってpauseのまま再生継続する）。
      expect(
        find.byIcon(Icons.play_arrow),
        findsOneWidget,
        reason: 'ループOFFなら最終フレームで自動停止するはず',
      );
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets('起動画面→コミュニティ画面まで例外なく遷移できる', (WidgetTester tester) async {
    setPhoneViewSize(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: '起動画面の描画で例外');

    final communityButtonFinder = find.byIcon(Icons.movie_filter_outlined);
    expect(communityButtonFinder, findsOneWidget);
    await tester.tap(communityButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'コミュニティ画面への遷移で例外');
    await probeAllControls(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
    'コミュニティ画面：作品タイトル・投稿者名のいずれでも検索絞り込みできる',
    (WidgetTester tester) async {
      setPhoneViewSize(tester);
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final communityButtonFinder = find.byIcon(Icons.movie_filter_outlined);
      expect(communityButtonFinder, findsOneWidget);
      await tester.tap(communityButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'コミュニティ画面への遷移で例外');

      // 絞り込み前は複数件のカードが表示されている（ダミーデータは24件）。
      final cardCountBefore = find.byType(CommunityWorkCard).evaluate().length;

      // 検索を開いて、ダミーデータの投稿者名の一部（'sakura_draws'）で
      // 検索する。作品タイトルでは一致しない語のため、投稿者名検索が
      // 機能していることの確認になる。
      final searchIconFinder = find.byIcon(Icons.search);
      expect(searchIconFinder, findsOneWidget);
      await tester.tap(searchIconFinder);
      await tester.pump();

      final searchFieldFinder = find.byType(TextField);
      expect(searchFieldFinder, findsOneWidget);
      await tester.enterText(searchFieldFinder, 'sakura_draws');
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '投稿者名検索の絞り込みで例外');

      // 絞り込み後は全件表示より少なくなっているはず（該当作者の作品のみ）。
      final cardCountAfter = find.byType(CommunityWorkCard).evaluate().length;
      expect(cardCountAfter, lessThan(cardCountBefore));
      expect(cardCountAfter, greaterThan(0));

      // 存在しない語で検索すると「該当なし」の空状態表示になる
      // （クラッシュせず、CommunityWorkCard＝作品カードが0件になること）。
      await tester.enterText(searchFieldFinder, 'このキーワードには絶対一致しない__zzz');
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '該当なし検索の表示で例外');
      expect(find.byIcon(Icons.search_off), findsOneWidget);

      // 検索を閉じると全件表示に戻る。
      final closeIconFinder = find.byIcon(Icons.close);
      expect(closeIconFinder, findsOneWidget);
      await tester.tap(closeIconFinder);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '検索クローズで例外');
      final cardCountRestored = find.byType(CommunityWorkCard).evaluate().length;
      expect(cardCountRestored, cardCountBefore);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets('起動→ホーム→ドロワー→有料会員画面まで例外なく遷移できる', (WidgetTester tester) async {
    await bootToHome(tester);

    final scaffoldState = tester.state<ScaffoldState>(
      find.byType(Scaffold).first,
    );
    scaffoldState.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ドロワー表示で例外');

    final premiumTileFinder = find.byIcon(Icons.workspace_premium_outlined);
    expect(premiumTileFinder, findsOneWidget);
    await tester.tap(premiumTileFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '有料会員画面への遷移で例外');
    await probeAllControls(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
    '起動→ホーム→各種設定画面（ショートカット以外）を例外なく巡回できる',
    (WidgetTester tester) async {
      await bootToHome(tester);
      await visitRoutesAndPop(tester, const [
        '/settings/gestures',
        '/settings/performance',
        '/settings/pen',
        '/settings/bucket',
        '/settings/workspace',
        '/settings/transfer',
        '/settings/theme',
        '/settings/watermark',
        '/settings/fonts',
        '/settings/license',
        '/settings/privacy-policy',
      ]);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  testWidgets('起動→ホーム→ヘルプ・ヒント画面を例外なく表示できる', (WidgetTester tester) async {
    await bootToHome(tester);
    await visitRoutesAndPop(
      tester,
      const ['/help', '/tips'],
      settleDelay: const Duration(milliseconds: 500),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→共有・ゴミ箱画面を例外なく表示できる', (WidgetTester tester) async {
    await bootToHome(tester);
    await visitRoutesAndPop(tester, const ['/shared', '/trash']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
    '起動→新規プロジェクト作成→詳細・素材管理・書き出し・自動塗りプリセット・'
    'セーブツリー画面を例外なく表示できる',
    (WidgetTester tester) async {
      await bootToHome(tester);

      final routerContext1 = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext1).push('/new-project');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規プロジェクト画面への遷移で例外');

      final createFinder = find.text('作成');
      expect(createFinder, findsOneWidget);
      await tester.tap(createFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'キャンバスモードへの遷移で例外');

      final projectId = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>()
          .projects
          .first
          .id;

      await visitRoutesAndPop(
        tester,
        [
          '/project/$projectId',
          '/materials/$projectId',
          '/export/$projectId',
          '/autofill-presets',
          '/save-tree/$projectId',
        ],
        settleDelay: const Duration(milliseconds: 500),
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  // ここから先は、独立したルートを持たずNavigator.push（MaterialPageRoute）
  // で開く画面（対象UIのタップ操作が別途必要な画面）を巡回する。

  testWidgets(
    '起動→自動塗りプリセット作成→詳細画面（別ルート）を例外なく表示できる',
    (WidgetTester tester) async {
      await bootToHome(tester);

      // ホーム画面にも同じ+アイコンのFABがあるため、pushではなくgoで
      // スタックごと置き換えて、FAB検索が2件ヒットしないようにする。
      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).go('/autofill-presets');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // FABはScaffoldのデフォルトHeroアニメーションの対象になるため、
      // 遷移アニメーションが完全に収まってからタップする必要がある。
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '自動塗りプリセット画面への遷移で例外');

      // FAB→「新規作成」を選び、プリセットを1件作成する。ホーム画面にも
      // 同じ+アイコンのFABが（画面遷移アニメーション中などに）同時に
      // 存在し得るため、AutofillPresetScreen配下のFABに絞って探す。
      final fabFinder = find.descendant(
        of: find.byType(AutofillPresetScreen),
        matching: find.byType(FloatingActionButton),
      );
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規作成/読み込み選択シート表示で例外');

      final newPresetOptionFinder = find.text('新規作成');
      expect(newPresetOptionFinder, findsWidgets);
      await tester.tap(newPresetOptionFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規作成ダイアログ表示で例外');

      const presetName = 'スモークテスト用';
      await tester.enterText(find.byType(TextField), presetName);
      await tester.pump(const Duration(milliseconds: 100));
      final createPresetFinder = find.text('作成');
      expect(createPresetFinder, findsWidgets);
      await tester.tap(createPresetFinder.last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'プリセット作成で例外');

      // 一覧に追加されたカードをタップして詳細画面（MaterialPageRoute）を開く。
      final presetCardFinder = find.text(presetName);
      expect(presetCardFinder, findsWidgets);
      await tester.tap(presetCardFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'プリセット詳細画面への遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);
      await probeAllControls(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    '起動→ホーム→設定→ワークスペース設定→PCレイアウト詳細設定画面'
    '（別ルート）を例外なく表示できる',
    (WidgetTester tester) async {
      await bootToHome(tester);

      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).push('/settings/workspace');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'ワークスペース設定画面への遷移で例外');

      final pcLayoutButtonFinder = find.byIcon(
        Icons.dashboard_customize_outlined,
      );
      expect(pcLayoutButtonFinder, findsOneWidget);
      await tester.tap(pcLayoutButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'PCレイアウト詳細設定画面への遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);
      await probeAllControls(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    '起動画面→コミュニティ画面→作品詳細→投稿者別作品一覧画面'
    '（別ルート）を例外なく表示できる',
    (WidgetTester tester) async {
      setPhoneViewSize(tester);
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: '起動画面の描画で例外');

      final communityButtonFinder = find.byIcon(Icons.movie_filter_outlined);
      expect(communityButtonFinder, findsOneWidget);
      await tester.tap(communityButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'コミュニティ画面への遷移で例外');

      // 作品カードをタップして詳細ボトムシートを開く。
      final workCardFinder = find.byType(CommunityWorkCard);
      expect(workCardFinder, findsWidgets);
      await tester.tap(workCardFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '作品詳細シート表示で例外');

      // シート内の投稿者アイコン（CircleAvatar、一覧カード側には無い）を
      // タップして投稿者別作品一覧画面（MaterialPageRoute）を開く。
      final authorAvatarFinder = find.byType(CircleAvatar);
      expect(authorAvatarFinder, findsWidgets);
      await tester.tap(authorAvatarFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '投稿者別作品一覧画面への遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);
      await probeAllControls(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    '起動→ホーム→新規プロジェクト画面→キャンバスサイズプリセット管理画面'
    '（別ルート）を例外なく表示できる',
    (WidgetTester tester) async {
      await bootToHome(tester);

      final routerContext = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext).push('/new-project');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規プロジェクト画面への遷移で例外');

      final presetManageButtonFinder = find.byIcon(Icons.tune);
      expect(presetManageButtonFinder, findsOneWidget);
      await tester.tap(presetManageButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'キャンバスサイズプリセット管理画面への遷移で例外',
      );
      expect(find.byType(Scaffold), findsWidgets);
      await probeAllControls(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    '起動→ホーム→作品一覧タブ→フォルダ作成→フォルダ内画面（別ルート）を'
    '例外なく表示できる',
    (WidgetTester tester) async {
      mockPathProvider(tester);
      await bootToHome(tester);

      // フォルダ一覧の表示条件（書き出し済みファイルが1件以上ある）を
      // 満たすため、exportsフォルダへダミーファイルを1件書き込む。実際の
      // 動画データではないため、一覧に表示される際のプレビュー生成は
      // 失敗するが、その失敗はVideoPlayerControllerのcatchErrorで
      // 捕捉される想定（アプリ側の設計）。
      final exportsDir = await tester.runAsync(ExportEngine.exportsDir);
      await tester.runAsync(
        () => File(
          '${exportsDir!.path}/smoke_test_dummy.mp4',
        ).writeAsBytes(const [0]),
      );
      // ExportEngine.listExportedFilesは結果を静的にキャッシュしており、
      // 起動画面のプリフェッチ（他のテストケースも含め、アプリを起動する
      // たびに走る）で既に空リストがキャッシュされている。作品一覧タブは
      // forceRefresh:falseで読むため、ここで明示的に強制更新しておかないと
      // 上で書き込んだダミーファイルが反映されない。
      await tester.runAsync(
        () => ExportEngine.listExportedFiles(forceRefresh: true),
      );

      final worksTabFinder = find.text('作品一覧');
      expect(worksTabFinder, findsWidgets);
      await tester.tap(worksTabFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // 書き出し済みファイル一覧の非同期読み込み待ち。
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '作品一覧タブへの切り替えで例外');

      final fabFinder = find.byIcon(Icons.create_new_folder_outlined);
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'フォルダ作成ダイアログ表示で例外');

      const folderName = 'スモークテスト用フォルダ';
      await tester.enterText(find.byType(TextField), folderName);
      await tester.pump(const Duration(milliseconds: 100));
      final createFolderFinder = find.text('作成');
      expect(createFolderFinder, findsWidgets);
      await tester.tap(createFolderFinder.last);
      await tester.pump(const Duration(milliseconds: 300));
      // ダイアログの閉じるアニメーションが終わるまで待つ（入力欄の
      // EditableTextがまだ残っていると、find.text()が同じ文字列を持つ
      // 入力欄自体にもマッチしてしまい、意図しない場所をタップしうる）。
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'フォルダ作成で例外');

      final folderTileFinder = find.text(folderName);
      expect(folderTileFinder, findsWidgets);
      await tester.tap(folderTileFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'フォルダ内画面への遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);
      await probeAllControls(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    '起動→保存データ超過状態→保存方式変更（別ルート）を例外なく表示できる',
    (WidgetTester tester) async {
      mockPathProvider(tester);
      await bootToHome(tester);

      final routerContext1 = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext1).push('/new-project');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '新規プロジェクト画面への遷移で例外');

      final createFinder = find.text('作成');
      expect(createFinder, findsOneWidget);
      await tester.tap(createFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'キャンバスモードへの遷移で例外');

      // 保存データ変更画面（スロット選択）は、ツリー方式（無制限）で保存件数を
      // 増やしたあと、より少ないスロット数の方式へ切り替えた場合にのみ
      // 表示される。切り替え自体はUI操作（品質プリセット→低品質）で行うが、
      // 事前の保存件数の積み上げはサービスを直接呼んで用意する（実際の
      // 保存ボタン連打をUI操作で再現するのは手間が大きいため）。
      final element = tester.element(find.byType(Scaffold).first);
      final performance = element.read<PerformanceService>();
      final saveService = element.read<SaveTreeService>();
      final projectService = element.read<ProjectService>();
      final project = projectService.projects.first;
      final scenes = projectService.scenesOf(project.id);
      final tileManager = projectService.tileManagerOf(project.id);

      performance.setQualityLevel(QualityLevel.high); // ツリー方式（無制限）
      saveService.setTreeMode(true);
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => saveService.saveAsChild(
            projectId: project.id,
            project: project,
            scenes: scenes,
            tileManager: tileManager,
          ),
        );
      }
      expect(tester.takeException(), isNull, reason: '保存データの積み上げで例外');

      // 設定→パフォーマンス設定画面で品質プリセットを「低」（スロット5件）へ
      // 切り替える。保存済み6件 > 5件のため、保存データ変更画面が開く。
      // routerContext1は新規プロジェクト作成でウィジェットツリーが
      // 差し替わり無効化されているため、ここで改めて取得し直す。
      final routerContext2 = tester.element(find.byType(Scaffold).first);
      GoRouter.of(routerContext2).push('/settings/performance');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'パフォーマンス設定画面への遷移で例外');

      final lowQualityFinder = find.text('低品質');
      expect(lowQualityFinder, findsWidgets);
      await tester.tap(lowQualityFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '保存データ変更画面への遷移で例外');
      expect(find.byType(Scaffold), findsWidgets);
      await probeAllControls(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
