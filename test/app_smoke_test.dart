import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
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

  testWidgets('起動画面→コミュニティ準備中画面まで例外なく遷移できる', (WidgetTester tester) async {
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
    expect(tester.takeException(), isNull, reason: 'コミュニティ準備中画面への遷移で例外');
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
}
