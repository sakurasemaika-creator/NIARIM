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
/// [pixelSize] is the size of a dot in canvas pixels and may be fractional,
/// so a picture can be split into an exact number of dots (100 dots across
/// 1920 pixels makes dots 19 or 20 pixels wide).
///
/// Pixels are premultiplied RGBA, as layers store them: colours are judged
/// unpremultiplied and written back premultiplied by the new alpha.
///
/// Horizontal/vertical internal boundaries stay hard. Diagonal opaque-color
/// boundaries may use a middle color only when the active color policy allows
/// it; callers can use the same converter for filters, brushes, and stamps.
///
/// With [dither] and a limited set of colours, a dot whose colour no single
/// colour of the set comes close to is made of up to three of them that,
/// side by side, look nearest to it, in a fixed 4 x 4 pattern (ordered
/// dithering, which stays put from one animation frame to the next). A dot
/// a colour of the set already matches well stays that one colour.
class PixelArtEngine {
  const PixelArtEngine();

  Uint8List convert(
    Uint8List data,
    int width,
    int height, {
    num pixelSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
    bool squareBlocks = true,
    bool dither = false,
  }) {
    final size = pixelSize.toDouble().clamp(
      1.0,
      math.max(1, math.max(width, height)).toDouble(),
    );
    final result = Uint8List.fromList(data);
    final xs = cellEdges(width, size);
    final ys = cellEdges(height, size);
    final cellsX = xs.length - 1;
    final cellsY = ys.length - 1;
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
        for (var dy = 0; dy < ys[cy + 1] - ys[cy]; dy++) {
          for (var dx = 0; dx < xs[cx + 1] - xs[cx]; dx++) {
            n++;
            final i = (((ys[cy] + dy) * width) + xs[cx] + dx) * 4;
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
            size,
            xs,
            ys,
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
    final limited = switch (colorMode) {
      PixelColorMode.count => countPalette,
      PixelColorMode.explicit || PixelColorMode.palette => paletteColors,
      PixelColorMode.none => const <int>[],
    };
    // Dots whose colour is a mix of two (dithered): left out of the diagonal
    // smoothing below, whose pattern a dither is full of.
    final mixed = Uint8List(cellCount);
    final List<int?> colors;
    if (dither && limited.length >= 2) {
      final ditherer = _Ditherer(limited);
      colors = List<int?>.filled(cellCount, null);
      final labs = Float64List(cellCount * 3);
      for (var c = 0; c < cellCount; c++) {
        final color = rawColors[c];
        if (color == null) continue;
        labs.setAll(c * 3, _Ditherer.labOf(color));
      }
      final edge = Uint8List(cellCount);
      for (var c = 0; c < cellCount; c++) {
        if (rawColors[c] != null &&
            _onEdge(rawColors, labs, cellsX, cellsY, c)) {
          edge[c] = 1;
        }
      }
      for (var c = 0; c < cellCount; c++) {
        var color = rawColors[c];
        if (color == null) continue;
        // A dot on a hard edge between two colours (often a blend of both)
        // takes the colour of its most alike neighbour off the edge, so the
        // pattern runs right up to the edge and no dots of some third colour
        // are scattered along it. A thin line, with no such neighbour, is
        // one colour.
        if (edge[c] != 0) {
          final like = _mostAlikeInside(
            rawColors,
            labs,
            edge,
            cellsX,
            cellsY,
            c,
          );
          if (like == null) {
            colors[c] = ditherer.nearest(color);
            continue;
          }
          color = like;
        }
        final plan = ditherer.planFor(color);
        if (plan.first == plan.last) {
          colors[c] = plan.first;
          continue;
        }
        mixed[c] = 1;
        final cx = c % cellsX, cy = c ~/ cellsX;
        colors[c] = plan[_bayer[(cy & 3) * 4 + (cx & 3)]];
      }
    } else {
      colors = rawColors
          .map(
            (color) => color == null
                ? null
                : _constrainColor(
                    color,
                    colorMode,
                    paletteColors,
                    countPalette,
                  ),
          )
          .toList();
    }

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
        if (mixed[cy * cellsX + cx] != 0 ||
            mixed[cy * cellsX + cx + 1] != 0 ||
            mixed[(cy + 1) * cellsX + cx] != 0 ||
            mixed[(cy + 1) * cellsX + cx + 1] != 0) {
          continue;
        }
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
        for (var y = ys[cy]; y < ys[cy + 1]; y++) {
          for (var x = xs[cx]; x < xs[cx + 1]; x++) {
            final i = (y * width + x) * 4;
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

  /// Where the cells of a [length]-pixel side start, plus [length] itself:
  /// cells [size] pixels long (rounded down where [size] is fractional).
  static List<int> cellEdges(int length, double size) {
    // The small margin keeps an exact division (1920 / 100 dots) from
    // gaining a sliver of an extra cell to rounding.
    final count = math.max(1, (length / size - 1e-9).ceil());
    return [for (var i = 0; i < count; i++) (i * size).floor(), length];
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
    double size,
    List<int> xs,
    List<int> ys,
    Uint8List alphaMax,
    Uint8List kept,
  ) {
    if (size < 2) return kept;
    final cellsX = xs.length - 1, cellsY = ys.length - 1;
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
          if (_paintJoins(data, width, xs, ys, cx, cy, level, group)) {
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
    List<int> xs,
    List<int> ys,
    int cx,
    int cy,
    int level,
    List<int> group,
  ) {
    final x0 = xs[cx], y0 = ys[cy];
    final w = xs[cx + 1] - x0, h = ys[cy + 1] - y0;
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
              ? (onX && _near(py, oy, h)) || (onY && _near(px, ox, w))
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

  /// Whether [v] lies in the half of a side of length [n] nearer the end it
  /// faces ([o] -1: the start, 1: the end): a diagonal neighbour is reached
  /// through that half of each side.
  static bool _near(int v, int o, int n) {
    final half = math.max(1, (n + 1) ~/ 2);
    return o < 0 ? v < half : v >= n - half;
  }

  /// How different dots [a] and [b] look: the squared CIELAB distance, from
  /// [labs] (three per dot).
  static double _apart(Float64List labs, int a, int b) {
    final dl = labs[a * 3] - labs[b * 3],
        da = labs[a * 3 + 1] - labs[b * 3 + 1],
        db = labs[a * 3 + 2] - labs[b * 3 + 2];
    return dl * dl + da * da + db * db;
  }

  /// Whether dot [c] differs sharply in colour from a side neighbour (more
  /// than [_edge] apart in CIELAB); transparent neighbours do not count.
  static bool _onEdge(
    List<int?> colors,
    Float64List labs,
    int cellsX,
    int cellsY,
    int c,
  ) {
    final cx = c % cellsX, cy = c ~/ cellsX;
    for (final (nx, ny) in [
      (cx - 1, cy),
      (cx + 1, cy),
      (cx, cy - 1),
      (cx, cy + 1),
    ]) {
      if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
      final n = ny * cellsX + nx;
      if (colors[n] == null) continue;
      if (_apart(labs, c, n) > _edge * _edge) return true;
    }
    return false;
  }

  /// The colour of the side neighbour of dot [c] that is not itself on an
  /// edge and looks most like it, if there is one.
  static int? _mostAlikeInside(
    List<int?> colors,
    Float64List labs,
    Uint8List edge,
    int cellsX,
    int cellsY,
    int c,
  ) {
    final cx = c % cellsX, cy = c ~/ cellsX;
    int? best;
    var bestDistance = double.infinity;
    for (final (nx, ny) in [
      (cx - 1, cy),
      (cx + 1, cy),
      (cx, cy - 1),
      (cx, cy + 1),
    ]) {
      if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
      final n = ny * cellsX + nx;
      final other = colors[n];
      if (other == null || edge[n] != 0) continue;
      final d = _apart(labs, c, n);
      if (d < bestDistance) {
        bestDistance = d;
        best = other;
      }
    }
    return best;
  }

  /// How different neighbouring dots must look to make an edge.
  static const double _edge = 20;

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

  /// The [requestedCount] colours that best stand for [colors] (one entry
  /// per dot): spread out first (each next one the colour furthest from
  /// those chosen, starting from the commonest), then each moved to the
  /// middle of the dots nearest it, weighted by how many there are (k-means,
  /// by how different the colours look), and finally to the real colour of
  /// those dots nearest that middle. Picking the most different colours alone
  /// left a large area of a middle colour (a face) to the nearest extreme.
  List<int> _buildCountPalette(List<int> colors, int requestedCount) {
    if (colors.isEmpty) return const [];
    final weights = <int, int>{};
    for (final color in colors) {
      final rgb = color & 0xffffff;
      weights[rgb] = (weights[rgb] ?? 0) + 1;
    }
    final unique = weights.keys.toList()..sort();
    final count = requestedCount.clamp(1, 256);
    if (unique.length <= count) return [for (final c in unique) _opaque(c)];

    final labs = [for (final c in unique) _lab(c)];
    final weight = [for (final c in unique) weights[c]!];
    double distance(Float64List a, Float64List b) {
      final dl = a[0] - b[0], da = a[1] - b[1], db = a[2] - b[2];
      return dl * dl + da * da + db * db;
    }

    // Spread out, from the commonest colour.
    var first = 0;
    for (var i = 1; i < unique.length; i++) {
      if (weight[i] > weight[first]) first = i;
    }
    final chosen = <int>[first];
    final nearest = Float64List(unique.length)
      ..fillRange(0, unique.length, double.infinity);
    while (chosen.length < count) {
      final last = labs[chosen.last];
      var best = -1;
      var bestDistance = 0.0;
      for (var i = 0; i < unique.length; i++) {
        final d = distance(labs[i], last);
        if (d < nearest[i]) nearest[i] = d;
        if (nearest[i] > bestDistance) {
          bestDistance = nearest[i];
          best = i;
        }
      }
      if (best < 0) break;
      chosen.add(best);
    }

    // k-means on how the colours look, weighted by the number of dots.
    final centres = [for (final i in chosen) Float64List.fromList(labs[i])];
    final owner = Int32List(unique.length);
    final rounds = count > 64 ? 4 : 8;
    for (var round = 0; round <= rounds; round++) {
      for (var i = 0; i < unique.length; i++) {
        var best = 0;
        var bestDistance = double.infinity;
        for (var k = 0; k < centres.length; k++) {
          final d = distance(labs[i], centres[k]);
          if (d < bestDistance) {
            bestDistance = d;
            best = k;
          }
        }
        owner[i] = best;
      }
      if (round == rounds) break;
      final sums = List.generate(centres.length, (_) => Float64List(4));
      for (var i = 0; i < unique.length; i++) {
        final sum = sums[owner[i]], w = weight[i].toDouble();
        sum[0] += labs[i][0] * w;
        sum[1] += labs[i][1] * w;
        sum[2] += labs[i][2] * w;
        sum[3] += w;
      }
      for (var k = 0; k < centres.length; k++) {
        final sum = sums[k];
        if (sum[3] == 0) continue;
        centres[k]
          ..[0] = sum[0] / sum[3]
          ..[1] = sum[1] / sum[3]
          ..[2] = sum[2] / sum[3];
      }
    }
    // Each centre becomes the real colour of its dots nearest it.
    final palette = <int>[];
    for (var k = 0; k < centres.length; k++) {
      var best = -1;
      var bestDistance = double.infinity;
      for (var i = 0; i < unique.length; i++) {
        if (owner[i] != k) continue;
        final d = distance(labs[i], centres[k]);
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      if (best >= 0) palette.add(_opaque(unique[best]));
    }
    return palette.toSet().toList();
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

  /// How different two colours look: the squared CIELAB distance (x100).
  /// Plain RGB distance puts a mid grey as near yellow as white or black, so
  /// the grey edge between a white shape and its dark outline came out as
  /// yellow dots.
  int _distance(int a, int b) {
    final x = _lab(a), y = _lab(b);
    final dl = x[0] - y[0], da = x[1] - y[1], db = x[2] - y[2];
    return (100 * (dl * dl + da * da + db * db)).round();
  }

  static final Map<int, Float64List> _labCache = {};

  static Float64List _lab(int color) {
    final rgb = color & 0xffffff;
    final cached = _labCache[rgb];
    if (cached != null) return cached;
    if (_labCache.length >= 1 << 16) _labCache.clear();
    double linear(int c) {
      final v = c / 255;
      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linear((rgb >> 16) & 0xff);
    final g = linear((rgb >> 8) & 0xff);
    final b = linear(rgb & 0xff);
    // sRGB (D65) to XYZ, relative to the white point.
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    double f(double t) => t > 216 / 24389
        ? math.pow(t, 1 / 3).toDouble()
        : (24389 / 27 * t + 16) / 116;
    final fx = f(x), fy = f(y), fz = f(z);
    return _labCache[rgb] = Float64List.fromList([
      116 * fy - 16,
      500 * (fx - fy),
      200 * (fy - fz),
    ]);
  }

  int _rgb(int r, int g, int b) =>
      0xff000000 | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);

  static int _opaque(int rgb) => 0xff000000 | (rgb & 0xffffff);

  /// The 4 x 4 ordered-dithering pattern (Bayer): which of the 16 colours of
  /// a mix (darkest first) each dot of a 4 x 4 square shows, so every share
  /// of the mix is spread evenly over the square.
  static const _bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
}

/// For each colour, how 16 dots of a limited set of colours (up to three of
/// them) look nearest to it side by side (ordered dithering, after
/// Yliluoma), or the one colour when no mix looks clearly nearer. Mixing is
/// in linear light (as the eye averages neighbouring dots); nearness is how
/// different the colours look (CIELAB). Three colours are allowed because
/// two cannot make many colours at all (a light skin from white, yellow and
/// red); each mix also costs by how much its dots stand out from each other
/// (their spread in lightness counting most, as the eye sees a pattern of
/// light and dark far more than one of hues), so a light sky is not turned
/// into a black-and-white checker for a slightly nearer grey.
class _Ditherer {
  _Ditherer(List<int> palette)
    : _colors = [for (final c in palette.toSet()) 0xff000000 | c] {
    for (final c in _colors) {
      _linear.add(
        Float64List.fromList([
          _toLinear((c >> 16) & 0xff),
          _toLinear((c >> 8) & 0xff),
          _toLinear(c & 0xff),
        ]),
      );
      _labs.add(PixelArtEngine._lab(c));
    }
  }

  /// How many of the nearest colours a mix is made from.
  static const _candidates = 6;

  /// What a mix costs per unit of its dots' spread (variance) in lightness
  /// and in hue and colourfulness (CIELAB a and b).
  static const _lightSpread = 0.15, _hueSpread = 0.08;

  /// A mix is used only when it looks at most this share as different from
  /// the colour wanted as the nearest single colour does: a small gain is not
  /// worth dots of another colour, which show up as specks. The further off
  /// the nearest colour is (in CIELAB), the readier a mix is taken: from
  /// [_closeRatio] where it is [_close] away to [_farRatio] from [_far].
  static const _closeRatio = 0.5, _farRatio = 0.8;
  static const double _close = 15, _far = 30;

  /// A colour this near (CIELAB) to one of the set is that colour: dots of
  /// another colour would only freckle it.
  static const double _enough = 10;

  /// The largest squared share of [single] (squared) a mix may keep.
  static double _gain(double single) {
    final t = ((math.sqrt(single) - _close) / (_far - _close)).clamp(0.0, 1.0);
    final ratio = _closeRatio + (_farRatio - _closeRatio) * t;
    return ratio * ratio;
  }

  final List<int> _colors;
  final _linear = <Float64List>[];
  final _labs = <Float64List>[];
  final _cache = <int, Int32List>{};

  /// CIELAB of an sRGB colour.
  static Float64List labOf(int color) => _labOfLinear(
    _toLinear((color >> 16) & 0xff),
    _toLinear((color >> 8) & 0xff),
    _toLinear(color & 0xff),
  );

  /// The colour of the set that looks nearest to [color].
  int nearest(int color) {
    final lab = labOf(color);
    var best = 0;
    var bestDistance = double.infinity;
    for (var k = 0; k < _labs.length; k++) {
      final l = _labs[k];
      final dl = l[0] - lab[0], da = l[1] - lab[1], db = l[2] - lab[2];
      final d = dl * dl + da * da + db * db;
      if (d < bestDistance) {
        bestDistance = d;
        best = k;
      }
    }
    return _colors[best];
  }

  /// The 16 colours of the mix for [color], darkest first (all the same
  /// when it is not mixed). Colours a step of 4 apart share a mix: no mix
  /// can tell them apart.
  Int32List planFor(int color) {
    final key = (color >> 2) & 0x3f3f3f;
    final cached = _cache[key];
    if (cached != null) return cached;
    final rgb = color & 0xffffff;
    final lr = _toLinear((rgb >> 16) & 0xff),
        lg = _toLinear((rgb >> 8) & 0xff),
        lb = _toLinear(rgb & 0xff);
    final lab = _labOfLinear(lr, lg, lb);
    double distance(Float64List x) {
      final dl = x[0] - lab[0], da = x[1] - lab[1], db = x[2] - lab[2];
      return dl * dl + da * da + db * db;
    }

    // The nearest few colours, nearest first.
    final near = <int>[];
    final nearDistance = <double>[];
    for (var k = 0; k < _colors.length; k++) {
      final d = distance(_labs[k]);
      if (near.length == _candidates && d >= nearDistance.last) continue;
      var at = near.length;
      while (at > 0 && nearDistance[at - 1] > d) {
        at--;
      }
      near.insert(at, k);
      nearDistance.insert(at, d);
      if (near.length > _candidates) {
        near.removeLast();
        nearDistance.removeLast();
      }
    }
    final single = nearDistance.first;
    final gain = _gain(single);
    var best = <int, int>{near.first: 16};
    var bestCost = single;
    if (single <= _enough * _enough) near.length = 1;

    // How far the mix of [counts] dots of [colours] (16 in all) looks from
    // the colour wanted.
    double off(List<int> colours, List<int> counts) {
      var r = 0.0, g = 0.0, b = 0.0;
      for (var k = 0; k < colours.length; k++) {
        final c = _linear[colours[k]], n = counts[k];
        r += c[0] * n;
        g += c[1] * n;
        b += c[2] * n;
      }
      return _distanceOfLinear(r / 16, g / 16, b / 16, lab);
    }

    // From [start] (counts for one set of colours), move one dot at a time
    // from one colour to another while that brings the mix nearer; then the
    // mix is weighed against the best so far, with what its pattern costs
    // (left out of choosing the counts, where it would pull every mix
    // towards fewer dots of the odd colour).
    void consider(List<int> colours, List<int> start) {
      final counts = List<int>.of(start);
      for (var k = 0; k < counts.length; k++) {
        if (counts[k] < 1) counts[k] = 1;
      }
      var total = counts.fold(0, (a, b) => a + b);
      // Back to 16 dots, from or to the largest share.
      while (total != 16) {
        var k = 0;
        for (var i = 1; i < counts.length; i++) {
          if (counts[i] > counts[k]) k = i;
        }
        if (total > 16 && counts[k] <= 1) return;
        counts[k] += total > 16 ? -1 : 1;
        total += total > 16 ? -1 : 1;
      }
      var nearestOff = off(colours, counts);
      for (var step = 0; step < 16; step++) {
        var moved = false;
        var bestFrom = -1, bestTo = -1;
        var bestOff = nearestOff;
        for (var from = 0; from < counts.length; from++) {
          if (counts[from] <= 1) continue;
          for (var to = 0; to < counts.length; to++) {
            if (to == from) continue;
            counts[from]--;
            counts[to]++;
            final o = off(colours, counts);
            counts[from]++;
            counts[to]--;
            if (o < bestOff) {
              bestOff = o;
              bestFrom = from;
              bestTo = to;
              moved = true;
            }
          }
        }
        if (!moved) break;
        counts[bestFrom]--;
        counts[bestTo]++;
        nearestOff = bestOff;
      }
      if (nearestOff > single * gain) return;
      var l = 0.0, a = 0.0, bb = 0.0;
      for (var k = 0; k < colours.length; k++) {
        final x = _labs[colours[k]], n = counts[k];
        l += x[0] * n;
        a += x[1] * n;
        bb += x[2] * n;
      }
      l /= 16;
      a /= 16;
      bb /= 16;
      var light = 0.0, hue = 0.0;
      for (var k = 0; k < colours.length; k++) {
        final x = _labs[colours[k]], n = counts[k];
        light += n * (x[0] - l) * (x[0] - l);
        hue += n * ((x[1] - a) * (x[1] - a) + (x[2] - bb) * (x[2] - bb));
      }
      final cost = nearestOff + (_lightSpread * light + _hueSpread * hue) / 16;
      if (cost < bestCost) {
        bestCost = cost;
        best = {for (var k = 0; k < colours.length; k++) colours[k]: counts[k]};
      }
    }

    for (var i = 0; i < near.length; i++) {
      for (var j = i + 1; j < near.length; j++) {
        final p = near[i], q = near[j];
        final a = _linear[p], b = _linear[q];
        final dr = b[0] - a[0], dg = b[1] - a[1], db = b[2] - a[2];
        final length = dr * dr + dg * dg + db * db;
        if (length == 0) continue;
        final t =
            ((lr - a[0]) * dr + (lg - a[1]) * dg + (lb - a[2]) * db) / length;
        final n = (t * 16).round();
        consider([p, q], [16 - n, n]);
        for (var k = j + 1; k < near.length; k++) {
          // Least squares in linear light for the shares of the three (they
          // add up to one), as a start.
          final c = _linear[near[k]];
          final ux = a[0] - c[0], uy = a[1] - c[1], uz = a[2] - c[2];
          final vx = b[0] - c[0], vy = b[1] - c[1], vz = b[2] - c[2];
          final wx = lr - c[0], wy = lg - c[1], wz = lb - c[2];
          final uu = ux * ux + uy * uy + uz * uz;
          final uv = ux * vx + uy * vy + uz * vz;
          final vv = vx * vx + vy * vy + vz * vz;
          final uw = ux * wx + uy * wy + uz * wz;
          final vw = vx * wx + vy * wy + vz * wz;
          final det = uu * vv - uv * uv;
          if (det.abs() < 1e-12) continue;
          final sa = (uw * vv - vw * uv) / det, sb = (vw * uu - uw * uv) / det;
          final na = (sa * 16).round().clamp(1, 14);
          final nb = (sb * 16).round().clamp(1, 14);
          consider([p, q, near[k]], [na, nb, 16 - na - nb]);
        }
      }
    }

    final plan = Int32List(16);
    final order = best.keys.toList()
      ..sort((p, q) => _labs[p][0].compareTo(_labs[q][0]));
    var at = 0;
    for (final k in order) {
      for (var n = 0; n < best[k]!; n++) {
        plan[at++] = _colors[k];
      }
    }
    if (_cache.length >= 1 << 16) _cache.clear();
    return _cache[key] = plan;
  }

  /// sRGB channel values in linear light.
  static final Float64List _linearOf = Float64List.fromList([
    for (var c = 0; c < 256; c++)
      c / 255 <= 0.04045
          ? c / 255 / 12.92
          : math.pow((c / 255 + 0.055) / 1.055, 2.4).toDouble(),
  ]);

  static double _toLinear(int c) => _linearOf[c];

  /// Cube roots over 0..1, for the CIELAB conversion of every mix tried:
  /// read between entries, they are good to a millionth.
  static const _rootSteps = 4096;
  static final Float64List _roots = Float64List.fromList([
    for (var k = 0; k <= _rootSteps; k++)
      math.pow(k / _rootSteps, 1 / 3).toDouble(),
  ]);

  static double _cubeRoot(double t) {
    if (t >= 1) return math.pow(t, 1 / 3).toDouble();
    final x = t * _rootSteps;
    final k = x.floor();
    final f = x - k;
    return _roots[k] * (1 - f) + _roots[k + 1] * f;
  }

  /// How different linear-light colour ([r], [g], [b]) looks from [lab]:
  /// the squared CIELAB distance, worked out without building the colour.
  static double _distanceOfLinear(
    double r,
    double g,
    double b,
    Float64List lab,
  ) {
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    const e = 216 / 24389, k = 24389 / 27;
    final fx = x > e ? _cubeRoot(x) : (k * x + 16) / 116;
    final fy = y > e ? _cubeRoot(y) : (k * y + 16) / 116;
    final fz = z > e ? _cubeRoot(z) : (k * z + 16) / 116;
    final dl = 116 * fy - 16 - lab[0],
        da = 500 * (fx - fy) - lab[1],
        db = 200 * (fy - fz) - lab[2];
    return dl * dl + da * da + db * db;
  }

  static Float64List _labOfLinear(double r, double g, double b) {
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    double f(double t) =>
        t > 216 / 24389 ? _cubeRoot(t) : (24389 / 27 * t + 16) / 116;
    final fx = f(x), fy = f(y), fz = f(z);
    return Float64List.fromList([
      116 * fy - 16,
      500 * (fx - fy),
      200 * (fy - fz),
    ]);
  }
}
