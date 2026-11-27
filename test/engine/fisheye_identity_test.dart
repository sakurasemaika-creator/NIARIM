import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// The fisheye gives, byte for byte, the mapping it is defined as:
/// [_referenceFisheye] works out every pixel's source on its own.
Uint8List _referenceFisheye(
  Uint8List data,
  int width,
  int height,
  double strength, {
  double radiusPercent = 100,
  double centerOffsetX = 0,
  double centerOffsetY = 0,
}) {
  final amount = (strength / 100.0).clamp(-1.0, 1.0);
  if (amount == 0) return Uint8List.fromList(data);
  final exponent = amount > 0 ? 1.0 + amount * 1.5 : 1.0 + amount * 0.85;
  final cx = width / 2.0 + centerOffsetX;
  final cy = height / 2.0 + centerOffsetY;
  final maxCanvasR = math.sqrt(width * width + height * height) / 2.0;
  final maxR = math.max(
    1.0,
    maxCanvasR * (radiusPercent / 100.0).clamp(0.01, 1.0),
  );
  final result = Uint8List(data.length);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final nx = (x - cx) / maxR;
      final ny = (y - cy) / maxR;
      final r = math.sqrt(nx * nx + ny * ny);
      double srcX, srcY;
      if (r > 1.0) {
        final q = (y * width + x) * 4;
        result[q] = data[q];
        result[q + 1] = data[q + 1];
        result[q + 2] = data[q + 2];
        result[q + 3] = data[q + 3];
        continue;
      } else if (r <= 1e-6) {
        srcX = cx;
        srcY = cy;
      } else {
        final newR = math.pow(r, exponent).toDouble();
        final theta = math.atan2(ny, nx);
        srcX = cx + math.cos(theta) * newR * maxR;
        srcY = cy + math.sin(theta) * newR * maxR;
      }
      final sx = srcX.round().clamp(0, width - 1);
      final sy = srcY.round().clamp(0, height - 1);
      final srcIdx = (sy * width + sx) * 4;
      final dstIdx = (y * width + x) * 4;
      result[dstIdx] = data[srcIdx];
      result[dstIdx + 1] = data[srcIdx + 1];
      result[dstIdx + 2] = data[srcIdx + 2];
      result[dstIdx + 3] = data[srcIdx + 3];
    }
  }
  return result;
}

Uint8List _picture(int width, int height, int seed) {
  final random = math.Random(seed);
  return Uint8List.fromList([
    for (var i = 0; i < width * height * 4; i++) random.nextInt(256),
  ]);
}

void main() {
  test('every strength, reach and centre on pictures of every shape', () {
    final engine = FilterEngine();
    var cases = 0;
    for (final (width, height) in const [
      (1, 1),
      (2, 1),
      (1, 5),
      (7, 4),
      (8, 8),
      (33, 20),
      (64, 41),
    ]) {
      final data = _picture(width, height, width * 10 + height);
      for (final strength in const [-100.0, -40.0, 0.0, 35.0, 100.0]) {
        for (final reach in const [100.0, 60.0, 5.0]) {
          for (final (ox, oy) in const [
            (0.0, 0.0),
            (0.5, -0.5),
            (3.0, 1.0),
            (1.3, -2.7),
          ]) {
            expect(
              engine.applyFisheye(
                data,
                width,
                height,
                strength,
                radiusPercent: reach,
                centerOffsetX: ox,
                centerOffsetY: oy,
              ),
              _referenceFisheye(
                data,
                width,
                height,
                strength,
                radiusPercent: reach,
                centerOffsetX: ox,
                centerOffsetY: oy,
              ),
              reason: '${width}x$height, $strength, $reach%, ($ox, $oy)',
            );
            cases++;
          }
        }
      }
    }
    expect(cases, 420);
  });

  test('a picture that starts anywhere in its buffer', () {
    final engine = FilterEngine();
    final data = _picture(37, 23, 5);
    for (final offset in const [1, 2, 3, 4]) {
      final buffer = Uint8List(data.length + offset + 3)
        ..setRange(offset, offset + data.length, data);
      final view = Uint8List.sublistView(buffer, offset, offset + data.length);
      expect(
        engine.applyFisheye(view, 37, 23, 64, centerOffsetX: 0.5),
        _referenceFisheye(data, 37, 23, 64, centerOffsetX: 0.5),
        reason: 'offset $offset',
      );
    }
  });

  // The quick way to a pixel's source rounds like the angle's cosine and
  // sine everywhere it is used (with no margin at all), and the margin only
  // hands more pixels to the angle (with a margin of most of a pixel).
  test('the quick way and the angle give the same sources', () {
    final engine = FilterEngine();
    addTearDown(() => FilterEngine.debugFisheyeMargin = 1e-9);
    for (final margin in const [0.0, 1e-4, 0.3]) {
      FilterEngine.debugFisheyeMargin = margin;
      for (final (width, height) in const [(120, 80), (97, 131), (256, 9)]) {
        final data = _picture(width, height, width + height * 7);
        for (final strength in const [-100.0, -63.0, 18.0, 77.0, 100.0]) {
          for (final (ox, oy) in const [
            (0.0, 0.0),
            (0.5, 0.5),
            (-0.5, 2.0),
            (11.25, -7.75),
            (0.3, 0.1),
          ]) {
            for (final reach in const [100.0, 45.0]) {
              expect(
                engine.applyFisheye(
                  data,
                  width,
                  height,
                  strength,
                  radiusPercent: reach,
                  centerOffsetX: ox,
                  centerOffsetY: oy,
                ),
                _referenceFisheye(
                  data,
                  width,
                  height,
                  strength,
                  radiusPercent: reach,
                  centerOffsetX: ox,
                  centerOffsetY: oy,
                ),
                reason:
                    'margin $margin, ${width}x$height, $strength, $reach%, '
                    '($ox, $oy)',
              );
            }
          }
        }
      }
    }
  });
}
