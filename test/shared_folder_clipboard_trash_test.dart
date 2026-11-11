import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim-shared-trash-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Project> incoming(ProjectService service, String name) async {
    final project = await service.importSharedProject(NiaproData(
      project: Project(
        id: 'source',
        name: name,
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        totalWorkSeconds: 0,
      ),
      scenes: const [],
      tileData: const {},
    ));
    await service.saveProject(project.id);
    return project;
  }

  test('received folder is trashed and restored with its projects', () async {
    final service = ProjectService();
    await service.init();
    final folder = await service.createSharedFolder('受信作品');
    final project = await incoming(service, '海');
    await service.moveToSharedFolder(project.id, folder.id);
    final saved = await service.moveFolderToTrash(folder.id, shared: true);
    expect(saved, isNotNull);
    expect(saved!.isShared, isTrue);
    expect(saved.projectIds, [project.id]);
    expect(service.sharedFolders, isEmpty);
    expect(service.shared, isEmpty);
    expect(service.trash.map((p) => p.id), contains(project.id));

    // Cold start must load the folder from the correct (received) collection.
    final reopened = ProjectService();
    await reopened.init();
    expect(reopened.trashedFolders.single.isShared, isTrue);
    expect(reopened.looseTrash, isEmpty);
    await reopened.restoreTrashedFolder(folder.id);
    expect(reopened.trashedFolders, isEmpty);
    expect(reopened.sharedFolders.single.id, folder.id);
    expect(reopened.shared.single.sharedFolderId, folder.id);
    expect(reopened.shared.single.name, '海');
    expect(reopened.trash, isEmpty);
    service.dispose();
    reopened.dispose();
  });

  test('copying a received folder duplicates all contents in the new folder',
      () async {
    final service = ProjectService();
    await service.init();
    final folder = await service.createSharedFolder('受信作品');
    final first = await incoming(service, '海');
    final second = await incoming(service, '空');
    await service.moveToSharedFolder(first.id, folder.id);
    await service.moveToSharedFolder(second.id, folder.id);

    final copied = await service.duplicateSharedFolderWithContents(folder.id);
    expect(copied.id, isNot(folder.id));
    expect(service.sharedFolders, hasLength(2));
    expect(service.shared.where((p) => p.sharedFolderId == copied.id)
        .map((p) => p.name).toSet(), {'海 (コピー)', '空 (コピー)'});
    expect(service.shared.where((p) => p.sharedFolderId == folder.id)
        .map((p) => p.name).toSet(), {'海', '空'});
    service.dispose();
  });

  test('favorite received project prevents trashing its entire folder',
      () async {
    final service = ProjectService();
    await service.init();
    final folder = await service.createSharedFolder('保存');
    final project = await incoming(service, '重要');
    await service.moveToSharedFolder(project.id, folder.id);
    await service.setFavorite(project.id, true);
    await expectLater(
      service.moveFolderToTrash(folder.id, shared: true),
      throwsA(isA<FavoriteProjectDeleteException>()),
    );
    expect(service.sharedFolders.single.id, folder.id);
    expect(service.shared.single.id, project.id);
    expect(service.trash, isEmpty);
    service.dispose();
  });
}
