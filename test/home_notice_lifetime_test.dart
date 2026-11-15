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
import 'package:niarim/widgets/app_toast_messenger.dart'
    show kToastEntrance, kToastFadeOut, kToastMaxLifetime;
import 'package:niarim/widgets/moved_to_trash_snack_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/home_clipboard_harness.dart';

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
      await tester.tap(find.widgetWithText(FilledButton, l10n.homeMoveToTrash));
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

  // 知らせは出てから5秒以内に消える（所有者の判断：トーストは基本的に5秒
  // 以内に消え、消えるときは徐々に薄くなる。操作ボタンの付いたものも同じ）。
  // 出たフレームを細かく見張り、そこから1フレーム（16ms）ずつ描いて、消え
  // 切るまでの時間を測る。1回の長いpumpだと、時間切れの後の薄くなる動きが
  // そのpumpの終わりのフレームまで始まらず、実際の端末より遅く見える。
  group('a moved-to-Trash notice closes within 5 s', () {
    Future<void> waitForSnack(WidgetTester tester, String text) async {
      for (var i = 0; i < 400 && snackText(tester) != text; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(snackText(tester), text);
    }

    Future<void> expectGoneWithinFiveSeconds(WidgetTester tester) async {
      const frame = Duration(milliseconds: 16);
      var elapsed = Duration.zero;
      while (find.byType(SnackBar).evaluate().isNotEmpty &&
          elapsed < const Duration(seconds: 8)) {
        await tester.pump(frame);
        elapsed += frame;
      }
      debugPrint(
        'the notice left ${elapsed.inMilliseconds} ms after it appeared',
      );
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'the notice is still on screen 8 s after it appeared',
      );
      expect(
        elapsed,
        lessThanOrEqualTo(const Duration(seconds: 5)),
        reason: 'the notice stayed longer than 5 s after it appeared',
      );
    }

    testWidgets('from a card menu', (tester) async {
      await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text(l10n.projectDetailTrashMenuItem));
      await waitForSnack(tester, l10n.homeMovedToTrashSnackbar(1));
      await expectGoneWithinFiveSeconds(tester);
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
      await tester.tap(find.widgetWithText(FilledButton, l10n.homeMoveToTrash));
      await waitForSnack(tester, l10n.homeMovedToTrashSnackbar(1));
      await expectGoneWithinFiveSeconds(tester);
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
      await expectGoneWithinFiveSeconds(tester);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  });

  // フォルダを1つだけゴミ箱へ移したときは、そのフォルダの名前で知らせる
  // （「フォルダ「scenes」をゴミ箱へ移動しました」）。以前はフォルダの知らせ
  // （showFolderMovedToTrashSnackBar）がどこからも呼ばれず、メニューからも
  // 選んで移したときも「1件をゴミ箱へ移動しました」だった。
  group('one folder moved to the Trash is named', () {
    for (final via in ['menu', 'selection']) {
      testWidgets('from the $via', (tester) async {
        final service = await openHome(tester, names: ['apple']);
        final l10n = l10nOf(tester);
        final folder = (await tester.runAsync(
          () => service.createFolder('scenes'),
        ))!;
        await settleIo(tester);
        if (via == 'menu') {
          await tester.tap(card('scenes'), buttons: kSecondaryMouseButton);
          await settle(tester);
          await tester.tap(find.text(l10n.homeMoveToTrash).last);
        } else {
          await tester.longPress(card('scenes'));
          await settle(tester);
          await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
        }
        await settle(tester);
        await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
        await waitFor(
          tester,
          () => service.trashedFolders.any((t) => t.folder.id == folder.id),
        );
        await waitFor(tester, () => snackText(tester) != null);
        expect(
          snackText(tester),
          l10n.homeFolderMovedToTrashSnackbar('scenes'),
        );
        // 「元に戻す」でフォルダが戻る。
        await tester.tap(find.text(l10n.homeUndoAction));
        await waitFor(
          tester,
          () => service.folders.any((f) => f.id == folder.id),
        );
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  });

  // お気に入りを移そうとして断られたときの知らせは、ほかの断りと同じく
  // 前の断りだけを取り下げる（showTrashRefusedSnackBar）。プロジェクト詳細と
  // 受け取ったもののメニューは素のshowSnackBarで、続けて押すと断りが
  // 順番待ちに積み重なり、5秒ずつ何度も出続けた。
  group('a refused favourite does not pile up notices', () {
    Future<void> pressThrice(
      WidgetTester tester,
      Future<void> Function() press,
    ) async {
      for (var i = 0; i < 3; i++) {
        await press();
        await settle(tester);
      }
    }

    Future<void> expectOneRefusal(WidgetTester tester, String text) async {
      expect(snackText(tester), text);
      // 出ている断りが消えた後に、積み重なった断りが続けて出ない（8秒の間
      // 少しずつ時計を進める。知らせは出切ってから5秒以内に消える）。
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(snackText(tester), isNull, reason: 'refusals were queued');
    }

    testWidgets('from Project Detail', (tester) async {
      final service = await openHome(tester, names: ['apple']);
      final l10n = l10nOf(tester);
      final apple = service.projects.single;
      await tester.runAsync(() => service.setFavorite(apple.id, true));
      await settleIo(tester);
      await tester.tap(card('apple'));
      await waitFor(
        tester,
        () =>
            find.byType(AppBar).evaluate().length >= 2 ||
            appRouter.routerDelegate.currentConfiguration.uri.path.startsWith(
              '/project/',
            ),
      );
      await settleIo(tester);
      await pressThrice(tester, () async {
        await tester.tap(
          find
              .descendant(
                of: find.byType(AppBar).last,
                matching: find.byIcon(Icons.more_vert),
              )
              .last,
        );
        await settle(tester);
        await tester.tap(find.text(l10n.projectDetailTrashMenuItem).last);
      });
      await expectOneRefusal(tester, l10n.commonFavoriteDeleteBlocked);
      expect(service.trash, isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('from a received work\'s menu', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final gift = await home.addReceived('gift');
      await tester.runAsync(() => home.projects.setFavorite(gift.id, true));
      await home.settleIo(2);
      await home.showTab(2);
      final l10n = home.l10n;
      await pressThrice(tester, () async {
        await tester.tap(
          find.text('gift').first,
          buttons: kSecondaryMouseButton,
        );
        await settle(tester);
        await tester.tap(find.text(l10n.projectDetailTrashMenuItem).last);
      });
      await expectOneRefusal(tester, l10n.commonFavoriteDeleteBlocked);
      expect(home.projects.trash, isEmpty);
      expect(tester.takeException(), isNull);
      await home.close();
    });
  });

  // 続けてゴミ箱へ移しても、前に移したものの「元に戻す」を失わない
  // （DISC092の残り）。前の知らせが出ている・待っている間に次を移すと、
  // 前の知らせは取り下げ、新しい知らせが両方の件数を伝え、その「元に戻す」で
  // 両方を戻す。ほかの機能の知らせ（出ている・待っている）は閉じない。
  group('moving to Trash again while the earlier notice is up', () {
    Future<void> bulkTrash(WidgetTester tester, List<String> names) async {
      final l10n = l10nOf(tester);
      await tester.longPress(card(names.first));
      await settle(tester);
      for (final name in names.skip(1)) {
        await tester.tap(card(name));
        await settle(tester);
      }
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, l10n.homeMoveToTrash));
    }

    testWidgets('two card-menu moves: one notice, Undo brings back both', (
      tester,
    ) async {
      final service = await openHome(
        tester,
        names: ['apple', 'banana', 'cherry'],
      );
      final l10n = l10nOf(tester);
      await trashFromMenu(tester, 'apple');
      await tester.tap(card('banana'), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text(l10n.projectDetailTrashMenuItem));
      await waitFor(
        tester,
        () => snackText(tester) == l10n.homeMovedToTrashSnackbar(2),
      );
      await settle(tester);
      expect(find.text(l10n.homeUndoAction), findsOneWidget);
      await tester.tap(find.text(l10n.homeUndoAction));
      await waitFor(tester, () => service.projects.length == 3);
      expect(service.trash, isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('a bulk move after a card-menu move: Undo brings back all', (
      tester,
    ) async {
      final service = await openHome(
        tester,
        names: ['apple', 'banana', 'cherry', 'damson'],
      );
      final l10n = l10nOf(tester);
      await trashFromMenu(tester, 'apple');
      await bulkTrash(tester, ['banana', 'cherry']);
      await waitFor(
        tester,
        () => snackText(tester) == l10n.homeMovedToTrashSnackbar(3),
      );
      await settle(tester);
      await tester.tap(find.text(l10n.homeUndoAction));
      await waitFor(tester, () => service.projects.length == 4);
      expect(service.trash, isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // 前の知らせが時間で消えた後に移したときは、合わせない（前の5秒は
    // もう過ぎている）。
    testWidgets('after the earlier notice has gone, the counts start over', (
      tester,
    ) async {
      final service = await openHome(
        tester,
        names: ['apple', 'banana', 'cherry'],
      );
      final l10n = l10nOf(tester);
      await trashFromMenu(tester, 'apple');
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      await trashFromMenu(tester, 'banana');
      expect(snackText(tester), l10n.homeMovedToTrashSnackbar(1));
      await tester.tap(find.text(l10n.homeUndoAction));
      await waitFor(tester, () => service.projects.length == 2);
      expect(service.trash.map((p) => p.name), ['apple']);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // 前の知らせが出ている間に、そこで移したものをゴミ箱のタブから戻した・
    // 完全に削除した・戻してまた移したときは、新しい知らせはいまゴミ箱に
    // あるものだけを1回ずつ数える（以前は前の移動をそのまま足し、
    // 「2件をゴミ箱へ移動しました」と1件のゴミ箱について言っていた）。
    Future<void> trashAgainFromMenu(WidgetTester tester, String name) async {
      final service = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      await tester.tap(card(name), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text(l10nOf(tester).projectDetailTrashMenuItem));
      await waitFor(tester, () => service.trash.any((p) => p.name == name));
      // 前の知らせが薄くなって下がり、新しい知らせが出切るまで。
      await settle(tester);
      await settle(tester);
    }

    for (final (label, change)
        in <(String, Future<void> Function(ProjectService, String))>[
          (
            'restored from the Trash tab',
            (service, id) => service.restoreProject(id),
          ),
          ('deleted for good', (service, id) => service.permanentDelete(id)),
        ]) {
      testWidgets('the earlier work was $label: the next notice counts only '
          'what is in the Trash', (tester) async {
        final service = await openHome(
          tester,
          names: ['apple', 'banana', 'cherry'],
        );
        final l10n = l10nOf(tester);
        final apple = service.projects.firstWhere((p) => p.name == 'apple');
        await trashFromMenu(tester, 'apple');
        await tester.runAsync(() => change(service, apple.id));
        await settleIo(tester);
        expect(service.trash, isEmpty);
        await trashAgainFromMenu(tester, 'banana');
        expect(service.trash.map((p) => p.name), ['banana']);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(snackText(tester), l10n.homeMovedToTrashSnackbar(1));
        await tester.tap(find.text(l10n.homeUndoAction));
        await waitFor(tester, () => service.trash.isEmpty);
        await settleIo(tester);
        expect(
          service.projects.map((p) => p.name).toSet(),
          label == 'deleted for good'
              ? {'banana', 'cherry'}
              : {'apple', 'banana', 'cherry'},
        );
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    testWidgets('a work restored from the Trash tab and moved again is '
        'counted once, and Undo brings it back', (tester) async {
      final service = await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      final apple = service.projects.firstWhere((p) => p.name == 'apple');
      await trashFromMenu(tester, 'apple');
      await tester.runAsync(() => service.restoreProject(apple.id));
      await settleIo(tester);
      await trashAgainFromMenu(tester, 'apple');
      expect(service.trash.map((p) => p.name), ['apple']);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(snackText(tester), l10n.homeMovedToTrashSnackbar(1));
      await tester.tap(find.text(l10n.homeUndoAction));
      await waitFor(tester, () => service.trash.isEmpty);
      await settleIo(tester);
      expect(service.projects.map((p) => p.name).toSet(), {'apple', 'banana'});
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // フォルダも同じ：戻してまた移したときは、そのフォルダの知らせ
    // （「フォルダ「scenes」をゴミ箱へ移動しました」）。
    testWidgets('a folder restored from the Trash tab and moved again is '
        'named once', (tester) async {
      final service = await openHome(tester, names: ['apple']);
      final l10n = l10nOf(tester);
      final folder = (await tester.runAsync(
        () => service.createFolder('scenes'),
      ))!;
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(HomeScreen)),
      );
      await tester.runAsync(() => service.moveFolderToTrash(folder.id));
      showFolderMovedToTrashSnackBar(messenger, l10n, service, folder);
      await waitFor(
        tester,
        () =>
            snackText(tester) == l10n.homeFolderMovedToTrashSnackbar('scenes'),
      );
      await tester.runAsync(() => service.restoreTrashedFolder(folder.id));
      await settleIo(tester);
      await tester.runAsync(() => service.moveFolderToTrash(folder.id));
      showFolderMovedToTrashSnackBar(messenger, l10n, service, folder);
      await settle(tester);
      await settle(tester);
      expect(service.trashedFolders.map((t) => t.folder.name), ['scenes']);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(snackText(tester), l10n.homeFolderMovedToTrashSnackbar('scenes'));
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // ほかの機能の知らせが出ていて、その後ろでもう1つ待っているときに
    // ゴミ箱へ移しても、出ている知らせを途中で閉じず、待っている知らせも
    // 下げない。ゴミ箱の知らせはその後ろに出る。
    testWidgets('leaves another feature\'s shown and waiting notices', (
      tester,
    ) async {
      await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
        ..showSnackBar(const SnackBar(content: Text('first notice')))
        ..showSnackBar(const SnackBar(content: Text('waiting notice')));
      await settle(tester);
      expect(snackText(tester), 'first notice');
      await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text(l10n.projectDetailTrashMenuItem));
      await settleIo(tester);
      const frame = Duration(milliseconds: 16);
      final seen = <String?>[];
      var elapsed = Duration.zero;
      var firstShownFor = Duration.zero;
      while (elapsed < const Duration(seconds: 16) &&
          (seen.isEmpty || find.byType(SnackBar).evaluate().isNotEmpty)) {
        await tester.pump(frame);
        elapsed += frame;
        final text = snackText(tester);
        if (text == 'first notice') firstShownFor += frame;
        if (seen.isEmpty || seen.last != text) seen.add(text);
      }
      debugPrint(
        'notices in order $seen; first notice ${firstShownFor.inMilliseconds} ms more',
      );
      expect(seen, [
        'first notice',
        'waiting notice',
        l10n.homeMovedToTrashSnackbar(1),
        null,
      ]);
      expect(
        firstShownFor,
        greaterThan(const Duration(seconds: 2)),
        reason: 'the trash move closed the notice that was on screen',
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // お気に入りを含む選択をゴミ箱へ移そうとして断られても、出ている
    // ゴミ箱の知らせの「元に戻す」は消さない（断りの知らせは後ろに並ぶ）。
    testWidgets('a refused bulk move keeps the earlier Undo', (tester) async {
      final service = await openHome(
        tester,
        names: ['apple', 'banana', 'cherry'],
      );
      final l10n = l10nOf(tester);
      final banana = service.projects.firstWhere((p) => p.name == 'banana');
      await tester.runAsync(() => service.setFavorite(banana.id, true));
      await settleIo(tester);
      await trashFromMenu(tester, 'apple');
      final moved = l10n.homeMovedToTrashSnackbar(1);
      await tester.longPress(card('banana'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await settle(tester);
      expect(snackText(tester), moved);
      expect(find.text(l10n.homeUndoAction), findsOneWidget);
      await tester.tap(find.text(l10n.homeUndoAction));
      await waitFor(tester, () => service.trash.isEmpty);
      expect(service.projects.length, 3);
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

    // 切り取りの知らせの後ろで別の知らせが待っているときに「元に戻す」で
    // 切り取りをやめても、待っている知らせは消さずに出す。読み上げ（TalkBack）
    // を使っていると、閉じた知らせはすぐ取り除かれ次の知らせが出るので、
    // 切り取りの知らせを二度閉じると、待っていた知らせまで出ないまま消えた。
    for (final talkBack in [false, true]) {
      testWidgets('Undo on the cut notice leaves a waiting notice '
          '(TalkBack ${talkBack ? 'on' : 'off'})', (tester) async {
        if (talkBack) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(accessibleNavigation: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await openHome(tester, names: ['apple', 'banana']);
        await cut(tester, 'apple');
        ScaffoldMessenger.of(
          tester.element(find.byType(HomeScreen)),
        ).showSnackBar(const SnackBar(content: Text('waiting notice')));
        await settle(tester);
        expect(snackText(tester), l10nOf(tester).homeCutSnackbar(1));
        await tester.tap(find.text(l10nOf(tester).homeUndoAction));
        await settle(tester);
        expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
        expect(snackText(tester), 'waiting notice');
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

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

    // 他の知らせが出ていて、その後ろでもう1つ待っているときに切り取ると、
    // 切り取りの知らせはその後ろに並ぶ（出ている・待っている他の機能の
    // 知らせを消さない。以前は待っている知らせを黙って下げていた、DISC092）。
    // Escで切り取りをやめると、順番を待っている切り取りの知らせだけを
    // 印で下げ、出ている知らせ・待っている知らせは閉じない。1フレーム
    // （16ms）ずつ描いて、出た知らせの順と時間を見る。
    testWidgets('a cut made while other notices are waiting queues its notice '
        'behind them, and Esc withdraws only it', (tester) async {
      await openHome(tester, names: ['apple', 'banana']);
      final l10n = l10nOf(tester);
      final cutText = l10n.homeCutSnackbar(1);
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
        ..showSnackBar(const SnackBar(content: Text('first notice')))
        ..showSnackBar(const SnackBar(content: Text('waiting notice')));
      await settle(tester);
      expect(snackText(tester), 'first notice');
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.commonCut));
      const frame = Duration(milliseconds: 16);
      final seen = <String?>[];
      void note() {
        final text = snackText(tester);
        if (seen.isEmpty || seen.last != text) seen.add(text);
      }

      var sinceCut = Duration.zero;
      Duration? cutShownAt;
      // 切り取ってから600ms後にEscで切り取りをやめる（切り取りの知らせは
      // まだ順番を待っている）。
      while (sinceCut < const Duration(milliseconds: 600)) {
        await tester.pump(frame);
        sinceCut += frame;
        note();
        if (snackText(tester) == cutText) cutShownAt ??= sinceCut;
      }
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      var sinceEsc = Duration.zero;
      while (find.byType(SnackBar).evaluate().isNotEmpty &&
          sinceEsc < const Duration(seconds: 12)) {
        await tester.pump(frame);
        sinceEsc += frame;
        note();
      }
      debugPrint(
        'notices in order $seen; the cut notice appeared '
        '${cutShownAt?.inMilliseconds} ms after the cut; all notices were '
        'gone ${sinceEsc.inMilliseconds} ms after Esc',
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('homeCrossTabPasteButton')), findsNothing);
      expect(seen, ['first notice', 'waiting notice', null]);
      expect(
        cutShownAt,
        isNull,
        reason: 'the cut notice was shown after the cut was cancelled',
      );
      // 出ていた知らせと待っていた知らせは、それぞれ5秒以内に消える。
      expect(
        sinceEsc,
        lessThanOrEqualTo(kToastMaxLifetime * 2),
        reason: 'the other notices stayed too long',
      );
      await close(tester);
    });
  });

  // 貼り付けボタンの横の「クリア」でクリップボードを空にすると、それを
  // 伝えていたコピー・切り取りの知らせ（「…貼り付けを押してください」）は
  // 閉じる。閉じるのはその知らせだけで、出ている・待っている他の知らせ
  // （ゴミ箱へ移した知らせとその「元に戻す」等）は閉じない。
  group('clearing the clipboard', () {
    final clearButton = find.byKey(const Key('homeClearClipboardButton'));

    void setTalkBack(WidgetTester tester, bool on) {
      if (!on) return;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    Future<void> copy(WidgetTester tester, String name) async {
      await tester.longPress(card(name));
      await settle(tester);
      await tester.tap(find.byTooltip(l10nOf(tester).commonCopy));
      await settle(tester);
      expect(clearButton, findsOneWidget);
    }

    for (final isCut in [false, true]) {
      final kind = isCut ? 'cut' : 'copy';

      testWidgets('Clear closes the $kind notice it made obsolete', (
        tester,
      ) async {
        await openHome(tester, names: ['apple', 'banana']);
        if (isCut) {
          await cut(tester, 'apple');
        } else {
          await copy(tester, 'apple');
          expect(snackText(tester), l10nOf(tester).homeCopiedSnackbar(1));
        }
        await tester.tap(clearButton);
        await settle(tester);
        expect(clearButton, findsNothing);
        expect(
          find.byType(SnackBar),
          findsNothing,
          reason: 'the notice still tells the user to press Paste',
        );
        expect(tester.takeException(), isNull);
        await close(tester);
      });

      testWidgets('Clear after a $kind leaves a later notice and its Undo', (
        tester,
      ) async {
        final service = await openHome(tester, names: ['apple', 'banana']);
        if (isCut) {
          await cut(tester, 'apple');
        } else {
          await copy(tester, 'apple');
        }
        await trashFromMenu(tester, 'banana');
        final moved = l10nOf(tester).homeMovedToTrashSnackbar(1);
        expect(snackText(tester), moved);
        await tester.tap(clearButton);
        await settle(tester);
        expect(clearButton, findsNothing);
        expect(snackText(tester), moved);
        await tester.tap(find.text(l10nOf(tester).homeUndoAction));
        await waitFor(tester, () => service.projects.length == 2);
        expect(service.trash, isEmpty);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    // 出てくる途中で空にしても、出終わった所で閉じる（4秒残らない）。
    testWidgets('Clear while the copy notice is still coming in closes it', (
      tester,
    ) async {
      await openHome(tester, names: ['apple', 'banana']);
      await tester.longPress(card('apple'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10nOf(tester).commonCopy));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(clearButton);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(clearButton, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    // コピーの知らせは、出ている・待っている他の知らせの後ろで順番を待つ
    // （他の機能の知らせを消さない、DISC092）。そこで空にしても、出ている
    // 知らせ・待っている知らせは閉じない。順番を待っていたコピーの知らせは、
    // 空のクリップボードを伝えたまま残らない。
    for (final talkBack in [false, true]) {
      testWidgets('Clear while the copy notice waits leaves the shown notice '
          '(TalkBack ${talkBack ? 'on' : 'off'})', (tester) async {
        setTalkBack(tester, talkBack);
        await openHome(tester, names: ['apple', 'banana']);
        final copied = l10nOf(tester).homeCopiedSnackbar(1);
        ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
          ..showSnackBar(const SnackBar(content: Text('first notice')))
          ..showSnackBar(const SnackBar(content: Text('waiting notice')));
        await settle(tester);
        expect(snackText(tester), 'first notice');
        await copy(tester, 'apple');
        expect(snackText(tester), 'first notice');
        await tester.tap(clearButton);
        await settle(tester);
        expect(clearButton, findsNothing);
        expect(snackText(tester), 'first notice');
        // 出ていた知らせと待っていた知らせが時間で閉じた後、コピーの知らせは
        // 出てもすぐ閉じる（自分の4秒は残らない）。出てくる（250ms）のと薄く
        // なって消える（400ms）のは見える：100msのフレームで8回まで。
        var copiedFrames = 0;
        var waitingShown = false;
        for (var i = 0; i < 110; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (snackText(tester) == copied) copiedFrames++;
          if (snackText(tester) == 'waiting notice') waitingShown = true;
        }
        expect(waitingShown, isTrue, reason: 'the waiting notice was dropped');
        final enterAndFade = (kToastEntrance + kToastFadeOut).inMilliseconds;
        debugPrint('the copy notice was on screen for $copiedFrames frames');
        expect(find.byType(SnackBar), findsNothing);
        expect(
          copiedFrames,
          lessThanOrEqualTo((enterAndFade / 100).ceil() + 2),
          reason: 'the copy notice stayed after the clipboard was cleared',
        );
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    // 貼り付けた結果の知らせは、クリップボードの中身を伝えるものではないので、
    // 空にしても閉じない。
    testWidgets('Clear after pasting a copy leaves the paste notice', (
      tester,
    ) async {
      final service = await openHome(tester, names: ['apple', 'banana']);
      await copy(tester, 'apple');
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      final pasted = l10nOf(tester).homePastedSnackbar(1);
      await waitFor(tester, () => snackText(tester) == pasted);
      await settle(tester);
      expect(service.projects.length, 3);
      await tester.tap(clearButton);
      await settle(tester);
      expect(clearButton, findsNothing);
      expect(snackText(tester), pasted);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  });
}
