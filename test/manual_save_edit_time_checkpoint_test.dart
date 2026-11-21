import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('niarim-edit-manual-save-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('only successful manual tree/slot saves trigger the hook', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final projects = ProjectService();
      await projects.init();
      final saves = SaveTreeService();
      final project = await projects.createProject(
        name: 'Manual edits',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      final id = project.id;
      final calls = <String>[];
      saves.onManualSaveCommitted = calls.add;
      // This is the same method used by background and navigation saves:
      // it must not synchronise candidate time to the cloud.
      await projects.saveProject(id);
      expect(calls, isEmpty);

      await saves.saveAsChild(
        projectId: id,
        project: project,
        scenes: projects.scenesOf(id),
        tileManager: projects.tileManagerOf(id),
      );
      expect(calls, [id]);

      await saves.saveToSlot(
        projectId: id,
        slotIndex: 0,
        project: project,
        scenes: projects.scenesOf(id),
        tileManager: projects.tileManagerOf(id),
      );
      expect(calls, [id, id]);

      // Optional server synchronization must not undo a successful save,
      // or imply a storage failure to the person who pressed Save.
      saves.onManualSaveCommitted = (_) => throw StateError('offline');
      final saved = await saves.saveAsChild(
        projectId: id,
        project: project,
        scenes: projects.scenesOf(id),
        tileManager: projects.tileManagerOf(id),
      );
      expect(saves.getNodes(id).any((node) => node.id == saved.id), isTrue);
      expect(calls, [id, id]);
      projects.dispose();
      saves.dispose();
    });
  });
}
