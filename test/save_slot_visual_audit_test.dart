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

/// セーブスロット画面の主要操作を SP / PC の実レンダリングで通し、
/// build/save-slot-visual-audit/ へ目視監査用PNGを焼く。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('セーブスロット全主要操作をSP/PCで実キャプチャ監査する', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync(
      'niarim_save_slot_visual_',
    );
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final boundaryKey = GlobalKey();
    Future<void> settle({int rounds = 6}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 35)),
        );
        await tester.pump();
      }
    }

    Future<void> setViewport(Size physicalSize, double dpr) async {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = dpr;
      await tester.pump();
      await settle(rounds: 2);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Finder dialog() {
      final result = find.byType(AlertDialog);
      expect(result, findsOneWidget);
      return result;
    }

    void expectDialogContains(String text) {
      expect(
        find.descendant(of: dialog(), matching: find.text(text)),
        findsWidgets,
      );
    }

    void expectDialogFitsViewport() {
      final rect = tester.getRect(dialog());
      final logicalSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(logicalSize.width));
      expect(rect.bottom, lessThanOrEqualTo(logicalSize.height));
    }

    Future<void> capture(String name) async {
      await settle(rounds: 4);
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final out = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(
        () => File('${out.path}/$name.png').writeAsBytes(bytes!),
      );
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
    final project = (await tester.runAsync(
      () => projectService.createProject(
        name: 'save-slot-visual-audit',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;

    final thumbnailBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    const comment = '既存データ・サムネイル確認';
    final node = (await tester.runAsync(
      () => saveService.saveToSlot(
        projectId: project.id,
        slotIndex: 0,
        project: project,
        scenes: projectService.scenesOf(project.id),
        tileManager: projectService.tileManagerOf(project.id),
        comment: comment,
        thumbnailPngBytes: thumbnailBytes,
      ),
    ))!;
    expect(node.thumbnailPath, isNotNull);
    expect(File(node.thumbnailPath!).existsSync(), isTrue);

    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    Finder buttons(String tooltip) =>
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);

    Future<void> cancelDialog() async {
      final cancel = find.descendant(
        of: dialog(),
        matching: find.widgetWithText(TextButton, l10n.commonCancel),
      );
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await settle();
      expect(find.byType(AlertDialog), findsNothing);
    }

    Future<void> audit({
      required String prefix,
      required Size physicalSize,
      required double dpr,
    }) async {
      await setViewport(physicalSize, dpr);
      appRouter.go('/save-tree/${project.id}?entry=projectDetail');
      await settle();
      expect(tester.takeException(), isNull);

      final writes = buttons(l10n.saveTreeSlotWriteTooltip);
      final loads = buttons(l10n.saveTreeSlotLoadTooltip);
      final deletes = buttons(l10n.saveTreeSlotDeleteTooltip);
      expect(writes.evaluate().length, saveService.slotMax);
      expect(loads.evaluate().length, saveService.slotMax);
      expect(deletes.evaluate().length, saveService.slotMax);
      expect(tester.widget<IconButton>(loads.first).onPressed, isNotNull);
      expect(tester.widget<IconButton>(loads.at(1)).onPressed, isNull);
      expect(tester.widget<IconButton>(deletes.first).onPressed, isNotNull);
      expect(tester.widget<IconButton>(deletes.at(1)).onPressed, isNull);
      await capture('${prefix}_01_project_detail_list');

      await tester.tap(writes.at(1));
      await settle();
      expectDialogContains(l10n.saveTreeSlotSaveDialogTitle(2));
      expectDialogFitsViewport();
      await capture('${prefix}_02_empty_slot_save_dialog');
      await cancelDialog();

      await tester.tap(writes.first);
      await settle();
      expectDialogContains(l10n.saveTreeOverwriteAction);
      expectDialogContains(comment);
      expect(
        find.descendant(of: dialog(), matching: find.byType(Image)),
        findsOneWidget,
      );
      expectDialogFitsViewport();
      await capture('${prefix}_03_overwrite_confirmation');

      final ok = find.descendant(
        of: dialog(),
        matching: find.widgetWithText(FilledButton, l10n.commonOk),
      );
      expect(ok, findsOneWidget);
      await tester.tap(ok);
      await settle();
      expectDialogContains(l10n.saveTreeSlotSaveDialogTitle(1));
      final field = find.descendant(
        of: dialog(),
        matching: find.byType(TextField),
      );
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).controller?.text, comment);
      expectDialogFitsViewport();
      await capture('${prefix}_04_overwrite_save_dialog');
      await cancelDialog();

      await tester.tap(loads.first);
      await settle();
      expectDialogContains(l10n.saveTreeRestoreAction);
      expectDialogContains(l10n.saveTreeProjectDetailResumeBody);
      expectDialogContains(comment);
      expectDialogFitsViewport();
      await capture('${prefix}_05_project_detail_load_confirmation');
      await cancelDialog();

      await tester.tap(deletes.first);
      await settle();
      expectDialogContains(l10n.confirmDeleteNamedBody(comment));
      expect(
        find.descendant(
          of: dialog(),
          matching: find.widgetWithText(FilledButton, l10n.commonDelete),
        ),
        findsOneWidget,
      );
      expectDialogFitsViewport();
      await capture('${prefix}_06_delete_confirmation');
      await cancelDialog();

      appRouter.go('/save-tree/${project.id}?entry=quickSave');
      await settle();
      final quickLoads = buttons(l10n.saveTreeSlotLoadTooltip);
      expect(tester.widget<IconButton>(quickLoads.first).onPressed, isNull);
      await capture('${prefix}_07_quick_save_load_disabled');

      appRouter.go('/save-tree/${project.id}?entry=timeline');
      await settle();
      final timelineLoads = buttons(l10n.saveTreeSlotLoadTooltip);
      expect(
        tester.widget<IconButton>(timelineLoads.first).onPressed,
        isNotNull,
      );
      await tester.tap(timelineLoads.first);
      await settle();
      expectDialogContains(l10n.saveTreeRestoreAction);
      expectDialogContains(l10n.saveTreeResumeConfirmBody);
      expectDialogContains(comment);
      expectDialogFitsViewport();
      await capture('${prefix}_08_timeline_load_confirmation');
      await cancelDialog();
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
  }, timeout: const Timeout(Duration(seconds: 180)));
}
