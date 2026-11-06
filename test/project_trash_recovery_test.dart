import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/project_trash_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.withData({});
  bool reject = false;
  int writes = 0;
  int? rejectWrite;
  Completer<void>? gate;
  Completer<void>? started;
  Future<void> Function()? beforeWrite;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.trashed_projects') {
      final write = ++writes;
      final signal = started;
      started = null;
      signal?.complete();
      final wait = gate;
      gate = null;
      if (wait != null) await wait.future;
      final before = beforeWrite;
      beforeWrite = null;
      if (before != null) await before();
      if (reject || rejectWrite == write) return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late SharedPreferencesStorePlatform previous;
  late Directory directory;
  late ProjectService service;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    SharedPreferences.resetStatic();
    previous = SharedPreferencesStorePlatform.instance;
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    directory = Directory.systemTemp.createTempSync('trash-recovery-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    service = ProjectService();
    await service.init();
  });
  tearDown(() {
    service.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });
  Future<Project> create(String name) => service.createProject(
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

  for (final operation in ['trash', 'restore', 'permanent']) {
    test(
      '$operation restores optimistic cache and retries to a cold result',
      () async {
        final p = await create('RETRY');
        if (operation != 'trash') await service.deleteProject(p.id);
        final source = await file(p.id);
        final bytes = source.readAsBytesSync();
        final before = (await SharedPreferences.getInstance()).getStringList(
          'trashed_projects',
        );
        Future<void> apply() => switch (operation) {
          'trash' => service.deleteProject(p.id),
          'restore' => service.restoreProject(p.id),
          _ => service.permanentDelete(p.id),
        };
        store.reject = true;
        await expectLater(apply(), throwsA(anything));
        expect(
          (await SharedPreferences.getInstance()).getStringList(
            'trashed_projects',
          ),
          before,
        );
        expect(source.readAsBytesSync(), bytes);
        store.reject = false;
        await apply();
        final loaded = await cold();
        expect(
          loaded.trash.any((item) => item.id == p.id),
          operation == 'trash',
        );
        expect(
          loaded.projects.any((item) => item.id == p.id),
          operation == 'restore',
        );
        if (operation == 'permanent') {
          expect(source.parent.existsSync(), isFalse);
        } else {
          expect(source.readAsBytesSync(), bytes);
        }
      },
    );
  }

  test(
    'different targets wait for acknowledgement and duplicate restore is safe',
    () async {
      final a = await create('FIRST');
      final b = await create('SECOND');
      final gate = Completer<void>();
      final started = Completer<void>();
      store
        ..gate = gate
        ..started = started;
      final first = service.deleteProject(a.id);
      await started.future;
      final second = service.deleteProject(b.id);
      expect(service.projects.map((p) => p.id), [a.id, b.id]);
      expect(service.trash, isEmpty);
      gate.complete();
      await Future.wait([first, second]);
      expect(
        (await cold()).trash.map((p) => p.id),
        unorderedEquals([a.id, b.id]),
      );
      var notifications = 0;
      service.addListener(() => notifications++);
      await Future.wait([
        service.restoreProject(a.id),
        service.restoreProject(a.id),
      ]);
      expect(service.projects.single.id, a.id);
      expect(service.scenesOf(a.id), isNotEmpty);
      expect(service.trash.single.id, b.id);
      expect(notifications, 1);
    },
  );

  for (final partial in [false, true]) {
    test(
      'filesystem failure retains named cold cleanup target / partial=$partial',
      () async {
        final p = await create('IDENTIFIABLE / 日本語');
        await service.deleteProject(p.id);
        final source = await file(p.id);
        final bytes = source.readAsBytesSync();
        final dir = source.parent;
        final backup = Directory('${dir.path}.owned-audit-backup');
        final blocker = File(dir.path);
        store.beforeWrite = () async {
          await dir.rename(backup.path);
          await blocker.writeAsString('owned audit blocker');
        };
        try {
          await expectLater(
            service.permanentDelete(p.id),
            throwsA(isA<FileSystemException>()),
          );
          expect(service.trash.single.id, p.id);
        } finally {
          if (await blocker.exists()) {
            expect(await blocker.readAsString(), 'owned audit blocker');
            await blocker.delete();
          }
          if (await backup.exists()) await backup.rename(dir.path);
        }
        expect(source.readAsBytesSync(), bytes);
        if (partial) {
          // Controlled state after an interrupted recursive delete; the guard was
          // produced by the actual operation above, not hand-built test metadata.
          await source.delete();
          await File('${dir.path}/remaining.bin').writeAsBytes([1, 2, 3]);
        }
        final loaded = await cold();
        expect(loaded.trash.single.name, p.name);
        expect(loaded.projects, isEmpty);
        if (partial) {
          await expectLater(loaded.restoreProject(p.id), throwsA(anything));
          expect(loaded.trash.single.id, p.id);
        }
        await loaded.permanentDelete(p.id);
        expect(dir.existsSync(), isFalse);
        expect(
          ProjectTrashGuard.fileFor(dir.parent.path, p.id).existsSync(),
          isFalse,
        );
        expect((await cold()).trash, isEmpty);
      },
    );
  }

  test(
    'unreadable archive stays named until a valid archive can be restored',
    () async {
      final p = await create('RESTORE ME');
      await service.deleteProject(p.id);
      final source = await file(p.id);
      final bytes = source.readAsBytesSync();
      final raw = await store.getAll();
      await source.writeAsBytes([0, 1, 2]);
      await expectLater(service.restoreProject(p.id), throwsA(anything));
      expect(await store.getAll(), raw);
      expect(source.readAsBytesSync(), [0, 1, 2]);
      final loaded = await cold();
      expect(loaded.trash.single.name, p.name);
      await source.writeAsBytes(bytes);
      await loaded.restoreProject(p.id);
      expect(loaded.projects.single.name, p.name);
      expect(loaded.scenesOf(p.id), isNotEmpty);
      expect(source.readAsBytesSync(), bytes);
    },
  );

  test(
    'post-delete metadata rejection cannot resurrect deleted content',
    () async {
      final p = await create('DELETE ME');
      final keep = await create('KEEP ME');
      await service.deleteProject(p.id);
      final source = await file(p.id);
      final keepFile = await file(keep.id);
      final keepBytes = keepFile.readAsBytesSync();
      store.rejectWrite = store.writes + 2;
      await service.permanentDelete(p.id);
      expect(source.parent.existsSync(), isFalse);
      expect((await store.getAll())['flutter.trashed_projects'], isNotEmpty);
      final loaded = await cold();
      expect(loaded.trash, isEmpty);
      expect(loaded.projects.single.id, keep.id);
      expect((await store.getAll())['flutter.trashed_projects'], isEmpty);
      expect(keepFile.readAsBytesSync(), keepBytes);
    },
  );

  test(
    'automatic cleanup failure remains retryable and does not block startup',
    () async {
      final p = await create('EXPIRED');
      await service.deleteProject(p.id);
      await (await SharedPreferences.getInstance()).setStringList(
        'trashed_projects',
        ['${p.id}|2020-01-01T00:00:00.000Z'],
      );
      final loaded = await cold();
      store.reject = true;
      await loaded.sweepExpiredTrash(1);
      expect(loaded.trash.single.id, p.id);
      expect((await file(p.id)).existsSync(), isTrue);
      store.reject = false;
      await loaded.sweepExpiredTrash(1);
      expect((await file(p.id)).existsSync(), isFalse);
    },
  );

  test('another archive ID cannot replace the requested project', () async {
    final p = await create('TARGET');
    final other = await create('UNRELATED');
    await service.deleteProject(p.id);
    final source = await file(p.id);
    final bytes = source.readAsBytesSync();
    final otherFile = await file(other.id);
    final otherBytes = otherFile.readAsBytesSync();
    await source.writeAsBytes(otherBytes);
    await expectLater(
      service.restoreProject(p.id),
      throwsA(isA<FormatException>()),
    );
    final loaded = await cold();
    expect(loaded.projects.single.id, other.id);
    expect(loaded.trash.single.id, p.id);
    expect(loaded.trash.single.name, p.name);
    expect(otherFile.readAsBytesSync(), otherBytes);
    await source.writeAsBytes(bytes);
    await loaded.restoreProject(p.id);
    expect(loaded.projects.map((p) => p.id), unorderedEquals([p.id, other.id]));
  });

  test(
    'guard write failure preserves content and membership for retry',
    () async {
      final p = await create('GUARD FAILURE');
      await service.deleteProject(p.id);
      final source = await file(p.id);
      final bytes = source.readAsBytesSync();
      final guard = ProjectTrashGuard.fileFor(source.parent.parent.path, p.id);
      final blocker = Directory(guard.path)..createSync();
      await expectLater(
        service.permanentDelete(p.id),
        throwsA(isA<FileSystemException>()),
      );
      expect(source.readAsBytesSync(), bytes);
      expect((await cold()).trash.single.id, p.id);
      blocker.deleteSync();
      await service.permanentDelete(p.id);
      expect(source.parent.existsSync(), isFalse);
    },
  );

  test('queued operation settles safely after service disposal', () async {
    final p = await create('DISPOSE');
    final isolated = ProjectService();
    await isolated.init();
    final gate = Completer<void>();
    final started = Completer<void>();
    store
      ..gate = gate
      ..started = started;
    final operation = isolated.deleteProject(p.id);
    await started.future;
    isolated.dispose();
    gate.complete();
    await operation;
    expect((await cold()).trash.single.id, p.id);
  });

  test(
    'interrupted guard temp files are cleaned without removing other files',
    () async {
      final p = await create('TEMP CLEANUP');
      await service.deleteProject(p.id);
      final source = await file(p.id);
      final path = ProjectTrashGuard.fileFor(
        source.parent.parent.path,
        p.id,
      ).path;
      final interrupted = File('$path.tmp-1234')
        ..writeAsStringSync('partial metadata');
      final unrelated = File('$path.tmp-not-owned')..writeAsStringSync('keep');
      final loaded = await cold();
      expect(interrupted.existsSync(), isFalse);
      expect(unrelated.readAsStringSync(), 'keep');
      expect(loaded.trash.single.name, p.name);
      expect(source.existsSync(), isTrue);
    },
  );
}
