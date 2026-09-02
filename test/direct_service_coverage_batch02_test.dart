import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('niarim_save_tree_direct_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('slot save overwrites safely, reports used slots and reloads serialized node', () async {
    final ps = ProjectService();
    await ps.init();
    final project = await ps.createProject(
      name: 'save-tree-direct',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 48,
    );
    final scenes = ps.scenesOf(project.id);
    final service = SaveTreeService()..setSlotMax(5);

    final first = await service.saveToSlot(
      projectId: project.id,
      slotIndex: 2,
      project: project,
      scenes: scenes,
      tileManager: ps.tileManagerOf(project.id),
      comment: 'first',
    );
    expect(service.getUsedSlots(project.id), [2]);
    expect((await service.loadNode(project.id, first.id)), isNotNull);

    final second = await service.saveToSlot(
      projectId: project.id,
      slotIndex: 2,
      project: project,
      scenes: scenes,
      tileManager: ps.tileManagerOf(project.id),
      comment: 'second',
    );
    expect(second.id, isNot(first.id));
    expect(service.getNodes(project.id), hasLength(1));
    expect(service.getNodes(project.id).single.comment, 'second');
    expect(service.getUsedSlots(project.id), [2]);
    expect(await service.loadNode(project.id, first.id), isNull,
        reason: 'successful overwrite removes the superseded node file');
    expect(await service.loadNode(project.id, second.id), isNotNull);
  });

  test('tree parent/child relations, archive mode change and restore preserve nodes', () async {
    final ps = ProjectService();
    await ps.init();
    final project = await ps.createProject(
      name: 'save-tree-branch',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 48,
    );
    final scenes = ps.scenesOf(project.id);
    final service = SaveTreeService()..setTreeMode(true);

    final root = await service.saveAsChild(
      projectId: project.id,
      project: project,
      scenes: scenes,
      tileManager: ps.tileManagerOf(project.id),
      comment: 'root',
    );
    final childA = await service.saveAsChild(
      projectId: project.id,
      project: project,
      scenes: scenes,
      tileManager: ps.tileManagerOf(project.id),
      parentId: root.id,
      comment: 'A',
    );
    final childB = await service.saveAsChild(
      projectId: project.id,
      project: project,
      scenes: scenes,
      tileManager: ps.tileManagerOf(project.id),
      parentId: root.id,
      comment: 'B',
    );

    expect(service.getChildren(project.id, null).map((n) => n.id), [root.id]);
    expect(
      service.getChildren(project.id, root.id).map((n) => n.id).toSet(),
      {childA.id, childB.id},
    );

    await service.applyModeChange(
      projectId: project.id,
      keepIds: [root.id, childA.id],
      archive: true,
      newIsTreeMode: false,
      newSlotMax: 2,
    );
    expect(service.isTreeMode, isFalse);
    expect(service.slotMax, 2);
    expect(service.getNodes(project.id).map((n) => n.slotIndex), [0, 1]);
    expect(service.getArchivedNodes(project.id).map((n) => n.id), [childB.id]);

    await service.applyModeChange(
      projectId: project.id,
      keepIds: service.getNodes(project.id).map((n) => n.id).toList(),
      archive: false,
      newIsTreeMode: true,
    );
    expect(service.isTreeMode, isTrue);
    expect(service.getNodes(project.id).every((n) => n.slotIndex == -1), isTrue);

    service.restoreArchive(project.id);
    expect(service.getArchivedNodes(project.id), isEmpty);
    expect(service.getNodes(project.id).map((n) => n.id).toSet(),
        {root.id, childA.id, childB.id});

    await service.deleteNode(project.id, childB.id);
    expect(service.getNodes(project.id).any((n) => n.id == childB.id), isFalse);
    expect(await service.loadNode(project.id, childB.id), isNull);
  });
}
