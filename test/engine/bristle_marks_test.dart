// 筆の毛のすじ・かすれ・紙の目（所有者の依頼、2026-11-27「クリスタで油彩とか
// 水彩とかブラシ名で検索するとプリセットとして用意するブラシやトーン、スタンプの
// ヒントになるものが沢山あると思います。テクスチャや仕組みのクオリティアップを
// お願いします」）。
//
// - 毛のすじは線に沿って走る（線を横切る向きに濃淡が変わり、沿う向きには
//   変わらない）。絵の具の乗った所は選んだ色（全体を薄くしない）。
// - かすれは線の始めでは無く、線を進むほど増え、外側の毛から先にかすれる。
// - 同じ線は何度描いても同じ（ふち滲みも紙の目に沿う。乱数で毎回変わらない）。
// - 紙の目はキャンバスに固定され、強く押すほど凹みまで埋まる。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/paper_tooth.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

const _layer = 'l';
const _blue = 0xFF2648D6;

Brush _brush({
  int streaks = 0,
  int dry = 0,
  double size = 40,
  int grain = 0,
  bool jitter = false,
}) => Brush(
  id: 'b',
  name: 'b',
  size: size,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    edgeJitter: FixedBrushSetting(enabled: jitter, value: 70),
  ),
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    edgeJitter: PressureRangeSetting(enabled: jitter, weak: 70, strong: 70),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
  grainStrength: grain,
  bristleStreaks: streaks,
  dryBrush: dry,
);

/// Draws a horizontal stroke of [brush] at y = 100 from x = 20 to [end] and
/// returns the layer's tiles (premultiplied RGBA) by tile key.
Map<String, Uint8List> _draw(
  Brush brush, {
  double end = 600,
  double pressure = 1,
  double y = 100,
}) {
  final tiles = TileManager(canvasWidth: 700, canvasHeight: 220);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(_blue)
    ..pressureEnabled = true;
  engine.beginStroke(StrokePoint(x: 20, y: y, pressure: pressure), _layer);
  for (var x = 22.0; x <= end; x += 2) {
    engine.continueStroke(StrokePoint(x: x, y: y, pressure: pressure), _layer);
  }
  engine.endStroke();
  final out = <String, Uint8List>{
    for (var tx = 0; tx * TileManager.tileSize < 700; tx++)
      for (var ty = 0; ty * TileManager.tileSize < 220; ty++)
        if (tiles.getTile(_layer, tx, ty) case final tile?)
          '$tx:$ty': Uint8List.fromList(tile),
  };
  tiles.dispose();
  return out;
}

int _alpha(Map<String, Uint8List> tiles, int x, int y) {
  const size = TileManager.tileSize;
  final tile = tiles['${x ~/ size}:${y ~/ size}'];
  if (tile == null) return 0;
  return tile[((y % size) * size + x % size) * 4 + 3];
}

/// The share of the band [y0]..[y1] between x = [x0] and [x1] that holds
/// paint (alpha over half).
double _covered(Map<String, Uint8List> tiles, int x0, int x1, int y0, int y1) {
  var hit = 0, all = 0;
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      all++;
      if (_alpha(tiles, x, y) > 127) hit++;
    }
  }
  return hit / all;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bristle streaks run along the stroke, and where paint lies it is the '
      'chosen colour', () {
    final tiles = _draw(_brush(streaks: 60));
    // Across the stroke the paint changes from row to row; along it, each
    // row stays nearly the same.
    var acrossChange = 0.0, alongChange = 0.0, rows = 0;
    for (var y = 86; y <= 114; y++) {
      final row = [for (var x = 150; x <= 400; x++) _alpha(tiles, x, y)];
      final below = [for (var x = 150; x <= 400; x++) _alpha(tiles, x, y + 1)];
      for (var i = 1; i < row.length; i++) {
        alongChange += (row[i] - row[i - 1]).abs();
        acrossChange += (below[i] - row[i]).abs();
      }
      rows++;
    }
    expect(rows, greaterThan(0));
    expect(acrossChange, greaterThan(alongChange * 8));
    // Here and there a hair is missing or thin…
    final band = [
      for (var x = 150; x <= 400; x += 10)
        for (var y = 84; y <= 116; y++) _alpha(tiles, x, y),
    ];
    expect(band.where((a) => a < 200), isNotEmpty);
    // …and on most hairs the paint is the colour as it is: no paleness.
    expect(band.where((a) => a == 255).length, greaterThan(band.length ~/ 2));
    const size = TileManager.tileSize;
    final tile = tiles['1:0']!;
    final i = (100 % size * size + 300 % size) * 4;
    if (tile[i + 3] == 255) {
      expect([tile[i], tile[i + 1], tile[i + 2]], [0x26, 0x48, 0xD6]);
    }
  });

  test('a dry brush starts loaded and breaks up along the stroke, from the '
      'edges in', () {
    // At a usual pen pressure.
    final tiles = _draw(_brush(streaks: 40, dry: 75), pressure: 0.6);
    final start = _covered(tiles, 30, 70, 84, 116);
    final end = _covered(tiles, 540, 590, 84, 116);
    expect(start, greaterThan(0.75));
    expect(end, lessThan(start - 0.2));
    expect(end, greaterThan(0.1), reason: 'a dry brush still marks');
    final middle = _covered(tiles, 540, 590, 94, 106);
    final edges =
        (_covered(tiles, 540, 590, 82, 88) +
            _covered(tiles, 540, 590, 112, 118)) /
        2;
    expect(edges, lessThan(middle));
    // A firmer press pushes more paint out.
    final light = _draw(_brush(streaks: 40, dry: 75), pressure: 0.4);
    expect(
      _covered(light, 540, 590, 84, 116),
      lessThan(
        _covered(_draw(_brush(streaks: 40, dry: 75)), 540, 590, 84, 116),
      ),
    );
  });

  test('without かすれ the stroke does not dry along its length', () {
    final tiles = _draw(_brush(streaks: 40));
    final start = _covered(tiles, 60, 120, 84, 116);
    final end = _covered(tiles, 520, 580, 84, 116);
    expect((start - end).abs(), lessThan(0.08));
  });

  test('the same stroke draws the same marks every time, edge jitter '
      'included', () {
    for (final brush in [
      _brush(streaks: 70, dry: 70),
      _brush(size: 18, grain: 45, jitter: true),
    ]) {
      final a = _draw(brush);
      final b = _draw(brush);
      expect(a.keys, b.keys);
      for (final key in a.keys) {
        expect(a[key], b[key], reason: key);
      }
    }
  });

  test('brushes without bristle marks are not touched by them', () {
    // A plain brush and the same with the settings at zero draw alike.
    final plain = _draw(_brush());
    final zero = _draw(_brush().copyWith(bristleStreaks: 0, dryBrush: 0));
    for (final key in plain.keys) {
      expect(plain[key], zero[key]);
    }
  });

  test('a knife lays smooth paint when pressed firmly and scrapes it thin '
      'in streaks when pressed lightly', () {
    double share(Map<String, Uint8List> tiles, bool Function(int) keep) {
      var hit = 0, all = 0;
      for (var x = 120; x <= 560; x += 4) {
        for (var y = 88; y <= 112; y++) {
          all++;
          if (keep(_alpha(tiles, x, y))) hit++;
        }
      }
      return hit / all;
    }

    final firm = _draw(_brush(dry: 35), pressure: 1);
    expect(share(firm, (a) => a == 255), 1.0, reason: 'no flecks');
    final light = _draw(_brush(dry: 35), pressure: 0.3);
    expect(share(light, (a) => a < 230), greaterThan(0.05));
    expect(
      share(light, (a) => a < 40),
      lessThan(0.02),
      reason: 'thin, not gone',
    );
  });

  test(
    'a tap presses the hairs down: dense in the middle, fibres at the rim',
    () {
      final tiles = TileManager(canvasWidth: 200, canvasHeight: 200);
      final engine = DrawingEngine(tileManager: tiles)
        ..currentBrush = _brush(streaks: 60, size: 60)
        ..currentColor = const ui.Color(_blue)
        ..pressureEnabled = true;
      engine.beginStroke(const StrokePoint(x: 100, y: 100), _layer);
      engine.endStroke();
      int alpha(int x, int y) =>
          tiles.getTile(_layer, 0, 0)![(y * 256 + x) * 4 + 3];
      var inner = 0, innerAll = 0, rim = 0, rimAll = 0;
      for (var y = 60; y <= 140; y++) {
        for (var x = 60; x <= 140; x++) {
          final r = math.sqrt(
            (x + 0.5 - 100) * (x + 0.5 - 100) +
                (y + 0.5 - 100) * (y + 0.5 - 100),
          );
          if (r < 15) {
            innerAll++;
            if (alpha(x, y) > 200) inner++;
          } else if (r > 26 && r < 29) {
            rimAll++;
            if (alpha(x, y) > 200) rim++;
          }
        }
      }
      tiles.dispose();
      expect(inner / innerAll, greaterThan(0.95));
      expect(rim / rimAll, lessThan(0.8));
      expect(rim / rimAll, greaterThan(0.1));
    },
  );

  test('a painting brush turns smoothly between sparse input points', () async {
    // A knife's blade turns with the stroke. Between input points far
    // apart, it turns gradually: the outside of the curve shows no teeth
    // where one segment's blade meets the next one's.
    final brush = BrushService.builtInBrushes.singleWhere(
      (b) => b.id == 'Brush0044',
    );
    await preloadBrushTextures(
      brush.resolvedCustomImagePaths,
      mode: brush.imageInkMode,
    );
    final tiles = TileManager(canvasWidth: 500, canvasHeight: 500);
    final engine = DrawingEngine(tileManager: tiles)
      ..currentBrush = brush
      ..currentColor = const ui.Color(_blue)
      ..pressureEnabled = true;
    const cx = 60.0, cy = 60.0, radius = 300.0;
    for (var i = 0; i <= 5; i++) {
      final a = i / 5 * math.pi / 2;
      final p = StrokePoint(
        x: cx + radius * 1.3 * math.cos(a),
        y: cy + radius * math.sin(a),
      );
      if (i == 0) {
        engine.beginStroke(p, _layer);
      } else {
        engine.continueStroke(p, _layer);
      }
    }
    engine.endStroke();
    int alpha(int x, int y) {
      if (x < 0 || y < 0 || x >= 500 || y >= 500) return 0;
      final tile = tiles.getTile(_layer, x ~/ 256, y ~/ 256);
      if (tile == null) return 0;
      return tile[((y % 256) * 256 + x % 256) * 4 + 3];
    }

    // The outer edge along rays from the centre.
    final outer = <double>[];
    for (var k = 40; k <= 410; k++) {
      final a = k / 450 * math.pi / 2;
      var edge = 0.0;
      for (var r = 150.0; r < 520; r += 0.25) {
        final x = (cx + r * math.cos(a)).floor();
        final y = (cy + r * math.sin(a)).floor();
        if (alpha(x, y) > 127) edge = r;
      }
      outer.add(edge);
    }
    tiles.dispose();
    var worst = 0.0;
    for (var i = 2; i + 2 < outer.length; i++) {
      final bump = (outer[i] - (outer[i - 2] + outer[i + 2]) / 2).abs();
      if (bump > worst) worst = bump;
    }
    expect(
      getCachedBrushTexture(
        brush.resolvedCustomImagePaths.single,
        mode: brush.imageInkMode,
      ),
      isNotNull,
    );
    expect(worst, lessThan(2.0));
  });

  test('paper tooth: fixed to the canvas, repeating, evenly spread, and a '
      'firmer press fills more of it', () {
    expect(paperTooth, hasLength(kPaperToothSize * kPaperToothSize));
    expect(paperToothAt(3, 5), paperToothAt(3 + kPaperToothSize, 5));
    expect(paperToothAt(3, 5), paperToothAt(3, 5 + 2 * kPaperToothSize));
    final buckets = List<int>.filled(8, 0);
    for (final h in paperTooth) {
      buckets[h >> 5]++;
    }
    for (final count in buckets) {
      expect(count, closeTo(paperTooth.length / 8, paperTooth.length / 80));
    }
    double share(double pressure) {
      var sum = 0.0;
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          sum += paperToothCover(x, y, 50, pressure);
        }
      }
      return sum / 4096;
    }

    expect(share(1), greaterThan(share(0.5)));
    expect(share(0.5), greaterThan(share(0.1)));
    // The bumps take the paint as it is.
    expect(
      [
        for (var i = 0; i < 4096; i++) paperToothCover(i % 64, i ~/ 64, 50, 1),
      ].where((c) => c == 1).length,
      greaterThan(2048),
    );
    expect(paperToothCover(1, 1, 0, 0), 1);
  });

  test('the new settings are saved and read back; older saves read as 0', () {
    final brush = _brush(streaks: 33, dry: 66);
    final again = Brush.fromJson(brush.toJson());
    expect(again.bristleStreaks, 33);
    expect(again.dryBrush, 66);
    final old = brush.toJson()
      ..remove('bristleStreaks')
      ..remove('dryBrush');
    final read = Brush.fromJson(old);
    expect(read.bristleStreaks, 0);
    expect(read.dryBrush, 0);
    final odd = brush.toJson()
      ..['bristleStreaks'] = 'many'
      ..['dryBrush'] = 250;
    final clamped = Brush.fromJson(odd);
    expect(clamped.bristleStreaks, 0);
    expect(clamped.dryBrush, 100);
  });
}
