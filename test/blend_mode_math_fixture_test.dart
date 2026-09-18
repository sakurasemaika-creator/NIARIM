import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Five canonical fixtures required by the production blend-mode closure.
  // This test is part of the Prism/Blend production regression.\n  // Keep the five fixtures aligned with the production closure matrix.
  const fixtures = <_Fixture>[
    _Fixture('black', [0, 0, 0, 255], [190, 90, 40, 255]),
    _Fixture('white', [255, 255, 255, 255], [40, 120, 210, 255]),
    _Fixture('gray50', [128, 128, 128, 255], [210, 70, 150, 255]),
    _Fixture('chromatic', [42, 176, 219, 255], [224, 73, 118, 255]),
    _Fixture('translucent', [54, 164, 218, 143], [205, 92, 47, 181]),
  ];

  for (final mode in LayerBlendMode.values) {
    for (final fixture in fixtures) {
      testWidgets('${mode.name} matches reference math for ${fixture.name}', (tester) async {
        final actual = await tester.runAsync(
          () => _compositePixel(mode, fixture.backdrop, fixture.source),
        );
        expect(actual, isNotNull);
        final expected = _reference(mode, fixture.backdrop, fixture.source);
        for (var channel = 0; channel < 4; channel++) {
          expect(
            actual![channel],
            closeTo(expected[channel], 3),
            reason:
                '${mode.name}/${fixture.name} channel $channel: '
                'actual=${actual[channel]} expected=${expected[channel]}',
          );
        }
      });
    }
  }
}

class _Fixture {
  const _Fixture(this.name, this.backdrop, this.source);
  final String name;
  final List<int> backdrop;
  final List<int> source;
}

Future<List<int>> _compositePixel(
  LayerBlendMode mode,
  List<int> backdrop,
  List<int> source,
) async {
  final tm = TileManager(canvasWidth: 1, canvasHeight: 1);
  tm.replaceLayerPixels('scene#0#backdrop', _premultiply(backdrop));
  tm.replaceLayerPixels('scene#0#source', _premultiply(source));
  final image = await LayerCompositor.composite(
    tm,
    <Layer>[
      Layer(
        id: 'source',
        name: 'Source',
        type: LayerType.normal,
        blendMode: mode,
      ),
      const Layer(
        id: 'backdrop',
        name: 'Backdrop',
        type: LayerType.normal,
      ),
    ],
    (layer) => 'scene#0#${layer.id}',
    1,
    1,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  image.dispose();
  tm.dispose();
  return data!.buffer.asUint8List().take(4).toList();
}

Uint8List _premultiply(List<int> straight) {
  final alpha = straight[3] / 255.0;
  return Uint8List.fromList(<int>[
    (straight[0] * alpha).round(),
    (straight[1] * alpha).round(),
    (straight[2] * alpha).round(),
    straight[3],
  ]);
}

List<int> _reference(
  LayerBlendMode mode,
  List<int> backdrop,
  List<int> source,
) {
  final cb = backdrop.take(3).map((v) => v / 255.0).toList();
  final cs = source.take(3).map((v) => v / 255.0).toList();
  final ab = backdrop[3] / 255.0;
  final as = source[3] / 255.0;

  // Flutter's plus operator is Porter-Duff plus rather than source-over.
  if (mode == LayerBlendMode.addition || mode == LayerBlendMode.linearDodge) {
    final out = <int>[];
    for (var c = 0; c < 3; c++) {
      out.add(((cb[c] * ab + cs[c] * as).clamp(0.0, 1.0) * 255).round());
    }
    out.add(((ab + as).clamp(0.0, 1.0) * 255).round());
    return out;
  }

  final ao = as + ab * (1 - as);
  if (ao <= 0) return const [0, 0, 0, 0];
  final blended = _blendRgb(mode, cb, cs);
  final out = <int>[];
  for (var c = 0; c < 3; c++) {
    final premultiplied =
        as * (1 - ab) * cs[c] +
        as * ab * blended[c] +
        (1 - as) * ab * cb[c];
    out.add((premultiplied / ao * 255).round().clamp(0, 255));
  }
  out.add((ao * 255).round().clamp(0, 255));
  return out;
}

List<double> _blendRgb(
  LayerBlendMode mode,
  List<double> b,
  List<double> s,
) {
  switch (mode) {
    case LayerBlendMode.hue:
      return _setLum(_setSat(List<double>.from(s), _sat(b)), _lum(b));
    case LayerBlendMode.saturation:
      return _setLum(_setSat(List<double>.from(b), _sat(s)), _lum(b));
    case LayerBlendMode.color:
      return _setLum(List<double>.from(s), _lum(b));
    case LayerBlendMode.luminosity:
      return _setLum(List<double>.from(b), _lum(s));
    default:
      return List<double>.generate(3, (i) => _blend(mode, b[i], s[i]));
  }
}

double _blend(LayerBlendMode mode, double b, double s) {
  switch (mode) {
    case LayerBlendMode.normal:
      return s;
    case LayerBlendMode.multiply:
      return b * s;
    case LayerBlendMode.screen:
      return b + s - b * s;
    case LayerBlendMode.overlay:
      return b <= 0.5 ? 2 * b * s : 1 - 2 * (1 - b) * (1 - s);
    case LayerBlendMode.subtract:
      return (b - s).clamp(0.0, 1.0);
    case LayerBlendMode.darken:
      return b < s ? b : s;
    case LayerBlendMode.lighten:
      return b > s ? b : s;
    case LayerBlendMode.colorBurn:
      return s <= 0 ? 0 : 1 - ((1 - b) / s).clamp(0.0, 1.0);
    case LayerBlendMode.colorDodge:
      return s >= 1 ? 1 : (b / (1 - s)).clamp(0.0, 1.0);
    case LayerBlendMode.hardLight:
      return s <= 0.5 ? 2 * b * s : 1 - 2 * (1 - b) * (1 - s);
    case LayerBlendMode.softLight:
      if (s <= 0.5) return b - (1 - 2 * s) * b * (1 - b);
      final d = b <= 0.25
          ? ((16 * b - 12) * b + 4) * b
          : _sqrt(b);
      return b + (2 * s - 1) * (d - b);
    case LayerBlendMode.difference:
      return (b - s).abs();
    case LayerBlendMode.linearBurn:
      return (b + s - 1).clamp(0.0, 1.0);
    case LayerBlendMode.vividLight:
      return s <= 0.5
          ? (s <= 0 ? 0 : 1 - ((1 - b) / (2 * s)).clamp(0.0, 1.0))
          : (s >= 1 ? 1 : (b / (2 * (1 - s))).clamp(0.0, 1.0));
    case LayerBlendMode.linearLight:
      return (b + 2 * s - 1).clamp(0.0, 1.0);
    case LayerBlendMode.pinLight:
      return s < 0.5 ? b.clamp(0.0, 2 * s) : b.clamp(2 * s - 1, 1.0);
    case LayerBlendMode.hardMix:
      return _blend(LayerBlendMode.vividLight, b, s) < 0.5 ? 0 : 1;
    case LayerBlendMode.exclusion:
      return b + s - 2 * b * s;
    case LayerBlendMode.divide:
      return s <= 0 ? 1 : (b / s).clamp(0.0, 1.0);
    case LayerBlendMode.addition:
    case LayerBlendMode.linearDodge:
    case LayerBlendMode.hue:
    case LayerBlendMode.saturation:
    case LayerBlendMode.color:
    case LayerBlendMode.luminosity:
      throw StateError('handled outside channel blend');
  }
}

double _lum(List<double> c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];

double _sat(List<double> c) {
  final min = c.reduce((a, b) => a < b ? a : b);
  final max = c.reduce((a, b) => a > b ? a : b);
  return max - min;
}

List<double> _clipColor(List<double> c) {
  final l = _lum(c);
  final n = c.reduce((a, b) => a < b ? a : b);
  final x = c.reduce((a, b) => a > b ? a : b);
  if (n < 0) {
    for (var i = 0; i < 3; i++) {
      c[i] = l + ((c[i] - l) * l) / (l - n);
    }
  }
  if (x > 1) {
    for (var i = 0; i < 3; i++) {
      c[i] = l + ((c[i] - l) * (1 - l)) / (x - l);
    }
  }
  return c;
}

List<double> _setLum(List<double> c, double l) {
  final d = l - _lum(c);
  for (var i = 0; i < 3; i++) {
    c[i] += d;
  }
  return _clipColor(c);
}

List<double> _setSat(List<double> c, double s) {
  final indices = [0, 1, 2]..sort((a, b) => c[a].compareTo(c[b]));
  final iMin = indices[0];
  final iMid = indices[1];
  final iMax = indices[2];
  if (c[iMax] > c[iMin]) {
    c[iMid] = ((c[iMid] - c[iMin]) * s) / (c[iMax] - c[iMin]);
    c[iMax] = s;
  } else {
    c[iMid] = 0;
    c[iMax] = 0;
  }
  c[iMin] = 0;
  return c;
}

// Newton iteration keeps this reference independent of dart:math's sqrt.
double _sqrt(double value) {
  if (value <= 0) return 0;
  var x = value;
  for (var i = 0; i < 10; i++) {
    x = 0.5 * (x + value / x);
  }
  return x;
}
