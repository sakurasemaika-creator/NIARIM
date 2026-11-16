import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/export_storage.dart';

/// 動画（MP4・WebM・AVI）の書き出しが途中で失敗したとき、書きかけの動画を
/// 書き出し先（`niarim/exports`）に残さず、フレームの一時フォルダも消す。
///
/// 以前は、エンコーダー（MP4は端末のMediaCodec、WebM・AVIはFFmpeg）が
/// 失敗すると、書きかけの動画が書き出し先に残って作品一覧に壊れた作品として
/// 出て、フレームのPNGを入れた一時フォルダも消えなかった。
///
/// エンコーダーはテストの環境に無いので、本物と同じ通り道（MP4は
/// `com.niarim.niarim/hw_video_encoder`、FFmpegは`flutter.arthenica.com/
/// ffmpeg_kit`のチャンネル）で受け、本物と同じく書き出し先へ途中まで
/// 書いてから失敗を返す。
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _hwEncoderChannel = MethodChannel('com.niarim.niarim/hw_video_encoder');
const _ffmpegChannel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late bool failDocuments;
  late bool encoderSucceeds;
  late List<String> ffmpegCommands;

  Directory exportsDir() => ExportStorage.managedDirectoryIn(documents);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-export-failure-');
    documents = Directory('${root.path}/documents')..createSync();
    temporary = Directory('${root.path}/temporary')..createSync();
    failDocuments = false;
    encoderSucceeds = false;
    ffmpegCommands = [];
    ExportStorage.invalidate();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
          return temporary.path;
        case 'getApplicationDocumentsDirectory':
          if (failDocuments) {
            throw PlatformException(code: 'unavailable');
          }
          return documents.path;
      }
      return root.path;
    });
    // MediaCodec: like the device, the muxer has already created the file
    // when the encoder fails.
    messenger.setMockMethodCallHandler(_hwEncoderChannel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      final output = File(args['outputPath']! as String);
      output.writeAsBytesSync(encoderSucceeds ? _fullVideo : _halfVideo);
      if (!encoderSucceeds) {
        throw PlatformException(code: 'ENCODE_FAILED', message: 'codec');
      }
      return null;
    });
    // FFmpeg: the output is written while the frames are encoded, and the
    // return code reports the failure afterwards.
    var arguments = const <String>[];
    messenger.setMockMethodCallHandler(_ffmpegChannel, (call) async {
      switch (call.method) {
        case 'ffmpegSession':
          arguments = List<String>.from(
            (call.arguments as Map<Object?, Object?>)['arguments']!
                as List<Object?>,
          );
          ffmpegCommands.add(arguments.join(' '));
          return <String, Object?>{
            'sessionId': ffmpegCommands.length,
            'createTime': DateTime.now().millisecondsSinceEpoch,
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'command': arguments.join(' '),
          };
        case 'ffmpegSessionExecute':
          File(
            arguments.last,
          ).writeAsBytesSync(encoderSucceeds ? _fullVideo : _halfVideo);
          return null;
        case 'abstractSessionGetReturnCode':
          return encoderSucceeds ? 0 : 1;
        case 'abstractSessionGetAllLogsAsString':
          return 'Conversion failed!';
        case 'getArch':
          return 'arm64-v8a';
        case 'getPlatform':
          return 'android';
        case 'getPackageName':
          return 'video';
        case 'isLTSBuild':
          return false;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _ffmpegEventChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    messenger.setMockMethodCallHandler(_hwEncoderChannel, null);
    messenger.setMockMethodCallHandler(_ffmpegChannel, null);
    messenger.setMockStreamHandler(_ffmpegEventChannel, null);
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
        ..[i] = 200
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

  for (final format in ['gif', 'png', 'jpg']) {
    test('an interrupted $format write never publishes the output', () async {
      final tiles = paintedTiles();
      final engine = ExportEngine();
      final generation = ExportStorage.generation;
      final failure = _FailImageWrite();
      await expectLater(
        IOOverrides.runWithIOOverrides(
          () => format == 'gif'
              ? engine.exportGif(
                  scenes: scenes,
                  tileManager: tiles,
                  fps: 1,
                  drawingWidth: w,
                  drawingHeight: h,
                  width: w,
                  height: h,
                  backgroundColor: 0xFFFFFFFF,
                )
              : engine.exportFrameImage(
                  scenes: scenes,
                  tileManager: tiles,
                  sceneId: scenes.single.id,
                  frameIndex: 0,
                  drawingWidth: w,
                  drawingHeight: h,
                  width: w,
                  height: h,
                  backgroundColor: 0xFFFFFFFF,
                  asJpeg: format == 'jpg',
                ),
          failure,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(failure.wrotePartialBytes, isTrue);
      expect(await exportsDir().list().toList(), isEmpty);
      expect(await ExportEngine.listExportedFiles(forceRefresh: true), isEmpty);
      expect(ExportStorage.generation, generation);
    });
  }

  final formats =
      <
        (
          String,
          String,
          Future<String> Function(ExportEngine, TileManager, bool endCard),
        )
      >[
        (
          'MP4',
          'export_frames',
          (engine, tiles, endCard) => engine.exportMp4(
            scenes: scenes,
            tileManager: tiles,
            fps: 1,
            drawingWidth: w,
            drawingHeight: h,
            width: w,
            height: h,
            backgroundColor: 0xFFFFFFFF,
            appendEndCard: endCard,
          ),
        ),
        (
          'WebM',
          'export_webm_frames',
          (engine, tiles, endCard) => engine.exportWebm(
            scenes: scenes,
            tileManager: tiles,
            fps: 1,
            drawingWidth: w,
            drawingHeight: h,
            width: w,
            height: h,
            backgroundColor: 0xFFFFFFFF,
            appendEndCard: endCard,
          ),
        ),
        (
          'AVI',
          'export_avi_frames',
          (engine, tiles, endCard) => engine.exportAvi(
            scenes: scenes,
            tileManager: tiles,
            fps: 1,
            drawingWidth: w,
            drawingHeight: h,
            width: w,
            height: h,
            backgroundColor: 0xFFFFFFFF,
            appendEndCard: endCard,
          ),
        ),
      ];

  List<String> exportedNames() => [
    if (exportsDir().existsSync())
      for (final f in exportsDir().listSync()) f.uri.pathSegments.last,
  ];

  for (final (name, framesFolder, export) in formats) {
    test('a $name export whose encoder fails leaves no video in the exports '
        'folder and no frame folder', () async {
      // Let the Works list remember the exports folder first, as when the
      // Works tab was opened before the export.
      expect(await ExportEngine.listExportedFiles(forceRefresh: true), isEmpty);

      await expectLater(
        export(ExportEngine(), paintedTiles(), false),
        throwsA(anything),
      );

      expect(
        exportedNames(),
        isEmpty,
        reason: 'the half-written video stayed in the exports folder',
      );
      expect(
        Directory('${temporary.path}/$framesFolder').existsSync(),
        isFalse,
        reason: 'the frame folder was not removed',
      );
      expect(
        await ExportEngine.listExportedFiles(),
        isEmpty,
        reason: 'the broken video is shown in the Works list',
      );
    });

    test('a $name export that fails before the encoder (the exports folder '
        'is unavailable) removes its frame folder', () async {
      failDocuments = true;
      await expectLater(
        export(ExportEngine(), paintedTiles(), false),
        throwsA(isA<PlatformException>()),
      );
      expect(
        Directory('${temporary.path}/$framesFolder').existsSync(),
        isFalse,
      );
    });

    test('a $name export that succeeds keeps its video and removes its frame '
        'folder', () async {
      encoderSucceeds = true;
      final output = await export(ExportEngine(), paintedTiles(), true);

      expect(File(output).readAsBytesSync(), _fullVideo);
      expect(exportedNames(), [File(output).uri.pathSegments.last]);
      expect(File(output).parent.path, exportsDir().path);
      expect(
        Directory('${temporary.path}/$framesFolder').existsSync(),
        isFalse,
      );
      expect(
        [for (final f in await ExportEngine.listExportedFiles()) f.path],
        [output],
      );
      if (name != 'MP4') {
        expect(ffmpegCommands.single, contains(output));
      }
    });
  }
}

final _fullVideo = Uint8List.fromList([for (var i = 0; i < 64; i++) i]);
final _halfVideo = Uint8List.fromList([for (var i = 0; i < 16; i++) i]);

final class _FailImageWrite extends IOOverrides {
  bool wrotePartialBytes = false;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.endsWith('image.part') ? _PartialImageFile(file, this) : file;
  }
}

class _PartialImageFile implements File {
  _PartialImageFile(this.file, this.probe);

  final File file;
  final _FailImageWrite probe;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await file.writeAsBytes(bytes.take(4).toList(), mode: mode, flush: flush);
    probe.wrotePartialBytes = true;
    throw FileSystemException('simulated full disk', file.path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
