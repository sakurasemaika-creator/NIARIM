import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/custom-automation');
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_custom_automation_audit_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const automationName = 'visual-audit-automation';

  setUpAll(() {
    out.createSync(recursive: true);
    appDocs.createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => appDocs.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'Canvas UI: start recording -> real filter -> stop -> edit -> save -> replay, with PNG evidence',
    (tester) async {
      tester.view.physicalSize = const Size(960, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);

      final providers = await tester.runAsync(buildAppProviders);
      ProjectService? ps;
      StateSetter? rebuildHost;
      String? projectId;
      final rootKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MultiProvider(
            providers: providers!,
            child: Builder(
              builder: (themeContext) => MaterialApp(
                theme: themeContext.watch<ThemeService>().themeData,
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: StatefulBuilder(
                  builder: (context, setState) {
                    ps ??= context.read<ProjectService>();
                    rebuildHost = setState;
                    if (projectId == null) return const SizedBox.expand();
                    return CanvasScreen(projectId: projectId);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final project = (await tester.runAsync(
        () => ps!.createProject(
          name: 'custom-automation-visual-audit',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 320,
        ),
      ))!;

      final seedScene = ps!.scenesOf(project.id).first;
      final seedLayer = seedScene.frames.first.layers
          .where((layer) => layer.type == model.LayerType.normal)
          .first;
      final tm = ps!.tileManagerOf(project.id);
      final seedKey = ps!.tileKeyFor(project.id, seedScene.id, 0, seedLayer.id);
      final tile = tm.getOrCreateTile(seedKey, 0, 0);
      for (var y = 40; y < 216; y++) {
        for (var x = 40; x < 216; x++) {
          final i = (y * TileManager.tileSize + x) * 4;
          final shade = 32 + ((x - 40) * 208 ~/ 175);
          tile[i] = shade;
          tile[i + 1] = shade;
          tile[i + 2] = shade;
          tile[i + 3] = 255;
        }
      }
      tm.invalidateTile(seedKey, 0, 0);
      await tester.runAsync(() async {
        final image = await tm.compositeLayerToImage(seedKey);
        image.dispose();
      });

      projectId = project.id;
      rebuildHost!(() {});
      await tester.pump(const Duration(milliseconds: 1400));

      void stage(String value) =>
          debugPrint('AUTOMATION_VISUAL_AUDIT_STAGE=$value');

      Future<void> capture(String name) async {
        stage('capture:$name:begin');
        await tester.pump(const Duration(milliseconds: 120));
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${out.path}/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
        stage('capture:$name:done');
      }

      CanvasArea canvasWidget() {
        final finder = find.byType(CanvasArea);
        expect(finder, findsOneWidget);
        return tester.widget<CanvasArea>(finder);
      }

      Uint8List activeLayerPixels() {
        final canvas = canvasWidget();
        final layerId = canvas.currentLayerId;
        expect(
          layerId,
          isNotNull,
          reason: 'Canvas must expose an active layer',
        );
        final key = ps!.tileKeyFor(
          project.id,
          canvas.sceneId,
          canvas.currentFrame,
          layerId!,
        );
        const tileBytes = TileManager.tileSize * TileManager.tileSize * 4;
        final snapshot = Uint8List(tm.tilesX * tm.tilesY * tileBytes);
        var offset = 0;
        for (var ty = 0; ty < tm.tilesY; ty++) {
          for (var tx = 0; tx < tm.tilesX; tx++) {
            final current = tm.getTile(key, tx, ty);
            if (current != null) {
              snapshot.setRange(offset, offset + tileBytes, current);
            }
            offset += tileBytes;
          }
        }
        return snapshot;
      }

      int changedBytes(Uint8List before, Uint8List after) {
        expect(after.length, before.length);
        var changed = 0;
        for (var i = 0; i < before.length; i++) {
          if (before[i] != after[i]) changed++;
        }
        return changed;
      }

      Future<void> prewarmActiveLayer() async {
        final canvas = canvasWidget();
        final layerId = canvas.currentLayerId;
        expect(layerId, isNotNull);
        final key = ps!.tileKeyFor(
          project.id,
          canvas.sceneId,
          canvas.currentFrame,
          layerId!,
        );
        await tester.runAsync(() async {
          final image = await tm.compositeLayerToImage(key);
          image.dispose();
        });
      }

      Future<void> letProductionAsyncWorkFinish() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1200)),
        );
      }

      Future<void> openCanvasSettings() async {
        stage('settings-helper:find');
        final settingsButton = find.byWidgetPredicate(
          (widget) =>
              widget is CanvasIconButton && widget.icon == Icons.settings,
          description: 'Canvas production settings button',
        );
        expect(settingsButton, findsOneWidget);
        stage('settings-helper:tap');
        await tester.tap(settingsButton);
        await tester.pump(const Duration(milliseconds: 350));
        stage('settings-helper:opened');
      }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CanvasScreen)),
      )!;
      await capture('00_canvas_before_recording');

      stage('settings:open');
      await openCanvasSettings();
      await capture('01_settings_open');

      final automationEntry = find.text(l10n.customAutomationTitle);
      expect(automationEntry, findsWidgets);
      await tester.ensureVisible(automationEntry.last);
      stage('manager:open');
      await tester.tap(automationEntry.last);
      await tester.pump(const Duration(milliseconds: 350));
      await capture('02_manager_open');

      final add = find.text(l10n.customAutomationAdd);
      expect(add, findsOneWidget);
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 250));
      final nameField = find.byType(TextField);
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, automationName);
      final start = find.text(l10n.customAutomationStartRecording);
      expect(start, findsOneWidget);
      stage('record:start');
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 350));
      await capture('03_recording_started');

      stage('filter:open-settings');
      await openCanvasSettings();
      final filterEntry = find.text(l10n.filterPanelTitle);
      expect(filterEntry, findsWidgets);
      await tester.ensureVisible(filterEntry.last);
      await tester.tap(filterEntry.last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FilterPanel), findsOneWidget);
      await letProductionAsyncWorkFinish();
      await capture('04_filter_panel_open_during_recording');

      final beforeRecordedAction = activeLayerPixels();
      final apply = find.text(l10n.filterApplyButton);
      expect(apply, findsOneWidget);
      stage('filter:apply-through-ui');
      await tester.tap(apply);
      await letProductionAsyncWorkFinish();
      final afterRecordedAction = activeLayerPixels();
      expect(
        changedBytes(beforeRecordedAction, afterRecordedAction),
        greaterThan(100),
        reason: 'Production FilterPanel Apply must change real Canvas RGBA',
      );
      await prewarmActiveLayer();
      await capture('05_real_filter_applied_and_recorded');

      final closeFilter = find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byIcon(Icons.close),
      );
      expect(closeFilter, findsOneWidget);
      await tester.tap(closeFilter);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(FilterPanel), findsNothing);

      final stop = find.text(l10n.customAutomationStopRecording);
      expect(stop, findsWidgets);
      stage('record:stop');
      await tester.ensureVisible(stop.last);
      await tester.tap(stop.last);
      await tester.pump(const Duration(milliseconds: 350));
      await capture('06_recording_stopped_draft');

      expect(find.byIcon(Icons.delete_outline), findsWidgets);
      expect(
        find.text('canvas.filterApply'),
        findsOneWidget,
        reason:
            'Draft must contain the replayable filter operation recorded by FilterPanel',
      );
      await capture('07_draft_edit');

      final save = find.text(l10n.commonSave);
      expect(save, findsWidgets);
      stage('draft:save');
      await tester.tap(save.last);
      await tester.pump(const Duration(milliseconds: 450));
      await capture('08_saved');

      final beforeReplay = activeLayerPixels();
      stage('replay:open-manager');
      await openCanvasSettings();
      final entryAgain = find.text(l10n.customAutomationTitle);
      await tester.ensureVisible(entryAgain.last);
      await tester.tap(entryAgain.last);
      await tester.pump(const Duration(milliseconds: 350));
      await capture('09_manager_saved_item');

      final savedItem = find.text(automationName);
      expect(savedItem, findsOneWidget);
      await tester.tap(savedItem);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.customAutomationRunConfirmTitle), findsOneWidget);
      final yes = find.text(l10n.customAutomationYes);
      expect(yes, findsOneWidget);
      stage('replay:confirm');
      await tester.tap(yes);
      await letProductionAsyncWorkFinish();
      final afterReplay = activeLayerPixels();
      expect(
        changedBytes(beforeReplay, afterReplay),
        greaterThan(100),
        reason: 'Saved automation replay must change real Canvas RGBA again',
      );
      await prewarmActiveLayer();
      await capture('10_reexecuted_real_canvas_pixels_changed');

      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
