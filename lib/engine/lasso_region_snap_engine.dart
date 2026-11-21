import 'dart:math' as math;
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

/// The lasso's 「線に吸着」: what the lasso encloses is selected the way a
/// bucket fill sees the picture, hugging the drawing exactly.
///
/// The picture is split into areas a bucket would fill: paper (transparent,
/// or near-white on a flattened reference) cut up by the lines, and fills of
/// one colour wider than a line. The areas lying mostly inside the lasso are
/// selected, with the lines that bound them out to their outer edge, so the
/// selection's edge follows the drawing's outline however the finger
/// wandered. Lines inside a selected area go with it; a line running on out
/// of the outline (a hair strand, the side of a neighbouring shape) is cut
/// at the outline, and a line that only crosses the lasso is left out.
class LassoRegionSnap {
  LassoRegionSnap._();

  /// The largest break in a line that is closed, in canvas pixels.
  static const int maxGapTolerancePx = 12;

  /// A paint region no thicker than twice this (in pixels) is a line.
  static const int _lineHalfWidth = 4;

  /// One byte per pixel, 1 where selected; null when the picture gives
  /// nothing to snap to (no drawing inside the lasso, or none it encloses),
  /// and the lasso is then taken as drawn.
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

    // Paint regions: neighbouring painted pixels of nearly the same colour,
    // as a bucket's tolerance groups them.
    final paper = Uint8List(n);
    var paintInside = 0;
    for (var p = 0; p < n; p++) {
      if (_isPaper(rgba, p)) {
        paper[p] = 1;
      } else if (inside[p] != 0) {
        paintInside++;
      }
    }
    if (paintInside == 0) return null;
    final region = Int32List(n)..fillRange(0, n, -1);
    final queue = Int32List(n);
    final regionSeeds = <int>[];
    for (var seed = 0; seed < n; seed++) {
      if (paper[seed] != 0 || region[seed] != -1) continue;
      final id = regionSeeds.length;
      regionSeeds.add(seed);
      var head = 0, tail = 0;
      region[seed] = id;
      queue[tail++] = seed;
      while (head < tail) {
        final p = queue[head++];
        final x = p % width;
        void visit(int q) {
          if (paper[q] == 0 && region[q] == -1 && _similar(rgba, seed, q)) {
            region[q] = id;
            queue[tail++] = q;
          }
        }

        if (x > 0) visit(p - 1);
        if (x < width - 1) visit(p + 1);
        if (p >= width) visit(p - width);
        if (p < n - width) visit(p + width);
      }
    }
    // How far each painted pixel is from the edge of its own region: a
    // region whose middle is no further than a line's half width is a line.
    final depth = _chamfer(width, height, (p) => paper[p] == 0, region);
    final thickest = Int32List(regionSeeds.length);
    for (var p = 0; p < n; p++) {
      final id = region[p];
      if (id >= 0 && depth[p] > thickest[id]) thickest[id] = depth[p];
    }
    final line = Uint8List(n);
    for (var p = 0; p < n; p++) {
      final id = region[p];
      if (id >= 0 && thickest[id] <= _lineHalfWidth * 3) line[p] = 1;
    }

    // A break in a line up to the tolerance is closed by widening the lines
    // by half of it while the areas are found, as a bucket fill's gap
    // closing does.
    final reach = (gapTolerancePx.clamp(0, maxGapTolerancePx) + 1) ~/ 2;
    final wall = reach == 0 ? line : _widen(line, width, height, reach);

    // The areas: paper between the lines, and the wider fills.
    final label = Int32List(n)..fillRange(0, n, -1);
    final totals = <int>[];
    final insides = <int>[];
    final opens = <bool>[];
    for (var seed = 0; seed < n; seed++) {
      if (wall[seed] != 0 || label[seed] != -1) continue;
      final id = totals.length;
      final kind = region[seed];
      var total = 0, within = 0, head = 0, tail = 0;
      var open = false;
      label[seed] = id;
      queue[tail++] = seed;
      while (head < tail) {
        final p = queue[head++];
        total++;
        if (inside[p] != 0) within++;
        final x = p % width;
        if (x == 0 || x == width - 1 || p < width || p >= n - width) {
          open = true;
        }
        void visit(int q) {
          if (wall[q] == 0 && label[q] == -1 && region[q] == kind) {
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
      opens.add(open);
    }
    // Areas mostly inside the lasso; the paper round the drawing, running
    // on to the canvas's edge, only when the lasso takes nearly all of it.
    final chosen = [
      for (var l = 0; l < totals.length; l++)
        opens[l]
            ? insides[l] * 10 >= totals[l] * 9
            : insides[l] * 2 >= totals[l],
    ];
    if (!chosen.contains(true)) return null;

    // The band that closed the gaps (paper or fill under the widened lines)
    // goes to the nearest area.
    var head = 0, tail = 0;
    for (var p = 0; p < n; p++) {
      if (label[p] != -1) queue[tail++] = p;
    }
    while (head < tail) {
      final p = queue[head++];
      final id = label[p];
      final x = p % width;
      void spread(int q) {
        if (label[q] == -1 && line[q] == 0) {
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

    // The lines bounding the selected areas, out to their far edge: from
    // the selected areas into the lines, as far as the line is thick where
    // it is crossed (twice the deepest point passed, and a pixel to spare),
    // so a line running on out of the outline is cut where it leaves it.
    final lineDepth = _chamfer(width, height, (p) => line[p] != 0, null);
    final steps = Int32List(n)..fillRange(0, n, -1);
    final deepest = Int32List(n);
    head = 0;
    tail = 0;
    for (var p = 0; p < n; p++) {
      if (mask[p] != 0) {
        steps[p] = 0;
        queue[tail++] = p;
      }
    }
    while (head < tail) {
      final p = queue[head++];
      final x = p % width;
      void cross(int q) {
        if (line[q] == 0 || mask[q] != 0) return;
        final s = steps[p] + 1;
        final d = math.max(deepest[p], lineDepth[q]);
        if (steps[q] == -1) {
          // Depths are in thirds of a pixel (chamfer 3-4).
          if (s * 3 > 2 * d + 3) return;
          steps[q] = s;
          deepest[q] = d;
          mask[q] = 1;
          selected++;
          queue[tail++] = q;
        } else if (steps[q] == s && d > deepest[q]) {
          deepest[q] = d;
        }
      }

      // Diagonal steps too, so the outer corners of an outline are as near
      // as its sides.
      for (var dy = -1; dy <= 1; dy++) {
        final row = p ~/ width + dy;
        if (row < 0 || row >= height) continue;
        for (var dx = -1; dx <= 1; dx++) {
          if ((dx == 0 && dy == 0) || x + dx < 0 || x + dx >= width) continue;
          cross(row * width + x + dx);
        }
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

  /// Paper: see-through, or near-white on a flattened, opaque reference.
  static bool _isPaper(Uint8List rgba, int p) {
    final i = p * 4;
    final a = rgba[i + 3];
    if (a < 24) return true;
    if (a < 245) return false;
    final luma = rgba[i] * .2126 + rgba[i + 1] * .7152 + rgba[i + 2] * .0722;
    return luma >= 235;
  }

  /// Within a bucket's tolerance of each other (straight colour and
  /// opacity).
  static bool _similar(Uint8List rgba, int p, int q) {
    final i = p * 4, j = q * 4;
    final a = rgba[i + 3], b = rgba[j + 3];
    if ((a - b).abs() > 48) return false;
    for (var c = 0; c < 3; c++) {
      final u = a == 0 ? 0 : rgba[i + c] * 255 ~/ a;
      final v = b == 0 ? 0 : rgba[j + c] * 255 ~/ b;
      if ((u - v).abs() > 48) return false;
    }
    return true;
  }

  /// For each pixel where [within] holds, how far (chamfer 3-4, so in
  /// thirds of a pixel) it is from the nearest pixel outside it (or, with
  /// [regions], of another region); 0 elsewhere.
  static Int32List _chamfer(
    int width,
    int height,
    bool Function(int p) within,
    Int32List? regions,
  ) {
    const straight = 3, diagonal = 4;
    final n = width * height;
    final distance = Int32List(n);
    const far = 1 << 28;
    for (var p = 0; p < n; p++) {
      distance[p] = within(p) ? far : 0;
    }
    bool apart(int p, int q) => regions != null && regions[p] != regions[q];
    void relax(int p, int x, int y, int step) {
      if (x < 0 || y < 0 || x >= width || y >= height) {
        if (step < distance[p]) distance[p] = step;
        return;
      }
      final q = y * width + x;
      final d = (apart(p, q) ? 0 : distance[q]) + step;
      if (d < distance[p]) distance[p] = d;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = y * width + x;
        if (distance[p] == 0) continue;
        relax(p, x - 1, y, straight);
        relax(p, x, y - 1, straight);
        relax(p, x - 1, y - 1, diagonal);
        relax(p, x + 1, y - 1, diagonal);
      }
    }
    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final p = y * width + x;
        if (distance[p] == 0) continue;
        relax(p, x + 1, y, straight);
        relax(p, x, y + 1, straight);
        relax(p, x + 1, y + 1, diagonal);
        relax(p, x - 1, y + 1, diagonal);
      }
    }
    return distance;
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
