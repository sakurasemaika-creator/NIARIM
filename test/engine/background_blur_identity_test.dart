import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/background_acclimation_engine.dart';

/// The background is softened, byte for byte, by the box blurs it is
/// defined as: [_referenceBlur] runs them a row and then a column at a
/// time, each channel on its own.
Uint8List _referenceBlur(
  Uint8List background,
  int width,
  int height,
  double radius,
) {
  final box = (radius / 2).round();
  if (box <= 0 || width <= 0 || height <= 0) return background;
  var work = Float64List(width * height * 4);
  for (var i = 0; i < work.length; i++) {
    work[i] = background[i].toDouble();
  }
  var next = Float64List(work.length);
  void pass(int length, int lines, int Function(int line, int at) index) {
    final size = box * 2 + 1;
    for (var line = 0; line < lines; line++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = -box; k <= box; k++) {
          sum += work[index(line, k.clamp(0, length - 1)) * 4 + c];
        }
        for (var at = 0; at < length; at++) {
          next[index(line, at) * 4 + c] = sum / size;
          final out = (at - box).clamp(0, length - 1);
          final into = (at + box + 1).clamp(0, length - 1);
          sum +=
              work[index(line, into) * 4 + c] - work[index(line, out) * 4 + c];
        }
      }
    }
    final swap = work;
    work = next;
    next = swap;
  }

  for (var round = 0; round < 2; round++) {
    pass(width, height, (y, x) => y * width + x);
    pass(height, width, (x, y) => y * width + x);
  }
  final out = Uint8List(background.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = work[i].round().clamp(0, 255);
  }
  return out;
}

Uint8List _background(int width, int height, int seed) {
  final random = math.Random(seed);
  final data = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final speck = random.nextInt(20) == 0;
      data[i] = speck ? random.nextInt(256) : x * 255 ~/ width;
      data[i + 1] = speck ? random.nextInt(256) : y * 255 ~/ height;
      data[i + 2] = (x * 7 + y * 3) % 256;
      data[i + 3] = random.nextInt(8) == 0 ? random.nextInt(256) : 255;
    }
  }
  return data;
}

void main() {
  test('every blur on backgrounds of every shape', () {
    for (final (width, height) in const [
      (1, 1),
      (1, 9),
      (9, 1),
      (7, 5),
      (40, 23),
      (96, 61),
    ]) {
      for (final radius in const [0.0, 1.0, 2.0, 3.0, 7.0, 16.0, 40.0]) {
        final data = _background(width, height, width + height);
        expect(
          BackgroundAcclimationEngine.blurredBackground(
            data,
            width,
            height,
            radius,
          ),
          _referenceBlur(data, width, height, radius),
          reason: '${width}x$height, radius $radius',
        );
      }
    }
  });
}
