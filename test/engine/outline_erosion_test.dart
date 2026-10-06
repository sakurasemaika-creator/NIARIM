import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// Outline's "reach inside" threshold decides how faint a pixel may be and
/// still count as the shape: at 0 the outline goes only outside everything
/// drawn, and raising it lets the outline reach in under a soft, fading edge
/// to hug the visible body — never over the solid part.
void main() {
  final engine = FilterEngine();
  const n = 80;

  /// A disc that is solid to radius 15 and fades out to nothing at 30.
  Uint8List softDisc() {
    final rgba = Uint8List(n * n * 4);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final d = math.sqrt(
          math.pow(x + .5 - 40, 2) + math.pow(y + .5 - 40, 2),
        );
        final a = (255 * (1 - ((d - 15) / 15).clamp(0.0, 1.0))).round();
        rgba.setAll((y * n + x) * 4, [a, 0, 0, a]); // premultiplied red
      }
    }
    return rgba;
  }

  /// How close to the centre the outline ring comes.
  double innerRadius(Uint8List ring) {
    var best = double.infinity;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (ring[(y * n + x) * 4 + 3] == 0) continue;
        best = math.min(
          best,
          math.sqrt(math.pow(x + .5 - 40, 2) + math.pow(y + .5 - 40, 2)),
        );
      }
    }
    return best;
  }

  Uint8List ring(double erosion) => engine.applyOutlineLayer(
    softDisc(),
    n,
    n,
    color: 0xFF000000,
    widthPx: 4,
    erosion: erosion,
  );

  test('at 0 the outline starts outside everything drawn', () {
    expect(innerRadius(ring(0)), greaterThan(29));
  });

  test('raising it lets the outline reach in under the fading edge', () {
    final r0 = innerRadius(ring(0));
    final r50 = innerRadius(ring(50));
    final r100 = innerRadius(ring(100));
    expect(r50, lessThan(r0 - 4));
    expect(r100, lessThan(r50));
    expect(r100, greaterThan(15), reason: 'never over the solid body');
  });

  test('a hard-edged shape gets the same outline at any threshold', () {
    final rgba = Uint8List(n * n * 4);
    for (var y = 20; y < 60; y++) {
      for (var x = 20; x < 60; x++) {
        rgba.setAll((y * n + x) * 4, [0, 0, 255, 255]);
      }
    }
    Uint8List at(double e) => engine.applyOutlineLayer(
      rgba,
      n,
      n,
      color: 0xFF000000,
      widthPx: 3,
      erosion: e,
    );
    expect(at(80), orderedEquals(at(0)));
  });

  test('the preview shows the picture over its outline', () {
    final src = softDisc();
    final ringOnly = engine.applyOutlineLayer(
      src,
      n,
      n,
      color: 0xFF202020,
      widthPx: 4,
      erosion: 60,
    );
    final preview = engine.applyOutline(
      src,
      n,
      n,
      color: 0xFF202020,
      widthPx: 4,
      erosion: 60,
    );
    for (var i = 0; i < src.length; i += 4) {
      final keep = 255 - src[i + 3];
      for (var c = 0; c < 4; c++) {
        expect(
          preview[i + c],
          closeTo(src[i + c] + ringOnly[i + c] * keep / 255, 1),
        );
      }
    }
  });

  test('the filter saves the threshold and applies it', () {
    const filter = FilterDef(
      id: 'outline',
      name: 'Outline',
      kind: FilterKind.outline,
      outlineWidth: 4,
      outlineErosion: 50,
    );
    expect(FilterDef.fromJson(filter.toJson()).outlineErosion, 50);
    expect(
      applyDrawFilterInIsolate((softDisc(), n, n, filter, null)),
      orderedEquals(
        engine.applyOutlineLayer(
          softDisc(),
          n,
          n,
          color: filter.outlineColor,
          widthPx: 4,
          erosion: 50,
        ),
      ),
    );
  });
}
