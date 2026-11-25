import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/pixel_line_path.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

/// ピクセルモードの線が、ドットがダマにならないなめらかなドット絵の線に
/// なることを確かめる：1画素の線は1段に1画素でL字の角が無く、ゆるい傾きの
/// 段の長さがそろう。太い線はどの角度でも線に直角な太さがそろい、偶数の
/// 太さもペンの位置が中心。ペンの下の画素はその場で描き、ペンを離した後の
/// 線と違うのはペン先の近くだけ。手の震えで行き来せず、線の終わりはペンの
/// 画素まで届く。輪を閉じた所・図形・縁取り・反復・ペン先の画像・散布・
/// カリグラフィーもダマにならない。ピクセルモードでないブラシの線は前と
/// 1ビットも変わらない。
const _layer = 'L';
const _size = TileManager.tileSize;

Brush _pixelBrush(
  double size, {
  bool pressureSize = false,
  bool fade = false,
  int spacing = 1,
  bool outline = false,
  bool repeat = false,
  List<String> images = const [],
  double scatter = 0,
  double? calligraphy,
}) => Brush(
  id: 'px',
  name: 'px',
  size: size,
  opacity: 100,
  spacing: spacing,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: true,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: PressureRangeSetting(enabled: pressureSize, weak: 10, strong: 100),
  ),
  fadeMode: fade ? FadeMode.custom : FadeMode.off,
  // 入り抜きの値が100%なら太さは変わらず、ペンを離した後の描き直しだけが起きる。
  fadeIn: const FadeEndpointSettings(value: 100, rangePx: 30),
  fadeOut: const FadeEndpointSettings(value: 100, rangePx: 30),
  strokeDecay: false,
  outlineEnabled: outline,
  outlineWidth: 1,
  outlineColor: 0xFF0000FF,
  lateralRepeatEnabled: repeat,
  lateralRepeatCount: 3,
  lateralRepeatSpacing: 4,
  customImagePaths: images,
  scatter: scatter,
  calligraphyAngle: calligraphy,
  nibWidthRatio: 0.25,
);

/// [points]をペンの線として描き、描かれた画素（不透明度）を返す。
/// [replay]は、キャンバスと同じくペンを離した後に線を描き直す。
Uint8List _draw(
  Brush brush,
  List<List<StrokePoint>> strokes, {
  bool eraser = false,
  bool replay = false,
  void Function(Uint8List alpha)? afterEachPoint,
  void Function(Uint8List rgba)? tile,
}) {
  final tm = TileManager(canvasWidth: _size, canvasHeight: _size);
  if (eraser) {
    final tile = tm.getOrCreateTile(_layer, 0, 0);
    for (var i = 3; i < tile.length; i += 4) {
      tile[i] = 255;
    }
  }
  final engine = DrawingEngine(tileManager: tm)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF000000)
    ..pressureEnabled = true
    ..isEraser = eraser;
  for (final stroke in strokes) {
    tm.beginUndoRecording(_layer);
    engine.beginStroke(stroke.first, _layer);
    afterEachPoint?.call(_alpha(tm));
    for (final p in stroke.skip(1)) {
      engine.continueStroke(p, _layer);
      afterEachPoint?.call(_alpha(tm));
    }
    if (replay && engine.needsFinalFadeReplay) {
      final drawn = tm.endUndoRecording();
      tm.applyTileSnapshot(_layer, drawn.before);
      tm.beginUndoRecording(_layer);
      engine.replayCurrentStrokeWithFinalFade();
    }
    engine.endStroke();
    tm.endUndoRecording();
  }
  final alpha = _alpha(tm);
  final drawn = tm.getTile(_layer, 0, 0);
  if (drawn != null) tile?.call(Uint8List.fromList(drawn));
  tm.dispose();
  return alpha;
}

Uint8List _alpha(TileManager tm) {
  final out = Uint8List(_size * _size);
  final tile = tm.getTile(_layer, 0, 0);
  if (tile == null) return out;
  for (var i = 0; i < out.length; i++) {
    out[i] = tile[i * 4 + 3];
  }
  return out;
}

bool _ink(Uint8List a, int x, int y) =>
    x >= 0 && y >= 0 && x < _size && y < _size && a[y * _size + x] > 0;

int _components(Uint8List a) {
  final seen = Uint8List(a.length);
  var count = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] == 0 || seen[i] == 1) continue;
    count++;
    final stack = [i];
    seen[i] = 1;
    while (stack.isNotEmpty) {
      final k = stack.removeLast();
      final x = k % _size, y = k ~/ _size;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (!_ink(a, x + dx, y + dy)) continue;
          final j = (y + dy) * _size + x + dx;
          if (seen[j] == 0) {
            seen[j] = 1;
            stack.add(j);
          }
        }
      }
    }
  }
  return count;
}

/// 2×2の画素のうち3つ以上が塗られた所（L字の角・ダマ）。
List<String> _clumps(Uint8List a) => [
  for (var y = 0; y < _size - 1; y++)
    for (var x = 0; x < _size - 1; x++)
      if ([
            _ink(a, x, y),
            _ink(a, x + 1, y),
            _ink(a, x, y + 1),
            _ink(a, x + 1, y + 1),
          ].where((v) => v).length >=
          3)
        '($x,$y)',
];

int _inked(Uint8List a) => a.where((v) => v > 0).length;

/// 線の途中の断面（傾きの小さい線は列、大きい線は行）ごとの画素の数。
List<int> _crossSections(Uint8List a, ui.Offset from, ui.Offset to, int skip) {
  final shallow = (to.dx - from.dx).abs() >= (to.dy - from.dy).abs();
  final length = (to - from).distance;
  final counts = <int>[];
  for (var s = skip.toDouble(); s <= length - skip; s++) {
    final p = from + (to - from) * (s / length);
    var count = 0;
    for (var k = 0; k < _size; k++) {
      count += shallow
          ? (_ink(a, p.dx.floor(), k) ? 1 : 0)
          : (_ink(a, k, p.dy.floor()) ? 1 : 0);
    }
    counts.add(count);
  }
  return counts;
}

/// [from]から[to]の直線を、[spacing]px前後（±30%）ごとの点で描く。
List<StrokePoint> _line(
  ui.Offset from,
  ui.Offset to, {
  double spacing = 3,
  int seed = 1,
  double Function(double t)? pressure,
}) {
  final rng = math.Random(seed);
  final length = (to - from).distance;
  final points = <StrokePoint>[];
  for (var s = 0.0; s < length; s += spacing * (0.7 + 0.6 * rng.nextDouble())) {
    final p = from + (to - from) * (s / length);
    points.add(
      StrokePoint(x: p.dx, y: p.dy, pressure: pressure?.call(s / length) ?? 1),
    );
  }
  points.add(StrokePoint(x: to.dx, y: to.dy, pressure: pressure?.call(1) ?? 1));
  return points;
}

/// 曲線[f]（0〜1）を[spacing]px前後ごとの点で描く。
List<StrokePoint> _curve(
  ui.Offset Function(double t) f, {
  double spacing = 3,
  double jitter = 0,
  int seed = 1,
  double Function(double t)? pressure,
}) {
  final rng = math.Random(seed);
  final dense = [for (var i = 0; i <= 4000; i++) f(i / 4000)];
  final points = <StrokePoint>[];
  var travelled = 0.0;
  var next = 0.0;
  for (var i = 0; i < dense.length; i++) {
    if (i > 0) travelled += (dense[i] - dense[i - 1]).distance;
    if (travelled + 1e-9 < next && i < dense.length - 1) continue;
    final t = i / (dense.length - 1);
    points.add(
      StrokePoint(
        x: dense[i].dx + jitter * (rng.nextDouble() * 2 - 1),
        y: dense[i].dy + jitter * (rng.nextDouble() * 2 - 1),
        pressure: pressure?.call(t) ?? 1,
      ),
    );
    next = travelled + spacing * (0.7 + 0.6 * rng.nextDouble());
  }
  return points;
}

ui.Offset Function(double) _circle(ui.Offset c, double r) =>
    (t) => c + ui.Offset.fromDirection(t * 2 * math.pi, r);

ui.Offset Function(double) _sCurve(ui.Offset origin) =>
    (t) => origin + ui.Offset(170 * t, 50 * math.sin(t * 2 * math.pi));

/// 塗られた画素を、1本の線としてたどった順（端から）。
List<(int, int)> _trace(Uint8List a) {
  final ink = <(int, int)>{
    for (var i = 0; i < a.length; i++)
      if (a[i] > 0) (i % _size, i ~/ _size),
  };
  List<(int, int)> near((int, int) c) => [
    for (var dy = -1; dy <= 1; dy++)
      for (var dx = -1; dx <= 1; dx++)
        if ((dx != 0 || dy != 0) && ink.contains((c.$1 + dx, c.$2 + dy)))
          (c.$1 + dx, c.$2 + dy),
  ];
  final ends = ink.where((c) => near(c).length == 1).toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  final path = [ends.isEmpty ? ink.first : ends.first];
  final seen = {path.first};
  while (true) {
    final next = near(path.last).where((c) => !seen.contains(c)).toList()
      ..sort(
        (a, b) => ((a.$1 - path.last.$1).abs() + (a.$2 - path.last.$2).abs())
            .compareTo(
              (b.$1 - path.last.$1).abs() + (b.$2 - path.last.$2).abs(),
            ),
      );
    if (next.isEmpty) break;
    path.add(next.first);
    seen.add(next.first);
  }
  return path;
}

/// 横寄りの1画素の線の、同じ行に並ぶ画素の数（ラン）の並び。
List<int> _rowRuns(List<(int, int)> path) {
  final runs = <int>[];
  var run = 1;
  for (var i = 1; i < path.length; i++) {
    if (path[i].$2 == path[i - 1].$2) {
      run++;
    } else {
      runs.add(run);
      run = 1;
    }
  }
  runs.add(run);
  return runs;
}

/// 線の途中のランで、両隣より2以上短い・長いもの（段がつまる・のびる所）。
/// 線の最初と最後のランは、線の端で切れているので比べない。
List<String> _jags(List<int> runs) => [
  for (var i = 2; i + 2 < runs.length; i++)
    if (runs[i] <= math.min(runs[i - 1], runs[i + 1]) - 2 ||
        runs[i] >= math.max(runs[i - 1], runs[i + 1]) + 2)
      '${runs[i - 1]}-${runs[i]}-${runs[i + 1]}',
];

/// 線の内側（両端から[margin]px）の、線に直角に測った平均の太さ
/// （塗った画素の数÷長さ）。
double _meanThickness(
  Uint8List a,
  ui.Offset from,
  ui.Offset to,
  double margin,
) {
  final length = (to - from).distance;
  final dir = (to - from) / length;
  var area = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] == 0) continue;
    final c = ui.Offset(i % _size + 0.5, i ~/ _size + 0.5) - from;
    final along = c.dx * dir.dx + c.dy * dir.dy;
    if (along >= margin && along < length - margin) area++;
  }
  return area / (length - 2 * margin);
}

/// 塗った画素の重心から、ペンの位置までのずれ。
ui.Offset _centroidOffset(Uint8List a, ui.Offset pen) {
  var x = 0.0, y = 0.0, n = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] == 0) continue;
    x += i % _size + 0.5;
    y += i ~/ _size + 0.5;
    n++;
  }
  return ui.Offset(x / n - pen.dx, y / n - pen.dy);
}

/// 同じ不透明度で、ちょうど不透明か透明の画素だけ。
bool _crisp(Uint8List a) => a.every((v) => v == 0 || v == 255);

/// つながった画素のかたまりごとの画素の数。
List<int> _componentSizes(Uint8List a) {
  final seen = Uint8List(a.length);
  final sizes = <int>[];
  for (var i = 0; i < a.length; i++) {
    if (a[i] == 0 || seen[i] == 1) continue;
    var count = 0;
    final stack = [i];
    seen[i] = 1;
    while (stack.isNotEmpty) {
      final k = stack.removeLast();
      count++;
      final x = k % _size, y = k ~/ _size;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (!_ink(a, x + dx, y + dy)) continue;
          final j = (y + dy) * _size + x + dx;
          if (seen[j] == 0) {
            seen[j] = 1;
            stack.add(j);
          }
        }
      }
    }
    sizes.add(count);
  }
  return sizes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a 1px line at any angle has one pixel per step and no L-corners', () {
    final rng = math.Random(3);
    for (var degrees = 0; degrees <= 360; degrees += 3) {
      for (final spacing in [3.0, 0.3, 30.0]) {
        final from = ui.Offset(128 + rng.nextDouble(), 128 + rng.nextDouble());
        final to = from + ui.Offset.fromDirection(degrees * math.pi / 180, 110);
        final a = _draw(_pixelBrush(1), [
          _line(from, to, spacing: spacing, seed: degrees),
        ]);
        final reason = '$degrees° every ${spacing}px';
        expect(_components(a), 1, reason: '$reason: broken');
        expect(_clumps(a), isEmpty, reason: '$reason: L-corners');
        expect(_crossSections(a, from, to, 1).toSet(), {
          1,
        }, reason: '$reason: one pixel per step');
      }
    }
  });

  test('1px circles, arcs and curves have no L-corners and stay connected', () {
    final rng = math.Random(5);
    for (var i = 0; i < 24; i++) {
      final centre = ui.Offset(
        128 + rng.nextDouble() * 4,
        128 + rng.nextDouble() * 4,
      );
      final radius = 8 + rng.nextDouble() * 100;
      for (final spacing in [3.0, 0.25, 12.0]) {
        final a = _draw(_pixelBrush(1), [
          _curve(_circle(centre, radius), spacing: spacing, seed: i),
        ]);
        final reason = 'r=${radius.toStringAsFixed(1)} every ${spacing}px';
        expect(_components(a), 1, reason: reason);
        expect(_clumps(a), isEmpty, reason: reason);
      }
    }
    final s = _draw(_pixelBrush(1), [
      _curve(_sCurve(const ui.Offset(40.3, 128.6))),
    ]);
    expect(_components(s), 1);
    expect(_clumps(s), isEmpty);
  });

  test('every dot of a pixel brush is the same grid-locked shape, centred on '
      'the pen', () {
    // ドット絵のブラシと同じ形：1は1画素、2は2×2、3は十字、4以上は円。
    // 偶数の太さは画素の角が中心で、ペンにいちばん近い角に置く。
    const expected = {1: 1, 2: 4, 3: 5, 4: 12, 5: 21, 6: 32};
    for (final entry in expected.entries) {
      final diameter = entry.key;
      List<String>? first;
      for (final offset in [0.02, 0.27, 0.45, 0.55, 0.73, 0.98]) {
        final pen = ui.Offset(100 + offset, 60 + (1 - offset));
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          [StrokePoint(x: pen.dx, y: pen.dy)],
        ]);
        expect(_inked(a), entry.value, reason: 'size $diameter at +$offset');
        expect(_crisp(a), isTrue);
        // 形はどこでも同じ（位置だけが変わる）。
        final xs = [
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0) i % _size,
        ];
        final ys = [
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0) i ~/ _size,
        ];
        final left = xs.reduce(math.min), top = ys.reduce(math.min);
        final shape = [
          for (var y = top; y < top + diameter; y++)
            [
              for (var x = left; x < left + diameter; x++)
                _ink(a, x, y) ? '#' : '.',
            ].join(),
        ];
        first ??= shape;
        expect(shape, first, reason: 'size $diameter at +$offset');
        // ドットの中心は、ペンから縦横とも半画素以内。
        final off = _centroidOffset(a, pen);
        expect(off.dx.abs(), lessThanOrEqualTo(0.5), reason: '$diameter $off');
        expect(off.dy.abs(), lessThanOrEqualTo(0.5), reason: '$diameter $off');
      }
      for (var j = 0; j < diameter; j++) {
        for (var i = 0; i < diameter; i++) {
          expect(
            pixelDotCovers(diameter, i, j),
            pixelDotCovers(diameter, diameter - 1 - i, j) &&
                pixelDotCovers(diameter, j, i),
            reason: 'size $diameter is symmetric',
          );
        }
      }
    }
    // 間を空けて置くドットも、どれも同じ形。
    final dotted = _draw(_pixelBrush(4, spacing: 13), [
      _line(const ui.Offset(20.3, 40.8), const ui.Offset(230.6, 52.1)),
    ]);
    expect(_components(dotted), greaterThan(10));
    expect(_inked(dotted), _components(dotted) * 12);
  });

  test('even sizes are centred on the pen, not half a pixel up-left', () {
    // 偶数の太さのドットは、ペンの位置を中心に置く（以前は半画素左上）。
    for (final diameter in [2, 4, 6]) {
      final rng = math.Random(diameter);
      var sum = ui.Offset.zero;
      const taps = 60;
      for (var k = 0; k < taps; k++) {
        final pen = ui.Offset(120 + rng.nextDouble(), 120 + rng.nextDouble());
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          [StrokePoint(x: pen.dx, y: pen.dy)],
        ]);
        sum += _centroidOffset(a, pen);
      }
      final mean = sum / taps.toDouble();
      expect(mean.dx.abs(), lessThan(0.12), reason: 'size $diameter $mean');
      expect(mean.dy.abs(), lessThan(0.12), reason: 'size $diameter $mean');
      // 横の線も、ペンの道が帯の真ん中。
      for (final y in [100.2, 100.5, 100.8]) {
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          _line(ui.Offset(30.3, y), ui.Offset(200.6, y), spacing: 2),
        ]);
        final rows = {
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0 && i % _size == 120) i ~/ _size,
        };
        final centre = (rows.reduce(math.min) + rows.reduce(math.max) + 1) / 2;
        expect(rows, hasLength(diameter));
        expect((centre - y).abs(), lessThanOrEqualTo(0.5), reason: '$y $rows');
      }
    }
  });

  test('a tilted stylus draws the same pixel dots as an upright one', () {
    // ペンを寝かせても、ドットは伸びず半透明にもならない。
    for (var diameter = 1; diameter <= 6; diameter++) {
      List<StrokePoint> stroke(double tilt) => [
        for (final p in _curve(_sCurve(const ui.Offset(40.4, 128.2))))
          StrokePoint(x: p.x, y: p.y, tiltX: tilt * 0.8, tiltY: tilt * 0.6),
      ];
      final upright = _draw(_pixelBrush(diameter.toDouble()), [stroke(0)]);
      final tilted = _draw(_pixelBrush(diameter.toDouble()), [stroke(1.2)]);
      expect(tilted, upright, reason: 'size $diameter');
      expect(tilted.where((v) => v != 0 && v != 255), isEmpty);
    }
  });

  test('thick pixel lines keep the same thickness at every angle', () {
    // 線に直角に測った太さ（塗った画素の数÷長さ）が、どの角度でも太さの
    // ±12%以内（太さ3の十字を並べると45°で0.71倍、太さ6の円は1.12倍だった）。
    // 縁はこぶの無い段：横寄りの線の列ごとの画素は1つながりで、数は1しか
    // 変わらない。
    final rng = math.Random(9);
    for (var diameter = 2; diameter <= 8; diameter++) {
      for (var degrees = 0; degrees <= 90; degrees += 3) {
        final from = ui.Offset(40 + rng.nextDouble(), 210 + rng.nextDouble());
        final to =
            from + ui.Offset.fromDirection(-degrees * math.pi / 180, 150);
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          _line(from, to, seed: degrees),
        ]);
        final reason = 'size $diameter at $degrees°';
        expect(_components(a), 1, reason: reason);
        expect(_crisp(a), isTrue, reason: reason);
        final thickness = _meanThickness(a, from, to, diameter + 6.0);
        expect(
          thickness / diameter,
          inInclusiveRange(0.88, 1.12),
          reason: '$reason: $thickness',
        );
        final counts = _crossSections(a, from, to, diameter + 2);
        expect(
          counts.reduce(math.max) - counts.reduce(math.min),
          lessThanOrEqualTo(1),
          reason: '$reason: $counts',
        );
        if (degrees == 0 || degrees == 90) {
          expect(counts.toSet(), {diameter}, reason: reason);
        }
        if (degrees == 45) expect(counts.toSet().length, 1, reason: reason);
        // 横寄りの線は、どの列も1つながり。
        final shallow = degrees <= 45;
        final length = (to - from).distance;
        for (var t = diameter + 4.0; t < length - diameter - 4; t++) {
          final p = from + (to - from) * (t / length);
          final cells = [
            for (var k = 0; k < _size; k++)
              if (shallow ? _ink(a, p.dx.floor(), k) : _ink(a, k, p.dy.floor()))
                k,
          ];
          expect(
            cells.last - cells.first + 1,
            cells.length,
            reason: '$reason: a gap in $cells',
          );
        }
      }
    }
  });

  test('thick pixel circles keep the same thickness all the way round', () {
    for (var diameter = 2; diameter <= 7; diameter++) {
      for (final radius in [24.0, 60.0, 100.0]) {
        const centre = ui.Offset(128.4, 128.3);
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          _curve(_circle(centre, radius), spacing: 2),
        ]);
        expect(_crisp(a), isTrue);
        // 中心からの半直線ごとに、帯を横切る長さ（0.05pxずつ調べる）。
        final widths = <double>[];
        for (var k = 0; k < 360; k++) {
          final dir = ui.Offset.fromDirection(k * math.pi / 180, 1);
          var inside = 0;
          for (var r = radius - 12; r <= radius + 12; r += 0.05) {
            final p = centre + dir * r;
            if (_ink(a, p.dx.floor(), p.dy.floor())) inside++;
          }
          widths.add(inside * 0.05);
        }
        final mean = widths.reduce((a, b) => a + b) / widths.length;
        final reason = 'size $diameter radius $radius: mean $mean';
        expect(mean / diameter, inInclusiveRange(0.9, 1.15), reason: reason);
        // 10°ごとの平均も太さの0.8〜1.25倍（十字を並べた太さ3は45°の
        // あたりで0.71倍だった）。
        for (var sector = 0; sector < 36; sector++) {
          final part = widths.sublist(sector * 10, sector * 10 + 10);
          final average = part.reduce((a, b) => a + b) / part.length;
          expect(
            average / diameter,
            inInclusiveRange(0.8, 1.25),
            reason: '$reason, ${sector * 10}°: $average',
          );
        }
      }
    }
  });

  test('sparse points leave no gaps', () {
    for (var diameter = 1; diameter <= 6; diameter++) {
      for (final spacing in [25.0, 40.0]) {
        for (final curve in [
          _sCurve(const ui.Offset(40.4, 128.2)),
          _circle(const ui.Offset(128.5, 128.5), 90),
        ]) {
          final a = _draw(_pixelBrush(diameter.toDouble()), [
            _curve(curve, spacing: spacing),
          ]);
          final reason = 'size $diameter every ${spacing}px';
          expect(_components(a), 1, reason: reason);
          if (diameter == 1) expect(_clumps(a), isEmpty, reason: reason);
        }
      }
    }
  });

  test(
    'a slow stroke gives the same pixels as a fast one over the same path',
    () {
      final rng = math.Random(11);
      for (var diameter = 1; diameter <= 6; diameter++) {
        for (var degrees = 0; degrees < 360; degrees += 17) {
          final from = ui.Offset(
            128 + rng.nextDouble(),
            128 + rng.nextDouble(),
          );
          final corner =
              from + ui.Offset.fromDirection(degrees * math.pi / 180, 70);
          final to =
              corner +
              ui.Offset.fromDirection((degrees + 70) * math.pi / 180, 40);
          final fast = [
            StrokePoint(x: from.dx, y: from.dy),
            StrokePoint(x: corner.dx, y: corner.dy),
            StrokePoint(x: to.dx, y: to.dy),
          ];
          // 同じ折れ線の上を、1画素に何個も点が入る細かさでなぞる。
          final slow = [
            ..._line(from, corner, spacing: 0.1, seed: degrees),
            ..._line(corner, to, spacing: 0.1, seed: degrees + 1).skip(1),
          ];
          expect(
            _draw(_pixelBrush(diameter.toDouble()), [slow]),
            _draw(_pixelBrush(diameter.toDouble()), [fast]),
            reason: 'size $diameter at $degrees°',
          );
        }
      }
    },
  );

  test('a slow stroke with hand tremor on a pixel edge stays one row', () {
    // ペン先が行の境目の上を震えながら進んでも、隣の行と行き来しない。
    final rng = math.Random(13);
    final points = [
      for (var x = 20.0; x < 230; x += 0.08)
        StrokePoint(x: x, y: 100.0 + (rng.nextDouble() * 2 - 1) * 0.3),
    ];
    final a = _draw(_pixelBrush(1), [points]);
    expect(_clumps(a), isEmpty);
    final rows = {
      for (var i = 0; i < a.length; i++)
        if (a[i] > 0) i ~/ _size,
    };
    expect(rows, hasLength(1));
    expect(_inked(a), 230 - 20);
  });

  test('the pixel under the pen is drawn on the same event', () {
    // 描いている途中も、ペンの下の画素はその場で描く（以前は1画素遅れた）。
    final rng = math.Random(17);
    for (var diameter = 1; diameter <= 4; diameter++) {
      for (var s = 0; s < 16; s++) {
        final from = ui.Offset(
          90 + rng.nextDouble() * 40,
          90 + rng.nextDouble() * 40,
        );
        final points = _curve(
          (t) =>
              from +
              ui.Offset.fromDirection(s * 0.4, 60 * t) +
              ui.Offset(0, 6 * math.sin(t * 5)),
          spacing: 0.6,
          seed: s,
        );
        var i = 0;
        _draw(
          _pixelBrush(diameter.toDouble()),
          [points],
          afterEachPoint: (a) {
            final pen = points[i++];
            final x = diameter.isEven ? pen.x.round() : pen.x.floor();
            final y = diameter.isEven ? pen.y.round() : pen.y.floor();
            // 偶数の太さはペンにいちばん近い角のまわりの4画素のどれか。
            final cells = diameter.isEven
                ? [(x - 1, y - 1), (x, y - 1), (x - 1, y), (x, y)]
                : [(x, y)];
            expect(
              cells.any((c) => _ink(a, c.$1, c.$2)),
              isTrue,
              reason: 'size $diameter stroke $s event ${i - 1}',
            );
          },
        );
      }
    }
  });

  test('the live stroke, the finished stroke and its replay agree', () {
    for (var diameter = 1; diameter <= 4; diameter++) {
      final stroke = _curve(
        _sCurve(const ui.Offset(40.4, 128.2)),
        spacing: 2,
        jitter: 0.4,
        seed: diameter,
      );
      final live = <Uint8List>[];
      final drawn = _draw(_pixelBrush(diameter.toDouble()), [
        stroke,
      ], afterEachPoint: live.add);
      // 描いている途中の画素は、ペン先の近く（ランを整える範囲と線の太さ）を
      // 除いて、その時点でペンを離した線と同じで、後で消えない。
      const reach = 16 + 6;
      for (var f = 0; f < live.length; f += f < 20 ? 1 : 7) {
        final pen = ui.Offset(stroke[f].x, stroke[f].y);
        final lifted = _draw(_pixelBrush(diameter.toDouble()), [
          stroke.sublist(0, f + 1),
        ]);
        for (var i = 0; i < drawn.length; i++) {
          final p = ui.Offset(i % _size + 0.5, i ~/ _size + 0.5);
          if ((p - pen).distance < reach + diameter) continue;
          final reason = 'size $diameter frame $f pixel $p pen $pen';
          expect(live[f][i] > 0, lifted[i] > 0, reason: reason);
          if (live[f][i] > 0) expect(drawn[i], greaterThan(0), reason: reason);
        }
      }
      final replayed = _draw(_pixelBrush(diameter.toDouble(), fade: true), [
        stroke,
      ], replay: true);
      expect(replayed, drawn, reason: 'size $diameter replay');
      expect(
        _draw(_pixelBrush(diameter.toDouble()), [stroke]),
        drawn,
        reason: 'size $diameter drawn again',
      );
    }
  });

  test('pressure changes the dot size in whole pixels', () {
    final stroke = _line(
      const ui.Offset(20.3, 100.6),
      const ui.Offset(230.7, 100.6),
      spacing: 2,
      pressure: (t) => t,
    );
    final a = _draw(_pixelBrush(7, pressureSize: true), [stroke]);
    expect(a.where((v) => v != 0 && v != 255), isEmpty);
    expect(_components(a), 1);
    final counts = _crossSections(
      a,
      const ui.Offset(20.3, 100.6),
      const ui.Offset(230.7, 100.6),
      4,
    );
    expect(counts.first, 1);
    expect(counts.last, 7);
    // 筆圧が強くなるほど太く、途中で細くならない。
    for (var i = 1; i < counts.length; i++) {
      expect(counts[i], greaterThanOrEqualTo(counts[i - 1]), reason: '$counts');
    }
  });

  test('mixing pixel brushes end the same however the points arrive', () {
    // まだ変わりうるペン先の画素を戻すとき、油彩風の絵の具・水彩風の
    // ぬれ具合も戻すので、ゆっくり描いても一度に描いても同じ線になる。
    for (final mode in [BrushMixingMode.oil, BrushMixingMode.watercolor]) {
      final brush = _pixelBrush(3).copyWith(
        pressureOn: BrushPressureOnSettings.defaults.copyWith(
          mixing: PressureMixingOnSetting(
            enabled: true,
            mode: mode,
            weakRate: 60,
            strongRate: 60,
          ),
        ),
      );
      List<StrokePoint> path(double spacing) => [
        ..._line(
          const ui.Offset(30.3, 60.6),
          const ui.Offset(200.7, 140.2),
          spacing: spacing,
          seed: 3,
        ),
        ..._line(
          const ui.Offset(200.7, 140.2),
          const ui.Offset(60.2, 200.8),
          spacing: spacing,
          seed: 4,
        ).skip(1),
      ];
      late Uint8List slow, fast;
      // 下に色を塗っておく（混ざる相手）。
      final under = _line(
        const ui.Offset(20.2, 120.3),
        const ui.Offset(230.4, 110.6),
        spacing: 2,
      );
      _draw(brush, [under, path(0.4)], tile: (t) => slow = t);
      _draw(brush, [
        under,
        [
          path(0.4).first,
          const StrokePoint(x: 200.7, y: 140.2),
          path(0.4).last,
        ],
      ], tile: (t) => fast = t);
      expect(slow, fast, reason: '$mode');
    }
  });

  test('the pixel eraser removes exactly the pixels the pixel pen paints', () {
    for (var diameter = 1; diameter <= 6; diameter++) {
      final strokes = [
        _curve(_sCurve(const ui.Offset(40.4, 128.2)), jitter: 0.3),
        _curve(_circle(const ui.Offset(128.5, 128.5), 60), spacing: 7),
      ];
      final painted = _draw(_pixelBrush(diameter.toDouble()), strokes);
      final erased = _draw(
        _pixelBrush(diameter.toDouble()),
        strokes,
        eraser: true,
      );
      for (var i = 0; i < painted.length; i++) {
        expect(erased[i], painted[i] > 0 ? 0 : 255, reason: 'size $diameter');
      }
    }
  });

  test('a stroke records only its own pixels for the colour post-process', () {
    final tm = TileManager(canvasWidth: _size, canvasHeight: _size);
    final tile = tm.getOrCreateTile(_layer, 0, 0);
    // 線の外の、前から描いてあった画素。
    for (var x = 0; x < 30; x++) {
      tile[(10 * _size + x) * 4 + 3] = 255;
    }
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _pixelBrush(3)
      ..currentColor = const ui.Color(0xFF000000);
    tm.beginUndoRecording(_layer);
    final stroke = _curve(_sCurve(const ui.Offset(40.4, 128.2)), jitter: 0.3);
    engine.beginStroke(stroke.first, _layer);
    for (final p in stroke.skip(1)) {
      engine.continueStroke(p, _layer);
    }
    engine.endStroke();
    var transformed = 0;
    tm.transformRecordingPixels((pixels) {
      final out = Uint8List.fromList(pixels);
      for (var i = 0; i < out.length; i += 4) {
        if (out[i + 3] == 0) continue;
        transformed++;
        out[i + 1] = out[i + 3];
      }
      return out;
    });
    final snapshot = tm.endUndoRecording();
    final drawn = tm.getTile(_layer, 0, 0)!;
    var green = 0;
    for (var i = 0; i < drawn.length; i += 4) {
      if (drawn[i + 1] > 0) green++;
    }
    final strokeOnly = _draw(_pixelBrush(3), [stroke]);
    expect(transformed, _inked(strokeOnly));
    expect(green, _inked(strokeOnly));
    for (var x = 0; x < 30; x++) {
      expect(drawn[(10 * _size + x) * 4 + 1], 0);
    }
    tm.applyTileSnapshot(_layer, snapshot.before);
    expect(_inked(_alpha(tm)), 30);
    tm.dispose();
  });

  test('the shape tool keeps rectangle corners and cleans its other lines', () {
    final tm = TileManager(canvasWidth: _size, canvasHeight: _size);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _pixelBrush(1)
      ..currentColor = const ui.Color(0xFF000000);
    engine.commitShapePath(
      const [
        StrokePoint(x: 10.3, y: 10.6),
        StrokePoint(x: 60.8, y: 10.6),
        StrokePoint(x: 60.8, y: 55.2),
        StrokePoint(x: 10.3, y: 55.2),
      ],
      _layer,
      closeLoop: true,
      removePixelCorners: false,
    );
    final rect = _alpha(tm);
    for (final (x, y) in [(10, 10), (60, 10), (60, 55), (10, 55)]) {
      expect(_ink(rect, x, y), isTrue, reason: 'corner ($x, $y)');
    }
    expect(_inked(rect), 2 * (51 + 46) - 4);
    tm.dispose();
  });

  test('rectangles keep full square corners at every size', () {
    // 太い四角形も角が欠けない（太さ3の十字を並べると外側の角が欠けた）。
    for (var diameter = 1; diameter <= 6; diameter++) {
      final tm = TileManager(canvasWidth: _size, canvasHeight: _size);
      DrawingEngine(tileManager: tm)
        ..currentBrush = _pixelBrush(diameter.toDouble())
        ..currentColor = const ui.Color(0xFF000000)
        ..commitShapePath(
          const [
            StrokePoint(x: 30.3, y: 30.6),
            StrokePoint(x: 120.8, y: 30.6),
            StrokePoint(x: 120.8, y: 95.2),
            StrokePoint(x: 30.3, y: 95.2),
          ],
          _layer,
          closeLoop: true,
          removePixelCorners: false,
        );
      final a = _alpha(tm);
      tm.dispose();
      final reason = 'size $diameter';
      // 外側の縁はちょうど四角：塗った画素を囲む四角の4つの角が塗られていて、
      // どの行・列も外側から内側まで太さぶんの画素が続く。
      final xs = [
        for (var i = 0; i < a.length; i++)
          if (a[i] > 0) i % _size,
      ];
      final ys = [
        for (var i = 0; i < a.length; i++)
          if (a[i] > 0) i ~/ _size,
      ];
      final left = xs.reduce(math.min), right = xs.reduce(math.max);
      final top = ys.reduce(math.min), bottom = ys.reduce(math.max);
      for (final (x, y) in [
        (left, top),
        (right, top),
        (left, bottom),
        (right, bottom),
      ]) {
        for (var j = 0; j < diameter; j++) {
          for (var i = 0; i < diameter; i++) {
            final cx = x == left ? x + i : x - i;
            final cy = y == top ? y + j : y - j;
            expect(
              _ink(a, cx, cy),
              isTrue,
              reason: '$reason corner ($cx, $cy)',
            );
          }
        }
      }
      for (var y = top; y <= bottom; y++) {
        final row = [
          for (var x = left; x <= right; x++)
            if (_ink(a, x, y)) x,
        ];
        final band = y < top + diameter || y > bottom - diameter;
        expect(
          row.length,
          band ? right - left + 1 : 2 * diameter,
          reason: '$reason row $y',
        );
      }
    }
  });

  test('the pixel ellipse is the midpoint ellipse, smooth and symmetric', () {
    // ピクセルモードの楕円は48角形ではなく、四角に内接する画素の楕円。
    for (final (l, t, r, b) in [
      (40.3, 50.2, 210.8, 190.6),
      (60.6, 70.1, 100.2, 160.9),
      (20.2, 120.3, 230.7, 135.8),
      (100.1, 100.2, 141.4, 141.7),
    ]) {
      for (var diameter = 1; diameter <= 4; diameter++) {
        final tm = TileManager(canvasWidth: _size, canvasHeight: _size);
        final engine = DrawingEngine(tileManager: tm)
          ..currentBrush = _pixelBrush(diameter.toDouble())
          ..currentColor = const ui.Color(0xFF000000);
        final rect = ui.Rect.fromLTRB(l, t, r, b);
        Function.apply(
          engine.commitShapePath,
          [
            [
              for (var i = 0; i < 48; i++)
                StrokePoint(
                  x:
                      rect.center.dx +
                      rect.width / 2 * math.cos(i / 48 * 2 * math.pi),
                  y:
                      rect.center.dy +
                      rect.height / 2 * math.sin(i / 48 * 2 * math.pi),
                ),
            ],
            _layer,
          ],
          {#closeLoop: true, #ellipse: rect},
        );
        final a = _alpha(tm);
        tm.dispose();
        final reason = 'size $diameter in $rect';
        expect(_components(a), 1, reason: reason);
        expect(_crisp(a), isTrue, reason: reason);
        // 上下・左右に対称。
        final xs = [
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0) i % _size,
        ];
        final ys = [
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0) i ~/ _size,
        ];
        final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max);
        final y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            expect(
              _ink(a, x, y),
              _ink(a, x0 + x1 - x, y),
              reason: '$reason ($x, $y)',
            );
            expect(
              _ink(a, x, y),
              _ink(a, x, y0 + y1 - y),
              reason: '$reason ($x, $y)',
            );
          }
        }
        if (diameter == 1) {
          // L字の角・ダマが無い。平たい楕円の端だけは上下の弧が1画素の幅の
          // 中で出会うので、端の列の2×2は残る。
          for (final c in _clumps(a)) {
            final x = int.parse(c.substring(1, c.indexOf(',')));
            expect(x <= x0 + 1 || x >= x1 - 2, isTrue, reason: '$reason $c');
          }
        }
        if (diameter == 1) {
          // 画素の中心は、本当の楕円（端の画素の中心を通る）から0.75px以内
          // （陰関数の値÷傾きの大きさで測る）。
          final cx = (x0 + x1 + 1) / 2, cy = (y0 + y1 + 1) / 2;
          final rx = (x1 - x0) / 2, ry = (y1 - y0) / 2;
          for (var i = 0; i < a.length; i++) {
            if (a[i] == 0) continue;
            final dx = i % _size + 0.5 - cx, dy = i ~/ _size + 0.5 - cy;
            final f = dx * dx / (rx * rx) + dy * dy / (ry * ry) - 1;
            final gx = 2 * dx / (rx * rx), gy = 2 * dy / (ry * ry);
            final distance = f.abs() / math.sqrt(gx * gx + gy * gy);
            expect(distance, lessThan(0.75), reason: '$reason pixel $i');
          }
        }
      }
    }
  });

  test('gentle freehand slopes and arcs step evenly', () {
    // ゆるい傾き・ゆるい曲線を手で描いても、両隣より2以上短い（長い）段
    // （「3・1・3」など）が残らない。
    var jags = <String>[];
    var lines = 0;
    for (var seed = 0; seed < 24; seed++) {
      final rng = math.Random(seed);
      final slope = 0.12 + rng.nextDouble() * 0.36;
      final from = ui.Offset(12.3 + rng.nextDouble(), 60.7 + rng.nextDouble());
      final to = from + ui.Offset(230, 230 * slope);
      final noise = math.Random(seed + 100);
      final points = [
        for (final p in _line(from, to, spacing: 1.2, seed: seed))
          StrokePoint(
            x: p.x + 0.25 * (noise.nextDouble() * 2 - 1),
            y: p.y + 0.25 * (noise.nextDouble() * 2 - 1),
          ),
      ];
      final a = _draw(_pixelBrush(1), [points]);
      expect(_clumps(a), isEmpty);
      jags.addAll(_jags(_rowRuns(_trace(a))).map((j) => 'line $seed: $j'));
      lines++;
      // 大きな円の弧（傾き0〜0.45）。
      final centre = ui.Offset(128.3, 330.6 + rng.nextDouble() * 40);
      final radius = 250 + rng.nextDouble() * 60;
      final arc = _curve(
        (t) => centre + ui.Offset.fromDirection(-math.pi / 2 + 0.4 * t, radius),
        spacing: 1.3,
        jitter: 0.2,
        seed: seed,
      );
      final b = _draw(_pixelBrush(1), [arc]);
      expect(_clumps(b), isEmpty);
      jags.addAll(_jags(_rowRuns(_trace(b))).map((j) => 'arc $seed: $j'));
    }
    expect(jags, isEmpty, reason: '$lines lines');
  });

  test('hand tremor across a pixel edge does not zigzag', () {
    // 行の境目の上を±0.5pxで震えながら進んでも、行と行を行き来しない。
    var changes = 0;
    for (var seed = 0; seed < 10; seed++) {
      final rng = math.Random(seed);
      final points = [
        for (var x = 20.0; x < 220; x += 0.1)
          StrokePoint(x: x, y: 100.0 + (rng.nextDouble() * 2 - 1) * 0.5),
      ];
      final a = _draw(_pixelBrush(1), [points]);
      expect(_clumps(a), isEmpty);
      final path = _trace(a);
      for (var i = 1; i < path.length; i++) {
        if (path[i].$2 != path[i - 1].$2) changes++;
      }
    }
    // 10本、2000pxで、行が変わるのは数回まで（以前は1000回近く）。
    expect(changes, lessThanOrEqualTo(10));
  });

  test('a stroke reaches the pixel where the pen was lifted', () {
    // 画素の境目を少し越えただけで止めた線も、ペンを離した画素まで届く
    // （以前は境目から0.35px未満で止めると1画素短かった）。
    final rng = math.Random(23);
    for (var k = 0; k < 120; k++) {
      final from = ui.Offset(40.5, 110.5 + rng.nextDouble() * 20);
      final angle = (rng.nextDouble() * 2 - 1) * math.pi / 6;
      // 終わりは列の境目から0.05〜0.3px越えた所。
      final length = 60 + rng.nextDouble() * 40;
      var to = from + ui.Offset.fromDirection(angle, length);
      to = ui.Offset(to.dx.floor() + 0.05 + rng.nextDouble() * 0.25, to.dy);
      final a = _draw(_pixelBrush(1), [_line(from, to, spacing: 0.8, seed: k)]);
      final column = [
        for (var y = 0; y < _size; y++)
          if (_ink(a, to.dx.floor(), y)) y,
      ];
      expect(column, isNotEmpty, reason: 'stroke $k to $to');
      expect(_ink(a, to.dx.floor() + 1, to.dy.floor()), isFalse);
    }
  });

  test('a loop that runs past its own start leaves no clump', () {
    // 輪を描いて書き始めを少し越えて終えても、書き始めの線にくっついて並ぶ
    // 画素（ダマ）が残らない。
    for (var diameter = 1; diameter <= 2; diameter++) {
      for (final extra in [0.02, 0.05, 0.08, 0.12, 0.15]) {
        for (final start in [-1.3, 0.4, 2.2]) {
          final a = _draw(_pixelBrush(diameter.toDouble()), [
            _curve(
              (t) =>
                  const ui.Offset(128.3, 128.6) +
                  ui.Offset.fromDirection(
                    start + 2 * math.pi * (1 + extra) * t,
                    40.2,
                  ),
              spacing: 2,
              jitter: 0.1,
              seed: (extra * 100).round(),
            ),
          ]);
          final reason = 'size $diameter, ${extra * 100}% past $start';
          if (diameter == 1) {
            expect(_clumps(a), isEmpty, reason: reason);
          } else {
            // 太さ2：線の外へはみ出す画素が無い（輪の帯の幅は2のまま）。
            for (var k = 0; k < 360; k++) {
              final dir = ui.Offset.fromDirection(k * math.pi / 180, 1);
              var inside = 0;
              for (var r = 30.0; r <= 50; r += 0.05) {
                final p = const ui.Offset(128.3, 128.6) + dir * r;
                if (_ink(a, p.dx.floor(), p.dy.floor())) inside++;
              }
              expect(inside * 0.05, lessThan(3.3), reason: '$reason at $k°');
            }
          }
        }
      }
    }
  });

  test('outlined pixel brushes draw a crisp one-pixel outline', () {
    // 縁取りは、格子に置いた塗りのまわりの1画素の輪（縦横で隣り合う画素）。
    final stroke = _curve(_sCurve(const ui.Offset(40.4, 128.2)), jitter: 0.2);
    for (var diameter = 2; diameter <= 5; diameter++) {
      late Uint8List rgba;
      final a = _draw(_pixelBrush(diameter.toDouble(), outline: true), [
        stroke,
      ], tile: (t) => rgba = t);
      final reason = 'size $diameter';
      expect(_crisp(a), isTrue, reason: reason);
      bool fill(int x, int y) {
        if (!_ink(a, x, y)) return false;
        return rgba[(y * _size + x) * 4 + 2] == 0; // 黒い塗り（縁取りは青）
      }

      var outline = 0;
      for (var y = 1; y < _size - 1; y++) {
        for (var x = 1; x < _size - 1; x++) {
          if (!_ink(a, x, y)) continue;
          if (fill(x, y)) {
            // 塗りの外側の縦横の隣は、塗りか縁取り。
            for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
              expect(
                _ink(a, x + dx, y + dy),
                isTrue,
                reason: '$reason ($x,$y)',
              );
            }
          } else {
            outline++;
            // 縁取りの画素は、どれも縦横で塗りと隣り合う。
            expect(
              [
                (1, 0),
                (-1, 0),
                (0, 1),
                (0, -1),
              ].any((d) => fill(x + d.$1, y + d.$2)),
              isTrue,
              reason: '$reason outline ($x,$y)',
            );
          }
        }
      }
      expect(outline, greaterThan(100), reason: reason);
    }
  });

  test('a lateral repeat draws each line as a clean pixel line', () {
    for (final stroke in [
      _curve(_sCurve(const ui.Offset(40.4, 128.2)), jitter: 0.15),
      _curve(_circle(const ui.Offset(128.5, 128.5), 70), spacing: 3),
    ]) {
      final a = _draw(_pixelBrush(1, repeat: true), [stroke]);
      expect(_crisp(a), isTrue);
      // 3本の線が、それぞれ1画素の線（2×2のダマが無い）。
      expect(_components(a), 3);
      expect(_clumps(a), isEmpty);
    }
  });

  test('pixel tip images are one fixed pixel shape on the grid', () async {
    await preloadBrushTextures(['assets/brushes/hexagon_tip.png']);
    final a = _draw(
      _pixelBrush(9, images: ['assets/brushes/hexagon_tip.png'], spacing: 14),
      [_curve(_sCurve(const ui.Offset(40.4, 128.2)), jitter: 0.2)],
    );
    expect(_crisp(a), isTrue);
    final sizes = _componentSizes(a);
    // 離して置いたペン先は、どれも同じ形（同じ画素の数）。
    expect(sizes.length, greaterThan(8));
    expect(sizes.toSet(), hasLength(1), reason: '$sizes');
  });

  test('scattered pixel dots are each the grid-locked dot shape', () {
    final a = _draw(_pixelBrush(3, scatter: 1, spacing: 9), [
      _curve(_sCurve(const ui.Offset(40.4, 128.2)), jitter: 0.2),
    ]);
    expect(_crisp(a), isTrue);
    final sizes = _componentSizes(a);
    // 重ならないドットは十字（5画素）。重なっても十字の数の倍数を超えない。
    expect(sizes.where((n) => n == 5).length, greaterThan(sizes.length ~/ 2));
    for (final n in sizes) {
      expect(n, lessThanOrEqualTo(5 * 3), reason: '$sizes');
    }
  });

  test('a calligraphy pixel nib is one fixed pixel shape', () {
    // 平たいペン先は、角度と太さごとに決まった画素の形：ペンが画素の
    // どこに置かれても同じ形（以前は小数の位置の楕円で形が変わった）。
    for (final size in [5.0, 9.0, 14.0]) {
      List<String>? first;
      for (final offset in [0.05, 0.3, 0.5, 0.7, 0.95]) {
        final a = _draw(_pixelBrush(size, calligraphy: 30), [
          [StrokePoint(x: 100 + offset, y: 100 + offset * 0.6)],
        ]);
        expect(_crisp(a), isTrue);
        final xs = [
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0) i % _size,
        ];
        final ys = [
          for (var i = 0; i < a.length; i++)
            if (a[i] > 0) i ~/ _size,
        ];
        final left = xs.reduce(math.min), top = ys.reduce(math.min);
        final shape = [
          for (var y = top; y <= ys.reduce(math.max); y++)
            [
              for (var x = left; x <= xs.reduce(math.max); x++)
                _ink(a, x, y) ? '#' : '.',
            ].join(),
        ];
        first ??= shape;
        expect(shape, first, reason: 'size $size at +$offset');
      }
    }
  });

  test('a calligraphy pixel nib sweeps a crisp band', () {
    // 平たいペン先を格子に写した形を、たどった画素ごとに置く。まっすぐな
    // 線では、どの列も同じ数の画素が1つながり。
    for (final degrees in [0, 20, 60]) {
      final from = const ui.Offset(30.4, 220.3);
      final to = from + ui.Offset.fromDirection(-degrees * math.pi / 180, 180);
      final a = _draw(_pixelBrush(9, calligraphy: 45), [
        _line(from, to, spacing: 1.5, seed: degrees),
      ]);
      expect(_crisp(a), isTrue);
      expect(_components(a), 1);
      final counts = _crossSections(a, from, to, 12);
      expect(
        counts.reduce(math.max) - counts.reduce(math.min),
        lessThanOrEqualTo(1),
        reason: '$degrees°: $counts',
      );
    }
  });

  test('brushes off the pixel grid draw exactly as before', () {
    // ピクセルモードでないブラシと、格子に置かないピクセルモードのブラシ
    // （六角形のペン先）の線は、ピクセルモードの線を足す前と1ビットも
    // 変わらない。
    // 値はその前のエンジンで描いたタイルのFNV-1a（どの線も四則演算と平方根
    // だけで決まり、端末によって変わらない）。
    Brush brush(
      double size, {
      int opacity = 100,
      int spacing = 1,
      bool pixelMode = false,
      bool fade = false,
      bool pressure = false,
      bool outline = false,
      BrushTipShape tip = BrushTipShape.round,
    }) => Brush(
      id: 'b',
      name: 'b',
      size: size,
      opacity: opacity,
      spacing: spacing,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: pixelMode,
      pressureOn: BrushPressureOnSettings.defaults.copyWith(
        size: PressureRangeSetting(enabled: pressure, weak: 30, strong: 100),
        opacity: PressureRangeSetting(enabled: pressure, weak: 40, strong: 100),
      ),
      fadeMode: fade ? FadeMode.custom : FadeMode.off,
      fadeIn: const FadeEndpointSettings(value: 0, rangePx: 40),
      fadeOut: const FadeEndpointSettings(value: 10, rangePx: 30),
      strokeDecay: false,
      outlineEnabled: outline,
      outlineWidth: 2,
      tipShape: tip,
    );

    String hashOf(Brush brush, {bool eraser = false}) {
      final tm = TileManager(canvasWidth: _size, canvasHeight: _size);
      if (eraser) {
        final tile = tm.getOrCreateTile(_layer, 0, 0);
        for (var i = 3; i < tile.length; i += 4) {
          tile[i] = 255;
        }
      }
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = brush
        ..currentColor = const ui.Color(0xFF3060C0)
        ..isEraser = eraser;
      final points = [
        for (var i = 0; i <= 60; i++)
          StrokePoint(
            x: 20.25 + i * 3.5,
            y: 128.5 + (i % 12 - 6) * (i % 12 - 6) * 1.25 - 20,
            pressure: (i % 20) / 20,
          ),
      ];
      tm.beginUndoRecording(_layer);
      engine.beginStroke(points.first, _layer);
      for (final p in points.skip(1)) {
        engine.continueStroke(p, _layer);
      }
      if (engine.needsFinalFadeReplay) {
        final drawn = tm.endUndoRecording();
        tm.applyTileSnapshot(_layer, drawn.before);
        tm.beginUndoRecording(_layer);
        engine.replayCurrentStrokeWithFinalFade();
      }
      engine.endStroke();
      tm.endUndoRecording();
      var hash = 0x811c9dc5;
      for (final b in tm.getTile(_layer, 0, 0)!) {
        hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
      }
      tm.dispose();
      return '0x${hash.toRadixString(16).padLeft(8, '0')}';
    }

    expect(hashOf(brush(12, pressure: true)), '0xda9879cb');
    expect(hashOf(brush(1.5, opacity: 70)), '0xc1b807c1');
    expect(hashOf(brush(8, fade: true)), '0x998d8f07');
    expect(hashOf(brush(10, opacity: 60), eraser: true), '0x9d8312de');
    expect(hashOf(brush(6, spacing: 14)), '0x01b56d89');
    expect(
      hashOf(brush(10, pixelMode: true, tip: BrushTipShape.hexagon)),
      '0xe5cce524',
    );
  });
}
