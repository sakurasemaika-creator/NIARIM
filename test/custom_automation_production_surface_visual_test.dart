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
    'production automation surfaces record a real Aurora filter and replay it',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('record-replay');
      final automation = harness.automationService;
      final l10n = harness.l10n;

      harness.showManager();
      await tester.pump();
      await harness.capture('01_manager_open');
      expect(find.text(l10n.customAutomationAdd), findsOneWidget);

      await tester.tap(find.text(l10n.customAutomationAdd));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'visual-audit-automation');
      await tester.tap(find.text(l10n.customAutomationStartRecording));
      await tester.pump(const Duration(milliseconds: 250));
      expect(automation.isRecording, isTrue);

      harness.filterService.selectFilter('Filter0019');
      harness.showFilterPanel();
      await tester.pump();
      await harness.waitForProductionAsync();
      expect(find.byType(FilterPanel), findsOneWidget);
      await harness.capture('02_aurora_filter_panel_during_recording');

      final beforeApply = harness.activeLayerPixels();
      await tester.tap(find.text(l10n.filterApplyButton));
      await harness.waitForProductionAsync();
      final afterApply = harness.activeLayerPixels();
      expect(
        _changedBytes(beforeApply, afterApply),
        greaterThan(100),
        reason:
            'The production FilterPanel Apply action must change real pixels',
      );
      expect(automation.draft, isNotNull);
      expect(automation.draft!.steps, hasLength(1));
      expect(automation.draft!.steps.single.command, 'canvas.filterApply');
      await harness.capture('03_real_aurora_applied_and_recorded');

      harness.showRecordingStop();
      await tester.pump();
      await harness.capture('04_recording_stop_ui');
      await tester.tap(find.text(l10n.customAutomationStopRecording));
      await tester.pump(const Duration(milliseconds: 100));
      expect(automation.isRecording, isFalse);

      harness.showDraftEditor();
      await tester.pump();
      expect(find.text('canvas.filterApply'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      await harness.capture('05_draft_editor');
      await tester.tap(find.text(l10n.commonSave).last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(automation.draft, isNull);
      expect(
        automation.items.any((item) => item.name == 'visual-audit-automation'),
        isTrue,
      );

      final beforeReplay = harness.activeLayerPixels();
      harness.showManager();
      await tester.pump();
      expect(find.text('visual-audit-automation'), findsOneWidget);
      await harness.capture('06_manager_saved_item');
      await tester.tap(find.text('visual-audit-automation'));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text(l10n.customAutomationRunConfirmTitle), findsOneWidget);
      await harness.capture('07_replay_confirmation');
      await tester.tap(find.text(l10n.customAutomationYes));
      await harness.waitForProductionAsync();
      final afterReplay = harness.activeLayerPixels();
      expect(
        _changedBytes(beforeReplay, afterReplay),
        greaterThan(100),
        reason: 'Saved automation replay must change real pixels again',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'three starter automations execute through the production manager',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      final cases = <(String, String, bool)>[
        ('オーロラホログラム', 'aurora_hologram', false),
        ('線画抽出', 'line_extraction', true),
        ('線画作成', 'line_creation', true),
      ];

      for (final entry in cases) {
        await harness.createProject('preset-${entry.$2}');
        final beforePixels = harness.activeLayerPixels();
        final beforeLayers = harness.normalLayerIds();

        harness.showManager();
        await tester.pump();
        expect(find.text(entry.$1), findsOneWidget);
        await harness.capture('preset_${entry.$2}_01_manager');
        await tester.tap(find.text(entry.$1));
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.text(harness.l10n.customAutomationRunConfirmTitle),
          findsOneWidget,
        );
        await tester.tap(find.text(harness.l10n.customAutomationYes));
        await harness.waitForProductionAsync(extraMilliseconds: 2200);

        if (!entry.$3) {
          expect(
            _changedBytes(beforePixels, harness.activeLayerPixels()),
            greaterThan(100),
            reason: '${entry.$1} must visibly change source pixels',
          );
        } else {
          final afterLayers = harness.normalLayerIds();
          final generated = afterLayers.difference(beforeLayers);
          expect(
            generated,
            isNotEmpty,
            reason: '${entry.$1} must create an output layer',
          );
          final layers = harness.projectService.layersOf(
            harness.projectId,
            harness.sceneId,
            harness.frameIndex,
          );
          final normalLayers = layers
              .where((layer) => layer.type == model.LayerType.normal)
              .toList();
          expect(normalLayers.first.id, generated.first);
          expect(
            _nonTransparentPixels(harness.layerPixels(generated.first)),
            greaterThan(50),
            reason: '${entry.$1} output layer must contain visible pixels',
          );
        }
        await harness.capture('preset_${entry.$2}_02_after');
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
        onClose: () => Navigator.pop(routeContext),
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
                Navigator.pop(routeContext);
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

  Future<void> waitForProductionAsync({int extraMilliseconds = 1500}) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: extraMilliseconds)),
    );
    await tester.pump(const Duration(milliseconds: 180));
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
    return Navigator(
      key: ValueKey(_generation),
      onGenerateInitialRoutes: (navigator, initialRoute) => [
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox.expand()),
        ),
        MaterialPageRoute<void>(
          builder: (routeContext) =>
              Scaffold(body: SafeArea(child: builder(routeContext))),
        ),
      ],
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
