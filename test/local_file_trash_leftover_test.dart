import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';

/// 書き出した作品・作った共有ファイルをゴミ箱へ移す途中で止まったとき、
/// ゴミ箱のフォルダ（`niarim/trash/files`）に記録（`meta.json`）の無い
/// フォルダを残さない。
///
/// 記録の無いフォルダはゴミ箱の一覧に出ないので、利用者は戻すことも
/// 消すこともできず、途中まで写したファイルが容量だけを使い続けた。
/// 元のファイルが写している途中にアプリの外で消えたとき（ほかのアプリ・
/// 同じファイルを2回移したとき）は、写すのに失敗しても元のファイルが
/// 無いのでフォルダを消していなかった。アプリが写している途中で
/// 止まったときは、後片付けそのものが動かない。
final class _VanishingSource extends IOOverrides {
  _VanishingSource(this.sourceDirectory, {required this.afterCopy});

  final String sourceDirectory;

  /// trueなら写し終えてから、falseなら半分写した所で元のファイルが消える。
  final bool afterCopy;

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return path.startsWith('$sourceDirectory/')
        ? _VanishingFile(real, this)
        : real;
  }
}

class _VanishingFile implements File {
  _VanishingFile(this._real, this._probe);

  final File _real;
  final _VanishingSource _probe;

  @override
  Future<File> copy(String newPath) async {
    if (_probe.afterCopy) {
      final copied = await _real.copy(newPath);
      await _real.delete();
      return copied;
    }
    final bytes = await _real.readAsBytes();
    await File(
      newPath,
    ).writeAsBytes(bytes.sublist(0, bytes.length ~/ 2), flush: true);
    await _real.delete();
    throw FileSystemException('Source vanished during copy', _real.path);
  }

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  File get absolute => File(_real.absolute.path);
  @override
  Directory get parent => _real.parent;
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<bool> exists() => _real.exists();
  @override
  int lengthSync() => _real.lengthSync();
  @override
  Future<int> length() => _real.length();
  @override
  FileStat statSync() => _real.statSync();
  @override
  Future<FileStat> stat() => _real.stat();
  @override
  Future<DateTime> lastModified() => _real.lastModified();
  @override
  DateTime lastModifiedSync() => _real.lastModifiedSync();
  @override
  Future<Uint8List> readAsBytes() => _real.readAsBytes();
  @override
  Uint8List readAsBytesSync() => _real.readAsBytesSync();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _real.delete(recursive: recursive);
  @override
  void deleteSync({bool recursive = false}) =>
      _real.deleteSync(recursive: recursive);
  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a probed file');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory exports;
  late Directory trashRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-trash-leftover-');
    exports = Directory('${root.path}/niarim/exports')
      ..createSync(recursive: true);
    trashRoot = Directory('${root.path}/niarim/trash/files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() async {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  List<int> clipBytes(int seed) => [
    for (var i = 0; i < 4096; i++) (i * 31 + seed) & 0xff,
  ];

  String nameOf(FileSystemEntity entity) =>
      entity.uri.pathSegments.where((s) => s.isNotEmpty).last;

  /// ゴミ箱のフォルダの直下にある物の名前。
  Set<String> trashNames() => {
    if (trashRoot.existsSync())
      for (final item in trashRoot.listSync(followLinks: false)) nameOf(item),
  };

  for (final kind in [
    LocalTrashKind.exportedWork,
    LocalTrashKind.outgoingShare,
  ]) {
    for (final afterCopy in [false, true]) {
      final when = afterCopy
          ? 'after it was copied, before its record'
          : 'half way through the copy';
      test('a ${kind.name} file that vanishes $when leaves no folder in the '
          'Trash', () async {
        final path = '${exports.path}/clip.mp4';
        File(path).writeAsBytesSync(clipBytes(7));
        IOOverrides.global = _VanishingSource(
          exports.path,
          afterCopy: afterCopy,
        );
        await expectLater(
          LocalFileTrashService.move(File(path), kind),
          throwsA(isA<FileSystemException>()),
        );
        IOOverrides.global = null;

        expect(File(path).existsSync(), isFalse);
        expect(await LocalFileTrashService.list(), isEmpty);
        expect(
          trashNames(),
          isEmpty,
          reason: 'a copy without a record stayed in the Trash folder',
        );
      });
    }
  }

  test('start-up removes the Trash folders that a stopped move left without '
      'a record, and keeps everything else', () async {
    trashRoot.createSync(recursive: true);
    final now = DateTime.now();
    final old = now.subtract(const Duration(days: 2));
    final oldSeed = old.microsecondsSinceEpoch;

    Directory folder(String name) =>
        Directory('${trashRoot.path}/$name')..createSync();
    File write(String path, List<int> bytes, {DateTime? modified}) {
      final file = File(path)..writeAsBytesSync(bytes);
      if (modified != null) file.setLastModifiedSync(modified);
      return file;
    }

    // A file move stopped during the copy: half of the bytes, and the record
    // still being written beside its final name.
    final stoppedCopy = folder('$oldSeed');
    write(
      '${stoppedCopy.path}/data',
      clipBytes(1).sublist(0, 900),
      modified: old,
    );
    write(
      '${stoppedCopy.path}/meta.json.${oldSeed + 5}-0.tmp',
      utf8.encode('{"id":'),
      modified: old,
    );
    // A works folder move stopped during the copy of its second file.
    final stoppedFolder = folder('${oldSeed + 1}');
    Directory('${stoppedFolder.path}/data').createSync();
    write('${stoppedFolder.path}/data/a.gif', clipBytes(2), modified: old);
    write(
      '${stoppedFolder.path}/data/b.gif',
      clipBytes(3).sublist(0, 10),
      modified: old,
    );
    // A restore or a permanent delete stopped after it removed the record.
    final stoppedDelete = folder('${oldSeed + 2}');
    write('${stoppedDelete.path}/data', clipBytes(4), modified: old);

    // An old item with its record.
    final recorded = folder('${oldSeed + 3}');
    write('${recorded.path}/data', clipBytes(5), modified: old);
    write(
      '${recorded.path}/meta.json',
      utf8.encode(
        jsonEncode({
          'id': '${oldSeed + 3}',
          'kind': LocalTrashKind.exportedWork.name,
          'originalPath': '${exports.path}/kept.mp4',
          'deletedAt': old.toIso8601String(),
        }),
      ),
      modified: old,
    );
    // A record that cannot be read is still a record: it is not removed.
    final unreadable = folder('${oldSeed + 4}');
    write('${unreadable.path}/data', clipBytes(6), modified: old);
    write(
      '${unreadable.path}/meta.json',
      utf8.encode('{broken'),
      modified: old,
    );
    // A move that has only just started, and an old folder whose copy is
    // still being written (another copy of the app): both may still finish.
    final justStarted = folder('${now.microsecondsSinceEpoch}');
    write('${justStarted.path}/data', clipBytes(7).sublist(0, 100));
    final stillWriting = folder('${oldSeed + 6}');
    write('${stillWriting.path}/data', clipBytes(8).sublist(0, 100));
    // Things the app never creates in the Trash folder are left alone.
    final notAnItem = folder('notes');
    write('${notAnItem.path}/data', clipBytes(9), modified: old);
    write('${trashRoot.path}/${oldSeed + 7}', clipBytes(10), modified: old);
    final outside = Directory('${root.path}/outside')..createSync();
    write('${outside.path}/data', clipBytes(11), modified: old);
    Link('${trashRoot.path}/${oldSeed + 8}').createSync(outside.path);
    // An item moved by the app in this run.
    final moved = File('${exports.path}/moved.mp4')
      ..writeAsBytesSync(clipBytes(12));
    final movedEntry = await LocalFileTrashService.move(
      moved,
      LocalTrashKind.exportedWork,
    );

    // Auto-delete is off: only the retention period is not applied.
    await LocalFileTrashService.sweepExpired(0);

    expect(trashNames(), {
      nameOf(recorded),
      nameOf(unreadable),
      nameOf(justStarted),
      nameOf(stillWriting),
      'notes',
      '${oldSeed + 7}',
      '${oldSeed + 8}',
      movedEntry.id,
    });
    expect(File('${outside.path}/data').readAsBytesSync(), clipBytes(11));
    expect(File('${recorded.path}/data').readAsBytesSync(), clipBytes(5));
    expect((await LocalFileTrashService.list()).map((e) => e.id).toSet(), {
      '${oldSeed + 3}',
      movedEntry.id,
    });
    expect(File(movedEntry.archivedPath).readAsBytesSync(), clipBytes(12));

    // The retention period still applies to listed items only.
    await LocalFileTrashService.sweepExpired(1);
    expect((await LocalFileTrashService.list()).map((e) => e.id).toSet(), {
      movedEntry.id,
    });
    expect(trashNames(), contains('notes'));
    expect(trashNames(), contains(nameOf(stillWriting)));
  });
}
