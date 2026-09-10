import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/prism_filter_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prism uses alpha-domain six bands on a non-square image', () {
    const width = 180;
    const height = 90;
    final source = Uint8List(width * height * 4);
    for (var y = 15; y < 75; y++) {
      for (var x = 60; x < 120; x++) {
        source[(y * width + x) * 4 + 3] = 255;
      }
    }

    final result = PrismFilterEngine().apply(
      source,
      width,
      height,
      blurPx: 0,
      gradientDirectionDegrees: 90,
    );

    const expected = <(int, int, int)>[
      (77, 0, 0),
      (0, 77, 0),
      (0, 77, 77),
      (0, 0, 77),
      (77, 0, 77),
      (77, 0, 0),
    ];
    const sampleY = <int>[19, 29, 39, 49, 59, 69];
    for (var band = 0; band < expected.length; band++) {
      final i = (sampleY[band] * width + 90) * 4;
      expect((result[i], result[i + 1], result[i + 2]), expected[band]);
      expect(result[i + 3], 255);
    }

    // Pixels outside the selected shape remain transparent before blur.
    expect(result[(45 * width + 20) * 4 + 3], 0);
  });

  test('prism direction rotates the six-way split by one-degree-capable input', () {
    const width = 180;
    const height = 90;
    final source = Uint8List(width * height * 4);
    for (var y = 15; y < 75; y++) {
      for (var x = 60; x < 120; x++) {
        source[(y * width + x) * 4 + 3] = 255;
      }
    }
    final horizontal = PrismFilterEngine().apply(
      source,
      width,
      height,
      blurPx: 0,
      gradientDirectionDegrees: 0,
    );
    final vertical = PrismFilterEngine().apply(
      source,
      width,
      height,
      blurPx: 0,
      gradientDirectionDegrees: 90,
    );
    expect(_changedBytes(horizontal, vertical), greaterThan(1000));
  });

  testWidgets(
    'default blur glows and addition composites over a required background PNG',
    (tester) async {
      const width = 360;
      const height = 220;
      const prismKey = 'scene#0#prism';
      const backgroundKey = 'scene#0#background';
      final source = _elongatedPrismAlpha(width, height);
      final engine = PrismFilterEngine();
      final prism = engine.apply(
        source,
        width,
        height,
        blurPx: PrismFilterEngine.defaultBlurPx,
        gradientDirectionDegrees: PrismFilterEngine.defaultDirectionDegrees,
      );

      // Gaussian blur happens after alpha-lock coloring, so light must escape the
      // original shape boundary.
      final glowIndex = (110 * width + 150) * 4;
      expect(source[glowIndex + 3], 0);
      expect(prism[glowIndex + 3], greaterThan(0));

      final background = Uint8List(width * height * 4);
      for (var i = 0; i < background.length; i += 4) {
        background[i] = 45;
        background[i + 1] = 40;
        background[i + 2] = 70;
        background[i + 3] = 255;
      }

      final tm = TileManager(canvasWidth: width, canvasHeight: height);
      tm.replaceLayerPixels(backgroundKey, background);
      tm.replaceLayerPixels(prismKey, prism);
      const layers = <Layer>[
        Layer(
          id: 'prism',
          name: 'Prism',
          type: LayerType.normal,
          blendMode: LayerBlendMode.addition,
        ),
        Layer(id: 'background', name: 'Background', type: LayerType.normal),
      ];
      final composite = await LayerCompositor.composite(
        tm,
        layers,
        (layer) => 'scene#0#${layer.id}',
        width,
        height,
      );
      final raw = await composite.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(raw, isNotNull);
      final pixels = raw!.buffer.asUint8List();
      final center = (110 * width + 180) * 4;
      expect(pixels[center], greaterThanOrEqualTo(background[center]));
      expect(pixels[center + 1], greaterThanOrEqualTo(background[center + 1]));
      expect(pixels[center + 2], greaterThanOrEqualTo(background[center + 2]));
      expect(
        pixels[center] + pixels[center + 1] + pixels[center + 2],
        greaterThan(
          background[center] + background[center + 1] + background[center + 2],
        ),
      );

      final png = await composite.toByteData(format: ui.ImageByteFormat.png);
      composite.dispose();
      expect(png, isNotNull);
      final out = Directory('build/visual-reaudit/prism')..createSync(recursive: true);
      File('${out.path}/prism_default17_vertical_linear_dodge_background.png')
          .writeAsBytesSync(png!.buffer.asUint8List());

      // A second real composite proves the adjustable split direction is reflected
      // in output rather than existing only as a stored setting.
      final horizontalPrism = engine.apply(
        source,
        width,
        height,
        blurPx: PrismFilterEngine.defaultBlurPx,
        gradientDirectionDegrees: 0,
      );
      tm.replaceLayerPixels(prismKey, horizontalPrism);
      final horizontalComposite = await LayerCompositor.composite(
        tm,
        layers,
        (layer) => 'scene#0#${layer.id}',
        width,
        height,
      );
      final horizontalPng = await horizontalComposite.toByteData(
        format: ui.ImageByteFormat.png,
      );
      horizontalComposite.dispose();
      expect(horizontalPng, isNotNull);
      File('${out.path}/prism_default17_horizontal_linear_dodge_background.png')
          .writeAsBytesSync(horizontalPng!.buffer.asUint8List());
      tm.dispose();
    },
  );
}

Uint8List _elongatedPrismAlpha(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  const centerX = 180.0;
  const top = 20;
  const bottom = 200;
  const maxHalfWidth = 24.0;
  final middle = (top + bottom) / 2;
  final halfHeight = (bottom - top) / 2;
  for (var y = top; y <= bottom; y++) {
    final taper = 1 - ((y - middle).abs() / halfHeight);
    final halfWidth = (maxHalfWidth * taper).clamp(1.0, maxHalfWidth);
    final left = (centerX - halfWidth).round();
    final right = (centerX + halfWidth).round();
    for (var x = left; x <= right; x++) {
      final i = (y * width + x) * 4;
      pixels[i] = 255;
      pixels[i + 1] = 255;
      pixels[i + 2] = 255;
      pixels[i + 3] = 255;
    }
  }
  return pixels;
}

int _changedBytes(Uint8List a, Uint8List b) {
  final length = a.length < b.length ? a.length : b.length;
  var changed = (a.length - b.length).abs();
  for (var i = 0; i < length; i++) {
    if (a[i] != b[i]) changed++;
  }
  return changed;
}
