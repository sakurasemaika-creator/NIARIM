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
}
