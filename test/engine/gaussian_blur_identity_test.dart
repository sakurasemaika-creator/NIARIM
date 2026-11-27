import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// The Gaussian blur gives, byte for byte, the straightforward convolution
/// it stands for: the normalised kernel of the radius, each output channel
/// the sum of the kernel's taps in order (rows first, then columns, edges
/// extending the outermost pixel), rounded.
List<double> _kernel(int radius) {
  final sigma = radius / 3.0;
  final kernel = List<double>.generate(radius * 2 + 1, (i) {
    final x = i - radius;
    return math.exp(-(x * x) / (2 * sigma * sigma));
  });
  final sum = kernel.fold(0.0, (a, b) => a + b);
  return kernel.map((v) => v / sum).toList();
}

Uint8List _pass(
  Uint8List data,
  int width,
  int height,
  List<double> kernel, {
  required bool rows,
}) {
  final radius = kernel.length ~/ 2;
  final result = Uint8List(data.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      double r = 0, g = 0, b = 0, a = 0;
      for (var k = 0; k < kernel.length; k++) {
        final idx = rows
            ? (y * width + (x + k - radius).clamp(0, width - 1)) * 4
            : ((y + k - radius).clamp(0, height - 1) * width + x) * 4;
        r += data[idx] * kernel[k];
        g += data[idx + 1] * kernel[k];
        b += data[idx + 2] * kernel[k];
        a += data[idx + 3] * kernel[k];
      }
      final idx = (y * width + x) * 4;
      result[idx] = r.round().clamp(0, 255);
      result[idx + 1] = g.round().clamp(0, 255);
      result[idx + 2] = b.round().clamp(0, 255);
      result[idx + 3] = a.round().clamp(0, 255);
    }
  }
  return result;
}

Uint8List _reference(Uint8List data, int width, int height, int radius) {
  final kernel = _kernel(radius);
  return _pass(
    _pass(data, width, height, kernel, rows: true),
    width,
    height,
    kernel,
    rows: false,
  );
}

/// A Gaussian of [sigma] approximated by three box blurs.
Uint8List _referenceBoxGaussian(
  Uint8List data,
  int width,
  int height,
  double sigma,
) {
  // Box widths whose three passes match the Gaussian's variance.
  const n = 3;
  final ideal = math.sqrt(12 * sigma * sigma / n + 1);
  var lower = ideal.floor();
  if (lower.isEven) lower--;
  final upper = lower + 2;
  final m =
      ((12 * sigma * sigma - n * lower * lower - 4 * n * lower - 3 * n) /
              (-4 * lower - 4))
          .round();
  var out = data;
  for (var i = 0; i < n; i++) {
    final r = ((i < m ? lower : upper) - 1) ~/ 2;
    out = _referenceBoxPass(out, width, height, r, horizontal: true);
    out = _referenceBoxPass(out, width, height, r, horizontal: false);
  }
  return out;
}

/// One running-sum box blur of radius [r] along rows or columns (edges
/// extend the outermost pixel, as the exact kernel does).
Uint8List _referenceBoxPass(
  Uint8List data,
  int width,
  int height,
  int r, {
  required bool horizontal,
}) {
  if (r <= 0) return Uint8List.fromList(data);
  final out = Uint8List(data.length);
  final lines = horizontal ? height : width;
  final length = horizontal ? width : height;
  final step = horizontal ? 4 : width * 4;
  final window = 2 * r + 1;
  final sum = Int32List(4);
  for (var line = 0; line < lines; line++) {
    final base = horizontal ? line * width * 4 : line * 4;
    int at(int i) => base + i.clamp(0, length - 1) * step;
    for (var c = 0; c < 4; c++) {
      var acc = 0;
      for (var k = -r; k <= r; k++) {
        acc += data[at(k) + c];
      }
      sum[c] = acc;
    }
    for (var i = 0; i < length; i++) {
      final o = base + i * step;
      for (var c = 0; c < 4; c++) {
        out[o + c] = (sum[c] / window).round();
        sum[c] += data[at(i + r + 1) + c] - data[at(i - r) + c];
      }
    }
  }
  return out;
}

Uint8List _picture(int width, int height, int seed) {
  final random = math.Random(seed);
  final data = Uint8List(width * height * 4);
  for (var i = 0; i < data.length; i += 4) {
    // Flat areas, hard edges and noise, premultiplied.
    final a = random.nextInt(5) == 0 ? random.nextInt(256) : 255 * (i % 7 ~/ 4);
    data[i + 3] = a;
    for (var c = 0; c < 3; c++) {
      data[i + c] = a == 0 ? 0 : random.nextInt(a + 1);
    }
  }
  return data;
}

/// Flat areas (paper, fills, transparency) with a few strokes and specks:
/// where most windows of a drawn frame hold one colour.
Uint8List _flatPicture(int width, int height, int seed) {
  final random = math.Random(seed);
  final data = Uint8List(width * height * 4);
  final colours = [
    for (var k = 0; k < 4; k++)
      [random.nextInt(256), random.nextInt(256), random.nextInt(256), 255],
    [0, 0, 0, 0],
  ];
  void fill(int x0, int y0, int x1, int y1, List<int> colour) {
    for (var y = y0; y < y1 && y < height; y++) {
      for (var x = x0; x < x1 && x < width; x++) {
        data.setRange((y * width + x) * 4, (y * width + x) * 4 + 4, colour);
      }
    }
  }

  fill(0, 0, width, height, colours[random.nextInt(colours.length)]);
  for (var k = 0; k < 6; k++) {
    final x = random.nextInt(width), y = random.nextInt(height);
    fill(
      x,
      y,
      x + 1 + random.nextInt(width),
      y + 1 + random.nextInt(height),
      colours[random.nextInt(colours.length)],
    );
  }
  for (var k = 0; k < width * height ~/ 40; k++) {
    final i = random.nextInt(width * height) * 4;
    final a = random.nextInt(256);
    data[i + 3] = a;
    for (var c = 0; c < 3; c++) {
      data[i + c] = random.nextInt(a + 1);
    }
  }
  return data;
}

void main() {
  test('every radius on pictures of every shape', () {
    final engine = FilterEngine();
    for (final (width, height) in const [
      (1, 1),
      (1, 9),
      (9, 1),
      (5, 4),
      (23, 17),
      (64, 40),
      (130, 90),
    ]) {
      for (var radius = 1; radius <= 20; radius++) {
        for (final data in [
          _picture(width, height, width * 100 + radius),
          _flatPicture(width, height, width * 100 + radius),
        ]) {
          expect(
            engine.applyGaussianBlur(data, width, height, radius.toDouble()),
            _reference(data, width, height, radius),
            reason: '${width}x$height, radius $radius',
          );
        }
      }
    }
  });

  test('large radii and sigmas use the same three box blurs', () {
    final engine = FilterEngine();
    for (final (width, height) in const [(1, 1), (7, 3), (45, 31), (120, 70)]) {
      final data = _flatPicture(width, height, width);
      final noisy = _picture(width, height, height);
      for (final radius in const [21, 33, 60, 100]) {
        for (final picture in [data, noisy]) {
          expect(
            engine.applyGaussianBlur(picture, width, height, radius.toDouble()),
            _referenceBoxGaussian(picture, width, height, radius / 3.0),
            reason: '${width}x$height, radius $radius',
          );
        }
      }
      for (final sigma in const [7.0, 17.0, 40.0]) {
        expect(
          engine.applyGaussianBlurSigma(noisy, width, height, sigma),
          _referenceBoxGaussian(noisy, width, height, sigma),
          reason: '${width}x$height, sigma $sigma',
        );
      }
    }
  });

  test('a picture that does not start on a word is blurred the same', () {
    final engine = FilterEngine();
    final data = _flatPicture(40, 30, 3);
    final shifted = Uint8List(data.length + 1)
      ..setRange(1, data.length + 1, data);
    expect(
      engine.applyGaussianBlur(Uint8List.sublistView(shifted, 1), 40, 30, 6),
      _reference(data, 40, 30, 6),
    );
  });

  test('a blur by sigma is the same blur of three times the radius', () {
    final engine = FilterEngine();
    final data = _picture(48, 32, 7);
    expect(
      engine.applyGaussianBlurSigma(data, 48, 32, 2.5),
      _reference(data, 48, 32, 8),
    );
  });
}
