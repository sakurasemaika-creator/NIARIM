import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

/// The sample character of the feature captures, and four scenes to set it
/// in, drawn at 256 x 256.
Future<Uint8List> _render(void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(256, 256);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

void _character(Canvas canvas) {
  final line = Paint()
    ..color = const Color(0xff242739)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  const head = Rect.fromLTWH(55, 33, 120, 120);
  final body = Path()
    ..moveTo(64, 145)
    ..lineTo(165, 145)
    ..lineTo(194, 217)
    ..quadraticBezierTo(115, 240, 35, 217)
    ..close();
  canvas
    ..drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(30, 140),
          const Offset(195, 235),
          [const Color(0xffdc7295), const Color(0xff653a9e)],
        ),
    )
    ..drawOval(head, Paint()..color = const Color(0xffffd8b4))
    ..drawPath(body, line)
    ..drawOval(head, line);
  final hair = Path()
    ..moveTo(55, 95)
    ..quadraticBezierTo(48, 20, 115, 27)
    ..quadraticBezierTo(186, 20, 178, 98)
    ..lineTo(145, 66)
    ..lineTo(114, 86)
    ..lineTo(94, 63)
    ..close();
  canvas
    ..drawPath(hair, Paint()..color = const Color(0xff36455e))
    ..drawPath(hair, line)
    ..drawCircle(const Offset(91, 104), 4, Paint()..color = line.color)
    ..drawCircle(const Offset(141, 104), 4, Paint()..color = line.color)
    ..drawArc(const Rect.fromLTWH(102, 111, 27, 22), 0.2, 2.7, false, line);
}

final _scenes = <void Function(Canvas)>[
  // The capture sample: orange to purple.
  (c) => c.drawRect(
    const Rect.fromLTWH(0, 0, 256, 256),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(256, 256), [
        const Color(0xffdd8443),
        const Color(0xff54359e),
      ]),
  ),
  // Day: sky and grass, the sun at the top left.
  (c) => c
    ..drawRect(
      const Rect.fromLTWH(0, 0, 256, 170),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 170), [
          const Color(0xff4f9be8),
          const Color(0xffcde6f7),
        ]),
    )
    ..drawRect(
      const Rect.fromLTWH(0, 170, 256, 86),
      Paint()..color = const Color(0xff5c9a3c),
    )
    ..drawCircle(
      const Offset(30, 30),
      22,
      Paint()..color = const Color(0xfffff6d8),
    ),
  // Night: a cyan neon sign right beside the character (within the
  // default sampling band of 28 px).
  (c) => c
    ..drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()..color = const Color(0xff141a33),
    )
    ..drawRect(
      const Rect.fromLTWH(0, 40, 30, 120),
      Paint()..color = const Color(0xffff2fb4),
    )
    ..drawRect(
      const Rect.fromLTWH(186, 60, 70, 110),
      Paint()..color = const Color(0xff27e0ff),
    )
    ..drawRect(
      const Rect.fromLTWH(0, 220, 256, 36),
      Paint()..color = const Color(0xff262a40),
    ),
  // Sunset: a bright horizon over dark ground.
  (c) => c
    ..drawRect(
      const Rect.fromLTWH(0, 0, 256, 150),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 150), [
          const Color(0xff3b2a6b),
          const Color(0xffff9a4a),
        ]),
    )
    ..drawRect(
      const Rect.fromLTWH(0, 150, 256, 106),
      Paint()..color = const Color(0xff2c1d3a),
    ),
];

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

  testWidgets('drawn for review: the sample character in four scenes, before '
      'and after', (tester) async {
    const filter = FilterDef(
      id: 'Filter0020',
      name: '背景馴染ませ',
      kind: FilterKind.backgroundBlend,
    );
    final character = (await tester.runAsync(() => _render(_character)))!;
    const scale = 2, gap = 8, side = 256 * scale;
    final sheet = img.Image(
      width: (side + gap) * _scenes.length - gap,
      height: side * 2 + gap,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (final (k, scene) in _scenes.indexed) {
      final background = (await tester.runAsync(() => _render(scene)))!;
      final out = BackgroundAcclimationEngine.apply(
        character,
        background,
        256,
        256,
        filter,
      );
      // Before above, after below, each over its scene.
      for (final (row, picture) in [(0, character), (1, out)]) {
        for (var y = 0; y < side; y++) {
          for (var x = 0; x < side; x++) {
            final i = ((y ~/ scale) * 256 + x ~/ scale) * 4;
            final a = picture[i + 3] / 255;
            int over(int c) => (picture[i + c] + background[i + c] * (1 - a))
                .round()
                .clamp(0, 255);
            sheet.setPixelRgb(
              k * (side + gap) + x,
              row * (side + gap) + y,
              over(0),
              over(1),
              over(2),
            );
          }
        }
      }
    }
    final dir = Directory('build/background-acclimation-v2')
      ..createSync(recursive: true);
    File(
      '${dir.path}/character_scenes.png',
    ).writeAsBytesSync(img.encodePng(sheet));
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
