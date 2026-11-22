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
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホームの取り消し（Ctrl+Z）で、最後にゴミ箱へ移したものを元に戻す。
/// 「元に戻す」の付いた知らせが消えた後でも戻せる（所有者の判断、
/// 2026-11-22「Ctrl+Zで戻せるようにする」、DISC125）。戻すのは最後の1回の
/// 移動だけで、続けて押しても前に移したものまでは戻さない。ゴミ箱のタブから
/// 戻した・知らせの「元に戻す」で戻したものは二度戻さない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// 本物のファイルの読み書き（ゴミ箱へ移す・戻す）を待ってから描く。
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await settleIo(tester);
    }
    expect(done(), isTrue, reason: 'waited for a state that never came');
  }

  Future<ProjectService> openHome(
    WidgetTester tester, {
    required List<String> names,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('home-trash-undo-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 後始末の途中で保存が走っていても、テストの結果は変えない。
      }
    });
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
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
    });
    await settleIo(tester);
    return service;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  Finder card(String name) => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.text(name),
  );

  bool snackShows(WidgetTester tester, String text) => find
      .descendant(
        of: find.byType(SnackBar),
        matching: find.bySemanticsLabel(text),
      )
      .evaluate()
      .isNotEmpty;

  Future<void> trashFromMenu(WidgetTester tester, String name) async {
    final before = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>()
        .trash
        .length;
    await tester.tap(card(name), buttons: kSecondaryMouseButton);
    await settle(tester);
    await tester.tap(find.text(l10nOf(tester).projectDetailTrashMenuItem));
    await waitFor(
      tester,
      () =>
          tester
              .element(find.byType(HomeScreen))
              .read<ProjectService>()
              .trash
              .length >
          before,
    );
    await settle(tester);
  }

  /// 知らせが消え切るまで待つ。
  Future<void> letNoticeGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
  }

  Future<void> pressUndo(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleIo(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Ctrl+Z brings back the last moved work after the notice went', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final service = await openHome(tester, names: ['apple', 'banana']);
    await trashFromMenu(tester, 'apple');
    await letNoticeGo(tester);
    expect(service.trash.map((p) => p.name), ['apple']);

    await pressUndo(tester);
    await waitFor(tester, () => service.trash.isEmpty);
    expect(service.projects.map((p) => p.name), contains('apple'));
    await settle(tester);
    expect(card('apple'), findsOneWidget);
    // 戻したことを知らせる。
    expect(snackShows(tester, l10nOf(tester).homeTrashMoveUndone(1)), isTrue);
    await letNoticeGo(tester);

    // もう一度押しても何も起きない（前に移したものは無い）。
    await pressUndo(tester);
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(service.trash, isEmpty);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await close(tester);
  });

  testWidgets('Ctrl+Z restores only the last move, not the one before', (
    tester,
  ) async {
    final service = await openHome(tester, names: ['apple', 'banana']);
    await trashFromMenu(tester, 'apple');
    await letNoticeGo(tester);
    await trashFromMenu(tester, 'banana');
    await letNoticeGo(tester);
    expect(service.trash.map((p) => p.name).toSet(), {'apple', 'banana'});

    await pressUndo(tester);
    await waitFor(tester, () => service.trash.length == 1);
    expect(service.trash.single.name, 'apple');
    await letNoticeGo(tester);
    await pressUndo(tester);
    await settle(tester);
    expect(service.trash.single.name, 'apple');
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('Ctrl+Z while the notice is up restores once and closes it', (
    tester,
  ) async {
    final service = await openHome(tester, names: ['apple', 'banana']);
    await trashFromMenu(tester, 'apple');
    final l10n = l10nOf(tester);
    expect(find.text(l10n.homeUndoAction), findsOneWidget);

    await pressUndo(tester);
    await waitFor(tester, () => service.trash.isEmpty);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    // ゴミ箱の知らせは閉じ、「元に戻す」はもう無い。
    expect(find.text(l10n.homeUndoAction), findsNothing);
    expect(service.projects.where((p) => p.name == 'apple'), hasLength(1));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('Undo in the notice, then Ctrl+Z, does not restore twice', (
    tester,
  ) async {
    final service = await openHome(tester, names: ['apple', 'banana']);
    await trashFromMenu(tester, 'apple');
    await tester.tap(find.text(l10nOf(tester).homeUndoAction));
    await waitFor(tester, () => service.trash.isEmpty);
    await letNoticeGo(tester);
    await pressUndo(tester);
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(service.projects.where((p) => p.name == 'apple'), hasLength(1));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('Ctrl+Z works from the Trash tab too', (tester) async {
    final service = await openHome(tester, names: ['apple', 'banana']);
    await trashFromMenu(tester, 'apple');
    await letNoticeGo(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await settleIo(tester);
    await settle(tester);
    await pressUndo(tester);
    await waitFor(tester, () => service.trash.isEmpty);
    expect(service.projects.where((p) => p.name == 'apple'), hasLength(1));
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
