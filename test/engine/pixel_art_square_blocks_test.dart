import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/pixel_color_mode.dart';

/// Pixel art turns each block of the grid into one pixel-art pixel: kept
/// blocks stay whole squares (they are not cut along the anti-aliased edge of
/// what was drawn), nothing semi-transparent is left around the shape, thin
/// lines don't vanish, and the colours obey the chosen colour rule.
void main() {
  const engine = PixelArtEngine();

  /// Anti-aliased coverage (0..1) of a pixel whose centre is [d] pixels
  /// inside the edge of a shape.
  double aa(double d) => (d + 0.5).clamp(0.0, 1.0);

  void paint(
    Uint8List rgba,
    int w,
    int h,
    double Function(double x, double y) inside,
    List<int> rgb, {
    int alpha = 255,
  }) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final a = (aa(inside(x + 0.5, y + 0.5)) * alpha).round();
        final i = (y * w + x) * 4;
        if (a <= rgba[i + 3]) continue;
        // Layers hold premultiplied RGBA.
        rgba[i] = (rgb[0] * a / 255).round();
        rgba[i + 1] = (rgb[1] * a / 255).round();
        rgba[i + 2] = (rgb[2] * a / 255).round();
        rgba[i + 3] = a;
      }
    }
  }

  double Function(double, double) disc(double cx, double cy, double r) =>
      (x, y) => r - math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));

  double Function(double, double) segment(
    double x0,
    double y0,
    double x1,
    double y1,
    double halfWidth,
  ) => (x, y) {
    final dx = x1 - x0, dy = y1 - y0;
    final t = (((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)).clamp(
      0.0,
      1.0,
    );
    final px = x0 + dx * t, py = y0 + dy * t;
    return halfWidth - math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
  };

  /// The alpha of each block, after checking every block is one flat colour.
  List<List<int>> blocks(Uint8List out, int w, int h, int size) {
    final rows = <List<int>>[];
    for (var cy = 0; cy * size < h; cy++) {
      final row = <int>[];
      for (var cx = 0; cx * size < w; cx++) {
        final first = ((cy * size) * w + cx * size) * 4;
        for (var y = cy * size; y < math.min(h, (cy + 1) * size); y++) {
          for (var x = cx * size; x < math.min(w, (cx + 1) * size); x++) {
            final i = (y * w + x) * 4;
            expect(
              out.sublist(i, i + 4),
              out.sublist(first, first + 4),
              reason: 'block ($cx, $cy) is one flat square',
            );
          }
        }
        row.add(out[first + 3]);
      }
      rows.add(row);
    }
    return rows;
  }

  Set<int> alphas(Uint8List out) => {
    for (var i = 3; i < out.length; i += 4) out[i],
  };

  void expectContiguous(List<int> line, String reason) {
    final kept = [
      for (var i = 0; i < line.length; i++)
        if (line[i] != 0) i,
    ];
    if (kept.isEmpty) return;
    expect(kept.last - kept.first + 1, kept.length, reason: reason);
  }

  test('an anti-aliased disc becomes whole opaque blocks with no fringe or '
      'bumps', () {
    const w = 96, h = 96, size = 8;
    final rgba = Uint8List(w * h * 4);
    paint(rgba, w, h, disc(48, 48, 30), [20, 30, 40]);
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    final grid = blocks(out, w, h, size);
    expect(alphas(out), {0, 255});
    for (var cy = 0; cy < grid.length; cy++) {
      expectContiguous(grid[cy], 'row $cy is one run');
    }
    for (var cx = 0; cx < grid.first.length; cx++) {
      expectContiguous([for (final r in grid) r[cx]], 'column $cx is one run');
    }
    // The disc is symmetric about the grid line through its centre.
    for (var cy = 0; cy < grid.length; cy++) {
      for (var cx = 0; cx < grid[cy].length; cx++) {
        expect(grid[cy][cx], grid[cy][grid[cy].length - 1 - cx]);
        expect(grid[cy][cx], grid[grid.length - 1 - cy][cx]);
      }
    }
    final kept = grid.expand((r) => r).where((a) => a != 0).length;
    final area = math.pi * 30 * 30 / (size * size);
    expect(kept, closeTo(area, area * 0.15));
  });

  test('a thin diagonal line stays a connected staircase one block wide', () {
    const w = 128, h = 128, size = 8;
    final rgba = Uint8List(w * h * 4);
    paint(rgba, w, h, segment(6, 6, 122, 122, 1), [0, 0, 0]);
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    final grid = blocks(out, w, h, size);
    expect(alphas(out), {0, 255});
    for (var i = 0; i < grid.length; i++) {
      expect(grid[i][i], 255, reason: 'the line runs through block ($i, $i)');
      final kept = grid[i].where((a) => a != 0).length;
      expect(kept, 1, reason: 'one block per row on a 45-degree line');
    }
  });

  test('a thin shallow line is kept and stays connected', () {
    const w = 160, h = 64, size = 8;
    final rgba = Uint8List(w * h * 4);
    paint(rgba, w, h, segment(4, 10, 156, 52, 1.2), [200, 30, 40]);
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    final grid = blocks(out, w, h, size);
    final columns = grid.first.length;
    int? previous;
    for (var cx = 0; cx < columns; cx++) {
      final kept = [
        for (var cy = 0; cy < grid.length; cy++)
          if (grid[cy][cx] != 0) cy,
      ];
      expect(kept, isNotEmpty, reason: 'column $cx keeps the line');
      expect(kept.length, lessThanOrEqualTo(2));
      if (previous != null) {
        expect(
          (kept.first - previous).abs(),
          lessThanOrEqualTo(1),
          reason: 'columns ${cx - 1} and $cx touch',
        );
      }
      previous = kept.last;
    }
  });

  test('a thin line split evenly between two rows of blocks stays one block '
      'thick', () {
    const w = 64, h = 32, size = 8;
    final rgba = Uint8List(w * h * 4);
    // Covers pixel rows 15 and 16: one in each row of blocks.
    paint(rgba, w, h, segment(-8, 16, 72, 16, 1), [0, 0, 0]);
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    final grid = blocks(out, w, h, size);
    for (var cx = 0; cx < grid.first.length; cx++) {
      expect(
        [for (final r in grid) r[cx]].where((a) => a != 0).length,
        1,
        reason: 'column $cx',
      );
    }
  });

  test(
    'a split line that ends inside the canvas grows no hook at its ends',
    () {
      const n = 64, size = 8;
      for (final upright in [false, true]) {
        final rgba = Uint8List(n * n * 4);
        paint(
          rgba,
          n,
          n,
          upright ? segment(16, 11, 16, 53, 1) : segment(11, 16, 53, 16, 1),
          [0, 0, 0],
        );
        final out = engine.convert(
          rgba,
          n,
          n,
          pixelSize: size,
          colorMode: PixelColorMode.none,
        );
        final grid = blocks(out, n, n, size);
        for (var i = 0; i < n ~/ size; i++) {
          final across = upright ? grid[i] : [for (final row in grid) row[i]];
          expect(
            across.where((a) => a != 0).length,
            lessThanOrEqualTo(1),
            reason: '${upright ? 'row' : 'column'} $i',
          );
        }
        expect(
          alphas(out).length,
          2,
          reason: 'the line is kept (upright: $upright)',
        );
      }
    },
  );

  /// The kept blocks, split into 8-connected groups.
  int blockGroups(List<List<int>> grid) {
    final seen = <(int, int)>{};
    var groups = 0;
    for (var y = 0; y < grid.length; y++) {
      for (var x = 0; x < grid[y].length; x++) {
        if (grid[y][x] == 0 || seen.contains((x, y))) continue;
        groups++;
        final stack = [(x, y)];
        seen.add((x, y));
        while (stack.isNotEmpty) {
          final (px, py) = stack.removeLast();
          for (var ny = py - 1; ny <= py + 1; ny++) {
            for (var nx = px - 1; nx <= px + 1; nx++) {
              if (ny < 0 || nx < 0 || ny >= grid.length) continue;
              if (nx >= grid[ny].length || grid[ny][nx] == 0) continue;
              if (seen.add((nx, ny))) stack.add((nx, ny));
            }
          }
        }
      }
    }
    return groups;
  }

  test('a thin line running into a filled shape stays joined to it', () {
    const n = 128, size = 8;
    // Lines meeting the disc at several angles.
    for (final (x, y) in [(4.0, 124.0), (20.0, 120.0), (6.0, 90.0)]) {
      final rgba = Uint8List(n * n * 4);
      paint(rgba, n, n, disc(80, 52, 26), [40, 180, 60]);
      paint(rgba, n, n, segment(x, y, 70, 60, 1), [0, 0, 0]);
      final out = engine.convert(
        rgba,
        n,
        n,
        pixelSize: size,
        colorMode: PixelColorMode.none,
      );
      expect(
        blockGroups(blocks(out, n, n, size)),
        1,
        reason: 'line from ($x, $y)',
      );
    }
  });

  test('a real gap between two shapes stays open', () {
    const n = 96, size = 8;
    final rgba = Uint8List(n * n * 4);
    // Both discs' rims fall in the same column of blocks (x 40-47), 5px
    // apart: the blocks on either side are kept, the column between them
    // holds paint from both, but that paint doesn't join.
    paint(rgba, n, n, disc(22, 48, 19), [200, 40, 40]);
    paint(rgba, n, n, disc(66.5, 48, 20), [40, 40, 200]);
    final out = engine.convert(
      rgba,
      n,
      n,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    expect(blockGroups(blocks(out, n, n, size)), 2);
  });

  test('uniform semi-transparent paint keeps its opacity with a hard edge', () {
    const w = 96, h = 96, size = 8;
    final rgba = Uint8List(w * h * 4);
    paint(rgba, w, h, disc(48, 48, 30), [40, 90, 200], alpha: 128);
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    blocks(out, w, h, size);
    expect(alphas(out), {0, 128});
  });

  test('lighter paint next to a solid line keeps its own opacity and leaves '
      'no gap', () {
    const w = 64, h = 32, size = 8;
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final line = x < 16;
        rgba.setAll(i, line ? [0, 0, 0, 255] : [24, 47, 86, 100]);
      }
    }
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: size,
      colorMode: PixelColorMode.none,
    );
    final grid = blocks(out, w, h, size);
    for (final row in grid) {
      expect(row, [255, 255, 100, 100, 100, 100, 100, 100]);
    }
  });

  test('matching the canvas resolution hardens the anti-aliased edge pixel by '
      'pixel', () {
    const w = 64, h = 64;
    final rgba = Uint8List(w * h * 4);
    paint(rgba, w, h, disc(32, 32, 20), [0, 0, 0]);
    final out = engine.convert(
      rgba,
      w,
      h,
      pixelSize: 1,
      colorMode: PixelColorMode.none,
    );
    expect(alphas(out), {0, 255});
    final kept = [
      for (var i = 3; i < out.length; i += 4) out[i],
    ].where((a) => a != 0).length;
    expect(kept, closeTo(math.pi * 20 * 20, 2 * math.pi * 20 * 0.5));
  });

  group('six-colour fixture (black, white, red, yellow, blue, green)', () {
    const w = 96, h = 64, size = 8;
    const palette = [
      0xFF000000,
      0xFFFFFFFF,
      0xFFFF0000,
      0xFFFFFF00,
      0xFF0000FF,
      0xFF00FF00,
    ];
    // Six slightly-off bands under an anti-aliased diagonal edge, so every
    // colour meets transparency along a slanted, soft edge.
    Uint8List fixture() {
      final rgba = Uint8List(w * h * 4);
      const bands = [
        [24, 20, 28],
        [236, 232, 240],
        [222, 34, 40],
        [232, 220, 36],
        [30, 40, 214],
        [42, 200, 52],
      ];
      for (var b = 0; b < bands.length; b++) {
        paint(rgba, w, h, (x, y) {
          final inBand = math.min(x - b * 16, (b + 1) * 16 - x);
          final belowEdge = (y - (h - x * 0.45)) / math.sqrt(1 + 0.45 * 0.45);
          return math.min(inBand + 0.5, belowEdge);
        }, bands[b]);
      }
      return rgba;
    }

    test('specified colours: only the six colours, opaque square blocks', () {
      final out = engine.convert(
        fixture(),
        w,
        h,
        pixelSize: size,
        colorMode: PixelColorMode.explicit,
        paletteColors: palette,
      );
      blocks(out, w, h, size);
      expect(alphas(out), {0, 255});
      final used = <int>{};
      for (var i = 0; i < out.length; i += 4) {
        if (out[i + 3] == 0) continue;
        used.add(0xFF000000 | (out[i] << 16) | (out[i + 1] << 8) | out[i + 2]);
      }
      expect(palette.toSet().containsAll(used), isTrue);
      expect(used, hasLength(6), reason: 'every band survives');
    });

    test('a one-colour palette still leaves no semi-transparent outline', () {
      final out = engine.convert(
        fixture(),
        w,
        h,
        pixelSize: size,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [0xFF000000],
      );
      expect(alphas(out), {0, 255});
    });

    test('colour count: at most the requested number of colours', () {
      for (final count in [2, 3, 6]) {
        final out = engine.convert(
          fixture(),
          w,
          h,
          pixelSize: size,
          colorMode: PixelColorMode.count,
          colorLevels: count,
        );
        final used = <int>{};
        for (var i = 0; i < out.length; i += 4) {
          if (out[i + 3] == 0) continue;
          used.add((out[i] << 16) | (out[i + 1] << 8) | out[i + 2]);
        }
        expect(used.length, lessThanOrEqualTo(count));
        expect(alphas(out), {0, 255});
      }
    });

    test('Pixel Art and Mosaic are different effects on the same fixture', () {
      final input = fixture();
      final pixelArt = FilterEngine().applyPixelate(
        input,
        w,
        h,
        mosaicSize: size,
        colorMode: PixelColorMode.none,
      );
      final mosaic = FilterEngine().applyMosaic(input, w, h, size);
      expect(pixelArt, isNot(orderedEquals(mosaic)));
      expect(alphas(pixelArt), {0, 255});
      expect(
        alphas(mosaic).where((a) => a != 0 && a != 255),
        isNotEmpty,
        reason: 'mosaic averages alpha along the soft edge',
      );
    });
  });

  test('the brush pixel mode only recolours and keeps the drawn alpha', () {
    // Premultiplied: the same red at full, 90 and 180 alpha.
    final rgba = Uint8List.fromList([
      200, 10, 10, 255, 71, 4, 4, 90, //
      0, 0, 0, 0, 141, 7, 7, 180,
    ]);
    final out = engine.convert(
      rgba,
      2,
      2,
      pixelSize: 1,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xFF0000FF],
      squareBlocks: false,
    );
    expect([out[3], out[7], out[11], out[15]], [255, 90, 0, 180]);
    expect(out.sublist(0, 3), [0, 0, 255]);
    expect(out.sublist(4, 7), [0, 0, 90], reason: 'blue, premultiplied');
    expect(out.sublist(12, 15), [0, 0, 180]);
  });

  test('colours are judged unpremultiplied: a soft edge keeps its hue', () {
    // A yellow disc with an anti-aliased rim: the rim's premultiplied
    // channels are darker, but it is the same yellow.
    const n = 48;
    final rgba = Uint8List(n * n * 4);
    paint(rgba, n, n, disc(24, 24, 15), [255, 220, 0]);
    for (final size in [1, 8]) {
      final out = engine.convert(
        rgba,
        n,
        n,
        pixelSize: size,
        colorMode: PixelColorMode.none,
      );
      for (var i = 0; i < out.length; i += 4) {
        if (out[i + 3] == 0) continue;
        expect(out[i + 3], 255);
        // Premultiplied rounding leaves at most one step either way.
        expect(out[i], closeTo(255, 1), reason: 'size $size');
        expect(out[i + 1], closeTo(220, 1), reason: 'size $size');
        expect(out[i + 2], closeTo(0, 1), reason: 'size $size');
      }
    }
    final palette = engine.convert(
      rgba,
      n,
      n,
      pixelSize: 1,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xFF000000, 0xFFFF0000, 0xFFFFFF00],
    );
    for (var i = 0; i < palette.length; i += 4) {
      if (palette[i + 3] == 0) continue;
      expect(palette.sublist(i, i + 3), [255, 255, 0], reason: 'no red rim');
    }
  });

  group('"Match canvas resolution" mode', () {
    const filter = FilterDef(
      id: 'pixel-canvas',
      name: 'Pixel art',
      kind: FilterKind.pixelate,
      strength: 12,
      pixelColorMode: PixelColorMode.none,
      pixelArtMatchCanvas: true,
    );

    test('is saved and restored with the filter', () {
      final restored = FilterDef.fromJson(filter.toJson());
      expect(restored.pixelArtMatchCanvas, isTrue);
      expect(restored.strength, 12, reason: 'the block size is kept for later');
      expect(restored.pixelArtBlockSize, 1);
      expect(
        FilterDef.fromJson(
          filter.copyWith(pixelArtMatchCanvas: false).toJson(),
        ).pixelArtBlockSize,
        12,
      );
    });

    test('applies one dot per canvas pixel', () {
      const w = 48, h = 48;
      final rgba = Uint8List(w * h * 4);
      paint(rgba, w, h, disc(24, 24, 15), [10, 10, 10]);
      final applied = applyDrawFilterInIsolate((rgba, w, h, filter, null));
      expect(
        applied,
        orderedEquals(
          engine.convert(
            rgba,
            w,
            h,
            pixelSize: 1,
            colorMode: PixelColorMode.none,
          ),
        ),
      );
      expect(alphas(applied), {0, 255});
    });
  });
}
