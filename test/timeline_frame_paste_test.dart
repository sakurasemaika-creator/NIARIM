import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';

/// タイムラインのフレーム複数貼り付け（Ctrl+V）で使うインデックス補正式
/// （同一シーン内へ貼り付ける際、挿入済み件数の分だけ複製元のインデックスが
/// 後ろへずれることを補正する）を、ProjectService.insertDuplicatedFrameを
/// 実際に呼び出して検証する。各フレームの識別にはレイヤー名を使う。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// timeline_screen.dartの_confirmFramePasteと同じ計算式で、
  /// [sortedSourceIndices]のフレームを[targetSceneId]の[insertAt]位置へ
  /// 順番に貼り付ける。
  void pasteFrames(
    ProjectService ps,
    String projectId,
    String sourceSceneId,
    String targetSceneId,
    List<int> sortedSourceIndices,
    int insertAt,
  ) {
    var insertedSoFar = 0;
    for (final originalIdx in sortedSourceIndices) {
      final sameScene = sourceSceneId == targetSceneId;
      final effectiveSrcIdx = (sameScene && originalIdx >= insertAt)
          ? originalIdx + insertedSoFar
          : originalIdx;
      ps.insertDuplicatedFrame(
        projectId: projectId,
        sourceSceneId: sourceSceneId,
        sourceFrameIndex: effectiveSrcIdx,
        targetSceneId: targetSceneId,
        insertAt: insertAt + insertedSoFar,
      );
      insertedSoFar++;
    }
  }

  /// 各フレームの識別用に付与したレイヤー名（先頭レイヤー）の並びを返す。
  List<String> frameTags(ProjectService ps, String projectId, String sceneId) {
    final total = ps.frameCount(projectId, sceneId);
    return [
      for (int i = 0; i < total; i++)
        ps.layersOf(projectId, sceneId, i).first.name,
    ];
  }

  test('同一シーン内・複数フレーム貼り付けのインデックス補正が正しい', () async {
    final ps = ProjectService();
    await ps.init();
    final project = await ps.createProject(
      name: 'テスト',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final sceneId = ps.scenesOf(project.id).first.id;
    // フレーム0は既存。1〜3を追加して計4フレームにする。
    for (int i = 0; i < 3; i++) {
      ps.addFrame(project.id, sceneId);
    }
    for (int i = 0; i < 4; i++) {
      ps.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: i,
        type: LayerType.normal,
        name: 'F$i',
      );
    }
    expect(
      frameTags(ps, project.id, sceneId),
      ['F0', 'F1', 'F2', 'F3'],
    );

    // フレーム1・3をコピーし、カーソル位置2（F1とF2の間）へ貼り付ける。
    pasteFrames(ps, project.id, sceneId, sceneId, [1, 3], 2);

    expect(
      frameTags(ps, project.id, sceneId),
      ['F0', 'F1', 'F1', 'F3', 'F2', 'F3'],
    );
  });

  test('別シーンへのフレーム貼り付けはインデックス補正が不要', () async {
    final ps = ProjectService();
    await ps.init();
    final project = await ps.createProject(
      name: 'テスト2',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final sourceSceneId = ps.scenesOf(project.id).first.id;
    ps.addFrame(project.id, sourceSceneId);
    for (int i = 0; i < 2; i++) {
      ps.addLayer(
        projectId: project.id,
        sceneId: sourceSceneId,
        frameIndex: i,
        type: LayerType.normal,
        name: 'S$i',
      );
    }
    final targetScene = ps.addScene(project.id);
    ps.addLayer(
      projectId: project.id,
      sceneId: targetScene.id,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'T0',
    );

    // ソースシーンのフレーム0・1を、ターゲットシーンの末尾(1)へ貼り付ける。
    pasteFrames(ps, project.id, sourceSceneId, targetScene.id, [0, 1], 1);

    expect(
      frameTags(ps, project.id, targetScene.id),
      ['T0', 'S0', 'S1'],
    );
    // ソース側は貼り付け（コピー）のみでは変化しない。
    expect(frameTags(ps, project.id, sourceSceneId), ['S0', 'S1']);
  });
}
