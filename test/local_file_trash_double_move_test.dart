import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 同じファイルを同時に2回ゴミ箱へ移しても、ゴミ箱に項目は1つだけ。
///
/// 以前は2つの移動がどちらも「元がある」と確かめてから写し、どちらも記録
/// （`meta.json`）を書いた。後から元を消そうとした方は元が無いので失敗するが、
/// 元が無いので写しを残し（記録のある写しは元が無ければ残す決まり）、
/// ゴミ箱に同じ項目が2つ出た（片方を戻すと、もう片方は戻す先にファイルが
/// あるので戻せない）。
///
/// [_SlowCopy]は、書き出したファイルの場所で作った`File`の`copy`を少し
/// 遅らせ、2つの移動が確かめ・写しの間で重なるようにする（実機では大きな
/// 動画の写しに時間がかかる間の二度押し・別の画面からの同時の移動）。
final class _SlowCopy extends IOOverrides {
  _SlowCopy(this.sourceDirectory);

  final String sourceDirectory;
  int copies = 0;

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return path.startsWith('$sourceDirectory/') ? _SlowFile(real, this) : real;
  }
}

class _SlowFile implements File {
  _SlowFile(this._real, this._probe);

  final File _real;
  final _SlowCopy _probe;

  @override
  Future<File> copy(String newPath) async {
    _probe.copies++;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _real.copy(newPath);
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
      throw UnsupportedError('${invocation.memberName} on a slow file');
}

/// The file of a single move: copied at once, and removed only once [gate]
/// completes (or after 2 s), so a works folder move of the same file can
/// finish in between, as with a large video copied by the single move.
class _DeleteAfter extends _SlowFile {
  _DeleteAfter(File real, this.gate) : super(real, _SlowCopy(''));

  final Future<void> gate;

  @override
  Future<File> copy(String newPath) => _real.copy(newPath);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    await gate.timeout(const Duration(seconds: 2), onTimeout: () {});
    return _real.delete(recursive: recursive);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory exports;
  late Directory trashRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-trash-double-move-');
    exports = Directory('${root.path}/niarim/exports')
      ..createSync(recursive: true);
    trashRoot = Directory('${root.path}/niarim/trash/files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
    SharedPreferences.setMockInitialValues({});
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

  /// ゴミ箱の項目のフォルダの中身（ファイル名）。
  Map<String, Set<String>> trashContents() => {
    if (trashRoot.existsSync())
      for (final item in trashRoot.listSync().whereType<Directory>())
        nameOf(item): {for (final f in item.listSync()) nameOf(f)},
  };

  /// [moves]を同時に走らせ、成功したものと失敗したものに分ける。
  Future<(List<LocalTrashedFile>, List<Object>)> together(
    List<Future<LocalTrashedFile> Function()> moves,
  ) async {
    final done = <LocalTrashedFile>[];
    final failed = <Object>[];
    await Future.wait([
      for (final move in moves)
        move().then(done.add, onError: (Object e) => failed.add(e)),
    ]);
    return (done, failed);
  }

  for (final kind in [
    LocalTrashKind.exportedWork,
    LocalTrashKind.outgoingShare,
  ]) {
    test('the same ${kind.name} file moved to the Trash twice at once makes '
        'one Trash item', () async {
      final source = File('${exports.path}/clip.mp4')
        ..writeAsBytesSync(clipBytes(1));
      final probe = _SlowCopy(exports.path);
      IOOverrides.global = probe;
      final (done, failed) = await together([
        () => LocalFileTrashService.move(File(source.path), kind),
        () => LocalFileTrashService.move(File(source.path), kind),
      ]);
      IOOverrides.global = null;

      expect(done, hasLength(1), reason: 'both moves reported success');
      expect(failed.single, isA<FileSystemException>());
      expect(source.existsSync(), isFalse);
      final items = await LocalFileTrashService.list();
      expect(items.map((e) => e.id), [
        done.single.id,
      ], reason: 'the Trash shows the same file more than once');
      expect(trashContents(), {
        done.single.id: {'meta.json', 'data'},
      }, reason: 'a second copy of the file was left in the Trash folder');
      expect(File(done.single.archivedPath).readAsBytesSync(), clipBytes(1));
      expect(probe.copies, 1, reason: 'the file was copied twice');

      // The one item restores the file.
      await LocalFileTrashService.restore(items.single);
      expect(source.readAsBytesSync(), clipBytes(1));
      expect(await LocalFileTrashService.list(), isEmpty);
      expect(trashContents(), isEmpty);
    });
  }

  test('a works folder and one of its files moved at once make one Trash item '
      'holding the file', () async {
    final a = File('${exports.path}/a.mp4')..writeAsBytesSync(clipBytes(2));
    final b = File('${exports.path}/b.gif')..writeAsBytesSync(clipBytes(3));
    IOOverrides.global = _SlowCopy(exports.path);
    final (done, failed) = await together([
      () => LocalFileTrashService.moveWorkFolder(
        folderName: 'Clips',
        files: [File(a.path), File(b.path)],
      ),
      () =>
          LocalFileTrashService.move(File(a.path), LocalTrashKind.exportedWork),
    ]);
    IOOverrides.global = null;

    expect(done, hasLength(1));
    expect(failed.single, isA<FileSystemException>());
    final items = await LocalFileTrashService.list();
    expect(items, hasLength(1));
    expect(trashContents().keys, [items.single.id]);
    expect(a.existsSync(), isFalse);
  });

  test('a works folder and one of its files moved at once make one Trash '
      'item, whichever finishes first', () async {
    final a = File('${exports.path}/a.mp4')..writeAsBytesSync(clipBytes(6));
    final folderDone = Completer<void>();
    IOOverrides.global = _SlowCopy(exports.path);
    final (done, failed) = await together([
      () => LocalFileTrashService.moveWorkFolder(
        folderName: 'Clips',
        files: [File(a.path)],
      ).whenComplete(folderDone.complete),
      // The single move has copied the file and written its record when the
      // folder move removes the file.
      () => LocalFileTrashService.move(
        _DeleteAfter(a, folderDone.future),
        LocalTrashKind.exportedWork,
      ),
    ]);
    IOOverrides.global = null;

    expect(done, hasLength(1), reason: 'both moves reported success');
    expect(failed.single, isA<FileSystemException>());
    final items = await LocalFileTrashService.list();
    expect(
      items,
      hasLength(1),
      reason: 'the Trash shows the same file more than once',
    );
    expect(trashContents().keys, [items.single.id]);
    expect(a.existsSync(), isFalse);
  });

  test('two different files moved at once both reach the Trash', () async {
    final a = File('${exports.path}/a.mp4')..writeAsBytesSync(clipBytes(4));
    final b = File('${exports.path}/b.mp4')..writeAsBytesSync(clipBytes(5));
    IOOverrides.global = _SlowCopy(exports.path);
    final (done, failed) = await together([
      () =>
          LocalFileTrashService.move(File(a.path), LocalTrashKind.exportedWork),
      () =>
          LocalFileTrashService.move(File(b.path), LocalTrashKind.exportedWork),
    ]);
    IOOverrides.global = null;

    expect(failed, isEmpty);
    expect(done, hasLength(2));
    expect(
      (await LocalFileTrashService.list()).map((e) => e.fileName).toSet(),
      {'a.mp4', 'b.mp4'},
    );
    expect(trashContents(), hasLength(2));
  });
}
