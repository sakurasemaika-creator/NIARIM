import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('niarim-file-trash-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => directory.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('exported work moves to persistent Trash and safely restores', () async {
    final input = File('${directory.path}/niarim/exports/clip.mp4');
    await input.parent.create(recursive: true);
    await input.writeAsBytes([11, 22, 33, 44]);
    final change = LocalFileTrashService.changes.value;

    final entry = await LocalFileTrashService.move(
      input, LocalTrashKind.exportedWork);
    expect(await input.exists(), isFalse);
    expect(LocalFileTrashService.changes.value, change + 1);
    final items = await LocalFileTrashService.list();
    expect(items, hasLength(1));
    expect(items.single.kind, LocalTrashKind.exportedWork);
    expect(items.single.fileName, 'clip.mp4');
    expect(await File(entry.archivedPath).readAsBytes(), [11,22,33,44]);

    await LocalFileTrashService.restore(items.single);
    expect(await input.readAsBytes(), [11,22,33,44]);
    expect(await LocalFileTrashService.list(), isEmpty);
  });

  test('restoration refuses overwrite and retains archived snapshot', () async {
    final input = File('${directory.path}/niarim/shared/outgoing/a.niashare');
    await input.parent.create(recursive: true);
    await input.writeAsBytes([1, 2, 3]);
    final saved = await LocalFileTrashService.move(
      input, LocalTrashKind.outgoingShare);
    expect((await LocalFileTrashService.list()).single.kind,
        LocalTrashKind.outgoingShare);

    await input.writeAsBytes([7, 8, 9]);
    await expectLater(
      LocalFileTrashService.restore(saved),
      throwsA(isA<FileSystemException>()),
    );
    expect(await input.readAsBytes(), [7,8,9]);
    expect(await File(saved.archivedPath).readAsBytes(), [1,2,3]);
    await LocalFileTrashService.deleteForever(saved);
    expect(await LocalFileTrashService.list(), isEmpty);
    expect(await input.readAsBytes(), [7,8,9]);
  });

  test('no fake entry is created when the source is absent', () async {
    await expectLater(
      LocalFileTrashService.move(
        File('${directory.path}/missing.mp4'),
        LocalTrashKind.exportedWork),
      throwsA(isA<FileSystemException>()),
    );
    expect(await LocalFileTrashService.list(), isEmpty);
  });
}
