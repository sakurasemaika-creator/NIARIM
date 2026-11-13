import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホームでキーボードで押した部品が、押したことで消える・押せなくなるとき
/// （貼り付け・選択中の操作バー・お気に入りの絞り込み・パンくず）、フォーカスが
/// ホームの画面へ戻ること。戻らないとFlutterは前にフォーカスのあった部品
/// （Tabで来る途中の「ゴミ箱」のタブ等）へ移し、続けて押したEnterでゴミ箱が
/// 開いた。本物のNiarimAppを起動処理から組み立てて確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_home_focus_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProjectService> boot(
    WidgetTester tester, {
    List<String> names = const ['apple', 'pear'],
    List<String> folders = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ExportStorage.invalidate();
    Directory('${tempDir.path}/exports').createSync();
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester);
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    await tester.runAsync(() async {
      for (final name in names) {
        await service.createProject(
          name: name,
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }
      for (final name in folders) {
        await service.createFolder(name);
      }
    });
    await settleIo(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    return service;
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  Finder card(String name) => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.text(name),
  );

  bool focusInside(Finder finder) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    final targets = finder.evaluate().toSet();
    if (targets.contains(focused)) return true;
    var inside = false;
    focused.visitAncestorElements((element) {
      inside = targets.contains(element);
      return !inside;
    });
    return inside;
  }

  bool homeHasFocus() =>
      FocusManager.instance.primaryFocus?.debugLabel == 'Home';

  String describeFocus() {
    final node = FocusManager.instance.primaryFocus;
    final context = node?.context;
    if (node == null || context == null) return 'null';
    String? tooltip;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Tooltip) tooltip = widget.message;
      return tooltip == null;
    });
    final texts = <String>[];
    void collect(Element element) {
      final widget = element.widget;
      if (widget is Text && widget.data != null) texts.add(widget.data!);
      if (texts.length < 2) element.visitChildren(collect);
    }

    (context as Element).visitChildren(collect);
    return 'label=${node.debugLabel} tooltip=$tooltip text=${texts.join('/')}';
  }

  Future<void> tabTo(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 80 && !focusInside(target); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusInside(target), isTrue, reason: 'Tab never reached $target');
  }

  int homeTab(WidgetTester tester) =>
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index;

  String location() =>
      appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

  /// 続けて押したEnterで何も起きず（タブが替わらない・ホームを離れない）、
  /// フォーカスがホームの画面にある。
  Future<void> expectEnterIsHarmless(
    WidgetTester tester,
    String what, {
    Finder? orInside,
  }) async {
    final before = describeFocus();
    final onHome =
        homeHasFocus() || (orInside != null && focusInside(orInside));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(
      homeTab(tester),
      0,
      reason: '$what: Enter on [$before] switched to tab ${homeTab(tester)}',
    );
    expect(location(), '/home', reason: '$what: Enter on [$before] left Home');
    expect(onHome, isTrue, reason: '$what: the focus was on [$before]');
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tester.longPress(card(name));
    await settle(tester);
  }

  testWidgets('paste a copy by keyboard: the focus stays on Home', (
    tester,
  ) async {
    final service = await boot(tester);
    await select(tester, 'apple');
    await tester.tap(find.byTooltip(l10n(tester).commonCopy));
    await settle(tester);
    final paste = find.byKey(const Key('homeCrossTabPasteButton'));
    expect(paste, findsOneWidget);
    await tabTo(tester, paste);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleIo(tester);
    expect(service.projects.where((p) => p.name.startsWith('apple')).length, 2);
    // コピーは貼り付けた後も残るので、フォーカスは貼り付けのボタン（もう一度
    // 貼り付けられる）かホームの画面にある。前の部品へは移さない。
    expect(paste, findsOneWidget);
    await expectEnterIsHarmless(tester, 'paste (copy)', orInside: paste);
  });

  testWidgets('paste a cut by keyboard: the toolbar goes, the focus stays '
      'on Home', (tester) async {
    final service = await boot(tester, folders: ['box']);
    await select(tester, 'apple');
    await tester.tap(find.byTooltip(l10n(tester).commonCut));
    await settle(tester);
    // 切り取った作品をフォルダの中へ貼り付ける。
    await tester.tap(card('box'));
    await settle(tester);
    final paste = find.byKey(const Key('homeCrossTabPasteButton'));
    await tabTo(tester, paste);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleIo(tester);
    final box = service.folders.firstWhere((f) => f.name == 'box');
    expect(
      service.projects.firstWhere((p) => p.name == 'apple').folderId,
      box.id,
    );
    expect(paste, findsNothing);
    await expectEnterIsHarmless(tester, 'paste (cut)');
  });

  for (final action in ['cut', 'copy', 'deselect']) {
    testWidgets('$action on the selection bar by keyboard: the focus stays '
        'on Home', (tester) async {
      await boot(tester);
      await select(tester, 'apple');
      final text = l10n(tester);
      final tooltip = switch (action) {
        'cut' => text.commonCut,
        'copy' => text.commonCopy,
        _ => text.homeSelectionAllDeselect,
      };
      final button = find.byTooltip(tooltip);
      await tabTo(tester, button);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byTooltip(text.homeSelectionAllSelect), findsNothing);
      await expectEnterIsHarmless(tester, action);
    });
  }

  testWidgets('the favorites chip by keyboard: the focus stays on Home', (
    tester,
  ) async {
    await boot(tester);
    final chip = find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.byType(FilterChip),
    );
    await tabTo(tester, chip);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    await expectEnterIsHarmless(tester, 'favorites chip');
  });

  testWidgets('the breadcrumb by keyboard: the focus stays on Home', (
    tester,
  ) async {
    await boot(tester, folders: ['box']);
    await tester.tap(card('box'));
    await settle(tester);
    final root = find.byTooltip(l10n(tester).projectListFolderRootOption);
    expect(root, findsOneWidget);
    await tabTo(tester, root);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(root, findsNothing);
    expect(card('apple'), findsOneWidget);
    await expectEnterIsHarmless(tester, 'breadcrumb');
  });

  testWidgets('opening the search by keyboard still puts the focus in the '
      'search field', (tester) async {
    await boot(tester);
    final search = find.byKey(const Key('homeSearchButton'));
    await tabTo(tester, search);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(
      focusInside(find.byKey(const Key('homeSearchInput'))),
      isTrue,
      reason: describeFocus(),
    );
    await tester.enterText(find.byKey(const Key('homeSearchInput')), 'pe');
    await settle(tester);
    expect(card('pear'), findsOneWidget);
    expect(card('apple'), findsNothing);
  });
}
