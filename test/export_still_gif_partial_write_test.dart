import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/export_storage.dart';

/// GIF・静止画（PNG・JPEG）の書き出しで、書き込みの途中で失敗しても（空きが
/// 無い等）、書きかけのファイルを書き出し先（`niarim/exports`）に残さない。
/// 書いている途中のファイルも作品一覧に出さない。
///
/// 以前は書き出し先へ直に書き込んでいたので、途中で失敗すると書きかけの
/// ファイルが残り、作品一覧に壊れた作品として出た。書いている最中に作品一覧を
/// 読むと、途中までのファイルも出た。
///
/// [_WriteProbe]は、書き出し先で作った`File`の`writeAsBytes`を、半分だけ
/// 書いた所で作品一覧を読み、[fail]なら本物の書き込みの失敗と同じく
/// 例外を投げる（空きが無いとき、ファイルには途中までが残る）。
final class _WriteProbe extends IOOverrides {
  _WriteProbe(this.exportsPath);

  final String exportsPath;
  bool fail = false;
  final listedWhileWriting = <List<String>>[];

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return path.startsWith('$exportsPath/') ? _ProbedExport(real, this) : real;
  }
}

class _ProbedExport implements File {
  _ProbedExport(this._real, this._probe);

  final File _real;
  final _WriteProbe _probe;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await _real.writeAsBytes(
      bytes.sublist(0, bytes.length ~/ 2),
      mode: mode,
      flush: true,
    );
    _probe.listedWhileWriting.add([
      for (final f in await ExportEngine.listExportedFiles(forceRefresh: true))
        f.uri.pathSegments.last,
    ]);
    if (_probe.fail) {
      throw FileSystemException(
        'Write failed',
        _real.path,
        const OSError('No space left on device', 28),
      );
    }
    return _real.writeAsBytes(bytes, mode: mode, flush: flush);
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
  Future<Uint8List> readAsBytes() => _real.readAsBytes();
  @override
  Uint8List readAsBytesSync() => _real.readAsBytesSync();
  @override
  Future<File> rename(String newPath) => _real.rename(newPath);
  @override
  File renameSync(String newPath) => _real.renameSync(newPath);
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
      throw UnsupportedError('${invocation.memberName} on a probed export');
}

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory documents;

  Directory exportsDir() => ExportStorage.managedDirectoryIn(documents);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-export-partial-');
    documents = Directory('${root.path}/documents')..createSync();
    ExportStorage.invalidate();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documents.path;
      }
      return root.path;
    });
  });

  tearDown(() async {
    IOOverrides.global = null;
    messenger.setMockMethodCallHandler(_pathChannel, null);
    ExportStorage.invalidate();
    if (await root.exists()) await root.delete(recursive: true);
  });

  const w = 8;
  const h = 8;
  const layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);
  const scenes = [
    Scene(
      id: 'Scene0001',
      index: 0,
      frames: [
        Frame(index: 0, layers: [layer]),
        Frame(index: 1, layers: [layer]),
      ],
    ),
  ];

  TileManager paintedTiles() {
    final tileManager = TileManager(canvasWidth: w, canvasHeight: h);
    addTearDown(tileManager.dispose);
    final pixels = Uint8List(w * h * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels
        ..[i] = 30
        ..[i + 1] = 120
        ..[i + 2] = 200
        ..[i + 3] = 255;
    }
    for (final frame in scenes.single.frames) {
      tileManager.replaceLayerPixels(
        frameLayerKey('Scene0001', frame.index, layer.id),
        pixels,
      );
    }
    return tileManager;
  }

  final formats =
      <(String, String, Future<String> Function(ExportEngine, TileManager))>[
        (
          'GIF',
          '.gif',
          (engine, tiles) => engine.exportGif(
            scenes: scenes,
            tileManager: tiles,
            fps: 2,
            drawingWidth: w,
            drawingHeight: h,
            width: w,
            height: h,
            backgroundColor: 0xFFFFFFFF,
          ),
        ),
        (
          'PNG',
          '.png',
          (engine, tiles) => engine.exportFrameImage(
            scenes: scenes,
            tileManager: tiles,
            sceneId: 'Scene0001',
            frameIndex: 1,
            drawingWidth: w,
            drawingHeight: h,
            width: w,
            height: h,
            backgroundColor: 0xFFFFFFFF,
            asJpeg: false,
          ),
        ),
        (
          'JPEG',
          '.jpg',
          (engine, tiles) => engine.exportFrameImage(
            scenes: scenes,
            tileManager: tiles,
            sceneId: 'Scene0001',
            frameIndex: 0,
            drawingWidth: w,
            drawingHeight: h,
            width: w,
            height: h,
            backgroundColor: 0xFFFFFFFF,
            asJpeg: true,
          ),
        ),
      ];

  List<String> exportedNames() => [
    if (exportsDir().existsSync())
      for (final f in exportsDir().listSync()) f.uri.pathSegments.last,
  ];

  for (final (name, extension, export) in formats) {
    test('a $name export whose write fails part way leaves nothing in the '
        'exports folder or the Works list', () async {
      // The Works list remembers the exports folder first, as when the Works
      // tab was opened before the export.
      expect(await ExportEngine.listExportedFiles(forceRefresh: true), isEmpty);
      final tiles = paintedTiles();
      final probe = _WriteProbe(exportsDir().path)..fail = true;
      IOOverrides.global = probe;
      await expectLater(
        export(ExportEngine(), tiles),
        throwsA(isA<FileSystemException>()),
      );
      IOOverrides.global = null;

      expect(
        exportedNames(),
        isEmpty,
        reason: 'the half-written file stayed in the exports folder',
      );
      expect(probe.listedWhileWriting, hasLength(1));
      expect(
        probe.listedWhileWriting.single,
        isEmpty,
        reason: 'the file being written was in the Works list',
      );
      expect(
        await ExportEngine.listExportedFiles(),
        isEmpty,
        reason: 'the broken file is shown in the Works list',
      );
    });

    test('a $name export that succeeds writes the whole file under its own '
        'name and shows it in the Works list', () async {
      expect(await ExportEngine.listExportedFiles(forceRefresh: true), isEmpty);
      final tiles = paintedTiles();
      final probe = _WriteProbe(exportsDir().path);
      IOOverrides.global = probe;
      final output = await export(ExportEngine(), tiles);
      IOOverrides.global = null;

      expect(output, endsWith(extension));
      expect(File(output).parent.path, exportsDir().path);
      expect(
        probe.listedWhileWriting.single,
        isEmpty,
        reason: 'the file being written was in the Works list',
      );
      expect(exportedNames(), [File(output).uri.pathSegments.last]);
      final bytes = File(output).readAsBytesSync();
      expect(
        ascii.decode(bytes.sublist(1, 4), allowInvalid: true) == 'PNG' ||
            ascii.decode(bytes.sublist(0, 3), allowInvalid: true) == 'GIF' ||
            (bytes[0] == 0xFF && bytes[1] == 0xD8),
        isTrue,
        reason: 'the file does not start with its format header',
      );
      // The end of the file is there (not cut at the half written by the
      // probe before the real write).
      if (extension == '.gif') {
        expect(bytes.last, 0x3B);
        final gif = img.decodeGif(bytes)!;
        expect(gif.numFrames, 2);
        expect(gif.frames.map((frame) => frame.frameDuration), [500, 500]);
        expect(root.listSync().whereType<Directory>().map((d) => d.path), [
          documents.path,
        ]);
      }
      if (extension == '.png') {
        expect(
          ascii.decode(bytes.sublist(bytes.length - 8, bytes.length - 4)),
          'IEND',
        );
      }
      if (extension == '.jpg') {
        expect(bytes.sublist(bytes.length - 2), [0xFF, 0xD9]);
      }
      expect(
        [for (final f in await ExportEngine.listExportedFiles()) f.path],
        [output],
        reason: 'the Works list did not pick up the new file',
      );
    });
  }
}
