import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FolderStore extends InMemorySharedPreferencesStore {
  _FolderStore(super.data) : super.withData();
  bool reject = false;
  bool throws = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject &&
        const {
          'flutter.project_folders',
          'flutter.shared_folders',
        }.contains(key)) {
      if (throws) throw PlatformException(code: 'audit-folder-store-failure');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final evidence = Directory('build/audit-s24');
  final results = <String, Object?>{};
  final audit = ProjectFolder(
    id: 'audit-folder',
    name: 'AUDIT',
    color: 0xFF112233,
    createdAt: DateTime.utc(2026, 10, 29),
  );
  final parent = ProjectFolder(
    id: 'audit-parent',
    name: 'PARENT',
    createdAt: DateTime.utc(2026, 10, 29),
  );
  final shared = ProjectFolder(
    id: 'audit-shared',
    name: 'SHARED',
    createdAt: DateTime.utc(2026, 10, 29),
  );

  Map<String, Object> snapshot(ProjectService service) => {
    'folders': service.folders.map((f) => f.toJson()).toList(),
    'sharedFolders': service.sharedFolders.map((f) => f.toJson()).toList(),
  };

  void persist(String name, Object row) {
    results[name] = row;
    evidence.createSync(recursive: true);
    File('${evidence.path}/prefs-after-results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'head': '0c02171d46b08d8ed297f158dc99e295ed8fcb67',
        'scope': 'controlled preference store boundary, not native UI',
        'results': results,
      }),
    );
  }

  Future<({ProjectService service, _FolderStore store, Directory directory})>
  open() async {
    SharedPreferences.resetStatic();
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _FolderStore({
      'flutter.project_folders': jsonEncode([audit.toJson(), parent.toJson()]),
      'flutter.shared_folders': jsonEncode([shared.toJson()]),
    });
    SharedPreferencesStorePlatform.instance = store;
    final directory = Directory.systemTemp.createTempSync(
      'audit-project-folders-',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final service = ProjectService();
    await service.init();
    addTearDown(() {
      service.dispose();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previous;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    return (service: service, store: store, directory: directory);
  }

  for (final throws in [false, true]) {
    for (final operation in [
      'create',
      'rename',
      'color',
      'favorite',
      'reparent',
      'delete',
      'shared-create',
      'shared-rename',
      'shared-delete',
    ]) {
      test('AFTER $operation / ${throws ? 'throw' : 'false'}', () async {
        final env = await open();
        final before = snapshot(env.service);
        var notifications = 0;
        env.service.addListener(() => notifications++);
        env.store
          ..reject = true
          ..throws = throws;
        Object? error;
        try {
          switch (operation) {
            case 'create':
              await env.service.createFolder('NEW');
            case 'rename':
              await env.service.renameFolder(audit.id, 'NEW');
            case 'color':
              await env.service.setFolderColor(audit.id, 0xFF665599);
            case 'favorite':
              await env.service.toggleFolderFavorite(audit.id);
            case 'reparent':
              await env.service.moveFolderTo(audit.id, parent.id);
            case 'delete':
              await env.service.deleteFolder(audit.id);
            case 'shared-create':
              await env.service.createSharedFolder('NEW');
            case 'shared-rename':
              await env.service.renameSharedFolder(shared.id, 'NEW');
            case 'shared-delete':
              await env.service.deleteSharedFolder(shared.id);
          }
        } catch (caught) {
          error = caught;
        }
        final memory = snapshot(env.service);
        final cached = await SharedPreferences.getInstance();
        expect(
          jsonDecode(cached.getString('project_folders')!),
          before['folders'],
        );
        expect(
          jsonDecode(cached.getString('shared_folders')!),
          before['sharedFolders'],
        );
        SharedPreferences.resetStatic();
        final cold = ProjectService();
        await cold.init();
        final restored = snapshot(cold);
        cold.dispose();
        final row = {
          'operation': operation,
          'storeFailure': throws ? 'throw' : 'false',
          'errorReturned': error?.runtimeType.toString(),
          'notifications': notifications,
          'before': before,
          'memoryAfter': memory,
          'coldReload': restored,
          'memoryPreserved': jsonEncode(memory) == jsonEncode(before),
          'coldPreserved': jsonEncode(restored) == jsonEncode(before),
        };
        persist('$operation/${throws ? 'throw' : 'false'}', row);
        expect(error, isNotNull, reason: jsonEncode(row));
        expect(memory, before);
        expect(restored, before);
        expect(notifications, 0);
      });
    }
  }

  test(
    'AFTER healthy project-folder deletion survives a cold project reload',
    () async {
      final env = await open();
      final project = await env.service.createProject(
        name: 'AUDIT real persisted project',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      await env.service.moveToFolder(project.id, audit.id);
      await env.service.saveProject(project.id);
      final base = await NiaproSerializer.projectsBasePath();
      final file = File('$base/${project.id}/${project.id}.niapro');
      final savedBefore = await NiaproSerializer.load(file.path);
      expect(
        savedBefore.project.folderId,
        audit.id,
        reason: 'Persist the original association before deleting',
      );
      final originalSize = file.lengthSync();
      final originalBytes = file.readAsBytesSync();
      File(
        '${evidence.path}/project-before-delete.niapro',
      ).writeAsBytesSync(originalBytes);
      await env.service.deleteFolder(audit.id);
      final memoryFolder = env.service.projects.single.folderId;
      File(
        '${evidence.path}/project-after-delete.niapro',
      ).writeAsBytesSync(file.readAsBytesSync());
      final savedAfter = await NiaproSerializer.load(file.path);
      SharedPreferences.resetStatic();
      final cold = ProjectService();
      await cold.init();
      final row = {
        'projectId': project.id,
        'memoryFolderAfterDelete': memoryFolder,
        'diskFolderAfterDelete': savedAfter.project.folderId,
        'coldFolder': cold.projects.single.folderId,
        'deletedFolderStillExists': cold.folders.any((f) => f.id == audit.id),
        'projectStillLoaded': cold.projects.length == 1,
        'fileStillExists': file.existsSync(),
        'fileBytesBefore': originalSize,
        'fileBytesAfter': file.lengthSync(),
        'projectFileUnchanged':
            base64Encode(originalBytes) == base64Encode(file.readAsBytesSync()),
      };
      cold.dispose();
      File(
        '${evidence.path}/delete-cold-reload-after.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(row));
      expect(savedAfter.project.folderId, isNull, reason: jsonEncode(row));
      expect(row['coldFolder'], isNull);
    },
  );
}
