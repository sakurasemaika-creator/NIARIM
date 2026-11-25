import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/timeline_video_time.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_timeline.dart';

Duration _ms(num ms) => Duration(microseconds: (ms * 1000).round());

VideoFrameTimeline _timelineMs(List<num> ms) =>
    VideoFrameTimeline.fromPresentationMicros(
      ms.map((m) => (m * 1000).round()),
    );

String _probeJson({
  required List<Map<String, Object?>> packets,
  String timeBase = '1/1000',
  String startTime = '0.000000',
  Map<String, Object?> stream = const {},
}) => jsonEncode({
  'packets': packets,
  'streams': [
    {'width': 64, 'height': 32, 'time_base': timeBase, ...stream},
  ],
  'format': {'start_time': startTime},
});

void main() {
  group('VideoFrameTimeline.frameIndexAt', () {
    final tenFps = _timelineMs([for (var i = 0; i < 20; i++) i * 100]);

    test('selects the frame on screen, not the next one', () {
      expect(tenFps.frameIndexAt(Duration.zero), 0);
      expect(tenFps.frameIndexAt(_ms(50)), 0);
      expect(tenFps.frameIndexAt(_ms(99)), 0);
      expect(tenFps.frameIndexAt(_ms(100)), 1);
      expect(tenFps.frameIndexAt(_ms(150)), 1);
      expect(tenFps.frameIndexAt(_ms(199.4)), 1);
    });

    test('holds the last frame through and past its display interval', () {
      expect(tenFps.frameIndexAt(_ms(1900)), 19);
      expect(tenFps.frameIndexAt(_ms(1950)), 19);
      expect(tenFps.frameIndexAt(_ms(60000)), 19);
    });

    test('shows the first frame before the video starts', () {
      final lateStart = _timelineMs([40, 80, 120]);
      expect(lateStart.frameIndexAt(Duration.zero), 0);
      expect(lateStart.frameIndexAt(_ms(39)), 0);
      expect(lateStart.frameIndexAt(_ms(80)), 1);
    });

    test('absorbs millisecond time-base rounding within 0.5 ms only', () {
      // A 30 fps video stored with a 1/1000 time base: 0, 33, 67, 100 ms.
      final rounded = _timelineMs([0, 33, 67, 100]);
      // 2/30 s = 66.667 ms is the start of frame 2 although it reads 67 ms.
      expect(rounded.frameIndexAt(const Duration(microseconds: 66667)), 2);
      // 0.6 ms before the stored time is still the previous frame.
      expect(rounded.frameIndexAt(const Duration(microseconds: 66400)), 1);
      expect(VideoFrameTimeline.selectionTolerance, _ms(0.5));
    });

    test('follows variable frame intervals', () {
      final vfr = _timelineMs([0, 100, 200, 300, 400, 500, 540, 570, 620, 660]);
      expect(vfr.frameIndexAt(_ms(530)), 5);
      expect(vfr.frameIndexAt(_ms(550)), 6);
      expect(vfr.frameIndexAt(_ms(600)), 7);
      expect(vfr.frameIndexAt(_ms(661)), 9);
      expect(vfr.frameIndexAt(_ms(5000)), 9);
    });

    test('has no frame for an empty table', () {
      final empty = VideoFrameTimeline.fromPresentationMicros(const []);
      expect(empty.isEmpty, isTrue);
      expect(empty.frameIndexAt(Duration.zero), isNull);
    });

    test('drops negative and duplicate timestamps and sorts the rest', () {
      final timeline = VideoFrameTimeline.fromPresentationMicros([
        200000,
        -40000,
        0,
        100000,
        100000,
      ]);
      expect(timeline.frameCount, 3);
      expect(timeline.presentationTimeOf(0), Duration.zero);
      expect(timeline.presentationTimeOf(1), _ms(100));
      expect(timeline.presentationTimeOf(2), _ms(200));
    });
  });

  group('VideoFrameTimeline.seekTimeFor', () {
    test('seeks between the previous frame and the requested one', () {
      final timeline = _timelineMs([0, 100, 200, 300]);
      expect(timeline.seekTimeFor(0), Duration.zero);
      expect(timeline.seekTimeFor(1), _ms(50));
      expect(timeline.seekTimeFor(3), _ms(250));
    });

    test('seeks to the container start for a late first frame', () {
      expect(_timelineMs([40, 80]).seekTimeFor(0), Duration.zero);
      expect(_timelineMs([40, 80]).seekTimeFor(1), _ms(60));
    });

    test('rejects an index outside the table', () {
      final timeline = _timelineMs([0, 100]);
      expect(() => timeline.seekTimeFor(2), throwsRangeError);
      expect(() => timeline.seekTimeFor(-1), throwsRangeError);
    });
  });

  group('VideoFrameTimeline.parseFfprobeJson', () {
    test('converts packet timestamps with the stream time base', () {
      final timeline = VideoFrameTimeline.parseFfprobeJson(
        _probeJson(
          timeBase: '1/90000',
          packets: [
            {'pts': 0, 'flags': 'K__'},
            {'pts': 6006, 'flags': '___'},
            {'pts': 3003, 'flags': '___'},
          ],
        ),
      )!;
      expect(timeline.frameCount, 3);
      expect(timeline.presentationTimeOf(1).inMicroseconds, 33367);
      expect(timeline.presentationTimeOf(2).inMicroseconds, 66733);
    });

    test('skips packets an edit list discards and packets without pts', () {
      final timeline = VideoFrameTimeline.parseFfprobeJson(
        _probeJson(
          timeBase: '1/10240',
          packets: [
            {'pts': -2048, 'flags': 'KD_'},
            {'pts': -1024, 'flags': '_D_'},
            {'flags': '___'},
            {'pts': 0, 'flags': '___'},
            {'pts': 1024, 'flags': '___'},
          ],
        ),
      )!;
      expect(timeline.frameCount, 2);
      expect(timeline.presentationTimeOf(0), Duration.zero);
      expect(timeline.presentationTimeOf(1), _ms(100));
    });

    test('measures timestamps from the container start', () {
      final timeline = VideoFrameTimeline.parseFfprobeJson(
        _probeJson(
          startTime: '1.400000',
          packets: [
            {'pts': 1400, 'flags': 'K__'},
            {'pts': 1500, 'flags': '___'},
          ],
        ),
      )!;
      expect(timeline.presentationTimeOf(0), Duration.zero);
      expect(timeline.presentationTimeOf(1), _ms(100));
    });

    test('reports the display size after rotation metadata', () {
      final sideData = VideoFrameTimeline.parseFfprobeJson(
        _probeJson(
          packets: [
            {'pts': 0, 'flags': 'K__'},
          ],
          stream: {
            'side_data_list': [
              {'rotation': -90},
            ],
          },
        ),
      )!;
      expect((sideData.displayWidth, sideData.displayHeight), (32, 64));

      final legacyTag = VideoFrameTimeline.parseFfprobeJson(
        _probeJson(
          packets: [
            {'pts': 0, 'flags': 'K__'},
          ],
          stream: {
            'tags': {'rotate': '180'},
          },
        ),
      )!;
      expect((legacyTag.displayWidth, legacyTag.displayHeight), (64, 32));
    });

    test('returns null without a usable video stream', () {
      expect(
        VideoFrameTimeline.parseFfprobeJson(
          jsonEncode({'packets': [], 'streams': [], 'format': {}}),
        ),
        isNull,
      );
      expect(
        VideoFrameTimeline.parseFfprobeJson(
          _probeJson(timeBase: '0/0', packets: const []),
        ),
        isNull,
      );
      expect(VideoFrameTimeline.parseFfprobeJson('not json'), isNull);
    });
  });

  group('shared timeline-to-frame selection', () {
    // A 30 fps source with FFmpeg's usual 1/15360 time base: 512 per frame.
    final thirtyFps = VideoFrameTimeline.parseFfprobeJson(
      _probeJson(
        timeBase: '1/15360',
        packets: [
          for (var i = 0; i < 90; i++) {'pts': i * 512, 'flags': '___'},
        ],
      ),
    )!;

    int? selected(int timelineFrame, double projectFps, {double rate = 1}) {
      final time = TimelineVideoTimeMapper.sourceTimeAt(
        timelineFrame: timelineFrame,
        clipStartFrame: 0,
        clipLengthFrames: 1000,
        sourceTrimStartFrame: 0,
        sourceTrimEndFrame: 1000,
        framesPerSecond: projectFps,
        playbackRate: rate,
      );
      return time == null ? null : thirtyFps.frameIndexAt(time);
    }

    test('maps every project frame 1:1 when project and source FPS match', () {
      for (var frame = 0; frame < 90; frame++) {
        expect(selected(frame, 30), frame, reason: 'timeline frame $frame');
      }
    });

    test('maps a 24 fps project onto a 30 fps source by elapsed time', () {
      for (var frame = 0; frame < 72; frame++) {
        // Frame f of a 24 fps project starts at f/24 s, showing the 30 fps
        // frame that started last: floor(f * 30 / 24).
        expect(selected(frame, 24), frame * 30 ~/ 24, reason: 'frame $frame');
      }
    });

    test('applies the playback rate before selecting the frame', () {
      for (var frame = 0; frame < 40; frame++) {
        expect(selected(frame, 30, rate: 2), frame * 2, reason: 'frame $frame');
      }
    });

    test('sourceTimeAt keeps microsecond precision', () {
      expect(
        TimelineVideoTimeMapper.sourceTimeAt(
          timelineFrame: 1,
          clipStartFrame: 0,
          clipLengthFrames: 10,
          sourceTrimStartFrame: 0,
          sourceTrimEndFrame: 9,
          framesPerSecond: 30,
        ),
        const Duration(microseconds: 33333),
      );
      expect(
        TimelineVideoTimeMapper.sourceTimeAt(
          timelineFrame: 10,
          clipStartFrame: 0,
          clipLengthFrames: 10,
          sourceTrimStartFrame: 0,
          sourceTrimEndFrame: 9,
          framesPerSecond: 30,
        ),
        isNull,
      );
      expect(
        TimelineVideoTimeMapper.sourceTimeAt(
          timelineFrame: 0,
          clipStartFrame: 0,
          clipLengthFrames: 10,
          sourceTrimStartFrame: 0,
          sourceTrimEndFrame: 9,
          framesPerSecond: 0,
        ),
        isNull,
      );
    });
  });

  group('decode arguments', () {
    test('formats seek seconds from integers', () {
      expect(formatSeekSeconds(Duration.zero), '0.000000');
      expect(formatSeekSeconds(const Duration(microseconds: 50)), '0.000050');
      expect(
        formatSeekSeconds(const Duration(seconds: 12, microseconds: 345678)),
        '12.345678',
      );
      expect(
        () => formatSeekSeconds(const Duration(microseconds: -1)),
        throwsArgumentError,
      );
    });

    test('decode command seeks, fits, pads and writes raw RGBA', () {
      final args = videoFrameDecodeArguments(
        path: '/m/a.mp4',
        seekTime: _ms(50),
        width: 40,
        height: 30,
        outputPath: '/t/out.rgba',
      );
      expect(args.sublist(args.indexOf('-ss'), args.indexOf('-ss') + 4), [
        '-ss',
        '0.050000',
        '-i',
        '/m/a.mp4',
      ]);
      final filter = args[args.indexOf('-vf') + 1];
      expect(filter, contains('force_original_aspect_ratio=decrease'));
      expect(filter, contains('flags=$videoFrameScaleFlags'));
      expect(filter, contains('pad=40:30:(ow-iw)/2:(oh-ih)/2:color=black@0'));
      expect(args, containsAllInOrder(['-map', '0:v:0', '-frames:v', '1']));
      expect(args.sublist(args.length - 6), [
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-y',
        '/t/out.rgba',
      ]);
    });

    test('probe command writes the first video stream packet table', () {
      final args = videoFrameProbeArguments('/m/a.mp4', '/t/p.json');
      expect(args, containsAllInOrder(['-select_streams', 'v:0']));
      final entries = args[args.indexOf('-show_entries') + 1];
      expect(entries, startsWith('packet=pts,flags'));
      expect(entries, contains('stream_side_data=rotation'));
      expect(args, containsAllInOrder(['-o', '/t/p.json', '-i', '/m/a.mp4']));
    });
  });
}
