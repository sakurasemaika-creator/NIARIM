import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/undo_manager.dart' as engine;
import 'package:niarim/router.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/material_asset.dart' as material_asset;
import 'package:niarim/services/material_service.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/performance_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/settings_service.dart';

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
///
/// 【Task#128調査メモ】素材追加ボタン（file_picker経由）のonPressedは
/// MaterialService.addMaterialの実ファイルI/O（readAsBytes/writeAsBytes）
/// を伴うが、tester.tap()経由でトリガーされたウィジェットのonPressed内で
/// 開始された本物のdart:io I/Oは、tester.runAsync()でtap自体を包んでも
/// テスト関数の実行中には完了しない（本物のI/O完了がテスト関数return
/// "後"にしか届かない）ことを実際に確認した。そのためタイムラインの
/// クリップ移動・トリムハンドルのテストでは、file_picker経由のUI操作
/// 自体は検証対象に含めず、ProjectService/MaterialServiceへテスト
/// コードから直接（tester.runAsync経由で）クリップ相当のレイヤーを
/// 登録する方式にした（テストコードから直接awaitする通常の非同期
/// 呼び出しは、上記の制約とは無関係に問題なく完了する）。
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
  }) async => null;
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
    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsWidgets,
      reason: '起動画面の最上部に横長広告モックが必要',
    );

    final createButtonFinder = find.byIcon(Icons.brush_outlined);
    expect(createButtonFinder, findsOneWidget);
    await tester.tap(createButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ホーム画面への遷移で例外');
    expect(find.byType(Scaffold), findsWidgets);
    expect(
      find.byKey(const Key('persistent-horizontal-ad-mock')),
      findsWidgets,
      reason: 'ホーム画面の最上部に横長広告モックが必要',
    );

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
    // RadioListTile.onChangedはRadioGroupへの移行で非推奨になったが、
    // ここは「そのコントロールが無効化されているか」を読み取るだけで、
    // 読み取り用の代替APIは用意されていない。
    // ignore: deprecated_member_use
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
    final skipLabels = {
      ...defaultSkipLabelSubstrings,
      ...extraSkipLabelSubstrings,
    };
    final tried = <String>{};

    // 現在アクティブな（ModalRoute.isCurrentがtrueの）ルートを取得する。
    // ダイアログ・ボトムシートを開いた直後はそれ自身のルートが返る。
    Route<dynamic>? currentRoute() {
      for (final e in tester.allElements) {
        if (e.widget is Scaffold ||
            e.widget is Dialog ||
            e.widget is BottomSheet) {
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

        final label =
            firstDescendantText(e) ?? firstDescendantIconLabel(e) ?? '';
        final skip = skipLabels.any((s) => s.isNotEmpty && label.contains(s));
        final id = '${w.runtimeType}:${label.isNotEmpty ? label : '#$index'}';
        index++;
        if (!skip && tried.add(id)) {
          return (
            element: e,
            label: label.isNotEmpty ? label : w.runtimeType.toString(),
          );
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
            navigator = Navigator.of(
              tester.element(find.byType(Scaffold).first),
            );
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
      expect(
        find.byKey(const Key('persistent-horizontal-ad-mock')),
        findsWidgets,
        reason: '$route の最上部に横長広告モックが必要',
      );

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

  testWidgets('作品をつくるホームでAndroid標準の戻る操作をすると起動画面へ戻る', (
    WidgetTester tester,
  ) async {
    await bootToHome(tester);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
    expect(find.byIcon(Icons.movie_filter_outlined), findsOneWidget);
    expect(find.text('投稿作品をみる'), findsOneWidget);
    expect(find.textContaining('みんなの作品'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→新規プロジェクト作成→キャンバス→タイムラインまで例外なく遷移できる', (
    WidgetTester tester,
  ) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス→タイムラインの各種パネルを'
      '例外なく操作できる', (WidgetTester tester) async {
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
  }, timeout: const Timeout(Duration(seconds: 120)));

  // Task#128：キャンバス・タイムラインの独自ジェスチャーを自律テスト化。
  // probeAllControlsは標準的なタップ系ウィジェット（ボタン・ListTile等）
  // しか操作できないため、生のポインターイベント（Listener）やonPanUpdate/
  // onHorizontalDragUpdate等で自前実装された「独自ジェスチャー」は対象外
  // （app_smoke_test.dart冒頭のドキュメントコメント参照）。ここではその
  // うち代表的なもの（ペンストローク描画・2本指ピンチズーム・タイムライン
  // のカメラキーフレームのドラッグ移動）を実際にドラッグ操作で駆動し、
  // 例外が出ないことに加え、操作の結果として実際に状態が変化したこと
  // （Undo履歴に積まれる／変形行列が変わる／キーフレームのフレーム位置が
  // 動く）まで検証する。バケツ塗り・投げ縄塗り・定規ハンドル・メッシュ
  // 変形ハンドル等の残りの独自ジェスチャーは今後の継続拡張課題とする。
  testWidgets('起動→新規プロジェクト作成→キャンバス：ペン・ぼかし・2本指ピンチ'
      'ズームが独自ジェスチャーとして機能する（Task#128）', (WidgetTester tester) async {
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

    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);

    // ① ペンストローク：既定ツール（ペン）のまま、キャンバス上を
    // ドラッグして実際にストロークを描く。onPointerDown/Move/Upという
    // 生のポインターイベントで実装されている（canvas_area.dartの
    // Listener）。
    var undoManager = tester.element(canvasFinder).read<engine.UndoManager>();
    expect(undoManager.canUndo, isFalse, reason: '描画前はUndoできる操作が無いはず');
    final canvasCenter = tester.getCenter(canvasFinder);
    await tester.dragFrom(
      canvasCenter - const Offset(60, 60),
      const Offset(120, 120),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'ペンストロークの描画で例外');
    undoManager = tester.element(canvasFinder).read<engine.UndoManager>();
    expect(undoManager.canUndo, isTrue, reason: 'ストロークがUndo履歴に積まれるはず');

    // ② ガウスぼかし：指ツールを長押ししてサブツールを選択し、先ほど
    // 描いた線をなぞる。PointerUpで操作が確定し、ペンとは別のUndo履歴が
    // 1件積まれることまで確認する（終了処理の配線漏れに対する回帰テスト）。
    final fingerTool = find.byTooltip('指');
    expect(fingerTool, findsOneWidget);
    tester
        .widget<ToolbarWidget>(find.byType(ToolbarWidget))
        .onFingerLongPress();
    await tester.pumpAndSettle();
    final blurItem = find.text('ガウスぼかし');
    expect(blurItem, findsOneWidget);
    await tester.tap(blurItem);
    await tester.pumpAndSettle();
    final undoCountBeforeBlur = undoManager.undoCount;
    await tester.dragFrom(
      canvasCenter - const Offset(50, 50),
      const Offset(100, 100),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'ガウスぼかし操作で例外');
    expect(
      undoManager.undoCount,
      undoCountBeforeBlur + 1,
      reason: 'ぼかし操作がPointerUpで確定し、独立したUndo履歴に積まれるはず',
    );

    // ③ 2本指ピンチズーム：Flutter標準のInteractiveViewerを使わず、
    // 2本指のonPointerDown/Move/Upから独自に拡大率・回転・平行移動を
    // 計算して_transformControllerへ反映している（canvas_area.dartの
    // _applyMultiTouchTransform）。CustomPaintを包むTransformウィジェット
    // の変形行列が実際に変化することを確認する。
    final transformFinder = find
        .descendant(of: canvasFinder, matching: find.byType(Transform))
        .first;
    final beforeStorage = List<double>.from(
      tester.widget<Transform>(transformFinder).transform.storage,
    );
    final gesture1 = await tester.startGesture(
      canvasCenter - const Offset(40, 0),
      kind: PointerDeviceKind.touch,
    );
    final gesture2 = await tester.startGesture(
      canvasCenter + const Offset(40, 0),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture1.moveBy(const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture2.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture1.up();
    await gesture2.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '2本指ピンチズームで例外');
    final afterStorage = tester
        .widget<Transform>(transformFinder)
        .transform
        .storage;
    final matrixChanged = List.generate(
      beforeStorage.length,
      (i) => (beforeStorage[i] - afterStorage[i]).abs() > 1e-6,
    ).any((changed) => changed);
    expect(matrixChanged, isTrue, reason: '2本指ピンチズームでキャンバスの変形行列が変化するはず');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス：バケツ塗りが独自ジェスチャーとして'
      '機能する（Task#128）', (WidgetTester tester) async {
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

    // バケツツールへ切り替える（バケツ塗りはonPointerDown/Up内の
    // _handleBucketDown/_handleBucketUpという独自実装で、
    // _flattenVisibleLayers()等の非同期処理を挟むため、down直後に
    // すぐupを送るtester.tap()ではなく、間にpumpを挟んで非同期処理が
    // 進む猶予を与える必要がある）。
    // Icons.format_color_fillは他のUI（カラーピッカー等）にも使われて
    // 複数ヒットするため、ツールバーのバケツボタンにだけ設定されている
    // ツールチップ文言で一意に特定する。
    final bucketToolFinder = find.byTooltip('バケツ（長押しでベタ/トーン切替）');
    expect(bucketToolFinder, findsOneWidget);
    await tester.tap(bucketToolFinder);
    await tester.pump(const Duration(milliseconds: 100));

    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);
    final undoManagerBefore = tester
        .element(canvasFinder)
        .read<engine.UndoManager>();
    expect(undoManagerBefore.canUndo, isFalse, reason: '塗る前はUndoできる操作が無いはず');

    final bucketGesture = await tester.startGesture(
      tester.getCenter(canvasFinder),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await bucketGesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'バケツ塗りで例外');

    final undoManagerAfter = tester
        .element(canvasFinder)
        .read<engine.UndoManager>();
    expect(
      undoManagerAfter.canUndo,
      isTrue,
      reason: '新規キャンバス全体への塗りがUndo履歴に積まれるはず',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス：自由変形/メッシュ変形の格子点'
      'ドラッグが独自ジェスチャーとして機能する（Task#128）', (WidgetTester tester) async {
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

    // 「設定/編集」メニュー→「自由変形・メッシュ変形」で変形モードへ入る。
    final settingsMenuFinder = find.byTooltip('設定/編集');
    expect(settingsMenuFinder, findsOneWidget);
    await tester.tap(settingsMenuFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '設定/編集メニュー表示で例外');

    final meshMenuItemFinder = find.text('自由変形・メッシュ変形');
    expect(meshMenuItemFinder, findsOneWidget);
    // メニューは項目数が多くスクロール可能なため、画面外にある項目を
    // スクロールして表示させてからタップする。
    await tester.ensureVisible(meshMenuItemFinder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(meshMenuItemFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '自由変形・メッシュ変形パネル表示で例外');

    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);

    // 既定の分割数（density=1）は4隅のみの格子点（＝自由変形）になり、
    // 左上の格子点はキャンバスピクセル座標(0,0)と一致する
    // （MeshWarpEngine.regularGrid参照）。canvasDrawingRectFor
    // （canvas_area.dartが実際の座標変換にも使う計算元）でキャンバス
    // ウィジェット内の実際の描画矩形を求め、その左上を狙ってドラッグ
    // する（生のポインターイベント：_hitTestMeshPoint→
    // _meshPointerToIndexという、ペンストローク・ピンチズームと同じ
    // Listenerベースの独自ジェスチャー実装）。
    final project = tester
        .element(canvasFinder)
        .read<ProjectService>()
        .projects
        .first;
    final canvasWidgetRect = tester.getRect(canvasFinder);
    final drawingRect = canvasDrawingRectFor(canvasWidgetRect.size, project);
    final topLeftHandleScreenPos =
        canvasWidgetRect.topLeft + drawingRect.topLeft + const Offset(6, 6);

    final meshGesture = await tester.startGesture(topLeftHandleScreenPos);
    await tester.pump(const Duration(milliseconds: 50));
    await meshGesture.moveBy(const Offset(40, 40));
    await tester.pump(const Duration(milliseconds: 50));
    await meshGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '自由変形の格子点ドラッグで例外');

    // 変形モードを抜ける（キャンセルで確定はしない。ワープ確定
    // 処理自体はcompute()でのisolate実行を伴うため、ここでは
    // 「ドラッグ操作自体が例外なく機能するか」の検証に留める）。
    final cancelButtonFinder = find.text('キャンセル');
    expect(cancelButtonFinder, findsOneWidget);
    await tester.tap(cancelButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '自由変形のキャンセルで例外');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス：定規ツールの移動ハンドル'
      'ドラッグが独自ジェスチャーとして機能する（Task#128）', (WidgetTester tester) async {
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

    // ツールバーの「定規」ボタン→定規パネルの「直線定規」で
    // 定規ツールへ切り替え、アクティブな定規を新規作成する。
    final rulerToolFinder = find.byTooltip('定規');
    expect(rulerToolFinder, findsOneWidget);
    await tester.tap(rulerToolFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '定規パネル表示で例外');

    final lineRulerFinder = find.text('直線定規');
    expect(lineRulerFinder, findsOneWidget);
    await tester.tap(lineRulerFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '直線定規の新規作成で例外');

    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);

    // 直線定規の新規作成自体が1件のUndoActionとして登録される
    // （RulerPanelからの選択・削除はcanvas_screen.dartの
    // _setActiveRulerWithUndoが担当）。
    final undoManager = tester.element(canvasFinder).read<engine.UndoManager>();
    expect(undoManager.canUndo, isTrue, reason: '定規新規作成がUndo履歴に積まれるはず');

    // 直線定規の「move」ハンドルは定規のposition（既定でキャンバス
    // 中央）と一致する（_rulerHandlePositions参照）。キャンバス中央は
    // canvasDrawingRectFor（canvas_area.dartが実際の座標変換にも
    // 使う計算元）が返す描画矩形の中心と一致するため、そこから
    // ドラッグする（生のポインターイベント：_handleRulerDown→
    // _handleRulerMoveという、ペンストローク・自由変形と同じ
    // Listenerベースの独自ジェスチャー実装）。
    final project = tester
        .element(canvasFinder)
        .read<ProjectService>()
        .projects
        .first;
    final canvasWidgetRect = tester.getRect(canvasFinder);
    final drawingRect = canvasDrawingRectFor(canvasWidgetRect.size, project);
    final moveHandleScreenPos = canvasWidgetRect.topLeft + drawingRect.center;

    final rulerGesture = await tester.startGesture(moveHandleScreenPos);
    await tester.pump(const Duration(milliseconds: 50));
    await rulerGesture.moveBy(const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 50));
    await rulerGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '定規の移動ハンドルドラッグで例外');

    // ハンドルドラッグ確定時（_handleRulerUp）にもう1件UndoActionが
    // 積まれるはず。undo()を2回呼んで「ドラッグ操作の巻き戻し」
    // 「定規新規作成の巻き戻し」の両方が例外なく完了し、最終的に
    // Undo履歴が空になることを確認することで、ドラッグが実際に
    // 1件のUndoActionとして機能したことを検証する
    // （単なる例外の有無だけでなく、Undo履歴の件数という実際の
    // 効果を確認する）。
    expect(undoManager.canUndo, isTrue, reason: 'ハンドルドラッグがUndo履歴に積まれるはず');
    undoManager.undo();
    expect(tester.takeException(), isNull, reason: 'ドラッグの巻き戻しで例外');
    expect(undoManager.canUndo, isTrue, reason: '定規新規作成の分がまだ残っているはず');
    undoManager.undo();
    expect(tester.takeException(), isNull, reason: '定規新規作成の巻き戻しで例外');
    expect(undoManager.canUndo, isFalse, reason: 'ドラッグと新規作成の2件のみ積まれていたはず');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス：定規ツールの回転ハンドル'
      'ドラッグが独自ジェスチャーとして機能する（Task#128）', (WidgetTester tester) async {
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

    final rulerToolFinder = find.byTooltip('定規');
    expect(rulerToolFinder, findsOneWidget);
    await tester.tap(rulerToolFinder);
    await tester.pump(const Duration(milliseconds: 300));

    final lineRulerFinder = find.text('直線定規');
    expect(lineRulerFinder, findsOneWidget);
    await tester.tap(lineRulerFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '直線定規の新規作成で例外');

    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);
    final undoManager = tester.element(canvasFinder).read<engine.UndoManager>();
    expect(undoManager.canUndo, isTrue, reason: '定規新規作成がUndo履歴に積まれるはず');

    // 直線定規の「rotate」ハンドルは、既定の回転角0（rad）のとき
    // position（キャンバス中央）からX軸正方向へ220（キャンバス
    // ピクセル単位）進んだ点になる（_rulerHandlePositions参照：
    // position + Offset.fromDirection(rotation, 220)）。moveハンドル
    // のテストと同じくcanvasDrawingRectForで実際の描画矩形の
    // 拡大縮小率を求め、220をその比率でスクリーン座標へ変換する。
    final project = tester
        .element(canvasFinder)
        .read<ProjectService>()
        .projects
        .first;
    final canvasWidgetRect = tester.getRect(canvasFinder);
    final drawingRect = canvasDrawingRectFor(canvasWidgetRect.size, project);
    final exportW = project.exportWidth.toDouble();
    final fitScale = drawingRect.width / exportW;
    final rotateHandleScreenPos =
        canvasWidgetRect.topLeft +
        drawingRect.center +
        Offset(220 * fitScale, 0);

    final rulerGesture = await tester.startGesture(rotateHandleScreenPos);
    await tester.pump(const Duration(milliseconds: 50));
    // 下方向へドラッグして回転角を変える
    // （_rulerWithHandleAtのhandleId=='rotate'は
    // (canvasPos - r.position).directionをそのまま新しいrotationにする）。
    await rulerGesture.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 50));
    await rulerGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '定規の回転ハンドルドラッグで例外');

    expect(undoManager.canUndo, isTrue, reason: '回転ハンドルドラッグがUndo履歴に積まれるはず');
    undoManager.undo();
    expect(tester.takeException(), isNull, reason: '回転の巻き戻しで例外');
    undoManager.undo();
    expect(tester.takeException(), isNull, reason: '定規新規作成の巻き戻しで例外');
    expect(undoManager.canUndo, isFalse, reason: '回転と新規作成の2件のみ積まれていたはず');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス：定規ツール（楕円定規）の'
      'サイズ変更ハンドルドラッグが独自ジェスチャーとして機能する'
      '（Task#128）', (WidgetTester tester) async {
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

    final rulerToolFinder = find.byTooltip('定規');
    expect(rulerToolFinder, findsOneWidget);
    await tester.tap(rulerToolFinder);
    await tester.pump(const Duration(milliseconds: 300));

    final ellipseRulerFinder = find.text('楕円定規');
    expect(ellipseRulerFinder, findsOneWidget);
    await tester.tap(ellipseRulerFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '楕円定規の新規作成で例外');

    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);
    final undoManager = tester.element(canvasFinder).read<engine.UndoManager>();
    expect(undoManager.canUndo, isTrue, reason: '定規新規作成がUndo履歴に積まれるはず');

    // 楕円定規の「resizeX」ハンドルは、既定の回転角0（rad）のとき
    // position（キャンバス中央）からX軸正方向へradiusX（既定200×
    // キャンバス幅/1920のスケール）進んだ点になる
    // （_rulerHandlePositions参照：
    // position + _rotatePoint(Offset(rx, 0), rotation)）。
    final project = tester
        .element(canvasFinder)
        .read<ProjectService>()
        .projects
        .first;
    final canvasWidgetRect = tester.getRect(canvasFinder);
    final drawingRect = canvasDrawingRectFor(canvasWidgetRect.size, project);
    final exportW = project.exportWidth.toDouble();
    final fitScale = drawingRect.width / exportW;
    final radiusX = 200.0 * (exportW / 1920.0);
    final resizeXHandleScreenPos =
        canvasWidgetRect.topLeft +
        drawingRect.center +
        Offset(radiusX * fitScale, 0);

    final rulerGesture = await tester.startGesture(resizeXHandleScreenPos);
    await tester.pump(const Duration(milliseconds: 50));
    await rulerGesture.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await rulerGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '楕円定規のサイズ変更ハンドルドラッグで例外');

    expect(undoManager.canUndo, isTrue, reason: 'サイズ変更ハンドルドラッグがUndo履歴に積まれるはず');
    undoManager.undo();
    expect(tester.takeException(), isNull, reason: 'サイズ変更の巻き戻しで例外');
    undoManager.undo();
    expect(tester.takeException(), isNull, reason: '定規新規作成の巻き戻しで例外');
    expect(undoManager.canUndo, isFalse, reason: 'サイズ変更と新規作成の2件のみ積まれていたはず');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→キャンバス（PC/DeXモード）：ドッキング'
      'パネルのリサイズハンドルドラッグが独自ジェスチャーとして機能する'
      '（Task#128）', (WidgetTester tester) async {
    await bootToHome(tester);

    // isWideScreen()はワークスペース設定のforcePcMode（手動指定）を
    // 画面の向きより優先するため、実機のようにポインティングデバイスを
    // 検知させたり画面を横向きにしたりしなくても、これだけでPC/DeX
    // モードのドッキングパネルレイアウトを再現できる。ただし
    // bootToHome()が設定するスマホ縦長サイズ（1080×2280）の横幅の
    // ままだと、実機のPC/DeXモードでは通常あり得ない極端に狭い横幅で
    // 複数のドッキングパネル＋キャンバスを並べることになりRenderFlex
    // がわずかに収まらないため、横幅だけ実機のPC/DeXモードを想定した
    // 広さへ明示的に広げ直す（高さは新規プロジェクト作成フォームが
    // 縦スクロールなしで収まる元の高さのまま維持する）。
    tester.view.physicalSize = const Size(1920, 2280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump(const Duration(milliseconds: 100));

    final settingsContext = tester.element(find.byType(Scaffold).first);
    final settingsService = settingsContext.read<SettingsService>();
    await tester.runAsync(() => settingsService.setForcePcMode(true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'PCモード強制切替で例外');
    expect(settingsService.desktopToolPanelWidth, 280.0, reason: '既定幅の前提');

    final routerContext1 = tester.element(find.byType(Scaffold).first);
    GoRouter.of(routerContext1).push('/new-project');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final createFinder = find.text('作成');
    expect(createFinder, findsOneWidget);
    await tester.tap(createFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'キャンバスモード（PC/DeX）への遷移で例外');

    // 既定のドッキングパネル（ブラシ・カラーピッカー・レイヤー）が
    // 自動で開くため、_ResizeHandle（canvas_screen.dart内のprivateな
    // クラスで、ドッキング領域とキャンバスの境界に置かれる横方向
    // ドラッグ専用のGestureDetector。onHorizontalDragUpdateを持つ
    // ウィジェットはこの画面内に他に存在しない）が複数出現する。
    // 最初の1つ（ツールオプション系ドッキング領域＝ブラシパネルの
    // 右端）をドラッグする。
    final resizeHandleFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onHorizontalDragUpdate != null,
    );
    expect(
      resizeHandleFinder,
      findsWidgets,
      reason: 'PC/DeXモードのリサイズハンドルが見つからない',
    );

    final handleCenter = tester.getCenter(resizeHandleFinder.first);
    final resizeGesture = await tester.startGesture(handleCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await resizeGesture.moveBy(const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await resizeGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'リサイズハンドルドラッグで例外');

    // ドラッグ確定（onDragEnd）でSettingsServiceへ実際に永続化される
    // ため、既定値280.0から実際に変化したことまで検証する
    // （単なる例外の有無だけでなく実際の効果を確認する）。
    expect(
      settingsService.desktopToolPanelWidth,
      greaterThan(280.0),
      reason: 'リサイズハンドルドラッグでツールパネル幅が広がるはず',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→タイムライン：カメラキーフレームのドラッグ'
      '移動が独自ジェスチャーとして機能する（Task#128）', (WidgetTester tester) async {
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
    final sceneId = ps.scenesOf(projectId).first.id;

    final routerContext = tester.element(find.byType(Scaffold).first);
    GoRouter.of(routerContext).go('/timeline/$projectId');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'タイムラインモードへの遷移で例外');

    // 現在フレーム（新規プロジェクトの既定は先頭フレーム＝0）へ
    // カメラキーフレームを1件追加する。
    final addCameraKfButton = find.byIcon(Icons.camera);
    expect(addCameraKfButton, findsOneWidget);
    await tester.tap(addCameraKfButton);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'カメラキーフレーム追加で例外');
    expect(
      ps.cameraKeyframesOf(projectId, sceneId).map((k) => k.frameIndex),
      contains(0),
      reason: '追加したカメラキーフレームがフレーム0に存在するはず',
    );

    // 追加したキーフレームのマーカー（timeline_screen.dartでTask#128用に
    // ValueKeyを付与済み）を横方向にドラッグし、独自実装の
    // onHorizontalDragStart/Update/End（_beginCameraKfDrag等）で
    // フレーム位置が変わることを確認する。
    final markerFinder = find.byKey(const ValueKey('cameraKfMarker_0'));
    expect(markerFinder, findsOneWidget);
    await tester.drag(markerFinder, const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'カメラキーフレームのドラッグ移動で例外');

    final frames = ps
        .cameraKeyframesOf(projectId, sceneId)
        .map((k) => k.frameIndex)
        .toList();
    expect(frames, isNot(contains(0)), reason: 'ドラッグ後は元のフレーム0から移動しているはず');
    expect(
      frames.any((f) => f > 0),
      isTrue,
      reason: 'ドラッグした分だけ後ろのフレームへ移動しているはず',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→タイムライン：動画クリップの長押し'
      'ドラッグ移動・トリムハンドルが独自ジェスチャーとして機能する'
      '（Task#128）', (WidgetTester tester) async {
    // MaterialService.addMaterialが素材保存先を解決するのに
    // path_providerを使うため必要（mockPathProvider参照）。
    mockPathProvider(tester);
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
    final ms = tester
        .element(find.byType(Scaffold).first)
        .read<MaterialService>();
    final projectId = ps.projects.first.id;
    final sceneId = ps.scenesOf(projectId).first.id;

    // タイムライン画面を開く前に、動画クリップを1件、直接
    // ProjectService/MaterialServiceへ登録しておく。実際の「＋動画」
    // ボタンはFilePicker→MaterialService.addMaterialという実ファイル
    // I/O（readAsBytes/writeAsBytes）をボタンのonPressed内で行うが、
    // flutter_testの仮想時計（fake async zone）はTimer/Future.delayed
    // は制御できてもボタンのonPressed内で開始された本物のdart:io I/O
    // の完了までは（tester.runAsyncでtap自体を包んでも）テスト本体の
    // 実行中に driveできない、というテストハーネス側の制約に
    // 実際に突き当たった（本物のI/O完了はテスト関数がreturnした
    // "後"にしか届かなかった）。そのためこのテストでは「＋動画」
    // ボタンのUI操作自体は検証対象に含めず、その代わりに
    // 移動・トリムハンドルという独自ジェスチャー自体の検証に
    // 専念する（ProjectService/MaterialServiceへの直接呼び出しは
    // テストコードから直接awaitする通常の非同期呼び出しであり、
    // 上記の制約とは無関係にtester.runAsyncで問題なく完了する）。
    // _TimelineScreenState._loadClipsFromProjectはシーンの
    // LayerType.timelineVideo/timelineImageレイヤーから_videoClips
    // 等を再構築する仕組みのため、ここで登録したレイヤーは実際の
    // 「＋動画」ボタン経由の追加と同じ形でタイムライン画面に表示される。
    final dummyDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('niarim_test_video_'),
    );
    addTearDown(() => dummyDir!.delete(recursive: true));
    final dummyFile = File('${dummyDir!.path}/dummy_video.mp4');
    await tester.runAsync(() => dummyFile.writeAsBytes(const [0, 1, 2, 3]));

    final asset = await tester.runAsync(
      () => ms.addMaterial(
        projectId: projectId,
        sourcePath: dummyFile.path,
        type: material_asset.MaterialType.video,
      ),
    );
    final layer = ps.addLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.timelineVideo,
      name: 'テスト動画',
    );
    ps.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layer: layer.copyWith(
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: 1,
        rangeEnd: 12,
        materialId: asset!.id,
        sourceTrimStart: 0,
        sourceTrimEnd: 11,
      ),
    );

    final routerContext = tester.element(find.byType(Scaffold).first);
    GoRouter.of(routerContext).go('/timeline/$projectId');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'タイムラインモードへの遷移で例外');

    Layer videoLayerOf(ProjectService s) => s
        .layersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.type == LayerType.timelineVideo);
    final layerBeforeMove = videoLayerOf(ps);
    final rangeStartBeforeMove = layerBeforeMove.rangeStart;
    final rangeEndBeforeMove = layerBeforeMove.rangeEnd;

    // クリップ本体（長押しドラッグで移動するGestureDetector。
    // onLongPressStartを持つのはタイムライン画面内でこれだけ）を
    // 取得する。トリムハンドル（onHorizontalDragUpdate）もこの
    // GestureDetectorのchild Stack内の兄弟要素として存在するため、
    // 後段でdescendantとして絞り込める。
    final clipMoveFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onLongPressStart != null,
    );
    expect(clipMoveFinder, findsOneWidget, reason: '追加した動画クリップが見つからない');

    // ① 長押しドラッグで移動：kLongPressTimeout（500ms）以上ホールド
    // してから水平方向へ動かす。_beginClipDrag/_updateClipDrag/
    // _endClipDragという、キャンバスのペンストローク等と同じ
    // 生のジェスチャーコールバック実装。
    final clipCenter = tester.getCenter(clipMoveFinder);
    final moveGesture = await tester.startGesture(clipCenter);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await moveGesture.moveBy(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await moveGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '動画クリップの長押しドラッグ移動で例外');

    final layerAfterMove = videoLayerOf(ps);
    expect(
      layerAfterMove.rangeStart,
      isNot(rangeStartBeforeMove),
      reason: '長押しドラッグ移動でrangeStartが変わるはず',
    );

    // ② トリムハンドル（右端）を横方向へドラッグして長さを変える。
    // クリップが移動した分、GestureDetectorは再構築されているため
    // 改めて取得し直す。
    final clipMoveFinderAfterMove = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onLongPressStart != null,
    );
    expect(clipMoveFinderAfterMove, findsOneWidget);
    final resizeHandleFinders = find.descendant(
      of: clipMoveFinderAfterMove,
      matching: find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragUpdate != null,
      ),
    );
    expect(
      resizeHandleFinders,
      findsNWidgets(2),
      reason: '左右2つのトリムハンドルが見つからない',
    );

    final rightHandleCenter = tester.getCenter(resizeHandleFinders.last);
    final resizeGesture = await tester.startGesture(rightHandleCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await resizeGesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await resizeGesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '動画クリップのトリムハンドルドラッグで例外');

    final layerAfterResize = videoLayerOf(ps);
    expect(
      layerAfterResize.rangeStart,
      layerAfterMove.rangeStart,
      reason: '右端のトリムハンドルはrangeStartを変えないはず',
    );
    expect(
      layerAfterResize.rangeEnd,
      isNot(rangeEndBeforeMove),
      reason: '右端のトリムハンドルドラッグでrangeEndが変わるはず',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→タイムライン再生：ループOFFなら最終フレームで自動停止する', (
    WidgetTester tester,
  ) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));

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

  testWidgets('コミュニティ画面：作品タイトル・投稿者名のいずれでも検索絞り込みできる', (
    WidgetTester tester,
  ) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('コミュニティ画面：ショートモードでショート動画のみの全画面ビューアが開く（Task#159）', (
    WidgetTester tester,
  ) async {
    setPhoneViewSize(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final communityButtonFinder = find.byIcon(Icons.movie_filter_outlined);
    await tester.tap(communityButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 縦画面モードボタンは「縦画面のみ」フィルターを選択したときにのみ
    // 表示される仕様のため、先に動画種類フィルターを「縦画面のみ」へ
    // 切り替える。
    final videoTypeFilterFinder = find.byIcon(Icons.filter_alt_outlined);
    expect(videoTypeFilterFinder, findsOneWidget);
    await tester.tap(videoTypeFilterFinder);
    await tester.pumpAndSettle();
    // ラベルのTextを直接タップしないこと。CheckedPopupMenuItemは中身
    // （チェックアイコン＋ラベルのListTile）をIgnorePointerで包む実装
    // （FlutterのSDK側`_CheckedPopupMenuItemState.buildChild()`）のため、
    // Textはヒットテスト対象にならない。Textを狙うと「タップ座標が対象
    // ウィジェットに当たらない」という警告が出たうえで、たまたま背後の
    // メニュー項目に当たって動いているだけの状態になる（レイアウトが
    // 変わると黙って別の項目を押しかねない）。ヒットテスト可能な
    // CheckedPopupMenuItem自体を対象にする。
    final verticalOnlyItemFinder = find.ancestor(
      of: find.text('縦画面のみ'),
      matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
    );
    expect(verticalOnlyItemFinder, findsOneWidget);
    await tester.tap(verticalOnlyItemFinder);
    await tester.pumpAndSettle();

    // ダミーデータは約35%がショート動画になるよう生成しているため、
    // 24件中で1件も無いことは考えにくいが、念のためボタン自体は必ず
    // 存在することを先に確認する。
    final shortsButtonFinder = find.byIcon(Icons.view_carousel_outlined);
    expect(shortsButtonFinder, findsOneWidget);
    await tester.tap(shortsButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ショートモードを開く際に例外');

    // 全画面ビューア（CommunityShortsScreen）が開き、閉じるボタンが
    // 表示されていること。背後にはコミュニティ画面のTabBarView
    // （内部的に横方向PageViewを使う）がまだマウントされたままのため、
    // ショートモード側の縦方向PageViewのみを絞り込んで確認する。
    expect(find.byType(CommunityShortsScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is PageView && w.scrollDirection == Axis.vertical,
      ),
      findsOneWidget,
    );

    // 閉じるボタンでコミュニティ画面へ戻れる。
    final closeFinder = find.byIcon(Icons.close);
    expect(closeFinder, findsOneWidget);
    await tester.tap(closeFinder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'ショートモードを閉じる際に例外');
    expect(find.byType(CommunityShortsScreen), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('コミュニティ画面：タグの追加・タップでの絞り込み・削除ができる', (WidgetTester tester) async {
    setPhoneViewSize(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final communityButtonFinder = find.byIcon(Icons.movie_filter_outlined);
    await tester.tap(communityButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 最初の作品カードをタップするとフローティング動画プレビュー
    // ウィンドウが開く。「詳細へ」ボタンで作品詳細画面（別ルート）へ
    // 遷移する。
    final workCardFinder = find.byType(CommunityWorkCard);
    expect(workCardFinder, findsWidgets);
    await tester.tap(workCardFinder.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フローティングプレビュー表示で例外');
    final detailButtonFinder = find.text('詳細へ');
    expect(
      detailButtonFinder,
      findsOneWidget,
      reason: 'フローティングプレビューの「詳細へ」ボタンが見つからない',
    );
    await tester.tap(detailButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '作品詳細画面表示で例外');

    // 「タグを追加」→ダイアログでタグ名を入力→OK。
    const newTag = 'テスト用タグ__probe';
    final addTagChipFinder = find.text('タグを追加');
    expect(addTagChipFinder, findsOneWidget);
    await tester.tap(addTagChipFinder);
    await tester.pump(const Duration(milliseconds: 300));
    final tagInputFinder = find.byType(TextField).last;
    await tester.enterText(tagInputFinder, newTag);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'タグ追加で例外');
    expect(find.text(newTag), findsOneWidget, reason: '追加したタグがシートに表示されていない');

    // 追加したタグ（一意な文字列のため該当作品は1件のみのはず）をタップし、
    // タグ検索モードでの絞り込みへ遷移することを確認する。
    await tester.tap(find.text(newTag));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'タグタップでの絞り込みで例外');
    expect(
      find.byIcon(Icons.sell),
      findsOneWidget,
      reason: 'タグ検索モードに切り替わっていない',
    );
    expect(
      find.byType(CommunityWorkCard),
      findsOneWidget,
      reason: '一意なタグでの絞り込み件数が想定と異なる',
    );

    // 絞り込まれた唯一の作品カードを開き（フローティングプレビュー→
    // 「詳細へ」）、追加したタグを削除できることを確認する
    // （新規タグなのでロックされておらず、削除ボタンが必ず出る）。
    await tester.tap(find.byType(CommunityWorkCard).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('詳細へ'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // 検索中の（下に隠れている）コミュニティ画面のAppBar検索欄にも
    // 同じタグ文字列が残ったままなので（EditableTextもテキストの
    // 一致対象になる）、find.text(newTag)は単体では一意にならない。
    // 作品詳細画面本体のSingleChildScrollView配下に絞り込むことで、
    // 詳細画面側のタグチップのTextだけを特定する。
    final sheetScope = find.byType(SingleChildScrollView).last;
    final tagTextInSheet = find.descendant(
      of: sheetScope,
      matching: find.text(newTag),
    );
    expect(tagTextInSheet, findsOneWidget, reason: '追加したタグがシートに表示されていない');
    // タグチップ内部ではラベルのTextと削除ボタンが同じRowの直接の子と
    // なっているため、最も近いRow祖先へ絞り込むことで、他のタグ
    // （同じ作品に元から付いているダミータグ）の削除ボタンと混同せずに
    // このタグ専用の削除ボタンだけを特定できる。
    final removeButtonFinder = find.descendant(
      of: find.ancestor(of: tagTextInSheet, matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.close),
    );
    expect(removeButtonFinder, findsOneWidget, reason: 'タグ削除ボタンが見つからない');
    await tester.tap(removeButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'タグ削除で例外');
    // AppBarの検索欄には削除後もタグ文字列のクエリが残ったままなので
    // （find.text(newTag)単体では引き続きヒットする）、シート側だけを
    // 見て削除できたことを確認する。
    expect(
      find.descendant(of: sheetScope, matching: find.text(newTag)),
      findsNothing,
      reason: '削除したはずのタグがまだシートに表示されている',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('コミュニティ画面：タグのロックは投稿者本人にのみ操作可能', (WidgetTester tester) async {
    setPhoneViewSize(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final communityButtonFinder = find.byIcon(Icons.movie_filter_outlined);
    await tester.tap(communityButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // kDummySelfAuthorId（'author_01'）に対応する投稿者名'あにめ工房ミラ'
    // の作品を開く（フローティングプレビュー→「詳細へ」）。この投稿者の
    // 作品にのみロック切り替えボタン（Icons.lock_open／ロック中タグの
    // Icons.lock）が表示されるはず。
    final selfAuthorCardFinder = find.widgetWithText(
      CommunityWorkCard,
      'あにめ工房ミラ',
    );
    expect(selfAuthorCardFinder, findsWidgets);
    await tester.tap(selfAuthorCardFinder.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('詳細へ'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '投稿者本人の作品詳細画面表示で例外');

    // ダミーデータは各作品に必ず1個ロック済みタグがあるため、
    // ロック解除ボタン（Icons.lock_open）が最低1個は表示されるはず。
    final unlockButtonFinder = find.byIcon(Icons.lock_open);
    expect(
      unlockButtonFinder,
      findsWidgets,
      reason: '投稿者本人にロック切り替えボタンが表示されていない',
    );
    final unlockCountBefore = unlockButtonFinder.evaluate().length;

    // 未ロックのタグを1つロックする。
    await tester.tap(unlockButtonFinder.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'タグロックの切り替えで例外');
    final unlockCountAfter = find.byIcon(Icons.lock_open).evaluate().length;
    expect(
      unlockCountAfter,
      unlockCountBefore - 1,
      reason: 'ロック後も解除ボタンの数が減っていない',
    );

    // 詳細画面を閉じてコミュニティ画面へ戻る。
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 投稿者本人ではない作品（'あにめ工房ミラ'以外）にはロック切り替え
    // ボタンが一切表示されないことを確認する。
    final otherAuthorCardFinder = find.byWidgetPredicate(
      (w) => w is CommunityWorkCard && w.work.authorName != 'あにめ工房ミラ',
    );
    expect(otherAuthorCardFinder, findsWidgets);
    await tester.tap(otherAuthorCardFinder.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('詳細へ'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '他ユーザー作品詳細画面表示で例外');
    expect(
      find.byIcon(Icons.lock_open),
      findsNothing,
      reason: '投稿者本人以外にロック解除ボタンが表示されている',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('コミュニティでブックマークした作品がホームの「ブクマ済み」タブに表示される', (
    WidgetTester tester,
  ) async {
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

    // 先頭の作品カードのタイトルを記録し、そのカードのブックマーク
    // ボタン（サムネイル右上）をタップしてブックマークする。
    final firstCard = tester.widget<CommunityWorkCard>(
      find.byType(CommunityWorkCard).first,
    );
    final bookmarkedTitle = firstCard.work.title;
    final bookmarkButtonFinder = find.byIcon(Icons.bookmark_border).first;
    await tester.tap(bookmarkButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ブックマーク操作で例外');
    expect(
      find.byIcon(Icons.bookmark).first,
      findsOneWidget,
      reason: 'ブックマーク済み表示に切り替わっていない',
    );

    // コミュニティ画面を閉じてスプラッシュへ戻り、通常のホーム画面遷移
    // 経路で「作品をつくる」からホームへ入る。
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final createButtonFinder = find.byIcon(Icons.brush_outlined);
    expect(createButtonFinder, findsOneWidget);
    await tester.tap(createButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ホーム画面への遷移で例外');

    final firstLaunchDialogButton = find.text('はじめる');
    if (firstLaunchDialogButton.evaluate().isNotEmpty) {
      await tester.tap(firstLaunchDialogButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // 「ブクマ済み」タブへ切り替え、先ほどブックマークした作品が
    // 表示されることを確認する（CommunityServiceがアプリ全体で共有の
    // Providerであることの確認でもある）。
    final bookmarkedTabFinder = find.text('ブクマ済み');
    expect(bookmarkedTabFinder, findsOneWidget);
    await tester.tap(bookmarkedTabFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'ブクマ済みタブ表示で例外');
    expect(
      find.widgetWithText(CommunityWorkCard, bookmarkedTitle),
      findsOneWidget,
      reason: 'ブックマークした作品がブクマ済みタブに表示されていない',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('コミュニティ作品詳細画面：リポストボタンでトグルできる（Task#145）', (
    WidgetTester tester,
  ) async {
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

    final communityService = tester
        .element(find.byType(Scaffold).first)
        .read<CommunityService>();
    // 自作リポストも許可されているが（Task#134継続）、フォロー中作者
    // タブとの兼ね合いをテストしやすいよう自分以外の作者の作品を選ぶ。
    final work = communityService.works.firstWhere(
      (w) => w.authorId != kDummySelfAuthorId,
    );
    expect(communityService.isRepostedBySelf(work.id), isFalse);

    final routerContext = tester.element(find.byType(Scaffold).first);
    GoRouter.of(routerContext).push('/community/work/${work.id}');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '作品詳細画面への遷移で例外');

    final repostButtonFinder = find.widgetWithText(OutlinedButton, 'リポスト');
    expect(repostButtonFinder, findsOneWidget, reason: 'リポストボタンが見つからない');
    await tester.tap(repostButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'リポスト操作で例外');
    expect(communityService.isRepostedBySelf(work.id), isTrue);
    expect(find.widgetWithText(OutlinedButton, 'リポスト済み'), findsOneWidget);

    // もう一度タップして取り消せることも確認する。
    await tester.tap(find.widgetWithText(OutlinedButton, 'リポスト済み'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'リポスト取り消しで例外');
    expect(communityService.isRepostedBySelf(work.id), isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('コミュニティ画面：フォロー通知ベルのバッジと通知一覧画面が動作する'
      '（Task#134継続）', (WidgetTester tester) async {
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

    final communityService = tester
        .element(find.byType(Scaffold).first)
        .read<CommunityService>();
    final initialUnread = communityService.unreadFollowNotificationCount;
    expect(initialUnread, greaterThan(0), reason: 'ダミーデータ上、未読通知が最初からある想定');

    // 通知ベルのバッジに未読数が表示されているはず。
    expect(find.text('$initialUnread'), findsOneWidget);

    final bellFinder = find.byIcon(Icons.notifications_outlined);
    expect(bellFinder, findsOneWidget);
    await tester.tap(bellFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フォロー通知一覧画面への遷移で例外');

    // 画面を開いた時点で全て既読になり、リストにも通知本文が表示される。
    expect(communityService.unreadFollowNotificationCount, 0);
    expect(find.textContaining('さんにフォローされました'), findsWidgets);

    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '通知一覧画面から戻る操作で例外');
    // 戻った後はバッジが消えているはず（既読になったため）。
    expect(find.text('$initialUnread'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('投稿者別作品一覧画面：フォロー中/フォロワー一覧の公開設定トグルと'
      '一覧表示ダイアログが動作する（Task#134継続）', (WidgetTester tester) async {
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

    final scaffoldContext = tester.element(find.byType(Scaffold).first);
    final communityService = scaffoldContext.read<CommunityService>();
    // 自分自身のフォロワー一覧の公開設定は既定で非公開のはず。
    expect(communityService.selfFollowersPublic, isFalse);

    Navigator.of(scaffoldContext).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: kDummySelfAuthorId,
          authorName: communityService.authorNameOf(kDummySelfAuthorId)!,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '自分の投稿者別作品一覧画面への遷移で例外');

    // 本人ページでは、非公開のうちはフォロー中/フォロワー数がタップ
    // できない（下線が付かない＝InkWellのonTapがnull）。
    final followerTapFinder = find.byKey(
      const Key('communityAuthorFollowerCountTap'),
    );
    final followingTapFinder = find.byKey(
      const Key('communityAuthorFollowingCountTap'),
    );
    expect(followerTapFinder, findsOneWidget);
    expect(followingTapFinder, findsOneWidget);

    // 公開設定トグルをオンにする。
    final toggleSwitchFinder = find.byType(Switch);
    expect(
      toggleSwitchFinder,
      findsOneWidget,
      reason: 'フォロー中/フォロワー一覧公開トグルが見つからない',
    );
    await tester.tap(toggleSwitchFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フォロー中/フォロワー一覧公開トグル操作で例外');
    expect(communityService.selfFollowersPublic, isTrue);

    // フォロワー数をタップすると一覧ダイアログが開く。
    await tester.tap(followerTapFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フォロワー一覧ダイアログ表示で例外');
    expect(find.byType(AlertDialog), findsOneWidget);

    // ダイアログを閉じる。
    await tester.tap(find.widgetWithText(TextButton, '閉じる'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フォロワー一覧ダイアログを閉じる操作で例外');
    expect(find.byType(AlertDialog), findsNothing);

    // フォロー中の数をタップすると一覧ダイアログが開く。
    await tester.tap(followingTapFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フォロー中一覧ダイアログ表示で例外');
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '閉じる'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'フォロー中一覧ダイアログを閉じる操作で例外');
    expect(find.byType(AlertDialog), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));

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
    expect(find.text('作品広場への投稿数/日'), findsOneWidget);
    expect(find.textContaining('みんなの作品'), findsNothing);
    await probeAllControls(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→各種設定画面（ショートカット以外）を例外なく巡回できる', (
    WidgetTester tester,
  ) async {
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
      '/storage',
    ]);
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('起動→ホーム→ヘルプ・ヒント画面を例外なく表示できる', (WidgetTester tester) async {
    await bootToHome(tester);
    await visitRoutesAndPop(tester, const [
      '/help',
      '/tips',
    ], settleDelay: const Duration(milliseconds: 500));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→共有・ゴミ箱画面を例外なく表示できる', (WidgetTester tester) async {
    await bootToHome(tester);
    await visitRoutesAndPop(tester, const ['/shared', '/trash']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→新規プロジェクト作成→詳細・素材管理・書き出し・自動塗りプリセット・'
      'セーブツリー画面を例外なく表示できる', (WidgetTester tester) async {
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

    await visitRoutesAndPop(tester, [
      '/project/$projectId',
      '/materials/$projectId',
      '/export/$projectId',
      '/autofill-presets',
      '/save-tree/$projectId',
    ], settleDelay: const Duration(milliseconds: 500));
  }, timeout: const Timeout(Duration(seconds: 90)));

  // ここから先は、独立したルートを持たずNavigator.push（MaterialPageRoute）
  // で開く画面（対象UIのタップ操作が別途必要な画面）を巡回する。

  testWidgets('起動→自動塗りプリセット作成→詳細画面（別ルート）を例外なく表示できる', (
    WidgetTester tester,
  ) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→設定→ワークスペース設定→PCレイアウト詳細設定画面'
      '（別ルート）を例外なく表示できる', (WidgetTester tester) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動画面→コミュニティ画面→作品詳細→投稿者別作品一覧画面'
      '（別ルート）を例外なく表示できる', (WidgetTester tester) async {
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

    // 作品カードをタップするとフローティング動画プレビューウィンドウが
    // 開く。「詳細へ」ボタンで作品詳細画面（別ルート）へ遷移する。
    final workCardFinder = find.byType(CommunityWorkCard);
    expect(workCardFinder, findsWidgets);
    await tester.tap(workCardFinder.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('詳細へ'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '作品詳細画面表示で例外');

    // 詳細画面内の投稿者アイコン（CircleAvatar、一覧カード側には無い）を
    // タップして投稿者別作品一覧画面（MaterialPageRoute）を開く。
    final authorAvatarFinder = find.byType(CircleAvatar);
    expect(authorAvatarFinder, findsWidgets);
    await tester.tap(authorAvatarFinder.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '投稿者別作品一覧画面への遷移で例外');
    expect(find.byType(Scaffold), findsWidgets);
    await probeAllControls(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→新規プロジェクト画面→キャンバスサイズプリセット管理画面'
      '（別ルート）を例外なく表示できる', (WidgetTester tester) async {
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
    expect(tester.takeException(), isNull, reason: 'キャンバスサイズプリセット管理画面への遷移で例外');
    expect(find.byType(Scaffold), findsWidgets);
    await probeAllControls(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→ホーム→作品一覧タブ→フォルダ作成→フォルダ内画面（別ルート）を'
      '例外なく表示できる', (WidgetTester tester) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('起動→保存データ超過状態→保存方式変更（別ルート）を例外なく表示できる', (
    WidgetTester tester,
  ) async {
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
  }, timeout: const Timeout(Duration(seconds: 60)));
}
