import 'helpers/project_storage.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene_stack.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('フレーム複製・削除・再index後も実タイルが正しいフレームへ追従する', () async {
    final ps = ProjectService();
    await ps.init();
    final p = await ps.createProject(
      name: 'frame-pixel-audit',
      fps: 1,
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
    expect(
      _framePixel(ps, p.id, sceneId, 1),
      colors[1],
      reason: '複製先編集が元フレームへ逆流しないこと',
    );

    // 比較しやすいよう複製先の先頭画素を緑へ戻してから、元F1を削除。
    tm.setPixel(
      tile,
      0,
      0,
      colors[1][0],
      colors[1][1],
      colors[1][2],
      colors[1][3],
    );
    ps.removeFrame(p.id, sceneId, 1);
    expect(ps.frameCount(p.id, sceneId), 3);
    expect(_framePixel(ps, p.id, sceneId, 0), colors[0]);
    expect(
      _framePixel(ps, p.id, sceneId, 1),
      colors[1],
      reason: '旧F2（複製）がindex1へ正しく前詰めされること',
    );
    expect(
      _framePixel(ps, p.id, sceneId, 2),
      colors[2],
      reason: '旧F3（青）がindex2へ正しく前詰めされること',
    );
  });

  test(
    'scene copy and frame deletion preserve local material and ranges',
    () async {
      final projects = ProjectService();
      final history = UndoManager();
      projects.setUndoManager(history);
      addTearDown(projects.dispose);
      addTearDown(history.dispose);
      await projects.init();
      final project = await projects.createProject(
        name: 'Scene range audit',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0,
        exportWidth: 16,
        exportHeight: 12,
      );
      final id = project.id;
      final source = projects.scenesOf(id).single.id;
      for (var i = 0; i < 4; i++) {
        projects.addFrame(id, source);
      }
      final common = projects
          .addLayer(
            projectId: id,
            sceneId: source,
            frameIndex: 1,
            type: LayerType.common,
            name: 'Shared drawing',
          )
          .copyWith(
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: 2,
            rangeEnd: 4,
          );
      projects.updateLayer(
        projectId: id,
        sceneId: source,
        frameIndex: 1,
        layer: common,
      );
      final tiles = projects.tileManagerOf(id);
      final originalKey = projects.tileKeyFor(id, source, 1, common.id);
      tiles.setPixel(
        tiles.getOrCreateTile(originalKey, 0, 0),
        0,
        0,
        255,
        0,
        0,
        255,
      );

      projects.addLayerGroup(id, source, 'Group', [common.id]);
      final stack = SceneStack(
        order: [stackTrackKey(StackTrackKind.image, 0), kStackFrame],
      );
      projects.updateSceneStack(id, source, stack);
      projects.addTimelineMarker(id, source, 2, 'Beat');
      projects.addEffectFilter(
        id,
        source,
        const EffectFilterInstance(
          id: 'blur',
          type: EffectFilterType.gaussianBlur,
          startFrame: 1,
          endFrame: 3,
        ),
      );

      final copy = projects.duplicateScene(id, source)!;
      final duplicated = copy.frames[1].layers.singleWhere(
        (layer) => layer.name == common.name,
      );
      expect(duplicated.id, isNot(common.id));
      expect(copy.groups.single.memberLayerIds, [duplicated.id]);
      expect(copy.stack.order, stack.order);
      expect(copy.markers.single.frameIndex, 2);
      final duplicateKey = projects.tileKeyFor(id, copy.id, 2, duplicated.id);
      expect(tiles.getPixelColorAt(duplicateKey, 0, 0)?.toARGB32(), 0xffff0000);

      projects.removeFrame(id, source, 1);
      final scene = projects.sceneOf(id, source)!;
      final moved = projects
          .layersOf(id, source, 1)
          .singleWhere((l) => l.id == common.id);
      expect((moved.rangeStart, moved.rangeEnd), (2, 3));
      expect(
        projects.layersOf(id, source, 3).any((l) => l.id == common.id),
        isFalse,
      );
      expect(
        (
          scene.effectFilters.single.startFrame,
          scene.effectFilters.single.endFrame,
        ),
        (1, 2),
      );
      final homeKey = projects.tileKeyFor(id, source, 2, common.id);
      expect(tiles.getPixelColorAt(homeKey, 0, 0)?.toARGB32(), 0xffff0000);

      history.undo(projectId: id);
      expect(projects.sceneOf(id, source)!.frames.length, 5);
      expect(projects.sceneOf(id, source)!.effectFilters.single.endFrame, 3);
      history.redo(projectId: id);
      expect(projects.sceneOf(id, source)!.frames.length, 4);
      expect(tiles.getPixelColorAt(homeKey, 0, 0)?.toARGB32(), 0xffff0000);

      final narrower = moved.copyWith(rangeStart: 3, rangeEnd: 3);
      projects.updateLayer(
        projectId: id,
        sceneId: source,
        frameIndex: 1,
        layer: narrower,
      );
      expect(projects.storedLayersOf(id, source, 1), contains(narrower));
      expect(projects.layersOf(id, source, 1), isNot(contains(narrower)));
      expect(
        projects.stackedLayersOf(id, source, 1).layers,
        isNot(contains(narrower)),
      );
      expect(projects.layersOf(id, source, 2), contains(narrower));
      expect(tiles.getPixelColorAt(homeKey, 0, 0)?.toARGB32(), 0xffff0000);

      projects.removeEffectFilter(id, source, 'blur');
      final engine = ExportEngine();
      Future<img.Pixel> firstExportedPixel(int frame) async {
        final file = await engine.exportFrameImage(
          scenes: projects.scenesOf(id),
          tileManager: tiles,
          sceneId: source,
          frameIndex: frame,
          drawingWidth: tiles.canvasWidth,
          drawingHeight: tiles.canvasHeight,
          width: 16,
          height: 12,
          backgroundColor: 0,
          asJpeg: false,
        );
        return img.decodePng(await File(file).readAsBytes())!.getPixel(0, 0);
      }

      expect((await firstExportedPixel(1)).a, 0);
      final visible = await firstExportedPixel(2);
      expect((visible.r, visible.a), (255, 255));
    },
  );
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
