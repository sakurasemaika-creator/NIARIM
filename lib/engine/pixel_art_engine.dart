import 'dart:math' as math;
import 'dart:typed_data';

import '../models/pixel_color_mode.dart';

/// Shared NIARIM pixel-art conversion contract.
///
/// With [squareBlocks] (filters, stamps) every cell of the grid becomes one
/// pixel-art pixel: it is either left fully transparent or filled whole with
/// a single colour and a single alpha, so blocks keep their square shape
/// instead of being cut along the source's anti-aliased edge, and no
/// semi-transparent fringe is left around the shape. Alpha is never
/// averaged. Without it (the brush's pixel mode, which already rasterises
/// one canvas pixel at a time) only the colours change and the source alpha
/// is kept exactly.
///
/// Pixels are premultiplied RGBA, as layers store them: colours are judged
/// unpremultiplied and written back premultiplied by the new alpha.
///
/// Horizontal/vertical internal boundaries stay hard. Diagonal opaque-color
/// boundaries may use a middle color only when the active color policy allows
/// it; callers can use the same converter for filters, brushes, and stamps.
class PixelArtEngine {
  const PixelArtEngine();

  Uint8List convert(
    Uint8List data,
    int width,
    int height, {
    int pixelSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
    bool squareBlocks = true,
  }) {
    final size = pixelSize.clamp(1, 64);
    final result = Uint8List.fromList(data);
    final cellsX = (width + size - 1) ~/ size;
    final cellsY = (height + size - 1) ~/ size;
    final cellCount = cellsX * cellsY;
    final rawColors = List<int?>.filled(cellCount, null);
    final alphaSum = Int32List(cellCount);
    final alphaMax = Uint8List(cellCount);
    final pixels = Int32List(cellCount);
    // How the paint inside each cell is laid out: 1 = along x (a flat
    // stroke), 2 = along y (an upright one), 0 = neither (a dot, a diagonal).
    final orientation = Uint8List(cellCount);

    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        var wr = 0, wg = 0, wb = 0, aw = 0, top = 0, n = 0;
        var sx = 0, sy = 0, sxx = 0, syy = 0;
        for (var dy = 0; dy < size && cy * size + dy < height; dy++) {
          for (var dx = 0; dx < size && cx * size + dx < width; dx++) {
            n++;
            final i = (((cy * size + dy) * width) + cx * size + dx) * 4;
            final a = data[i + 3];
            if (a == 0) continue;
            // Premultiplied channels are the colour already weighted by alpha.
            wr += data[i];
            wg += data[i + 1];
            wb += data[i + 2];
            aw += a;
            if (a > top) top = a;
            sx += dx * a;
            sy += dy * a;
            sxx += dx * dx * a;
            syy += dy * dy * a;
          }
        }
        final c = cy * cellsX + cx;
        pixels[c] = n;
        alphaSum[c] = aw;
        alphaMax[c] = top;
        if (aw == 0) continue;
        final mx = sx / aw, my = sy / aw;
        final varX = sxx / aw - mx * mx, varY = syy / aw - my * my;
        if (varX > 1.5 * varY + 0.01) {
          orientation[c] = 1;
        } else if (varY > 1.5 * varX + 0.01) {
          orientation[c] = 2;
        }
        rawColors[c] = _rgb(
          (wr * 255 / aw).round().clamp(0, 255),
          (wg * 255 / aw).round().clamp(0, 255),
          (wb * 255 / aw).round().clamp(0, 255),
        );
      }
    }

    final blockAlpha = squareBlocks
        ? _bridgeGaps(
            data,
            width,
            height,
            size,
            cellsX,
            cellsY,
            alphaMax,
            _blockAlphas(
              cellsX,
              cellsY,
              alphaSum,
              alphaMax,
              pixels,
              orientation,
            ),
          )
        : null;
    if (blockAlpha != null) {
      for (var c = 0; c < cellCount; c++) {
        if (blockAlpha[c] == 0) rawColors[c] = null;
      }
    }

    final countPalette = colorMode == PixelColorMode.count
        ? _buildCountPalette(rawColors.whereType<int>().toList(), colorLevels)
        : const <int>[];
    final colors = rawColors
        .map(
          (color) => color == null
              ? null
              : _constrainColor(color, colorMode, paletteColors, countPalette),
        )
        .toList();

    // Only a true diagonal A/B crossing is eligible for a middle color.
    // Transparency blocks smoothing. Horizontal/vertical A/B boundaries never
    // match this pattern, so they stay crisp.
    for (var cy = 0; cy + 1 < cellsY; cy++) {
      for (var cx = 0; cx + 1 < cellsX; cx++) {
        final tl = colors[cy * cellsX + cx];
        final tr = colors[cy * cellsX + cx + 1];
        final bl = colors[(cy + 1) * cellsX + cx];
        final br = colors[(cy + 1) * cellsX + cx + 1];
        if (tl == null || tr == null || bl == null || br == null) continue;
        if (tl == br && tr == bl && tl != tr) {
          final middle = _middleColor(
            tl,
            tr,
            colorMode,
            paletteColors,
            countPalette,
          );
          if (middle != null) colors[cy * cellsX + cx + 1] = middle;
        }
      }
    }

    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        final color = colors[c];
        if (color == null && blockAlpha == null) continue;
        final r = color == null ? 0 : (color >> 16) & 0xff;
        final g = color == null ? 0 : (color >> 8) & 0xff;
        final b = color == null ? 0 : color & 0xff;
        for (var dy = 0; dy < size && cy * size + dy < height; dy++) {
          for (var dx = 0; dx < size && cx * size + dx < width; dx++) {
            final i = (((cy * size + dy) * width) + cx * size + dx) * 4;
            // Colours only (no blocks): the source alpha is kept exactly.
            final a = blockAlpha == null ? data[i + 3] : blockAlpha[c];
            if (blockAlpha == null && a == 0) continue;
            result[i] = (r * a + 127) ~/ 255;
            result[i + 1] = (g * a + 127) ~/ 255;
            result[i + 2] = (b * a + 127) ~/ 255;
            result[i + 3] = a;
          }
        }
      }
    }
    return result;
  }

  /// Decides, for every cell, whether it becomes a pixel-art pixel and with
  /// which alpha (0 = left transparent).
  ///
  /// A cell's alpha is measured against the strongest alpha around it (its
  /// own and its eight neighbours'), so the anti-aliased fringe of a shape is
  /// told apart from the shape itself whatever opacity it was painted with:
  /// - a cell at least half filled at that strength is kept;
  /// - a thinner stroke is kept where it peaks across the stroke (a ridge,
  ///   looked for across the way the paint in the cell runs, so a line's end
  ///   doesn't count as a peak along it), so lines narrower than a block
  ///   don't vanish, but a sliver of fringe along the edge of a filled shape
  ///   doesn't add bumps to it;
  /// - a cell much fainter than its neighbours is kept only when it is an
  ///   even area of its own (lighter paint next to darker paint), never when
  ///   it is just the fade-out of an edge.
  /// A kept cell takes the strength around it, unless it is such an even
  /// area of clearly lighter paint, which keeps its own: so edges come out
  /// solid, lighter paint stays lighter, and alpha is never averaged.
  Uint8List _blockAlphas(
    int cellsX,
    int cellsY,
    Int32List alphaSum,
    Uint8List alphaMax,
    Int32List pixels,
    Uint8List orientation,
  ) {
    final count = cellsX * cellsY;
    final level = Uint8List(count);
    final coverage = Float64List(count);
    final even = List<bool>.filled(count, false);
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        var top = 0;
        for (var ny = cy - 1; ny <= cy + 1; ny++) {
          if (ny < 0 || ny >= cellsY) continue;
          for (var nx = cx - 1; nx <= cx + 1; nx++) {
            if (nx < 0 || nx >= cellsX) continue;
            final a = alphaMax[ny * cellsX + nx];
            if (a > top) top = a;
          }
        }
        level[c] = top;
        if (top > 0) coverage[c] = alphaSum[c] / (pixels[c] * top);
      }
    }
    // An even area: the cell is filled at its own strength, and so are most
    // of its neighbours (all but one, at most three, of those on the canvas).
    // The fade-out along an edge has at most the two cells along the edge.
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        final own = alphaMax[c];
        if (own == 0 || alphaSum[c] < 0.9 * pixels[c] * own) continue;
        var neighbours = 0, similar = 0;
        for (final (nx, ny) in [
          (cx - 1, cy),
          (cx + 1, cy),
          (cx, cy - 1),
          (cx, cy + 1),
        ]) {
          if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
          neighbours++;
          final a = alphaMax[ny * cellsX + nx];
          if (_similar(a, own)) similar++;
        }
        even[c] = neighbours >= 2 && similar >= math.min(3, neighbours - 1);
      }
    }

    double cov(int x, int y) => x < 0 || y < 0 || x >= cellsX || y >= cellsY
        ? 0
        : coverage[y * cellsX + x];
    bool solid(int x, int y) => cov(x, y) >= 0.5;
    // Peaks across the axis. Ties go to the later cell, so a stroke split
    // evenly between two rows of blocks stays one block thick.
    bool ridge(double before, double here, double after) =>
        here >= before && here > after;
    // The fringe along a filled shape (solid on one side, emptier outside),
    // or the gap between two shapes (solid on both sides). A line that does
    // cross such a gap is joined up again by [_bridgeGaps].
    bool fringe(
      bool solidBefore,
      double before,
      bool solidAfter,
      double after,
      double here,
    ) =>
        (solidBefore && solidAfter) ||
        (solidBefore && after < here) ||
        (solidAfter && before < here);

    final out = Uint8List(count);
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        final own = alphaMax[c];
        if (own == 0) continue;
        if (own * 2 < level[c]) {
          if (even[c]) out[c] = own;
          continue;
        }
        final here = coverage[c];
        var keep = here >= 0.5;
        if (!keep) {
          final l = cov(cx - 1, cy), r = cov(cx + 1, cy);
          final u = cov(cx, cy - 1), d = cov(cx, cy + 1);
          final edgeX = fringe(
            solid(cx - 1, cy),
            l,
            solid(cx + 1, cy),
            r,
            here,
          );
          final edgeY = fringe(
            solid(cx, cy - 1),
            u,
            solid(cx, cy + 1),
            d,
            here,
          );
          final across = orientation[c];
          keep =
              (across != 2 && ridge(u, here, d) && !edgeX) ||
              (across != 1 && ridge(l, here, r) && !edgeY);
        }
        if (!keep) continue;
        out[c] = !_similar(own, level[c]) && even[c] ? own : level[c];
      }
    }
    return out;
  }

  static const _ring = [
    (0, -1),
    (1, -1),
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
  ];

  /// Keeps a skipped cell when the paint inside it joins kept cells that
  /// would otherwise not touch: a thin line running into a filled shape
  /// passes through the shape's soft rim, which on its own isn't kept, and
  /// the line would stop one block short of the shape. A gap that is really
  /// there (two shapes whose rims don't meet inside the cell) stays open.
  Uint8List _bridgeGaps(
    Uint8List data,
    int width,
    int height,
    int size,
    int cellsX,
    int cellsY,
    Uint8List alphaMax,
    Uint8List kept,
  ) {
    if (size < 2) return kept;
    for (var pass = 0; pass < 2; pass++) {
      final bridges = <int, int>{};
      for (var cy = 0; cy < cellsY; cy++) {
        for (var cx = 0; cx < cellsX; cx++) {
          final c = cy * cellsX + cx;
          if (kept[c] != 0 || alphaMax[c] == 0) continue;
          // Kept neighbours, grouped by whether they touch each other.
          final group = List<int>.filled(8, -1);
          var groups = 0;
          for (var k = 0; k < 8; k++) {
            final (ox, oy) = _ring[k];
            final nx = cx + ox, ny = cy + oy;
            if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
            if (kept[ny * cellsX + nx] == 0) continue;
            group[k] = groups++;
          }
          if (groups < 2) continue;
          for (var changed = true; changed;) {
            changed = false;
            for (var a = 0; a < 8; a++) {
              for (var b = 0; b < 8; b++) {
                if (group[a] < 0 || group[b] < 0 || group[a] == group[b]) {
                  continue;
                }
                final (ax, ay) = _ring[a];
                final (bx, by) = _ring[b];
                if ((ax - bx).abs() > 1 || (ay - by).abs() > 1) continue;
                final from = math.max(group[a], group[b]);
                final to = math.min(group[a], group[b]);
                for (var k = 0; k < 8; k++) {
                  if (group[k] == from) group[k] = to;
                }
                changed = true;
              }
            }
          }
          if (group.where((g) => g >= 0).toSet().length < 2) continue;
          final level = _strongestAround(kept, cellsX, cellsY, cx, cy);
          if (alphaMax[c] * 2 < level) continue;
          if (_paintJoins(data, width, height, size, cx, cy, level, group)) {
            bridges[c] = level;
          }
        }
      }
      if (bridges.isEmpty) break;
      bridges.forEach((c, a) => kept[c] = a);
    }
    return kept;
  }

  static int _strongestAround(
    Uint8List kept,
    int cellsX,
    int cellsY,
    int cx,
    int cy,
  ) {
    var top = 0;
    for (final (ox, oy) in _ring) {
      final nx = cx + ox, ny = cy + oy;
      if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
      top = math.max(top, kept[ny * cellsX + nx]);
    }
    return top;
  }

  /// Whether one connected patch of solid paint inside the cell reaches the
  /// sides (or, for a diagonal neighbour, the corner) facing two different
  /// groups of kept neighbours.
  static bool _paintJoins(
    Uint8List data,
    int width,
    int height,
    int size,
    int cx,
    int cy,
    int level,
    List<int> group,
  ) {
    final x0 = cx * size, y0 = cy * size;
    final w = math.min(size, width - x0), h = math.min(size, height - y0);
    // A diagonal neighbour is reached through the half of each side nearer
    // to it.
    final corner = math.max(1, (size + 1) ~/ 2);
    final seen = Uint8List(w * h);
    final stack = <int>[];
    for (var start = 0; start < w * h; start++) {
      if (seen[start] != 0) continue;
      final sx = start % w, sy = start ~/ w;
      if (data[((y0 + sy) * width + x0 + sx) * 4 + 3] * 2 < level) continue;
      final reached = <int>{};
      seen[start] = 1;
      stack.add(start);
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final px = p % w, py = p ~/ w;
        for (var k = 0; k < 8; k++) {
          if (group[k] < 0) continue;
          final (ox, oy) = _ring[k];
          final onX = ox < 0 ? px == 0 : (ox > 0 ? px == w - 1 : true);
          final onY = oy < 0 ? py == 0 : (oy > 0 ? py == h - 1 : true);
          final touches = ox != 0 && oy != 0
              ? (onX && _near(py, oy, h, corner)) ||
                    (onY && _near(px, ox, w, corner))
              : onX && onY;
          if (touches) reached.add(group[k]);
        }
        if (reached.length >= 2) return true;
        for (var ny = py - 1; ny <= py + 1; ny++) {
          for (var nx = px - 1; nx <= px + 1; nx++) {
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            final q = ny * w + nx;
            if (seen[q] != 0) continue;
            if (data[((y0 + ny) * width + x0 + nx) * 4 + 3] * 2 < level) {
              continue;
            }
            seen[q] = 1;
            stack.add(q);
          }
        }
      }
    }
    return false;
  }

  /// Whether [v] lies within [corner] of the end of a side of length [n]
  /// that faces direction [o] (-1: the start, 1: the end).
  static bool _near(int v, int o, int n, int corner) =>
      o < 0 ? v < corner : v >= n - corner;

  /// Alphas within a fifth of each other count as the same strength.
  static bool _similar(int a, int b) => a * 5 >= b * 4 && a * 4 <= b * 5;

  int _constrainColor(
    int color,
    PixelColorMode mode,
    List<int> explicitPalette,
    List<int> countPalette,
  ) {
    if (mode == PixelColorMode.count && countPalette.isNotEmpty) {
      return _nearestColor(color, countPalette);
    }
    if ((mode == PixelColorMode.explicit || mode == PixelColorMode.palette) &&
        explicitPalette.isNotEmpty) {
      return _nearestColor(color, explicitPalette);
    }
    return color;
  }

  int? _middleColor(
    int a,
    int b,
    PixelColorMode mode,
    List<int> explicitPalette,
    List<int> countPalette,
  ) {
    final middle = _rgb(
      ((((a >> 16) & 0xff) + ((b >> 16) & 0xff)) / 2).round(),
      ((((a >> 8) & 0xff) + ((b >> 8) & 0xff)) / 2).round(),
      (((a & 0xff) + (b & 0xff)) / 2).round(),
    );
    if (mode == PixelColorMode.count) {
      if (countPalette.isEmpty) return null;
      final candidate = _nearestColor(middle, countPalette);
      return candidate == a || candidate == b ? null : candidate;
    }
    if (mode == PixelColorMode.explicit || mode == PixelColorMode.palette) {
      if (explicitPalette.isEmpty) return null;
      final candidate = _nearestColor(middle, explicitPalette);
      return candidate == a || candidate == b ? null : candidate;
    }
    return middle;
  }

  List<int> _buildCountPalette(List<int> colors, int requestedCount) {
    if (colors.isEmpty) return const [];
    final unique = colors.toSet().toList()..sort();
    final count = requestedCount.clamp(1, 256);
    if (unique.length <= count) return unique;

    final palette = <int>[unique.first];
    while (palette.length < count) {
      var best = unique.first;
      var bestDistance = -1;
      for (final color in unique) {
        var nearestDistance = 1 << 30;
        for (final chosen in palette) {
          final d = _distance(color, chosen);
          if (d < nearestDistance) nearestDistance = d;
        }
        if (nearestDistance > bestDistance) {
          bestDistance = nearestDistance;
          best = color;
        }
      }
      if (palette.contains(best)) break;
      palette.add(best);
    }
    return palette;
  }

  int _nearestColor(int color, List<int> palette) {
    var best = palette.first;
    var bestDistance = 1 << 30;
    for (final candidate in palette) {
      final d = _distance(color, candidate);
      if (d < bestDistance) {
        bestDistance = d;
        best = candidate;
      }
    }
    return _rgb((best >> 16) & 0xff, (best >> 8) & 0xff, best & 0xff);
  }

  int _distance(int a, int b) {
    final dr = ((a >> 16) & 0xff) - ((b >> 16) & 0xff);
    final dg = ((a >> 8) & 0xff) - ((b >> 8) & 0xff);
    final db = (a & 0xff) - (b & 0xff);
    return dr * dr + dg * dg + db * db;
  }

  int _rgb(int r, int g, int b) =>
      0xff000000 | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);
}
