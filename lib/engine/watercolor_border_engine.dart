import 'dart:math' as math;
import 'dart:typed_data';

/// 水彩境界 (watercolour border): only adds the pigment a wash gathers
/// along its edge as it dries — a denser, darker band, as with Clip Studio
/// Paint's watercolour-edge layer effect. Everything else stays exactly as
/// it was painted: the inside is neither lightened nor made see-through
/// (how see-through a wash is belongs to the brush, 水分量). (The owner,
/// 2026-11-27: 「透けさせるのはブラシ側でやるので水彩境界では透けさせないで
/// そのままにして名前の通り縁の境界だけに色が溜まるように描画追加するだけ」.)
///
/// [data] is premultiplied RGBA (as layers hold it). The edges are where the
/// paint meets transparency and, with [colorEdges], where it meets paint of a
/// clearly different colour (so areas painted side by side on one layer
/// each get their own rim). [range] is how far in from the edge the rim
/// reaches and [blur] softens it, both in pixels; [darkenEffect] (0–100) is
/// how much deeper the rim's colour is. Pixels the rim does not reach come
/// out unchanged, on a layer and on an opaque frame (演出フィルター) alike.
Uint8List applyWatercolorBorder(
  Uint8List data,
  int width,
  int height, {
  required double range,
  required double darkenEffect,
  double blur = 2,
  bool colorEdges = true,
}) {
  final out = Uint8List.fromList(data);
  final n = width * height;
  if (n == 0 || data.length < n * 4) return out;
  final reach = math.max(0.5, range);
  final darkness = (darkenEffect / 100).clamp(0.0, 1.0) * 1.6;
  if (darkness <= 0) return out;

  // Coverage. The edge is where any paint ends (not where the coverage
  // crosses a half, which paper grain inside a pale wash does all over);
  // how steeply it falls there is measured on the coverage softened a
  // little, so the grain does not count as an edge.
  final cover = Float32List(n);
  for (var i = 0; i < n; i++) {
    cover[i] = data[i * 4 + 3] / 255;
  }
  final smooth = _boxBlur3(cover, width, height);
  bool painted(int i) => cover[i] > 0.03;
  // Straight colours, softened the same way.
  final soft = colorEdges ? _softColours(data, width, height) : Float32List(0);

  // Where the rim starts (distance 0), and how much pigment gathers there:
  // a crisp edge (the wash stops) gathers it, a soft fade (painted wet into
  // wet) hardly does, whatever the wash's own density.
  final seeds = Uint8List(n);
  final gather = Float32List(n);
  void seed(int i, double amount) {
    seeds[i] = 1;
    if (amount > gather[i]) gather[i] = amount;
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      if (!painted(i)) continue;
      final atEdge =
          (x > 0 && !painted(i - 1)) ||
          (x < width - 1 && !painted(i + 1)) ||
          (y > 0 && !painted(i - width)) ||
          (y < height - 1 && !painted(i + width));
      if (atEdge) {
        // How steeply the coverage falls here (per pixel).
        final gx =
            (x < width - 1 ? smooth[i + 1] : smooth[i]) -
            (x > 0 ? smooth[i - 1] : smooth[i]);
        final gy =
            (y < height - 1 ? smooth[i + width] : smooth[i]) -
            (y > 0 ? smooth[i - width] : smooth[i]);
        final steep = math.sqrt(gx * gx + gy * gy) / 2;
        seed(i, _smoothstep((steep - 0.01) / 0.06));
      }
      if (!colorEdges || cover[i] < 0.3) continue;
      // Compare two pixels apart, so a one-pixel anti-aliased step is still
      // seen as the edge it is.
      if (x + 2 < width && cover[i + 2] >= 0.3 && _differ(soft, i, i + 2)) {
        seed(i, 1);
        seed(i + 1, 1);
        seed(i + 2, 1);
      }
      if (y + 2 < height &&
          cover[i + 2 * width] >= 0.3 &&
          _differ(soft, i, i + 2 * width)) {
        seed(i, 1);
        seed(i + width, 1);
        seed(i + 2 * width, 1);
      }
    }
  }
  // How much the nearby edge gathers, spread over the rim's reach.
  final spreadSigma = math.max(1.0, reach * 0.5);
  final seedShare = Float32List(n);
  for (var i = 0; i < n; i++) {
    seedShare[i] = seeds[i].toDouble();
  }
  final nearGather = _blur(gather, width, height, spreadSigma);
  final nearSeeds = _blur(seedShare, width, height, spreadSigma);

  final distance = _distanceToSeeds(seeds, width, height);
  var rim = Float32List(n);
  // Pigment gathers towards the edge (softened by [blur]) and piles up in
  // a thin crisp line right at it.
  final line = math.max(1.5, reach * 0.18);
  for (var i = 0; i < n; i++) {
    final t = 1 - distance[i] / reach;
    rim[i] = t <= 0 ? 0 : 0.6 * math.pow(t, 2.5).toDouble();
  }
  if (blur >= 0.5) rim = _blur(rim, width, height, blur);
  for (var i = 0; i < n; i++) {
    rim[i] += 0.4 * (1 - distance[i] / line).clamp(0.0, 1.0);
    final near = nearSeeds[i];
    rim[i] *= near > 1e-4 ? (nearGather[i] / near).clamp(0.0, 1.0) : 0.0;
  }

  for (var i = 0; i < n; i++) {
    final p = i * 4;
    final a = data[p + 3];
    if (a == 0) continue;
    final e = rim[i].clamp(0.0, 1.0);
    // Beyond the rim the paint stays exactly as it was.
    if (e == 0) continue;
    // Where pigment gathers it lies thicker, as a second layer of the same
    // paint does: each channel is raised to a power above 1 (a multiply of
    // the colour with itself at most), so the rim deepens towards a richer
    // shade of the same colour rather than towards grey, and white (no
    // pigment) stays white.
    final deepen = 1 + darkness * e;
    // The gathered pigment also makes a pale wash denser at its rim.
    final gathered = a / 255;
    final newA = ((gathered + (1 - gathered) * e * darkness * 0.3) * 255)
        .round()
        .clamp(0, 255);
    out[p + 3] = newA;
    for (var c = 0; c < 3; c++) {
      final straight = data[p + c] / a;
      final value = math.pow(straight, deepen).toDouble();
      out[p + c] = (value * newA).round().clamp(0, newA);
    }
  }
  return out;
}

/// [src] averaged over 3×3.
Float32List _boxBlur3(Float32List src, int width, int height) {
  final out = Float32List(src.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (x > 0 && y > 0 && x < width - 1 && y < height - 1) {
        // Inside: all nine, added in the same order as below.
        final above = (y - 1) * width + x;
        final row = y * width + x;
        final below = (y + 1) * width + x;
        var sum = 0.0;
        sum += src[above - 1];
        sum += src[above];
        sum += src[above + 1];
        sum += src[row - 1];
        sum += src[row];
        sum += src[row + 1];
        sum += src[below - 1];
        sum += src[below];
        sum += src[below + 1];
        out[row] = sum / 9;
        continue;
      }
      var sum = 0.0;
      var count = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= height) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= width) continue;
          sum += src[yy * width + xx];
          count++;
        }
      }
      out[y * width + x] = sum / count;
    }
  }
  return out;
}

double _smoothstep(double x) {
  final v = x.clamp(0.0, 1.0);
  return v * v * (3 - 2 * v);
}

/// Straight RGB (0–255) averaged over 3×3, each pixel weighted by its
/// coverage (so a pale wash keeps its own colour).
Float32List _softColours(Uint8List data, int width, int height) {
  final soft = Float32List(width * height * 3);
  // Premultiplied channels summed over the coverage: the average straight
  // colour, weighted by how much paint each pixel holds. Summed along each
  // row first (three rows kept at a time), then down: whole numbers, so
  // the same sums as adding up the 3×3 directly.
  final rows = List.generate(3, (_) => Int32List(width * 4));
  void sumRow(int y, Int32List row) {
    final base = y * width * 4;
    for (var o = 0; o < width * 4; o++) {
      // A channel of the pixel and its left and right neighbours (the
      // ones inside the row).
      final x = o >> 2;
      var sum = data[base + o];
      if (x > 0) sum += data[base + o - 4];
      if (x < width - 1) sum += data[base + o + 4];
      row[o] = sum;
    }
  }

  if (height > 0) sumRow(0, rows[0]);
  if (height > 1) sumRow(1, rows[1]);
  final none = Int32List(width * 4);
  for (var y = 0; y < height; y++) {
    if (y + 1 < height && y >= 1) sumRow(y + 1, rows[(y + 1) % 3]);
    final above = y >= 1 ? rows[(y - 1) % 3] : none;
    final middle = rows[y % 3];
    final below = y + 1 < height ? rows[(y + 1) % 3] : none;
    for (var x = 0; x < width; x++) {
      final o = x * 4;
      final r = above[o] + middle[o] + below[o];
      final g = above[o + 1] + middle[o + 1] + below[o + 1];
      final b = above[o + 2] + middle[o + 2] + below[o + 2];
      final weight = above[o + 3] + middle[o + 3] + below[o + 3];
      final p = (y * width + x) * 3;
      if (weight > 0) {
        soft[p] = r * 255 / weight;
        soft[p + 1] = g * 255 / weight;
        soft[p + 2] = b * 255 / weight;
      }
    }
  }
  return soft;
}

/// Whether the colours at [i] and [j] are clearly different paints (the
/// "redmean" weighted RGB distance, close to how different they look).
bool _differ(Float32List soft, int i, int j) {
  final a = i * 3;
  final b = j * 3;
  final mean = (soft[a] + soft[b]) / 2;
  final dr = soft[a] - soft[b];
  final dg = soft[a + 1] - soft[b + 1];
  final db = soft[a + 2] - soft[b + 2];
  final d2 =
      (2 + mean / 256) * dr * dr +
      4 * dg * dg +
      (2 + (255 - mean) / 256) * db * db;
  return d2 > 60 * 60;
}

/// The distance from each pixel to the nearest seed (exact, Euclidean;
/// Felzenszwalb and Huttenlocher's two passes).
Float64List _distanceToSeeds(Uint8List seeds, int width, int height) {
  const far = 1e20;
  final grid = Float64List(width * height);
  for (var i = 0; i < grid.length; i++) {
    grid[i] = seeds[i] != 0 ? 0 : far;
  }
  final size = math.max(width, height);
  final f = Float64List(size), d = Float64List(size);
  final v = Int32List(size), z = Float64List(size + 1);
  void pass(int count) {
    var k = 0;
    v[0] = 0;
    z[0] = -far;
    z[1] = far;
    for (var q = 1; q < count; q++) {
      final fq = f[q] + q * q;
      var at = v[k];
      var s = (fq - (f[at] + at * at)) / (2 * q - 2 * at);
      while (s <= z[k]) {
        k--;
        at = v[k];
        s = (fq - (f[at] + at * at)) / (2 * q - 2 * at);
      }
      k++;
      v[k] = q;
      z[k] = s;
      z[k + 1] = far;
    }
    k = 0;
    for (var q = 0; q < count; q++) {
      while (z[k + 1] < q) {
        k++;
      }
      final dq = q - v[k];
      d[q] = dq * dq + f[v[k]];
    }
  }

  // Down the columns, a few side by side (each read a row at a time, not a
  // column at a time). A column without a seed gives what every such
  // column gives.
  const block = 8;
  final columns = Float64List(block * height);
  Float64List? seedless;
  for (var x0 = 0; x0 < width; x0 += block) {
    final count = math.min(block, width - x0);
    for (var y = 0; y < height; y++) {
      final row = y * width + x0;
      for (var c = 0; c < count; c++) {
        columns[c * height + y] = grid[row + c];
      }
    }
    for (var c = 0; c < count; c++) {
      final at = c * height;
      var seeded = false;
      for (var y = 0; y < height; y++) {
        if (columns[at + y] != far) {
          seeded = true;
          break;
        }
      }
      if (!seeded && seedless != null) {
        columns.setRange(at, at + height, seedless);
        continue;
      }
      f.setRange(0, height, columns, at);
      pass(height);
      columns.setRange(at, at + height, d);
      if (!seeded) seedless = Float64List.fromList(d.sublist(0, height));
    }
    for (var y = 0; y < height; y++) {
      final row = y * width + x0;
      for (var c = 0; c < count; c++) {
        grid[row + c] = columns[c * height + y];
      }
    }
  }
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      f[x] = grid[y * width + x];
    }
    pass(width);
    for (var x = 0; x < width; x++) {
      grid[y * width + x] = math.sqrt(d[x]);
    }
  }
  return grid;
}

/// Three box blurs approximating a Gaussian of [sigma] pixels.
///
/// Each row's and each column's running sum adds its terms in the same
/// order as one sum at a time would; the columns are run side by side, a
/// row at a time (reading the picture in order instead of down each
/// column).
Float32List _blur(Float32List src, int width, int height, double sigma) {
  final radius = math.max(1, (sigma - 0.3).round());
  final out = Float32List.fromList(src);
  final tmp = Float32List(width * height);
  final scale = 1 / (2 * radius + 1);
  final sums = Float64List(width);
  for (var pass = 0; pass < 3; pass++) {
    for (var y = 0; y < height; y++) {
      final row = y * width;
      var sum = 0.0;
      for (var k = -radius; k <= radius; k++) {
        sum += out[row + (k < 0 ? 0 : (k > width - 1 ? width - 1 : k))];
      }
      for (var x = 0; x < width; x++) {
        tmp[row + x] = sum * scale;
        sum +=
            out[row + (x + radius + 1 < width ? x + radius + 1 : width - 1)] -
            out[row + (x - radius > 0 ? x - radius : 0)];
      }
    }
    sums.fillRange(0, width, 0);
    for (var k = -radius; k <= radius; k++) {
      final row = (k < 0 ? 0 : (k > height - 1 ? height - 1 : k)) * width;
      for (var x = 0; x < width; x++) {
        sums[x] += tmp[row + x];
      }
    }
    for (var y = 0; y < height; y++) {
      final row = y * width;
      final into =
          (y + radius + 1 < height ? y + radius + 1 : height - 1) * width;
      final out0 = (y - radius > 0 ? y - radius : 0) * width;
      for (var x = 0; x < width; x++) {
        out[row + x] = sums[x] * scale;
        sums[x] += tmp[into + x] - tmp[out0 + x];
      }
    }
  }
  return out;
}
