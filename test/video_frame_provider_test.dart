import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_provider.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/engine/video_material_snapshot.dart';
import 'package:niarim/models/material_asset.dart';

/// Frames are solid colours whose red channel is the frame index, so a test
/// can read back which frame an image holds.
class _FakeDecoder implements VideoFrameDecoder {
  _FakeDecoder(this.timelines);

  final Map<String, VideoFrameTimeline> timelines;
  final probes = <String>[];
  final decodes = <(String, int, int, int)>[];
  final failingFrames = <int>{};
  bool failProbe = false;

  /// When set, each decode waits for its own completer (in call order).
  bool holdDecodes = false;
  final held = <Completer<void>>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<VideoFrameTimeline> probe(String path) async {
    probes.add(path);
    await Future<void>.delayed(Duration.zero);
    if (failProbe || !timelines.containsKey(path)) {
      throw VideoFrameDecodeException('unreadable $path');
    }
    return timelines[path]!;
  }

  @override
  Future<DecodedVideoFrame> decode({
    required String path,
    required VideoFrameTimeline timeline,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    decodes.add((path, frameIndex, width, height));
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (holdDecodes) {
        final gate = Completer<void>();
        held.add(gate);
        await gate.future;
      } else {
        await Future<void>.delayed(Duration.zero);
      }
      if (failingFrames.contains(frameIndex)) {
        throw VideoFrameDecodeException('bad frame $frameIndex');
      }
      final rgba = Uint8List(width * height * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = frameIndex;
        rgba[i + 1] = 7;
        rgba[i + 2] = 9;
        rgba[i + 3] = 255;
      }
      return DecodedVideoFrame(
        rgba: rgba,
        width: width,
        height: height,
        frameIndex: frameIndex,
      );
    } finally {
      active--;
    }
  }
}

VideoMaterialSnapshot _snapshot(Map<String, String?> paths) =>
    VideoMaterialSnapshot.fromAssets([
      for (final id in paths.keys)
        MaterialAsset(
          id: id,
          originalFileName: '$id.mp4',
          type: MaterialType.video,
          sizeBytes: 1,
          addedAt: DateTime(2026),
        ),
    ], paths);

final _tenFps = VideoFrameTimeline.fromPresentationMicros([
  for (var i = 0; i < 20; i++) i * 100000,
]);

Duration _ms(int ms) => Duration(milliseconds: ms);

Future<int> _redOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.getUint8(0);
}

Future<void> _pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeDecoder decoder;

  VideoFrameProvider provider({
    Map<String, String?> paths = const {'M1': '/m/1.mp4'},
    int cacheBudgetBytes = VideoFrameProvider.defaultCacheBudgetBytes,
    int maxConcurrentDecodes = 2,
  }) {
    final p = VideoFrameProvider(
      snapshot: _snapshot(paths),
      decoder: decoder,
      cacheBudgetBytes: cacheBudgetBytes,
      maxConcurrentDecodes: maxConcurrentDecodes,
    );
    addTearDown(p.dispose);
    return p;
  }

  setUp(() {
    decoder = _FakeDecoder({'/m/1.mp4': _tenFps, '/m/2.mp4': _tenFps});
  });

  group('frame selection and ownership', () {
    test('returns the selected frame as an image the caller owns', () async {
      final frames = provider();
      final result = await frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(250),
        width: 4,
        height: 3,
      );
      final ready = result as VideoFrameReady;
      expect(ready.frameIndex, 2);
      expect(ready.presentationTime, _ms(200));
      expect((ready.image.width, ready.image.height), (4, 3));
      expect(await _redOf(ready.image), 2);
      ready.image.dispose();
      expect(decoder.decodes, [('/m/1.mp4', 2, 4, 3)]);
    });

    test('times that select the same frame share one decode', () async {
      final frames = provider();
      for (final ms in [200, 230, 299]) {
        final ready =
            await frames.frameAt(
                  materialId: 'M1',
                  sourceTime: _ms(ms),
                  width: 4,
                  height: 4,
                )
                as VideoFrameReady;
        expect(await _redOf(ready.image), 2);
        ready.image.dispose();
      }
      expect(decoder.decodes, hasLength(1));
      expect(decoder.probes, hasLength(1));
    });

    test('different sizes are decoded and cached separately', () async {
      final frames = provider();
      for (final size in [4, 8, 4]) {
        final ready =
            await frames.frameAt(
                  materialId: 'M1',
                  sourceTime: Duration.zero,
                  width: size,
                  height: size,
                )
                as VideoFrameReady;
        ready.image.dispose();
      }
      expect(decoder.decodes.map((d) => d.$3), [4, 8]);
    });

    test(
      'concurrent requests for one frame share a decode but not an image',
      () async {
        final frames = provider();
        final results = await Future.wait([
          for (var i = 0; i < 3; i++)
            frames.frameAt(
              materialId: 'M1',
              sourceTime: _ms(100),
              width: 4,
              height: 4,
            ),
        ]);
        expect(decoder.decodes, hasLength(1));
        final images = [for (final r in results) (r as VideoFrameReady).image];
        images[0].dispose();
        images[1].dispose();
        expect(await _redOf(images[2]), 1);
        images[2].dispose();
      },
    );
  });

  group('missing and failing materials', () {
    test('an unknown material is reported without probing', () async {
      final result = await provider().frameAt(
        materialId: 'nope',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
      );
      expect(
        (result as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.unknownMaterial,
      );
      expect(result.reason.isFailure, isTrue);
      expect(decoder.probes, isEmpty);
    });

    test('a missing file is reported without probing or decoding', () async {
      final frames = provider(paths: {'M1': null});
      final result = await frames.frameAt(
        materialId: 'M1',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
      );
      expect(
        (result as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.missingFile,
      );
      expect(decoder.probes, isEmpty);
      expect(decoder.decodes, isEmpty);
      expect(
        await frames.timelineOf('M1'),
        isA<VideoTimelineUnavailable>().having(
          (t) => t.reason,
          'reason',
          VideoFrameUnavailableReason.missingFile,
        ),
      );
    });

    test('an unreadable file is probed once and reported', () async {
      decoder.failProbe = true;
      final frames = provider();
      for (var i = 0; i < 2; i++) {
        final result = await frames.frameAt(
          materialId: 'M1',
          sourceTime: Duration.zero,
          width: 4,
          height: 4,
        );
        expect(
          (result as VideoFrameUnavailable).reason,
          VideoFrameUnavailableReason.unreadable,
        );
        expect(result.error, isA<VideoFrameDecodeException>());
      }
      expect(decoder.probes, hasLength(1));
      expect(decoder.decodes, isEmpty);
    });

    test('a failed decode is reported and not cached', () async {
      decoder.failingFrames.add(3);
      final frames = provider();
      for (var i = 0; i < 2; i++) {
        final result = await frames.frameAt(
          materialId: 'M1',
          sourceTime: _ms(300),
          width: 4,
          height: 4,
        );
        expect(
          (result as VideoFrameUnavailable).reason,
          VideoFrameUnavailableReason.decodeFailed,
        );
        expect(result.error, isA<VideoFrameDecodeException>());
      }
      expect(decoder.decodes, hasLength(2));
      expect(frames.cachedFrameCount, 0);
      expect(frames.inFlightCount, 0);
    });

    test('a failure in one material does not affect another', () async {
      decoder.failingFrames.add(0);
      final frames = provider(paths: {'M1': '/m/1.mp4', 'M2': '/m/2.mp4'});
      final bad = await frames.frameAt(
        materialId: 'M1',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
      );
      final good = await frames.frameAt(
        materialId: 'M2',
        sourceTime: _ms(100),
        width: 4,
        height: 4,
      );
      expect(bad, isA<VideoFrameUnavailable>());
      expect(await _redOf((good as VideoFrameReady).image), 1);
      good.image.dispose();
    });
  });

  group('cache budget', () {
    const frameBytes = 4 * 4 * 4;

    test('evicts least recently used frames beyond the byte budget', () async {
      final frames = provider(cacheBudgetBytes: frameBytes * 2);
      final kept = <ui.Image>[];
      Future<void> request(int ms) async {
        final ready =
            await frames.frameAt(
                  materialId: 'M1',
                  sourceTime: _ms(ms),
                  width: 4,
                  height: 4,
                )
                as VideoFrameReady;
        kept.add(ready.image);
      }

      await request(0); // frame 0
      await request(100); // frame 1
      await request(0); // frame 0 becomes most recent
      await request(200); // frame 2 evicts frame 1
      expect(frames.cachedFrameCount, 2);
      expect(frames.cachedBytes, frameBytes * 2);
      expect(decoder.decodes.map((d) => d.$2), [0, 1, 2]);

      await request(0); // still cached
      await request(100); // evicted, decoded again
      expect(decoder.decodes.map((d) => d.$2), [0, 1, 2, 1]);

      // Images handed out before eviction stay valid.
      expect(
        [for (final image in kept) await _redOf(image)],
        [0, 1, 0, 2, 0, 1],
      );
      for (final image in kept) {
        image.dispose();
      }
    });

    test('a frame larger than the budget is returned but not cached', () async {
      final frames = provider(cacheBudgetBytes: frameBytes - 1);
      for (var i = 0; i < 2; i++) {
        final ready =
            await frames.frameAt(
                  materialId: 'M1',
                  sourceTime: Duration.zero,
                  width: 4,
                  height: 4,
                )
                as VideoFrameReady;
        expect(await _redOf(ready.image), 0);
        ready.image.dispose();
      }
      expect(frames.cachedFrameCount, 0);
      expect(decoder.decodes, hasLength(2));
    });

    test(
      'dispose releases the cache but not images already returned',
      () async {
        final frames = provider();
        final ready =
            await frames.frameAt(
                  materialId: 'M1',
                  sourceTime: Duration.zero,
                  width: 4,
                  height: 4,
                )
                as VideoFrameReady;
        expect(frames.cachedFrameCount, 1);
        frames.dispose();
        expect(frames.cachedFrameCount, 0);
        expect(frames.cachedBytes, 0);
        expect(await _redOf(ready.image), 0);
        ready.image.dispose();
        final after = await frames.frameAt(
          materialId: 'M1',
          sourceTime: Duration.zero,
          width: 4,
          height: 4,
        );
        expect(
          (after as VideoFrameUnavailable).reason,
          VideoFrameUnavailableReason.disposed,
        );
        expect(after.reason.isFailure, isFalse);
      },
    );
  });

  group('latest-wins seeking', () {
    test('an older request for the same key is superseded', () async {
      decoder.holdDecodes = true;
      final frames = provider();
      final first = frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(100),
        width: 4,
        height: 4,
        latestKey: 'layer-A',
      );
      await _pump();
      final second = frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(500),
        width: 4,
        height: 4,
        latestKey: 'layer-A',
      );
      await _pump();
      for (final gate in decoder.held) {
        gate.complete();
      }
      final results = await Future.wait([first, second]);
      expect(
        (results[0] as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.superseded,
      );
      expect(results[0] is VideoFrameReady, isFalse);
      final latest = results[1] as VideoFrameReady;
      expect(await _redOf(latest.image), 5);
      latest.image.dispose();
    });

    test('a superseded request that has not started never decodes', () async {
      decoder.holdDecodes = true;
      final frames = provider(maxConcurrentDecodes: 1);
      final blocker = frames.frameAt(
        materialId: 'M1',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
        latestKey: 'other-layer',
      );
      await _pump();
      // Each scrub position gets queued behind the blocker before the next
      // one replaces it.
      final stale = <Future<VideoFrameResult>>[];
      for (final ms in [100, 200, 300]) {
        stale.add(
          frames.frameAt(
            materialId: 'M1',
            sourceTime: _ms(ms),
            width: 4,
            height: 4,
            latestKey: 'scrubbed-layer',
          ),
        );
        await _pump();
        expect(frames.inFlightCount, 1 + stale.length);
      }
      final latest = frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(900),
        width: 4,
        height: 4,
        latestKey: 'scrubbed-layer',
      );
      await _pump();
      expect(decoder.decodes.map((d) => d.$2), [0]);
      while (decoder.held.any((g) => !g.isCompleted)) {
        for (final gate in decoder.held.where((g) => !g.isCompleted)) {
          gate.complete();
        }
        await _pump();
      }
      for (final result in await Future.wait(stale)) {
        expect(
          (result as VideoFrameUnavailable).reason,
          VideoFrameUnavailableReason.superseded,
        );
      }
      final ready = await latest as VideoFrameReady;
      expect(await _redOf(ready.image), 9);
      ready.image.dispose();
      ((await blocker) as VideoFrameReady).image.dispose();
      // Frames 1–3 were never decoded.
      expect(decoder.decodes.map((d) => d.$2), [0, 9]);
    });

    test('a shared decode still serves a request that wants it', () async {
      decoder.holdDecodes = true;
      final frames = provider();
      final scrubbed = frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(100),
        width: 4,
        height: 4,
        latestKey: 'layer-A',
      );
      final export = frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(100),
        width: 4,
        height: 4,
      );
      await _pump();
      final moved = frames.frameAt(
        materialId: 'M1',
        sourceTime: _ms(200),
        width: 4,
        height: 4,
        latestKey: 'layer-A',
      );
      await _pump();
      while (decoder.held.any((g) => !g.isCompleted)) {
        for (final gate in decoder.held.where((g) => !g.isCompleted)) {
          gate.complete();
        }
        await _pump();
      }
      expect(
        ((await scrubbed) as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.superseded,
      );
      final kept = await export as VideoFrameReady;
      final latest = await moved as VideoFrameReady;
      expect(await _redOf(kept.image), 1);
      expect(await _redOf(latest.image), 2);
      kept.image.dispose();
      latest.image.dispose();
    });
  });

  group('cancellation, disposal and concurrency', () {
    test('a cancelled request does not decode', () async {
      final frames = provider();
      final result = await frames.frameAt(
        materialId: 'M1',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
        isCancelled: () => true,
      );
      expect(
        (result as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.cancelled,
      );
      expect(decoder.decodes, isEmpty);
    });

    test('cancelling during a decode discards its image', () async {
      decoder.holdDecodes = true;
      var cancelled = false;
      final frames = provider();
      final pending = frames.frameAt(
        materialId: 'M1',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
        isCancelled: () => cancelled,
      );
      await _pump();
      expect(decoder.decodes, hasLength(1));
      cancelled = true;
      decoder.held.single.complete();
      final result = await pending;
      expect(
        (result as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.cancelled,
      );
    });

    test('disposing during a decode releases its result', () async {
      decoder.holdDecodes = true;
      final frames = provider();
      final pending = frames.frameAt(
        materialId: 'M1',
        sourceTime: Duration.zero,
        width: 4,
        height: 4,
      );
      await _pump();
      frames.dispose();
      decoder.held.single.complete();
      final result = await pending;
      expect(
        (result as VideoFrameUnavailable).reason,
        VideoFrameUnavailableReason.disposed,
      );
      await _pump();
      expect(frames.cachedFrameCount, 0);
      expect(frames.inFlightCount, 0);
    });

    test('runs at most maxConcurrentDecodes decodes at once', () async {
      decoder.holdDecodes = true;
      final frames = provider(maxConcurrentDecodes: 2);
      final requests = [
        for (var i = 0; i < 5; i++)
          frames.frameAt(
            materialId: 'M1',
            sourceTime: _ms(i * 100),
            width: 4,
            height: 4,
          ),
      ];
      await _pump();
      expect(decoder.active, 2);
      while (decoder.held.any((g) => !g.isCompleted) ||
          decoder.decodes.length < 5) {
        for (final gate in decoder.held.where((g) => !g.isCompleted)) {
          gate.complete();
        }
        await _pump();
      }
      final results = await Future.wait(requests);
      expect(decoder.maxActive, 2);
      for (final (index, result) in results.indexed) {
        final ready = result as VideoFrameReady;
        expect(await _redOf(ready.image), index);
        ready.image.dispose();
      }
    });

    test('rejects a non-positive frame size', () async {
      expect(
        () => provider().frameAt(
          materialId: 'M1',
          sourceTime: Duration.zero,
          width: 0,
          height: 4,
        ),
        throwsArgumentError,
      );
    });
  });
}
