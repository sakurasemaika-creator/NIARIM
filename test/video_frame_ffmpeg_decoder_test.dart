import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/timeline_video_time.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_provider.dart';
import 'package:niarim/engine/video_material_snapshot.dart';
import 'package:niarim/models/material_asset.dart';

/// Decodes real files with the system ffmpeg/ffprobe, running the same
/// argument lists FFmpegKit runs on the device. Required in the
/// timeline-preview-export-parity workflow, which installs FFmpeg and sets
/// NIARIM_VIDEO_FRAME_FFMPEG_TESTS=1.
final _enabled = Platform.environment['NIARIM_VIDEO_FRAME_FFMPEG_TESTS'] == '1';

Future<bool> _run(String tool, List<String> arguments) async {
  final result = await Process.run(tool, arguments);
  return result.exitCode == 0;
}

Future<void> _ffmpeg(List<String> arguments) async {
  final result = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    ...arguments,
  ]);
  if (result.exitCode != 0) {
    fail('ffmpeg ${arguments.join(' ')} failed: ${result.stderr}');
  }
}

/// Frame N of the generated test videos has luma 16 + 10N (limited range),
/// i.e. grey (16 + 10N - 16) * 255 / 219 after conversion to RGB.
int _frameNumberOfGrey(int red) => (red * 219 / 2550).round();

void main() {
  late Directory root;
  late Directory scratch;
  late FfmpegVideoFrameDecoder decoder;
  late String cfr; // 10 fps, 20 frames, H.264 with B-frames, 32x16
  late String cfr30; // 30 fps: timestamps that do not round to microseconds
  late String vfr; // variable intervals
  late String editList; // starts at original frame 4 via an edit list
  late String rotated; // 64x32 stored, displayed 32x64
  late String natural; // lossy 30 fps test pattern
  late String audioOnly;

  VideoFrameProvider providerFor(
    Map<String, String?> paths, {
    int cacheBudgetBytes = VideoFrameProvider.defaultCacheBudgetBytes,
    int maxConcurrentDecodes = 2,
    VideoFrameDecoder? using,
  }) {
    final provider = VideoFrameProvider(
      snapshot: VideoMaterialSnapshot.fromAssets([
        for (final id in paths.keys)
          MaterialAsset(
            id: id,
            originalFileName: '$id.mp4',
            type: MaterialType.video,
            sizeBytes: 1,
            addedAt: DateTime(2026),
          ),
      ], paths),
      decoder: using ?? decoder,
      cacheBudgetBytes: cacheBudgetBytes,
      maxConcurrentDecodes: maxConcurrentDecodes,
    );
    addTearDown(provider.dispose);
    return provider;
  }

  Future<Uint8List> rgbaOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  }

  Future<int> frameNumberAt(
    VideoFrameProvider provider,
    String materialId,
    Duration time, {
    int width = 32,
    int height = 16,
  }) async {
    final result = await provider.frameAt(
      materialId: materialId,
      sourceTime: time,
      width: width,
      height: height,
    );
    if (result is! VideoFrameReady) fail('no frame at $time: $result');
    final rgba = await rgbaOf(result.image);
    result.image.dispose();
    final centre = ((height ~/ 2) * width + width ~/ 2) * 4;
    return _frameNumberOfGrey(rgba[centre]);
  }

  setUpAll(() async {
    if (!_enabled) return;
    for (final tool in ['ffmpeg', 'ffprobe']) {
      final check = await Process.run(tool, ['-version']);
      if (check.exitCode != 0) fail('$tool is required on PATH');
    }
    root = await Directory.systemTemp.createTemp('niarim-video-frames-');
    scratch = Directory('${root.path}/scratch');
    decoder = FfmpegVideoFrameDecoder(
      workDirectory: scratch,
      runFfmpeg: (arguments) => _run('ffmpeg', arguments),
      runFfprobe: (arguments) => _run('ffprobe', arguments),
    );
    String numbered(int fps, double seconds) =>
        'nullsrc=s=32x16:r=$fps:d=$seconds,format=yuv444p,'
        "geq=lum='16+N*10':cb=128:cr=128";

    cfr = '${root.path}/cfr.mp4';
    await _ffmpeg([
      '-f', 'lavfi', '-i', numbered(10, 2), //
      '-c:v', 'libx264', '-qp', '0', '-g', '8', '-bf', '2',
      '-pix_fmt', 'yuv444p', cfr,
    ]);

    cfr30 = '${root.path}/cfr30.mp4';
    await _ffmpeg([
      '-f', 'lavfi', //
      '-i',
      'nullsrc=s=32x16:r=30:d=1,format=yuv444p,'
          "geq=lum='16+N*7':cb=128:cr=128",
      '-c:v', 'libx264', '-qp', '0', '-g', '12', '-bf', '2',
      '-pix_fmt', 'yuv444p', cfr30,
    ]);

    vfr = '${root.path}/vfr.mp4';
    await _ffmpeg([
      '-f', 'lavfi', '-i', numbered(100, 0.1), //
      '-vf', "setpts='if(lt(N,5),N*0.1,0.5+(N-5)*0.04)/TB'",
      '-fps_mode', 'vfr', '-c:v', 'libx264', '-qp', '0', '-bf', '0',
      '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000', vfr,
    ]);

    final gop = '${root.path}/gop.mp4';
    await _ffmpeg([
      '-f', 'lavfi', '-i', numbered(10, 2), //
      '-c:v', 'libx264', '-qp', '0', '-g', '10', '-keyint_min', '10',
      '-sc_threshold', '0', '-bf', '2', '-pix_fmt', 'yuv444p', gop,
    ]);
    editList = '${root.path}/edit_list.mp4';
    await _ffmpeg(['-ss', '0.35', '-i', gop, '-c', 'copy', editList]);

    final upright = '${root.path}/upright.mp4';
    await _ffmpeg([
      '-f', 'lavfi', '-i', 'color=c=white:s=64x32:r=10:d=0.5', //
      '-vf', 'drawbox=x=32:y=0:w=32:h=32:color=black:t=fill',
      '-c:v', 'libx264', '-qp', '0', '-pix_fmt', 'yuv444p', upright,
    ]);
    rotated = '${root.path}/rotated.mp4';
    await _ffmpeg([
      '-display_rotation',
      '90',
      '-i',
      upright,
      '-c',
      'copy',
      rotated,
    ]);

    natural = '${root.path}/natural.mp4';
    await _ffmpeg([
      '-f', 'lavfi', '-i', 'testsrc2=s=96x54:r=30:d=1.5', //
      '-c:v', 'libx264', '-crf', '28', '-bf', '3', '-pix_fmt', 'yuv420p',
      natural,
    ]);

    audioOnly = '${root.path}/audio.m4a';
    await _ffmpeg(['-f', 'lavfi', '-i', 'sine=d=0.5', audioOnly]);
  });

  tearDownAll(() async {
    if (_enabled) await root.delete(recursive: true);
  });

  group(
    'FFmpeg video frame decoding',
    () {
      test('probes every presentation time of a B-frame H.264 file', () async {
        final timeline = await decoder.probe(cfr);
        expect(timeline.frameCount, 20);
        for (var i = 0; i < 20; i++) {
          expect(
            timeline.presentationTimeOf(i),
            Duration(milliseconds: i * 100),
          );
        }
        expect((timeline.displayWidth, timeline.displayHeight), (32, 16));
      });

      test('decodes every frame by index', () async {
        final timeline = await decoder.probe(cfr);
        for (var i = 0; i < timeline.frameCount; i++) {
          final frame = await decoder.decode(
            path: cfr,
            timeline: timeline,
            frameIndex: i,
            width: 32,
            height: 16,
          );
          expect(frame.rgba.length, 32 * 16 * 4);
          expect(_frameNumberOfGrey(frame.rgba[(8 * 32 + 16) * 4]), i);
        }
      });

      test(
        'decodes every frame of a 30 fps file whose timestamps round',
        () async {
          // 1/15360 time base: frame k is at k/30 s (e.g. 66666.67 µs), which
          // no microsecond or six-decimal value represents exactly.
          final timeline = await decoder.probe(cfr30);
          expect(timeline.frameCount, 30);
          for (var i = 0; i < timeline.frameCount; i++) {
            final frame = await decoder.decode(
              path: cfr30,
              timeline: timeline,
              frameIndex: i,
              width: 32,
              height: 16,
            );
            final red = frame.rgba[(8 * 32 + 16) * 4];
            expect((red * 219 / (7 * 255)).round(), i, reason: 'frame $i');
          }
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );

      test(
        'returns the frame on screen between frames and after the end',
        () async {
          // A plain `ffmpeg -ss` returns the next frame between frames and
          // nothing during the last frame; the shared rule does neither.
          Future<String> rawSeek(String seconds) async {
            final result = await Process.run('ffmpeg', [
              '-hide_banner',
              '-loglevel',
              'error',
              '-ss',
              seconds,
              '-i',
              cfr, //
              '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'gray', '-',
            ], stdoutEncoding: null);
            final bytes = result.stdout as List<int>;
            return bytes.isEmpty
                ? 'none'
                : 'frame ${(bytes.first * 219 / 2550).round()}';
          }

          expect(await rawSeek('0.15'), 'frame 2');
          expect(await rawSeek('1.95'), 'none');

          final provider = providerFor({'cfr': cfr});
          const cases = {
            0: 0,
            50: 0,
            99: 0,
            100: 1,
            150: 1,
            199: 1,
            1900: 19,
            1950: 19,
            5000: 19,
          };
          for (final MapEntry(key: ms, value: expected) in cases.entries) {
            expect(
              await frameNumberAt(provider, 'cfr', Duration(milliseconds: ms)),
              expected,
              reason: '$ms ms',
            );
          }
        },
      );

      test('follows variable frame intervals', () async {
        final timeline = await decoder.probe(vfr);
        expect(
          [
            for (var i = 0; i < timeline.frameCount; i++)
              timeline.presentationTimeOf(i).inMilliseconds,
          ],
          [0, 100, 200, 300, 400, 500, 540, 570, 620, 660],
        );
        final provider = providerFor({'vfr': vfr});
        const cases = {530: 5, 550: 6, 600: 7, 630: 8, 700: 9};
        for (final MapEntry(key: ms, value: expected) in cases.entries) {
          expect(
            await frameNumberAt(provider, 'vfr', Duration(milliseconds: ms)),
            expected,
            reason: '$ms ms',
          );
        }
      });

      test('starts where an edit list starts', () async {
        final provider = providerFor({'cut': editList});
        expect(await frameNumberAt(provider, 'cut', Duration.zero), 4);
        expect(
          await frameNumberAt(
            provider,
            'cut',
            const Duration(milliseconds: 150),
          ),
          5,
        );
      });

      test('applies rotation and fits the frame centred with transparent '
          'padding', () async {
        final timeline = await decoder.probe(rotated);
        expect((timeline.displayWidth, timeline.displayHeight), (32, 64));
        final frame = await decoder.decode(
          path: rotated,
          timeline: timeline,
          frameIndex: 0,
          width: 40,
          height: 40,
        );
        int alpha(int x, int y) => frame.rgba[(y * 40 + x) * 4 + 3];
        int red(int x, int y) => frame.rgba[(y * 40 + x) * 4];
        // Displayed 32x64 fits 40x40 as 20x40 at x = 10..29.
        for (final y in [0, 20, 39]) {
          expect(
            [for (var x = 0; x < 40; x++) alpha(x, y) == 255],
            [for (var x = 0; x < 40; x++) x >= 10 && x < 30],
            reason: 'row $y',
          );
          expect(red(0, y), 0, reason: 'padding is transparent black');
        }
        // The stored left/right halves now lie top/bottom.
        expect((red(20, 4) - red(20, 35)).abs(), greaterThan(200));
      });

      test('reports files without video frames and missing files', () async {
        await expectLater(
          decoder.probe(audioOnly),
          throwsA(isA<VideoFrameDecodeException>()),
        );
        await expectLater(
          decoder.probe('${root.path}/missing.mp4'),
          throwsA(isA<VideoFrameDecodeException>()),
        );
        final provider = providerFor({'audio': audioOnly});
        final result = await provider.frameAt(
          materialId: 'audio',
          sourceTime: Duration.zero,
          width: 8,
          height: 8,
        );
        expect(
          (result as VideoFrameUnavailable).reason,
          VideoFrameUnavailableReason.unreadable,
        );
        final timeline = await decoder.probe(cfr);
        await expectLater(
          decoder.decode(
            path: cfr,
            timeline: timeline,
            frameIndex: 20,
            width: 8,
            height: 8,
          ),
          throwsRangeError,
        );
      });

      test('preview and export providers produce identical RGBA', () async {
        // Preview: latest-wins per layer, one-frame cache, one decode at a
        // time. Export: no latest key, default cache. A second decoder with
        // its own scratch directory stands in for a separate job.
        final preview = providerFor(
          {'clip': natural},
          cacheBudgetBytes: 96 * 54 * 4,
          maxConcurrentDecodes: 1,
        );
        final export = providerFor({'clip': natural});
        final independent = providerFor(
          {'clip': natural},
          using: FfmpegVideoFrameDecoder(
            workDirectory: Directory('${root.path}/scratch2'),
            runFfmpeg: (arguments) => _run('ffmpeg', arguments),
            runFfprobe: (arguments) => _run('ffprobe', arguments),
          ),
        );
        final rawTimeline = await decoder.probe(natural);

        // A 24 fps project clip starting at timeline frame 5, trimmed to
        // start 6 project frames into the source, at 1.5x.
        for (var timelineFrame = 5; timelineFrame < 25; timelineFrame++) {
          final time = TimelineVideoTimeMapper.sourceTimeAt(
            timelineFrame: timelineFrame,
            clipStartFrame: 5,
            clipLengthFrames: 20,
            sourceTrimStartFrame: 6,
            sourceTrimEndFrame: 35,
            framesPerSecond: 24,
            playbackRate: 1.5,
          )!;
          final fromPreview =
              await preview.frameAt(
                    materialId: 'clip',
                    sourceTime: time,
                    width: 96,
                    height: 54,
                    latestKey: 'layer-1',
                  )
                  as VideoFrameReady;
          final fromExport =
              await export.frameAt(
                    materialId: 'clip',
                    sourceTime: time,
                    width: 96,
                    height: 54,
                  )
                  as VideoFrameReady;
          final fromIndependent =
              await independent.frameAt(
                    materialId: 'clip',
                    sourceTime: time,
                    width: 96,
                    height: 54,
                  )
                  as VideoFrameReady;
          final expectedIndex = rawTimeline.frameIndexAt(time)!;
          expect(fromPreview.frameIndex, expectedIndex);
          expect(fromExport.frameIndex, expectedIndex);

          final previewRgba = await rgbaOf(fromPreview.image);
          expect(
            previewRgba,
            await rgbaOf(fromExport.image),
            reason: 'timeline frame $timelineFrame',
          );
          expect(
            previewRgba,
            await rgbaOf(fromIndependent.image),
            reason: 'timeline frame $timelineFrame (separate job)',
          );
          // The image holds exactly the decoder's pixels.
          final raw = await decoder.decode(
            path: natural,
            timeline: rawTimeline,
            frameIndex: expectedIndex,
            width: 96,
            height: 54,
          );
          expect(previewRgba, raw.rgba);
          fromPreview.image.dispose();
          fromExport.image.dispose();
          fromIndependent.image.dispose();
        }
      }, timeout: const Timeout(Duration(minutes: 3)));

      test(
        'a run of frames in one pass is byte-identical to single decodes',
        () async {
          final files = {
            'cfr': cfr,
            'cfr30': cfr30,
            'vfr': vfr,
            'editList': editList,
            'rotated': rotated,
            'natural': natural,
          };
          for (final MapEntry(key: name, value: path) in files.entries) {
            final timeline = await decoder.probe(path);
            final n = timeline.frameCount;
            for (final stride in [1, 2, 3]) {
              for (final first in {0, n ~/ 2, n - 2}) {
                if (first < 0) continue;
                // Asks for more than the file has from there: the run ends
                // with the file.
                final run = await decoder.decodeRun(
                  path: path,
                  timeline: timeline,
                  firstFrameIndex: first,
                  count: 6,
                  stride: stride,
                  width: 40,
                  height: 20,
                );
                final expected = [
                  for (
                    var i = first;
                    i < n && i < first + 6 * stride;
                    i += stride
                  )
                    i,
                ];
                expect(
                  [for (final f in run) f.frameIndex],
                  expected,
                  reason: '$name from $first every $stride',
                );
                for (final frame in run) {
                  final single = await decoder.decode(
                    path: path,
                    timeline: timeline,
                    frameIndex: frame.frameIndex,
                    width: 40,
                    height: 20,
                  );
                  expect(
                    frame.rgba,
                    single.rgba,
                    reason:
                        '$name frame ${frame.frameIndex} '
                        '(from $first every $stride)',
                  );
                }
              }
            }
          }
          expect(scratch.listSync(), isEmpty);
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );

      test('an export provider reading ahead decodes far fewer times and '
          'gives the same pixels, walking forward at 1x and at 3x', () async {
        final timeline = await decoder.probe(natural);
        for (final step in [1, 3]) {
          final ahead = VideoFrameProvider(
            snapshot: VideoMaterialSnapshot.fromAssets(
              [
                MaterialAsset(
                  id: 'clip',
                  originalFileName: 'clip.mp4',
                  type: MaterialType.video,
                  sizeBytes: 1,
                  addedAt: DateTime(2026),
                ),
              ],
              {'clip': natural},
            ),
            decoder: decoder,
            readAhead: 8,
            cacheBudgetBytes: 96 * 54 * 4 * 11,
          );
          addTearDown(ahead.dispose);
          final alone = providerFor({'clip': natural});
          var requests = 0;
          for (var i = 0; i < timeline.frameCount; i += step) {
            requests++;
            final time = timeline.presentationTimeOf(i);
            final read =
                await ahead.frameAt(
                      materialId: 'clip',
                      sourceTime: time,
                      width: 96,
                      height: 54,
                    )
                    as VideoFrameReady;
            final single =
                await alone.frameAt(
                      materialId: 'clip',
                      sourceTime: time,
                      width: 96,
                      height: 54,
                    )
                    as VideoFrameReady;
            expect(read.frameIndex, i);
            expect(
              await rgbaOf(read.image),
              await rgbaOf(single.image),
              reason: 'frame $i (every $step)',
            );
            read.image.dispose();
            single.image.dispose();
          }
          expect(alone.decodeCount, requests);
          // One pass per 8 frames, and the first one or two on their own
          // while the step is learnt.
          expect(
            ahead.decodeCount,
            lessThanOrEqualTo((requests / 8).ceil() + 2),
            reason: 'every $step',
          );
        }
      }, timeout: const Timeout(Duration(minutes: 3)));

      test('removes every scratch file it wrote', () async {
        final timeline = await decoder.probe(natural);
        await decoder.decode(
          path: natural,
          timeline: timeline,
          frameIndex: 3,
          width: 16,
          height: 9,
        );
        await expectLater(
          decoder.decode(
            path: '${root.path}/missing.mp4',
            timeline: timeline,
            frameIndex: 0,
            width: 16,
            height: 9,
          ),
          throwsA(isA<VideoFrameDecodeException>()),
        );
        expect(scratch.listSync(), isEmpty);
      });
    },
    skip: _enabled
        ? false
        : 'Set NIARIM_VIDEO_FRAME_FFMPEG_TESTS=1 with ffmpeg and ffprobe on '
              'PATH (required in timeline-preview-export-parity CI).',
  );
}
