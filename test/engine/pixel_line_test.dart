import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/pixel_line_path.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

/// ピクセルモードの線が、ドットがダマにならないなめらかなドット絵の線に
/// なることを確かめる：1画素の線は1段に1画素でL字の角が無い、太い線は
/// 太さがそろう、まばらな点でも途切れない、点の細かさや描き直しで画素が
/// 変わらない。ピクセルモードでないブラシの線は前と1ビットも変わらない。
const _layer = 'L';
const _size = TileManager.tileSize;

Brush _pixelBrush(
  double size, {
  bool pressureSize = false,
  bool fade = false,
  int spacing = 1,
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
);

/// [points]をペンの線として描き、描かれた画素（不透明度）を返す。
/// [replay]は、キャンバスと同じくペンを離した後に線を描き直す。
Uint8List _draw(
  Brush brush,
  List<List<StrokePoint>> strokes, {
  bool eraser = false,
  bool replay = false,
  void Function(Uint8List alpha)? afterEachPoint,
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

  test('every dot of a pixel brush is the same grid-locked shape', () {
    // ドット絵のブラシと同じ形：1は1画素、2は2×2、3は十字、4以上は円。
    const expected = {1: 1, 2: 4, 3: 5, 4: 12, 5: 21, 6: 32};
    for (final entry in expected.entries) {
      final diameter = entry.key;
      List<String>? first;
      for (final offset in [0.02, 0.27, 0.5, 0.73, 0.98]) {
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          [StrokePoint(x: 100 + offset, y: 60 + (1 - offset))],
        ]);
        expect(_inked(a), entry.value, reason: 'size $diameter at +$offset');
        final shape = [
          for (var y = 50; y < 70; y++)
            [for (var x = 90; x < 110; x++) _ink(a, x, y) ? '#' : '.'].join(),
        ];
        first ??= shape;
        expect(shape, first, reason: 'size $diameter at +$offset');
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

  test('thick pixel lines keep an even thickness at every angle', () {
    final rng = math.Random(9);
    for (var diameter = 2; diameter <= 6; diameter++) {
      for (var degrees = 0; degrees <= 90; degrees += 3) {
        final from = ui.Offset(40 + rng.nextDouble(), 210 + rng.nextDouble());
        final to =
            from + ui.Offset.fromDirection(-degrees * math.pi / 180, 150);
        final a = _draw(_pixelBrush(diameter.toDouble()), [
          _line(from, to, seed: degrees),
        ]);
        final counts = _crossSections(a, from, to, diameter + 2);
        final reason = 'size $diameter at $degrees°: $counts';
        expect(_components(a), 1, reason: reason);
        // 斜めの段では、前の段と次の段のドットが1画素ずつ重なることがある。
        expect(
          counts.reduce(math.max) - counts.reduce(math.min),
          lessThanOrEqualTo(1),
          reason: reason,
        );
        if (degrees == 0 || degrees == 90) {
          expect(counts.toSet(), {diameter}, reason: reason);
        }
        if (degrees == 45) expect(counts.toSet().length, 1, reason: reason);
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
      // 描いている途中の画素は、描き終えた線の画素の一部（後で消える画素を
      // 先に描かない）。
      for (final frame in live) {
        for (var i = 0; i < frame.length; i++) {
          if (frame[i] > 0) expect(drawn[i], greaterThan(0));
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

    final ellipse = TileManager(canvasWidth: _size, canvasHeight: _size);
    DrawingEngine(tileManager: ellipse)
      ..currentBrush = _pixelBrush(1)
      ..currentColor = const ui.Color(0xFF000000)
      ..commitShapePath(
        [
          for (var i = 0; i < 48; i++)
            StrokePoint(
              x: 128.5 + 80.2 * math.cos(i / 48 * 2 * math.pi),
              y: 128.3 + 60.7 * math.sin(i / 48 * 2 * math.pi),
            ),
        ],
        _layer,
        closeLoop: true,
      );
    final a = _alpha(ellipse);
    expect(_components(a), 1);
    expect(_clumps(a), isEmpty);
    ellipse.dispose();
  });

  test('brushes off the pixel grid draw exactly as before', () {
    // ピクセルモードでないブラシと、格子に置かないピクセルモードのブラシ
    // （縁取り）の線は、ピクセルモードの線を足す前と1ビットも変わらない。
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
    expect(hashOf(brush(10, pixelMode: true, outline: true)), '0xa46ef648');
  });
}
