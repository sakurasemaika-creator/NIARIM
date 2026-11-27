import 'dart:math' as math;
import 'dart:typed_data';

import 'perceptual_color_mixer.dart';
import 'tile_manager.dart';

/// One stroke of 水彩風混色 (watercolour-style mixing).
///
/// While the stroke is drawn, each pixel the brush covers shows a wash of
/// the paint over the layer as it was before the stroke (the stroke never
/// builds up on itself, like one wet wash). On white paper, at full opacity
/// and the default 水分量 and 絵具量, the wash is the chosen colour: the
/// paper's grain and the blotches where the pigment settled unevenly vary
/// it both ways, a little lighter where the pigment is thin and a richer,
/// darker shade of the same colour where it pooled, so on average it stays
/// the chosen colour. More water thins it (paler, more see-through) and
/// less pigment too; less water and more pigment make it a little denser.
/// When the stroke ends ([finish]) the wash "dries": the pigment spreads
/// past the brush with a ragged edge. The darker rim a dried wash leaves is
/// the 水彩境界 draw filter's, so it can be tuned after painting.
///
/// 水分量 sets how wet the whole wash is: with more water it is paler, runs
/// further into the colours under it, spreads further past the brush as it
/// dries (with にじみ setting how far and how raggedly the water carries
/// it), dries with a softer edge (on top of 境界のぼかし) and is blotchier;
/// with little water it is crisp, hard-edged, stays where the brush went
/// and keeps nearer its own colour over other paint.
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
/// Tiles hold premultiplied RGBA (as they are drawn as images). The wash is
/// worked out on straight colours: the tile before the stroke is kept both
/// as it was (to put back untouched pixels exactly) and divided back by its
/// alpha, and each result is multiplied by its alpha as it is written.
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
    _paintLog = Float64List.fromList([
      for (var c = 0; c < 3; c++) math.log(lut[c]),
    ]);
    _paintLuminance = _luminanceOf(lut[0], lut[1], lut[2]);
    _depth = 0.45 * (1 - math.sqrt(_paintLuminance));
    // The channel the paint absorbs most (to tell how dense a wash of it
    // is), if it absorbs any clearly.
    var k = 0;
    for (var c = 1; c < 3; c++) {
      if (lut[c] < lut[k]) k = c;
    }
    _absorbing = lut[k] < 0.8 && lut[k] > 0 ? k : -1;
    _logAbsorbing = _absorbing < 0 ? 0 : math.log(lut[k]);
    // The paint at each density from 1 (the chosen colour) to the densest:
    // each channel raised to that power.
    final steps = ((_maxDensity - 1) * _deepSteps).round();
    _deepLinear = Float64List((steps + 1) * 3);
    _deep8 = Int32List(steps + 1);
    for (var i = 0; i <= steps; i++) {
      final d = 1 + i / _deepSteps;
      var rgb = 0;
      for (var c = 0; c < 3; c++) {
        final v = i == 0 ? lut[c] : math.exp(_paintLog[c] * d);
        _deepLinear[i * 3 + c] = v;
        rgb =
            rgb << 8 |
            (i == 0 ? paint >> (16 - 8 * c) & 0xFF : srgb8FromLinear(v));
      }
      _deep8[i] = rgb;
    }
    final w = _water;
    _density = _densityFor(w, _pigment);
    _merge = 0.3 + 0.4 * w;
    _bloom = 0.6 * _smoothstep((w - 0.5) / 0.5);
  }

  /// How dense a wash of [water] and [pigment] (0–1) is before texture, as
  /// a share of the chosen colour (1 at the defaults: the chosen colour on
  /// white paper). More water thins it, down to 0.4 at the most; less water
  /// makes it a little denser (1.1 at none). Less pigment thins it, more a
  /// little denser.
  static double _densityFor(double water, double pigment) {
    final wet = water <= 0.5
        ? 1.1 - 0.2 * water
        : 1.0 - 0.6 * math.pow((water - 0.5) / 0.5, 1.2);
    final paint = pigment >= 0.6
        ? 1 + 0.25 * (pigment - 0.6) / 0.4
        : 0.25 + 0.75 * math.pow(pigment / 0.6, 0.8);
    return wet * paint;
  }

  static double _luminanceOf(double r, double g, double b) =>
      0.2126 * r + 0.7152 * g + 0.0722 * b;

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

  /// The log of each channel of the paint in linear light, to raise it to a
  /// power.
  late final Float64List _paintLog;

  /// The paint at densities from 1 up, [_deepSteps] steps per unit: linear
  /// light (3 per step) and as 0xRRGGBB (step 0 is the paint itself).
  late final Float64List _deepLinear;
  late final Int32List _deep8;
  static const int _deepSteps = 128;

  /// [_joinShare]'s answers (share, and the density in [_joinedDensities])
  /// by the colour before the stroke (0xRRGGBBAA): a wash goes over few
  /// different colours, each many times.
  final Map<int, double> _joinShares = {};
  final Map<int, double> _joinedDensities = {};

  /// How much one layer of this paint deepens what is under it.
  late final double _depth;
  late final double _paintLuminance;

  /// The channel the paint absorbs most (-1 if it hardly absorbs any), and
  /// the log of the paint's linear value there.
  late final int _absorbing;
  late final double _logAbsorbing;

  /// How dense one wash is before texture (1 is the chosen colour on white
  /// paper; more is a deeper shade of it, less paler).
  late final double _density;

  /// How readily the wash runs into the paint under it rather than lying
  /// over it (0–1, from the water).
  late final double _merge;

  /// How much softer the water makes the dried edge (0–0.6).
  late final double _bloom;

  /// The density of the paint [_joinShare] last looked at.
  double _joinedDensity = 0;

  /// Per tile ("tx:ty"): the tile before the stroke, how much the brush
  /// covered (0–255), its mixing rate (0–100) and its opacity (0–255)
  /// there.
  final Map<String, Uint8List> _before = {};
  final Map<String, Uint8List> _beforeRaw = {};
  final Map<String, Uint8List> _coverage = {};
  final Map<String, Uint8List> _rate = {};
  final Map<String, Uint8List> _opacity = {};

  /// Per tile: [_texture] at each pixel, once worked out (−1 before).
  final Map<String, Float32List> _textures = {};
  var _lastRate = 0;
  var _lastOpacity = 255;
  var _minX = 1 << 30;
  var _minY = 1 << 30;
  var _maxX = -1;
  var _maxY = -1;

  static const int _size2 = TileManager.tileSize * TileManager.tileSize;

  /// Remembers [tile] as it is before the stroke paints on it. Call before
  /// the first pixel of the tile changes.
  void touchTile(int tx, int ty, Uint8List tile) {
    final key = '$tx:$ty';
    if (_before.containsKey(key)) return;
    _beforeRaw[key] = Uint8List.fromList(tile);
    final straight = Uint8List.fromList(tile);
    for (var p = 0; p < straight.length; p += 4) {
      final a = straight[p + 3];
      if (a == 0 || a == 255) continue;
      for (var c = 0; c < 3; c++) {
        straight[p + c] = (straight[p + c] * 255 / a).round().clamp(0, 255);
      }
    }
    _before[key] = straight;
    _coverage[key] = Uint8List(_size2);
    _rate[key] = Uint8List(_size2);
    _opacity[key] = Uint8List(_size2);
    _textures[key] = Float32List(_size2)..fillRange(0, _size2, -1);
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
    final density =
        coverage / 255 * _density * _textureAt(_textures[key]!, pos, x, y);
    _composite(
      tile,
      before,
      _beforeRaw[key]!,
      pos * 4,
      density.clamp(0.0, _maxDensity),
      rate,
      opacity,
    );
  }

  /// What [cover] last recorded at pixel [pos] of tile ([tx], [ty]):
  /// coverage, mixing rate and opacity in one int (null before the tile is
  /// touched). [restorePixel] puts it back, for a pixel painted for a
  /// moment and then taken back.
  int? pixelState(int tx, int ty, int pos) {
    final key = '$tx:$ty';
    final coverage = _coverage[key];
    if (coverage == null) return null;
    return coverage[pos] | _rate[key]![pos] << 8 | _opacity[key]![pos] << 16;
  }

  void restorePixel(int tx, int ty, int pos, int state) {
    final key = '$tx:$ty';
    final coverage = _coverage[key];
    if (coverage == null) return;
    coverage[pos] = state & 0xFF;
    _rate[key]![pos] = state >> 8 & 0xFF;
    _opacity[key]![pos] = state >> 16 & 0xFF;
  }

  /// Dries the stroke: spreads it past the brush with a ragged edge.
  /// Returns the tiles it changed (as "tx:ty") so they can be redrawn.
  Set<String> finish(TileManager tiles) {
    final changed = <String>{};
    if (_maxX < _minX) return changed;
    const tileSize = TileManager.tileSize;
    // How soft the dried edge is, 0–1: from 境界のぼかし and the water.
    final soft = 1 - (1 - _soft) * (1 - _bloom / 0.6);
    // The water carries the wash past the brush (only to the paper's tooth
    // without water); にじみ sets how far it gets, and 境界のぼかし lets it
    // run on as far as a damp sheet would.
    final spread = math.max(
      math.max(1.5, _size * 0.3 * _soft),
      _size * (0.01 + 0.22 * math.pow(_water, 1.5) * (0.3 + 1.4 * _bleed)),
    );
    final margin = (math.max(spread, _runReach) * 2.5 + 2).ceil();
    final left = math.max(0, _minX - margin);
    final top = math.max(0, _minY - margin);
    final right = math.min(tiles.canvasWidth - 1, _maxX + margin);
    final bottom = math.min(tiles.canvasHeight - 1, _maxY + margin);
    if (right < left || bottom < top) return changed;
    final w = right - left + 1;
    final h = bottom - top + 1;

    // Where the brush went, 0–1, whatever its opacity (the water spreads
    // a wash laid at a lowered opacity as far, but no denser than it was).
    final covered = Float32List(w * h);
    for (final entry in _coverage.entries) {
      final parts = entry.key.split(':');
      final ox = int.parse(parts[0]) * tileSize;
      final oy = int.parse(parts[1]) * tileSize;
      final cov = entry.value;
      final opacity = _opacity[entry.key]!;
      final y0 = math.max(top, oy);
      final y1 = math.min(bottom, oy + tileSize - 1);
      final x0 = math.max(left, ox);
      final x1 = math.min(right, ox + tileSize - 1);
      for (var y = y0; y <= y1; y++) {
        final row = (y - oy) * tileSize - ox;
        final out = (y - top) * w - left;
        for (var x = x0; x <= x1; x++) {
          final c = cov[row + x];
          if (c != 0) {
            covered[out + x] = math.min(1.0, c / math.max(1, opacity[row + x]));
          }
        }
      }
    }

    // The water carries pigment a little past the brush; how far varies
    // along the edge, which makes it ragged rather than a blurred circle.
    final wet = _blur(covered, w, h, spread);
    final amount = Float32List(w * h);
    final reachScale = _size * 0.3;
    // How far the water's reach wanders along the edge: barely with little
    // water (a crisp edge, only following the paper's tooth), into broad
    // irregular lobes with much (and more with more にじみ).
    final lobes = (0.06 + 0.3 * _water) * (0.5 + _bleed);
    // The paper's tooth (none on paper without texture, むら 0).
    final tooth = 0.35 * math.min(1.0, _textureAmount);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final c = covered[i];
        // Too little water reaches here to carry pigment, whatever the edge
        // does (the reach below is at most 1.6, the threshold at least
        // 0.06).
        if (wet[i] < 0.035) {
          amount[i] = c * (1 - soft);
          continue;
        }
        final wx = left + x;
        final wy = top + y;
        // The edge wanders only near the edge: well inside, the wash is
        // whole.
        final whole = _smoothstep((wet[i] - 0.5) / 0.45);
        var reach = 0.85 + 0.15 * whole;
        if (whole < 1) {
          reach +=
              (lobes *
                      (_fractalNoise(
                            wx / reachScale,
                            wy / reachScale,
                            seed + 17,
                          ) -
                          0.5) *
                      2 +
                  tooth * _paperGrain(wx, wy)) *
              (1 - whole);
        }
        // Where the water stops, the wash ends in an edge that follows the
        // paper and the water's reach, not an even fade: crisp with little
        // water, and with much (or 境界のぼかし) a soft, uneven bleed that
        // thins the wash on both sides of where the brush went, as wet-in-wet
        // paint does.
        final spreadOut = _smoothstep(
          (wet[i] * reach - (0.16 - 0.1 * soft)) / (0.26 + 0.5 * soft),
        );
        amount[i] = math.max(
          c * (1 - soft),
          spreadOut * math.min(1.0, wet[i] * (2.5 + 1.5 * soft)),
        );
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
        final raw = _beforeRaw[key]!;
        final rates = _rate[key]!;
        final opacities = _opacity[key]!;
        final textures = _textures[key]!;
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            final i = (y - top) * w + x - left;
            final pos = (y - oy) * tileSize + (x - ox);
            final a = amount[i];
            if (a <= 0.004) {
              // Untouched by the wash: as before the stroke.
              final p = pos * 4;
              tile[p] = raw[p];
              tile[p + 1] = raw[p + 1];
              tile[p + 2] = raw[p + 2];
              tile[p + 3] = raw[p + 3];
              continue;
            }
            final brushed = rates[pos] != 0 || covered[i] > 0;
            final opacity = brushed ? opacities[pos] : _lastOpacity;
            final density =
                a * opacity / 255 * _density * _textureAt(textures, pos, x, y);
            _composite(
              tile,
              before,
              raw,
              pos * 4,
              density.clamp(0.0, _maxDensity),
              brushed ? rates[pos] : _lastRate,
              opacity,
            );
          }
        }
        tiles.markDirty(layerId, tx, ty);
        changed.add(key);
      }
    }
    _runTogether(tiles, amount, left, top, w, h, changed);
    return changed;
  }

  /// How far (px, a blur's sigma) the colours in the wet wash run into each
  /// other as it dries: more with more water.
  double get _runReach => _size * (0.03 + 0.45 * math.pow(_water, 1.3));

  /// Where the wet wash holds different colours side by side (the paint
  /// over the yellow next to the paint over bare paper, say), or meets
  /// other paint at its edge, they run into each other while it dries, like
  /// dyes in water: a soft, slightly irregular blend instead of a hard
  /// boundary. Only where the wash is wet ([wet], over the [w]×[h] area at
  /// ([left], [top])) and a little way into the paint around it, and only
  /// on paint (nothing spreads onto bare paper, which is the bloom's part);
  /// how far and how much it runs grows with the water. Where neighbouring
  /// pixels are the same colour (the paper's grain, the blotches) nothing
  /// changes, so the texture stays crisp. Adds the tiles it changes to
  /// [changed].
  void _runTogether(
    TileManager tiles,
    Float32List amount,
    int left,
    int top,
    int w,
    int h,
    Set<String> changed,
  ) {
    final reach = _runReach;
    if (reach < 0.75) return;
    // The colours run together smoothly, so how they spread is worked out on
    // cells about two thirds as wide as they run, and read back only where
    // the wash is wet.
    final cell = math.max(2, (reach / 1.5).round());
    final cw = (w + cell - 1) ~/ cell;
    final ch = (h + cell - 1) ~/ cell;
    final cells = cw * ch;
    final perCell = 1 / (cell * cell);
    final cellReach = reach / cell;
    // The water wicks a little way into the paint around the wash.
    final cellAmount = Float32List(cells);
    for (var y = 0; y < h; y++) {
      final row = (y ~/ cell) * cw;
      final from = y * w;
      for (var x = 0; x < w; x++) {
        final a = amount[from + x];
        if (a != 0) cellAmount[row + x ~/ cell] += a * perCell;
      }
    }
    final wicked = _blur(cellAmount, cw, ch, cellReach);
    final wet = Float32List(w * h);
    var anyWet = false;
    for (var y = 0; y < h; y++) {
      final cellRow = (y ~/ cell) * cw;
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        // Far from any wash: dry (the nearest cell and its neighbours have
        // no water at all).
        if (amount[i] == 0 && wicked[cellRow + x ~/ cell] <= 1e-6) continue;
        final around = _sampleCells(wicked, cw, ch, cell, x, y);
        final value = math.max(amount[i], math.min(1.0, around * 1.6));
        if (value > 0.004) {
          wet[i] = value;
          anyWet = true;
        }
      }
    }
    if (!anyWet) return;
    final share = 0.35 + 0.55 * _water;
    const tileSize = TileManager.tileSize;
    // The colours there, in linear light, weighted by how wet and how dense
    // each pixel is, summed per cell.
    final cellRed = Float32List(cells);
    final cellGreen = Float32List(cells);
    final cellBlue = Float32List(cells);
    final cellWeight = Float32List(cells);
    var cachedTx = -1, cachedTy = -1;
    Uint8List? cached;
    Uint8List? tileAt(int cx, int cy) {
      final tx = cx ~/ tileSize, ty = cy ~/ tileSize;
      if (tx != cachedTx || ty != cachedTy) {
        cachedTx = tx;
        cachedTy = ty;
        cached = tiles.getTile(layerId, tx, ty);
      }
      return cached;
    }

    // Lowest and highest share of each channel in the colours there: if
    // they hardly differ, nothing can run together.
    var low0 = 1.0, low1 = 1.0, low2 = 1.0;
    var high0 = 0.0, high1 = 0.0, high2 = 0.0;
    for (var y = 0; y < h; y++) {
      final cy = top + y;
      final row = (y ~/ cell) * cw;
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final wetHere = wet[i];
        if (wetHere == 0) continue;
        final cx = left + x;
        final tile = tileAt(cx, cy);
        if (tile == null) {
          wet[i] = 0;
          continue;
        }
        final p = ((cy % tileSize) * tileSize + cx % tileSize) * 4;
        final a = tile[p + 3];
        if (a == 0) {
          // Bare paper: nothing to run together with.
          wet[i] = 0;
          continue;
        }
        final r = linearFromSrgb8(_straight(tile[p], a));
        final g = linearFromSrgb8(_straight(tile[p + 1], a));
        final b = linearFromSrgb8(_straight(tile[p + 2], a));
        final weightHere = wetHere * a / 255 * perCell;
        final c = row + x ~/ cell;
        cellRed[c] += r * weightHere;
        cellGreen[c] += g * weightHere;
        cellBlue[c] += b * weightHere;
        cellWeight[c] += weightHere;
        final sum = r + g + b;
        if (sum > 1e-6) {
          final s0 = r / sum, s1 = g / sum, s2 = b / sum;
          if (s0 < low0) low0 = s0;
          if (s0 > high0) high0 = s0;
          if (s1 < low1) low1 = s1;
          if (s1 > high1) high1 = s1;
          if (s2 < low2) low2 = s2;
          if (s2 > high2) high2 = s2;
        }
      }
    }
    if (high0 - low0 <= 0.04 && high1 - low1 <= 0.04 && high2 - low2 <= 0.04) {
      return;
    }
    final redAround = _blur(cellRed, cw, ch, cellReach);
    final greenAround = _blur(cellGreen, cw, ch, cellReach);
    final blueAround = _blur(cellBlue, cw, ch, cellReach);
    final weightAround = _blur(cellWeight, cw, ch, cellReach);
    final noiseScale = reach * 2;
    final writable = <int, Uint8List>{};
    cachedTx = -1;
    for (var y = 0; y < h; y++) {
      final cy = top + y;
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final wetHere = wet[i];
        if (wetHere == 0) continue;
        final around = _sampleCells(weightAround, cw, ch, cell, x, y);
        if (around < 1e-9) continue;
        final cx = left + x;
        final tile = tileAt(cx, cy)!;
        final p = ((cy % tileSize) * tileSize + cx % tileSize) * 4;
        final a = tile[p + 3];
        final r = linearFromSrgb8(_straight(tile[p], a));
        final g = linearFromSrgb8(_straight(tile[p + 1], a));
        final b = linearFromSrgb8(_straight(tile[p + 2], a));
        final ar = _sampleCells(redAround, cw, ch, cell, x, y) / around;
        final ag = _sampleCells(greenAround, cw, ch, cell, x, y) / around;
        final ab = _sampleCells(blueAround, cw, ch, cell, x, y) / around;
        // How different a colour (not how light or dark) is nearby.
        final sum = r + g + b;
        final sumAround = ar + ag + ab;
        if (sum <= 1e-6 || sumAround <= 1e-6) continue;
        final difference = math.max(
          (r / sum - ar / sumAround).abs(),
          math.max(
            (g / sum - ag / sumAround).abs(),
            (b / sum - ab / sumAround).abs(),
          ),
        );
        if (difference <= 0.04) continue;
        var mix =
            math.min(1.0, wetHere) *
            share *
            _smoothstep((difference - 0.04) / 0.16);
        if (mix <= 0.002) continue;
        mix *=
            0.55 +
            0.45 * _fractalNoise(cx / noiseScale, cy / noiseScale, seed + 41);
        // Written through the tile manager, so undo keeps the tile as it
        // was before the stroke and the tile is redrawn.
        final tx = cx ~/ tileSize;
        final ty = cy ~/ tileSize;
        final target = writable[tx << 16 | ty] ??= () {
          final writing = tiles.getOrCreateTile(layerId, tx, ty);
          tiles.markDirty(layerId, tx, ty);
          changed.add('$tx:$ty');
          return writing;
        }();
        _put(
          target,
          p,
          srgb8FromLinear(r + (ar - r) * mix),
          srgb8FromLinear(g + (ag - g) * mix),
          srgb8FromLinear(b + (ab - b) * mix),
          a / 255,
        );
      }
    }
  }

  /// [cells] ([cw]×[ch], each [cell] pixels wide) read at pixel ([x],
  /// [y]): between the four nearest cell centres.
  static double _sampleCells(
    Float32List cells,
    int cw,
    int ch,
    int cell,
    int x,
    int y,
  ) {
    var fx = (x + 0.5) / cell - 0.5;
    var fy = (y + 0.5) / cell - 0.5;
    if (fx < 0) fx = 0;
    if (fy < 0) fy = 0;
    if (fx > cw - 1) fx = cw - 1.0;
    if (fy > ch - 1) fy = ch - 1.0;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1 < cw ? x0 + 1 : x0;
    final y1 = y0 + 1 < ch ? y0 + 1 : y0;
    final tx = fx - x0;
    final ty = fy - y0;
    final top =
        cells[y0 * cw + x0] + (cells[y0 * cw + x1] - cells[y0 * cw + x0]) * tx;
    final bottom =
        cells[y1 * cw + x0] + (cells[y1 * cw + x1] - cells[y1 * cw + x0]) * tx;
    return top + (bottom - top) * ty;
  }

  static int _straight(int c, int a) =>
      a == 255 ? c : math.min(255, (c * 255 / a).round());

  /// [_texture] at pixel [pos] of a tile at canvas ([x], [y]), worked out
  /// once ([cache] holds −1 until then): a soft brush covers a pixel a
  /// little more at each of many dabs.
  double _textureAt(Float32List cache, int pos, int x, int y) {
    final cached = cache[pos];
    if (cached >= 0) return cached;
    final texture = _texture(x, y);
    cache[pos] = texture;
    return texture;
  }

  /// The densest a wash gets (where blotches pool on top of a dense wash).
  static const double _maxDensity = 3.0;

  /// Paper grain and the uneven settling of the pigment in its blotches,
  /// both fixed to the canvas (as the paper's sizing is), so washes of the
  /// same colour laid side by side join without a seam. Around 1 on
  /// average: thinner and denser in about equal measure.
  double _texture(int x, int y) {
    final grain = _paperGrain(x, y);
    // A dried wash is a little uneven over wide areas: a faint, broad
    // variation (more with more water), not patches.
    final blotchScale = math.max(
      24.0,
      _size * 1.6 / math.max(1.0, _textureAmount),
    );
    final blotch =
        (_fractalNoise(x / blotchScale, y / blotchScale, 13) - 0.5) * 2;
    final amount = _textureAmount;
    // (むら past its default brings the variation up faster and closer
    // together, to blotches at the most.)
    return math.max(
      0.0,
      (1 + (0.08 + 0.08 * _pigment) * grain * 2 * amount) *
          (1 + (0.05 + 0.12 * _water) * blotch * amount * amount),
    );
  }

  /// The paper's grain at canvas pixel ([x], [y]), −0.5 to 0.5: where its
  /// tooth holds more pigment (granulation) and where a wash's edge reaches.
  static double _paperGrain(int x, int y) =>
      (_valueNoise(x / 2.1, y / 2.1, 7) * 0.4 +
          _valueNoise(x / 5.2, y / 5.2, 11) * 0.6) -
      0.5;

  /// Writes the straight colour ([r], [g], [b]) at [alpha] (0–1) as the
  /// tile's premultiplied pixel at [p].
  static void _put(Uint8List tile, int p, int r, int g, int b, double alpha) {
    final a = (alpha * 255).round().clamp(0, 255);
    tile[p] = (r * a / 255).round().clamp(0, a);
    tile[p + 1] = (g * a / 255).round().clamp(0, a);
    tile[p + 2] = (b * a / 255).round().clamp(0, a);
    tile[p + 3] = a;
  }

  /// Lays a wash of [density] (1: the chosen colour on white paper) over
  /// the pixel at [p] as it was [before] the stroke (straight colours;
  /// [raw] is the same tile as it was), at the brush's [opacity] (0–255).
  void _composite(
    Uint8List tile,
    Uint8List before,
    Uint8List raw,
    int p,
    double density,
    int rate,
    int opacity,
  ) {
    if (density <= 0) {
      tile[p] = raw[p];
      tile[p + 1] = raw[p + 1];
      tile[p + 2] = raw[p + 2];
      tile[p + 3] = raw[p + 3];
      return;
    }
    final b = before[p + 3] / 255;
    // Up to the chosen colour the wash covers part of the pixel; past it,
    // more pigment is a deeper shade of the colour: each channel raised to
    // a power above 1, as a second layer of the same paint does (richer,
    // not greyer, and white stays white).
    final alpha = density < 1 ? density : 1.0;
    // The deeper shade, from a table of 128 steps per unit of density.
    final step = density > 1 ? ((density - 1) * _deepSteps).round() : 0;
    final deep = _deepLinear;
    final pr = deep[step * 3];
    final pg = deep[step * 3 + 1];
    final pb = deep[step * 3 + 2];
    final outA = b + alpha - alpha * b;
    if (b <= 0) {
      final rgb = _deep8[step];
      _put(tile, p, rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF, outA);
      return;
    }
    // At full opacity a wash over paint of its own colour joins it: the
    // denser of the two shows and nothing deepens, so a flat area painted
    // in several strokes stays even.
    final join = opacity >= 250 ? _joinShare(before, p) : 0.0;
    final beforeDensity = join > 0 ? _joinedDensity : 0.0;
    if (join >= 1) {
      if (density <= beforeDensity) {
        tile[p] = raw[p];
        tile[p + 1] = raw[p + 1];
        tile[p + 2] = raw[p + 2];
        tile[p + 3] = raw[p + 3];
      } else {
        final rgb = _deep8[step];
        _put(tile, p, rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF, alpha);
      }
      return;
    }
    final share = (rate / 100).clamp(0.0, 1.0);
    final belowRgb = before[p] << 16 | before[p + 1] << 8 | before[p + 2];
    // The wash turns the colour under it towards the paint the way paint
    // mixes (yellow under a blue wash turns green). How much of the colour
    // under it still shows: more where the wash is thinner, and more with
    // more water, which lets the wash run into the paint under it rather
    // than lie over it. Wet into wet (混色度合い) the two run together
    // further, nearer to an even mix…
    final merge = 1 - (1 - _merge) * (1 - 0.5 * share);
    final mixed = _mixer.mix(belowRgb, 1 - alpha * (1 - merge));
    // …while a wash laid over dry paint is another transparent layer, which
    // deepens it: more for a dark paint, so a second wash of a colour is
    // deeper than the first. Pigment that pooled deepens it as on paper.
    var deepen = 1 - alpha * (1 - share) * _depth;
    if (step > 0 && _paintLuminance > 0) {
      deepen *= _luminanceOf(pr, pg, pb) / _paintLuminance;
    }
    // Nearly the same colour: part of the way to joining.
    final joinedDensity = math.max(density, beforeDensity);
    final joinedA = joinedDensity < 1 ? joinedDensity : 1.0;
    final finalA = outA + (joinedA - outA) * join;
    final newer = density > beforeDensity;
    // (The colour itself, not its table step, decides which is denser.)
    final lut = linearFromSrgb8;
    final r = _glazed(lut(mixed >> 16 & 0xFF) * deepen, pr, b, alpha, outA);
    final g = _glazed(lut(mixed >> 8 & 0xFF) * deepen, pg, b, alpha, outA);
    final bl = _glazed(lut(mixed & 0xFF) * deepen, pb, b, alpha, outA);
    _put(
      tile,
      p,
      srgb8FromLinear(r + ((newer ? pr : lut(before[p])) - r) * join),
      srgb8FromLinear(g + ((newer ? pg : lut(before[p + 1])) - g) * join),
      srgb8FromLinear(bl + ((newer ? pb : lut(before[p + 2])) - bl) * join),
      finalA,
    );
  }

  /// The straight colour of a pixel of alpha [outA] that is [onPaint] where
  /// the paint under it ([below] of it) was, and [paint] at [alpha] over the
  /// rest.
  static double _glazed(
    double onPaint,
    double paint,
    double below,
    double alpha,
    double outA,
  ) => (below * onPaint + (1 - below) * alpha * paint) / outA;

  /// How nearly the colour at [p] in [before] is a wash of the paint's own
  /// colour, at whatever density: 1 within a few levels, 0 from a clearly
  /// different colour. Leaves that wash's density in [_joinedDensity].
  double _joinShare(Uint8List before, int p) {
    final key =
        before[p] << 24 |
        before[p + 1] << 16 |
        before[p + 2] << 8 |
        before[p + 3];
    final known = _joinShares[key];
    if (known != null) {
      _joinedDensity = _joinedDensities[key]!;
      return known;
    }
    if (_joinShares.length >= 4096) {
      _joinShares.clear();
      _joinedDensities.clear();
    }
    final share = _workOutJoinShare(before, p);
    _joinShares[key] = share;
    _joinedDensities[key] = _joinedDensity;
    return share;
  }

  double _workOutJoinShare(Uint8List before, int p) {
    final a = before[p + 3];
    final k = _absorbing;
    var density = a / 255;
    if (a == 255 && k >= 0) {
      // As dense as the channel the paint absorbs most says (at least the
      // chosen colour, as the pixel is opaque).
      final v = linearFromSrgb8(before[p + k]);
      final d = v <= 0 ? _maxDensity : math.log(v) / _logAbsorbing;
      density = d.clamp(1.0, _maxDensity).toDouble();
    }
    _joinedDensity = density;
    var difference = 0;
    for (var c = 0; c < 3; c++) {
      final expected = density <= 1
          ? paint >> (16 - 8 * c) & 0xFF
          : srgb8FromLinear(math.exp(_paintLog[c] * density));
      final d = (before[p + c] - expected).abs();
      if (d > difference) difference = d;
    }
    return 1 - _smoothstep((difference - 4) / 16);
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
