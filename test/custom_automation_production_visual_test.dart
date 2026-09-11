import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/custom_automation_executor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
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
    '${Directory.systemTemp.path}/niarim_custom_automation_production_docs',
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
          (call) async => appDocs.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'real Custom Automation widgets record -> apply -> stop -> edit -> save -> replay with PNG evidence',
    (tester) async {
      final harness = await _ProductionHarness.create(tester, out);
      await harness.createAndShowProject('record-replay');
      final l10n = harness.l10n;
      final automation = harness.automationService;

      harness.showManager();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(l10n.customAutomationAdd));
      await tester.pump(const Duration(milliseconds: 200));
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await tester.enterText(field, 'visual-audit-automation');
      await tester.tap(find.text(l10n.customAutomationStartRecording));
      await tester.pump(const Duration(milliseconds: 300));
      expect(automation.isRecording, isTrue);

      final filterService = harness.canvasContext.read<FilterService>();
      filterService.selectFilter('Filter0019');
      harness.showFilterPanel();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FilterPanel), findsOneWidget);

      final beforeApply = harness.activeLayerPixels();
      await tester.tap(find.text(l10n.filterApplyButton));
      await harness.waitForPixelChange(
        beforeApply,
        label: 'recorded filter apply',
      );
      final afterApply = harness.activeLayerPixels();
      expect(
        _changedBytes(beforeApply, afterApply),
        greaterThan(100),
        reason: 'The real FilterPanel Apply action must change Canvas pixels',
      );
      expect(automation.draft, isNotNull);
      expect(automation.draft!.steps, hasLength(1));
      expect(automation.draft!.steps.single.command, 'canvas.filterApply');

      expect(
        find.byType(FilterPanel),
        findsNothing,
        reason: 'FilterPanel closes itself after a successful Apply',
      );

      harness.showRecordingStop();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text(l10n.customAutomationStopRecording));
      await tester.pump(const Duration(milliseconds: 250));
      expect(automation.isRecording, isFalse);
      expect(automation.draft, isNotNull);

      harness.showDraftEditor();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('canvas.filterApply'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.text(l10n.commonSave).last);
      await tester.pump(const Duration(milliseconds: 350));
      expect(automation.draft, isNull);
      expect(
        automation.items.any((item) => item.name == 'visual-audit-automation'),
        isTrue,
      );

      final beforeReplay = harness.activeLayerPixels();
      harness.showManager();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('visual-audit-automation'), findsOneWidget);
      await tester.tap(find.text('visual-audit-automation'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(l10n.customAutomationRunConfirmTitle), findsOneWidget);
      await tester.tap(find.text(l10n.customAutomationYes));
      await harness.waitForPixelChange(
        beforeReplay,
        label: 'saved automation replay',
      );
      final afterReplay = harness.activeLayerPixels();
      expect(
        _changedBytes(beforeReplay, afterReplay),
        greaterThan(100),
        reason: 'Saved automation replay must change real Canvas pixels again',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'three starter automations execute through real manager UI and produce visible Canvas output',
    (tester) async {
      final harness = await _ProductionHarness.create(tester, out);
      final cases = <(String, String, bool)>[
        ('オーロラホログラム', 'aurora_hologram', false),
        ('線画抽出', 'line_extraction', true),
        ('線画作成', 'line_creation', true),
      ];

      for (final entry in cases) {
        final name = entry.$1;
        final slug = entry.$2;
        final createsLayer = entry.$3;
        await harness.createAndShowProject('preset-$slug', showCanvas: true);
        final beforePixels = harness.activeLayerPixels();
        final canvas = harness.canvasWidget;
        final beforeLayers = harness.projectService
            .layersOf(harness.projectId, canvas.sceneId, canvas.currentFrame)
            .where((layer) => layer.type == model.LayerType.normal)
            .map((layer) => layer.id)
            .toSet();

        await harness.capture('preset_${slug}_00_before');
        harness.showManager();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text(name), findsOneWidget);
        await harness.capture('preset_${slug}_01_manager');
        await tester.tap(find.text(name));
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.text(harness.l10n.customAutomationRunConfirmTitle),
          findsOneWidget,
        );
        await tester.tap(find.text(harness.l10n.customAutomationYes));
        await harness.waitForAutomationResult(
          beforePixels: beforePixels,
          beforeLayers: beforeLayers,
          createsLayer: createsLayer,
          label: name,
        );

        if (!createsLayer) {
          final afterPixels = harness.activeLayerPixels();
          expect(
            _changedBytes(beforePixels, afterPixels),
            greaterThan(100),
            reason: '$name must visibly change the source Canvas pixels',
          );
        } else {
          final nowCanvas = harness.canvasWidget;
          final afterLayers = harness.projectService
              .layersOf(
                harness.projectId,
                nowCanvas.sceneId,
                nowCanvas.currentFrame,
              )
              .where((layer) => layer.type == model.LayerType.normal)
              .toList();
          final generated = afterLayers.where(
            (layer) => !beforeLayers.contains(layer.id),
          );
          expect(
            generated,
            isNotEmpty,
            reason: '$name must create an output layer',
          );
          final generatedLayer = generated.first;
          expect(
            afterLayers.first.id,
            generatedLayer.id,
            reason: '$name output must be placed at the top of the layer stack',
          );
          final generatedPixels = harness.layerPixels(generatedLayer.id);
          expect(
            _nonTransparentPixels(generatedPixels),
            greaterThan(50),
            reason: '$name output layer must contain visible pixels',
          );
        }
        await harness.capture('preset_${slug}_02_after');
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

class _ProductionHarness {
  final WidgetTester tester;
  final Directory out;
  final ProjectService projectService;
  final GlobalKey rootKey;
  final StateSetter rebuildHost;
  String? _projectId;
  String? _sceneId;
  int _frame = 0;
  String? _layerId;

  _ProductionHarness({
    required this.tester,
    required this.out,
    required this.projectService,
    required this.rootKey,
    required this.rebuildHost,
  });

  String get projectId => _projectId!;
  BuildContext get canvasContext =>
      tester.element(find.byType(Navigator).first);
  CanvasArea get canvasWidget =>
      tester.widget<CanvasArea>(find.byType(CanvasArea));
  CustomAutomationService get automationService =>
      canvasContext.read<CustomAutomationService>();
  AppLocalizations get l10n => AppLocalizations.of(canvasContext)!;

  static Future<_ProductionHarness> create(
    WidgetTester tester,
    Directory out,
  ) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final providers = await tester.runAsync(buildAppProviders);
    ProjectService? ps;
    StateSetter? hostSetter;
    String? activeProjectId;
    Widget? testSurface;
    var showCanvas = false;
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
                  hostSetter = setState;
                  if (activeProjectId == null) return const SizedBox.expand();
                  if (testSurface != null) return testSurface!;
                  if (!showCanvas) {
                    return const Material(child: SizedBox.expand());
                  }
                  return CanvasScreen(
                    key: ValueKey(activeProjectId),
                    projectId: activeProjectId!,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    late _ProductionHarness harness;
    harness = _ProductionHarness(
      tester: tester,
      out: out,
      projectService: ps!,
      rootKey: rootKey,
      rebuildHost: (fn) {
        hostSetter!(fn);
        harness._projectId = activeProjectId;
      },
    );
    harness._setProject = (id, canvasVisible) {
      activeProjectId = id;
      showCanvas = canvasVisible;
      harness._projectId = id;
      hostSetter!(() {});
    };
    harness._setSurface = (child) {
      testSurface = child;
      hostSetter!(() {});
    };
    return harness;
  }

  late void Function(String id, bool showCanvas) _setProject;
  late void Function(Widget? child) _setSurface;

  Future<void> createAndShowProject(
    String name, {
    bool showCanvas = false,
  }) async {
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
    final scene = projectService.scenesOf(project.id).first;
    final layer = scene.frames.first.layers
        .where((entry) => entry.type == model.LayerType.normal)
        .first;
    final tm = projectService.tileManagerOf(project.id);
    final key = projectService.tileKeyFor(project.id, scene.id, 0, layer.id);
    final tile = tm.getOrCreateTile(key, 0, 0);
    tile.fillRange(0, tile.length, 0);
    for (var y = 36; y < 244; y++) {
      for (var x = 36; x < 244; x++) {
        final i = (y * TileManager.tileSize + x) * 4;
        var shade = 20 + ((x - 36) * 225 ~/ 207);
        if ((x > 92 && x < 118) || (y > 148 && y < 174)) {
          shade = 18;
        }
        if (x > 188 && x < 242 && y > 78 && y < 132) {
          shade = 235;
        }
        tile[i] = shade;
        tile[i + 1] = shade;
        tile[i + 2] = shade;
        tile[i + 3] = 255;
      }
    }
    tm.invalidateTile(key, 0, 0);
    await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      image.dispose();
    });
    _sceneId = scene.id;
    _frame = 0;
    _layerId = layer.id;
    _setProject(project.id, showCanvas);
    await tester.pump();
    if (showCanvas) {
      await tester.pump(const Duration(milliseconds: 1200));
    }
  }

  Future<void> capture(String name) async {
    await tester.pump(const Duration(milliseconds: 100));
    final boundary =
        rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  }

  Uint8List activeLayerPixels() => layerPixels(_layerId!);

  Uint8List layerPixels(String layerId) {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(
      projectId,
      _sceneId!,
      _frame,
      layerId,
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

  Future<void> _yieldAsyncWork() async {
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump();
  }

  Future<void> waitForPixelChange(
    Uint8List before, {
    required String label,
  }) async {
    for (var attempt = 0; attempt < 600; attempt++) {
      if (_changedBytes(before, activeLayerPixels()) > 100) return;
      await _yieldAsyncWork();
    }
    throw TestFailure('$label did not change Canvas pixels');
  }

  Future<void> waitForAutomationResult({
    required Uint8List beforePixels,
    required Set<String> beforeLayers,
    required bool createsLayer,
    required String label,
  }) async {
    for (var attempt = 0; attempt < 600; attempt++) {
      if (createsLayer) {
        final current = projectService
            .layersOf(projectId, _sceneId!, _frame)
            .where((layer) => layer.type == model.LayerType.normal)
            .map((layer) => layer.id)
            .toSet();
        if (current.difference(beforeLayers).isNotEmpty) return;
      } else if (_changedBytes(beforePixels, activeLayerPixels()) > 100) {
        return;
      }
      await _yieldAsyncWork();
    }
    throw TestFailure('$label did not reach its observable completion state');
  }

  Future<void> _execute(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
    List<int>? targetFrames,
  ) async {
    final sceneId = _sceneId!;
    final currentFrame = _frame;
    final currentLayerId = _layerId;
    if (scope == CustomAutomationExecutionScope.specifiedFrames) {
      for (final frame in targetFrames ?? const <int>[]) {
        await CustomAutomationExecutor.executeCanvas(
          automation: automation,
          scope: CustomAutomationExecutionScope.currentFrame,
          projectService: projectService,
          projectId: projectId,
          sceneId: sceneId,
          currentFrame: frame,
          currentLayerId: currentLayerId,
          handleCanvasStateCommand: (_, __) async {},
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
      currentFrame: currentFrame,
      currentLayerId: currentLayerId,
      handleCanvasStateCommand: (_, __) async {},
    );
  }

  void _hideSurface() => _setSurface(null);

  Widget _localNavigator(Widget page) => Navigator(
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );

  Widget _sheetPage(Widget child) => Material(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Material(child: child),
    ),
  );

  void showManager() {
    final count = projectService.frameCount(projectId, _sceneId!);
    _setSurface(
      _localNavigator(
        _sheetPage(
          CustomAutomationManagerSheet(
            surface: CustomAutomationSurface.canvas,
            recordingStartFrame: _frame,
            frameCount: count,
            onRecordingStarted: _hideSurface,
            onExecute: (automation, scope, targetFrames) async {
              _hideSurface();
              await _execute(automation, scope, targetFrames);
            },
          ),
        ),
      ),
    );
  }

  void showFilterPanel() {
    _setSurface(
      _localNavigator(
        _sheetPage(
          Center(
            child: FilterPanel(
              projectId: projectId,
              sceneId: _sceneId!,
              layerId: _layerId,
              frameIndex: _frame,
              onClose: _hideSurface,
            ),
          ),
        ),
      ),
    );
  }

  void showRecordingStop() {
    final service = automationService;
    _setSurface(
      _localNavigator(
        Material(
          child: Stack(
            children: [
              CustomAutomationRecordingStopButton(
                onStop: () {
                  service.stopRecording();
                  _hideSurface();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showDraftEditor() {
    _setSurface(
      _localNavigator(
        _sheetPage(
          CustomAutomationDraftEditorSheet(
            surface: CustomAutomationSurface.canvas,
            onResumeRecording: _hideSurface,
            onSaved: _hideSurface,
          ),
        ),
      ),
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
