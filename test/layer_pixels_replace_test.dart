import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/models/layer.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 120, _h = 80;

/// A filter applied in place (replacing a layer's pixels from outside the
/// canvas) is one Undo step, and the canvas shows it at once — and shows the
/// original again after Undo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Uint8List solid(int r, int g, int b) {
    final rgba = Uint8List(_w * _h * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = 255;
    }
    return rgba;
  }

  Uint8List layerBytes(TileManager tm, String key) {
    final out = Uint8List(_w * _h * 4);
    final tile = tm.getTile(key, 0, 0);
    if (tile == null) return out;
    for (var y = 0; y < _h; y++) {
      out.setRange(
        y * _w * 4,
        (y + 1) * _w * 4,
        tile,
        y * TileManager.tileSize * 4,
      );
    }
    return out;
  }

  Future<
    ({
      ProjectService projects,
      app_undo.UndoManager undo,
      String projectId,
      String sceneId,
      Layer layer,
      String key,
      TileManager tm,
    })
  >
  setUpProject(WidgetTester? tester) async {
    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    Future<T> run<T>(Future<T> Function() f) async =>
        tester == null ? await f() : (await tester.runAsync(f)) as T;
    final p = await run(
      () => projects.createProject(
        name: 'replace',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: _w,
        exportHeight: _h,
      ),
    );
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);
    tm.replaceLayerPixels(key, solid(200, 40, 40));
    return (
      projects: projects,
      undo: undo,
      projectId: p.id,
      sceneId: scene.id,
      layer: layer,
      key: key,
      tm: tm,
    );
  }

  test('replacing a layer\'s pixels is one Undo step, with Redo', () async {
    final s = await setUpProject(null);
    final before = layerBytes(s.tm, s.key);
    s.projects.replaceLayerPixels(
      projectId: s.projectId,
      sceneId: s.sceneId,
      frameIndex: 0,
      layerId: s.layer.id,
      pixels: solid(30, 60, 220),
    );
    final after = layerBytes(s.tm, s.key);
    expect(after, isNot(orderedEquals(before)));
    expect(s.undo.undoCount, 1);

    s.undo.undo();
    expect(layerBytes(s.tm, s.key), orderedEquals(before));
    s.undo.redo();
    expect(layerBytes(s.tm, s.key), orderedEquals(after));
  });

  test('Undo also restores the layer settings changed with it', () async {
    final s = await setUpProject(null);
    s.projects.replaceLayerPixels(
      projectId: s.projectId,
      sceneId: s.sceneId,
      frameIndex: 0,
      layerId: s.layer.id,
      pixels: solid(30, 60, 220),
      updatedLayer: s.layer.copyWith(blendMode: LayerBlendMode.linearDodge),
    );
    LayerBlendMode mode() =>
        s.projects.layersOf(s.projectId, s.sceneId, 0).single.blendMode;
    expect(mode(), LayerBlendMode.linearDodge);
    s.undo.undo();
    expect(mode(), s.layer.blendMode);
    s.undo.redo();
    expect(mode(), LayerBlendMode.linearDodge);
  });

  test('a recording already open (a stroke) is left alone', () async {
    final s = await setUpProject(null);
    s.tm.beginUndoRecording(s.key);
    s.projects.replaceLayerPixels(
      projectId: s.projectId,
      sceneId: s.sceneId,
      frameIndex: 0,
      layerId: s.layer.id,
      pixels: solid(30, 60, 220),
    );
    expect(s.tm.recordingTouchedTiles, isNotNull, reason: 'still recording');
    expect(s.undo.undoCount, 0);
    s.tm.endUndoRecording();
  });

  test('inside an automation run, an existing layer changed in place comes '
      'back with the run\'s single Undo', () async {
    final s = await setUpProject(null);
    final before = layerBytes(s.tm, s.key);
    await s.projects.runWithGroupedUndo(
      description: 'automation',
      operation: () async => s.projects.replaceLayerPixels(
        projectId: s.projectId,
        sceneId: s.sceneId,
        frameIndex: 0,
        layerId: s.layer.id,
        pixels: solid(30, 60, 220),
      ),
    );
    expect(s.undo.undoCount, 1);
    s.undo.undo();
    expect(layerBytes(s.tm, s.key), orderedEquals(before));
  });

  test('a layer the run creates and then filters comes back on Redo with '
      'its final pixels', () async {
    final s = await setUpProject(null);
    late String createdKey;
    await s.projects.runWithGroupedUndo(
      description: 'automation',
      operation: () async {
        final created = s.projects.addLayer(
          projectId: s.projectId,
          sceneId: s.sceneId,
          frameIndex: 0,
          type: LayerType.normal,
          name: 'output',
        );
        createdKey = s.projects.tileKeyFor(
          s.projectId,
          s.sceneId,
          0,
          created.id,
        );
        s.tm.replaceLayerPixels(createdKey, solid(10, 200, 10));
        s.projects.replaceLayerPixels(
          projectId: s.projectId,
          sceneId: s.sceneId,
          frameIndex: 0,
          layerId: created.id,
          pixels: solid(250, 250, 20),
        );
      },
    );
    final finalPixels = layerBytes(s.tm, createdKey);
    s.undo.undo();
    expect(s.projects.layersOf(s.projectId, s.sceneId, 0), hasLength(1));
    s.undo.redo();
    expect(s.projects.layersOf(s.projectId, s.sceneId, 0), hasLength(2));
    expect(layerBytes(s.tm, createdKey), orderedEquals(finalPixels));
  });

  testWidgets('the canvas shows the new pixels at once, and the old ones '
      'after Undo', (tester) async {
    tester.view.physicalSize = const Size(_w * 3, _h * 3);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await setUpProject(tester);
    final providers = await tester.runAsync(buildAppProviders);
    final boundary = GlobalKey();
    final project = s.projects.projects.firstWhere((p) => p.id == s.projectId);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: s.projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: s.undo),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: CanvasArea(
              project: project,
              currentLayerId: s.layer.id,
              currentTool: DrawingTool.pen,
              currentFrame: 0,
              sceneId: s.sceneId,
            ),
          ),
        ),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<List<int>> centre() async {
      final pixels = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final width = image.width;
        final height = image.height;
        image.dispose();
        final i = ((height ~/ 2) * width + width ~/ 2) * 4;
        return data!.buffer.asUint8List().sublist(i, i + 3);
      });
      return pixels!;
    }

    await settle();
    expect(await centre(), [200, 40, 40], reason: 'the original layer');

    s.projects.replaceLayerPixels(
      projectId: s.projectId,
      sceneId: s.sceneId,
      frameIndex: 0,
      layerId: s.layer.id,
      pixels: solid(30, 60, 220),
    );
    await settle();
    expect(await centre(), [30, 60, 220], reason: 'the filter result');

    s.undo.undo();
    await settle();
    expect(await centre(), [200, 40, 40], reason: 'back after Undo');
  });
}
