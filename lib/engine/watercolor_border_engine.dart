import 'dart:math' as math;
import 'dart:typed_data';

/// 水彩境界 (watercolour border): each painted area looks like a wash that
/// dried — denser and darker in a band along its edge, more transparent
/// inside — as with Clip Studio Paint's watercolour-edge layer effect.
///
/// [data] is premultiplied RGBA (as layers hold it). The edges are where the
/// paint meets transparency and, with [colorEdges], where it meets paint of a
/// clearly different colour (so areas painted side by side on one layer
/// each get their own rim). [range] is how far in from the edge the rim
/// reaches and [blur] softens it, both in pixels; [opacityEffect] (0–100)
/// is how much more transparent the inside becomes, and [darkenEffect]
/// (0–100) how much deeper the rim's colour is.
///
/// On an opaque frame (演出フィルター) there is nothing behind the paint, so
/// with [onPaper] "more transparent" lets white paper show through instead.
Uint8List applyWatercolorBorder(
  Uint8List data,
  int width,
  int height, {
  required double range,
  required double opacityEffect,
  required double darkenEffect,
  double blur = 2,
  bool colorEdges = true,
  bool onPaper = false,
}) {
  final out = Uint8List.fromList(data);
  final n = width * height;
  if (n == 0 || data.length < n * 4) return out;
  final reach = math.max(0.5, range);
  final transparency = (opacityEffect / 100).clamp(0.0, 1.0) * 0.9;
  final darkness = (darkenEffect / 100).clamp(0.0, 1.0) * 1.6;
  if (transparency <= 0 && darkness <= 0) return out;

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
    // Where pigment gathers it lies thicker, as a second layer of the same
    // paint does: each channel is raised to a power above 1 (a multiply of
    // the colour with itself at most), so the rim deepens towards a richer
    // shade of the same colour rather than towards grey, and white (no
    // pigment) stays white.
    final deepen = 1 + darkness * e;
    final thin = transparency * (1 - e);
    // The gathered pigment also makes a pale wash denser at its rim.
    final gathered = a / 255 * (1 - thin);
    final newA = onPaper
        ? a
        : ((gathered + (1 - gathered) * e * darkness * 0.3) * 255)
              .round()
              .clamp(0, 255);
    out[p + 3] = newA;
    for (var c = 0; c < 3; c++) {
      final straight = data[p + c] / a;
      var value = math.pow(straight, deepen).toDouble();
      // On an opaque frame the paper (white) shows through the thinner
      // inside instead.
      if (onPaper) value += (1 - value) * thin;
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
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var r = 0.0, g = 0.0, b = 0.0, weight = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= height) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= width) continue;
          final p = (yy * width + xx) * 4;
          // Premultiplied channels summed over the coverage: the average
          // straight colour, weighted by how much paint each pixel holds.
          r += data[p];
          g += data[p + 1];
          b += data[p + 2];
          weight += data[p + 3];
        }
      }
      final o = (y * width + x) * 3;
      if (weight > 0) {
        soft[o] = r * 255 / weight;
        soft[o + 1] = g * 255 / weight;
        soft[o + 2] = b * 255 / weight;
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
      double meet(int at) =>
          ((f[q] + q * q) - (f[at] + at * at)) / (2 * q - 2 * at);
      var s = meet(v[k]);
      while (s <= z[k]) {
        k--;
        s = meet(v[k]);
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

  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      f[y] = grid[y * width + x];
    }
    pass(height);
    for (var y = 0; y < height; y++) {
      grid[y * width + x] = d[y];
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
Float32List _blur(Float32List src, int width, int height, double sigma) {
  final radius = math.max(1, (sigma - 0.3).round());
  final out = Float32List.fromList(src);
  final tmp = Float32List(width * height);
  final scale = 1 / (2 * radius + 1);
  for (var pass = 0; pass < 3; pass++) {
    for (var y = 0; y < height; y++) {
      final row = y * width;
      var sum = 0.0;
      for (var k = -radius; k <= radius; k++) {
        sum += out[row + k.clamp(0, width - 1)];
      }
      for (var x = 0; x < width; x++) {
        tmp[row + x] = sum * scale;
        sum +=
            out[row + math.min(width - 1, x + radius + 1)] -
            out[row + math.max(0, x - radius)];
      }
    }
    for (var x = 0; x < width; x++) {
      var sum = 0.0;
      for (var k = -radius; k <= radius; k++) {
        sum += tmp[k.clamp(0, height - 1) * width + x];
      }
      for (var y = 0; y < height; y++) {
        out[y * width + x] = sum * scale;
        sum +=
            tmp[math.min(height - 1, y + radius + 1) * width + x] -
            tmp[math.max(0, y - radius) * width + x];
      }
    }
  }
  return out;
}
