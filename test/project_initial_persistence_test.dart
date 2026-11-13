import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/models/project.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  var documentsAvailable = true;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('initial_persistence_');
    documentsAvailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (!documentsAvailable &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<Project> create(ProjectService service) => service.createProject(
    name: 'Persist before editing',
    fps: 12,
    durationSeconds: 1,
    backgroundColor: 0xFFFFFFFF,
    exportWidth: 320,
    exportHeight: 180,
  );

  test('successful creation is already readable by a fresh service', () async {
    final service = ProjectService();
    addTearDown(service.dispose);
    final project = await create(service);
    expect(
      File(
        '${directory.path}/niarim/projects/${project.id}/${project.id}.niapro',
      ).existsSync(),
      isTrue,
    );
    final restarted = ProjectService();
    addTearDown(restarted.dispose);
    await restarted.init();
    expect(restarted.projects.single.id, project.id);
    expect(restarted.projects.single.name, 'Persist before editing');
    expect(restarted.scenesOf(project.id).single.frames.length, 12);
  });

  test(
    'failed initial storage is reported without publishing a ghost project',
    () async {
      final service = ProjectService();
      addTearDown(service.dispose);
      var notifications = 0;
      service.addListener(() => notifications++);
      documentsAvailable = false;
      await expectLater(
        create(service),
        throwsA(isA<MissingPlatformDirectoryException>()),
      );
      expect(service.projects, isEmpty);
      expect(notifications, 0);
      documentsAvailable = true;
      final project = await create(service);
      expect(service.projects.single.id, project.id);
      expect(notifications, 1);
      expect(
        service.scenesOf(project.id).single.frames.first.layers.single.id,
        'Layer0001',
      );
      expect(
        File(
          '${directory.path}/niarim/projects/${project.id}/${project.id}.niapro',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'a filesystem write failure preserves the blocker and allows retry',
    () async {
      final service = ProjectService();
      addTearDown(service.dispose);
      final blocker = File('${directory.path}/niarim');
      blocker.writeAsStringSync('existing data');
      await expectLater(create(service), throwsA(isA<FileSystemException>()));
      expect(service.projects, isEmpty);
      expect(blocker.readAsStringSync(), 'existing data');

      blocker.deleteSync();
      final project = await create(service);
      final restarted = ProjectService();
      addTearDown(restarted.dispose);
      await restarted.init();
      expect(restarted.projects.single.id, project.id);
    },
  );
}
