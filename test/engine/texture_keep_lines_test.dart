import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

const _w = 132, _h = 84;
const _ink = [36, 39, 57, 255];

/// A shaded shirt with its outline and a fold line drawn on the same layer,
/// on transparency. [isInk] tells which pixels are the drawn lines.
(Uint8List, bool Function(int x, int y)) _shirt() {
  final d = Uint8List(_w * _h * 4);
  final ink = <int>{};
  for (var y = 10; y <= 80; y++) {
    final half = 20 + 30 * (y - 10) / 70;
    for (var x = 0; x < _w; x++) {
      const cx = 66.0;
      if ((x - cx).abs() > half) continue;
      final edge = half - (x - cx).abs();
      final fold = (x - (cx + 6 * math.sin(y / 9))).abs();
      final shade =
          (0.45 +
                  0.45 * math.cos((x - cx) / 22) -
                  0.25 * math.exp(-fold * fold / 30))
              .clamp(0.4, 1.0);
      final v = (shade * 230).round();
      var c = [(v * .55).round(), (v * .75).round(), v, 255];
      if (edge < 2.2 || y < 12 || y > 78 || fold < 1.0 && y > 30) {
        c = _ink;
        ink.add(y * _w + x);
      }
      d.setAll((y * _w + x) * 4, c);
    }
  }
  return (d, (x, y) => ink.contains(y * _w + x));
}

/// A sphere shaded down to near black at its rim, with no outline.
Uint8List _sphere() {
  final d = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final dx = (x - 40) / 32, dy = (y - 42) / 32;
      final r2 = dx * dx + dy * dy;
      if (r2 > 1) continue;
      final z = math.sqrt(1 - r2);
      final l = (0.15 + 0.75 * math.max(0, -dx * .5 - dy * .6 + z * .62)).clamp(
        0.0,
        1.0,
      );
      final v = (l * 255).round();
      d.setAll((y * _w + x) * 4, [v, (v * .9).round(), (v * .8).round(), 255]);
    }
  }
  return d;
}

bool _same(Uint8List a, Uint8List b, int p) {
  for (var c = 0; c < 4; c++) {
    if (a[p * 4 + c] != b[p * 4 + c]) return false;
  }
  return true;
}

/// 質感変更「線画を残す」: line art drawn on the same layer as the
/// surfaces keeps its own colour, and only the surfaces take the texture.
void main() {
  final engine = FilterEngine();
  Uint8List texture(
    Uint8List data, {
    required bool keepLines,
    AuroraHologramPreset preset = AuroraHologramPreset.auroraPastel,
  }) => engine.applyAuroraHologram(
    data,
    _w,
    _h,
    strength: 100,
    brightness: 0,
    saturation: 0,
    preset: preset,
    keepLines: keepLines,
  );

  test('the outline and the fold line keep their colour; the surfaces '
      'between take the texture', () {
    final (shirt, isInk) = _shirt();
    for (final preset in AuroraHologramPreset.values) {
      final kept = texture(shirt, keepLines: true, preset: preset);
      final plain = texture(shirt, keepLines: false, preset: preset);
      var ink = 0, inkKept = 0, surface = 0, surfaceKept = 0;
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final p = y * _w + x;
          if (shirt[p * 4 + 3] == 0) continue;
          if (isInk(x, y)) {
            ink++;
            if (_same(kept, shirt, p)) inkKept++;
          } else {
            surface++;
            if (_same(kept, shirt, p)) surfaceKept++;
            // Away from the lines the result is the texture's own.
            final nearInk = [
              for (var oy = -3; oy <= 3; oy++)
                for (var ox = -3; ox <= 3; ox++) isInk(x + ox, y + oy),
            ].any((b) => b);
            if (!nearInk) {
              expect(
                _same(kept, plain, p),
                isTrue,
                reason: '${preset.name} ($x, $y)',
              );
            }
          }
        }
      }
      expect(inkKept / ink, greaterThan(.9), reason: preset.name);
      expect(surfaceKept / surface, lessThan(.05), reason: preset.name);
    }
    // Off, the lines take the texture like the rest.
    final plain = texture(shirt, keepLines: false);
    var changed = 0, ink = 0;
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        if (!isInk(x, y)) continue;
        ink++;
        if (!_same(plain, shirt, y * _w + x)) changed++;
      }
    }
    expect(changed / ink, greaterThan(.95));
  });

  test('shading that darkens to a shape\'s edge is not a line', () {
    final sphere = _sphere();
    final kept = texture(sphere, keepLines: true);
    final plain = texture(sphere, keepLines: false);
    // Inside the rim (where a few pixels of steep shading look the same as
    // an outline) the texture is the same as with the lines not kept.
    var inside = 0;
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final r = math.sqrt(math.pow(x - 40, 2) + math.pow(y - 42, 2));
        if (r > 32 - 5) continue;
        inside++;
        expect(_same(kept, plain, y * _w + x), isTrue, reason: '($x, $y)');
      }
    }
    expect(inside, greaterThan(2000));
  });

  test('a wide dark area and a thin dark shape on its own take the '
      'texture', () {
    final d = Uint8List(_w * _h * 4);
    // A light square with a 30 px dark band across it, and a thin dark
    // stroke on the transparency beside it.
    for (var y = 10; y < 70; y++) {
      for (var x = 10; x < 70; x++) {
        final dark = y >= 25 && y < 55;
        d.setAll(
          (y * _w + x) * 4,
          dark ? const [30, 32, 40, 255] : const [210, 200, 190, 255],
        );
      }
      for (var x = 100; x < 103; x++) {
        d.setAll((y * _w + x) * 4, const [30, 32, 40, 255]);
      }
    }
    final kept = texture(d, keepLines: true);
    final plain = texture(d, keepLines: false);
    for (final (x, y) in const [(40, 40), (30, 30), (60, 50), (101, 40)]) {
      expect(_same(kept, plain, y * _w + x), isTrue, reason: '($x, $y)');
    }
  });

  test('on by default, saved and restored, and on for older filters', () {
    const filter = FilterDef(
      id: 'texture',
      name: 'texture',
      kind: FilterKind.auroraHologram,
      strength: 100,
    );
    expect(filter.hologramKeepLines, isTrue);
    final off = filter.copyWith(hologramKeepLines: false);
    expect(FilterDef.fromJson(off.toJson()).hologramKeepLines, isFalse);
    final old = filter.toJson()..remove('hologramKeepLines');
    expect(FilterDef.fromJson(old).hologramKeepLines, isTrue);
    // The applied filter follows the switch.
    final (shirt, isInk) = _shirt();
    final on = applyDrawFilterInIsolate((shirt, _w, _h, filter, null));
    final offOut = applyDrawFilterInIsolate((shirt, _w, _h, off, null));
    final p = 11 * _w + 66; // on the top outline
    expect(isInk(66, 11), isTrue);
    expect(_same(on, shirt, p), isTrue);
    expect(_same(offOut, shirt, p), isFalse);
  });
}
