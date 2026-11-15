import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 書き出した作品・作った共有ファイルをゴミ箱へ移す間、ゴミ箱の一覧
/// （`LocalFileTrashService.list`）に写している途中の項目を出さない。
///
/// 以前は1つのファイルを移すとき、写す前にゴミ箱の記録（`meta.json`）を
/// 書いていた。写している間に一覧を読むと、途中までしか写っていない
/// ファイルがゴミ箱の項目として出て、写すのに失敗したり途中でアプリが
/// 終わったりすると、元のファイルが残ったまま壊れた項目が出た。
///
/// [_CopyProbe]は、書き出したファイルの場所で作った`File`の`copy`を、
/// 写し先に半分だけ書いた所で止めて一覧を読む（本物の写しの途中と同じく、
/// 写し先には途中までのファイルがある）。
final class _CopyProbe extends IOOverrides {
  _CopyProbe(this.sourceDirectory);

  final String sourceDirectory;
  final copies = <String>[];
  final listings = <List<LocalTrashedFile>>[];
  bool failCopy = false;

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return path.startsWith('$sourceDirectory/')
        ? _ProbedSource(real, this)
        : real;
  }
}

class _ProbedSource implements File {
  _ProbedSource(this._real, this._probe);

  final File _real;
  final _CopyProbe _probe;

  @override
  Future<File> copy(String newPath) async {
    final bytes = await _real.readAsBytes();
    await File(
      newPath,
    ).writeAsBytes(bytes.sublist(0, bytes.length ~/ 2), flush: true);
    _probe.copies.add(_real.uri.pathSegments.last);
    _probe.listings.add(await LocalFileTrashService.list());
    if (_probe.failCopy) {
      throw FileSystemException('Copy interrupted', newPath);
    }
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
      throw UnsupportedError('${invocation.memberName} on a probed file');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory exports;
  late Directory trashRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-trash-move-');
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

  /// ゴミ箱の項目のフォルダの中身（ファイル名）。
  Map<String, Set<String>> trashContents() => {
    if (trashRoot.existsSync())
      for (final item in trashRoot.listSync().whereType<Directory>())
        item.uri.pathSegments.where((s) => s.isNotEmpty).last: {
          for (final f in item.listSync())
            f.uri.pathSegments.where((s) => s.isNotEmpty).last,
        },
  };

  for (final kind in [
    LocalTrashKind.exportedWork,
    LocalTrashKind.outgoingShare,
  ]) {
    test('a ${kind.name} file is not in the Trash list while it is still '
        'being copied, and is listed once with all its bytes', () async {
      final bytes = clipBytes(3);
      final path = '${exports.path}/clip.gif';
      File(path).writeAsBytesSync(bytes);
      final probe = _CopyProbe(exports.path);
      IOOverrides.global = probe;
      final entry = await LocalFileTrashService.move(File(path), kind);
      IOOverrides.global = null;

      expect(probe.copies, ['clip.gif']);
      expect(
        [
          for (final listing in probe.listings)
            for (final item in listing) item.id,
        ],
        isEmpty,
        reason: 'a half-copied file was listed in the Trash',
      );
      final listed = await LocalFileTrashService.list();
      expect(listed.single.id, entry.id);
      expect(File(listed.single.archivedPath).readAsBytesSync(), bytes);
      expect(File(path).existsSync(), isFalse);
    });

    test('a ${kind.name} copy that fails leaves the file, no Trash item and '
        'nothing behind in the Trash folder', () async {
      final bytes = clipBytes(5);
      final path = '${exports.path}/broken.gif';
      File(path).writeAsBytesSync(bytes);
      final probe = _CopyProbe(exports.path)..failCopy = true;
      IOOverrides.global = probe;
      await expectLater(
        LocalFileTrashService.move(File(path), kind),
        throwsA(isA<FileSystemException>()),
      );
      IOOverrides.global = null;

      expect(
        [
          for (final listing in probe.listings)
            for (final item in listing) item.id,
        ],
        isEmpty,
        reason: 'the failing copy was listed in the Trash',
      );
      expect(await LocalFileTrashService.list(), isEmpty);
      expect(trashContents(), isEmpty, reason: 'leftover in the Trash folder');
      expect(File(path).readAsBytesSync(), bytes);
    });
  }

  test('a works folder is not in the Trash list until all its files are '
      'copied, and a failed copy leaves no item behind', () async {
    final files = [
      for (var i = 0; i < 3; i++)
        File('${exports.path}/clip_$i.gif')..writeAsBytesSync(clipBytes(i)),
    ];
    final probe = _CopyProbe(exports.path)..failCopy = true;
    IOOverrides.global = probe;
    await expectLater(
      LocalFileTrashService.moveWorkFolder(
        folderName: 'Clips',
        files: [for (final f in files) File(f.path)],
      ),
      throwsA(isA<FileSystemException>()),
    );
    probe.failCopy = false;
    final entry = await LocalFileTrashService.moveWorkFolder(
      folderName: 'Clips',
      files: [for (final f in files) File(f.path)],
    );
    IOOverrides.global = null;

    expect(probe.copies, [
      'clip_0.gif',
      'clip_0.gif',
      'clip_1.gif',
      'clip_2.gif',
    ]);
    expect([
      for (final listing in probe.listings)
        for (final item in listing) item.id,
    ], isEmpty);
    final listed = await LocalFileTrashService.list();
    expect(listed.single.id, entry.id);
    expect(trashContents(), {
      entry.id: {'meta.json', 'data'},
    });
    for (final (i, name) in entry.fileNames.indexed) {
      expect(
        File('${entry.archivedPath}/$name').readAsBytesSync(),
        clipBytes(i),
      );
    }
    final meta = jsonDecode(
      File('${trashRoot.path}/${entry.id}/meta.json').readAsStringSync(),
    );
    expect((meta as Map)['fileNames'], [
      'clip_0.gif',
      'clip_1.gif',
      'clip_2.gif',
    ]);
  });
}
