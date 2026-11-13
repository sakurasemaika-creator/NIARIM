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
import 'package:niarim/widgets/moved_to_trash_snack_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

// ホームの知らせ（SnackBar）がいつ消えるか。「元に戻す」の付いた知らせは
// 既定では時間で消えず、次の画面まで付いてきて下のボタンに重なる。
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
    final dir = Directory.systemTemp.createTempSync('home-notice-');
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

  String? snackText(WidgetTester tester) {
    final texts = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (texts.evaluate().isEmpty) return null;
    return (texts.evaluate().first.widget as Text).data;
  }

  Future<void> trashFromMenu(WidgetTester tester, String name) async {
    await tester.tap(card(name), buttons: kSecondaryMouseButton);
    await settle(tester);
    await tester.tap(find.text(l10nOf(tester).projectDetailTrashMenuItem));
    final moved = l10nOf(tester).homeMovedToTrashSnackbar(1);
    await waitFor(tester, () => snackText(tester) == moved);
    // 出てくる動きが終わってから、消えるまでの時間を数え始める。
    await settle(tester);
  }

  Future<void> cut(WidgetTester tester, String name) async {
    await tester.longPress(card(name));
    await settle(tester);
    await tester.tap(find.byTooltip(l10nOf(tester).commonCut));
    await settle(tester);
    expect(snackText(tester), l10nOf(tester).homeCutSnackbar(1));
    expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('moved to Trash', () {
    testWidgets('the notice from a card menu closes by itself', (tester) async {
      final service = await openHome(tester, names: ['apple', 'banana']);
      await trashFromMenu(tester, 'apple');
      expect(find.text(l10nOf(tester).homeUndoAction), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      // 消えただけで、作品はゴミ箱に残っている。
      expect(service.trash.map((p) => p.name), ['apple']);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('the notice from a bulk move closes by itself', (tester) async {
      final service = await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonMove));
      await waitFor(
        tester,
        () => snackText(tester) == l10n.homeMovedToTrashSnackbar(1),
      );
      await settle(tester);
      expect(find.text(l10n.homeUndoAction), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(service.trash.map((p) => p.name), ['apple']);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // 一覧の最後の1件をゴミ箱へ移すと、一覧は「プロジェクトがありません」に
    // 替わる。「元に戻す」が消えた一覧の部品を通していたので、押しても何も
    // 起きず、作品はゴミ箱に残ったまま知らせだけが閉じていた。
    testWidgets('Undo brings back the only work after its card is gone', (
      tester,
    ) async {
      final service = await openHome(tester, names: ['apple']);
      await trashFromMenu(tester, 'apple');
      expect(service.projects, isEmpty);
      expect(card('apple'), findsNothing);
      await tester.tap(find.text(l10nOf(tester).homeUndoAction));
      await waitFor(tester, () => service.projects.isNotEmpty);
      expect(service.projects.single.name, 'apple');
      expect(service.trash, isEmpty);
      await settleIo(tester);
      expect(card('apple'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  });

  // 知らせは5秒以内に消える（所有者の判断：トーストは基本的に5秒以内に
  // 消え、操作ボタンの付いたものも同じ）。消えるまでの時間は出終わってから
  // 数え始まるので、出たのを細かく見張り、出終わった所から5秒待つ。
  group('a moved-to-Trash notice closes within 5 s', () {
    Future<void> waitForSnack(WidgetTester tester, String text) async {
      for (var i = 0; i < 400 && snackText(tester) != text; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(snackText(tester), text);
      // 出てくる動き（250ms）を終わらせ、次の描き直しで時間を数え始める。
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    Future<void> expectGoneAfterFiveSeconds(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      // 消える動き（250ms）の分。
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'the notice is still on screen 5 s after it appeared',
      );
    }

    testWidgets('from a card menu', (tester) async {
      await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text(l10n.projectDetailTrashMenuItem));
      await waitForSnack(tester, l10n.homeMovedToTrashSnackbar(1));
      await expectGoneAfterFiveSeconds(tester);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('from a bulk move', (tester) async {
      await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonMove));
      await waitForSnack(tester, l10n.homeMovedToTrashSnackbar(1));
      await expectGoneAfterFiveSeconds(tester);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('for a folder moved with its contents', (tester) async {
      final service = await openHome(tester, names: ['apple']);
      final l10n = l10nOf(tester);
      final folder = (await tester.runAsync(
        () => service.createFolder('scenes'),
      ))!;
      showFolderMovedToTrashSnackBar(
        ScaffoldMessenger.of(tester.element(find.byType(HomeScreen))),
        l10n,
        service,
        folder,
      );
      await waitForSnack(tester, l10n.homeFolderMovedToTrashSnackbar('scenes'));
      await expectGoneAfterFiveSeconds(tester);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  });

  group('cut', () {
    // 切り取りは貼り付けるまで続くが、知らせは時間で消える。
    testWidgets('the cut notice closes by itself and the cut stays pending', (
      tester,
    ) async {
      await openHome(tester, names: ['apple', 'banana']);
      await cut(tester, 'apple');
      expect(find.text(l10nOf(tester).homeUndoAction), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);
      expect(
        find.ancestor(of: card('apple'), matching: find.byType(Opacity)),
        findsOneWidget,
        reason: 'the cut work stays dimmed',
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('Esc that cancels a cut also closes the cut notice', (
      tester,
    ) async {
      await openHome(tester, names: ['apple', 'banana']);
      await cut(tester, 'apple');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'the notice still tells the user to press Paste',
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // 切り取りの知らせの「元に戻す」でやめたときも、知らせは閉じる。
    testWidgets('Undo on the cut notice cancels the cut and closes it', (
      tester,
    ) async {
      await openHome(tester, names: ['apple', 'banana']);
      await cut(tester, 'apple');
      await tester.tap(find.text(l10nOf(tester).homeUndoAction));
      await settle(tester);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // 切り取りの後で別の知らせ（ゴミ箱へ移した・元に戻す）が出ているときに
    // Escで切り取りをやめても、その知らせは閉じない。
    testWidgets('Esc that cancels a cut leaves a later notice alone', (
      tester,
    ) async {
      final service = await openHome(tester, names: ['apple', 'banana']);
      await cut(tester, 'apple');
      await trashFromMenu(tester, 'banana');
      final moved = l10nOf(tester).homeMovedToTrashSnackbar(1);
      expect(snackText(tester), moved);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
      expect(snackText(tester), moved);
      // 残った知らせの「元に戻す」は効く。
      await tester.tap(find.text(l10nOf(tester).homeUndoAction));
      await waitFor(tester, () => service.projects.length == 2);
      expect(service.trash, isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // 他の知らせが出ていて、その後ろでもう1つ待っているときに切り取っても、
    // 切り取りの知らせをすぐ出す。待っていた知らせの後ろに回ると、Escで
    // 切り取りをやめたときに、出ている別の知らせを閉じてしまう。
    testWidgets('a cut made while other notices are waiting shows its notice '
        'at once and can be cancelled', (tester) async {
      await openHome(tester, names: ['apple', 'banana']);
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
        ..showSnackBar(const SnackBar(content: Text('first notice')))
        ..showSnackBar(const SnackBar(content: Text('waiting notice')));
      await settle(tester);
      expect(snackText(tester), 'first notice');
      await cut(tester, 'apple');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await close(tester);
    });
  });
}
