import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ゴミ箱から作品一覧のフォルダを戻している間も、ゴミ箱の一覧
/// （`LocalFileTrashService.list`）はその項目を見失わない。
///
/// 戻す途中の記録（`meta.json`の戻し先のフォルダ・戻したファイル）を
/// その場で書き直していたので、書き直す間に一覧を読むと、空や途中の
/// `meta.json`を読んでその項目を飛ばし、戻している最中のフォルダが
/// ゴミ箱から一瞬消えた（テストは「3回続けて空」を待って避けていた）。
///
/// [_MetaWriteProbe]は、ゴミ箱の項目のフォルダの直下のファイル
/// （`meta.json`と、その書き換えに使うファイル）への書き込みを、ファイルを
/// 書き込み用に開いた（中身を空にした）所で止めて一覧を読む。その場の
/// 書き直しでは、その時点の`meta.json`は空。
final class _MetaWriteProbe extends IOOverrides {
  _MetaWriteProbe(this.trashRoot);

  final String trashRoot;
  final writes = <String>[];
  final listings = <List<String>>[];

  Future<void> probe(String what) async {
    writes.add(what);
    final entries = await LocalFileTrashService.list();
    listings.add([for (final entry in entries) entry.id]);
  }

  bool _inItemDirectory(String path) {
    if (!path.startsWith('$trashRoot/')) return false;
    final rest = path.substring(trashRoot.length + 1);
    return rest.split('/').length == 2;
  }

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return _inItemDirectory(path) ? _ProbedFile(real, this) : real;
  }
}

class _ProbedFile implements File {
  _ProbedFile(this._real, this._probe);

  final File _real;
  final _MetaWriteProbe _probe;

  String get _name => _real.uri.pathSegments.last;

  /// 書き込み用に開いたときと同じく中身を空にしてから、一覧を読む。
  Future<void> _opened(FileMode mode) async {
    if (mode == FileMode.write || mode == FileMode.writeOnly) {
      _real.writeAsBytesSync(const [], flush: true);
    }
    await _probe.probe('write $_name');
  }

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  File get absolute => _real.absolute;
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
  Future<String> readAsString({Encoding encoding = utf8}) =>
      _real.readAsString(encoding: encoding);
  @override
  String readAsStringSync({Encoding encoding = utf8}) =>
      _real.readAsStringSync(encoding: encoding);
  @override
  Future<Uint8List> readAsBytes() => _real.readAsBytes();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _real.delete(recursive: recursive);
  @override
  void deleteSync({bool recursive = false}) =>
      _real.deleteSync(recursive: recursive);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    await _opened(mode);
    return _real.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await _opened(mode);
    return _real.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> rename(String newPath) async {
    final renamed = await _real.rename(newPath);
    await _probe.probe('rename $_name');
    return renamed;
  }

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

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-trash-listing-');
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

  Future<(LocalTrashedFile, WorkFolderService, List<File>)> trashFolder(
    int count,
  ) async {
    final folders = WorkFolderService();
    await folders.init();
    addTearDown(folders.dispose);
    final folder = await folders.createFolder('Clips');
    final exports = Directory('${root.path}/niarim/exports')
      ..createSync(recursive: true);
    final files = [
      for (var i = 0; i < count; i++)
        File('${exports.path}/clip_$i.gif')..writeAsBytesSync([i, i + 1, 7]),
    ];
    for (final file in files) {
      await folders.moveFileToFolder(file.uri.pathSegments.last, folder.id);
    }
    final entry = await LocalFileTrashService.moveWorkFolder(
      folderName: folder.name,
      files: files,
    );
    await folders.deleteFolder(folder.id);
    return (entry, folders, files);
  }

  test('the Trash list keeps a works folder while its restore rewrites the '
      'restore record', () async {
    final (entry, folders, files) = await trashFolder(3);
    final probe = _MetaWriteProbe('${root.path}/niarim/trash/files');
    IOOverrides.global = probe;
    await LocalFileTrashService.restoreWorkFolder(entry, folders);
    IOOverrides.global = null;

    // 戻し先のフォルダ（1回）と、戻したファイル（1つずつ）を記録する。
    expect(probe.writes.where((w) => w.startsWith('write')), hasLength(4));
    final missing = [
      for (final (i, ids) in probe.listings.indexed)
        if (!ids.contains(entry.id)) probe.writes[i],
    ];
    expect(missing, isEmpty, reason: 'the item vanished from the Trash list');
    for (final file in files) {
      expect(file.readAsBytesSync(), hasLength(3));
    }
    expect(await LocalFileTrashService.list(), isEmpty);
    expect(folders.folders.single.name, 'Clips');
  });

  test('the Trash list read again and again while a works folder is being '
      'restored only loses the folder at the end', () async {
    final (entry, folders, files) = await trashFolder(60);
    var restoring = true;
    final restore = LocalFileTrashService.restoreWorkFolder(
      entry,
      folders,
    ).whenComplete(() => restoring = false);
    final seen = <bool>[];
    while (restoring) {
      final ids = [
        for (final item in await LocalFileTrashService.list()) item.id,
      ];
      seen.add(ids.contains(entry.id));
    }
    await restore;
    // 一度消えたら戻らない（消えるのは戻し終えてゴミ箱から除いたときだけ）。
    final firstGone = seen.indexOf(false);
    if (firstGone >= 0) {
      expect(
        seen.sublist(firstGone),
        everyElement(isFalse),
        reason: 'the item vanished and came back during the restore',
      );
    }
    expect(seen.where((s) => s), isNotEmpty);
    for (final file in files) {
      expect(file.existsSync(), isTrue);
    }
  });

  test('a restore interrupted after some files keeps a readable record and '
      'resumes', () async {
    final (entry, folders, files) = await trashFolder(3);
    final meta = File('${Directory(entry.archivedPath).parent.path}/meta.json');
    // 2つ目のファイルは戻し先に同じ名前のフォルダがあり、写せない（1つ目を
    // 戻して記録を書いた後で止まる）。
    final blocker = Directory(files[1].path)..createSync();
    await expectLater(
      LocalFileTrashService.restoreWorkFolder(entry, folders),
      throwsA(isA<FileSystemException>()),
    );
    expect(jsonDecode(meta.readAsStringSync()), isA<Map<String, dynamic>>());
    expect((await LocalFileTrashService.list()).single.id, entry.id);
    expect(meta.parent.listSync().map((e) => e.path.split('/').last).toSet(), {
      'meta.json',
      'data',
    }, reason: 'no staging file is left beside the record');
    expect((jsonDecode(meta.readAsStringSync()) as Map)['restoredFiles'], [
      'clip_0.gif',
    ]);
    blocker.deleteSync();
    await LocalFileTrashService.restoreWorkFolder(entry, folders);
    expect(await LocalFileTrashService.list(), isEmpty);
    expect(files[1].readAsBytesSync(), [1, 2, 7]);
    expect(folders.folders, hasLength(1));
  });
}
