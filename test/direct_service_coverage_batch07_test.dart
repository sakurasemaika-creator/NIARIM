import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/services/workspace_preset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('niarim_direct_ws_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('WorkFolderService direct coverage', () {
    test('create rename move root delete and persistence work', () async {
      final service = WorkFolderService();
      var notifications = 0;
      service.addListener(() => notifications++);
      await service.init();
      expect(service.folders, isEmpty);

      final a = await service.createFolder('A');
      final b = await service.createFolder('B');
      expect(service.folders.map((f) => f.name), ['A', 'B']);

      await service.renameFolder(a.id, 'Renamed');
      expect(service.folders.firstWhere((f) => f.id == a.id).name, 'Renamed');
      await service.renameFolder('missing', 'ignored');

      await service.moveFileToFolder('one.mp4', a.id);
      await service.moveFileToFolder('two.gif', b.id);
      expect(service.folderIdOf('one.mp4'), a.id);
      expect(service.folderIdOf('two.gif'), b.id);

      await service.moveFileToFolder('one.mp4', null);
      expect(service.folderIdOf('one.mp4'), isNull);

      final restored = WorkFolderService();
      await restored.init();
      expect(restored.folders.map((f) => f.name), ['Renamed', 'B']);
      expect(restored.folderIdOf('two.gif'), b.id);

      await restored.deleteFolder(b.id);
      expect(restored.folders.any((f) => f.id == b.id), isFalse);
      expect(restored.folderIdOf('two.gif'), isNull,
          reason: 'deleting a folder returns its files to root');
      expect(notifications, greaterThanOrEqualTo(6));
    });

    test('malformed saved JSON falls back to empty state', () async {
      SharedPreferences.setMockInitialValues({
        'work_folders': '{bad',
        'work_file_folder_map': '[bad',
      });
      final service = WorkFolderService();
      await service.init();
      expect(service.folders, isEmpty);
      expect(service.folderIdOf('anything'), isNull);
    });
  });

  group('WorkspacePresetService direct coverage', () {
    test('save overwrite-by-name rename overwrite export import delete and persistence work', () async {
      final service = WorkspacePresetService();
      await service.init();
      expect(service.presets, isEmpty);

      await service.save(
        'Anime',
        isLeftHanded: true,
        forcePcMode: true,
        toolbarOrder: const ['pen', 'eraser', 'invalid'],
        hiddenToolbarItems: const ['bucket'],
        quickToolEntries: const [
          {'id': 'q1', 'label': 'Q1', 'toolKey': 'pen'},
        ],
        defaultDockedPanels: const ['layers', 'colorPicker'],
        desktopPanelWidth: 333,
        desktopToolPanelWidth: 222,
        toolOptionDockOrder: const ['brush', 'ruler'],
        rightDockOrder: const ['layers', 'preview'],
      );
      expect(service.presets, hasLength(1));
      final original = service.presets.single;
      expect(original.isLeftHanded, isTrue);
      expect(original.forcePcMode, isTrue);
      expect(original.desktopPanelWidth, 333);

      await service.save(
        'Anime',
        isLeftHanded: false,
        forcePcMode: null,
        toolbarOrder: const ['eraser'],
      );
      expect(service.presets, hasLength(1),
          reason: 'saving the same name replaces the prior preset');
      final replaced = service.presets.single;
      expect(replaced.id, isNot(original.id));
      expect(replaced.isLeftHanded, isFalse);
      expect(replaced.forcePcMode, isNull);

      await service.rename(replaced.id, '  Animation  ');
      expect(service.presets.single.name, 'Animation');
      await service.rename(replaced.id, '   ');
      expect(service.presets.single.name, 'Animation');
      await service.rename('missing', 'Ignored');

      await service.overwrite(
        replaced.id,
        newName: 'Detailed',
        isLeftHanded: true,
        forcePcMode: false,
        toolbarOrder: const ['pen', 'bucket'],
        hiddenToolbarItems: const ['eraser'],
        quickToolEntries: const [
          {'id': 'q2', 'label': 'Q2', 'toolKey': 'bucket'},
        ],
        defaultDockedPanels: const ['layers'],
        desktopPanelWidth: 400,
        desktopToolPanelWidth: 250,
        toolOptionDockOrder: const ['tone'],
        rightDockOrder: const ['preview'],
      );
      final overwritten = service.presets.single;
      expect(overwritten.id, replaced.id,
          reason: 'overwrite preserves the preset ID');
      expect(overwritten.name, 'Detailed');
      expect(overwritten.isLeftHanded, isTrue);
      expect(overwritten.forcePcMode, isFalse);
      expect(overwritten.toolbarOrder, ['pen', 'bucket']);
      expect(overwritten.hiddenToolbarItems, ['eraser']);
      expect(overwritten.desktopPanelWidth, 400);
      expect(overwritten.desktopToolPanelWidth, 250);

      await service.overwrite(
        overwritten.id,
        newName: '   ',
        isLeftHanded: false,
        forcePcMode: null,
      );
      expect(service.presets.single.name, 'Detailed',
          reason: 'blank overwrite name preserves current name');
      await service.overwrite(
        'missing',
        isLeftHanded: false,
        forcePcMode: null,
      );

      final exportFile = await service.exportPreset(overwritten.id);
      expect(exportFile.path, endsWith('Detailed.niaworkspace'));
      expect(exportFile.existsSync(), isTrue);
      final exportedText = await exportFile.readAsString();
      expect(exportedText, contains('Detailed'));

      final fromJson = await service.importPresetJson(exportedText);
      expect(fromJson.id, isNot(overwritten.id));
      expect(fromJson.name, 'Detailed');
      expect(service.presets, hasLength(2));

      final fromFile = await service.importPresetFile(exportFile.path);
      expect(fromFile.id, isNot(fromJson.id));
      expect(fromFile.name, 'Detailed');
      expect(service.presets, hasLength(3));

      final restored = WorkspacePresetService();
      await restored.init();
      expect(restored.presets, hasLength(3));
      expect(restored.presets.every((p) => p.name == 'Detailed'), isTrue);

      await restored.delete(fromJson.id);
      expect(restored.presets.any((p) => p.id == fromJson.id), isFalse);
    });

    test('export sanitizes invalid filename characters', () async {
      final service = WorkspacePresetService();
      await service.init();
      await service.save(
        'a/b:c*?"d<e>|',
        isLeftHanded: false,
        forcePcMode: null,
      );
      final file = await service.exportPreset(service.presets.single.id);
      expect(file.path, isNot(contains('/b:c')));
      expect(file.path, endsWith('a_b_c___d_e__.niaworkspace'));
    });
  });
}
