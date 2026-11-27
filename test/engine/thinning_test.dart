import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/thinning.dart';

/// [thinTwoPass] removes, pass by pass, the same pixels as looking at every
/// pixel inside the border in every pass (the way the thinnings were
/// written before), for the decisions the line-art filters use.
void _everyPixel(
  Uint8List image,
  int width,
  int height, {
  int? maxRounds,
  required bool Function(int pixel, int pass) removable,
}) {
  if (width < 3 || height < 3) return;
  for (var round = 0; maxRounds == null || round < maxRounds; round++) {
    var changed = false;
    for (var pass = 0; pass < 2; pass++) {
      final remove = <int>[];
      for (var y = 1; y < height - 1; y++) {
        for (var x = 1; x < width - 1; x++) {
          final p = y * width + x;
          if (image[p] != 0 && removable(p, pass)) remove.add(p);
        }
      }
      for (final p in remove) {
        image[p] = 0;
      }
      if (remove.isNotEmpty) changed = true;
    }
    if (!changed) break;
  }
}

/// Zhang–Suen's decision ([fewest] neighbours at least: 2, or 3 with Lü
/// and Wang's correction), on the raw values.
bool Function(int, int) _zhangSuen(Uint8List image, int width, int fewest) =>
    (p, pass) {
      final ring = [
        image[p - width],
        image[p - width + 1],
        image[p + 1],
        image[p + width + 1],
        image[p + width],
        image[p + width - 1],
        image[p - 1],
        image[p - width - 1],
      ];
      final [p2, _, p4, _, p6, _, p8, _] = ring;
      final neighbours = ring.fold(0, (a, b) => a + b);
      if (neighbours < fewest || neighbours > 6) return false;
      var transitions = 0;
      for (var k = 0; k < 8; k++) {
        if (ring[k] == 0 && ring[(k + 1) % 8] != 0) transitions++;
      }
      if (transitions != 1) return false;
      return pass == 0
          ? p2 * p4 * p6 == 0 && p4 * p6 * p8 == 0
          : p2 * p4 * p8 == 0 && p2 * p6 * p8 == 0;
    };

/// Guo–Hall's decision.
bool Function(int, int) _guoHall(Uint8List image, int width) => (p, pass) {
  int at(int q) => image[q] != 0 ? 1 : 0;
  final p2 = at(p - width), p3 = at(p - width + 1), p4 = at(p + 1);
  final p5 = at(p + width + 1), p6 = at(p + width), p7 = at(p + width - 1);
  final p8 = at(p - 1), p9 = at(p - width - 1);
  final runs =
      (p2 == 0 && (p3 | p4) != 0 ? 1 : 0) +
      (p4 == 0 && (p5 | p6) != 0 ? 1 : 0) +
      (p6 == 0 && (p7 | p8) != 0 ? 1 : 0) +
      (p8 == 0 && (p9 | p2) != 0 ? 1 : 0);
  if (runs != 1) return false;
  final n1 = (p9 | p2) + (p3 | p4) + (p5 | p6) + (p7 | p8);
  final n2 = (p2 | p3) + (p4 | p5) + (p6 | p7) + (p8 | p9);
  final count = math.min(n1, n2);
  if (count < 2 || count > 3) return false;
  final side = pass == 0
      ? (p6 | p7 | (1 - p9)) & p8
      : (p2 | p3 | (1 - p5)) & p4;
  return side == 0;
};

/// Thick strokes, blobs, crossings and specks.
Uint8List _mask(int width, int height, int seed) {
  final random = math.Random(seed);
  final mask = Uint8List(width * height);
  for (var k = 0; k < 2 + random.nextInt(6); k++) {
    final cx = random.nextDouble() * width, cy = random.nextDouble() * height;
    final r = 0.5 + random.nextDouble() * 9;
    final ex = random.nextDouble() * width, ey = random.nextDouble() * height;
    for (var t = 0.0; t <= 1; t += 0.02) {
      final x = cx + (ex - cx) * t, y = cy + (ey - cy) * t;
      for (var py = (y - r).floor(); py <= (y + r).ceil(); py++) {
        for (var px = (x - r).floor(); px <= (x + r).ceil(); px++) {
          if (px < 0 || py < 0 || px >= width || py >= height) continue;
          if ((px - x) * (px - x) + (py - y) * (py - y) <= r * r) {
            mask[py * width + px] = 1;
          }
        }
      }
    }
  }
  for (var k = 0; k < width * height ~/ 50; k++) {
    mask[random.nextInt(mask.length)] = 1;
  }
  return mask;
}

void main() {
  test('the same pixels go as looking at every pixel every pass', () {
    for (var seed = 0; seed < 30; seed++) {
      final width = 3 + (seed * 13) % 70;
      final height = 3 + (seed * 7) % 50;
      final mask = _mask(width, height, seed);
      for (final (name, rounds, decide) in [
        ('Zhang–Suen', 60, (Uint8List i) => _zhangSuen(i, width, 2)),
        ('Lü–Wang', math.max(width, height), (i) => _zhangSuen(i, width, 3)),
        ('Guo–Hall', null, (i) => _guoHall(i, width)),
        ('two rounds', 2, (i) => _zhangSuen(i, width, 2)),
      ]) {
        final expected = Uint8List.fromList(mask);
        _everyPixel(
          expected,
          width,
          height,
          maxRounds: rounds,
          removable: decide(expected),
        );
        final thinned = Uint8List.fromList(mask);
        thinTwoPass(
          thinned,
          width,
          height,
          maxRounds: rounds,
          removable: decide(thinned),
        );
        expect(thinned, expected, reason: '$name, seed $seed');
      }
    }
  });

  test('pictures too small to have an inside are left as they are', () {
    final image = Uint8List.fromList([1, 1, 1, 1, 1, 1]);
    thinTwoPass(image, 3, 2, removable: (_, _) => true);
    expect(image, [1, 1, 1, 1, 1, 1]);
  });
}
