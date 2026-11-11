import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/widgets/folder_thumbnail.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Project _project(String id, String folderId, String? thumbnail, int day) {
  final date = DateTime.utc(2026, 1, day);
  return Project(
    id: id,
    name: id,
    fps: 12,
    durationSeconds: 1,
    backgroundColor: 0xFFFFFFFF,
    createdAt: date,
    updatedAt: date,
    totalWorkSeconds: 0,
    folderId: folderId,
    thumbnailPath: thumbnail,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Folder metadata keeps all four thumbnail choices after JSON roundtrip', () {
    for (final mode in ['auto', 'none', 'item', 'custom']) {
      final folder = ProjectFolder(
        id: 'root',
        name: 'Parent',
        thumbnailMode: mode,
        thumbnailSourceId: 'project-3',
        thumbnailImagePath: '/pictures/user.png',
      );
      final copy = ProjectFolder.fromJson(folder.toJson());
      expect(copy.thumbnailMode, mode);
      expect(copy.thumbnailSourceId, 'project-3');
      expect(copy.thumbnailImagePath, '/pictures/user.png');
      final disabled = copy.copyWith(
        thumbnailMode: 'none',
        thumbnailSourceId: null,
        thumbnailImagePath: null,
      );
      expect(disabled.thumbnailSourceId, isNull);
      expect(disabled.thumbnailImagePath, isNull);
    }
    expect(
      ProjectFolder.fromJson({'id': 'legacy', 'name': 'old'}).thumbnailMode,
      'auto',
    );
  });

  test('Project and received-share folder thumbnails persist after reload',
      () async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('folder_thumbs_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final first = ProjectService();
    await first.init();
    final local = await first.createFolder('Paintings');
    final received = await first.createSharedFolder('Received');
    await first.setFolderThumbnail(
      local.id,
      mode: 'item',
      sourceId: 'project-1',
    );
    await first.setFolderThumbnail(
      received.id,
      mode: 'custom',
      imagePath: '/my-shared-cover.jpg',
      shared: true,
    );
    expect(first.folders.single.thumbnailSourceId, 'project-1');
    expect(first.sharedFolders.single.thumbnailMode, 'custom');
    first.dispose();

    final reloaded = ProjectService();
    await reloaded.init();
    expect(reloaded.folders.single.thumbnailMode, 'item');
    expect(reloaded.folders.single.thumbnailSourceId, 'project-1');
    expect(reloaded.sharedFolders.single.thumbnailMode, 'custom');
    expect(reloaded.sharedFolders.single.thumbnailImagePath,
        '/my-shared-cover.jpg');
    reloaded.dispose();
  });

  test('Exported-work thumbnail preference survives service reload', () async {
    SharedPreferences.setMockInitialValues({});
    final first = WorkFolderService();
    await first.init();
    final folder = await first.createFolder('Export previews');
    await first.setFolderThumbnail(
      folder.id, mode: 'custom', imagePath: '/my-cover.png');
    expect(first.folders.single.thumbnailMode, 'custom');
    first.dispose();

    final restored = WorkFolderService();
    await restored.init();
    expect(restored.folders.single.thumbnailMode, 'custom');
    expect(restored.folders.single.thumbnailImagePath, '/my-cover.png');
    await restored.setFolderThumbnail(
      folder.id, mode: 'item', sourceId: '/exports/clip.mp4');
    expect(restored.folders.single.thumbnailSourceId, '/exports/clip.mp4');
    restored.dispose();

    final again = WorkFolderService();
    await again.init();
    expect(again.folders.single.thumbnailMode, 'item');
    expect(again.folders.single.thumbnailSourceId, '/exports/clip.mp4');
    again.dispose();
  });

  test('Auto cover traverses child and grandchild folders without cycles', () {
    final parent = ProjectFolder(id: 'root', name: 'root');
    final child = ProjectFolder(id: 'child', name: 'child',
        parentFolderId: 'root');
    final grandchild = ProjectFolder(id: 'deep', name: 'deep',
        parentFolderId: 'child');
    // Malformed metadata with a cycle must not loop indefinitely.
    final cycle = ProjectFolder(id: 'cycle', name: 'cycle',
        parentFolderId: 'deep');
    final folders = [parent, child, grandchild, cycle];
    final projects = [
      _project('old', 'root', '/older.png', 1),
      _project('newest', 'deep', '/newer.png', 20),
      _project('empty-thumb', 'cycle', null, 23),
    ];

    final choices = projectFolderThumbnailChoices(
      folders, projects, 'root');
    expect(choices.map((c) => c.id), containsAll(['old', 'newest']));
    expect(choices.length, 2);
    expect(folderThumbnailPath(parent, choices), '/newer.png');
    expect(
      folderThumbnailPath(parent.copyWith(
        thumbnailMode: 'item',
        thumbnailSourceId: 'old',
      ), choices),
      '/older.png',
    );
    expect(
      folderThumbnailPath(parent.copyWith(thumbnailMode: 'none'), choices),
      isNull,
    );
    expect(
      folderThumbnailPath(parent.copyWith(
        thumbnailMode: 'custom',
        thumbnailImagePath: '/user.png',
      ), choices),
      '/user.png',
    );
    expect(
      folderThumbnailPath(
        parent.copyWith(thumbnailMode: 'item',
            thumbnailSourceId: 'deleted'),
        choices,
      ),
      isNull,
    );
    expect(
      folderThumbnailPath(
        parent,
        projectFolderThumbnailChoices(folders, [], 'root'),
      ),
      isNull,
    );
  });

  testWidgets(
    'Radio-controlled panel stays between options and Cancel/Apply; '
    'nothing persists before Apply',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folder = ProjectFolder(id: 'test', name: 'Example');
      final choices = [
        FolderThumbnailChoice(
          id: 'p1',
          name: 'First work',
          imagePath: '/nonexistent/example.png',
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      ];
      final selected = <String>[];
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ja'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open thumbnail'),
              onPressed: () => showFolderThumbnailDialog(
                context,
                folder: folder,
                choices: choices,
                onSave: ({required mode, sourceId, imagePath}) async {
                  selected.add('$mode:$sourceId');
                },
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open thumbnail'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('folderCoverAuto')), findsOneWidget);
      expect(find.byKey(const Key('folderCoverNone')), findsOneWidget);
      expect(find.byKey(const Key('folderCoverItem')), findsOneWidget);
      expect(find.byKey(const Key('folderCoverCustom')), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('適用'), findsOneWidget);
      expect(find.byKey(const Key('folderCoverItemPanel')), findsNothing);
      expect(find.byKey(const Key('folderCoverCustomPanel')), findsNothing);

      await tester.tap(find.byKey(const Key('folderCoverItem')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folderCoverItemPanel')), findsOneWidget);
      expect(find.byKey(const Key('folderCoverCustomPanel')), findsNothing);
      expect(
        tester.widget<FilledButton>(
          find.byKey(const Key('folderCoverApply')),
        ).onPressed,
        isNull,
        reason: 'A work must be chosen before Apply',
      );
      expect(selected, isEmpty);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);

      await tester.tap(find.text('Open thumbnail'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folderCoverCustom')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folderCoverCustomPanel')), findsOneWidget);
      expect(find.byKey(const Key('folderCoverItemPanel')), findsNothing);
      expect(find.byKey(const Key('folderCoverChooseImage')), findsOneWidget);
      expect(
        tester.widget<FilledButton>(
          find.byKey(const Key('folderCoverApply')),
        ).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('folderCoverNone')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folderCoverCustomPanel')), findsNothing);
      await tester.tap(find.byKey(const Key('folderCoverApply')));
      await tester.pumpAndSettle();
      expect(selected, ['none:null']);
      expect(tester.takeException(), isNull);
    },
  );
}
