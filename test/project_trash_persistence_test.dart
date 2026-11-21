import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _TrashStore extends InMemorySharedPreferencesStore {
  _TrashStore() : super.withData({});
  bool reject = false;
  bool throwFailure = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.trashed_projects' && reject) {
      if (throwFailure) {
        throw PlatformException(code: 'audit-trash-store-failure');
      }
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TrashStore store;
  late SharedPreferencesStorePlatform previousStore;
  late Directory directory;
  late ProjectService service;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    SharedPreferences.resetStatic();
    previousStore = SharedPreferencesStorePlatform.instance;
    store = _TrashStore();
    SharedPreferencesStorePlatform.instance = store;
    directory = Directory.systemTemp.createTempSync('audit-trash-persistence-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    service = ProjectService();
    await service.init();
  });

  tearDown(() {
    service.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previousStore;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
  });

  for (final operation in ['trash', 'restore', 'permanent-delete']) {
    for (final throws in [false, true]) {
      test('$operation retains data on ${throws ? 'throw' : 'false'}', () async {
        final project = await service.createProject(
          name: 'Audit $operation',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFF123456,
          exportWidth: 64,
          exportHeight: 64,
        );
        if (operation != 'trash') await service.deleteProject(project.id);
        final path =
            '${await NiaproSerializer.projectsBasePath()}/${project.id}/${project.id}.niapro';
        final file = File(path);
        final beforeBytes = await file.readAsBytes();
        final beforeRaw = Map<String, Object>.from(await store.getAll());
        var notifications = 0;
        service.addListener(() => notifications++);
        store
          ..reject = true
          ..throwFailure = throws;
        Object? error;
        try {
          switch (operation) {
            case 'trash':
              await service.deleteProject(project.id);
            case 'restore':
              await service.restoreProject(project.id);
            case 'permanent-delete':
              await service.permanentDelete(project.id);
          }
        } catch (caught) {
          error = caught;
        }
        final afterRaw = Map<String, Object>.from(await store.getAll());
        final fileUnchanged =
            file.existsSync() &&
            listEquals(beforeBytes, file.readAsBytesSync());
        final cached = (await SharedPreferences.getInstance()).getStringList(
          'trashed_projects',
        );
        SharedPreferences.resetStatic();
        final cold = ProjectService();
        await cold.init();
        addTearDown(cold.dispose);
        final expectedTrash = operation != 'trash';
        final report = {
          'operation': operation,
          'failure': throws ? 'throw' : 'false',
          'error': error?.toString(),
          'notifications': notifications,
          'memory_active': service.projects.map((p) => p.id).toList(),
          'memory_trash': service.trash.map((p) => p.id).toList(),
          'cold_active': cold.projects.map((p) => p.id).toList(),
          'cold_trash': cold.trash.map((p) => p.id).toList(),
          'before_raw': beforeRaw,
          'after_raw': afterRaw,
          'optimistic_cached_trash': cached,
          'file_unchanged': fileUnchanged,
        };
        final evidence = Directory('build/audit-s27/counters')
          ..createSync(recursive: true);
        File(
          '${evidence.path}/$operation-${throws ? 'throw' : 'false'}.json',
        ).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n',
        );
        expect(
          error,
          isNotNull,
          reason: 'A failed write must reach its caller',
        );
        expect(notifications, 0);
        expect(afterRaw, beforeRaw);
        expect(fileUnchanged, isTrue);
        expect(service.trash.any((p) => p.id == project.id), expectedTrash);
        expect(service.projects.any((p) => p.id == project.id), !expectedTrash);
        expect(cold.trash.any((p) => p.id == project.id), expectedTrash);
        expect(cold.projects.any((p) => p.id == project.id), !expectedTrash);
      });
    }
  }
}
