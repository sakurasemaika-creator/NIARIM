import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// The lens blur gives, byte for byte, the disc average it is defined as:
/// [_referenceLensBlur] is the filter written plainly (each channel's sums
/// kept in a list, each row's running totals in a list of its own).
Uint8List _referenceLensBlur(
  Uint8List data,
  int width,
  int height,
  double strength,
) {
  final radius = strength.round().clamp(1, kMaxBlurRadius);
  final pixels = width * height;
  // Weight 1 for black up to 16 for white (the colour's own luma, before
  // its opacity, to the 4th power).
  final weight = Int32List(pixels);
  for (var p = 0; p < pixels; p++) {
    final i = p * 4;
    final alpha = data[i + 3];
    if (alpha == 0) {
      weight[p] = 1;
      continue;
    }
    final luma = (data[i] * 77 + data[i + 1] * 150 + data[i + 2] * 29) >> 8;
    final t = (luma / alpha).clamp(0.0, 1.0);
    weight[p] = 1 + (15 * t * t * t * t).round();
  }
  final rowLength = width + 1;
  final ring = 2 * radius + 1;
  // Running totals along each of the last [ring] rows: weight × each
  // premultiplied colour channel, weight × opacity, and opacity.
  final totals = List.generate(5, (_) => Int32List(ring * rowLength));
  void buildRow(int y) {
    final slot = (y % ring) * rowLength;
    var r = 0, g = 0, b = 0, wa = 0, a = 0;
    for (var x = 0; x < width; x++) {
      final p = y * width + x;
      final i = p * 4;
      final wt = weight[p];
      r += data[i] * wt;
      g += data[i + 1] * wt;
      b += data[i + 2] * wt;
      wa += data[i + 3] * wt;
      a += data[i + 3];
      totals[0][slot + x + 1] = r;
      totals[1][slot + x + 1] = g;
      totals[2][slot + x + 1] = b;
      totals[3][slot + x + 1] = wa;
      totals[4][slot + x + 1] = a;
    }
  }

  final halfWidths = [
    for (var dy = -radius; dy <= radius; dy++)
      math.sqrt(radius * radius - dy * dy).floor(),
  ];
  final result = Uint8List(data.length);
  var built = -1;
  final sums = List<int>.filled(5, 0);
  for (var y = 0; y < height; y++) {
    final last = math.min(height - 1, y + radius);
    while (built < last) {
      built++;
      buildRow(built);
    }
    for (var x = 0; x < width; x++) {
      sums.fillRange(0, 5, 0);
      var count = 0;
      for (var dy = -radius; dy <= radius; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        final half = halfWidths[dy + radius];
        final x0 = math.max(0, x - half);
        final x1 = math.min(width - 1, x + half);
        count += x1 - x0 + 1;
        final slot = (ny % ring) * rowLength;
        for (var c = 0; c < 5; c++) {
          final row = totals[c];
          sums[c] += row[slot + x1 + 1] - row[slot + x0];
        }
      }
      final weightedAlpha = sums[3];
      if (weightedAlpha == 0 || count == 0) continue;
      final o = (y * width + x) * 4;
      final a = (sums[4] / count).round().clamp(0, 255);
      result[o + 3] = a;
      // The brightness-weighted straight colour, at the disc's opacity.
      final scale = a / weightedAlpha;
      result[o] = math.min(a, (sums[0] * scale).round());
      result[o + 1] = math.min(a, (sums[1] * scale).round());
      result[o + 2] = math.min(a, (sums[2] * scale).round());
    }
  }
  return result;
}

Uint8List _picture(int width, int height, int seed, {required bool flat}) {
  final random = math.Random(seed);
  final data = Uint8List(width * height * 4);
  for (var i = 0; i < data.length; i += 4) {
    final a = flat
        ? (i ~/ 4 % width < width ~/ 2 ? 255 : 0)
        : (random.nextInt(4) == 0 ? random.nextInt(256) : 255);
    final speck = random.nextInt(30) == 0;
    final alpha = speck ? random.nextInt(256) : a;
    data[i + 3] = alpha;
    for (var c = 0; c < 3; c++) {
      data[i + c] = alpha == 0
          ? 0
          : (flat && !speck ? alpha * (c + 1) ~/ 4 : random.nextInt(alpha + 1));
    }
  }
  return data;
}

void main() {
  test('every radius on pictures of every shape', () {
    final engine = FilterEngine();
    for (final (width, height) in const [
      (1, 1),
      (1, 7),
      (7, 1),
      (6, 5),
      (31, 19),
      (80, 50),
    ]) {
      for (final radius in const [1, 2, 3, 5, 8, 13, 24, 40]) {
        for (final flat in const [false, true]) {
          final data = _picture(width, height, width * 50 + radius, flat: flat);
          expect(
            engine.applyLensBlur(data, width, height, radius.toDouble()),
            _referenceLensBlur(data, width, height, radius.toDouble()),
            reason: '${width}x$height, radius $radius, flat $flat',
          );
        }
      }
    }
  });
}
