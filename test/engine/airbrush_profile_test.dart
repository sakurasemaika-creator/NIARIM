// エアブラシは選んだ色を100%で置き、線の真ん中だけが濃く、ふちへ向かって
// なめらかに0%まで薄れる。真ん中に線だけがくっきり見える形にしない（所有者の
// 指定、2026-11-27「エアブラシは全体が透けているのではなく、ちゃんと色自体は
// 100％で描かれるけれど濃いのはストロークの中央だけでふちがぼやけるイメージ
// ですね。でも中央線だけくっきり見える形は絶対に避けてください。真ん中は100％
// だけど自然な形で滑らかに徐々に不透明度0%に向かうように薄くしていってほしい
// んです。」）。
//
// 線を横切る断面を測る：真ん中は不透明（0.99以上）、ふちへ向かって増えずに0まで
// 下がり、真ん中にとがった山が無い（平らか丸い頂）。スタンプが重なっても真ん中に
// 筋が立たない（ゆっくり引いた線も、1回置いた跡の断面と同じ）。太さ10・30・80、
// まっすぐな線と曲線で。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

const _w = 600;
const _h = 600;

/// One level of an 8-bit alpha.
const _level = 1 / 255;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Brush airbrush;

  setUpAll(() async {
    airbrush = BrushService.builtInBrushes.singleWhere(
      (b) => b.id == 'Brush0003',
    );
    await preloadBrushTextures(
      airbrush.resolvedCustomImagePaths,
      mode: airbrush.imageInkMode,
    );
  });

  TileManager draw(Brush brush, List<(double, double)> points) {
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tiles)
      ..currentBrush = brush
      ..currentColor = const ui.Color(0xFF2648D6)
      ..pressureEnabled = true;
    engine.beginStroke(
      StrokePoint(x: points.first.$1, y: points.first.$2, pressure: 1),
      'l',
    );
    for (final (x, y) in points.skip(1)) {
      engine.continueStroke(StrokePoint(x: x, y: y, pressure: 1), 'l');
    }
    engine.endStroke();
    return tiles;
  }

  double alphaAt(TileManager tiles, int x, int y) =>
      tiles.getPixelColorAt('l', x, y)?.a ?? 0;

  /// The alpha of a single dab at (300, 300), [d] pixels below its centre.
  List<double> dabProfile(Brush brush, int reach) {
    final tiles = draw(brush, [(300.5, 300.5)]);
    return [for (var d = 0; d <= reach; d++) alphaAt(tiles, 300, 300 + d)];
  }

  void expectSoftProfile(List<double> below, List<double> above, String label) {
    // The centre is the chosen colour.
    expect(below[0], greaterThanOrEqualTo(0.99), reason: label);
    // A flat or rounded top: no peak of a line along the middle.
    final second = below[1] - 2 * below[0] + above[1];
    expect(second, greaterThan(-0.02), reason: '$label: second difference');
    expect(below[2], greaterThan(below[0] - 0.03), reason: label);
    expect(above[2], greaterThan(above[0] - 0.03), reason: label);
    // Down to nothing at the edge, never back up, without a step.
    for (final side in [below, above]) {
      for (var d = 1; d < side.length; d++) {
        expect(
          side[d],
          lessThanOrEqualTo(side[d - 1] + _level),
          reason: '$label at $d',
        );
        expect(
          side[d - 1] - side[d],
          lessThan(0.06),
          reason: '$label: a step at $d',
        );
      }
      expect(side.last, 0, reason: '$label at the edge');
    }
  }

  for (final size in [10.0, 30.0, 80.0]) {
    test('size $size: a straight stroke is the chosen colour in the middle '
        'and fades smoothly to nothing, with no ridge where dabs overlap', () {
      final brush = airbrush.copyWith(size: size);
      // The blur reaches past the tip by its own width.
      final reach = (size / 2 + brush.pressureOn.blur.strong + 4).ceil();
      final dab = dabProfile(brush, reach);
      for (final step in [2.0, 0.25]) {
        final tiles = draw(brush, [
          for (var x = 100.0; x <= 500; x += step) (x + 0.5, 300.5),
        ]);
        final below = [
          for (var d = 0; d <= reach; d++) alphaAt(tiles, 300, 300 + d),
        ];
        final above = [
          for (var d = 0; d <= reach; d++) alphaAt(tiles, 300, 300 - d),
        ];
        final label = 'size $size, every ${step}px';
        expectSoftProfile(below, above, label);
        // Overlapping dabs build nothing up: across the stroke it is one dab.
        for (var d = 0; d <= reach; d++) {
          expect(
            (below[d] - dab[d]).abs(),
            lessThanOrEqualTo(2 * _level),
            reason: '$label at $d',
          );
          expect(
            (above[d] - dab[d]).abs(),
            lessThanOrEqualTo(2 * _level),
            reason: '$label at -$d',
          );
        }
      }
    });

    test('size $size: a curved stroke has the same soft profile on both '
        'sides', () {
      final brush = airbrush.copyWith(size: size);
      final reach = (size / 2 + brush.pressureOn.blur.strong + 4).ceil();
      final dab = dabProfile(brush, reach);
      // An arc of radius 170 round (300, 470), over the top at (300, 300).
      final tiles = draw(brush, [
        for (var a = 200.0; a <= 340; a += 0.5)
          (
            300.5 + 170 * math.cos(a * math.pi / 180),
            470.5 + 170 * math.sin(a * math.pi / 180),
          ),
      ]);
      // Outside the curve (up) and inside it (down), across the top.
      final outside = [
        for (var d = 0; d <= reach; d++) alphaAt(tiles, 300, 300 - d),
      ];
      final inside = [
        for (var d = 0; d <= reach; d++) alphaAt(tiles, 300, 300 + d),
      ];
      expectSoftProfile(inside, outside, 'size $size, curve');
      for (var d = 0; d <= reach; d++) {
        expect(
          (outside[d] - dab[d]).abs(),
          lessThanOrEqualTo(3 * _level),
          reason: 'outside at $d',
        );
        expect(
          (inside[d] - dab[d]).abs(),
          lessThanOrEqualTo(3 * _level),
          reason: 'inside at $d',
        );
      }
    });
  }
}
