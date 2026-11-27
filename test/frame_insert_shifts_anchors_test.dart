// コマを途中に複製・削除したら、後ろのコマを指すもの（共通レイヤーの表示範囲、
// レイヤーとグループのキーフレーム）も一緒にずらす。
//
// 実際に使ってみたとき（2026-11-27）、F12を複製しても共通レイヤーの範囲
// 「星 10〜23」「流れ星 10〜25」とキーフレームが元のコマ番号のままで、後ろの
// 絵とレイヤーの動きが1コマずれた（最後のコマから流れ星が消えた）。
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('duplicating and deleting a frame moves ranges and keyframes', () async {
    final ps = ProjectService();
    await ps.init();
    final undo = UndoManager();
    ps.setUndoManager(undo);
    final p = await ps.createProject(
      name: 'shift anchors',
      fps: 6,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 32,
      exportHeight: 32,
    );
    final scene = ps.scenesOf(p.id).first.id;
    expect(ps.frameCount(p.id, scene), 6);

    // A common layer on frames 2..5 (1-based) moving from frame index 1 to 4.
    final star = ps.addLayer(
      projectId: p.id,
      sceneId: scene,
      frameIndex: 1,
      type: LayerType.normal,
      name: 'star',
    );
    ps.convertLayerToCommon(
      projectId: p.id,
      sceneId: scene,
      frameIndex: 1,
      layer: star.copyWith(
        keyframes: const [
          LayerKeyframe(frameIndex: 1, x: 0),
          LayerKeyframe(frameIndex: 4, x: 40),
        ],
      ),
      rangeMode: LayerRangeMode.frameRange,
      rangeStart: 2,
      rangeEnd: 5,
    );
    final local = ps.layersOf(p.id, scene, 3).first;
    final group = ps.addLayerGroup(p.id, scene, 'g', [local.id]);
    ps.updateLayerGroup(
      p.id,
      scene,
      group.copyWith(keyframes: const [LayerKeyframe(frameIndex: 3, scale: 2)]),
    );

    Layer starNow() => ps
        .scenesOf(p.id)
        .first
        .frames
        .expand((f) => f.layers)
        .firstWhere((l) => l.id == star.id);
    List<int> groupKeys() => ps
        .layerGroupsOf(p.id, scene)
        .single
        .keyframes
        .map((k) => k.frameIndex)
        .toList();

    // Duplicate frame index 2 (inside the range): it lands at index 3.
    ps.duplicateFrame(p.id, scene, 2);
    expect(ps.frameCount(p.id, scene), 7);
    expect((starNow().rangeStart, starNow().rangeEnd), (2, 6));
    expect(starNow().keyframes.map((k) => k.frameIndex), [1, 5]);
    expect(groupKeys(), [4]);

    // Undo puts everything back.
    undo.undo();
    expect(ps.frameCount(p.id, scene), 6);
    expect((starNow().rangeStart, starNow().rangeEnd), (2, 5));
    expect(starNow().keyframes.map((k) => k.frameIndex), [1, 4]);
    expect(groupKeys(), [3]);

    // Deleting frame index 2 pulls the later ones back by one.
    ps.removeFrame(p.id, scene, 2);
    expect((starNow().rangeStart, starNow().rangeEnd), (2, 4));
    expect(starNow().keyframes.map((k) => k.frameIndex), [1, 3]);
    expect(groupKeys(), [2]);
  });
}
