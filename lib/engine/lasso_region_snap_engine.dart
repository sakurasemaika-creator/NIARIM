import 'dart:typed_data';
import 'dart:ui' show Offset;

/// What the lasso's 「線に吸着」 works on, sent to a background isolate.
typedef LassoRegionSnapArgs = ({
  List<Offset> lasso,
  Uint8List rgba,
  int width,
  int height,
  int gapTolerancePx,
});

/// [LassoRegionSnap.select] for `compute`.
Uint8List? lassoRegionSnapInIsolate(LassoRegionSnapArgs args) =>
    LassoRegionSnap.select(
      lasso: args.lasso,
      rgba: args.rgba,
      width: args.width,
      height: args.height,
      gapTolerancePx: args.gapTolerancePx,
    );

/// The lasso's 「線に吸着」: the line art divides the canvas into areas, the
/// way a bucket fill sees it, and the lasso selects the areas lying mostly
/// inside it. The selection's edge runs along the middle of the lines, so
/// a rough lasso around a shape selects exactly the shape, however the
/// finger wandered, and lines inside it are taken along.
class LassoRegionSnap {
  LassoRegionSnap._();

  /// The largest break in a line that is closed, in canvas pixels.
  static const int maxGapTolerancePx = 12;

  /// One byte per pixel, 1 where selected; null when the line art gives
  /// nothing to snap to (no line inside the lasso, or no area mostly inside
  /// it), and the lasso is then taken as drawn.
  static Uint8List? select({
    required List<Offset> lasso,
    required Uint8List rgba,
    required int width,
    required int height,
    int gapTolerancePx = 6,
  }) {
    final n = width * height;
    if (lasso.length < 3 || n == 0 || rgba.length < n * 4) return null;
    final inside = polygonMask(lasso, width, height);
    final ink = Uint8List(n);
    var inkInside = 0;
    for (var i = 0; i < n; i++) {
      if (_isInk(rgba, i)) {
        ink[i] = 1;
        if (inside[i] != 0) inkInside++;
      }
    }
    if (inkInside == 0) return null;

    // A break in a line up to the tolerance is closed by widening the lines
    // by half of it while the areas are found, as a bucket fill's gap
    // closing does; the widened band is shared out again afterwards.
    final reach = (gapTolerancePx.clamp(0, maxGapTolerancePx) + 1) ~/ 2;
    final wall = reach == 0 ? ink : _widen(ink, width, height, reach);

    final label = Int32List(n)..fillRange(0, n, -1);
    final queue = Int32List(n);
    final totals = <int>[];
    final insides = <int>[];
    for (var seed = 0; seed < n; seed++) {
      if (wall[seed] != 0 || label[seed] != -1) continue;
      final id = totals.length;
      var total = 0;
      var within = 0;
      var head = 0;
      var tail = 0;
      label[seed] = id;
      queue[tail++] = seed;
      while (head < tail) {
        final p = queue[head++];
        total++;
        if (inside[p] != 0) within++;
        final x = p % width;
        void visit(int q) {
          if (wall[q] == 0 && label[q] == -1) {
            label[q] = id;
            queue[tail++] = q;
          }
        }

        if (x > 0) visit(p - 1);
        if (x < width - 1) visit(p + 1);
        if (p >= width) visit(p - width);
        if (p < n - width) visit(p + width);
      }
      totals.add(total);
      insides.add(within);
    }
    if (totals.isEmpty) return null;
    final chosen = [
      for (var l = 0; l < totals.length; l++) insides[l] * 2 >= totals[l],
    ];
    if (!chosen.contains(true)) return null;

    // Every line pixel (and the band that closed the gaps) goes to the
    // nearest area, so a line between a chosen area and another is split
    // down its middle, and a line between two chosen areas is chosen.
    var head = 0;
    var tail = 0;
    for (var p = 0; p < n; p++) {
      if (label[p] != -1) queue[tail++] = p;
    }
    while (head < tail) {
      final p = queue[head++];
      final id = label[p];
      final x = p % width;
      void spread(int q) {
        if (label[q] == -1) {
          label[q] = id;
          queue[tail++] = q;
        }
      }

      if (x > 0) spread(p - 1);
      if (x < width - 1) spread(p + 1);
      if (p >= width) spread(p - width);
      if (p < n - width) spread(p + width);
    }

    final mask = Uint8List(n);
    var selected = 0;
    for (var p = 0; p < n; p++) {
      final id = label[p];
      if (id >= 0 && chosen[id]) {
        mask[p] = 1;
        selected++;
      }
    }
    return selected == 0 ? null : mask;
  }

  /// 1 where the pixel's centre is inside [polygon] (even-odd rule).
  static Uint8List polygonMask(List<Offset> polygon, int width, int height) {
    final mask = Uint8List(width * height);
    final count = polygon.length;
    if (count < 3) return mask;
    final crossings = <double>[];
    for (var y = 0; y < height; y++) {
      final cy = y + .5;
      crossings.clear();
      for (var k = 0; k < count; k++) {
        final a = polygon[k];
        final b = polygon[(k + 1) % count];
        if ((a.dy <= cy && b.dy > cy) || (b.dy <= cy && a.dy > cy)) {
          crossings.add(a.dx + (cy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx));
        }
      }
      crossings.sort();
      final row = y * width;
      for (var k = 0; k + 1 < crossings.length; k += 2) {
        // Pixel x is inside when its centre x + .5 lies in [from, to).
        final from = (crossings[k] - .5).ceil().clamp(0, width);
        final to = (crossings[k + 1] - .5).ceil().clamp(0, width);
        for (var x = from; x < to; x++) {
          mask[row + x] = 1;
        }
      }
    }
    return mask;
  }

  /// Transparent line-art layers are read by alpha; on flattened, opaque
  /// references, ink is what is visibly darker than near-white paper.
  static bool _isInk(Uint8List rgba, int p) {
    final i = p * 4;
    final a = rgba[i + 3];
    if (a < 24) return false;
    if (a < 245) return true;
    final luma = rgba[i] * .2126 + rgba[i + 1] * .7152 + rgba[i + 2] * .0722;
    return luma < 235;
  }

  /// [ink] widened by [reach] pixels (a disc), from a chamfer distance.
  static Uint8List _widen(Uint8List ink, int width, int height, int reach) {
    const straight = 3;
    const diagonal = 4;
    final limit = reach * straight;
    final cap = limit + diagonal;
    final n = width * height;
    final distance = Uint16List(n);
    for (var p = 0; p < n; p++) {
      distance[p] = ink[p] != 0 ? 0 : cap;
    }
    int at(int x, int y) => x < 0 || y < 0 || x >= width || y >= height
        ? cap
        : distance[y * width + x];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = y * width + x;
        var d = distance[p];
        if (d == 0) continue;
        final left = at(x - 1, y) + straight;
        final up = at(x, y - 1) + straight;
        final upLeft = at(x - 1, y - 1) + diagonal;
        final upRight = at(x + 1, y - 1) + diagonal;
        if (left < d) d = left;
        if (up < d) d = up;
        if (upLeft < d) d = upLeft;
        if (upRight < d) d = upRight;
        distance[p] = d > cap ? cap : d;
      }
    }
    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final p = y * width + x;
        var d = distance[p];
        if (d == 0) continue;
        final right = at(x + 1, y) + straight;
        final down = at(x, y + 1) + straight;
        final downRight = at(x + 1, y + 1) + diagonal;
        final downLeft = at(x - 1, y + 1) + diagonal;
        if (right < d) d = right;
        if (down < d) d = down;
        if (downRight < d) d = downRight;
        if (downLeft < d) d = downLeft;
        distance[p] = d > cap ? cap : d;
      }
    }
    final wall = Uint8List(n);
    for (var p = 0; p < n; p++) {
      if (distance[p] <= limit) wall[p] = 1;
    }
    return wall;
  }
}
