import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/onion_skin.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/onion_skin_settings.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');

  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('実描画ストロークをUndo/Redoすると全画素が完全に元へ戻る', () async {
    const width = 128;
    const height = 96;
    const layer = 'scene#0#layer';
    final tm = TileManager(canvasWidth: width, canvasHeight: height);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(opacity: 100)
      ..currentColor = const ui.Color(0xFF202020);
    final undo = UndoManager();

    tm.beginUndoRecording(layer);
    engine.beginStroke(const StrokePoint(x: 16, y: 24), layer);
    for (var x = 17; x <= 108; x++) {
      engine.continueStroke(StrokePoint(x: x.toDouble(), y: 48), layer);
    }
    engine.endStroke();
    final firstSnapshot = tm.endUndoRecording();
    final drawn = _canvasBytes(tm, layer, width, height);
    expect(_alphaCount(drawn), greaterThan(0));
    await _save(drawn, width, height, '${out.path}/undo_drawn.png');

    undo.push(
      TileUndoAction(
        tileManager: tm,
        layerId: layer,
        before: firstSnapshot.before,
        after: firstSnapshot.after,
        onApply: () {},
      ),
    );
    undo.undo();
    final undone = _canvasBytes(tm, layer, width, height);
    expect(_alphaCount(undone), 0, reason: '描画前が完全透明ならUndo後も完全透明であること');
    await _save(undone, width, height, '${out.path}/undo_undone.png');

    undo.redo();
    final redone = _canvasBytes(tm, layer, width, height);
    expect(
      redone,
      orderedEquals(drawn),
      reason: 'Redoは描画後の全RGBAを1byteも変えず復元すること',
    );
    await _save(redone, width, height, '${out.path}/undo_redone.png');

    // 別操作として消しゴムを交差させ、2段階履歴でも正しく戻るか確認する。
    tm.beginUndoRecording(layer);
    engine
      ..isEraser = true
      ..currentBrush = _brush(opacity: 100, size: 12);
    engine.beginStroke(const StrokePoint(x: 64, y: 15), layer);
    for (var y = 16; y <= 80; y++) {
      engine.continueStroke(StrokePoint(x: 64, y: y.toDouble()), layer);
    }
    engine.endStroke();
    final eraseSnapshot = tm.endUndoRecording();
    final erased = _canvasBytes(tm, layer, width, height);
    expect(erased, isNot(orderedEquals(drawn)));
    await _save(erased, width, height, '${out.path}/undo_erased.png');

    undo.push(
      TileUndoAction(
        tileManager: tm,
        layerId: layer,
        before: eraseSnapshot.before,
        after: eraseSnapshot.after,
        onApply: () {},
      ),
    );
    undo.undo();
    expect(
      _canvasBytes(tm, layer, width, height),
      orderedEquals(drawn),
      reason: '消しゴムだけUndoすると直前のペン線へ完全一致で戻ること',
    );
    undo.redo();
    expect(
      _canvasBytes(tm, layer, width, height),
      orderedEquals(erased),
      reason: '消しゴムRedoで消去後へ完全一致すること',
    );

    // Undo後に新規操作を行ったら、分岐前のRedo履歴は破棄される。
    undo.undo();
    expect(undo.canRedo, isTrue);
    tm.beginUndoRecording(layer);
    engine
      ..isEraser = false
      ..currentColor = const ui.Color(0xFF0066CC)
      ..currentBrush = _brush(opacity: 100, size: 6);
    engine.beginStroke(const StrokePoint(x: 20, y: 82), layer);
    engine.continueStroke(const StrokePoint(x: 105, y: 82), layer);
    engine.endStroke();
    final branchSnapshot = tm.endUndoRecording();
    undo.push(
      TileUndoAction(
        tileManager: tm,
        layerId: layer,
        before: branchSnapshot.before,
        after: branchSnapshot.after,
        onApply: () {},
      ),
    );
    expect(undo.canRedo, isFalse, reason: 'Undo後の新規描画は古いRedo分岐を破棄すること');
  });

  test('レイヤー削除と複製のUndo/Redoで元のレイヤー順序を完全維持する', () async {
    final service = ProjectService();
    await service.init();
    final project = await service.createProject(
      name: 'undo-layer-order',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final scene = service.scenesOf(project.id).first;
    final base = service.layersOf(project.id, scene.id, 0).first;
    final undo = UndoManager();
    service.setUndoManager(undo);

    final a = service.addLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'A',
    );
    final b = service.addLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'B',
    );
    undo.clear();
    expect(_layerIds(service, project.id, scene.id), [b.id, a.id, base.id]);

    service.removeLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layerId: a.id,
    );
    expect(_layerIds(service, project.id, scene.id), [b.id, base.id]);
    undo.undo();
    expect(_layerIds(service, project.id, scene.id), [
      b.id,
      a.id,
      base.id,
    ], reason: '中央レイヤー削除のUndoは元indexへ復元すること');
    undo.redo();
    expect(_layerIds(service, project.id, scene.id), [b.id, base.id]);
    undo.undo();
    expect(_layerIds(service, project.id, scene.id), [b.id, a.id, base.id]);

    undo.clear();
    final copy = service.duplicateLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layerId: a.id,
    )!;
    expect(_layerIds(service, project.id, scene.id), [
      b.id,
      copy.id,
      a.id,
      base.id,
    ]);
    undo.undo();
    expect(_layerIds(service, project.id, scene.id), [b.id, a.id, base.id]);
    undo.redo();
    expect(_layerIds(service, project.id, scene.id), [
      b.id,
      copy.id,
      a.id,
      base.id,
    ], reason: '複製Redoも元の挿入位置へ戻ること');
  });

  test('オニオンスキンは前後・枚数・間隔・濃度・色を設定通り返す', () async {
    final engine = OnionSkinEngine();
    const settings = OnionSkinSettings(
      enabled: true,
      showPrev: true,
      showNext: true,
      prevFrames: 3,
      nextFrames: 2,
      frameInterval: 2,
      prevOpacity: 0.40,
      nextOpacity: 0.30,
      prevColor: ui.Color(0xFFFF0000),
      nextColor: ui.Color(0xFF0000FF),
      fadeByDistance: true,
    );

    expect(engine.getVisibleFrameOffsets(settings), [-2, -4, -6, 2, 4]);
    expect(engine.getOpacityForFrame(settings, 0), 0);
    expect(
      engine.getOpacityForFrame(settings, -1),
      0,
      reason: '間隔2なら隣接-1フレームは表示対象外',
    );
    expect(engine.getOpacityForFrame(settings, 1), 0);
    final p1 = engine.getOpacityForFrame(settings, -2);
    final p2 = engine.getOpacityForFrame(settings, -4);
    final p3 = engine.getOpacityForFrame(settings, -6);
    expect(p1, closeTo(0.40, 1e-9));
    expect(p1, greaterThan(p2));
    expect(p2, greaterThan(p3));
    expect(p3, greaterThan(0));
    expect(engine.getOpacityForFrame(settings, -8), 0);
    expect(engine.getOpacityForFrame(settings, 2), closeTo(0.30, 1e-9));
    expect(engine.getOpacityForFrame(settings, 4), greaterThan(0));
    expect(engine.getOpacityForFrame(settings, 6), 0);
    expect(engine.getColorForFrame(settings, -2), const ui.Color(0xFFFF0000));
    expect(engine.getColorForFrame(settings, 2), const ui.Color(0xFF0000FF));

    // 診断用PNG: 実際の設定から返る前後色と距離alphaを帯として可視化する。
    final rgba = Uint8List(200 * 80 * 4);
    final offsets = engine.getVisibleFrameOffsets(settings);
    for (var i = 0; i < offsets.length; i++) {
      final delta = offsets[i];
      final c = engine.getColorForFrame(settings, delta);
      final a = (engine.getOpacityForFrame(settings, delta) * 255).round();
      for (var y = 10; y < 70; y++) {
        for (var x = i * 40; x < (i + 1) * 40; x++) {
          final idx = (y * 200 + x) * 4;
          rgba[idx] = (c.r * 255).round();
          rgba[idx + 1] = (c.g * 255).round();
          rgba[idx + 2] = (c.b * 255).round();
          rgba[idx + 3] = a;
        }
      }
    }
    await _save(rgba, 200, 80, '${out.path}/onion_offsets_opacity.png');
  });

  test('オニオンスキンOFF・前後個別OFF・距離減衰OFFを正しく尊重する', () {
    final engine = OnionSkinEngine();
    const disabled = OnionSkinSettings(enabled: false);
    expect(engine.getVisibleFrameOffsets(disabled), isEmpty);
    expect(engine.getOpacityForFrame(disabled, -1), 0);

    const prevOnly = OnionSkinSettings(
      enabled: true,
      showPrev: true,
      showNext: false,
      prevFrames: 2,
      frameInterval: 1,
      prevOpacity: 0.37,
      fadeByDistance: false,
    );
    expect(engine.getVisibleFrameOffsets(prevOnly), [-1, -2]);
    expect(engine.getOpacityForFrame(prevOnly, -1), closeTo(0.37, 1e-9));
    expect(engine.getOpacityForFrame(prevOnly, -2), closeTo(0.37, 1e-9));
    expect(engine.getOpacityForFrame(prevOnly, 1), 0);
  });
}

Brush _brush({int opacity = 100, double size = 8}) => Brush(
  id: 'audit',
  name: 'audit',
  size: size,
  opacity: opacity,
  spacing: 10,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: PressureMode.off,
  pressureStrength: 0,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);

List<String> _layerIds(ProjectService s, String projectId, String sceneId) =>
    s.layersOf(projectId, sceneId, 0).map((l) => l.id).toList();

Uint8List _canvasBytes(TileManager tm, String layer, int width, int height) {
  final out = Uint8List(width * height * 4);
  final tile = tm.getTile(layer, 0, 0);
  if (tile == null) return out;
  for (var y = 0; y < height; y++) {
    final src = y * TileManager.tileSize * 4;
    final dst = y * width * 4;
    out.setRange(dst, dst + width * 4, tile, src);
  }
  return out;
}

int _alphaCount(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) n++;
  }
  return n;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  desc.dispose();
  buffer.dispose();
}
