import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/widgets/folder_thumbnail.dart';
import 'package:niarim/services/project_service.dart';

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
