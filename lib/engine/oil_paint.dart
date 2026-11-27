import 'dart:math' as math;
import 'dart:typed_data';

import 'perceptual_color_mixer.dart';
import 'tile_manager.dart';

/// How much of the paint already on the layer oil laid at full opacity
/// covers: all of it (oil does not show through; at 95% the edge of what lay
/// under the stroke still showed). On an empty pixel the paint is as opaque
/// as the stroke.
const double kOilPaintCover = 1.0;

/// One stroke of 油彩風混色 (oil-style mixing): opaque paint from a loaded
/// brush.
///
/// The brush is a row of bristles across its width ([OilBristles]), each
/// holding a reservoir of paint that starts as the brush's own colour. Over
/// paint already on the layer each bristle picks some of it up — more with
/// 混色度合い, a little more with each step, so it takes the brush a while
/// to load up — and the paint it lays is its reservoir: the brush's colour
/// mixed with what it picked up the way paint mixes ([AnalogPaintMixer]; blue
/// that picked up yellow lays green), more of it the more loaded it is. Out on bare paper what it picked up
/// runs out over 色延び's length; over another colour it gives way to that
/// colour over three quarters as long (at once without 色延び), so the
/// colour picked up on one patch is dragged into the next and onto the
/// paper, fading. Bristles pick up and run out at slightly different rates,
/// so the dragged colour streaks along the stroke.
///
/// Oil does not show through: at full opacity the paint the bristle lays
/// covers what was there ([kOilPaintCover]). So where the brush has not
/// picked anything up yet it covers with its own colour, and the outline of
/// what lies under the stroke does not show through it; where it has, the
/// colour changes gradually along the stroke as it loads up. At a lowered
/// opacity the paint lays over what was there as usual.
///
/// A pixel's colour is laid over the layer as it was before the stroke (kept
/// per tile), never over what this stroke laid a moment earlier, so a pixel
/// covered by many overlapping dabs ends as if covered once: no line along
/// the middle where the dabs overlap most, and no arcs where their edges
/// were. Each pixel is laid when the brush first covers it and again as the
/// brush's centre passes it, so where the colour changes along the stroke it
/// changes straight across the stroke.

class OilStroke {
  OilStroke({required this.layerId, required int bristles, required int seed})
    : bristles = OilBristles(bristles, seed);

  final String layerId;

  /// What the brush carries now. The pixel mode keeps copies to go back to.
  OilBristles bristles;

  /// The tiles as they were before the stroke (premultiplied RGBA), by
  /// tile position.
  final Map<int, Uint8List> _before = {};

  static int _key(int tx, int ty) => tx << 20 | ty;

  /// How far a bristle moves over paint to pick up most of what it will
  /// hold (1 − 1/e of it): [pickWidths] of the width of a brush
  /// [pickWidth] pixels wide; further for a wider brush and less far for a
  /// narrower one, but less than in proportion (as the square root), so a
  /// wide brush still mixes within a patch of paint and a narrow one does
  /// not change colour in a few pixels.
  static const double pickWidths = 0.9;
  static const double pickWidth = 40;

  /// Remembers [tile] as it is before the stroke paints on it. Call before
  /// the first pixel of the tile changes.
  void touchTile(int tx, int ty, Uint8List tile) {
    _before.putIfAbsent(_key(tx, ty), () => Uint8List.fromList(tile));
  }

  /// The brush moves to ([x], [y]) with [radius]: each bristle picks up some
  /// of the paint that was under it before the stroke, or runs out of some
  /// of what it holds over bare paper. [direction] is the way the stroke
  /// goes there (radians), if known. [stretch] is 色延び (0–100) and [rate]
  /// 混色度合い (0–1); the brush's own colour is [paint] (0xRRGGBB), mixed
  /// by [mixer].
  void advance(
    TileManager tiles,
    double x,
    double y,
    double radius, {
    double? direction,
    required int stretch,
    required int paint,
    required double rate,
    required AnalogPaintMixer mixer,
  }) {
    final b = bristles;
    final lastX = b.lastX;
    final lastY = b.lastY;
    b.lastX = x;
    b.lastY = y;
    final moved = lastX == null || lastY == null
        ? 0.0
        : math.sqrt((x - lastX) * (x - lastX) + (y - lastY) * (y - lastY));
    b.moved = moved;
    b.stepX = lastX == null ? 0 : x - lastX;
    b.stepY = lastY == null ? 0 : y - lastY;
    b.lastNx = b.nx;
    b.lastNy = b.ny;
    var nx = b.nx;
    var ny = b.ny;
    if (direction != null) {
      nx = -math.sin(direction);
      ny = math.cos(direction);
    } else if (moved > 1e-6) {
      nx = -(y - lastY!) / moved;
      ny = (x - lastX!) / moved;
    }
    // Bristles keep their side of the brush when the stroke turns back.
    if (lastX != null && nx * b.nx + ny * b.ny < 0) {
      nx = -nx;
      ny = -ny;
    }
    b.nx = nx;
    b.ny = ny;
    final count = b.count;
    if (count == 0) return;
    if (b.paint != paint || b.rate != rate) {
      // What the bristles lay is worked out for another paint.
      b.paint = paint;
      b.rate = rate;
      b.under.fillRange(0, count, 0);
    }
    final width = math.max(1.0, radius * 2);
    // How far a bristle moves over paint to load up, how far what it picked
    // up lasts on bare paper (色延び; none at 0), and how far it lasts over
    // another colour.
    final pickLength = pickWidths * math.sqrt(width * pickWidth);
    final carry = stretch / 100 * 6 * width;
    final trade = carry * 0.75;
    final own0 = linearFromSrgb8(paint >> 16 & 0xFF);
    final own1 = linearFromSrgb8(paint >> 8 & 0xFF);
    final own2 = linearFromSrgb8(paint & 0xFF);
    final colour = b.colour;
    final amount = b.amount;
    final laid = b.laid;
    for (var j = 0; j < count; j++) {
      final s = ((j + 0.5) / count * 2 - 1) * radius;
      final sx = (x + nx * s).floor();
      final sy = (y + ny * s).floor();
      // The paint under the bristle before the stroke.
      final tile = _tileBefore(tiles, sx, sy);
      final i = _index;
      final a = tile == null ? 0 : tile[i + 3];
      final under = a / 255;
      final o = j * 3;
      if (a > 0) {
        // The brush's paint with as much of this mixed in as it picks up
        // here (混色度合い of it), worked out once for each paint below.
        final here =
            _straight(tile![i], a) << 16 |
            _straight(tile[i + 1], a) << 8 |
            _straight(tile[i + 2], a);
        final key = here << 8 | a;
        if (b.under[j] != key) {
          b.under[j] = key;
          final mixed = mixer.mixNear(here, rate * under, paint);
          laid[o] = linearFromSrgb8(mixed >> 16 & 0xFF);
          laid[o + 1] = linearFromSrgb8(mixed >> 8 & 0xFF);
          laid[o + 2] = linearFromSrgb8(mixed & 0xFF);
        }
        if (amount[j] < 1e-3) {
          // Nothing picked up yet: what it picks up is this.
          colour[o] = laid[o];
          colour[o + 1] = laid[o + 1];
          colour[o + 2] = laid[o + 2];
        } else if (moved > 0) {
          // What it picked up before gives way to this (at once without
          // 色延び).
          final give = trade <= 0
              ? under
              : (1 - math.exp(-moved * b.pickRate[j] / trade)) * under;
          colour[o] += (laid[o] - colour[o]) * give;
          colour[o + 1] += (laid[o + 1] - colour[o + 1]) * give;
          colour[o + 2] += (laid[o + 2] - colour[o + 2]) * give;
        }
      }
      if (moved > 0) {
        // Over paint the bristle loads up; over bare paper it runs out of
        // what it picked up.
        final load = 1 - math.exp(-moved * b.pickRate[j] / pickLength);
        final runOut = carry <= 0
            ? 1.0
            : 1 - math.exp(-moved * b.keepRate[j] / carry);
        final f = amount[j];
        amount[j] = f + (1 - f) * under * load - f * (1 - under) * runOut;
      }
      // It lays its own paint, as loaded as it is (in linear light).
      final f = amount[j];
      b.colour8[j] = f < 1 / 512
          ? paint
          : srgb8FromLinear(own0 + (colour[o] - own0) * f) << 16 |
                srgb8FromLinear(own1 + (colour[o + 1] - own1) * f) << 8 |
                srgb8FromLinear(own2 + (colour[o + 2] - own2) * f);
    }
  }

  /// The tile at ([x], [y]) as it was before the stroke (null for none or
  /// outside the canvas), with the pixel's index (of its red) into
  /// [_index].
  Uint8List? _tileBefore(TileManager tiles, int x, int y) {
    if (x < 0 || y < 0 || x >= tiles.canvasWidth || y >= tiles.canvasHeight) {
      return null;
    }
    const size = TileManager.tileSize;
    final tx = x ~/ size;
    final ty = y ~/ size;
    _index = ((y - ty * size) * size + (x - tx * size)) * 4;
    return _before[_key(tx, ty)] ?? tiles.getTile(layerId, tx, ty);
  }

  int _index = 0;

  static int _straight(int c, int a) =>
      a == 255 ? c : math.min(255, (c * 255 / a).round());

  /// Whether the dab centred at ([cx], [cy]) has just passed pixel
  /// ([x], [y]) (its centre, in canvas coordinates): the last dab that lays
  /// paint there before the brush leaves it.
  bool passes(double x, double y, double cx, double cy) {
    final b = bristles;
    if (b.moved <= 0) return false;
    // Along the stroke (the normal turned a quarter): behind this dab's
    // centre, and ahead of the last dab's. Measured against both, so on the
    // outside of a curve, where the two are further apart than the step,
    // no pixel is skipped.
    if ((x - cx) * b.ny - (y - cy) * b.nx > 0) return false;
    final lastX = cx - b.stepX;
    final lastY = cy - b.stepY;
    return (x - lastX) * b.lastNy - (y - lastY) * b.lastNx > 0;
  }

  /// Lays paint on pixel ([px], [py]) of tile ([tx], [ty]) by [alpha]
  /// (0–255, the most this stroke has covered it), over the layer as it was
  /// before the stroke: with [carry], the paint the bristle over the pixel
  /// lays (the dab is centred at ([cx], [cy]) with [radius]); otherwise
  /// [paint] (0xRRGGBB) as it is.
  void lay(
    Uint8List tile,
    int tx,
    int ty,
    int px,
    int py,
    int alpha,
    int paint, {
    required bool carry,
    required double cx,
    required double cy,
    required double radius,
  }) {
    final before = _before[_key(tx, ty)]!;
    const size = TileManager.tileSize;
    final i = (py * size + px) * 4;
    final belowAlpha = before[i + 3];
    var laid = paint;
    final b = bristles;
    if (carry && b.count > 0 && radius > 0) {
      final s =
          ((tx * size + px + 0.5) - cx) * b.nx +
          ((ty * size + py + 0.5) - cy) * b.ny;
      var j = ((s / radius + 1) * 0.5 * b.count).floor();
      if (j < 0) j = 0;
      if (j >= b.count) j = b.count - 1;
      laid = b.colour8[j];
    }
    // Over the layer as it was before the stroke (premultiplied), with the
    // paint that was there showing through by 1 − [kOilPaintCover].
    final a = alpha / 255;
    final outA = (alpha + belowAlpha * (1 - a)).round().clamp(0, 255);
    final own = a * (1 - (1 - kOilPaintCover) * belowAlpha / 255);
    final keep = 1 - a * kOilPaintCover;
    tile[i] = ((laid >> 16 & 0xFF) * own + before[i] * keep).round().clamp(
      0,
      outA,
    );
    tile[i + 1] = ((laid >> 8 & 0xFF) * own + before[i + 1] * keep)
        .round()
        .clamp(0, outA);
    tile[i + 2] = ((laid & 0xFF) * own + before[i + 2] * keep).round().clamp(
      0,
      outA,
    );
    tile[i + 3] = outA;
  }
}

/// The paint the bristles of an [OilStroke]'s brush hold, from one side of
/// the brush to the other.
class OilBristles {
  OilBristles(int count, int seed)
    : this._(
        count,
        Float64List(count * 3),
        Float64List(count),
        Int32List(count),
        Float64List(count * 3),
        Uint32List(count),
        _vary(count, seed, 0.6, 1.4),
        _vary(count, seed + 7, 0.75, 1.25),
      );

  OilBristles._(
    this.count,
    this.colour,
    this.amount,
    this.colour8,
    this.laid,
    this.under,
    this.pickRate,
    this.keepRate,
  );

  final int count;

  /// The colour each bristle lays once fully loaded with what it picked up:
  /// the brush's paint mixed with it (straight, in linear light, 3 per
  /// bristle).
  final Float64List colour;

  /// How loaded each bristle is with what it picked up (0–1; at 0 it lays
  /// the brush's own paint).
  final Float64List amount;

  /// The colour each bristle lays (0xRRGGBB).
  final Int32List colour8;

  /// The brush's paint mixed with the paint under each bristle (linear
  /// light, 3 per bristle), and that paint (0xRRGGBB << 8 | its alpha; 0 for
  /// none yet).
  final Float64List laid;
  final Uint32List under;

  /// The brush's colour (0xRRGGBB) and 混色度合い [laid] is for.
  int paint = -1;
  double rate = -1;

  /// How quickly each bristle picks paint up and runs out of it (around 1):
  /// bristles differ, so dragged paint streaks.
  final Float64List pickRate;
  final Float64List keepRate;

  double? lastX;
  double? lastY;

  /// How far the brush moved to its latest dab, and by how much on each
  /// axis.
  double moved = 0;
  double stepX = 0;
  double stepY = 0;

  /// [nx] and [ny] at the dab before.
  double lastNx = 0;
  double lastNy = 1;

  /// Across the brush (unit vector): where the bristles are.
  double nx = 0;
  double ny = 1;

  OilBristles copy() =>
      OilBristles._(
          count,
          Float64List.fromList(colour),
          Float64List.fromList(amount),
          Int32List.fromList(colour8),
          Float64List.fromList(laid),
          Uint32List.fromList(under),
          pickRate,
          keepRate,
        )
        ..paint = paint
        ..rate = rate
        ..lastX = lastX
        ..lastY = lastY
        ..moved = moved
        ..stepX = stepX
        ..stepY = stepY
        ..lastNx = lastNx
        ..lastNy = lastNy
        ..nx = nx
        ..ny = ny;

  /// The same brush holding only its own paint, before it has moved.
  OilBristles empty() => OilBristles._(
    count,
    Float64List(count * 3),
    Float64List(count),
    Int32List(count),
    Float64List(count * 3),
    Uint32List(count),
    pickRate,
    keepRate,
  );

  /// [count] values from [low] to [high], varying smoothly across the brush.
  static Float64List _vary(int count, int seed, double low, double high) {
    final out = Float64List(count);
    final spacing = math.max(1.5, count / 9);
    for (var j = 0; j < count; j++) {
      final t = j / spacing;
      final i = t.floor();
      var f = t - i;
      f = f * f * (3 - 2 * f);
      final a = _hash(i, seed);
      final c = _hash(i + 1, seed);
      out[j] = low + (high - low) * (a + (c - a) * f);
    }
    return out;
  }

  static double _hash(int i, int seed) {
    var h = (i * 374761393 + seed * 668265263) & 0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
    h ^= h >> 16;
    return (h & 0xFFFFFF) / 0xFFFFFF;
  }
}
