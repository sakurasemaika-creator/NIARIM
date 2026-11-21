import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';

/// 作品一覧の書き出したファイルの一覧（`ExportEngine.listExportedFiles`）は、
/// 各ファイルの更新日時を1回だけ読んで新しい順に並べ、読めない（並べる間に
/// 消えた）ファイルを一覧に入れない。アプリが書き出した作品は、覚えている
/// 一覧を使う次の読み込みにも入る。
///
/// 以前は並べ替えで比べるたびに両方のファイルの`statSync()`を呼び（n log n
/// 回のディスクの問い合わせ）、並べる間に消えたファイルは「見つからない」の
/// 日時（1970年）として一覧の末尾に残った。覚えている一覧はゴミ箱へ移す・
/// 戻すときだけ捨て、アプリが動画・GIFを書き出しても捨てなかったので、
/// 書き出した作品が作品一覧に出なかった。
///
/// [_TimeReads]は書き出したファイルの場所の`Directory`を包み、一覧の
/// ファイルの日時の読み出し（`stat`・`statSync`・`lastModified`・
/// `lastModifiedSync`）をファイルごとに数える。[vanish]を決めると、一覧を
/// 読み終えた直後にそのファイルを消す（並べる前に消えたのと同じ）。
final class _TimeReads extends IOOverrides {
  _TimeReads(this.exportsPath);

  final String exportsPath;
  final reads = <String, int>{};
  String? vanish;

  void count(String path) => reads[path] = (reads[path] ?? 0) + 1;

  @override
  Directory createDirectory(String path) {
    final real = super.createDirectory(path);
    return path == exportsPath ? _ListedDirectory(real, this) : real;
  }

  @override
  FileStat statSync(String path) {
    count(path);
    return super.statSync(path);
  }

  @override
  Future<FileStat> stat(String path) {
    count(path);
    return super.stat(path);
  }
}

class _ListedDirectory implements Directory {
  _ListedDirectory(this._real, this._probe);

  final Directory _real;
  final _TimeReads _probe;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    final entries = await _real
        .list(recursive: recursive, followLinks: followLinks)
        .toList();
    for (final entry in entries) {
      yield entry is File ? _TimedFile(entry, _probe) : entry;
    }
    final gone = _probe.vanish;
    if (gone != null) File('${_real.path}/$gone').deleteSync();
  }

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  Future<Directory> create({bool recursive = false}) =>
      _real.create(recursive: recursive);
  @override
  void createSync({bool recursive = false}) =>
      _real.createSync(recursive: recursive);
  @override
  Future<bool> exists() => _real.exists();
  @override
  bool existsSync() => _real.existsSync();
  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a probed directory');
}

class _TimedFile implements File {
  _TimedFile(this._real, this._probe);

  final File _real;
  final _TimeReads _probe;

  // stat・statSyncはIOOverridesの方で数える。
  @override
  FileStat statSync() => _real.statSync();
  @override
  Future<FileStat> stat() => _real.stat();
  @override
  DateTime lastModifiedSync() {
    _probe.count(path);
    return _real.lastModifiedSync();
  }

  @override
  Future<DateTime> lastModified() {
    _probe.count(path);
    return _real.lastModified();
  }

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  Directory get parent => _real.parent;
  @override
  Future<bool> exists() => _real.exists();
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<int> length() => _real.length();
  @override
  int lengthSync() => _real.lengthSync();
  @override
  String toString() => _real.toString();
  @override
  bool operator ==(Object other) => other is File && other.path == path;
  @override
  int get hashCode => path.hashCode;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a probed file');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory exports;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-export-list-');
    exports = Directory('${root.path}/niarim/exports')
      ..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });

  tearDown(() async {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// 書き出したファイルを[count]個、1分ずつ古い日時で作る（名前の並びと
  /// 日時の並びが違うように、名前は日時と逆の順にしない）。
  List<String> exported(int count) {
    final base = DateTime(2026, 11, 1, 12);
    final names = <String>[];
    for (var i = 0; i < count; i++) {
      final name = 'clip_${(i * 7) % count}_$i.gif';
      File('${exports.path}/$name')
        ..writeAsBytesSync([i])
        ..setLastModifiedSync(base.subtract(Duration(minutes: i)));
      names.add(name);
    }
    return names; // 新しい順
  }

  List<String> names(List<File> files) => [
    for (final f in files) f.uri.pathSegments.last,
  ];

  test('listing exported files reads each file\'s modified time once and '
      'orders them newest first', () async {
    final newestFirst = exported(24);
    final probe = _TimeReads(exports.path);
    IOOverrides.global = probe;
    final files = await ExportEngine.listExportedFiles(forceRefresh: true);
    IOOverrides.global = null;

    final most = probe.reads.values.fold(0, (a, b) => a > b ? a : b);
    debugPrint(
      'TIME READS files=${probe.reads.length} '
      'total=${probe.reads.values.fold(0, (a, b) => a + b)} max=$most',
    );
    expect(names(files), newestFirst);
    expect(
      {
        for (final e in probe.reads.entries)
          if (e.value > 1) e.key.split('/').last: e.value,
      },
      isEmpty,
      reason: 'a file\'s modified time was read more than once',
    );
  });

  test('a file that vanishes after it was listed is left out of the list, '
      'not shown with a 1970 date', () async {
    final newestFirst = exported(6);
    final gone = newestFirst[2];
    final probe = _TimeReads(exports.path)..vanish = gone;
    IOOverrides.global = probe;
    final files = await ExportEngine.listExportedFiles(forceRefresh: true);
    IOOverrides.global = null;

    debugPrint('VANISHED $gone listed=${names(files)}');
    expect(names(files), [...newestFirst]..remove(gone));
  });

  test('a GIF the app exports is in the next list, also when the list was '
      'read and remembered before', () async {
    exported(2);
    final before = await ExportEngine.listExportedFiles(forceRefresh: true);
    expect(before, hasLength(2));
    // 覚えている一覧を使う読み込み（作品一覧のタブを開いたとき）。
    expect(await ExportEngine.listExportedFiles(), same(before));

    const w = 8;
    const h = 8;
    const layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);
    final tileManager = TileManager(canvasWidth: w, canvasHeight: h);
    addTearDown(tileManager.dispose);
    final pixels = Uint8List(w * h * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels
        ..[i] = 200
        ..[i + 3] = 255;
    }
    tileManager.replaceLayerPixels(
      frameLayerKey('Scene0001', 0, layer.id),
      pixels,
    );
    final output = await ExportEngine().exportGif(
      scenes: const [
        Scene(
          id: 'Scene0001',
          index: 0,
          frames: [
            Frame(index: 0, layers: [layer]),
          ],
        ),
      ],
      tileManager: tileManager,
      fps: 1,
      drawingWidth: w,
      drawingHeight: h,
      width: w,
      height: h,
      backgroundColor: 0xFFFFFFFF,
    );
    expect(File(output).existsSync(), isTrue);

    final after = await ExportEngine.listExportedFiles();
    debugPrint('AFTER EXPORT ${names(after)}');
    expect(
      [for (final f in after) f.path],
      contains(output),
      reason: 'the exported GIF is missing from the remembered list',
    );
    expect(after, hasLength(3));
  });
}
