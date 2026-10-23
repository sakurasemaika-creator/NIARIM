import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホーム画面の状態の持ち方と戻る操作：検索・複数選択・タブ・スクロール・
/// 初回案内・PCの側面パネル。実際の起動画面から「作品をつくる」で入る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_home_state_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<List<SingleChildWidget>> boot(
    WidgetTester tester, {
    bool firstLaunch = false,
    int projects = 0,
    Size size = const Size(390, 844),
    bool? forcePc,
  }) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': firstLaunch,
      'force_pc_mode': ?switch (forcePc) {
        true => 1,
        false => 0,
        null => null,
      },
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    if (projects > 0) {
      final context = tester.element(find.byType(SplashScreen));
      final service = context.read<ProjectService>();
      await tester.runAsync(() async {
        for (var i = 0; i < projects; i++) {
          await service.createProject(
            name: 'P${i + 1}',
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
          );
        }
      });
    }
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    return providers;
  }

  String location() =>
      appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

  // 選択を使うテストは広い画面で確かめる（スマホ幅での操作バーの収まりは
  // project_selection_clipboard_testが見張る）。
  const selectionSize = Size(800, 900);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('opening search focuses the field and typing filters', (
    tester,
  ) async {
    await boot(tester, projects: 3);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<EditableText>() ??
          (focused?.widget is EditableText ? focused!.widget : null),
      isNotNull,
      reason: 'search field has focus right after opening',
    );
    await tester.enterText(find.byType(TextField), 'P2');
    await settle(tester);
    expect(find.text('P2'), findsWidgets);
    expect(find.text('P1'), findsNothing);
  });

  testWidgets('Ctrl+A inside the search field does not select projects', (
    tester,
  ) async {
    await boot(tester, projects: 3);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byIcon(Icons.content_cut), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.selection.textInside(field.controller!.text), 'P');
  });

  Future<void> ctrlA(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  testWidgets('while searching, Ctrl+A selects nothing even after Enter', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    // 検索は開いたまま、入力だけ終える。検索中は全選択等のショートカットを
    // 効かせない（検索で隠れた作品を操作しないため）。
    expect(find.byType(TextField), findsOneWidget);
    await ctrlA(tester);
    expect(find.textContaining('件選択中'), findsNothing);
  });

  testWidgets('select-all leaves out works received through Share', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    // 「共有」から取り込んだ作品はプロジェクト一覧に出ないので、全選択でも
    // 選ばない（選ぶと、見えていない作品まで一括削除の対象になる）。
    final service = tester
        .element(find.byType(ProjectListWidget))
        .read<ProjectService>();
    await tester.runAsync(
      () => service.importSharedProject(
        NiaproData(
          project: Project(
            id: 'ignored',
            name: '受け取った作品',
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            totalWorkSeconds: 0,
          ),
          scenes: const [],
          tileData: const {},
        ),
      ),
    );
    await settle(tester);
    await ctrlA(tester);
    expect(find.text('2件選択中'), findsOneWidget);
  });

  for (final close in ['close button', 'Escape']) {
    testWidgets('shortcuts work after closing search with the $close', (
      tester,
    ) async {
      await boot(tester, projects: 2, size: selectionSize);
      await tester.tap(find.byIcon(Icons.search));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'P');
      if (close == 'Escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tap(find.byIcon(Icons.close));
      }
      await settle(tester);
      expect(find.byType(TextField), findsNothing);
      await ctrlA(tester);
      expect(find.text('2件選択中'), findsOneWidget);
    });
  }

  testWidgets('back closes search, then selection, then returns to splash', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    // Search open: back closes it and stays on Home.
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);

    // Selection mode: back leaves selection, still on Home.
    await tester.longPress(find.text('P1'));
    await settle(tester);
    expect(find.byIcon(Icons.content_cut), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byIcon(Icons.content_cut), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);

    // Nothing open: back returns to the splash screen.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  // 検索中の左上はハンバーガーごと隠れ、検索は右上の×で閉じる。
  testWidgets('the close button ends search without leaving Home', (
    tester,
  ) async {
    await boot(tester, projects: 1);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    expect(find.byIcon(Icons.menu), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('a Home reached by go() returns to splash on back', (
    tester,
  ) async {
    await boot(tester, projects: 1, size: selectionSize);
    appRouter.go('/home');
    await settle(tester);
    // 入れ替わる前のホームが退場し終えるまで待つ。
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SplashScreen), findsNothing);
    // 引き出し・検索・選択はアプリを閉じずに1つずつ閉じる。
    await tester.tap(find.byIcon(Icons.menu));
    await settle(tester);
    expect(find.byType(HomeDrawer), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeDrawer), findsNothing);
    expect(location(), '/home');
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    await tester.longPress(find.text('P1'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byIcon(Icons.content_cut), findsNothing);
    expect(location(), '/home');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  for (final root in [false, true]) {
    testWidgets('back with the drawer open closes only the drawer '
        '(${root ? 'root' : 'pushed'} Home)', (tester) async {
      await boot(tester, projects: 1, size: selectionSize);
      if (root) {
        appRouter.go('/home');
        await settle(tester);
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.longPress(find.text('P1'));
      await settle(tester);
      expect(find.byIcon(Icons.content_cut), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await settle(tester);
      expect(find.byType(HomeDrawer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(HomeDrawer), findsNothing);
      expect(
        find.byIcon(Icons.content_cut),
        findsOneWidget,
        reason: 'selection behind the drawer is kept',
      );
      expect(location(), '/home');
    });
  }

  // 画面下の左右にFABが浮くので、一番下までスクロールすれば最後の行の
  // 名前がFABの上へ出ること（以前は一覧の下端の余白が8pxだけで、最後の
  // 行の名前とメニューが左右のFABの下に隠れたままだった）。
  testWidgets('scrolled to the end, the last row clears the bottom FABs', (
    tester,
  ) async {
    await boot(tester, projects: 20);
    await tester.drag(find.byType(GridView), const Offset(0, -4000));
    await settle(tester);
    final fabTop = tester
        .getRect(find.byKey(const Key('homeBackToSplashFab')))
        .top;
    for (final name in ['P1', 'P2', 'P3']) {
      expect(
        tester.getRect(find.text(name)).bottom,
        lessThanOrEqualTo(fabTop),
        reason: name,
      );
    }
  });

  // 起動画面へ戻るのは左下のFAB。
  testWidgets('the back FAB returns to splash even over another screen', (
    tester,
  ) async {
    await boot(tester);
    // 保存容量の画面の「作品を整理」のように、別の画面からホームを開いた。
    appRouter.push('/home');
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('homeBackToSplashFab')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(location(), '/');
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('leaving the Projects tab ends selection and search', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P2');
    await settle(tester);
    await tester.longPress(
      find.descendant(
        of: find.byType(ProjectListWidget),
        matching: find.text('P2'),
      ),
    );
    await settle(tester);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    await tester.tap(find.text('作品一覧'));
    await settle(tester);
    expect(find.byIcon(Icons.delete), findsNothing, reason: 'selection ended');
    expect(find.byIcon(Icons.search), findsNothing, reason: 'project search');
    expect(find.byType(ProjectViewModeMenu), findsNothing);
    expect(find.byType(TextField), findsNothing, reason: 'search closed');
    await tester.tap(find.text('プロジェクト'));
    await settle(tester);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsNothing);
    // 検索の絞り込みも外れて、両方の作品が見える。
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);
    await ctrlA(tester);
    expect(find.text('2件選択中'), findsOneWidget);
  });

  testWidgets('the project list keeps its scroll position across tabs', (
    tester,
  ) async {
    await boot(tester, projects: 40);
    final grid = find.byType(GridView);
    await tester.drag(grid, const Offset(0, -600));
    await settle(tester);
    // 先頭のScrollableはタブを横に送るPageViewなので、一覧のものを探す。
    double offset() => tester
        .state<ScrollableState>(
          find.descendant(of: grid, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(100));
    await tester.tap(find.text('作品一覧'));
    await settle(tester);
    await tester.tap(find.text('プロジェクト'));
    await settle(tester);
    expect(offset(), closeTo(before, 1));
  });

  testWidgets('empty bookmarks offer a way to Work Plaza', (tester) async {
    await boot(tester);
    await tester.tap(find.text('ブクマ済み'));
    await settle(tester);
    expect(find.text('近日公開'), findsNothing);
    await tester.tap(find.text('作品広場'));
    await settle(tester);
    expect(location(), '/community');
  });

  testWidgets('bookmarks hidden by Plaza filters are not called missing', (
    tester,
  ) async {
    await boot(tester);
    final community = tester
        .element(find.byType(Scaffold).first)
        .read<CommunityService>();
    final work = community.works.firstWhere(
      (w) => community.isDiscoverableForViewer(w) && !community.isOwnWork(w),
    );
    await tester.runAsync(() => community.toggleBookmark(work.id));
    await tester.tap(find.text('ブクマ済み'));
    await settle(tester);
    expect(find.text('表示できるブックマーク作品がありません'), findsNothing);
    // 作品広場のミュートでその作品が隠れても、ブックマークは残っている。
    await tester.runAsync(() => community.setMutedWords([work.title]));
    await settle(tester);
    expect(find.text('ブックマークは保存されています'), findsOneWidget);
    expect(find.text('表示できるブックマーク作品がありません'), findsNothing);
    expect(find.text('作品広場'), findsOneWidget);
  });
}
