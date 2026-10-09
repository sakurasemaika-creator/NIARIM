import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/background_acclimation_engine.dart';
import 'package:niarim/engine/premultiplied.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart' as model;

const _size = 120;

/// A square of straight colour [rgb] (side 60, in the middle), opaque.
Uint8List _square(List<int> rgb, {int alpha = 255}) {
  final out = Uint8List(_size * _size * 4);
  for (var y = 30; y < 90; y++) {
    for (var x = 30; x < 90; x++) {
      out.setAll((y * _size + x) * 4, [
        for (final c in rgb) premultipliedChannel(c, alpha),
        alpha,
      ]);
    }
  }
  return out;
}

/// A background whose colour at each pixel is [colour] (x, y).
Uint8List _background(List<int> Function(int x, int y) colour) {
  final out = Uint8List(_size * _size * 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      out.setAll((y * _size + x) * 4, [...colour(x, y), 255]);
    }
  }
  return out;
}

List<int> _at(Uint8List data, int x, int y) {
  final i = (y * _size + x) * 4;
  return [
    for (var c = 0; c < 3; c++) straightChannel(data[i + c], data[i + 3]),
  ];
}

double _luma(List<int> c) => c[0] * .2126 + c[1] * .7152 + c[2] * .0722;

double _saturation(List<int> c) {
  final hi = c.reduce((a, b) => a > b ? a : b);
  final lo = c.reduce((a, b) => a < b ? a : b);
  return hi == 0 ? 0 : (hi - lo) / hi;
}

/// Only [toneMatch] at work: everything else at 0.
FilterDef _onlyTones(double toneMatch) => FilterDef(
  id: 'bg',
  name: 'bg',
  kind: FilterKind.backgroundBlend,
  bgBlendStrength: 100,
  bgBlendLightStrength: 0,
  bgBlendShadowStrength: 0,
  bgBlendAmbientStrength: 0,
  bgBlendReflectionStrength: 0,
  bgBlendColorBleed: 0,
  bgBlendSecondaryStrength: 0,
  bgBlendToneMatch: toneMatch,
);

/// 背景馴染ませ follows the tips of a painting tutorial on fitting a
/// character into a photo background: the drawing's own colours are kept
/// within the background's brightness and saturation, each tone takes the
/// background's colour cast (colour balance), shadows are the colour of the
/// background's shadows rather than black or grey, the surroundings' colour
/// goes over in Overlay, reflected light in Screen and a strong coloured
/// light (neon) in Add.
void main() {
  // A dim, muted evening: blue-grey shadows, dull orange light, nothing
  // brighter than about 60 %.
  final dusk = _background(
    (x, y) => y < 60 ? const [150, 112, 92] : const [52, 60, 84],
  );

  test('a highlight brighter than the background\'s brightest comes down '
      'towards it; with the setting at 0 it stays', () {
    final white = _square(const [250, 250, 250]);
    final kept = BackgroundAcclimationEngine.apply(
      white,
      dusk,
      _size,
      _size,
      _onlyTones(0),
    );
    expect(_at(kept, 60, 60), [250, 250, 250]);
    final matched = BackgroundAcclimationEngine.apply(
      white,
      dusk,
      _size,
      _size,
      _onlyTones(100),
    );
    final l = _luma(_at(matched, 60, 60));
    expect(l, lessThan(200), reason: '${_at(matched, 60, 60)}');
    // Not flattened to the background: still the lightest thing there.
    expect(l, greaterThan(_luma(const [150, 112, 92])));
  });

  test('a colour more saturated than the background\'s is toned down', () {
    final red = _square(const [230, 20, 30]);
    final out = BackgroundAcclimationEngine.apply(
      red,
      dusk,
      _size,
      _size,
      _onlyTones(100),
    );
    final before = _saturation(const [230, 20, 30]);
    final after = _saturation(_at(out, 60, 60));
    expect(after, lessThan(before - .1));
    // Still red.
    final c = _at(out, 60, 60);
    expect(c[0], greaterThan(c[1] + 60));
  });

  test('each tone takes the background\'s colour cast, keeping its '
      'brightness (colour balance)', () {
    final warm = _background(
      (x, y) => [
        (200 - y).clamp(0, 255),
        (150 - y).clamp(0, 255),
        (90 - y ~/ 2).clamp(0, 255),
      ],
    );
    final grey = _square(const [128, 128, 128]);
    final out = BackgroundAcclimationEngine.apply(
      grey,
      warm,
      _size,
      _size,
      _onlyTones(100),
    );
    final c = _at(out, 60, 60);
    expect(c[0], greaterThan(c[2] + 10), reason: '$c');
    expect(_luma(c), closeTo(128, 4));
  });

  test('dark lines keep their darkness and colour', () {
    final ink = _square(const [20, 22, 30]);
    final out = BackgroundAcclimationEngine.apply(
      ink,
      _background((x, y) => const [240, 140, 40]),
      _size,
      _size,
      _onlyTones(100),
    );
    final c = _at(out, 60, 60);
    for (var k = 0; k < 3; k++) {
      expect(c[k], closeTo(const [20, 22, 30][k], 2), reason: '$c');
    }
  });

  test('the shadow colour is the background\'s shadow colour, dark, not '
      'black or grey', () {
    // Light from the top left; the shadows of the scene are deep blue.
    final scene = _background(
      (x, y) => x + y < _size ? const [250, 220, 170] : const [40, 60, 130],
    );
    final analysis = BackgroundAcclimationEngine.analyze(
      _square(const [128, 128, 128]),
      scene,
      _size,
      _size,
      const FilterDef(id: 'bg', name: 'bg', kind: FilterKind.backgroundBlend),
    );
    final shadow = analysis.shadowColor;
    final r = (shadow >> 16) & 0xFF, g = (shadow >> 8) & 0xFF;
    final b = shadow & 0xFF;
    expect(b, greaterThan(r + 20), reason: 'blue: ${shadow.toRadixString(16)}');
    expect(_luma([r, g, b]), lessThan(70), reason: 'dark enough to deepen');
    expect(_luma([r, g, b]), greaterThan(8), reason: 'not black');
    expect(analysis.tones.shadow, isNot(analysis.tones.highlight));
  });

  test('a strong coloured light glows in Add; daylight and a sunset do '
      'not', () {
    expect(BackgroundAcclimationEngine.isGlowingLight(0xFFFF2FB4), isTrue);
    expect(BackgroundAcclimationEngine.isGlowingLight(0xFF27E0FF), isTrue);
    expect(BackgroundAcclimationEngine.isGlowingLight(0xFFCF7F52), isFalse);
    expect(BackgroundAcclimationEngine.isGlowingLight(0xFFBCDCF1), isFalse);
    expect(BackgroundAcclimationEngine.isGlowingLight(0xFF808080), isFalse);
    // Add only brightens, by the light's colour times its amount.
    final (r, g, b) = BackgroundAcclimationEngine.blendForTest(
      100,
      100,
      100,
      0xFF00C0FF,
      .5,
      mode: model.LayerBlendMode.addition,
    );
    expect(r, closeTo(100, 1));
    expect(g, closeTo(100 + 192 * .5, 1));
    expect(b, closeTo(100 + 255 * .5, 1));
  });

  test('beside a cyan neon, the edge facing it lights up cyan', () {
    final neon = _background(
      (x, y) => x > 100 ? const [39, 224, 255] : const [20, 26, 51],
    );
    final grey = _square(const [120, 110, 100]);
    final out = BackgroundAcclimationEngine.apply(
      grey,
      neon,
      _size,
      _size,
      const FilterDef(id: 'bg', name: 'bg', kind: FilterKind.backgroundBlend),
    );
    final facing = _at(out, 88, 60), away = _at(out, 31, 60);
    expect(facing[2], greaterThan(away[2] + 10), reason: '$facing / $away');
    expect(
      facing[2] - facing[0],
      greaterThan(away[2] - away[0] + 15),
      reason: '$facing / $away',
    );
  });

  test('「ぼかし具合」 softens the background the colours are taken from', () {
    // Stripes 2 px wide, black and white.
    final stripes = _background(
      (x, y) => x ~/ 2 % 2 == 0 ? const [0, 0, 0] : const [255, 255, 255],
    );
    expect(
      BackgroundAcclimationEngine.blurredBackground(stripes, _size, _size, 0),
      same(stripes),
    );
    final soft = BackgroundAcclimationEngine.blurredBackground(
      stripes,
      _size,
      _size,
      8,
    );
    for (var x = 10; x < 20; x++) {
      expect(soft[(50 * _size + x) * 4], closeTo(128, 20), reason: 'x = $x');
      expect(soft[(50 * _size + x) * 4 + 3], 255);
    }
  });

  test('the setting is saved, restored and 50 for older filters', () {
    const filter = FilterDef(
      id: 'bg',
      name: 'bg',
      kind: FilterKind.backgroundBlend,
      bgBlendToneMatch: 80,
    );
    expect(FilterDef.fromJson(filter.toJson()).bgBlendToneMatch, 80);
    final old = filter.toJson()..remove('bgBlendToneMatch');
    expect(FilterDef.fromJson(old).bgBlendToneMatch, 50);
    expect(filter.copyWith(bgBlendToneMatch: 10).bgBlendToneMatch, 10);
  });
}
