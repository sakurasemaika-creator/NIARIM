import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/project_service.dart';

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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // appRouterはモジュールレベルのシングルトンのため、前のテストケースで
    // 遷移した先のルートが残ったままになる。各テストを必ず起動画面から
    // 始められるよう、テストごとに明示的にリセットする。
    appRouter.go('/');
  });

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

    // 設定一覧から、ショートカット設定画面まで開いてみる。
    final shortcutEntryFinder = find.byIcon(Icons.keyboard);
    if (shortcutEntryFinder.evaluate().isNotEmpty) {
      await tester.tap(shortcutEntryFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'ショートカット設定画面への遷移で例外');
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
  }, timeout: const Timeout(Duration(seconds: 60)));

  /// 指定したルートへ順番に遷移して戻ってくることを繰り返し、途中で
  /// 例外が発生しないかを確認する。プロジェクトIDを必要としない設定・
  /// ヘルプ系の画面など、UIタップより直接遷移の方が経路が安定する
  /// 画面のために使う共通処理（新規プロジェクト作成テストで既に
  /// 使っている「経路の妥当性よりも画面自体の描画確認を優先する」方針を
  /// 複数画面へ拡張したもの）。
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
      GoRouter.of(routerContext).pop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$route から戻る際に例外');
    }
  }

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
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
