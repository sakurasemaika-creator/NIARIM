import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('フレーム複製・削除・再index後も実タイルが正しいフレームへ追従する', () async {
    final ps = ProjectService();
    await ps.init();
    final p = await ps.createProject(
      name: 'frame-pixel-audit',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0x00000000,
      exportWidth: 16,
      exportHeight: 12,
    );
    final sceneId = ps.scenesOf(p.id).first.id;
    ps.addFrame(p.id, sceneId);
    ps.addFrame(p.id, sceneId);
    expect(ps.frameCount(p.id, sceneId), 3);

    // addFrameは通常レイヤー構成を引き継ぐので、各フレームの先頭レイヤーへ
    // 明確に異なる実画素を置く。
    final colors = <List<int>>[
      [240, 20, 30, 255],
      [30, 220, 50, 255],
      [40, 70, 235, 255],
    ];
    for (var fi = 0; fi < 3; fi++) {
      final layer = ps.layersOf(p.id, sceneId, fi).first;
      final key = ps.tileKeyFor(p.id, sceneId, fi, layer.id);
      final bytes = Uint8List(16 * 12 * 4);
      for (var i = 0; i < bytes.length; i += 4) {
        bytes[i] = colors[fi][0];
        bytes[i + 1] = colors[fi][1];
        bytes[i + 2] = colors[fi][2];
        bytes[i + 3] = colors[fi][3];
      }
      ps.tileManagerOf(p.id).replaceLayerPixels(key, bytes);
    }

    expect(_framePixel(ps, p.id, sceneId, 0), colors[0]);
    expect(_framePixel(ps, p.id, sceneId, 1), colors[1]);
    expect(_framePixel(ps, p.id, sceneId, 2), colors[2]);

    // F1を複製。既存F2のタイルキーは2→3へ後ろから安全にrenameされ、
    // 新F2にはF1の内容が新しいlayerIdでCopy-on-Write複製される。
    ps.duplicateFrame(p.id, sceneId, 1);
    expect(ps.frameCount(p.id, sceneId), 4);
    expect(_framePixel(ps, p.id, sceneId, 0), colors[0]);
    expect(_framePixel(ps, p.id, sceneId, 1), colors[1]);
    expect(_framePixel(ps, p.id, sceneId, 2), colors[1]);
    expect(_framePixel(ps, p.id, sceneId, 3), colors[2]);

    // 複製先だけ1画素変更しても、Copy-on-Writeにより複製元F1は変化しない。
    final copiedLayer = ps.layersOf(p.id, sceneId, 2).first;
    final copiedKey = ps.tileKeyFor(p.id, sceneId, 2, copiedLayer.id);
    final tm = ps.tileManagerOf(p.id);
    final tile = tm.getOrCreateTile(copiedKey, 0, 0);
    tm.setPixel(tile, 0, 0, 250, 200, 10, 255);
    expect(_framePixel(ps, p.id, sceneId, 2), [250, 200, 10, 255]);
    expect(_framePixel(ps, p.id, sceneId, 1), colors[1],
        reason: '複製先編集が元フレームへ逆流しないこと');

    // 比較しやすいよう複製先の先頭画素を緑へ戻してから、元F1を削除。
    tm.setPixel(tile, 0, 0, ...colors[1]);
    ps.removeFrame(p.id, sceneId, 1);
    expect(ps.frameCount(p.id, sceneId), 3);
    expect(_framePixel(ps, p.id, sceneId, 0), colors[0]);
    expect(_framePixel(ps, p.id, sceneId, 1), colors[1],
        reason: '旧F2（複製）がindex1へ正しく前詰めされること');
    expect(_framePixel(ps, p.id, sceneId, 2), colors[2],
        reason: '旧F3（青）がindex2へ正しく前詰めされること');
  });
}

List<int> _framePixel(
  ProjectService ps,
  String projectId,
  String sceneId,
  int frameIndex,
) {
  final layer = ps.layersOf(projectId, sceneId, frameIndex).first;
  final key = ps.tileKeyFor(projectId, sceneId, frameIndex, layer.id);
  final tile = ps.tileManagerOf(projectId).getTile(key, 0, 0);
  if (tile == null) return [0, 0, 0, 0];
  return [tile[0], tile[1], tile[2], tile[3]];
}
