import 'dart:math' as math;
import 'dart:typed_data';

import 'perceptual_color_mixer.dart';
import 'tile_manager.dart';

/// One stroke of 水彩風混色 (watercolour-style mixing).
///
/// While the stroke is drawn, each pixel the brush covers shows a
/// transparent wash of the paint over the layer as it was before the stroke
/// (the stroke never builds up on itself, like one wet wash): light where
/// there is more water, granulated by the paper and blotchy where the
/// pigment settled unevenly. When the stroke ends ([finish]) the wash
/// "dries": the pigment spreads past the brush with a ragged edge (にじみ,
/// and a little more with more water). The darker rim a dried wash leaves
/// is the 水彩境界 draw filter's, so it can be tuned after painting.
///
/// Over paint already on the layer the wash glazes: the colour under it
/// turns towards the paint the way paint mixes ([AnalogPaintMixer]; a blue
/// wash over yellow is green), and deepens as a transparent layer does, so a
/// second wash of the same colour at a lowered opacity is deeper. 混色度合い
/// makes the two run together wet instead, nearer to an even mix without
/// deepening. At full opacity a wash of the same colour as the paint under
/// it joins it instead of glazing it: the area grows without getting darker
/// where the strokes overlap, so a flat area laid in several strokes is even
/// (the paper's blotches are fixed to the canvas, so overlapping washes
/// share them).
///
/// Tiles hold straight (not premultiplied) RGBA, as [TileManager.blendPixel]
/// writes them.
class WatercolorStroke {
  WatercolorStroke({
    required this.layerId,
    required this.paint,
    required double brushSize,
    required int water,
    required int pigment,
    int bleed = 50,
    int texture = 50,
    int softEdge = 0,
    required int brightnessCorrection,
    required this.seed,
  }) : _water = water.clamp(0, 100) / 100,
       _pigment = pigment.clamp(0, 100) / 100,
       _bleed = bleed.clamp(0, 100) / 100,
       _textureAmount = texture.clamp(0, 100) / 50,
       _soft = softEdge.clamp(0, 100) / 100,
       _size = math.max(1.0, brushSize),
       _mixer = AnalogPaintMixer(
         selected: paint,
         brightnessCorrection: brightnessCorrection,
       ) {
    final lut = Float64List(3);
    lut[0] = linearFromSrgb8(paint >> 16);
    lut[1] = linearFromSrgb8(paint >> 8);
    lut[2] = linearFromSrgb8(paint);
    _paintLinear = lut;
    final luminance = 0.2126 * lut[0] + 0.7152 * lut[1] + 0.0722 * lut[2];
    _depth = 0.45 * (1 - math.sqrt(luminance));
  }

  final String layerId;

  /// The paint colour as 0xRRGGBB.
  final int paint;

  final double _water;
  final double _pigment;
  final double _bleed;

  /// How strong the paper grain and the blotches are, 0–2 (1 is the
  /// default むら).
  final double _textureAmount;

  /// 境界のぼかし, 0–1: how much the dried wash fades out towards its edge
  /// instead of ending crisply.
  final double _soft;
  final double _size;

  /// Varies the blotches from stroke to stroke.
  final int seed;
  final AnalogPaintMixer _mixer;
  late final Float64List _paintLinear;

  /// How much one layer of this paint deepens what is under it.
  late final double _depth;

  /// Per tile ("tx:ty"): the tile before the stroke, how much the brush
  /// covered (0–255), its mixing rate (0–100) and its opacity (0–255)
  /// there.
  final Map<String, Uint8List> _before = {};
  final Map<String, Uint8List> _coverage = {};
  final Map<String, Uint8List> _rate = {};
  final Map<String, Uint8List> _opacity = {};
  var _lastRate = 0;
  var _lastOpacity = 255;
  var _minX = 1 << 30;
  var _minY = 1 << 30;
  var _maxX = -1;
  var _maxY = -1;

  static const int _size2 = TileManager.tileSize * TileManager.tileSize;

  /// How dense one wash is before texture: more pigment is deeper, more
  /// water paler (all pigment and no water covers fully, for flat paint).
  double get _density => (0.16 + 0.84 * _pigment) * (1 - 0.45 * _water);

  /// Remembers [tile] as it is before the stroke paints on it. Call before
  /// the first pixel of the tile changes.
  void touchTile(int tx, int ty, Uint8List tile) {
    final key = '$tx:$ty';
    if (_before.containsKey(key)) return;
    _before[key] = Uint8List.fromList(tile);
    _coverage[key] = Uint8List(_size2);
    _rate[key] = Uint8List(_size2);
    _opacity[key] = Uint8List(_size2);
  }

  /// The brush now covers pixel ([px], [py]) of tile ([tx], [ty]) by
  /// [coverage] (0–255, the most this stroke has covered it) with mixing
  /// rate [rate] (0–100) at the stamp's [opacity] (0–255): shows the wet
  /// wash there.
  void cover(
    Uint8List tile,
    int tx,
    int ty,
    int px,
    int py,
    int coverage,
    int rate, {
    int opacity = 255,
  }) {
    final key = '$tx:$ty';
    final before = _before[key];
    if (before == null) return;
    final pos = py * TileManager.tileSize + px;
    _coverage[key]![pos] = coverage;
    _rate[key]![pos] = rate;
    _opacity[key]![pos] = opacity;
    _lastRate = rate;
    _lastOpacity = opacity;
    final x = tx * TileManager.tileSize + px;
    final y = ty * TileManager.tileSize + py;
    if (x < _minX) _minX = x;
    if (y < _minY) _minY = y;
    if (x > _maxX) _maxX = x;
    if (y > _maxY) _maxY = y;
    final alpha = coverage / 255 * _density * _texture(x, y);
    _composite(tile, before, pos * 4, alpha.clamp(0.0, 1.0), rate, opacity);
  }

  /// Dries the stroke: spreads it past the brush with a ragged edge.
  /// Returns the tiles it changed (as "tx:ty") so they can be redrawn.
  Set<String> finish(TileManager tiles) {
    final changed = <String>{};
    if (_maxX < _minX) return changed;
    const tileSize = TileManager.tileSize;
    // にじみ carries the wash furthest; water only a little.
    final spread = _size * (0.008 + 0.06 * _water + 0.14 * _bleed);
    // 境界のぼかし fades the wash out over a band this wide.
    final fade = _size * (0.04 + 0.3 * _soft);
    final margin = (math.max(spread, _soft > 0 ? fade : 0) * 2.5 + 2).ceil();
    final left = math.max(0, _minX - margin);
    final top = math.max(0, _minY - margin);
    final right = math.min(tiles.canvasWidth - 1, _maxX + margin);
    final bottom = math.min(tiles.canvasHeight - 1, _maxY + margin);
    if (right < left || bottom < top) return changed;
    final w = right - left + 1;
    final h = bottom - top + 1;

    // Where the brush went, 0–1.
    final covered = Float32List(w * h);
    for (final entry in _coverage.entries) {
      final parts = entry.key.split(':');
      final ox = int.parse(parts[0]) * tileSize;
      final oy = int.parse(parts[1]) * tileSize;
      final cov = entry.value;
      final y0 = math.max(top, oy);
      final y1 = math.min(bottom, oy + tileSize - 1);
      final x0 = math.max(left, ox);
      final x1 = math.min(right, ox + tileSize - 1);
      for (var y = y0; y <= y1; y++) {
        final row = (y - oy) * tileSize - ox;
        final out = (y - top) * w - left;
        for (var x = x0; x <= x1; x++) {
          final c = cov[row + x];
          if (c != 0) covered[out + x] = c / 255;
        }
      }
    }

    // The water carries pigment a little past the brush; how far varies
    // along the edge, which makes it ragged rather than a blurred circle.
    final wet = _blur(covered, w, h, spread);
    final amount = Float32List(w * h);
    final reachScale = _size * 0.22;
    final fringeScale = math.max(1.5, _size * 0.05);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final c = covered[i];
        // Too little water reaches here to carry pigment, whatever the edge
        // does (the reach below is at most 1.95).
        if (wet[i] < 0.082) {
          amount[i] = c;
          continue;
        }
        final wx = left + x;
        final wy = top + y;
        final reach =
            0.85 +
            (0.25 + 0.15 * _water + 0.45 * _bleed) *
                (_fractalNoise(wx / reachScale, wy / reachScale, seed + 17) -
                    0.5) *
                2 +
            (0.2 + 0.3 * _bleed) *
                (_valueNoise(wx / fringeScale, wy / fringeScale, seed + 23) -
                    0.5);
        // Where the water stops, the wash ends in an edge, not a fade.
        final spreadOut = _smoothstep((wet[i] * reach - 0.16) / 0.26);
        amount[i] = math.max(c, spreadOut * math.min(1.0, wet[i] * 2.5));
      }
    }

    if (_soft > 0) {
      // A soft edge: the blurred footprint fades from the full wash inside
      // to nothing outside, as a wash laid wet into a damp sheet does.
      final faded = _blur(covered, w, h, fade);
      for (var i = 0; i < amount.length; i++) {
        final soft = _smoothstep(faded[i] * 1.15);
        amount[i] += (soft - amount[i]) * _soft;
      }
    }

    for (var ty = top ~/ tileSize; ty <= bottom ~/ tileSize; ty++) {
      for (var tx = left ~/ tileSize; tx <= right ~/ tileSize; tx++) {
        final key = '$tx:$ty';
        final ox = tx * tileSize;
        final oy = ty * tileSize;
        final y0 = math.max(top, oy);
        final y1 = math.min(bottom, oy + tileSize - 1);
        final x0 = math.max(left, ox);
        final x1 = math.min(right, ox + tileSize - 1);
        var any = _before.containsKey(key);
        if (!any) {
          for (var y = y0; y <= y1 && !any; y++) {
            for (var x = x0; x <= x1; x++) {
              if (amount[(y - top) * w + x - left] > 0.004) {
                any = true;
                break;
              }
            }
          }
          if (!any) continue;
        }
        final tile = tiles.getOrCreateTile(layerId, tx, ty);
        touchTile(tx, ty, tile);
        final before = _before[key]!;
        final rates = _rate[key]!;
        final opacities = _opacity[key]!;
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            final i = (y - top) * w + x - left;
            final pos = (y - oy) * tileSize + (x - ox);
            final a = amount[i];
            if (a <= 0.004) {
              // Untouched by the wash: as before the stroke.
              final p = pos * 4;
              tile[p] = before[p];
              tile[p + 1] = before[p + 1];
              tile[p + 2] = before[p + 2];
              tile[p + 3] = before[p + 3];
              continue;
            }
            final alpha = a * _density * _texture(x, y);
            final brushed = rates[pos] != 0 || covered[i] > 0;
            _composite(
              tile,
              before,
              pos * 4,
              alpha.clamp(0.0, 1.0),
              brushed ? rates[pos] : _lastRate,
              brushed ? opacities[pos] : _lastOpacity,
            );
          }
        }
        tiles.markDirty(layerId, tx, ty);
        changed.add(key);
      }
    }
    return changed;
  }

  /// Paper grain and the uneven settling of the pigment in its blotches,
  /// both fixed to the canvas (as the paper's sizing is), so washes of the
  /// same colour laid side by side join without a seam.
  double _texture(int x, int y) {
    final grain =
        (_valueNoise(x / 1.4, y / 1.4, 7) * 0.35 +
            _valueNoise(x / 3.8, y / 3.8, 11) * 0.65) -
        0.5;
    final blotchScale = _size * 0.75;
    var blotch =
        (_fractalNoise(x / blotchScale, y / blotchScale, 13) - 0.5) * 2;
    // Pigment settles in patches rather than in a gentle ripple.
    blotch = blotch.sign * math.pow(blotch.abs(), 0.7);
    final amount = _textureAmount;
    return math.max(
      0.0,
      (1 + (0.14 + 0.1 * _pigment) * grain * 2 * amount) *
          (1 + (0.22 + 0.4 * _water) * blotch * amount),
    );
  }

  /// Lays a wash of [alpha] over the pixel at [p] as it was [before] the
  /// stroke, at the brush's [opacity] (0–255).
  void _composite(
    Uint8List tile,
    Uint8List before,
    int p,
    double alpha,
    int rate,
    int opacity,
  ) {
    final b = before[p + 3] / 255;
    if (alpha <= 0) {
      tile[p] = before[p];
      tile[p + 1] = before[p + 1];
      tile[p + 2] = before[p + 2];
      tile[p + 3] = before[p + 3];
      return;
    }
    final paintLinear = _paintLinear;
    final outA = b + alpha - alpha * b;
    if (b <= 0) {
      tile[p] = paint >> 16 & 0xFF;
      tile[p + 1] = paint >> 8 & 0xFF;
      tile[p + 2] = paint & 0xFF;
      tile[p + 3] = (outA * 255).round().clamp(0, 255);
      return;
    }
    // At full opacity a wash over paint of its own colour joins it: the
    // denser of the two shows and nothing deepens, so a flat area painted
    // in several strokes stays even.
    final join = opacity >= 250 ? _sameColourShare(before, p) : 0.0;
    if (join >= 1) {
      if (alpha <= b) {
        tile[p] = before[p];
        tile[p + 1] = before[p + 1];
        tile[p + 2] = before[p + 2];
        tile[p + 3] = before[p + 3];
      } else {
        tile[p] = paint >> 16 & 0xFF;
        tile[p + 1] = paint >> 8 & 0xFF;
        tile[p + 2] = paint & 0xFF;
        tile[p + 3] = (alpha * 255).round().clamp(0, 255);
      }
      return;
    }
    final share = (rate / 100).clamp(0.0, 1.0);
    final belowRgb = before[p] << 16 | before[p + 1] << 8 | before[p + 2];
    // The wash turns the colour under it towards the paint the way paint
    // mixes (yellow under a blue wash turns green). Wet into wet
    // (混色度合い) the two run together nearer to an even mix…
    final mixed = _mixer.mix(belowRgb, 1 - alpha * (1 - 0.5 * share));
    // …while a wash laid over dry paint is another transparent layer, which
    // deepens it: more for a dark paint, so a second wash of a colour is
    // deeper than the first.
    final deepen = 1 - alpha * (1 - share) * _depth;
    // Nearly the same colour: part of the way to joining.
    final joinedA = math.max(alpha, b);
    final finalA = outA + (joinedA - outA) * join;
    for (var c = 0; c < 3; c++) {
      final onPaint = linearFromSrgb8(mixed >> (16 - 8 * c)) * deepen;
      final premultiplied = b * onPaint + (1 - b) * alpha * paintLinear[c];
      final glazed = premultiplied / outA;
      final joined = alpha > b
          ? paintLinear[c]
          : linearFromSrgb8(before[p + c]);
      tile[p + c] = srgb8FromLinear(glazed + (joined - glazed) * join);
    }
    tile[p + 3] = (finalA * 255).round().clamp(0, 255);
  }

  /// How nearly the colour at [p] in [before] is the paint's own colour: 1
  /// within a few levels, 0 from a clearly different colour.
  double _sameColourShare(Uint8List before, int p) {
    final dr = (before[p] - (paint >> 16 & 0xFF)).abs();
    final dg = (before[p + 1] - (paint >> 8 & 0xFF)).abs();
    final db = (before[p + 2] - (paint & 0xFF)).abs();
    final d = math.max(dr, math.max(dg, db));
    return 1 - _smoothstep((d - 4) / 16);
  }
}

/// A Gaussian-like blur ([sigma] in pixels) of the [w]×[h] values in [src]:
/// three box blurs, on a coarser grid when [sigma] is large.
Float32List _blur(Float32List src, int w, int h, double sigma) {
  if (sigma < 0.5) return Float32List.fromList(src);
  final step = sigma > 12 ? math.min(8, (sigma / 6).floor()) : 1;
  if (step == 1) {
    final radius = math.max(1, (sigma - 0.3).round());
    final out = Float32List.fromList(src);
    final tmp = Float32List(w * h);
    for (var pass = 0; pass < 3; pass++) {
      _boxRows(out, tmp, w, h, radius);
      _boxColumns(tmp, out, w, h, radius);
    }
    return out;
  }
  final cw = (w + step - 1) ~/ step;
  final ch = (h + step - 1) ~/ step;
  final coarse = Float32List(cw * ch);
  for (var y = 0; y < h; y++) {
    final row = (y ~/ step) * cw;
    for (var x = 0; x < w; x++) {
      coarse[row + x ~/ step] += src[y * w + x];
    }
  }
  final cell = 1 / (step * step);
  for (var i = 0; i < coarse.length; i++) {
    coarse[i] *= cell;
  }
  final blurred = _blur(coarse, cw, ch, sigma / step);
  final out = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final fy = ((y + 0.5) / step - 0.5).clamp(0.0, ch - 1.0);
    final y0 = fy.floor();
    final y1 = math.min(ch - 1, y0 + 1);
    final ty = fy - y0;
    for (var x = 0; x < w; x++) {
      final fx = ((x + 0.5) / step - 0.5).clamp(0.0, cw - 1.0);
      final x0 = fx.floor();
      final x1 = math.min(cw - 1, x0 + 1);
      final tx = fx - x0;
      final top =
          blurred[y0 * cw + x0] +
          (blurred[y0 * cw + x1] - blurred[y0 * cw + x0]) * tx;
      final bottom =
          blurred[y1 * cw + x0] +
          (blurred[y1 * cw + x1] - blurred[y1 * cw + x0]) * tx;
      out[y * w + x] = top + (bottom - top) * ty;
    }
  }
  return out;
}

void _boxRows(Float32List src, Float32List dst, int w, int h, int r) {
  final scale = 1 / (2 * r + 1);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var sum = 0.0;
    for (var k = -r; k <= r; k++) {
      sum += src[row + k.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      dst[row + x] = sum * scale;
      sum +=
          src[row + math.min(w - 1, x + r + 1)] - src[row + math.max(0, x - r)];
    }
  }
}

void _boxColumns(Float32List src, Float32List dst, int w, int h, int r) {
  final scale = 1 / (2 * r + 1);
  for (var x = 0; x < w; x++) {
    var sum = 0.0;
    for (var k = -r; k <= r; k++) {
      sum += src[k.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      dst[y * w + x] = sum * scale;
      sum +=
          src[math.min(h - 1, y + r + 1) * w + x] -
          src[math.max(0, y - r) * w + x];
    }
  }
}

double _smoothstep(double x) {
  final v = x.clamp(0.0, 1.0);
  return v * v * (3 - 2 * v);
}

/// Smooth value noise in 0–1 at ([x], [y]) (lattice spacing 1).
double _valueNoise(double x, double y, int seed) {
  final xf = x.floorToDouble();
  final yf = y.floorToDouble();
  final xi = xf.toInt();
  final yi = yf.toInt();
  var fx = x - xf;
  var fy = y - yf;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  final a = _hash(xi, yi, seed);
  final b = _hash(xi + 1, yi, seed);
  final c = _hash(xi, yi + 1, seed);
  final d = _hash(xi + 1, yi + 1, seed);
  final top = a + (b - a) * fx;
  final bottom = c + (d - c) * fx;
  return top + (bottom - top) * fy;
}

/// Two octaves of [_valueNoise].
double _fractalNoise(double x, double y, int seed) =>
    _valueNoise(x, y, seed) * 0.65 +
    _valueNoise(x * 2.3 + 17.1, y * 2.3 + 5.3, seed + 1) * 0.35;

double _hash(int x, int y, int seed) {
  var h = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  h ^= h >> 16;
  return (h & 0xFFFFFF) / 0xFFFFFF;
}
