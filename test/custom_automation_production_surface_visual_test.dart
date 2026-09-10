import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/custom_automation_executor.dart';
import 'package:niarim/engine/custom_automation_filter_runner.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/custom_automation_manager_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/custom-automation-production');
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_custom_automation_surface_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

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
          (_) async => appDocs.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'record start canvas change stop edit save replay changes PNG pixels',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('record-edit-replay-source');
      final automation = harness.automationService;

      await harness.captureCanvas('01_canvas_before_recording');

      automation.beginDraft(
        name: 'record-edit-replay-proof',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      expect(automation.isRecording, isTrue);
      expect(automation.draft, isNotNull);

      harness.filterService.selectFilter('Filter0019');
      final filter = harness.filterService.currentFilter!;

      final beforeFirstApply = harness.activeLayerPixels();
      await tester.runAsync(() async {
        await CustomAutomationFilterRunner.apply(
          projectService: harness.projectService,
          projectId: harness.projectId,
          sceneId: harness.sceneId,
          frameIndex: harness.frameIndex,
          sourceLayerId: harness.layerId,
          filter: filter,
        );
      });
      automation.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: filter.name,
        args: {'filter': filter.toJson()},
        recordedFrame: harness.frameIndex,
      );
      final afterFirstApply = harness.activeLayerPixels();
      final firstChanged = _changedBytes(beforeFirstApply, afterFirstApply);
      expect(firstChanged, greaterThan(100));
      expect(automation.draft!.steps, hasLength(1));
      await harness.captureCanvas('02_canvas_after_first_recorded_change');

      final beforeSecondApply = harness.activeLayerPixels();
      await tester.runAsync(() async {
        await CustomAutomationFilterRunner.apply(
          projectService: harness.projectService,
          projectId: harness.projectId,
          sceneId: harness.sceneId,
          frameIndex: harness.frameIndex,
          sourceLayerId: harness.layerId,
          filter: filter,
        );
      });
      automation.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: filter.name,
        args: {'filter': filter.toJson()},
        recordedFrame: harness.frameIndex,
      );
      final secondChanged = _changedBytes(
        beforeSecondApply,
        harness.activeLayerPixels(),
      );
      expect(secondChanged, greaterThan(100));
      expect(automation.draft!.steps, hasLength(2));
      await harness.captureCanvas('03_canvas_after_second_recorded_change');

      automation.stopRecording();
      expect(automation.isRecording, isFalse);
      expect(automation.draft!.steps, hasLength(2));

      automation.removeDraftStep(1);
      expect(automation.draft!.steps, hasLength(1));
      expect(automation.draft!.steps.single.command, 'canvas.filterApply');

      final saved = await tester.runAsync(() => automation.saveDraft());
      expect(saved, isNotNull);
      expect(saved!.steps, hasLength(1));
      expect(saved.steps.single.command, 'canvas.filterApply');
      expect(
        automation.items.any(
          (item) =>
              item.id == saved.id && item.name == 'record-edit-replay-proof',
        ),
        isTrue,
      );

      await harness.createProject('record-edit-replay-fresh-target');
      final beforeReplay = harness.activeLayerPixels();
      await harness.captureCanvas('04_canvas_before_saved_replay');

      await tester.runAsync(() async {
        await harness.execute(
          saved,
          CustomAutomationExecutionScope.currentFrame,
          null,
        );
      });
      final afterReplay = harness.activeLayerPixels();
      final replayChanged = _changedBytes(beforeReplay, afterReplay);
      expect(replayChanged, greaterThan(100));
      await harness.captureCanvas('05_canvas_after_saved_replay');

      File('${out.path}/pixel-proof.txt').writeAsStringSync(
        'recording_started=true\n'
        'first_recorded_changed_bytes=$firstChanged\n'
        'second_recorded_changed_bytes=$secondChanged\n'
        'recording_stopped=${!automation.isRecording}\n'
        'edited_steps=${saved.steps.length}\n'
        'saved_command=${saved.steps.single.command}\n'
        'replay_changed_bytes=$replayChanged\n',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'starter Aurora line extraction and line creation produce actual PNG output',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      final cases = <(String, String, bool)>[
        ('オーロラホログラム', 'aurora_hologram', false),
        ('線画抽出', 'line_extraction', true),
        ('線画作成', 'line_creation', true),
      ];

      for (final entry in cases) {
        await harness.createProject('step3-${entry.$2}');
        if (entry.$2 == 'line_extraction') {
          final tm = harness.projectService.tileManagerOf(harness.projectId);
          final key = harness.projectService.tileKeyFor(
            harness.projectId,
            harness.sceneId,
            harness.frameIndex,
            harness.layerId,
          );
          final rough = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
          void paintDot(int cx, int cy, int radius) {
            for (var y = cy - radius; y <= cy + radius; y++) {
              if (y < 0 || y >= tm.canvasHeight) continue;
              for (var x = cx - radius; x <= cx + radius; x++) {
                if (x < 0 || x >= tm.canvasWidth) continue;
                if ((x - cx) * (x - cx) + (y - cy) * (y - cy) >
                    radius * radius) {
                  continue;
                }
                final i = (y * tm.canvasWidth + x) * 4;
                rough[i] = 20;
                rough[i + 1] = 20;
                rough[i + 2] = 20;
                rough[i + 3] = 255;
              }
            }
          }

          for (var x = 54; x <= 266; x++) {
            final y = 78 + ((x - 54) * 118 ~/ 212);
            paintDot(x, y, 6);
          }
          for (var y = 92; y <= 258; y++) {
            paintDot(178, y, 6);
          }
          for (var x = 84; x <= 246; x++) {
            paintDot(x, 224, 6);
          }
          tm.replaceLayerPixels(key, rough);
        }
        final beforePixels = harness.activeLayerPixels();
        final beforeLayers = harness.normalLayerIds();
        final preset = harness.automationService.items
            .where((item) => item.name == entry.$1)
            .single;

        await tester.runAsync(() async {
          await harness.execute(
            preset,
            CustomAutomationExecutionScope.currentFrame,
            null,
          );
        });

        if (!entry.$3) {
          expect(
            _changedBytes(beforePixels, harness.activeLayerPixels()),
            greaterThan(100),
            reason: '${entry.$1} must visibly change the source layer',
          );
          await harness.captureCanvas('step3_${entry.$2}_actual');
        } else {
          final generated = harness.normalLayerIds().difference(beforeLayers);
          expect(
            generated,
            isNotEmpty,
            reason: '${entry.$1} must create an output layer',
          );
          final generatedId = generated.first;
          final pixels = harness.layerPixels(generatedId);
          var nonTransparent = 0;
          for (var i = 3; i < pixels.length; i += 4) {
            if (pixels[i] != 0) nonTransparent++;
          }
          expect(
            nonTransparent,
            greaterThan(50),
            reason: '${entry.$1} output layer must contain visible pixels',
          );
          await harness.captureCanvas(
            'step3_${entry.$2}_actual',
            targetLayerId: generatedId,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _SurfaceHarness {
  final WidgetTester tester;
  final Directory out;
  final GlobalKey repaintKey;
  final GlobalKey<_SurfaceHostState> hostKey;
  late final ProjectService projectService;
  late final CustomAutomationService automationService;
  late final FilterService filterService;
  late final AppLocalizations l10n;

  String projectId = '';
  String sceneId = '';
  String layerId = '';
  int frameIndex = 0;

  _SurfaceHarness({
    required this.tester,
    required this.out,
    required this.repaintKey,
    required this.hostKey,
  });

  static Future<_SurfaceHarness> create(
    WidgetTester tester,
    Directory out,
  ) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final providers = await tester.runAsync(buildAppProviders);
    final repaintKey = GlobalKey();
    final hostKey = GlobalKey<_SurfaceHostState>();

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: MultiProvider(
          providers: providers!,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _SurfaceHost(key: hostKey),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final harness = _SurfaceHarness(
      tester: tester,
      out: out,
      repaintKey: repaintKey,
      hostKey: hostKey,
    );
    final context = hostKey.currentContext!;
    harness.projectService = context.read<ProjectService>();
    harness.automationService = context.read<CustomAutomationService>();
    harness.filterService = context.read<FilterService>();
    harness.l10n = AppLocalizations.of(context)!;
    return harness;
  }

  Future<void> createProject(String name) async {
    final project = (await tester.runAsync(
      () => projectService.createProject(
        name: name,
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 320,
      ),
    ))!;
    projectId = project.id;
    sceneId = projectService.scenesOf(project.id).first.id;
    frameIndex = 0;
    layerId = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .firstWhere((layer) => layer.type == model.LayerType.normal)
        .id;

    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      layerId,
    );
    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final tile = tm.getOrCreateTile(key, tx, ty);
        tile.fillRange(0, tile.length, 0);
        for (var localY = 0; localY < TileManager.tileSize; localY++) {
          final y = ty * TileManager.tileSize + localY;
          if (y >= tm.canvasHeight) continue;
          for (var localX = 0; localX < TileManager.tileSize; localX++) {
            final x = tx * TileManager.tileSize + localX;
            if (x >= tm.canvasWidth ||
                x < 36 ||
                x >= 284 ||
                y < 36 ||
                y >= 284) {
              continue;
            }
            final i = (localY * TileManager.tileSize + localX) * 4;
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
    await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      image.dispose();
    });
  }

  Set<String> normalLayerIds() => projectService
      .layersOf(projectId, sceneId, frameIndex)
      .where((layer) => layer.type == model.LayerType.normal)
      .map((layer) => layer.id)
      .toSet();

  Uint8List activeLayerPixels() => layerPixels(layerId);

  Uint8List layerPixels(String id) {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, id);
    const tileBytes = TileManager.tileSize * TileManager.tileSize * 4;
    final snapshot = Uint8List(tm.tilesX * tm.tilesY * tileBytes);
    var offset = 0;
    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final current = tm.getTile(key, tx, ty);
        if (current != null)
          snapshot.setRange(offset, offset + tileBytes, current);
        offset += tileBytes;
      }
    }
    return snapshot;
  }

  Future<void> execute(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
    List<int>? targetFrames,
  ) async {
    if (scope == CustomAutomationExecutionScope.specifiedFrames) {
      for (final frame in targetFrames ?? const <int>[]) {
        await CustomAutomationExecutor.executeCanvas(
          automation: automation,
          scope: CustomAutomationExecutionScope.currentFrame,
          projectService: projectService,
          projectId: projectId,
          sceneId: sceneId,
          currentFrame: frame,
          currentLayerId: layerId,
          handleCanvasStateCommand: (_, _) async {},
        );
      }
      return;
    }
    await CustomAutomationExecutor.executeCanvas(
      automation: automation,
      scope: scope,
      projectService: projectService,
      projectId: projectId,
      sceneId: sceneId,
      currentFrame: frameIndex,
      currentLayerId: layerId,
      handleCanvasStateCommand: (_, _) async {},
    );
  }

  void showManager() {
    hostKey.currentState!.show(
      CustomAutomationManagerSheet(
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: frameIndex,
        frameCount: projectService.frameCount(projectId, sceneId),
        onRecordingStarted: () {},
        onExecute: execute,
      ),
    );
  }

  void showFilterPanel() {
    hostKey.currentState!.showBuilder(
      (routeContext) => FilterPanel(
        projectId: projectId,
        sceneId: sceneId,
        layerId: layerId,
        frameIndex: frameIndex,
        onClose: () {},
      ),
    );
  }

  void showRecordingStop() {
    hostKey.currentState!.showBuilder(
      (routeContext) => Scaffold(
        body: Stack(
          children: [
            CustomAutomationRecordingStopButton(
              onStop: () {
                automationService.stopRecording();
              },
            ),
          ],
        ),
      ),
    );
  }

  void showDraftEditor() {
    hostKey.currentState!.show(
      CustomAutomationDraftEditorSheet(
        surface: CustomAutomationSurface.canvas,
        onResumeRecording: () {},
        onSaved: () {},
      ),
    );
  }

  Future<void> captureCanvas(String name, {String? targetLayerId}) async {
    final id = targetLayerId ?? layerId;
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, id);
    final png = await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    File('${out.path}/$name.png').writeAsBytesSync(png!);
  }

  Future<void> capture(String name) async {
    await tester.pump(const Duration(milliseconds: 80));
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  }
}

class _SurfaceHost extends StatefulWidget {
  const _SurfaceHost({super.key});

  @override
  State<_SurfaceHost> createState() => _SurfaceHostState();
}

class _SurfaceHostState extends State<_SurfaceHost> {
  WidgetBuilder? _builder;
  int _generation = 0;

  void show(Widget widget) => showBuilder((_) => widget);

  void showBuilder(WidgetBuilder builder) {
    setState(() {
      _builder = builder;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final builder = _builder;
    if (builder == null) return const Scaffold(body: SizedBox.expand());
    return KeyedSubtree(
      key: ValueKey(_generation),
      child: Scaffold(body: SafeArea(child: builder(context))),
    );
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

int _nonTransparentPixels(Uint8List pixels) {
  var count = 0;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] != 0) count++;
  }
  return count;
}
