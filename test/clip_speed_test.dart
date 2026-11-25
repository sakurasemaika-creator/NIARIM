import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/clip_speed.dart';
import 'package:niarim/engine/export_audio.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_video_time.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

final _ffmpegTests =
    Platform.environment['NIARIM_VIDEO_FRAME_FFMPEG_TESTS'] == '1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speed values', () {
    test('only finite speeds from 0.01 to 100 are valid', () {
      for (final rate in [0.01, 0.1, 0.5, 1, 2, 16, 100, 1.37]) {
        expect(isValidPlaybackRate(rate.toDouble()), isTrue, reason: '$rate');
      }
      for (final rate in [
        0.0,
        -1.0,
        0.009,
        100.01,
        double.nan,
        double.infinity,
      ]) {
        expect(isValidPlaybackRate(rate), isFalse, reason: '$rate');
      }
    });

    test('the slider is logarithmic from 0.1x to 16x', () {
      expect(playbackRateToSlider(0.1), 0);
      expect(playbackRateToSlider(16), closeTo(1, 1e-12));
      expect(playbackRateToSlider(1), closeTo(0.454, 0.001));
      // Low speeds get as much travel as high ones: 0.1→1 and 1→10 match.
      expect(
        playbackRateToSlider(1) - playbackRateToSlider(0.1),
        closeTo(playbackRateToSlider(10) - playbackRateToSlider(1), 1e-9),
      );
      for (final rate in [0.1, 0.25, 0.5, 1, 2, 4, 8, 16]) {
        expect(
          sliderToPlaybackRate(playbackRateToSlider(rate.toDouble())),
          closeTo(rate, 0.006),
        );
      }
      // Typed speeds outside the slider sit at its ends.
      expect(playbackRateToSlider(0.01), 0);
      expect(playbackRateToSlider(100), 1);
    });

    test('typed speeds accept decimals, commas and an x', () {
      expect(parsePlaybackRate('1.5'), 1.5);
      expect(parsePlaybackRate(' 0,25 '), 0.25);
      expect(parsePlaybackRate('2x'), 2);
      expect(parsePlaybackRate('100×'), 100);
      expect(parsePlaybackRate('0.01'), 0.01);
      for (final text in ['', '0', '-2', '101', 'abc', '1.', 'nan']) {
        expect(
          parsePlaybackRate(text),
          text == '1.' ? 1 : isNull,
          reason: text,
        );
      }
    });

    test('speeds read without trailing zeros', () {
      expect(formatPlaybackRate(1), '1x');
      expect(formatPlaybackRate(1.5), '1.5x');
      expect(formatPlaybackRate(0.25), '0.25x');
      expect(formatPlaybackRate(100), '100x');
      expect(formatPlaybackRate(0.01), '0.01x');
    });
  });

  group('lengths and positions', () {
    test('the timeline length is the source time divided by the speed', () {
      expect(timelineLengthForSource(48, 1), 48);
      expect(timelineLengthForSource(48, 2), 24);
      expect(timelineLengthForSource(48, 0.5), 96);
      expect(timelineLengthForSource(48, 0.1), 480);
      expect(timelineLengthForSource(48, 16), 3);
      expect(timelineLengthForSource(48, 1.5), 32);
      // At least one frame, even at 100x.
      expect(timelineLengthForSource(48, 100), 1);
      expect(timelineLengthForSource(10, 3), 3);
    });

    test('a split keeps the exact source position, fraction included', () {
      expect(
        sourcePositionAfter(
          startFrame: 4,
          startFraction: 0,
          elapsedFrames: 3,
          rate: 1.5,
        ),
        (frame: 8, fraction: 0.5),
      );
      expect(
        sourcePositionAfter(
          startFrame: 8,
          startFraction: 0.5,
          elapsedFrames: 1,
          rate: 1.5,
        ),
        (frame: 10, fraction: 0.0),
      );
      // 0.1 × 10 is 0.9999999… in binary: still frame 1.
      expect(
        sourcePositionAfter(
          startFrame: 0,
          startFraction: 0,
          elapsedFrames: 10,
          rate: 0.1,
        ),
        (frame: 1, fraction: 0.0),
      );
    });

    test('a split video plays the same source time as before', () {
      // A clip from timeline frame 3, 20 frames, trim 5–40, at 1.5x.
      const whole = Layer(
        id: 'v',
        name: 'v',
        type: LayerType.timelineVideo,
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: 4,
        rangeEnd: 23,
        sourceTrimStart: 5,
        sourceTrimEnd: 40,
        playbackRate: 1.5,
      );
      for (final split in [4, 7, 10, 15]) {
        final elapsed = split - 3;
        final right = sourcePositionAfter(
          startFrame: 5,
          startFraction: 0,
          elapsedFrames: elapsed,
          rate: 1.5,
        );
        final rightLayer = whole.copyWith(
          rangeStart: split + 1,
          sourceTrimStart: right.frame,
          sourceTrimStartFraction: right.fraction,
        );
        for (var frame = split; frame <= 22; frame++) {
          expect(
            TimelineVideoTimeMapper.layerSourceTimeAt(rightLayer, frame, 24),
            TimelineVideoTimeMapper.layerSourceTimeAt(whole, frame, 24),
            reason: 'split at $split, frame $frame',
          );
        }
      }
    });

    test('the video time follows the speed', () {
      const clip = Layer(
        id: 'v',
        name: 'v',
        type: LayerType.timelineVideo,
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: 1,
        rangeEnd: 10,
        sourceTrimStart: 0,
        sourceTrimEnd: 100,
        playbackRate: 4,
      );
      expect(
        TimelineVideoTimeMapper.layerSourceTimeAt(clip, 3, 10),
        const Duration(milliseconds: 1200),
      );
      // Past the trim the last frame is held.
      expect(
        TimelineVideoTimeMapper.layerSourceTimeAt(
          clip.copyWith(sourceTrimEnd: 8),
          3,
          10,
        ),
        const Duration(milliseconds: 800),
      );
    });
  });

  group('keyframe retiming', () {
    const keys = [
      LayerKeyframe(frameIndex: 2, x: 1),
      LayerKeyframe(frameIndex: 10, x: 2, easing: LayerKeyframeEasing.easeIn),
      LayerKeyframe(frameIndex: 14, x: 3),
      LayerKeyframe(frameIndex: 30, x: 4),
    ];

    test('scales the time from the anchor and keeps values and easing', () {
      final faster = retimeKeyframes(keys, anchorFrame: 10, factor: 2)!;
      expect(faster.map((k) => k.frameIndex), [2, 10, 12, 20]);
      expect(faster.map((k) => k.x), [1, 2, 3, 4]);
      expect(faster[1].easing, LayerKeyframeEasing.easeIn);
      final slower = retimeKeyframes(keys, anchorFrame: 10, factor: 0.5)!;
      expect(slower.map((k) => k.frameIndex), [2, 10, 18, 50]);
    });

    test('refuses a speed that would put two keyframes on one frame', () {
      expect(retimeKeyframes(keys, anchorFrame: 10, factor: 16), isNull);
      expect(retimeKeyframes(keys, anchorFrame: 10, factor: 0), isNull);
    });

    test('speeds changed back and forth bring every key back to its frame', () {
      // A clip at 1x with keys 7 and 11 frames after its start.
      const start = [
        LayerKeyframe(frameIndex: 10),
        LayerKeyframe(frameIndex: 17, x: 5),
        LayerKeyframe(frameIndex: 21, x: 9),
      ];
      // 1x → 3x → 1x: 17 lands on 10 + 7 / 3 ≈ 12.33 (frame 12), then
      // back on 17, not 10 + 2 × 3 = 16.
      final fast = retimeKeyframes(start, anchorFrame: 10, factor: 3)!;
      expect(fast.map((k) => k.frameIndex), [10, 12, 14]);
      expect(fast[1].exactFrame, closeTo(10 + 7 / 3, 1e-9));
      final back = retimeKeyframes(fast, anchorFrame: 10, factor: 1 / 3)!;
      expect(back.map((k) => k.frameIndex), [10, 17, 21]);
      // On its frame again, the key has no fraction left to keep.
      expect(back.map((k) => k.exactFrame), [null, null, null]);

      // Many speeds in turn, back to 1x: still the frames it started on.
      var keys = start;
      var rate = 1.0;
      for (final next in [0.7, 1.3, 2.5, 0.45, 1.9, 1.0]) {
        keys = retimeKeyframes(keys, anchorFrame: 10, factor: next / rate)!;
        rate = next;
      }
      expect(keys.map((k) => k.frameIndex), [10, 17, 21]);
      expect(keys.map((k) => k.x), [0, 5, 9]);
    });

    test('a key moved by whole frames keeps its fraction; one moved '
        'without it falls back to its frame; the fraction is saved', () {
      const key = LayerKeyframe(frameIndex: 12, exactFrame: 12.25);
      expect(key.exactTime, 12.25);
      final moved = key.copyWith(frameIndex: 20);
      expect(moved.exactFrame, 20.25);
      expect(moved.exactTime, 20.25);
      // A key whose fraction no longer rounds to its frame is on its frame.
      const stale = LayerKeyframe(frameIndex: 30, exactFrame: 12.25);
      expect(stale.exactTime, 30);
      expect(key.copyWith(exactFrame: null).exactFrame, isNull);
      final read = LayerKeyframe.fromJson(key.toJson());
      expect(read.exactFrame, 12.25);
      expect(
        const LayerKeyframe(frameIndex: 3).toJson().containsKey('exactFrame'),
        isFalse,
      );
      expect(
        LayerKeyframe.fromJson({...key.toJson(), 'exactFrame': 'x'}).exactFrame,
        isNull,
      );
    });
  });

  group('key range retiming', () {
    const keys = [0, 4, 8, 12, 20];

    test('spaces the range\'s keys by 1 / speed from its first key; keys '
        'outside it stay put', () {
      expect(retimeKeyRange(keys, fromFrame: 4, toFrame: 12, rate: 2), {
        0: 0,
        4: 4,
        8: 6,
        12: 8,
        20: 20,
      });
      expect(retimeKeyRange(keys, fromFrame: 0, toFrame: 8, rate: 0.75), {
        0: 0,
        4: 5,
        8: 11,
        12: 12,
        20: 20,
      });
    });

    test('refuses keys on one frame, passing a later key, leaving the scene '
        'or a range without two keys', () {
      // 100x puts 4, 8 and 12 on frame 4.
      expect(
        retimeKeyRange(keys, fromFrame: 4, toFrame: 12, rate: 100),
        isNull,
      );
      // 0.5x would move 12 to 20, onto the key after the range.
      expect(
        retimeKeyRange(keys, fromFrame: 4, toFrame: 12, rate: 0.5),
        isNull,
      );
      // 0.25x would move 8 past 12 (the key after the range).
      expect(
        retimeKeyRange(keys, fromFrame: 0, toFrame: 8, rate: 0.25),
        isNull,
      );
      // The last range reaching past the scene's last frame.
      expect(
        retimeKeyRange(
          keys,
          fromFrame: 12,
          toFrame: 20,
          rate: 0.5,
          lastFrame: 23,
        ),
        isNull,
      );
      expect(
        retimeKeyRange(
          keys,
          fromFrame: 12,
          toFrame: 20,
          rate: 0.5,
          lastFrame: 28,
        ),
        {0: 0, 4: 4, 8: 8, 12: 12, 20: 28},
      );
      expect(retimeKeyRange(keys, fromFrame: 5, toFrame: 7, rate: 2), isNull);
      expect(retimeKeyRange(keys, fromFrame: 4, toFrame: 4, rate: 2), isNull);
      expect(retimeKeyRange(keys, fromFrame: 0, toFrame: 20, rate: 0), isNull);
    });

    test('moves keys keeping their values and easing', () {
      const animation = [
        LayerKeyframe(frameIndex: 0, x: 1),
        LayerKeyframe(
          frameIndex: 10,
          x: 2,
          easing: LayerKeyframeEasing.easeOut,
        ),
        LayerKeyframe(frameIndex: 20, x: 3),
      ];
      final moved = moveKeyframes(
        animation,
        retimeKeyRange(
          [for (final k in animation) k.frameIndex],
          fromFrame: 0,
          toFrame: 20,
          rate: 2,
        )!,
        frameOf: (k) => k.frameIndex,
        withFrame: (k, f) => k.copyWith(frameIndex: f),
      );
      expect(moved.map((k) => k.frameIndex), [0, 5, 10]);
      expect(moved.map((k) => k.x), [1, 2, 3]);
      expect(moved[1].easing, LayerKeyframeEasing.easeOut);
    });
  });

  group('export sound', () {
    test('atempo chains halvings for slow speeds', () {
      double product(List<double> chain) => chain.fold(1.0, (a, b) => a * b);
      for (final rate in [0.01, 0.1, 0.25, 0.5, 1, 2, 16, 100]) {
        final chain = atempoChain(rate.toDouble());
        expect(product(chain), closeTo(rate, 1e-12), reason: '$rate');
        expect(
          chain.every((f) => f >= 0.5 && f <= 100),
          isTrue,
          reason: '$chain',
        );
      }
      expect(atempoChain(2), [2]);
      expect(atempoChain(0.1), [0.5, 0.5, 0.5, 0.8]);
    });

    test('the plan reads the source at the clip speed', () async {
      final dir = Directory.systemTemp.createTempSync('niarim-speed-plan-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.wav')..writeAsBytesSync([0]);
      final plan = await buildExportAudioPlan(
        scenes: [
          Scene(
            id: 'S',
            index: 0,
            frames: [
              for (var i = 0; i < 40; i++)
                Frame(
                  index: i,
                  layers: i == 0
                      ? const [
                          Layer(
                            id: 'v',
                            name: 'v',
                            type: LayerType.timelineVideo,
                            materialId: 'a',
                            rangeMode: LayerRangeMode.frameRange,
                            rangeStart: 21,
                            rangeEnd: 30,
                            sourceTrimStart: 7,
                            sourceTrimStartFraction: 0.5,
                            playbackRate: 3,
                          ),
                        ]
                      : const [],
                ),
            ],
            audioClips: const [
              AudioClip(
                id: 'c',
                label: 'c',
                materialId: 'a',
                startFrame: 4,
                lengthFrames: 10,
                sourceStartFrame: 6,
                sourceStartFraction: 0.25,
                playbackRate: 0.5,
              ),
            ],
          ),
        ],
        sourceFps: 10,
        pathOf: (_) async => file.path,
      );
      final clip = plan.sources.first;
      expect(clip.startSeconds, 0.4);
      expect(clip.sourceSeconds, closeTo(0.625, 1e-9));
      expect(clip.durationSeconds, 1.0);
      expect(clip.playbackRate, 0.5);
      final video = plan.sources.last;
      expect(video.startSeconds, 2.0);
      expect(video.sourceSeconds, closeTo(0.75, 1e-9));
      expect(video.playbackRate, 3);
      // The video uses source frames 7.5 to the end of 16 (its trim end is
      // its start + length − 1): 9.5 frames, 3.17 timeline frames at 3x.
      // After that the picture holds frame 16 and the video is silent.
      expect(video.durationSeconds, closeTo(9.5 / 3 / 10, 1e-9));

      // With the video's sound at normal speed, only the picture is faster.
      final soundAtNormalSpeed = await buildExportAudioPlan(
        scenes: [
          Scene(
            id: 'S',
            index: 0,
            frames: [
              for (var i = 0; i < 40; i++)
                Frame(
                  index: i,
                  layers: i == 0
                      ? const [
                          Layer(
                            id: 'v',
                            name: 'v',
                            type: LayerType.timelineVideo,
                            materialId: 'a',
                            rangeMode: LayerRangeMode.frameRange,
                            rangeStart: 21,
                            rangeEnd: 30,
                            sourceTrimStart: 7,
                            sourceTrimStartFraction: 0.5,
                            playbackRate: 3,
                            videoSoundFollowsSpeed: false,
                          ),
                        ]
                      : const [],
                ),
            ],
          ),
        ],
        sourceFps: 10,
        pathOf: (_) async => file.path,
      );
      final plainSound = soundAtNormalSpeed.sources.single;
      expect(plainSound.sourceSeconds, closeTo(0.75, 1e-9));
      // The same 9.5 source frames at 1x, within the 10-frame clip.
      expect(plainSound.durationSeconds, closeTo(0.95, 1e-9));
      expect(plainSound.playbackRate, 1);
      final plainArgs = exportAudioSourceArguments(plainSound, '/out.wav');
      expect(plainArgs[plainArgs.indexOf('-t') + 1], '0.950');
      expect(
        plainArgs[plainArgs.indexOf('-af') + 1],
        isNot(contains('atempo')),
      );

      final args = exportAudioSourceArguments(video, '/out.wav');
      // It reads only the used 9.5 source frames.
      expect(args[args.indexOf('-t') + 1], '0.950');
      expect(args[args.indexOf('-af') + 1], startsWith('atempo=3.0,volume='));
    });

    test('a video sounds only over its used range: silent where its last '
        'frame is held', () async {
      final dir = Directory.systemTemp.createTempSync('niarim-held-plan-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/v.mp4')..writeAsBytesSync([0]);
      Future<List<ExportAudioSource>> sound(Layer layer) async =>
          (await buildExportAudioPlan(
            scenes: [
              Scene(
                id: 'S',
                index: 0,
                frames: [
                  for (var i = 0; i < 30; i++)
                    Frame(index: i, layers: i == 0 ? [layer] : const []),
                ],
              ),
            ],
            sourceFps: 10,
            pathOf: (_) async => file.path,
          )).sources;
      // Source frames 0–5 over 10 timeline frames from frame 4: frames 10–13
      // hold frame 5.
      const held = Layer(
        id: 'v',
        name: 'v',
        type: LayerType.timelineVideo,
        materialId: 'v',
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: 5,
        rangeEnd: 14,
        sourceTrimStart: 0,
        sourceTrimEnd: 5,
      );
      var source = (await sound(held)).single;
      expect(source.startSeconds, closeTo(0.4, 1e-9));
      expect(source.durationSeconds, closeTo(0.6, 1e-9));
      expect(source.sourceSeconds, 0);

      // At 2x the six frames last three; at 2x with the sound at 1x the
      // sound still plays the six source frames.
      source = (await sound(held.copyWith(playbackRate: 2))).single;
      expect(source.durationSeconds, closeTo(0.3, 1e-9));
      source = (await sound(
        held.copyWith(playbackRate: 2, videoSoundFollowsSpeed: false),
      )).single;
      expect(source.durationSeconds, closeTo(0.6, 1e-9));

      // A fractional start plays to the end of the last used frame.
      source = (await sound(
        held.copyWith(sourceTrimStart: 1, sourceTrimStartFraction: 0.25),
      )).single;
      expect(source.sourceSeconds, closeTo(0.125, 1e-9));
      expect(source.durationSeconds, closeTo(0.475, 1e-9));

      // A clip that starts past its used range only holds its last frame.
      expect(
        await sound(held.copyWith(sourceTrimStart: 7, sourceTrimEnd: 5)),
        isEmpty,
      );

      // Without a held part, the whole clip sounds.
      source = (await sound(held.copyWith(sourceTrimEnd: 40))).single;
      expect(source.durationSeconds, closeTo(1.0, 1e-9));
    });

    test(
      'a speed-changed clip keeps its pitch and reads the right part',
      () async {
        final dir = Directory.systemTemp.createTempSync('niarim-speed-sound-');
        addTearDown(() => dir.deleteSync(recursive: true));
        // 0–1 s: 440 Hz, 1–2 s: 880 Hz.
        final source = '${dir.path}/two_tones.wav';
        final made = Process.runSync('ffmpeg', [
          '-hide_banner', '-loglevel', 'error', '-y', //
          '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
          '-f', 'lavfi', '-i', 'sine=frequency=880:duration=1',
          '-filter_complex', '[0][1]concat=n=2:v=0:a=1',
          '-ar', '48000', source,
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');

        Future<(double seconds, double hertz)> render(
          double sourceSeconds,
          double outputSeconds,
          double rate,
        ) async {
          final out = '${dir.path}/out_${rate}_$sourceSeconds.wav';
          final args = exportAudioSourceArguments(
            ExportAudioSource(
              path: source,
              startSeconds: 0,
              sourceSeconds: sourceSeconds,
              durationSeconds: outputSeconds,
              clipSeconds: outputSeconds,
              playbackRate: rate,
            ),
            out,
          );
          final run = await Process.run('ffmpeg', [
            '-hide_banner',
            '-loglevel',
            'error',
            ...args,
          ]);
          expect(run.exitCode, 0, reason: '${run.stderr}');
          final wav = File(out).readAsBytesSync();
          // 16-bit PCM after a 44-byte header; the left channel.
          final samples = Int16List.view(
            wav.buffer,
            wav.offsetInBytes + 44,
            (wav.length - 44) ~/ 2,
          );
          final left = [for (var i = 0; i < samples.length; i += 2) samples[i]];
          var crossings = 0;
          for (var i = 1; i < left.length; i++) {
            if ((left[i - 1] < 0) != (left[i] < 0)) crossings++;
          }
          final seconds = left.length / exportAudioSampleRate;
          return (seconds, crossings / 2 / seconds);
        }

        // 2x for 0.45 s reads source 0–0.9 s: 440 Hz, not 880 Hz.
        final fast = await render(0, 0.45, 2);
        expect(fast.$1, closeTo(0.45, 0.03));
        expect(fast.$2, closeTo(440, 15));
        // 0.5x for 1 s reads source 1.1–1.6 s: 880 Hz kept.
        final slow = await render(1.1, 1.0, 0.5);
        expect(slow.$1, closeTo(1.0, 0.03));
        expect(slow.$2, closeTo(880, 25));
      },
      skip: _ffmpegTests ? false : 'Needs NIARIM_VIDEO_FRAME_FFMPEG_TESTS=1',
    );
  });

  test('speeds and source fractions survive saving; old projects play at '
      '1x', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-speed-save-');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.utc(2026);
    final project = Project(
      id: 'p',
      name: 'p',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: now,
      updatedAt: now,
      totalWorkSeconds: 0,
    );
    final scene = Scene(
      id: 'S',
      index: 0,
      frames: const [
        Frame(
          index: 0,
          layers: [
            Layer(
              id: 'fast',
              name: 'fast',
              type: LayerType.timelineVideo,
              sourceTrimStart: 3,
              sourceTrimStartFraction: 0.375,
              playbackRate: 2.5,
            ),
            Layer(id: 'plain', name: 'plain', type: LayerType.timelineVideo),
            Layer(
              id: 'quiet',
              name: 'quiet',
              type: LayerType.timelineVideo,
              playbackRate: 4,
              videoSoundFollowsSpeed: false,
            ),
          ],
        ),
      ],
      audioClips: const [
        AudioClip(
          id: 'slow',
          label: 'slow',
          startFrame: 0,
          lengthFrames: 4,
          sourceStartFraction: 0.5,
          playbackRate: 0.25,
        ),
        AudioClip(id: 'normal', label: 'n', startFrame: 0, lengthFrames: 4),
      ],
    );
    final path = '${dir.path}/p.niapro';
    await NiaproSerializer.saveToPath(
      filePath: path,
      project: project,
      scenes: [scene],
      tileManager: TileManager(canvasWidth: 8, canvasHeight: 8),
    );
    final loaded = (await NiaproSerializer.load(path)).scenes.single;
    final layers = {for (final l in loaded.frames.single.layers) l.id: l};
    expect(layers['fast']!.playbackRate, 2.5);
    expect(layers['fast']!.sourceTrimStartFraction, 0.375);
    expect(layers['plain']!.playbackRate, 1.0);
    expect(layers['plain']!.sourceTrimStartFraction, 0.0);
    expect(layers['plain']!.videoSoundFollowsSpeed, isTrue);
    expect(layers['fast']!.videoSoundFollowsSpeed, isTrue);
    expect(layers['quiet']!.videoSoundFollowsSpeed, isFalse);
    expect(layers['quiet']!.playbackRate, 4);
    final clips = {for (final c in loaded.audioClips) c.id: c};
    expect(clips['slow']!.playbackRate, 0.25);
    expect(clips['slow']!.sourceStartFraction, 0.5);
    expect(clips['normal']!.playbackRate, 1.0);
  });
}
