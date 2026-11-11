import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-work-folder-trash-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('whole exported-work folder survives cold restart and restore', () async {
    final folders = WorkFolderService();
    await folders.init();
    final folder = await folders.createFolder('動画とGIF');
    final directory = Directory('${root.path}/niarim/exports');
    await directory.create(recursive: true);
    final movie = File('${directory.path}/movie.mp4')..writeAsBytesSync([1,2,3]);
    final gif = File('${directory.path}/dance.gif')..writeAsBytesSync([4,5]);
    await folders.moveFileToFolder('movie.mp4', folder.id);
    await folders.moveFileToFolder('dance.gif', folder.id);
    final archived = await LocalFileTrashService.moveWorkFolder(
      folderName: folder.name, files: [movie,gif],
    );
    await folders.deleteFolder(folder.id);
    expect(await movie.exists(), isFalse);
    expect(await gif.exists(), isFalse);
    expect(folders.folders, isEmpty);

    final entry = (await LocalFileTrashService.list()).single;
    expect(entry.isFolder, isTrue);
    expect(entry.fileName, '動画とGIF');
    expect(entry.fileNames.toSet(), {'movie.mp4','dance.gif'});
    expect(archived.id, entry.id);
    folders.dispose();

    final reopened = WorkFolderService();
    await reopened.init();
    await LocalFileTrashService.restoreWorkFolder(entry, reopened);
    expect(await movie.readAsBytes(), [1,2,3]);
    expect(await gif.readAsBytes(), [4,5]);
    expect(reopened.folders.single.name, '動画とGIF');
    expect(reopened.folderIdOf('movie.mp4'), reopened.folders.single.id);
    expect(reopened.folderIdOf('dance.gif'), reopened.folders.single.id);
    expect(await LocalFileTrashService.list(), isEmpty);
    reopened.dispose();
  });

  test('empty exported-work folder is preserved', () async {
    final folders = WorkFolderService();
    await folders.init();
    final entry = await LocalFileTrashService.moveWorkFolder(
      folderName: '空フォルダ', files: [],
    );
    expect(entry.isFolder, isTrue);
    expect((await LocalFileTrashService.list()).single.fileName, '空フォルダ');
    await LocalFileTrashService.restoreWorkFolder(entry, folders);
    expect(folders.folders.single.name, '空フォルダ');
    expect(await LocalFileTrashService.list(), isEmpty);
    folders.dispose();
  });

  test('a conflicting file blocks restore without overwriting bytes', () async {
    final folders = WorkFolderService();
    await folders.init();
    final file = File('${root.path}/exports/clip.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1,2,3]);
    final entry = await LocalFileTrashService.moveWorkFolder(
      folderName: '映画', files: [file],
    );
    await file.writeAsBytes([9,9,9]);
    await expectLater(
      LocalFileTrashService.restoreWorkFolder(entry, folders),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.readAsBytes(), [9,9,9]);
    expect(await File('${entry.archivedPath}/clip.mp4').readAsBytes(), [1,2,3]);
    expect(folders.folders, isEmpty);
    expect(await LocalFileTrashService.list(), hasLength(1));
    folders.dispose();
  });
}
