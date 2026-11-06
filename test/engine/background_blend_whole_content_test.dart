import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/background_acclimation_engine.dart';
import 'package:niarim/engine/premultiplied.dart';
import 'package:niarim/models/filter_def.dart';

/// Background blend colours the whole drawing, not only its outline: the
/// environment's colour reaches the middle, and the side towards the light
/// is lighter than the far side well inside the edge. Colours are worked on
/// as the colours they are, so a see-through drawing takes the same colours
/// as an opaque one.
void main() {
  const size = 120;

  /// A grey square (straight colour 128) of side 80 in the middle, at
  /// opacity [alpha], premultiplied.
  Uint8List subject({int alpha = 255}) {
    final out = Uint8List(size * size * 4);
    final v = premultipliedChannel(128, alpha);
    for (var y = 20; y < 100; y++) {
      for (var x = 20; x < 100; x++) {
        out.setAll((y * size + x) * 4, [v, v, v, alpha]);
      }
    }
    return out;
  }

  /// Warm orange on the left, deep blue on the right.
  Uint8List background() {
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        out.setAll(
          (y * size + x) * 4,
          x < size ~/ 2 ? const [255, 150, 40, 255] : const [20, 40, 120, 255],
        );
      }
    }
    return out;
  }

  // Light from the left (towards 180°), set by hand so the test does not
  // depend on the estimate.
  const filter = FilterDef(
    id: 'bg',
    name: 'bg',
    kind: FilterKind.backgroundBlend,
    bgBlendAutoLight: false,
    bgBlendDirection: 180,
  );

  List<int> straightAt(Uint8List data, int x, int y) {
    final i = (y * size + x) * 4;
    final a = data[i + 3];
    return [for (var c = 0; c < 3; c++) straightChannel(data[i + c], a)];
  }

  double luma(List<int> c) => c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722;

  test('the middle of the drawing takes the environment\'s colour', () {
    final out = BackgroundAcclimationEngine.apply(
      subject(),
      background(),
      size,
      size,
      filter,
    );
    final centre = straightAt(out, 60, 60);
    final change = centre.fold<int>(0, (sum, c) => sum + (c - 128).abs());
    expect(change, greaterThanOrEqualTo(12), reason: 'centre $centre');
  });

  test('the side towards the light is lighter, well inside the edge', () {
    final out = BackgroundAcclimationEngine.apply(
      subject(),
      background(),
      size,
      size,
      filter,
    );
    // 25 px inside the left and right edges (beyond the edge falloff).
    final lit = luma(straightAt(out, 45, 60));
    final shaded = luma(straightAt(out, 75, 60));
    expect(lit, greaterThan(shaded + 6), reason: 'lit $lit, shaded $shaded');
  });

  test('a see-through drawing takes the same colours as an opaque one', () {
    final opaque = BackgroundAcclimationEngine.apply(
      subject(),
      background(),
      size,
      size,
      filter,
    );
    final half = BackgroundAcclimationEngine.apply(
      subject(alpha: 128),
      background(),
      size,
      size,
      filter,
    );
    for (final (x, y) in const [(60, 60), (25, 60), (95, 60), (60, 95)]) {
      final a = straightAt(opaque, x, y), b = straightAt(half, x, y);
      for (var c = 0; c < 3; c++) {
        expect(b[c], closeTo(a[c], 3), reason: '($x, $y) channel $c');
      }
      expect(half[(y * size + x) * 4 + 3], 128, reason: 'opacity kept');
    }
  });

  test('strength 0 leaves every byte as it was', () {
    final input = subject(alpha: 128);
    final out = BackgroundAcclimationEngine.apply(
      input,
      background(),
      size,
      size,
      filter.copyWith(bgBlendStrength: 0),
    );
    expect(out, orderedEquals(input));
  });
}
