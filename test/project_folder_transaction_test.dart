import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/folder_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store(super.data) : super.withData();
  bool reject = false;
  Completer<void>? gate;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.project_folders' || key == 'flutter.shared_folders') {
      final pending = gate;
      gate = null;
      if (pending != null) await pending.future;
      if (reject) return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectService service;
  late _Store store;
  late Directory dir;
  late SharedPreferencesStorePlatform previous;
  setUp(() async {
    SharedPreferences.resetStatic();
    previous = SharedPreferencesStorePlatform.instance;
    store = _Store({});
    SharedPreferencesStorePlatform.instance = store;
    dir = Directory.systemTemp.createTempSync('project-folder-transaction-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    service = ProjectService();
    await service.init();
  });
  tearDown(() {
    service.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    dir.deleteSync(recursive: true);
  });
  Future<Project> project(String name) => service.createProject(
    name: name,
    fps: 1,
    durationSeconds: 1,
    backgroundColor: 0xFF123456,
    exportWidth: 64,
    exportHeight: 64,
  );
  Future<File> file(String id) async =>
      File('${await NiaproSerializer.projectsBasePath()}/$id/$id.niapro');
  Future<ProjectService> cold() async {
    SharedPreferences.resetStatic();
    final next = ProjectService();
    await next.init();
    addTearDown(next.dispose);
    return next;
  }

  test(
    'queued create/edit/reparent wait for acknowledgement and retain earlier results',
    () async {
      final gate = Completer<void>();
      store.gate = gate;
      final first = service.createFolder('FIRST');
      final second = service.createFolder('SECOND');
      expect(service.folders, isEmpty);
      gate.complete();
      final folder = await first;
      final parent = await second;
      await Future.wait([
        service.editFolder(folder.id, name: 'RENAMED', color: 0xFF123456),
        service.moveFolderTo(folder.id, parent.id),
      ]);
      final saved = (await cold()).folders.firstWhere((f) => f.id == folder.id);
      expect(saved.name, 'RENAMED');
      expect(saved.color, 0xFF123456);
      expect(saved.parentFolderId, parent.id);
    },
  );

  test(
    'rejected queue remains usable and preserves name/color until retry',
    () async {
      final folder = await service.createFolder('ORIGINAL');
      store.reject = true;
      await expectLater(
        service.editFolder(folder.id, name: 'NEW', color: 0xFFAA3322),
        throwsA(isA<FolderSaveException>()),
      );
      expect(service.folders.single.name, 'ORIGINAL');
      expect(service.folders.single.color, isNull);
      store.reject = false;
      await service.editFolder(folder.id, name: 'NEW', color: 0xFFAA3322);
      final saved = (await cold()).folders.single;
      expect(saved.name, 'NEW');
      expect(saved.color, 0xFFAA3322);
    },
  );

  test(
    'membership retains unknown metadata and every other archive entry',
    () async {
      final p = await project('KEEP');
      final source = await file(p.id);
      final archive = ZipDecoder().decodeBytes(source.readAsBytesSync());
      final manifest =
          jsonDecode(
                utf8.decode(
                  archive.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map<String, dynamic>;
      manifest['futureField'] = {
        'nested': [1, 'KEEP'],
      };
      archive.addFile(
        ArchiveFile('manifest.json', 0, utf8.encode(jsonEncode(manifest))),
      );
      archive.addFile(ArchiveFile('Future/opaque.bin', 0, [0, 1, 255, 34]));
      source.writeAsBytesSync(ZipEncoder().encode(archive)!);
      final before = ZipDecoder().decodeBytes(source.readAsBytesSync());
      final folder = await service.createFolder('DESTINATION');
      await service.moveToFolder(p.id, folder.id);
      final after = ZipDecoder().decodeBytes(source.readAsBytesSync());
      expect(
        after.files.map((e) => e.name).toSet(),
        before.files.map((e) => e.name).toSet(),
      );
      for (final entry in before.files.where(
        (e) => e.name != 'manifest.json',
      )) {
        expect(
          after.findFile(entry.name)!.content,
          entry.content,
          reason: entry.name,
        );
      }
      final next =
          jsonDecode(
                utf8.decode(
                  after.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map<String, dynamic>;
      expect(next, {...manifest, 'folderId': folder.id});
    },
  );

  test(
    'background save requested during move cannot restore the previous folder',
    () async {
      final p = await project('DRAWING');
      final folder = await service.createFolder('DESTINATION');
      final moving = service.moveToFolder(p.id, folder.id);
      await service.setProjectTags(p.id, ['new drawing metadata']);
      await moving;
      await service.saveProject(p.id);
      final saved = await NiaproSerializer.load((await file(p.id)).path);
      expect(saved.project.folderId, folder.id);
      expect(saved.project.tags, ['new drawing metadata']);
    },
  );

  for (final shared in [false, true]) {
    test(
      '${shared ? 'shared' : 'project'} deletion retains folder and reports partial I/O; retry and cold reload finish',
      () async {
        final original = await project('ONE');
        final two = await project('TWO');
        final contents = <Project>[];
        if (shared) {
          for (final p in [original, two]) {
            contents.add(
              await service.importSharedProject(
                await NiaproSerializer.load((await file(p.id)).path),
              ),
            );
          }
        } else {
          contents.addAll([original, two]);
        }
        final folder = shared
            ? await service.createSharedFolder('FOLDER')
            : await service.createFolder('FOLDER');
        for (final p in contents) {
          if (shared) {
            await service.moveToSharedFolder(p.id, folder.id);
          } else {
            await service.moveToFolder(p.id, folder.id);
          }
        }
        final source = await file(contents.last.id);
        final backup = source.renameSync('${source.path}.backup');
        Directory(source.path).createSync();
        Future<void> remove() => shared
            ? service.deleteSharedFolder(folder.id)
            : service.deleteFolder(folder.id);
        await expectLater(
          remove(),
          throwsA(
            isA<FolderSaveException>().having(
              (e) => e.partiallySaved,
              'partial',
              true,
            ),
          ),
        );
        expect(
          (shared ? service.sharedFolders : service.folders).single.id,
          folder.id,
        );
        final partial = service.projects.firstWhere(
          (p) => p.id == contents.first.id,
        );
        expect(shared ? partial.sharedFolderId : partial.folderId, isNull);
        Directory(source.path).deleteSync();
        backup.renameSync(source.path);
        await remove();
        final restored = await cold();
        expect(shared ? restored.sharedFolders : restored.folders, isEmpty);
        for (final p in contents) {
          final saved = restored.projects.firstWhere((v) => v.id == p.id);
          expect(shared ? saved.sharedFolderId : saved.folderId, isNull);
          expect(saved.name, p.name);
          expect(saved.backgroundColor, p.backgroundColor);
        }
      },
    );
  }

  test(
    'preference failure after contents moved retains folder, exposes partial result, and retries',
    () async {
      final p = await project('KEEP');
      final folder = await service.createFolder('FOLDER');
      await service.moveToFolder(p.id, folder.id);
      store.reject = true;
      await expectLater(
        service.deleteFolder(folder.id),
        throwsA(
          isA<FolderSaveException>().having(
            (e) => e.partiallySaved,
            'partial',
            true,
          ),
        ),
      );
      expect(service.folders.single.id, folder.id);
      expect(service.projects.single.folderId, isNull);
      final partial = await cold();
      expect(partial.folders.single.id, folder.id);
      expect(partial.projects.single.folderId, isNull);
      store.reject = false;
      await service.deleteFolder(folder.id);
      expect((await cold()).folders, isEmpty);
    },
  );

  test(
    'folder deletion updates trashed projects without discarding their archive data',
    () async {
      final p = await project('TRASH KEEP');
      final folder = await service.createFolder('FOLDER');
      await service.moveToFolder(p.id, folder.id);
      await service.deleteProject(p.id);
      await service.deleteFolder(folder.id);
      final restored = await cold();
      expect(restored.trash.single.folderId, isNull);
      await restored.restoreProject(p.id);
      expect(restored.projects.single.folderId, isNull);
      expect(restored.projects.single.name, p.name);
      expect(restored.scenesOf(p.id), isNotEmpty);
    },
  );

  test(
    'missing project file rejects a move without publishing; restored file can retry',
    () async {
      final p = await project('KEEP');
      final folder = await service.createFolder('FOLDER');
      final source = await file(p.id);
      final backup = source.renameSync('${source.path}.backup');
      await expectLater(
        service.moveToFolder(p.id, folder.id),
        throwsA(isA<FolderSaveException>()),
      );
      expect(service.projects.single.folderId, isNull);
      backup.renameSync(source.path);
      await service.moveToFolder(p.id, folder.id);
      expect((await cold()).projects.single.folderId, folder.id);
    },
  );
}
