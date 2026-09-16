import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/custom_automation_executor.dart';
import 'package:niarim/engine/custom_automation_filter_runner.dart';
import 'package:niarim/engine/layer_compositor.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, (_) async => appDocs.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('record start canvas change stop edit save replay changes PNG pixels', (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    await harness.createProject('record-edit-replay-source');
    final automation = harness.automationService;
    await harness.captureCanvas('01_canvas_before_recording');
    automation.beginDraft(name: 'record-edit-replay-proof', surface: CustomAutomationSurface.canvas, recordingStartFrame: harness.frameIndex);
    harness.filterService.selectFilter('Filter0014');
    final filter = harness.filterService.currentFilter!;
    final beforeFirstApply = harness.activeLayerPixels();
    await tester.runAsync(() => CustomAutomationFilterRunner.apply(projectService: harness.projectService, projectId: harness.projectId, sceneId: harness.sceneId, frameIndex: harness.frameIndex, sourceLayerId: harness.layerId, filter: filter));
    automation.recordStep(surface: CustomAutomationSurface.canvas, command: 'canvas.filterApply', label: filter.name, args: {'filter': filter.toJson()}, recordedFrame: harness.frameIndex);
    final firstChanged = _changedBytes(beforeFirstApply, harness.activeLayerPixels());
    expect(firstChanged, greaterThan(100));
    await harness.captureCanvas('02_canvas_after_first_recorded_change');
    automation.stopRecording();
    final saved = await tester.runAsync(() => automation.saveDraft());
    expect(saved, isNotNull);
    await harness.createProject('record-edit-replay-fresh-target');
    final beforeReplay = harness.activeLayerPixels();
    await harness.captureCanvas('03_canvas_before_saved_replay');
    await tester.runAsync(() => harness.execute(saved!, CustomAutomationExecutionScope.currentFrame));
    final replayChanged = _changedBytes(beforeReplay, harness.activeLayerPixels());
    expect(replayChanged, greaterThan(100));
    await harness.captureCanvas('04_canvas_after_saved_replay');
    File('${out.path}/pixel-proof.txt').writeAsStringSync('first_recorded_changed_bytes=$firstChanged\nreplay_changed_bytes=$replayChanged\n');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('all current built-in automation presets produce actual PNG output', (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    final cases = <(String, String)>[
      ('デジタル線画作成', 'digital_lineart'),
      ('アナログ線画作成', 'analog_lineart'),
    ];
    expect(harness.automationService.items.map((item) => item.name).toSet(), containsAll(cases.map((entry) => entry.$1)));

    for (final entry in cases) {
      await harness.createProject('builtin-${entry.$2}', transparentRough: entry.$1 == 'デジタル線画作成');
      final beforeLayers = harness.normalLayerIds();
      final beforeComposite = await harness.compositePixels();
      final beforeSource = harness.activeLayerPixels();
      final preset = harness.automationService.items.where((item) => item.name == entry.$1).single;
      await harness.captureComposite('preset_${entry.$2}_before');
      await tester.runAsync(() => harness.execute(preset, CustomAutomationExecutionScope.currentFrame));
      final afterLayers = harness.normalLayerIds();
      final generated = afterLayers.difference(beforeLayers);
      var generatedVisiblePixels = 0;
      for (final id in generated) {
        final pixels = harness.layerPixels(id);
        for (var i = 3; i < pixels.length; i += 4) {
          if (pixels[i] != 0) generatedVisiblePixels++;
        }
      }
      final afterComposite = await harness.compositePixels();
      final compositeChanged = _changedBytes(beforeComposite, afterComposite);
      if (entry.$1 == 'デジタル線画作成') {
        expect(generated, isNotEmpty, reason: '${entry.$1} must create generated output layers');
        expect(generatedVisiblePixels, greaterThan(20), reason: '${entry.$1} generated layers must contain visible pixels');
      } else {
        expect(_changedBytes(beforeSource, harness.activeLayerPixels()), greaterThan(100), reason: '${entry.$1} must transform the source layer including brightness-to-alpha');
      }
      expect(compositeChanged, greaterThan(100), reason: '${entry.$1} must visibly change the composited canvas');
      await harness.captureComposite('preset_${entry.$2}_after');
    }
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
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

  Future<void> createProject(String name, {bool transparentRough = false}) async {
    const size = 96;
    final project = (await tester.runAsync(() => projectService.createProject(name: name, fps: 24, durationSeconds: 1, backgroundColor: 0xFFFFFFFF, exportWidth: size, exportHeight: size)))!;
    projectId = project.id;
    sceneId = projectService.scenesOf(project.id).first.id;
    frameIndex = 0;
    layerId = projectService.layersOf(projectId, sceneId, frameIndex).firstWhere((layer) => layer.type == model.LayerType.normal).id;
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, layerId);
    final tile = tm.getOrCreateTile(key, 0, 0);
    tile.fillRange(0, tile.length, 0);
    if (transparentRough) {
      void paintDisc(int cx, int cy, int radius) {
        for (var y = cy - radius; y <= cy + radius; y++) {
          if (y < 0 || y >= size) continue;
          for (var x = cx - radius; x <= cx + radius; x++) {
            if (x < 0 || x >= size) continue;
            final dx = x - cx;
            final dy = y - cy;
            if (dx * dx + dy * dy > radius * radius) continue;
            final i = (y * 256 + x) * 4;
            tile[i] = 24;
            tile[i + 1] = 24;
            tile[i + 2] = 24;
            tile[i + 3] = 255;
          }
        }
      }
      void paintStroke(int x0, int y0, int x1, int y1, int radius) {
        final steps = (x1 - x0).abs() + (y1 - y0).abs();
        for (var step = 0; step <= steps; step++) {
          final t = steps == 0 ? 0.0 : step / steps;
          paintDisc((x0 + (x1 - x0) * t).round(), (y0 + (y1 - y0) * t).round(), radius);
        }
      }
      paintStroke(14, 20, 78, 72, 4);
      paintStroke(18, 70, 76, 26, 4);
      paintStroke(46, 14, 46, 82, 3);
    } else {
      for (var y = 8; y < size - 8; y++) {
        for (var x = 8; x < size - 8; x++) {
          final i = (y * 256 + x) * 4;
          var shade = 20 + ((x - 8) * 225 ~/ (size - 17));
          if ((x > 26 && x < 36) || (y > 45 && y < 55)) shade = 18;
          if (x > 58 && x < 78 && y > 22 && y < 42) shade = 235;
          tile[i] = shade;
          tile[i + 1] = shade;
          tile[i + 2] = shade;
          tile[i + 3] = 255;
        }
      }
    }
    tm.invalidateTile(key, 0, 0);
  }

  Set<String> normalLayerIds() => projectService.layersOf(projectId, sceneId, frameIndex).where((layer) => layer.type == model.LayerType.normal).map((layer) => layer.id).toSet();
  Uint8List activeLayerPixels() => layerPixels(layerId);
  Uint8List layerPixels(String id) {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, id);
    final snapshot = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
    for (var y = 0; y < tm.canvasHeight; y++) {
      for (var x = 0; x < tm.canvasWidth; x++) {
        final tile = tm.getTile(key, x ~/ 256, y ~/ 256);
        if (tile == null) continue;
        final src = ((y % 256) * 256 + (x % 256)) * 4;
        final dst = (y * tm.canvasWidth + x) * 4;
        snapshot.setRange(dst, dst + 4, tile, src);
      }
    }
    return snapshot;
  }

  Future<ui.Image> _compositeImage() {
    final tm = projectService.tileManagerOf(projectId);
    final layers = projectService.layersOf(projectId, sceneId, frameIndex);
    return LayerCompositor.composite(tm, layers, (layer) => projectService.tileKeyFor(projectId, sceneId, frameIndex, layer.id), tm.canvasWidth, tm.canvasHeight);
  }

  Future<Uint8List> compositePixels() async {
    return (await tester.runAsync(() async {
      final image = await _compositeImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
  }

  Future<void> captureComposite(String name) async {
    final bytes = await tester.runAsync(() async {
      final image = await _compositeImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    File('${out.path}/$name.png').writeAsBytesSync(bytes!);
  }

  Future<void> captureCanvas(String name) => captureComposite(name);

  Future<void> execute(CustomAutomation automation, CustomAutomationExecutionScope scope) async {
    await CustomAutomationExecutor.executeCanvas(automation: automation, scope: scope, projectService: projectService, projectId: projectId, sceneId: sceneId, currentFrame: frameIndex, currentLayerId: layerId, handleCanvasStateCommand: (command, args) async {
      if (command == 'canvas.brightnessToAlpha') {
        await projectService.tileManagerOf(projectId).applyBrightnessToAlpha(projectService.tileKeyFor(projectId, sceneId, frameIndex, layerId), grayMode: args['grayMode'] != false);
      }
    });
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
