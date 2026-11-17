import 'helpers/project_storage.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/models/timeline_row_kind.dart';
import 'package:niarim/services/project_service.dart';

/// タイムラインのフレーム複数貼り付け（Ctrl+V）で使うインデックス補正式
/// （同一シーン内へ貼り付ける際、挿入済み件数の分だけ複製元のインデックスが
/// 後ろへずれることを補正する）を、ProjectService.insertDuplicatedFrameを
/// 実際に呼び出して検証する。各フレームの識別にはレイヤー名を使う。
void main() {
  useTemporaryProjectStorage();
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

  Future<void> expectSceneSaved(
    String path,
    bool Function(Scene) matches,
  ) async {
    for (var attempt = 0; attempt < 120; attempt++) {
      final saved = (await NiaproSerializer.load(path)).scenes.single;
      if (matches(saved)) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(
      (await NiaproSerializer.load(path)).scenes.single,
      predicate(matches),
    );
  }

  test('timeline metadata is written without leaving the timeline', () async {
    final ps = ProjectService();
    addTearDown(ps.dispose);
    await ps.init();
    final project = await ps.createProject(
      name: 'Timeline persistence',
      fps: 4,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final id = project.id;
    final scene = ps.scenesOf(id).single;
    final sceneId = scene.id;
    final path = '${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro';
    const keyframe = CameraKeyframe(frameIndex: 1, x: 30);
    const filter = EffectFilterInstance(
      id: 'test-blur',
      type: EffectFilterType.gaussianBlur,
      startFrame: 0,
      endFrame: 3,
      param1: 5,
    );
    final layerId = scene.frames.first.layers.first.id;

    ps.addCameraKeyframe(id, sceneId, keyframe);
    await expectSceneSaved(
      path,
      (s) => s.cameraKeyframes.singleOrNull?.frameIndex == 1,
    );
    final group = ps.addLayerGroup(id, sceneId, 'Group', [layerId]);
    await expectSceneSaved(path, (s) => s.groups.singleOrNull?.id == group.id);
    final marker = ps.addTimelineMarker(id, sceneId, 1, 'First');
    await expectSceneSaved(
      path,
      (s) => s.markers.singleOrNull?.id == marker.id,
    );
    ps.addEffectFilter(id, sceneId, filter);
    await expectSceneSaved(
      path,
      (s) => s.effectFilters.singleOrNull?.param1 == 5,
    );

    ps.updateCameraKeyframe(id, sceneId, 1, keyframe.copyWith(frameIndex: 2));
    ps.updateLayerGroup(id, sceneId, group.copyWith(name: 'Renamed'));
    ps.updateTimelineMarker(id, sceneId, marker.copyWith(comment: 'Edited'));
    ps.updateEffectFilter(id, sceneId, filter.copyWith(param1: 12));
    await expectSceneSaved(
      path,
      (s) =>
          s.cameraKeyframes.singleOrNull?.frameIndex == 2 &&
          s.groups.singleOrNull?.name == 'Renamed' &&
          s.markers.singleOrNull?.comment == 'Edited' &&
          s.effectFilters.singleOrNull?.param1 == 12,
    );

    ps.removeCameraKeyframe(id, sceneId, 2);
    ps.removeLayerGroup(id, sceneId, group.id);
    ps.removeTimelineMarker(id, sceneId, marker.id);
    ps.removeEffectFilter(id, sceneId, filter.id);
    await expectSceneSaved(
      path,
      (s) =>
          s.cameraKeyframes.isEmpty &&
          s.groups.isEmpty &&
          s.markers.isEmpty &&
          s.effectFilters.isEmpty,
    );
  });

  test('frame markers and camera keys follow their frames and undo', () async {
    final ps = ProjectService();
    final history = UndoManager();
    addTearDown(history.dispose);
    addTearDown(ps.dispose);
    await ps.init();
    ps.setUndoManager(history);
    final project = await ps.createProject(
      name: 'Frame anchors',
      fps: 5,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    final id = project.id;
    final sceneId = ps.scenesOf(id).single.id;
    final path = '${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro';
    ps.addTimelineMarker(id, sceneId, 1, 'Removed');
    ps.addTimelineMarker(id, sceneId, 4, 'Follow');
    ps.addTimelineMarker(id, sceneId, 4, 'Also follow');
    ps.addCameraKeyframe(id, sceneId, const CameraKeyframe(frameIndex: 1));
    ps.addCameraKeyframe(
      id,
      sceneId,
      const CameraKeyframe(frameIndex: 4, x: 9),
    );

    void expectAnchors(int index) {
      final scene = ps.scenesOf(id).single;
      expect(scene.cameraKeyframes.single.frameIndex, index);
      expect(scene.cameraKeyframes.single.x, 9);
      expect(scene.markers.map((m) => m.frameIndex), [index, index]);
      expect(scene.markers.map((m) => m.comment).toSet(), {
        'Follow',
        'Also follow',
      });
    }

    ps.removeFrame(id, sceneId, 1);
    expectAnchors(3);
    ps.duplicateFrame(id, sceneId, 0);
    expectAnchors(4);
    ps.reorderFrames(id, sceneId, [4, 0, 1, 2, 3]);
    expectAnchors(0);
    history.undo(projectId: id);
    expectAnchors(4);
    expect(ps.sceneFrameShrinkHasContent(id, sceneId, 3), isTrue);
    ps.setSceneFrameCount(id, sceneId, 3);
    await expectSceneSaved(
      path,
      (s) =>
          s.frames.length == 3 &&
          s.cameraKeyframes.isEmpty &&
          s.markers.isEmpty,
    );
    history.undo(projectId: id);
    expectAnchors(4);
    await expectSceneSaved(
      path,
      (s) =>
          s.frames.length == 5 &&
          s.cameraKeyframes.singleOrNull?.frameIndex == 4 &&
          s.markers.length == 2 &&
          s.markers.every((m) => m.frameIndex == 4),
    );
  });

  test(
    'project settings and changes during a different project automation remain undoable',
    () async {
      final ps = ProjectService();
      final history = UndoManager();
      addTearDown(history.dispose);
      addTearDown(ps.dispose);
      await ps.init();
      ps.setUndoManager(history);
      Future<String> create(String name) async => (await ps.createProject(
        name: name,
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      )).id;
      final first = await create('First');
      final second = await create('Second');
      final scene = ps.scenesOf(first).first.id;
      final finish = Completer<void>();
      final automation = ps.editProjectWithAutomation(
        first,
        'Recipe',
        () async {
          await finish.future;
          ps.addFrame(first, scene);
        },
      );
      final tags = ['Test'];
      await ps.setProjectTags(second, tags);
      tags.clear();
      await ps.setEnabledAutofillPresetIds(second, ['preset']);
      await ps.setEnabledAutofillPresetIds(second, ['preset']);
      finish.complete();
      await automation;

      Project project() => ps.projects.firstWhere((p) => p.id == second);
      expect(project().tags, ['Test']);
      history.undo(projectId: second);
      expect(project().enabledAutofillPresetIds, isNull);
      expect(project().tags, ['Test']);
      history.undo(projectId: second);
      expect(project().tags, isEmpty);
      expect(history.canUndoFor(second), isFalse);
      history.redo(projectId: second);
      history.redo(projectId: second);
      expect(project().tags, ['Test']);
      expect(project().enabledAutofillPresetIds, ['preset']);
      expect(ps.frameCount(first, scene), 2);
      history.undo(projectId: first);
      expect(ps.frameCount(first, scene), 1);
      expect(project().tags, ['Test']);
      await ps.saveProject(first);
      await ps.saveProject(second);
    },
  );

  test(
    'cutting a frame across scenes carries its anchors exactly once',
    () async {
      final ps = ProjectService();
      final history = UndoManager();
      addTearDown(history.dispose);
      addTearDown(ps.dispose);
      await ps.init();
      ps.setUndoManager(history);
      final project = await ps.createProject(
        name: 'Cut anchors',
        fps: 3,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      final id = project.id;
      final source = ps.scenesOf(id).single.id;
      final target = ps.addScene(id).id;
      final marker = ps.addTimelineMarker(id, source, 1, 'Move me');
      ps.addCameraKeyframe(
        id,
        source,
        const CameraKeyframe(frameIndex: 1, zoom: 2),
      );
      ps.editTimeline(id, 'Cut frame', () {
        ps.insertDuplicatedFrame(
          projectId: id,
          sourceSceneId: source,
          sourceFrameIndex: 1,
          targetSceneId: target,
          insertAt: 0,
          transferFrameAnchors: true,
        );
        ps.removeFrame(id, source, 1);
      });
      expect(ps.timelineMarkersOf(id, source), isEmpty);
      expect(ps.cameraKeyframesOf(id, source), isEmpty);
      expect(ps.timelineMarkersOf(id, target).single.id, marker.id);
      expect(ps.timelineMarkersOf(id, target).single.frameIndex, 0);
      expect(ps.cameraKeyframesOf(id, target).single.frameIndex, 0);
      expect(ps.cameraKeyframesOf(id, target).single.zoom, 2);
      history.undo(projectId: id);
      expect(ps.timelineMarkersOf(id, source).single.frameIndex, 1);
      expect(ps.cameraKeyframesOf(id, source).single.frameIndex, 1);
      expect(ps.timelineMarkersOf(id, target), isEmpty);
      expect(ps.cameraKeyframesOf(id, target), isEmpty);
      await ps.saveProject(id);
    },
  );

  test(
    'pasting before the source copies the pixels from its new index',
    () async {
      final ps = ProjectService();
      addTearDown(ps.dispose);
      await ps.init();
      final project = await ps.createProject(
        name: 'Paste pixels',
        fps: 3,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      final id = project.id;
      final scene = ps.scenesOf(id).single.id;
      final manager = ps.tileManagerOf(id);
      for (final (index, red) in [(1, 27), (2, 145)]) {
        final layerId = ps.layersOf(id, scene, index).first.id;
        final key = ps.tileKeyFor(id, scene, index, layerId);
        manager.getOrCreateTile(key, 0, 0).setRange(0, 4, [red, 0, 0, 255]);
      }
      ps.insertDuplicatedFrame(
        projectId: id,
        sourceSceneId: scene,
        sourceFrameIndex: 2,
        targetSceneId: scene,
        insertAt: 0,
      );
      final pastedLayer = ps.layersOf(id, scene, 0).first.id;
      final key = ps.tileKeyFor(id, scene, 0, pastedLayer);
      expect(manager.getTile(key, 0, 0)?.take(4), [145, 0, 0, 255]);
    },
  );

  test(
    'switching between open projects keeps their undo and redo separate',
    () async {
      final ps = ProjectService();
      final history = UndoManager();
      addTearDown(history.dispose);
      addTearDown(ps.dispose);
      await ps.init();
      ps.setUndoManager(history);
      Future<String> create(String name) async => (await ps.createProject(
        name: name,
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      )).id;
      final a = await create('First');
      final b = await create('Second');
      final sceneA = ps.scenesOf(a).first.id;
      final sceneB = ps.scenesOf(b).first.id;
      history.selectProject(a);
      ps.addFrame(a, sceneA);
      history.undo();
      expect(history.canRedo, isTrue);
      history.selectProject(b);
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      ps.addFrame(b, sceneB);
      history.selectProject(a);
      history.redo();
      expect(ps.frameCount(a, sceneA), 2);
      expect(ps.frameCount(b, sceneB), 2);
      history.selectProject(b);
      history.undo();
      expect(ps.frameCount(a, sceneA), 2);
      expect(ps.frameCount(b, sceneB), 1);
      await ps.saveProject(a);
      await ps.saveProject(b);
    },
  );

  test(
    'audio clip history restores ranges, duplicates and removed rows',
    () async {
      final ps = ProjectService();
      final history = UndoManager();
      addTearDown(history.dispose);
      addTearDown(ps.dispose);
      await ps.init();
      ps.setUndoManager(history);
      final project = await ps.createProject(
        name: 'Audio clip history',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      final id = project.id;
      final scene = ps.scenesOf(id).first.id;
      const rowKind = TimelineRowKind.audio;
      const clip = AudioClip(
        id: 'source',
        label: 'Audio',
        materialId: 'sound',
        startFrame: 0,
        lengthFrames: 4,
        trackRow: 1,
      );
      List<AudioClip> current() => ps.audioClipsOf(id, scene);
      int rows() => ps.rowNamesOf(id, scene, rowKind).length;

      ps.editTimeline(id, 'Add clip and row', () {
        ps.addTrackRow(id, scene, rowKind);
        ps.addAudioClip(id, scene, clip);
      }, changesTiles: false);
      expect(history.undoCount, 1);
      expect(rows(), 2);
      history.undo();
      expect(current(), isEmpty);
      expect(rows(), 1);
      expect(ps.isMaterialUsed(id, 'sound'), isTrue);
      history.redo();

      final moved = clip.copyWith(
        startFrame: 2,
        lengthFrames: 3,
        sourceStartFrame: 1,
      );
      ps.updateAudioClip(id, scene, moved);
      expect(current().single, moved);
      history.undo();
      expect(current().single, clip);
      history.redo();
      expect(current().single, moved);

      const duplicate = AudioClip(
        id: 'duplicate',
        label: 'Audio',
        materialId: 'sound',
        startFrame: 6,
        lengthFrames: 3,
        sourceStartFrame: 1,
        trackRow: 1,
      );
      ps.addAudioClip(id, scene, duplicate);
      history.undo();
      expect(current(), [moved]);
      history.redo();
      expect(current(), [moved, duplicate]);

      ps.editTimeline(id, 'Delete clips and empty row', () {
        ps.removeAudioClip(id, scene, moved.id);
        ps.removeAudioClip(id, scene, duplicate.id);
        ps.removeTrackRow(id, scene, rowKind, 1);
      }, changesTiles: false);
      expect(current(), isEmpty);
      expect(rows(), 1);
      expect(ps.isMaterialUsed(id, 'sound'), isTrue);
      history.undo();
      expect(current(), [moved, duplicate]);
      expect(rows(), 2);
      history.redo();
      history.clear();
      expect(ps.isMaterialUsed(id, 'sound'), isFalse);
      expect(current(), isEmpty);
      expect(rows(), 1);
      await ps.saveProject(id);
    },
  );

  test(
    'timeline frame, camera and filter edits share one ordered history',
    () async {
      final ps = ProjectService();
      final history = UndoManager();
      addTearDown(history.dispose);
      addTearDown(ps.dispose);
      await ps.init();
      ps.setUndoManager(history);
      final project = await ps.createProject(
        name: 'Timeline history',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      final id = project.id;
      final scene = ps.scenesOf(id).first.id;
      final count = ps.frameCount(id, scene);
      const filter = EffectFilterInstance(
        id: 'test-blur',
        type: EffectFilterType.gaussianBlur,
        startFrame: 0,
        endFrame: 5,
      );

      ps.addFrame(id, scene);
      ps.insertDuplicatedFrame(
        projectId: id,
        sourceSceneId: scene,
        sourceFrameIndex: 0,
        targetSceneId: scene,
        insertAt: 1,
      );
      ps.addCameraKeyframe(
        id,
        scene,
        const CameraKeyframe(frameIndex: 1, x: 30),
      );
      ps.addEffectFilter(id, scene, filter);
      expect(history.undoCount, 4);
      expect(ps.frameCount(id, scene), count + 2);

      history.undo();
      expect(ps.effectFiltersOf(id, scene), isEmpty);
      history.undo();
      expect(ps.cameraKeyframesOf(id, scene), isEmpty);
      history.undo();
      expect(ps.frameCount(id, scene), count + 1);
      history.undo();
      expect(ps.frameCount(id, scene), count);

      for (var i = 0; i < 4; i++) {
        history.redo();
      }
      expect(ps.frameCount(id, scene), count + 2);
      expect(ps.cameraKeyframesOf(id, scene).single.x, 30);
      expect(ps.effectFiltersOf(id, scene).single, filter);
      await ps.saveProject(id);
    },
  );

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
    expect(frameTags(ps, project.id, sceneId), ['F0', 'F1', 'F2', 'F3']);

    // フレーム1・3をコピーし、カーソル位置2（F1とF2の間）へ貼り付ける。
    pasteFrames(ps, project.id, sceneId, sceneId, [1, 3], 2);

    expect(frameTags(ps, project.id, sceneId), [
      'F0',
      'F1',
      'F1',
      'F3',
      'F2',
      'F3',
    ]);
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

    expect(frameTags(ps, project.id, targetScene.id), ['T0', 'S0', 'S1']);
    // ソース側は貼り付け（コピー）のみでは変化しない。
    expect(frameTags(ps, project.id, sourceSceneId), ['S0', 'S1']);
  });
}
