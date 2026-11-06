import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart' show ProjectFolder;
import 'package:niarim/services/work_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'helpers/controlled_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final folder = ProjectFolder(
    id: 'audit-folder',
    name: 'AUDIT',
    createdAt: DateTime.utc(2026, 10, 28),
  );
  const filename = 'AUDIT_keep.gif';
  const foldersKey = 'flutter.work_folders';
  const mapKey = 'flutter.work_file_folder_map';

  Future<({ControlledPreferencesStore store, WorkFolderService service})> open({
    bool inside = false,
    Object? rawMap,
    bool autoDispose = true,
  }) async {
    SharedPreferences.resetStatic();
    final previous = SharedPreferencesStorePlatform.instance;
    final store = ControlledPreferencesStore({
      foldersKey: jsonEncode([folder.toJson()]),
      mapKey: rawMap ?? jsonEncode(inside ? {filename: folder.id} : {}),
    });
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previous;
    });
    final service = WorkFolderService();
    await service.init();
    if (autoDispose) addTearDown(service.dispose);
    return (store: store, service: service);
  }

  Future<void> sameAfterReload(
    WorkFolderService expected, {
    bool cold = true,
  }) async {
    if (cold) SharedPreferences.resetStatic();
    final restored = WorkFolderService();
    await restored.init();
    expect(
      restored.folders.map((f) => f.toJson()).toList(),
      expected.folders.map((f) => f.toJson()).toList(),
    );
    expect(restored.folderIdOf(filename), expected.folderIdOf(filename));
    restored.dispose();
  }

  for (final throws in [false, true]) {
    for (final operation in ['move', 'create', 'rename', 'delete']) {
      test(
        'rejected $operation (${throws ? 'throw' : 'false'}) preserves cached and cold state',
        () async {
          final env = await open(inside: operation == 'delete');
          final original = await env.store.getAll();
          var notifications = 0;
          env.service.addListener(() => notifications++);
          env.store
            ..failWrites = true
            ..throwOnFailure = throws;
          Future<void> change() async {
            switch (operation) {
              case 'move':
                await env.service.moveFileToFolder(filename, folder.id);
              case 'create':
                await env.service.createFolder('NEW');
              case 'rename':
                await env.service.renameFolder(folder.id, 'NEW');
              case 'delete':
                await env.service.deleteFolder(folder.id);
            }
          }

          await expectLater(
            change(),
            throwsA(
              isA<WorkFolderSaveException>().having(
                (e) => e.partiallySaved,
                'partiallySaved',
                false,
              ),
            ),
          );
          expect(await env.store.getAll(), original);
          expect(env.service.folders.single.name, 'AUDIT');
          expect(
            env.service.folderIdOf(filename),
            operation == 'delete' ? folder.id : null,
          );
          expect(notifications, 0);
          await sameAfterReload(env.service, cold: false);
          await sameAfterReload(env.service);
        },
      );
    }
  }

  test(
    'successful CRUD preserves existing keys and all folder metadata',
    () async {
      final env = await open();
      final created = await env.service.createFolder('NEW');
      await env.service.renameFolder(created.id, 'RENAMED');
      await env.service.moveFileToFolder(filename, created.id);
      await sameAfterReload(env.service);
      await env.service.deleteFolder(created.id);
      expect(env.service.folderIdOf(filename), isNull);
      expect(env.service.folders.single.toJson(), folder.toJson());
      await sameAfterReload(env.service);
      expect((await env.store.getAll()).keys.toSet(), {foldersKey, mapKey});
    },
  );

  test(
    'delete rolls back a completed association write when folder persistence fails',
    () async {
      final env = await open(inside: true);
      final before = await env.store.getAll();
      env.store.reject = (key, value) => key == foldersKey && value == '[]';
      await expectLater(
        env.service.deleteFolder(folder.id),
        throwsA(
          isA<WorkFolderSaveException>().having(
            (e) => e.partiallySaved,
            'partiallySaved',
            false,
          ),
        ),
      );
      expect(await env.store.getAll(), before);
      expect(env.service.folders.single.id, folder.id);
      expect(env.service.folderIdOf(filename), folder.id);
      await sameAfterReload(env.service, cold: false);
      await sameAfterReload(env.service);
    },
  );

  test(
    'failed delete rollback exposes the actual partial state and remains retryable',
    () async {
      final env = await open(inside: true);
      env.store.reject = (key, value) =>
          (key == foldersKey && value == '[]') ||
          (key == mapKey &&
              value is String &&
              (jsonDecode(value) as Map).isNotEmpty);
      await expectLater(
        env.service.deleteFolder(folder.id),
        throwsA(
          isA<WorkFolderSaveException>().having(
            (e) => e.partiallySaved,
            'partiallySaved',
            true,
          ),
        ),
      );
      expect(env.service.folders.single.id, folder.id);
      expect(env.service.folderIdOf(filename), isNull);
      await sameAfterReload(env.service, cold: false);
      await sameAfterReload(env.service);
      env.store.reject = null;
      await env.service.deleteFolder(folder.id);
      expect(env.service.folders, isEmpty);
      expect(env.service.folderIdOf(filename), isNull);
      await sameAfterReload(env.service);
    },
  );

  test('a rejected operation does not poison the retry queue', () async {
    final env = await open();
    env.store.failWrites = true;
    await expectLater(
      env.service.createFolder('REJECTED'),
      throwsA(isA<WorkFolderSaveException>()),
    );
    env.store.failWrites = false;
    await env.service.createFolder('SAVED');
    expect(env.service.folders.map((f) => f.name), ['AUDIT', 'SAVED']);
    await sameAfterReload(env.service);
  });

  test(
    'queued mutations publish after persistence and include the previous result',
    () async {
      final env = await open();
      final gate = Completer<void>();
      env.store.nextWriteGate = gate;
      final first = env.service.createFolder('FIRST');
      final second = env.service.createFolder('SECOND');
      await Future<void>.delayed(Duration.zero);
      expect(env.service.folders.map((f) => f.name), ['AUDIT']);
      expect(env.store.writes, hasLength(1));
      gate.complete();
      await Future.wait([first, second]);
      expect(env.service.folders.map((f) => f.name), [
        'AUDIT',
        'FIRST',
        'SECOND',
      ]);
      await sameAfterReload(env.service);
    },
  );

  for (final original in <Object>[
    true,
    <Object?>['legacy'],
  ]) {
    test(
      'failure preserves legacy preference type ${original.runtimeType}',
      () async {
        final env = await open(rawMap: original);
        env.store.failWrites = true;
        await expectLater(
          env.service.moveFileToFolder(filename, folder.id),
          throwsA(isA<WorkFolderSaveException>()),
        );
        expect(
          (await SharedPreferences.getInstance()).get('work_file_folder_map'),
          original,
        );
        expect((await env.store.getAll())[mapKey], original);
        await sameAfterReload(env.service, cold: false);
        await sameAfterReload(env.service);
      },
    );
  }

  test(
    'accepted save completes safely after disposal without notifying dead listeners',
    () async {
      final env = await open(autoDispose: false);
      final gate = Completer<void>();
      env.store.nextWriteGate = gate;
      final pending = env.service.moveFileToFolder(filename, folder.id);
      await Future<void>.delayed(Duration.zero);
      env.service.dispose();
      gate.complete();
      await pending;
      SharedPreferences.resetStatic();
      final restored = WorkFolderService();
      await restored.init();
      expect(restored.folderIdOf(filename), folder.id);
      restored.dispose();
    },
  );
}
