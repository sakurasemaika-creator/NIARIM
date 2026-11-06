import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';

const _w = 240, _h = 160;

/// A face seen from the front: skin up to the cheek line at x = 75 and
/// x = 165, background beyond; and vertical stripes every 10 px so the
/// magnification can be measured.
Uint8List _face() {
  final d = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final skin = x >= 75 && x < 165;
      final stripe = x % 10 == 0;
      d[i] = stripe ? 40 : (skin ? 240 : 200);
      d[i + 1] = stripe ? 40 : (skin ? 200 : 220);
      d[i + 2] = stripe ? 40 : (skin ? 180 : 250);
      d[i + 3] = 255;
    }
  }
  return d;
}

/// A round lens of [radius] centred on ([cx], [cy]).
Uint8List _lens(double cx, double cy, double radius) {
  final m = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      if (math.pow(x - cx, 2) + math.pow(y - cy, 2) <= radius * radius) {
        m[(y * _w + x) * 4 + 3] = 255;
      }
    }
  }
  return m;
}

/// The x positions of the dark stripes along row [y], between [from] and
/// [to].
List<double> _stripes(Uint8List d, int y, int from, int to) {
  final out = <double>[];
  var x = from;
  while (x < to) {
    if (d[(y * _w + x) * 4] < 150) {
      var sum = 0.0, weight = 0.0;
      while (x < to && d[(y * _w + x) * 4] < 150) {
        final w = 255.0 - d[(y * _w + x) * 4];
        sum += x * w;
        weight += w;
        x++;
      }
      out.add(sum / weight);
    } else {
      x++;
    }
  }
  return out;
}

void _write(String name, Uint8List before, Uint8List after, Uint8List mask) {
  final image = img.Image(width: _w * 2 + 8, height: _h);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (final (offset, d) in [(0, before), (_w + 8, after)]) {
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final i = (y * _w + x) * 4;
        var r = d[i], g = d[i + 1], b = d[i + 2];
        // The lens rim, thinly, so the step at its edge can be seen.
        final rim =
            mask[i + 3] != 0 &&
            ((x > 0 && mask[i - 1] == 0) ||
                (x < _w - 1 && mask[i + 7] == 0) ||
                (y > 0 && mask[i + 3 - _w * 4] == 0) ||
                (y < _h - 1 && mask[i + 3 + _w * 4] == 0));
        if (rim) (r, g, b) = (90, 90, 90);
        image.setPixelRgb(x + offset, y, r, g, b);
      }
    }
  }
  final dir = Directory('build/filter-glasses')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

/// 眼鏡断層 shows what a real strong lens does (the reference photos of
/// strongly short-sighted glasses): what is seen through the lens is shrunk
/// evenly about the lens's centre, by roughly a tenth, so the cheek line
/// steps inwards at the rim; nothing is sucked into the middle.
void main() {
  final engine = FilterEngine();

  test('a minus lens shrinks what is behind it evenly, and the cheek steps '
      'in at the rim', () {
    final before = _face();
    // A lens over the left eye that reaches past the cheek line.
    final mask = _lens(95, 80, 45);
    final after = engine.applyLensDistortion(before, _w, _h, -50, mask);
    _write('minus_lens', before, after, mask);

    // Stripes 10 px apart appear about 0.88 x 10 px apart through the
    // lens, near the centre and further out alike.
    final seen = _stripes(after, 80, 60, 130);
    expect(seen.length, greaterThan(6));
    final mean = (seen.last - seen.first) / (seen.length - 1);
    expect(mean, closeTo(8.8, 0.3), reason: 'stripes $seen');
    // Near the centre and towards the rim alike: no suction into the middle.
    double meanGap(Iterable<double> xs) {
      final list = xs.toList();
      return (list.last - list.first) / (list.length - 1);
    }

    final inner = meanGap(seen.where((x) => (x - 95).abs() <= 20));
    final outer = meanGap(seen.where((x) => x < 80));
    expect((inner - outer).abs(), lessThan(.8), reason: '$inner vs $outer');

    // The cheek line (skin starts at x = 75 outside the lens) is seen
    // further in through the lens: a step at the rim.
    int skinStart(int y) {
      for (var x = 0; x < _w; x++) {
        if (after[(y * _w + x) * 4] > 230) return x;
      }
      return -1;
    }

    expect(skinStart(20), 75, reason: 'above the lens, unchanged');
    expect(skinStart(80), inInclusiveRange(76, 79), reason: 'through it');
    // Outside the lens nothing changes.
    for (var i = 0; i < before.length; i += 4) {
      if (mask[i + 3] == 0) expect(after[i], before[i]);
    }
  });

  test('a plus lens enlarges, and a stronger lens changes size more', () {
    final before = _face();
    final mask = _lens(120, 80, 40);
    double gap(double strength) {
      final after = engine.applyLensDistortion(before, _w, _h, strength, mask);
      final seen = _stripes(after, 80, 95, 146);
      return (seen.last - seen.first) / (seen.length - 1);
    }

    expect(gap(50), greaterThan(10.5));
    expect(gap(-30), allOf(greaterThan(gap(-80)), lessThan(10)));
    expect(gap(-100), greaterThan(7.0), reason: 'never extreme');
  });
}
