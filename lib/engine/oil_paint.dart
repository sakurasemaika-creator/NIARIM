import 'dart:math' as math;
import 'dart:typed_data';

import 'perceptual_color_mixer.dart';
import 'tile_manager.dart';

/// One stroke of 油彩風混色 (oil-style mixing).
///
/// Where the brush lays paint, its own colour mixes — the way paint mixes
/// ([AnalogPaintMixer]) — into the wet paint already there, by 混色度合い:
/// blue over yellow lays green.
///
/// The brush is also a row of bristles across its width ([OilBristles]).
/// Moving over paint, each bristle loads up with the paint the brush is
/// laying there (green, on the yellow), and it carries that paint on: into
/// the next colour, where it gives way to the paint the brush lays there
/// over part of 色延び's length, and out onto bare paper, where it runs out
/// over 色延び's length. Bristles load and run out at slightly different
/// rates, so dragged paint streaks along the stroke. Where the paint a
/// bristle carries differs from what the brush lays there, the two run
/// together (the carried paint, pressed on by the brush, counting for more).
///
/// A pixel's colour is worked out from the layer as it was before the stroke
/// (kept per tile), never by mixing again what this stroke laid a moment
/// earlier, so a pixel covered by many overlapping dabs ends as if covered
/// once: no line along the middle where the dabs overlap most, and no arcs
/// where their edges were. Each pixel is laid when the brush first covers
/// it and again as the brush's centre passes it, so where the colour
/// changes along the stroke it changes straight across the stroke.
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

  /// How much the paint a bristle carries counts against the same amount of
  /// paint already where it lays it.
  static const double _pressed = 2.0;

  /// Remembers [tile] as it is before the stroke paints on it. Call before
  /// the first pixel of the tile changes.
  void touchTile(int tx, int ty, Uint8List tile) {
    _before.putIfAbsent(_key(tx, ty), () => Uint8List.fromList(tile));
  }

  /// The brush moves to ([x], [y]) with [radius]: the bristles load up with
  /// the paint the brush has laid under them and run out of some of what
  /// they carry. [direction] is the way the stroke goes there (radians), if
  /// known. [stretch] is 色延び (0–100). Where the brush first lands, the
  /// bristles take up the paint it is about to lay: [paint] (0xRRGGBB)
  /// mixed by [mixer] into the paint there by [rate] (0–1).
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
    if (stretch <= 0 || count == 0) {
      // 色延び 0: nothing is carried; the brush only mixes where it is.
      b.amount.fillRange(0, count, 0);
      b.presence.fillRange(0, count, 0);
      return;
    }
    final width = math.max(1.0, radius * 2);
    // How far carried paint lasts out on paper, and how soon it gives way
    // to other paint the brush moves onto.
    final carry = stretch / 100 * 6 * width;
    final trade = carry * OilBristles.tradeShare;
    final first = lastX == null;
    final colour = b.colour;
    final amount = b.amount;
    final scratch = _scratch;
    if (b.paint != paint || b.rate != rate) {
      // What the brush lays on each colour has changed.
      b.paint = paint;
      b.rate = rate;
      b.under.fillRange(0, count, 0);
    }
    for (var j = 0; j < count; j++) {
      final s = ((j + 0.5) / count * 2 - 1) * radius;
      final sx = (x + nx * s).floor();
      final sy = (y + ny * s).floor();
      // The paint there before the stroke, and what the brush lays on it
      // (the same as at the bristle's last dab, mostly).
      final tile = _tileBefore(tiles, sx, sy);
      final i = _index;
      final a = tile == null ? 0 : tile[i + 3];
      final o = j * 3;
      if (a > 0) {
        final here =
            _straight(tile![i], a) << 16 |
            _straight(tile[i + 1], a) << 8 |
            _straight(tile[i + 2], a) |
            a << 24;
        if (here != b.under[j] || first) {
          final laid = mixer.mixNear(here & 0xFFFFFF, rate * a / 255, paint);
          b.under[j] = here;
          scratch[0] = linearFromSrgb8(laid >> 16 & 0xFF);
          scratch[1] = linearFromSrgb8(laid >> 8 & 0xFF);
          scratch[2] = linearFromSrgb8(laid & 0xFF);
          b.laid[o] = scratch[0];
          b.laid[o + 1] = scratch[1];
          b.laid[o + 2] = scratch[2];
        }
      }
      if (first) {
        // The brush lands on paint: it is already wet with what it lays.
        if (a > 0) {
          colour[o] = b.laid[o];
          colour[o + 1] = b.laid[o + 1];
          colour[o + 2] = b.laid[o + 2];
          amount[j] = a / 255 * b.settled(j);
        }
      } else {
        if (a > 0) {
          // Trade carried paint for the paint the brush lays here.
          final pick = 1 - math.exp(-moved * b.pickRate[j] / trade);
          final underAlpha = a / 255;
          final keepShare = amount[j] * (1 - pick);
          final takeShare = underAlpha * pick;
          final sum = keepShare + takeShare;
          if (sum > 1e-9) {
            final k = keepShare / sum;
            final t = takeShare / sum;
            colour[o] = colour[o] * k + b.laid[o] * t;
            colour[o + 1] = colour[o + 1] * k + b.laid[o + 1] * t;
            colour[o + 2] = colour[o + 2] * k + b.laid[o + 2] * t;
          }
          if (underAlpha > amount[j]) {
            amount[j] += (underAlpha - amount[j]) * pick;
          }
        }
        amount[j] *= math.exp(-moved * b.keepRate[j] / carry);
      }
      final presence = amount[j] / b.settled(j);
      b.presence[j] = presence >= 1 ? 1.0 : presence;
      b.colour8[j] =
          srgb8FromLinear(colour[o]) << 16 |
          srgb8FromLinear(colour[o + 1]) << 8 |
          srgb8FromLinear(colour[o + 2]);
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

  /// Lays the brush's paint on pixel ([px], [py]) of tile ([tx], [ty]) by
  /// [alpha] (0–255, the most this stroke has covered it): [paint]
  /// (0xRRGGBB) mixed by [mixer] into the paint there before the stroke by
  /// [rate] (0–1). With [carry] the paint the bristle over the pixel
  /// carries (the dab is centred at ([cx], [cy]) with [radius]) runs into
  /// it.
  void lay(
    Uint8List tile,
    int tx,
    int ty,
    int px,
    int py,
    int alpha,
    double rate,
    int paint,
    AnalogPaintMixer mixer, {
    required bool carry,
    required double cx,
    required double cy,
    required double radius,
  }) {
    final before = _before[_key(tx, ty)]!;
    const size = TileManager.tileSize;
    final i = (py * size + px) * 4;
    final belowAlpha = before[i + 3];
    var mixed = paint;
    if (belowAlpha > 0 && rate > 0) {
      mixed = mixer.mixNear(
        _straight(before[i], belowAlpha) << 16 |
            _straight(before[i + 1], belowAlpha) << 8 |
            _straight(before[i + 2], belowAlpha),
        rate * belowAlpha / 255,
        paint,
      );
    }
    final b = bristles;
    if (carry && b.count > 0 && radius > 0) {
      final s =
          ((tx * size + px + 0.5) - cx) * b.nx +
          ((ty * size + py + 0.5) - cy) * b.ny;
      var j = ((s / radius + 1) * 0.5 * b.count).floor();
      if (j < 0) j = 0;
      if (j >= b.count) j = b.count - 1;
      final carried = b.presence[j];
      if (carried > 1 / 256 && b.colour8[j] != mixed) {
        // Over bare paper the carried paint and the brush's own share the
        // pixel by how much is carried; over paint the carried paint is
        // pressed into it.
        final share = belowAlpha == 0
            ? carried
            : carried * _pressed / (carried * _pressed + belowAlpha / 255);
        final o = j * 3;
        final colour = b.colour;
        final r = linearFromSrgb8(mixed >> 16 & 0xFF);
        final g = linearFromSrgb8(mixed >> 8 & 0xFF);
        final bl = linearFromSrgb8(mixed & 0xFF);
        mixed =
            srgb8FromLinear(r + (colour[o] - r) * share) << 16 |
            srgb8FromLinear(g + (colour[o + 1] - g) * share) << 8 |
            srgb8FromLinear(bl + (colour[o + 2] - bl) * share);
      }
    }
    // Over the layer as it was before the stroke (premultiplied).
    final a = alpha / 255;
    final keep = 1 - a;
    final outA = (alpha + belowAlpha * keep).round().clamp(0, 255);
    tile[i] = ((mixed >> 16 & 0xFF) * a + before[i] * keep).round().clamp(
      0,
      outA,
    );
    tile[i + 1] = ((mixed >> 8 & 0xFF) * a + before[i + 1] * keep)
        .round()
        .clamp(0, outA);
    tile[i + 2] = ((mixed & 0xFF) * a + before[i + 2] * keep).round().clamp(
      0,
      outA,
    );
    tile[i + 3] = outA;
  }
}

/// The paint the bristles of an [OilStroke]'s brush carry, from one side of
/// the brush to the other.
class OilBristles {
  OilBristles(int count, int seed)
    : this._(
        count,
        Float64List(count * 3),
        Float64List(count),
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
    this.presence,
    this.colour8,
    this.laid,
    this.under,
    this.pickRate,
    this.keepRate,
  );

  /// What share of 色延び's length carried paint lasts over other paint (it
  /// gives way to the paint laid there), against bare paper.
  static const double tradeShare = 0.75;

  final int count;

  /// The carried paint's straight colour in linear light, 3 per bristle.
  final Float64List colour;

  /// How much paint each bristle carries (0–1).
  final Float64List amount;

  /// [amount] against what the bristle holds after moving over solid paint
  /// for a while (0–1): how much the carried paint counts.
  final Float64List presence;

  /// [colour] as 0xRRGGBB.
  final Int32List colour8;

  /// What the brush lays where each bristle is (straight colour in linear
  /// light, 3 per bristle), and the paint there before the stroke it was
  /// worked out for (0xAARRGGBB, 0 for none yet).
  final Float64List laid;
  final Uint32List under;

  /// The brush's colour (0xRRGGBB) and 混色度合い (0–1) [laid] is for.
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

  /// How much bristle [j] carries after moving over solid paint for a while.
  double settled(int j) =>
      pickRate[j] / (pickRate[j] + tradeShare * keepRate[j]);

  OilBristles copy() =>
      OilBristles._(
          count,
          Float64List.fromList(colour),
          Float64List.fromList(amount),
          Float64List.fromList(presence),
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

  /// The same brush carrying nothing, before it has moved.
  OilBristles empty() => OilBristles._(
    count,
    Float64List(count * 3),
    Float64List(count),
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

final Float64List _scratch = Float64List(3);
