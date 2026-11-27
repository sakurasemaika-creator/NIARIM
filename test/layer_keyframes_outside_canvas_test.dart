// レイヤーのキーフレーム（倍率・回転など）は、キャンバスだけでなく
// フレーム一覧・プレビュー・作品のサムネイル・結合など、コマを合成する
// どこでも同じ位置で描く。
//
// 実際に使ってみたとき（2026-11-27）、空のレイヤーに倍率1.8のキーフレームを
// 付けると、キャンバスでは全面に広がるのに、フレーム一覧のサムネイル・
// キャンバスプレビュー・ホームのカード・詳細のプレビューでは元の大きさの
// ままだった。下と結合すると広げた分が消えた。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/services/frame_thumbnail_renderer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Uint8List> rgba(ui.Image image) async {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    return data.buffer.asUint8List();
  }

  int alphaAt(Uint8List pixels, int width, int x, int y) =>
      pixels[(y * width + x) * 4 + 3];

  test('the frame picture and merge use the layer\'s keyframe', () async {
    final ps = ProjectService();
    await ps.init();
    ps.setUndoManager(UndoManager());
    final p = await ps.createProject(
      name: 'keyframes outside the canvas',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    );
    final scene = ps.scenesOf(p.id).first.id;
    final tiles = ps.tileManagerOf(p.id);
    final layer = ps.layersOf(p.id, scene, 0).first;
    // An 8x8 square in the middle (28..36).
    final pixels = Uint8List(64 * 64 * 4);
    for (var y = 28; y < 36; y++) {
      for (var x = 28; x < 36; x++) {
        final i = (y * 64 + x) * 4;
        pixels[i] = 200;
        pixels[i + 3] = 255;
      }
    }
    tiles.replaceLayerPixels(ps.tileKeyFor(p.id, scene, 0, layer.id), pixels);
    ps.updateLayer(
      projectId: p.id,
      sceneId: scene,
      frameIndex: 0,
      layer: layer.copyWith(
        keyframes: const [LayerKeyframe(frameIndex: 0, scale: 3)],
      ),
      recordUndo: false,
    );

    // The frame picture (frame strip, previews, home cards) shows it scaled.
    final picture = await compositeFrameThumbnail(
      ps,
      projectId: p.id,
      sceneId: scene,
      frameIndex: 0,
      maxSize: 64,
    );
    final shown = await rgba(picture!);
    expect(alphaAt(shown, 64, 32, 32), greaterThan(0));
    expect(
      alphaAt(shown, 64, 22, 32),
      greaterThan(0),
      reason: 'scaled 3x the square reaches 20..44',
    );

    // Merging bakes the scale and takes the keyframe off the result.
    final top = ps.addLayer(
      projectId: p.id,
      sceneId: scene,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'top',
    );
    final layers = ps.layersOf(p.id, scene, 0);
    await ps.mergeLayers(
      projectId: p.id,
      sceneId: scene,
      frameIndex: 0,
      layerIds: [top.id, layers.firstWhere((l) => l.id == layer.id).id],
    );
    final merged = ps
        .layersOf(p.id, scene, 0)
        .firstWhere((l) => l.id == layer.id || l.id == top.id);
    expect(merged.keyframes, isEmpty);
    final image = await tiles.compositeLayerToImage(
      ps.tileKeyFor(p.id, scene, 0, merged.id),
    );
    final mergedPixels = await rgba(image);
    expect(alphaAt(mergedPixels, 64, 22, 32), greaterThan(0));
    expect(alphaAt(mergedPixels, 64, 32, 32), greaterThan(0));
  });
}
