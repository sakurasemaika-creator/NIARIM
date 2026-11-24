import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_audio.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/services/export_storage.dart';

/// The timeline's sounds in the exported videos (所有者の判断、2026-11-23
/// 「音を入れる」). Before, no video export had any sound.
///
/// The plan places each sound as the timeline plays it. WebM and AVI run the
/// app's FFmpeg arguments on this computer's FFmpeg and the output is read
/// back: the tone must be silent before its clip and sound after it. MP4's
/// sound is made by the device's AAC encoder (checked on a device); here the
/// WAV handed to it is checked the same way.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _hwEncoderChannel = MethodChannel('com.niarim.niarim/hw_video_encoder');
const _ffmpegChannel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');
const _ffmpegEventChannel = EventChannel(
  'flutter.arthenica.com/ffmpeg_kit_event',
);

bool _hasTool(String tool) {
  try {
    return Process.runSync(tool, ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Scene _scene(
  String id,
  int index,
  int frames, {
  List<AudioClip> audio = const [],
  List<Layer> layers = const [],
}) => Scene(
  id: id,
  index: index,
  frames: [
    for (var f = 0; f < frames; f++)
      Frame(index: f, layers: f == 0 ? layers : const []),
  ],
  audioClips: audio,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the plan', () {
    late Directory dir;
    late Map<String, String> files;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('niarim-audio-plan-');
      files = {
        for (final id in ['a', 'b', 'v'])
          id: (File('${dir.path}/$id.wav')..writeAsBytesSync([0])).path,
      };
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<ExportAudioPlan> plan(List<Scene> scenes, {int? maxSeconds}) =>
        buildExportAudioPlan(
          scenes: scenes,
          sourceFps: 10,
          maxSeconds: maxSeconds,
          pathOf: (id) async => files[id],
        );

    test(
      'clips start where their scene starts, after the scenes before',
      () async {
        final result = await plan([
          _scene(
            's1',
            0,
            20,
            audio: const [
              AudioClip(
                id: 'c1',
                label: 'a',
                materialId: 'a',
                startFrame: 5,
                lengthFrames: 10,
                sourceStartFrame: 3,
                volume: 0.5,
                fadeIn: 0.2,
                fadeOut: 0.4,
              ),
            ],
          ),
          _scene(
            's2',
            1,
            30,
            audio: const [
              AudioClip(
                id: 'c2',
                label: 'b',
                materialId: 'b',
                startFrame: 0,
                lengthFrames: 10,
              ),
            ],
          ),
        ]);
        expect(result.missing, 0);
        expect(result.sources, hasLength(2));
        final first = result.sources[0];
        expect(first.path, files['a']);
        expect(first.startSeconds, closeTo(0.5, 1e-9));
        expect(first.sourceSeconds, closeTo(0.3, 1e-9));
        expect(first.durationSeconds, closeTo(1.0, 1e-9));
        expect(first.volume, 0.5);
        expect(first.fadeInSeconds, 0.2);
        expect(first.fadeOutSeconds, 0.4);
        // The second scene starts after the first one's 20 frames.
        expect(result.sources[1].startSeconds, closeTo(2.0, 1e-9));
      },
    );

    test('a clip stops at its scene end and at the export limit', () async {
      final result = await plan([
        _scene(
          's1',
          0,
          20,
          audio: const [
            AudioClip(
              id: 'long',
              label: 'a',
              materialId: 'a',
              startFrame: 10,
              lengthFrames: 50,
            ),
          ],
        ),
        _scene(
          's2',
          1,
          100,
          audio: const [
            AudioClip(
              id: 'late',
              label: 'b',
              materialId: 'b',
              startFrame: 5,
              lengthFrames: 50,
            ),
          ],
        ),
      ], maxSeconds: 3);
      // Scene 1: frames 10 to 20 only (1 second), the clip's own length is
      // kept for its fade-out.
      expect(result.sources[0].durationSeconds, closeTo(1.0, 1e-9));
      expect(result.sources[0].clipSeconds, closeTo(5.0, 1e-9));
      // Scene 2 starts at 2 s; the limit (3 s) leaves 0.5 s of the clip.
      expect(result.sources[1].startSeconds, closeTo(2.5, 1e-9));
      expect(result.sources[1].durationSeconds, closeTo(0.5, 1e-9));
    });

    test('a missing material is counted, a silent clip is skipped', () async {
      final result = await plan([
        _scene(
          's1',
          0,
          20,
          audio: const [
            AudioClip(
              id: 'gone',
              label: 'x',
              materialId: 'gone',
              startFrame: 0,
              lengthFrames: 5,
            ),
            AudioClip(
              id: 'mute',
              label: 'a',
              materialId: 'a',
              startFrame: 0,
              lengthFrames: 5,
              volume: 0,
            ),
            AudioClip(id: 'none', label: 'n', startFrame: 0, lengthFrames: 5),
          ],
        ),
      ]);
      expect(result.sources, isEmpty);
      expect(result.missing, 1);
    });

    test('a video material sounds over the frames it shows, once', () async {
      const video = Layer(
        id: 'vid',
        name: 'clip',
        type: LayerType.timelineVideo,
        materialId: 'v',
        rangeStart: 4,
        rangeEnd: 14,
        sourceTrimStart: 7,
        videoVolume: 0.8,
      );
      final scene = Scene(
        id: 's1',
        index: 0,
        frames: [
          for (var f = 0; f < 20; f++)
            Frame(index: f, layers: f < 2 ? const [video] : const []),
        ],
      );
      final result = await plan([scene]);
      expect(result.sources, hasLength(1));
      final source = result.sources.single;
      expect(source.path, files['v']);
      expect(source.startSeconds, closeTo(0.3, 1e-9));
      expect(source.durationSeconds, closeTo(1.1, 1e-9));
      expect(source.sourceSeconds, closeTo(0.7, 1e-9));
      expect(source.volume, 0.8);
    });

    test('the FFmpeg arguments cut, fade and place the sound', () {
      const source = ExportAudioSource(
        path: '/in.mp3',
        startSeconds: 1.5,
        sourceSeconds: 0.25,
        durationSeconds: 2,
        clipSeconds: 5,
        volume: 0.5,
        fadeInSeconds: 0.5,
        fadeOutSeconds: 1,
      );
      final args = exportAudioSourceArguments(source, '/out.wav');
      expect(args.sublist(0, 7), [
        '-y',
        '-ss',
        '0.250',
        '-t',
        '2.000',
        '-i',
        '/in.mp3',
      ]);
      final filters = args[args.indexOf('-af') + 1];
      expect(filters, contains('volume=0.500'));
      expect(filters, contains('afade=t=in:st=0:d=0.500'));
      // The fade-out would start at 4 s of a 5 s clip, after the 2 s used.
      expect(filters, isNot(contains('t=out')));
      final mix = exportAudioMixArguments(
        [(path: '/a.wav', startSeconds: 1.5)],
        6,
        '/mix.wav',
      );
      final graph = mix[mix.indexOf('-filter_complex') + 1];
      expect(graph, contains('adelay=1500:all=1'));
      expect(graph, contains('normalize=0'));
      expect(graph, contains('apad=whole_dur=6.000'));
    });
  });

  group('shared preview/export envelope', () {
    test('preview gain uses the same clip-relative linear fade boundaries', () {
      double gain(double elapsed) => AudioClipEnvelope.gainAt(
        elapsedSeconds: elapsed,
        clipSeconds: 5,
        volume: 0.8,
        fadeInSeconds: 0.5,
        fadeOutSeconds: 1,
      );

      expect(gain(0), 0);
      expect(gain(0.25), closeTo(0.4, 1e-9));
      expect(gain(1), closeTo(0.8, 1e-9));
      expect(gain(4.5), closeTo(0.4, 1e-9));
      expect(gain(5), 0);
      expect(gain(-0.1), 0);
    });

    test('overlapping fades multiply and export uses matching fade bounds', () {
      final overlap = AudioClipEnvelope.gainAt(
        elapsedSeconds: 0.5,
        clipSeconds: 1,
        volume: 0.8,
        fadeInSeconds: 1,
        fadeOutSeconds: 1,
      );
      expect(overlap, closeTo(0.2, 1e-9));

      final filters = AudioClipEnvelope.ffmpegFilters(
        clipSeconds: 5,
        durationSeconds: 5,
        volume: 0.8,
        fadeInSeconds: 0.5,
        fadeOutSeconds: 1,
      );
      expect(filters, [
        'volume=0.800',
        'afade=t=in:st=0:d=0.500',
        'afade=t=out:st=4.000:d=1.000',
      ]);
    });

    test('export does not fade a clip cut off before its own fade-out', () {
      final filters = AudioClipEnvelope.ffmpegFilters(
        clipSeconds: 5,
        durationSeconds: 2,
        volume: 0.6,
        fadeOutSeconds: 1,
      );
      expect(filters, ['volume=0.600']);
    });
  });

  group('real files', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final tools = _hasTool('ffmpeg') && _hasTool('ffprobe');
    late Directory root;
    late Directory documents;
    late Directory temporary;
    late List<Map<Object?, Object?>> encoderCalls;

    setUp(() {
      root = Directory.systemTemp.createTempSync('niarim-export-audio-');
      documents = Directory('${root.path}/documents')..createSync();
      temporary = Directory('${root.path}/temporary')..createSync();
      encoderCalls = [];
      ExportStorage.invalidate();
      messenger.setMockMethodCallHandler(_pathChannel, (call) async {
        if (call.method == 'getTemporaryDirectory') return temporary.path;
        return documents.path;
      });
      messenger.setMockMethodCallHandler(_hwEncoderChannel, (call) async {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        final audio = args['audioPath'] as String?;
        // The mix is removed after the export, so it is kept now.
        if (audio != null) {
          args['audioBytes'] = File(audio).readAsBytesSync();
        }
        encoderCalls.add(args);
        File(args['outputPath']! as String).writeAsBytesSync([0, 0, 0, 0]);
        return audio != null;
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
            return <String, Object?>{
              'sessionId': arguments.hashCode,
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

    tearDown(() {
      messenger.setMockMethodCallHandler(_pathChannel, null);
      messenger.setMockMethodCallHandler(_hwEncoderChannel, null);
      messenger.setMockMethodCallHandler(_ffmpegChannel, null);
      messenger.setMockStreamHandler(_ffmpegEventChannel, null);
      ExportStorage.invalidate();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    /// A 440 Hz tone of [seconds] as an MP3 (a usual material file).
    String tone(double seconds) {
      final path = '${root.path}/tone.mp3';
      final run = Process.runSync('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=$seconds',
        path,
      ]);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      return path;
    }

    /// A video file without any sound.
    String silentVideo() {
      final path = '${root.path}/silent.mp4';
      final run = Process.runSync('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=32x32:d=2',
        '-c:v',
        'mpeg4',
        path,
      ]);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      return path;
    }

    /// The loudness (RMS of 16-bit samples) of each 0.25 s of [path]'s sound.
    List<double> loudness(String path) {
      final run = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-i',
        path,
        '-vn',
        '-f',
        's16le',
        '-ac',
        '1',
        '-ar',
        '8000',
        '-',
      ], stdoutEncoding: null);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final bytes = Uint8List.fromList(run.stdout as List<int>);
      final samples = bytes.buffer.asInt16List(0, bytes.length ~/ 2);
      const window = 2000;
      return [
        for (var i = 0; i + window <= samples.length; i += window)
          math.sqrt(
            samples
                    .sublist(i, i + window)
                    .fold<double>(0, (s, v) => s + v * v) /
                window,
          ),
      ];
    }

    Map<String, dynamic> audioStream(String path) {
      final run = Process.runSync('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'a:0',
        '-show_entries',
        'stream=codec_name,sample_rate,channels',
        '-show_entries',
        'format=duration',
        '-of',
        'json',
        path,
      ]);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final json = jsonDecode(run.stdout as String) as Map<String, dynamic>;
      final streams = json['streams'] as List;
      return {
        if (streams.isNotEmpty) ...streams.first as Map<String, dynamic>,
        'duration': double.parse(
          (json['format'] as Map<String, dynamic>)['duration'] as String,
        ),
      };
    }

    const layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);

    TileManager tiles(int frames) {
      final manager = TileManager(canvasWidth: 32, canvasHeight: 32);
      addTearDown(manager.dispose);
      final pixels = Uint8List(32 * 32 * 4)..fillRange(0, 32 * 32 * 4, 255);
      for (var f = 0; f < frames; f++) {
        manager.replaceLayerPixels(
          frameLayerKey('Scene0001', f, layer.id),
          pixels,
        );
      }
      return manager;
    }

    /// 4 seconds at 4 fps; the tone (1.5 s) starts at frame 4 (1 s), plus a
    /// silent video material.
    Future<(List<Scene>, ExportAudioPlan)> project() async {
      final tonePath = tone(3);
      final videoPath = silentVideo();
      final scenes = [
        Scene(
          id: 'Scene0001',
          index: 0,
          frames: [
            for (var f = 0; f < 16; f++)
              Frame(
                index: f,
                layers: [
                  layer,
                  if (f == 0)
                    const Layer(
                      id: 'vid',
                      name: 'silent',
                      type: LayerType.timelineVideo,
                      materialId: 'video',
                      rangeStart: 1,
                      rangeEnd: 9,
                    ),
                ],
              ),
          ],
          audioClips: const [
            AudioClip(
              id: 'beep',
              label: 'tone',
              materialId: 'tone',
              startFrame: 4,
              lengthFrames: 6,
            ),
          ],
        ),
      ];
      final plan = await buildExportAudioPlan(
        scenes: scenes,
        sourceFps: 4,
        pathOf: (id) async => {'tone': tonePath, 'video': videoPath}[id],
      );
      return (scenes, plan);
    }

    void expectTonePlacement(List<double> windows, {required double seconds}) {
      // 0.25 s windows: silent for the first second, sounding from 1.0 to
      // 2.5 s, silent again after it.
      expect(windows.length, closeTo(seconds * 4, 1));
      for (var i = 0; i < 4; i++) {
        expect(windows[i], lessThan(50), reason: 'before the clip, $i');
      }
      for (var i = 4; i < 10; i++) {
        expect(windows[i], greaterThan(1000), reason: 'in the clip, $i');
      }
      for (var i = 10; i < windows.length; i++) {
        expect(windows[i], lessThan(50), reason: 'after the clip, $i');
      }
    }

    for (final (name, codec) in [('WebM', 'opus'), ('AVI', 'pcm_s16le')]) {
      test(
        '$name carries the tone where its clip is, and the end mark is silent',
        () async {
          final (scenes, plan) = await project();
          final engine = ExportEngine();
          Future<String> run() => name == 'WebM'
              ? engine.exportWebm(
                  scenes: scenes,
                  tileManager: tiles(16),
                  fps: 4,
                  drawingWidth: 32,
                  drawingHeight: 32,
                  width: 32,
                  height: 32,
                  backgroundColor: 0xFFFFFFFF,
                  appendEndCard: true,
                  audio: plan,
                )
              : engine.exportAvi(
                  scenes: scenes,
                  tileManager: tiles(16),
                  fps: 4,
                  drawingWidth: 32,
                  drawingHeight: 32,
                  width: 32,
                  height: 32,
                  backgroundColor: 0xFFFFFFFF,
                  appendEndCard: true,
                  audio: plan,
                );
          final path = await run();
          final stream = audioStream(path);
          expect(stream['codec_name'], codec);
          expect(stream['sample_rate'], '48000');
          expect(stream['channels'], 2);
          // 4 s of work + 5 s of end mark.
          expect(stream['duration'] as double, closeTo(9, 0.15));
          expectTonePlacement(loudness(path), seconds: 9);
          // The silent video has no sound to put in.
          expect(engine.audioLeftOut, 1);
          expect(temporary.listSync().whereType<Directory>(), isEmpty);
        },
        skip: tools ? false : 'ffmpeg and ffprobe are not installed',
      );
    }

    test(
      'MP4 hands the device the same sound as a 48 kHz stereo WAV',
      () async {
        final (scenes, plan) = await project();
        final engine = ExportEngine();
        await engine.exportMp4(
          scenes: scenes,
          tileManager: tiles(16),
          fps: 4,
          drawingWidth: 32,
          drawingHeight: 32,
          width: 32,
          height: 32,
          backgroundColor: 0xFFFFFFFF,
          audio: plan,
        );
        final call = encoderCalls.single;
        final wav = File('${root.path}/mix.wav')
          ..writeAsBytesSync(call['audioBytes']! as List<int>);
        final stream = audioStream(wav.path);
        expect(stream['codec_name'], 'pcm_s16le');
        expect(stream['sample_rate'], '48000');
        expect(stream['channels'], 2);
        expect(stream['duration'] as double, closeTo(4, 0.05));
        expectTonePlacement(loudness(wav.path), seconds: 4);
        expect(engine.audioLeftOut, 1);
      },
      skip: tools ? false : 'ffmpeg and ffprobe are not installed',
    );

    test('a video without sounds exports as before, with no sound', () async {
      final engine = ExportEngine();
      final scenes = [
        _scene('Scene0001', 0, 4, layers: const [layer]),
      ];
      final path = await engine.exportWebm(
        scenes: scenes,
        tileManager: tiles(4),
        fps: 4,
        drawingWidth: 32,
        drawingHeight: 32,
        width: 32,
        height: 32,
        backgroundColor: 0xFFFFFFFF,
      );
      expect(audioStream(path).containsKey('codec_name'), isFalse);
      expect(engine.audioLeftOut, 0);
      await engine.exportMp4(
        scenes: scenes,
        tileManager: tiles(4),
        fps: 4,
        drawingWidth: 32,
        drawingHeight: 32,
        width: 32,
        height: 32,
        backgroundColor: 0xFFFFFFFF,
      );
      expect(encoderCalls.single.containsKey('audioPath'), isFalse);
    }, skip: tools ? false : 'ffmpeg and ffprobe are not installed');
  });
}
