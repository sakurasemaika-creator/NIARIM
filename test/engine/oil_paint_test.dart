// 油彩風混色（OilStroke）：1本の線は1つの絵の具の塊として塗られ、真ん中に
// 筆の色の細い線（スタンプが最も重なる所）も、スタンプの弧の模様も出ない
// （所有者の指摘、2026-11-27「ストロークの真ん中に濃い青が細い線のように
// 残っている」）。異なる色の上を通ると、拾った色を次の色の上と紙の上へ
// 引っ張り、色延びの長さで薄れていく（同「異なる色が重なるようにストローク
// をした時には色が引っ張られるはず」）。混ざる色は絵の具らしい（青と黄で
// 緑、赤と青で紫）。1回の取り消しで線全体が戻る。
// 油彩は透けない：不透明度100%の線は筆の絵の具で下を覆い、筆は下の絵の具を
// 少しずつ拾って色が変わる。黄色に入った所は青のまま、そこから少しずつ緑に
// なり、黄色の形の縁がくっきり残らない（所有者の指摘、2026-11-27「最初に
// 黄色に入るところだけその下に描画した領域の境界線が混ざらずくっきり
// 残っちゃってる」「不透明度100%で書いている場合は色が引っ張られて混ざって
// いる部分以外は上に描画された色で上書きされるように」。95%で透けさせた後に
// 「今透けすぎてるので100％にしてください」）。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/oil_paint.dart';
import 'package:niarim/engine/perceptual_color_mixer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

import '../helpers/delta_e.dart';

const _w = 420;
const _h = 160;
const _yellow = 0xF4CE2C;
const _red = 0xD8363A;
const _blue = 0x2648D6;

/// The most the stroke's colour may change from one pixel to the next along
/// it where it enters a colour: a step of loading up, no more.
const _edgeStep = 2.5;

Brush _oil({
  double size = 30,
  int blur = 0,
  int rate = 50,
  int stretch = kDefaultMixingStretch,
  int opacity = 100,
  bool pixelMode = false,
}) => Brush(
  id: 'oil-test',
  name: 'Oil Test',
  size: size,
  opacity: opacity,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: pixelMode,
  pressureOff: BrushPressureOffSettings(
    blur: FixedBrushSetting(enabled: blur > 0, value: blur),
    edgeJitter: const FixedBrushSetting(enabled: false, value: 0),
    mixing: PressureMixingOffSetting(
      enabled: true,
      mode: BrushMixingMode.oil,
      rate: rate,
      stretch: stretch,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);

/// A canvas whose columns [from]..[to] (exclusive) are flat [rgb].
void _fill(TileManager tiles, int rgb, int from, int to) {
  for (var y = 0; y < _h; y++) {
    for (var x = from; x < to; x++) {
      final tile = tiles.getOrCreateTile(
        'layer',
        x ~/ TileManager.tileSize,
        y ~/ TileManager.tileSize,
      );
      final i =
          ((y % TileManager.tileSize) * TileManager.tileSize +
              x % TileManager.tileSize) *
          4;
      tile[i] = rgb >> 16 & 0xFF;
      tile[i + 1] = rgb >> 8 & 0xFF;
      tile[i + 2] = rgb & 0xFF;
      tile[i + 3] = 255;
    }
  }
}

/// The brush's own paint [paint] laid at full opacity over opaque [under]
/// (both 0xRRGGBB), as CIELAB.
List<double> _covering(int paint, int under) {
  double over(int shift) =>
      (paint >> shift & 0xFF) * kOilPaintCover +
      (under >> shift & 0xFF) * (1 - kOilPaintCover);
  return labOf(over(16), over(8), over(0));
}

/// A horizontal blue stroke along y 80 from [x0] to [x1].
void _stroke(
  TileManager tiles,
  Brush brush, {
  double x0 = 10,
  double x1 = 410,
  int colour = _blue,
}) {
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = ui.Color(0xFF000000 | colour)
    ..pressureEnabled = false;
  engine.beginStroke(StrokePoint(x: x0, y: 80, pressure: 1), 'layer');
  for (var x = x0 + 2; x <= x1; x += 2) {
    engine.continueStroke(StrokePoint(x: x, y: 80, pressure: 1), 'layer');
  }
  engine.endStroke();
}

/// The pixel at ([x], [y]) on white paper, as CIELAB.
List<double> _lab(TileManager tiles, int x, int y) {
  final c = tiles.getPixelColorAt('layer', x, y);
  if (c == null) return labOf(255, 255, 255);
  double over(double v) => (v * c.a + (1 - c.a)) * 255;
  return labOf(over(c.r), over(c.g), over(c.b));
}

/// The mean colour of column [x] over the middle half of the stroke.
List<double> _column(TileManager tiles, int x, double size) => meanLab([
  for (var y = (80 - size / 4).round(); y <= (80 + size / 4).round(); y++)
    _lab(tiles, x, y),
]);

void main() {
  test('one body of paint: no line along the middle, no arcs of dabs', () {
    // Long enough for the brush to have loaded up with yellow: from there
    // on it lays one paint.
    const w = 1100;
    for (final size in [10.0, 30.0, 80.0]) {
      for (final blur in [0, 1, 10]) {
        final tiles = TileManager(canvasWidth: w, canvasHeight: _h);
        _fill(tiles, _yellow, 0, w);
        _stroke(
          tiles,
          _oil(size: size, blur: blur),
          x1: w - 10,
        );
        final label = 'size $size, ぼかし $blur';
        // How much the tip covers each row (a soft tip fades towards its
        // edge whether it mixes or not): the same stroke on an empty layer.
        final bare = TileManager(canvasWidth: w, canvasHeight: _h);
        _stroke(
          bare,
          _oil(size: size, blur: blur),
          x1: w - 10,
        );
        final rows = [
          for (var y = (80 - size * 0.4).round(); y <= 80 + size * 0.4; y++)
            if ((bare.getPixelColorAt('layer', 800, y)?.a ?? 0) > 0.5) y,
        ];
        expect(rows.length, greaterThanOrEqualTo(3), reason: label);
        // The colour the brush laid on a pixel, taking the yellow it only
        // partly covers out again.
        List<double> laid(int x, int y) {
          final a = bare.getPixelColorAt('layer', x, y)!.a * kOilPaintCover;
          final c = tiles.getPixelColorAt('layer', x, y)!;
          double back(double v, int under) =>
              ((v * 255 - under * (1 - a)) / a).clamp(0, 255).toDouble();
          return labOf(
            back(c.r, _yellow >> 16 & 0xFF),
            back(c.g, _yellow >> 8 & 0xFF),
            back(c.b, _yellow & 0xFF),
          );
        }

        // Over the flat yellow, well away from the ends.
        for (var x = 700; x <= 1000; x += 9) {
          final centre = _lab(tiles, x, 80);
          // Across the stroke the brush laid one colour: no line of the
          // brush's colour where the dabs overlap most.
          for (final y in rows) {
            expect(
              deltaE2000(laid(x, 80), laid(x, y)),
              lessThan(1.5),
              reason: '$label at ($x, $y)',
            );
          }
          // Along it too: no arcs where each dab's edge was.
          expect(
            deltaE2000(centre, _lab(tiles, x + 1, 80)),
            lessThan(1),
            reason: '$label at x $x',
          );
        }
      }
    }
  });

  test('over one colour the mix follows 混色度合い, whatever 色延び', () {
    List<double> mix(int stretch) {
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      _fill(tiles, _yellow, 0, _w);
      _stroke(tiles, _oil(stretch: stretch));
      return _column(tiles, 210, 30);
    }

    final none = mix(0);
    expect(deltaE2000(mix(30), none), lessThan(1));
    expect(deltaE2000(mix(100), none), lessThan(1));
    // Blue into yellow: a clean green, between the two.
    final green = none;
    expect(green[1], lessThan(-20)); // a*: green
    expect(deltaE2000(green, labOfRgb(_blue)), greaterThan(20));
    expect(deltaE2000(green, labOfRgb(_yellow)), greaterThan(20));
  });

  test('blue into red is a clean purple', () {
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    _fill(tiles, _red, 0, _w);
    _stroke(tiles, _oil());
    final purple = _column(tiles, 210, 30);
    expect(purple[1], greaterThan(30)); // a*: red-purple
    expect(purple[2], lessThan(-20)); // b*: blue
    // No brighter than the lighter of the two.
    expect(purple[0], lessThan(labOfRgb(_red)[0]));
  });

  group('oil covers what is under it', () {
    final mixer = AnalogPaintMixer(selected: _blue);

    test('at full opacity the brush lays its own paint over what was there, '
        'none of which shows through', () {
      expect(kOilPaintCover, 1.0);
      // Without 混色度合い the brush picks nothing up: wherever it goes it
      // lays its own blue.
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      _fill(tiles, _yellow, 150, 300);
      _stroke(tiles, _oil(rate: 0));
      for (final x in [60, 120, 320, 390]) {
        expect(
          deltaE2000(_column(tiles, x, 30), labOfRgb(_blue)),
          lessThan(1),
          reason: 'paper at x $x',
        );
      }
      for (final x in [150, 151, 200, 299]) {
        expect(
          deltaE2000(_column(tiles, x, 30), _covering(_blue, _yellow)),
          lessThan(1),
          reason: 'yellow at x $x',
        );
      }
      // Loaded with yellow, it lays the mix of the two over the yellow the
      // same way.
      const w = 700;
      final loaded = TileManager(canvasWidth: w, canvasHeight: _h);
      _fill(loaded, _yellow, 0, w);
      _stroke(loaded, _oil(), x1: w - 10);
      expect(
        deltaE2000(
          _column(loaded, 600, 30),
          _covering(mixer.mix(_yellow, 0.5), _yellow),
        ),
        lessThan(1),
      );
    });

    test('entering a colour the brush is still its own paint, then picks it '
        'up gradually: the edge of the colour does not show as a line', () {
      // Paper up to x 200, yellow after it.
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      _fill(tiles, _yellow, 200, _w);
      _stroke(tiles, _oil());
      final blue = _covering(_blue, _yellow);
      final green = _covering(mixer.mix(_yellow, 0.5), _yellow);
      expect(deltaE2000(blue, green), greaterThan(30));
      // Just inside the yellow the stroke is still strongly blue.
      final inside = _column(tiles, 201, 30);
      expect(deltaE2000(inside, blue), lessThan(deltaE2000(inside, green) / 4));
      // It turns green gradually along the stroke.
      var last = deltaE2000(inside, green);
      for (final x in [210, 220, 235, 260, 300]) {
        final now = deltaE2000(_column(tiles, x, 30), green);
        expect(now, lessThan(last), reason: 'x $x');
        last = now;
      }
      expect(last, lessThan(3));
      // No sudden change anywhere along it, the edge of the yellow included.
      for (var x = 180; x <= 300; x++) {
        expect(
          deltaE2000(_column(tiles, x - 1, 30), _column(tiles, x, 30)),
          lessThan(_edgeStep),
          reason: 'x $x',
        );
      }
    });
  });

  group('paint picked up is dragged along the stroke', () {
    /// Yellow up to x 150, red after it; the blue stroke goes right.
    TileManager yellowThenRed(int stretch) {
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      _fill(tiles, _yellow, 0, 150);
      _fill(tiles, _red, 150, _w);
      _stroke(tiles, _oil(stretch: stretch));
      return tiles;
    }

    test('into the next colour, fading as it goes', () {
      final tiles = yellowThenRed(kDefaultMixingStretch);
      final far = _column(tiles, 380, 30);
      // Half a brush width into the red, the green picked up on the yellow
      // still shows; further on it fades into the mix with red.
      final near = _column(tiles, 165, 30);
      final later = _column(tiles, 195, 30);
      expect(deltaE2000(near, far), greaterThan(12));
      expect(near[1], lessThan(far[1] - 15)); // greener than the purple
      expect(deltaE2000(later, far), lessThan(deltaE2000(near, far)));
      expect(deltaE2000(_column(tiles, 300, 30), far), lessThan(3));
      // Without 色延び nothing is dragged.
      final still = yellowThenRed(0);
      expect(
        deltaE2000(_column(still, 165, 30), _column(still, 380, 30)),
        lessThan(3),
      );
    });

    test('out onto bare paper, for longer with more 色延び', () {
      // Red up to x 150, paper after it.
      double redness(int stretch, int x) {
        final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
        _fill(tiles, _red, 0, 150);
        _stroke(tiles, _oil(stretch: stretch));
        return deltaE2000(_column(tiles, x, 30), labOfRgb(_blue));
      }

      // Just past the red the stroke is still the purple it laid there.
      expect(redness(30, 160), greaterThan(15));
      // It fades back to the brush's blue…
      expect(redness(30, 320), lessThan(redness(30, 160) / 3));
      // …further with more 色延び, and at once without it.
      expect(redness(100, 250), greaterThan(redness(30, 250) + 5));
      expect(redness(0, 160), lessThan(2));
    });
  });

  test('the whole stroke is one step to undo', () {
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    _fill(tiles, _yellow, 0, 150);
    _fill(tiles, _red, 150, _w);
    final before = Uint8List.fromList(tiles.getOrCreateTile('layer', 0, 0));
    tiles.beginUndoRecording('layer');
    _stroke(tiles, _oil(blur: 1));
    final snapshot = tiles.endUndoRecording();
    expect(snapshot.before['0,0'], before);
    tiles.applyTileSnapshot('layer', snapshot.before);
    expect(tiles.getOrCreateTile('layer', 0, 0), before);
  });

  test('a lowered opacity lays the mix over the paint, partly', () {
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    _fill(tiles, _yellow, 0, _w);
    _stroke(tiles, _oil(opacity: 50));
    final half = _column(tiles, 210, 30);
    final full = TileManager(canvasWidth: _w, canvasHeight: _h);
    _fill(full, _yellow, 0, _w);
    _stroke(full, _oil());
    expect(half[0], greaterThan(_column(full, 210, 30)[0] + 5));
    expect(deltaE2000(half, labOfRgb(_yellow)), greaterThan(10));
  });

  test('the pixel mode draws the same stroke the same way', () {
    Uint8List draw() {
      final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
      _fill(tiles, _yellow, 0, 150);
      _stroke(tiles, _oil(size: 6, pixelMode: true));
      return Uint8List.fromList(tiles.getOrCreateTile('layer', 0, 0));
    }

    final once = draw();
    expect(draw(), once);
    // It mixed over the yellow and stayed blue past it.
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    _fill(tiles, _yellow, 0, 150);
    _stroke(tiles, _oil(size: 6, pixelMode: true, stretch: 0));
    final green = _lab(tiles, 80, 80);
    expect(green[1], lessThan(-20));
    expect(deltaE2000(_lab(tiles, 350, 80), labOfRgb(_blue)), lessThan(2));
  });
}
