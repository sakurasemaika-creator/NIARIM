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

/// 動画の書き出し（全面監査のD034）が、本当に再生できる動画になるか。
///
/// WebM・AVIは、アプリがFFmpegへ渡す引数をそのまま、この計算機のffmpegで
/// 走らせ、出来た動画をffprobeとffmpegで読み直して、コーデック・大きさ・
/// コマ数・コマの速さ・各コマの色を確かめる（端末のFFmpegは版が違うが、
/// 引数は同じ）。MP4は端末のMediaCodecが作るのでここでは作れない（実機の
/// 確認）。その代わり、端末へ渡すコマの画像の並び・大きさ・色を確かめる。
/// 奇数の大きさ（63×35）も書き出せること。
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _hwEncoderChannel = MethodChannel('com.niarim.niarim/hw_video_encoder');
const _ffmpegChannel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

const _red = (220, 30, 40);
const _blue = (20, 60, 210);

bool _hasTool(String tool) {
  try {
    return Process.runSync(tool, ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final tools = _hasTool('ffmpeg') && _hasTool('ffprobe');
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late List<List<String>> ffmpegRuns;
  late List<Map<Object?, Object?>> encoderCalls;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-video-output-');
    documents = Directory('${root.path}/documents')..createSync();
    temporary = Directory('${root.path}/temporary')..createSync();
    ffmpegRuns = [];
    encoderCalls = [];
    ExportStorage.invalidate();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (call.method == 'getTemporaryDirectory') return temporary.path;
      return documents.path;
    });
    messenger.setMockMethodCallHandler(_hwEncoderChannel, (call) async {
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      // The frames are removed after the export, so they are read now.
      args['frames'] = [
        for (final path in (args['framePaths']! as List).cast<String>())
          img.decodePng(File(path).readAsBytesSync())!,
      ];
      encoderCalls.add(args);
      File(args['outputPath']! as String).writeAsBytesSync([0, 0, 0, 0]);
      return null;
    });
    var arguments = const <String>[];
    var exitCode = 1;
    var output = '';
    messenger.setMockMethodCallHandler(_ffmpegChannel, (call) async {
      switch (call.method) {
        case 'ffmpegSession':
          arguments = List<String>.from(
            (call.arguments as Map<Object?, Object?>)['arguments']! as List,
          );
          ffmpegRuns.add(arguments);
          return <String, Object?>{
            'sessionId': ffmpegRuns.length,
            'createTime': DateTime.now().millisecondsSinceEpoch,
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'command': arguments.join(' '),
          };
        case 'ffmpegSessionExecute':
          final run = Process.runSync('ffmpeg', [
            '-hide_banner',
            '-loglevel',
            'error',
            ...arguments,
          ]);
          exitCode = run.exitCode;
          output = '${run.stdout}${run.stderr}';
          return null;
        case 'abstractSessionGetReturnCode':
          return exitCode;
        case 'abstractSessionGetOutput':
        case 'abstractSessionGetAllLogsAsString':
          return output;
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

  const layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);
  const scenes = [
    Scene(
      id: 'Scene0001',
      index: 0,
      frames: [
        Frame(index: 0, layers: [layer]),
        Frame(index: 1, layers: [layer]),
        Frame(index: 2, layers: [layer]),
      ],
    ),
  ];

  /// Frames 0 and 2 are red, frame 1 is blue, all opaque.
  TileManager paintedTiles(int w, int h) {
    final tileManager = TileManager(canvasWidth: w, canvasHeight: h);
    addTearDown(tileManager.dispose);
    for (final frame in scenes.single.frames) {
      final (r, g, b) = frame.index == 1 ? _blue : _red;
      final pixels = Uint8List(w * h * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels
          ..[i] = r
          ..[i + 1] = g
          ..[i + 2] = b
          ..[i + 3] = 255;
      }
      tileManager.replaceLayerPixels(
        frameLayerKey('Scene0001', frame.index, layer.id),
        pixels,
      );
    }
    return tileManager;
  }

  Map<String, dynamic> probe(String path) {
    final run = Process.runSync('ffprobe', [
      '-v',
      'error',
      '-count_frames',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream=codec_name,width,height,r_frame_rate,nb_read_frames',
      '-of',
      'json',
      path,
    ]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    return ((jsonDecode(run.stdout as String) as Map)['streams'] as List).first
        as Map<String, dynamic>;
  }

  /// The colour in the middle of each decoded frame.
  List<(int, int, int)> frameColours(String path, int w, int h) {
    final run = Process.runSync('ffmpeg', [
      '-v',
      'error',
      '-i',
      path,
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgb24',
      '-',
    ], stdoutEncoding: null);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    final bytes = run.stdout as List<int>;
    final frameBytes = w * h * 3;
    return [
      for (var f = 0; f + frameBytes <= bytes.length; f += frameBytes)
        (
          bytes[f + ((h ~/ 2) * w + w ~/ 2) * 3],
          bytes[f + ((h ~/ 2) * w + w ~/ 2) * 3 + 1],
          bytes[f + ((h ~/ 2) * w + w ~/ 2) * 3 + 2],
        ),
    ];
  }

  void expectNear((int, int, int) actual, (int, int, int) expected, String r) {
    expect((actual.$1 - expected.$1).abs(), lessThan(24), reason: r);
    expect((actual.$2 - expected.$2).abs(), lessThan(24), reason: r);
    expect((actual.$3 - expected.$3).abs(), lessThan(24), reason: r);
  }

  for (final (w, h) in [(64, 36), (63, 35)]) {
    for (final (name, codec, ext) in [
      ('WebM', 'vp9', '.webm'),
      ('AVI', 'mjpeg', '.avi'),
    ]) {
      for (final endCard in [false, true]) {
        test('$name ${w}x$h${endCard ? ' with the end card' : ''} '
            'is a playable video with every frame', () async {
          final engine = ExportEngine();
          final tiles = paintedTiles(w, h);
          Future<String> run() => name == 'WebM'
              ? engine.exportWebm(
                  projectName: 'Clip',
                  scenes: scenes,
                  tileManager: tiles,
                  fps: 4,
                  drawingWidth: w,
                  drawingHeight: h,
                  width: w,
                  height: h,
                  backgroundColor: 0xFFFFFFFF,
                  appendEndCard: endCard,
                )
              : engine.exportAvi(
                  projectName: 'Clip',
                  scenes: scenes,
                  tileManager: tiles,
                  fps: 4,
                  drawingWidth: w,
                  drawingHeight: h,
                  width: w,
                  height: h,
                  backgroundColor: 0xFFFFFFFF,
                  appendEndCard: endCard,
                );
          final path = await run();
          expect(path, endsWith(ext));
          expect(ffmpegRuns, hasLength(1));
          final info = probe(path);
          expect(info['codec_name'], codec);
          expect(info['width'], w);
          expect(info['height'], h);
          expect(info['r_frame_rate'], '4/1');
          final frames = 3 + (endCard ? 4 * 5 : 0);
          expect(int.parse(info['nb_read_frames'] as String), frames);
          final colours = frameColours(path, w, h);
          expect(colours, hasLength(frames));
          expectNear(colours[0], _red, 'frame 0');
          expectNear(colours[1], _blue, 'frame 1');
          expectNear(colours[2], _red, 'frame 2');
          // The frame folder is removed after the export.
          expect(temporary.listSync().whereType<Directory>(), isEmpty);
        }, skip: tools ? false : 'ffmpeg and ffprobe are not installed');
      }
    }

    test('MP4 ${w}x$h hands the device encoder every frame in order', () async {
      final engine = ExportEngine();
      final tiles = paintedTiles(w, h);
      final path = await engine.exportMp4(
        projectName: 'Clip',
        scenes: scenes,
        tileManager: tiles,
        fps: 4,
        drawingWidth: w,
        drawingHeight: h,
        width: w,
        height: h,
        backgroundColor: 0xFFFFFFFF,
        appendEndCard: true,
      );
      expect(path, endsWith('.mp4'));
      final call = encoderCalls.single;
      expect(call['fps'], 4);
      expect(call['width'], w);
      expect(call['height'], h);
      final frames = (call['frames']! as List).cast<img.Image>();
      expect(frames, hasLength(3 + 4 * 5));
      for (final frame in frames) {
        expect((frame.width, frame.height), (w, h));
      }
      (int, int, int) mid(img.Image f) {
        final p = f.getPixel(w ~/ 2, h ~/ 2);
        return (p.r.toInt(), p.g.toInt(), p.b.toInt());
      }

      expect(mid(frames[0]), _red);
      expect(mid(frames[1]), _blue);
      expect(mid(frames[2]), _red);
      expect(temporary.listSync().whereType<Directory>(), isEmpty);
    });
  }
}
