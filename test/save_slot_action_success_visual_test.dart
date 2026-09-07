import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 確認ダイアログを開くだけでなく、保存・上書き・復元・削除の確定操作まで
/// 実データで完走させ、成功後の画面を SP / PC でキャプチャする。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('セーブスロットの確定操作をSP/PCで実データ完走する', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('niarim_save_slot_e2e_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final boundaryKey = GlobalKey();
    Future<void> settle({int rounds = 8}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 45)),
        );
        await tester.pump();
      }
    }

    Future<void> waitForDialogToClose() async {
      for (var i = 0; i < 50 && find.byType(AlertDialog).evaluate().isNotEmpty; i++) {
        await settle(rounds: 1);
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    }

    Future<void> setViewport(Size physicalSize, double dpr) async {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = dpr;
      await tester.pump();
      await settle(rounds: 2);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> capture(String name) async {
      await settle(rounds: 3);
      expect(tester.takeException(), isNull);
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final out = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(() => File('${out.path}/$name.png').writeAsBytes(bytes!));
    }

    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settle();

    final context = tester.element(find.byType(MaterialApp).first);
    final projectService = context.read<ProjectService>();
    final saveService = context.read<SaveTreeService>();
    expect(saveService.isTreeMode, isFalse);
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    final seedThumbnail = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    Finder buttons(String tooltip) => find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == tooltip,
    );

    Future<void> audit({
      required String prefix,
      required Size physicalSize,
      required double dpr,
    }) async {
      await setViewport(physicalSize, dpr);
      final project = (await tester.runAsync(
        () => projectService.createProject(
          name: 'save-slot-e2e-$prefix',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 180,
        ),
      ))!;
      const originalComment = '復元元データ';
      final original = (await tester.runAsync(
        () => saveService.saveToSlot(
          projectId: project.id,
          slotIndex: 0,
          project: project,
          scenes: projectService.scenesOf(project.id),
          tileManager: projectService.tileManagerOf(project.id),
          comment: originalComment,
          thumbnailPngBytes: seedThumbnail,
        ),
      ))!;

      appRouter.go('/save-tree/${project.id}?entry=projectDetail');
      await settle();

      // 1) 空スロットへの保存をUIから確定する。
      var writes = buttons(l10n.saveTreeSlotWriteTooltip);
      await tester.tap(writes.at(1));
      await settle();
      final emptyField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(emptyField, findsOneWidget);
      await tester.enterText(emptyField, 'UI新規保存');
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
      await waitForDialogToClose();
      var nodes = saveService.getNodes(project.id);
      final newSlot = nodes.where((n) => n.slotIndex == 1).toList();
      expect(newSlot, hasLength(1));
      expect(newSlot.single.comment, 'UI新規保存');
      await capture('${prefix}_09_after_empty_slot_saved');

      // 2) 既存スロットをUIから上書き確定する。
      final oldId = original.id;
      writes = buttons(l10n.saveTreeSlotWriteTooltip);
      await tester.tap(writes.first);
      await settle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonOk));
      await settle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
      await waitForDialogToClose();
      nodes = saveService.getNodes(project.id);
      final overwritten = nodes.singleWhere((n) => n.slotIndex == 0);
      expect(overwritten.id, isNot(oldId));
      expect(overwritten.comment, originalComment);
      await capture('${prefix}_10_after_overwrite_saved');

      // 3) 実保存データから復元をUIで確定し、成功Snackbarまで確認する。
      var loads = buttons(l10n.saveTreeSlotLoadTooltip);
      await tester.tap(loads.first);
      await settle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.saveTreeResumeFromHereAction),
      );
      await settle(rounds: 12);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(l10n.saveTreeRestoredSnackbar(originalComment)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture('${prefix}_11_after_restore_success');

      // Snackbarが次の削除確認を覆わないよう閉じる。
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).hideCurrentSnackBar();
      await settle(rounds: 3);

      // 4) スロット2をUIから削除確定し、一覧から消えるところまで確認する。
      final deletes = buttons(l10n.saveTreeSlotDeleteTooltip);
      await tester.tap(deletes.at(1));
      await settle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
      await waitForDialogToClose();
      nodes = saveService.getNodes(project.id);
      expect(nodes.where((n) => n.slotIndex == 1), isEmpty);
      final currentLoads = buttons(l10n.saveTreeSlotLoadTooltip);
      expect(tester.widget<IconButton>(currentLoads.at(1)).onPressed, isNull);
      await capture('${prefix}_12_after_delete_success');
    }

    await audit(
      prefix: 'sp_360x760',
      physicalSize: const Size(1080, 2280),
      dpr: 3,
    );
    await audit(
      prefix: 'pc_1440x900',
      physicalSize: const Size(1440, 900),
      dpr: 1,
    );
  }, timeout: const Timeout(Duration(seconds: 240)));
}
