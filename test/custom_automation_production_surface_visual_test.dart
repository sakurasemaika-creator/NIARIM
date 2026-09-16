import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/custom_automation_executor.dart';
import 'package:niarim/engine/custom_automation_filter_runner.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/custom-automation-production');
  final appDocs = Directory('${Directory.systemTemp.path}/niarim_custom_automation_surface_docs');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    out.createSync(recursive: true);
    appDocs.createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async => appDocs.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('record start canvas change stop edit save replay changes PNG pixels', (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    await harness.createProject('record-edit-replay-source');
    final automation = harness.automationService;
    await harness.captureCanvas('01_canvas_before_recording');
    automation.beginDraft(name: 'record-edit-replay-proof', surface: CustomAutomationSurface.canvas, recordingStartFrame: harness.frameIndex);
    harness.filterService.selectFilter('Filter0019');
    final filter = harness.filterService.currentFilter!;
    final beforeFirstApply = harness.activeLayerPixels();
    await tester.runAsync(() => CustomAutomationFilterRunner.apply(projectService: harness.projectService, projectId: harness.projectId, sceneId: harness.sceneId, frameIndex: harness.frameIndex, sourceLayerId: harness.layerId, filter: filter));
    automation.recordStep(surface: CustomAutomationSurface.canvas, command: 'canvas.filterApply', label: filter.name, args: {'filter': filter.toJson()}, recordedFrame: harness.frameIndex);
    final firstChanged = _changedBytes(beforeFirstApply, harness.activeLayerPixels());
    expect(firstChanged, greaterThan(100));
    await harness.captureCanvas('02_canvas_after_first_recorded_change');
    final beforeSecondApply = harness.activeLayerPixels();
    await tester.runAsync(() => CustomAutomationFilterRunner.apply(projectService: harness.projectService, projectId: harness.projectId, sceneId: harness.sceneId, frameIndex: harness.frameIndex, sourceLayerId: harness.layerId, filter: filter));
    automation.recordStep(surface: CustomAutomationSurface.canvas, command: 'canvas.filterApply', label: filter.name, args: {'filter': filter.toJson()}, recordedFrame: harness.frameIndex);
    final secondChanged = _changedBytes(beforeSecondApply, harness.activeLayerPixels());
    expect(secondChanged, greaterThan(100));
    await harness.captureCanvas('03_canvas_after_second_recorded_change');
    automation.stopRecording();
    automation.removeDraftStep(1);
    final saved = await tester.runAsync(() => automation.saveDraft());
    expect(saved, isNotNull);
    await harness.createProject('record-edit-replay-fresh-target');
    final beforeReplay = harness.activeLayerPixels();
    await harness.captureCanvas('04_canvas_before_saved_replay');
    await tester.runAsync(() => harness.execute(saved!, CustomAutomationExecutionScope.currentFrame, null));
    final replayChanged = _changedBytes(beforeReplay, harness.activeLayerPixels());
    expect(replayChanged, greaterThan(100));
    await harness.captureCanvas('05_canvas_after_saved_replay');
    File('${out.path}/pixel-proof.txt').writeAsStringSync('first_recorded_changed_bytes=$firstChanged\nsecond_recorded_changed_bytes=$secondChanged\nreplay_changed_bytes=$replayChanged\n');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('all current built-in automation presets produce actual PNG output', (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    final cases = <(String, String)>[
      ('デジタル線画作成', 'digital_lineart'),
      ('アナログ線画作成', 'analog_lineart'),
    ];
    expect(harness.automationService.items.map((item) => item.name).toSet(), containsAll(cases.map((entry) => entry.$1)));

    for (final entry in cases) {
      await harness.createProject('builtin-${entry.$2}');
      final beforeLayers = harness.normalLayerIds();
      final beforeComposite = await harness.compositePixels();
      final preset = harness.automationService.items.where((item) => item.name == entry.$1).single;
      await harness.captureComposite('preset_${entry.$2}_before');
      await tester.runAsync(() => harness.execute(preset, CustomAutomationExecutionScope.currentFrame, null));
      final afterLayers = harness.normalLayerIds();
      final generated = afterLayers.difference(beforeLayers);
      var generatedVisiblePixels = 0;
      for (final id in generated) {
        final pixels = harness.layerPixels(id);
        for (var i = 3; i < pixels.length; i += 4) {
          if (pixels[i] != 0) {
            generatedVisiblePixels++;
          }
        }
      }
      final afterComposite = await harness.compositePixels();
      final compositeChanged = _changedBytes(beforeComposite, afterComposite);
      if (entry.$1 == 'デジタル線画作成') {
        expect(generated, isNotEmpty, reason: '${entry.$1} must create generated output layers');
        expect(generatedVisiblePixels, greaterThan(50), reason: '${entry.$1} generated layers must contain visible pixels');
      } else {
        expect(_changedBytes(harness.initialLayerPixels, harness.activeLayerPixels()), greaterThan(100), reason: '${entry.$1} must transform the source layer');
      }
      expect(compositeChanged, greaterThan(100), reason: '${entry.$1} must visibly change the composited canvas');
      await harness.captureComposite('preset_${entry.$2}_after');
    }
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

class _SurfaceHarness {
  final WidgetTester tester;
  final Directory out;
  late final ProjectService projectService;
  late final CustomAutomationService automationService;
  late final FilterService filterService;
  String projectId = '';
  String sceneId = '';
  String layerId = '';
  int frameIndex = 0;
  Uint8List initialLayerPixels = Uint8List(0);

  _SurfaceHarness(this.tester, this.out);

  static Future<_SurfaceHarness> create(WidgetTester tester, Directory out) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(MultiProvider(providers: providers!, child: Builder(builder: (context) => MaterialApp(theme: context.watch<ThemeService>().themeData, locale: const Locale('ja'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: const Scaffold()))));
    await tester.pump();
    final harness = _SurfaceHarness(tester, out);
    final context = tester.element(find.byType(Scaffold));
    harness.projectService = context.read<ProjectService>();
    harness.automationService = context.read<CustomAutomationService>();
    harness.filterService = context.read<FilterService>();
    return harness;
  }

  Future<void> createProject(String name) async {
    final project = (await tester.runAsync(() => projectService.createProject(name: name, fps: 24, durationSeconds: 1, backgroundColor: 0xFFFFFFFF, exportWidth: 320, exportHeight: 320)))!;
    projectId = project.id;
    sceneId = projectService.scenesOf(project.id).first.id;
    frameIndex = 0;
    layerId = projectService.layersOf(projectId, sceneId, frameIndex).firstWhere((layer) => layer.type == model.LayerType.normal).id;
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, layerId);
    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final tile = tm.getOrCreateTile(key, tx, ty);
        tile.fillRange(0, tile.length, 0);
        for (var localY = 0; localY < 256; localY++) {
          final y = ty * 256 + localY;
          if (y >= tm.canvasHeight) continue;
          for (var localX = 0; localX < 256; localX++) {
            final x = tx * 256 + localX;
            if (x >= tm.canvasWidth || x < 36 || x >= 284 || y < 36 || y >= 284) continue;
            final i = (localY * 256 + localX) * 4;
            var shade = 20 + ((x - 36) * 225 ~/ 247);
            if ((x > 92 && x < 118) || (y > 148 && y < 174)) shade = 18;
            if (x > 188 && x < 242 && y > 78 && y < 132) shade = 235;
            tile[i] = shade;
            tile[i + 1] = shade;
            tile[i + 2] = shade;
            tile[i + 3] = 255;
          }
        }
        tm.invalidateTile(key, tx, ty);
      }
    }
    initialLayerPixels = activeLayerPixels();
  }

  Set<String> normalLayerIds() => projectService.layersOf(projectId, sceneId, frameIndex).where((layer) => layer.type == model.LayerType.normal).map((layer) => layer.id).toSet();
  Uint8List activeLayerPixels() => layerPixels(layerId);
  Uint8List layerPixels(String id) {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, id);
    const tileBytes = 256 * 256 * 4;
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

  Future<Uint8List> compositePixels() async {
    final image = await projectService.tileManagerOf(projectId).compositeLayerToImage(projectService.tileKeyFor(projectId, sceneId, frameIndex, layerId));
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> captureComposite(String name) async {
    final image = await projectService.tileManagerOf(projectId).compositeLayerToImage(projectService.tileKeyFor(projectId, sceneId, frameIndex, layerId));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('${out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }

  Future<void> captureCanvas(String name) => captureComposite(name);

  Future<void> execute(CustomAutomation automation, CustomAutomationExecutionScope scope, List<int>? targetFrames) async {
    await CustomAutomationExecutor.executeCanvas(automation: automation, scope: scope, projectService: projectService, projectId: projectId, sceneId: sceneId, currentFrame: frameIndex, currentLayerId: layerId, handleCanvasStateCommand: (_, _) async {});
  }
}

int _changedBytes(Uint8List before, Uint8List after) {
  expect(after.length, before.length);
  var changed = 0;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) changed++;
  }
  return changed;
}