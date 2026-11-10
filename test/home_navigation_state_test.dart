import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_drawer.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホーム画面の状態の持ち方と戻る操作：検索・複数選択・タブ・スクロール・
/// 初回案内・引き出し。実際の起動画面から「作品をつくる」で入る。
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> boot(
    WidgetTester tester, {
    bool firstLaunch = false,
    int projects = 0,
    Size size = const Size(390, 844),
    bool? forcePc,
  }) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': firstLaunch,
      'language': 'ja',
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
      final service = tester
          .element(find.byType(SplashScreen))
          .read<ProjectService>();
      await tester.runAsync(() async {
        for (var i = 0; i < projects; i++) {
          await service.createProject(
            name: 'P${i + 1}',
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 320,
            exportHeight: 180,
          );
        }
      });
    }
    await tester.tap(find.byKey(const Key('splashCreateActionButton')));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen).last))!;

  String location() =>
      appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

  // 選択を使うテストは、選択中の操作バーが文字のまま並ぶ広さで確かめる
  // （スマホ幅での操作バーの収まりはhome_selection_toolbar_layout_testが
  // 見張る）。
  const selectionSize = Size(800, 900);

  Finder searchButton(WidgetTester tester) =>
      find.byTooltip(l10nOf(tester).commonSearch);

  Finder backArrow() => find.byKey(const Key('homeBackToSplashButton'));

  Finder listText(String name) => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.text(name),
  );

  bool fieldFocused() {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused?.widget is EditableText ||
        focused?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> ctrlA(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  Finder selectionCount(WidgetTester tester, int count) =>
      find.text(l10nOf(tester).homeSelectionCount(count));

  testWidgets('opening search focuses the field and typing filters', (
    tester,
  ) async {
    await boot(tester, projects: 3);
    await tester.tap(searchButton(tester));
    await settle(tester);
    expect(fieldFocused(), isTrue, reason: 'search field has focus at once');
    await tester.enterText(find.byType(TextField), 'P2');
    await settle(tester);
    expect(listText('P2'), findsOneWidget);
    expect(listText('P1'), findsNothing);
  });

  testWidgets('Ctrl+A inside the search field does not select projects', (
    tester,
  ) async {
    await boot(tester, projects: 3);
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P');
    await ctrlA(tester);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.selection.textInside(field.controller!.text), 'P');
  });

  // 以前の版は「Enterの後のCtrl+Aは見つかった作品だけを選ぶ」だったが、
  // その後「検索中は全選択・コピー等のショートカットを一切効かせない」に
  // 決まった。Enterで入力を終えても検索は開いたまま、Ctrl+Aでは何も選ばない。
  testWidgets('after Enter in search, the search stays open and Ctrl+A '
      'selects nothing', (tester) async {
    await boot(tester, projects: 2, size: selectionSize);
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(fieldFocused(), isFalse);
    await ctrlA(tester);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsNothing);
  });

  testWidgets('select-all while searching selects only the found works', (
    tester,
  ) async {
    await boot(tester, projects: 3, size: selectionSize);
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P2');
    await settle(tester);
    await tester.longPress(listText('P2'));
    await settle(tester);
    expect(selectionCount(tester, 1), findsOneWidget);
    await tester.tap(find.byTooltip(l10nOf(tester).homeSelectionAllSelect));
    await settle(tester);
    expect(selectionCount(tester, 1), findsOneWidget, reason: 'P1/P3 hidden');
  });

  testWidgets('switching to tag search with a mouse or pen keeps typing', (
    tester,
  ) async {
    await boot(tester, projects: 3);
    await tester.tap(searchButton(tester));
    await settle(tester);
    for (final (kind, icon) in [
      (PointerDeviceKind.mouse, Icons.sell_outlined),
      (PointerDeviceKind.stylus, Icons.search),
    ]) {
      await tester.tap(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
        kind: kind,
      );
      await settle(tester);
      expect(fieldFocused(), isTrue, reason: '$kind');
    }
  });

  for (final close in ['close button', 'Escape']) {
    testWidgets('shortcuts work after closing search with the $close', (
      tester,
    ) async {
      await boot(tester, projects: 2, size: selectionSize);
      await tester.tap(searchButton(tester));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'P');
      if (close == 'Escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tap(find.byTooltip(l10nOf(tester).commonClose));
      }
      await settle(tester);
      expect(find.byType(TextField), findsNothing);
      await ctrlA(tester);
      expect(selectionCount(tester, 2), findsOneWidget);
    });
  }

  for (final afterEnter in [false, true]) {
    testWidgets('Escape closes search and clears the query'
        '${afterEnter ? ' after Enter' : ''}', (tester) async {
      await boot(tester, projects: 2);
      await tester.tap(searchButton(tester));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'P2');
      await settle(tester);
      expect(listText('P1'), findsNothing);
      if (afterEnter) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);
        expect(fieldFocused(), isFalse);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(TextField), findsNothing, reason: 'search closed');
      expect(listText('P1'), findsOneWidget, reason: 'filter removed');
      expect(listText('P2'), findsOneWidget);
      await tester.tap(searchButton(tester));
      await settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(location(), '/home');
    });
  }

  testWidgets('back closes search, then selection, then returns to splash', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    // Search open: back closes it and stays on Home.
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);

    // Selection mode: back leaves selection, still on Home.
    await tester.longPress(listText('P1'));
    await settle(tester);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);

    // Nothing open: back returns to the splash screen.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  // 検索中も左上の戻る矢印と右上のメニューはそのままで、検索は×で閉じる。
  testWidgets('the close button ends search without leaving Home', (
    tester,
  ) async {
    await boot(tester, projects: 1);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    expect(find.byKey(const Key('homeBackToSplashButton')), findsOneWidget);
    expect(find.byKey(const Key('homeMenuButton')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SplashScreen), findsNothing);
  });

  // いまの決まり：左上の矢印は検索中も起動画面へ戻る（矢印は常に
  // homeBackToSplashButtonで、検索は×・Esc・端末の戻るで閉じる）。
  // dev_branchのfe164fc4（2026-10-29）の作りに従う。検索中の矢印を
  // 「検索を閉じる」にするかはDISC071で所有者の判断待ちなので、決まったら
  // このテストを書き換える。
  testWidgets('while searching, the arrow returns to the launch screen', (
    tester,
  ) async {
    await boot(tester, projects: 1);
    final l10n = l10nOf(tester);
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await settle(tester);
    expect(
      tester.widget<IconButton>(backArrow()).tooltip,
      l10n.homeBackToSplashTooltip,
    );
    await tester.tap(backArrow());
    await settle(tester);
    expect(location(), '/');
    expect(find.byType(SplashScreen), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await settle(tester);
    expect(find.byType(HomeDrawer), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeDrawer), findsNothing);
    expect(location(), '/home');
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    await tester.longPress(listText('P1'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsNothing);
    expect(location(), '/home');
    // 何も開いていなければ、アプリを閉じずに起動画面へ戻る。
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(location(), '/');
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  // Android 16以降の予測型「戻る」：Flutterが「戻る操作を受ける」とOSへ
  // 伝えていないと、OSは戻る操作をアプリへ渡さずにアプリを裏へ回す
  // （BackButtonListenerは呼ばれない）。handlePopRouteはこの判断を
  // 通らないので、OSへ伝えた値（setFrameworkHandlesBack）を見る。
  testWidgets('a Home reached by go() keeps Back from the system '
      '(predictive back)', (tester) async {
    final handlesBack = <bool>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        handlesBack.add(call.arguments as bool);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await boot(tester, projects: 1, size: selectionSize);
    expect(handlesBack, isNotEmpty);
    expect(handlesBack.last, isTrue, reason: 'pushed Home');
    appRouter.go('/home');
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SplashScreen), findsNothing);
    expect(handlesBack.last, isTrue, reason: 'go() Home, nothing open');
    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await settle(tester);
    expect(find.byType(HomeDrawer), findsOneWidget);
    expect(handlesBack.last, isTrue, reason: 'go() Home, drawer open');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(HomeDrawer), findsNothing);
    expect(handlesBack.last, isTrue, reason: 'go() Home, drawer closed');
    for (final tab in [1, 2, 3]) {
      await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
      await settle(tester);
      expect(handlesBack.last, isTrue, reason: 'go() Home, tab $tab');
    }
    // 戻る操作が届けば、アプリを閉じずに起動画面へ戻る。
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(location(), '/');
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  // 入力欄の外をマウス・ペンで押すと、入力欄はフォーカスを手放す。
  // 画面のショートカット（Esc）は、画面のフォーカスへ戻っていれば効く。
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
    testWidgets('after pressing outside the search field ($kind), Escape '
        'closes search and clears the query', (tester) async {
      await boot(tester, projects: 2);
      await tester.tap(searchButton(tester));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'P2');
      await settle(tester);
      expect(listText('P1'), findsNothing);
      // 一覧の何も無い所（見つかった1件の下）を押す。
      await tester.tapAt(
        tester.getCenter(find.byType(ProjectListWidget)),
        kind: kind,
      );
      await settle(tester);
      expect(fieldFocused(), isFalse, reason: 'the field let go');
      expect(find.byType(TextField), findsOneWidget, reason: 'still searching');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(TextField), findsNothing, reason: 'search closed');
      expect(listText('P1'), findsOneWidget, reason: 'filter removed');
      expect(location(), '/home');
    });
  }

  // 入力を終えた欄から、Flutterはフォーカスを画面のスコープそのもの
  // （画面のショートカットより上）へ落とすことがある。画面へ戻さないと、
  // 画面を一度押すまでEsc等が効かない。
  testWidgets('focus that falls to the page scope comes back to Home', (
    tester,
  ) async {
    await boot(tester, projects: 2);
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P2');
    await settle(tester);
    FocusManager.instance.primaryFocus!.unfocus();
    await settle(tester);
    expect(fieldFocused(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(TextField), findsNothing, reason: 'search closed');
    expect(listText('P1'), findsOneWidget);
  });

  // 検索中に引き出しを開いてEscを押し続けても、閉じるのは引き出しだけ。
  // キーを押し続けたときの繰り返しで検索まで閉じて検索語を消さない
  // （繰り返すのは取り消し・やり直し・コマ送りだけ）。
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('holding Escape while searching closes only the drawer '
        '($kind)', (tester) async {
      await boot(tester, projects: 2);
      await tester.tap(searchButton(tester));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'P2');
      await settle(tester);
      await tester.tap(find.byKey(const Key('homeMenuButton')), kind: kind);
      await settle(tester);
      expect(find.byType(HomeDrawer), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(HomeDrawer), findsNothing, reason: 'drawer closed');
      expect(find.byType(TextField), findsOneWidget, reason: 'still searching');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'P2',
      );
      expect(listText('P1'), findsNothing);
    });
  }

  // 引き出しは一覧を覆う（押せない）ので、その後ろの一覧へ全選択・
  // 切り取り・貼り付けのショートカットを効かせない。
  testWidgets('list shortcuts do not reach the list behind the open drawer', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settle(tester);
    }

    await tester.longPress(listText('P1'));
    await settle(tester);
    // コピーすると選択は終わる。
    await ctrl(LogicalKeyboardKey.keyC);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsNothing);
    final paste = find.byIcon(Icons.content_paste);
    expect(paste, findsOneWidget, reason: 'P1 is on the clipboard');

    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await settle(tester);
    expect(find.byType(HomeDrawer), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await ctrl(LogicalKeyboardKey.keyV);
    }
    await ctrl(LogicalKeyboardKey.keyA);
    expect(find.byType(HomeDrawer), findsOneWidget);
    expect(service.projects, hasLength(2), reason: 'no hidden copies');
    expect(
      find.byTooltip(l10nOf(tester).homeMoveToTrash),
      findsNothing,
      reason: 'nothing selected behind the drawer',
    );
    // 引き出しを閉じれば、また効く。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(HomeDrawer), findsNothing);
    await ctrl(LogicalKeyboardKey.keyA);
    expect(selectionCount(tester, 2), findsOneWidget);
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
      await tester.longPress(listText('P1'));
      await settle(tester);
      expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsOneWidget);
      await tester.tap(find.byKey(const Key('homeMenuButton')));
      await settle(tester);
      expect(find.byType(HomeDrawer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(HomeDrawer), findsNothing);
      expect(
        find.byTooltip(l10nOf(tester).homeMoveToTrash),
        findsOneWidget,
        reason: 'selection behind the drawer is kept',
      );
      expect(location(), '/home');
    });
  }

  testWidgets('the arrow returns to splash even over another screen', (
    tester,
  ) async {
    await boot(tester);
    // 保存容量の画面の「作品を整理」のように、別の画面からホームを開いた。
    appRouter.push('/home');
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(backArrow());
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(location(), '/');
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('leaving the Projects tab ends selection and search', (
    tester,
  ) async {
    await boot(tester, projects: 2, size: selectionSize);
    await tester.tap(searchButton(tester));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'P2');
    await settle(tester);
    await tester.longPress(listText('P2'));
    await settle(tester);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await settle(tester);
    expect(
      find.byTooltip(l10nOf(tester).homeMoveToTrash),
      findsNothing,
      reason: 'selection ended',
    );
    expect(searchButton(tester), findsNothing, reason: 'project search');
    expect(find.byIcon(Icons.view_module), findsNothing);
    expect(find.byType(TextField), findsNothing, reason: 'search closed');
    await tester.tap(find.byKey(const ValueKey('home_tab_0')));
    await settle(tester);
    expect(searchButton(tester), findsOneWidget);
    expect(find.byTooltip(l10nOf(tester).homeMoveToTrash), findsNothing);
    // 検索の絞り込みも外れて、両方の作品が見える。
    expect(listText('P1'), findsOneWidget);
    expect(listText('P2'), findsOneWidget);
    // 検索欄から離れた後も、画面のショートカットが効く。
    await ctrlA(tester);
    expect(selectionCount(tester, 2), findsOneWidget);
  });

  ScrollPosition listPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  testWidgets('the project list keeps its scroll position across tabs', (
    tester,
  ) async {
    await boot(tester, projects: 40);
    await tester.drag(find.byType(ProjectListWidget), const Offset(0, -600));
    await settle(tester);
    final before = listPosition(tester).pixels;
    expect(before, greaterThan(100));
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_0')));
    await settle(tester);
    expect(listPosition(tester).pixels, closeTo(before, 1));
  });

  testWidgets('each display size keeps its own scroll position', (
    tester,
  ) async {
    await boot(tester, projects: 40);
    final l10n = l10nOf(tester);
    await tester.drag(find.byType(ProjectListWidget), const Offset(0, -600));
    await settle(tester);
    final small = listPosition(tester).pixels;
    expect(small, greaterThan(100));
    Future<void> chooseSize(String label) async {
      await tester.tap(find.byIcon(Icons.view_module));
      await settle(tester);
      await tester.tap(find.text(label).last);
      await settle(tester);
    }

    await chooseSize(l10n.homeViewModeDetail);
    expect(listPosition(tester).pixels, 0, reason: 'detail starts at the top');
    await chooseSize(l10n.homeViewModeSmall);
    expect(listPosition(tester).pixels, closeTo(small, 1));
  });

  // 以前の版は「戻る操作で閉じても表示済みにする」だった。いまの初回の
  // 案内は保存を待つため（保存に失敗したら開いたまま、やり直せる）、
  // 戻る操作では閉じず、「はじめる」で閉じて表示済みにする。
  testWidgets('the first-run guide survives back and Start marks it seen', (
    tester,
  ) async {
    await boot(tester, firstLaunch: true);
    final l10n = l10nOf(tester);
    final settings = tester
        .element(find.byType(HomeScreen))
        .read<SettingsService>();
    expect(find.text(l10n.homeFirstLaunchStart), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(l10n.homeFirstLaunchStart), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(settings.isFirstLaunch, isTrue);
    await tester.tap(find.text(l10n.homeFirstLaunchStart));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
    expect(find.text(l10n.homeFirstLaunchStart), findsNothing);
    expect(settings.isFirstLaunch, isFalse);
  });

  // 以前の版は広いPC画面で引き出しの中身を左に常に出していたが、いまの
  // ホームはどの幅でも右上のメニューから引き出しを開く。
  for (final (pc, size) in [
    (false, const Size(390, 844)),
    (true, const Size(1280, 800)),
  ]) {
    testWidgets('the drawer stays behind the menu button '
        '(${pc ? 'PC' : 'phone'})', (tester) async {
      await boot(tester, size: size, forcePc: pc);
      expect(find.byKey(const Key('homeMenuButton')), findsOneWidget);
      expect(find.byType(HomeDrawer), findsNothing);
      await tester.tap(find.byKey(const Key('homeMenuButton')));
      await settle(tester);
      expect(find.byType(HomeDrawer), findsOneWidget);
      final scaffold = tester.state<ScaffoldState>(
        find
            .ancestor(
              of: find.byKey(const Key('homeMenuButton')),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(scaffold.isEndDrawerOpen, isTrue);
    });
  }

  testWidgets('the add and display-size buttons have accessible names', (
    tester,
  ) async {
    await boot(tester, projects: 1);
    final l10n = l10nOf(tester);
    final add = tester.widget<FloatingActionButton>(
      find.byWidgetPredicate(
        (w) => w is FloatingActionButton && w.heroTag == 'home-add-project',
      ),
    );
    expect(add.tooltip, isNotNull);
    expect(add.tooltip, isNotEmpty);
    expect(add.tooltip, isNot(l10n.communityScrollToTop));
    final sizeButton = find.ancestor(
      of: find.byIcon(Icons.view_module),
      matching: find.byType(PopupMenuButton<ProjectViewMode>),
    );
    expect(sizeButton, findsOneWidget);
    expect(
      tester.widget<PopupMenuButton<ProjectViewMode>>(sizeButton).tooltip,
      l10n.homeViewModeTooltip,
    );
    final sizeTooltip = find.descendant(
      of: sizeButton,
      matching: find.byTooltip(l10n.homeViewModeTooltip),
    );
    expect(sizeTooltip, findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(sizeTooltip).getSemanticsData().tooltip,
        l10n.homeViewModeTooltip,
      );
      expect(
        tester
            .getSemantics(find.byTooltip(add.tooltip!))
            .getSemanticsData()
            .tooltip,
        add.tooltip,
      );
    } finally {
      semantics.dispose();
    }
  });
}
