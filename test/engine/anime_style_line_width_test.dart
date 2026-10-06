import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// Anime style darkens outlines without thickening the drawing's lines at a
/// line thickening of 0, and thickens them by about that many pixels a side
/// when it is raised.
void main() {
  final engine = FilterEngine();
  const w = 48, h = 16;

  /// A light background with a 3px dark upright line at x 20 - 22.
  Uint8List line() {
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = x >= 20 && x <= 22 ? 40 : 230;
        rgba.setAll((y * w + x) * 4, [v, v, v, 255]);
      }
    }
    return rgba;
  }

  /// How many pixels across the middle row are dark.
  int darkWidth(Uint8List rgba) => [
    for (var x = 0; x < w; x++) rgba[(8 * w + x) * 4 + 1],
  ].where((v) => v < 128).length;

  Uint8List anime(double lineWidth) => engine.applyAnimeStyle(
    line(),
    w,
    h,
    strength: 100,
    colorCount: 32,
    edgeStrength: 1,
    lineWidth: lineWidth,
  );

  test('at 0 the line keeps its width', () {
    expect(darkWidth(line()), 3);
    expect(darkWidth(anime(0)), 3);
  });

  test('raising it thickens the line on both sides', () {
    expect(darkWidth(anime(2)), greaterThanOrEqualTo(7));
    expect(darkWidth(anime(4)), greaterThanOrEqualTo(11));
    expect(darkWidth(anime(4)), greaterThan(darkWidth(anime(2))));
  });

  test('the filter saves its line thickening and applies it', () {
    const filter = FilterDef(
      id: 'anime',
      name: 'Anime',
      kind: FilterKind.animeStyle,
      colorLevels: 32,
      edgeStrength: 1,
      animeLineWidth: 3,
    );
    expect(FilterDef.fromJson(filter.toJson()).animeLineWidth, 3);
    expect(
      const FilterDef(
        id: 'a',
        name: 'a',
        kind: FilterKind.animeStyle,
      ).animeLineWidth,
      0,
    );
    final applied = applyDrawFilterInIsolate((line(), w, h, filter, null));
    expect(
      applied,
      orderedEquals(
        engine.applyAnimeStyle(
          line(),
          w,
          h,
          strength: filter.strength,
          colorCount: 32,
          edgeStrength: 1,
          lineWidth: 3,
        ),
      ),
    );
    expect(darkWidth(applied), greaterThan(3));
  });
}
