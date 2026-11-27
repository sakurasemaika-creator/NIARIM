import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

const _engine = PixelArtEngine();
const _ink = (42, 34, 51);
const _skin = (250, 222, 204);
const _shirt = (96, 128, 204);

/// 乗算済みRGBAの絵。[paper]があれば不透明な紙、無ければ透明なレイヤー。
class _Picture {
  _Picture(this.w, this.h, {(int, int, int)? paper})
    : data = Uint8List(w * h * 4) {
    if (paper == null) return;
    for (var p = 0; p < w * h; p++) {
      data
        ..[p * 4] = paper.$1
        ..[p * 4 + 1] = paper.$2
        ..[p * 4 + 2] = paper.$3
        ..[p * 4 + 3] = 255;
    }
  }

  final int w, h;
  final Uint8List data;

  /// [inside]（画素の中心が形の縁から内側へ何画素か）の形を、縁を
  /// アンチエイリアスして[rgb]で重ねる。
  void paint(
    double Function(double x, double y) inside, [
    (int, int, int) rgb = _ink,
  ]) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final cover = (inside(x + 0.5, y + 0.5) + 0.5).clamp(0.0, 1.0);
        if (cover == 0) continue;
        final i = (y * w + x) * 4;
        final keep = 1 - cover;
        data[i] = (rgb.$1 * cover + data[i] * keep).round();
        data[i + 1] = (rgb.$2 * cover + data[i + 1] * keep).round();
        data[i + 2] = (rgb.$3 * cover + data[i + 2] * keep).round();
        data[i + 3] = (255 * cover + data[i + 3] * keep).round();
      }
    }
  }
}

double Function(double, double) _segment(
  double x0,
  double y0,
  double x1,
  double y1,
  double width,
) => (x, y) {
  final dx = x1 - x0, dy = y1 - y0;
  final t = (((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)).clamp(
    0.0,
    1.0,
  );
  final px = x0 + dx * t, py = y0 + dy * t;
  return width / 2 - math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
};

double Function(double, double) _polyline(
  List<(double, double)> points,
  double width,
) => (x, y) {
  var best = double.negativeInfinity;
  for (var i = 0; i + 1 < points.length; i++) {
    final (ax, ay) = points[i];
    final (bx, by) = points[i + 1];
    best = math.max(best, _segment(ax, ay, bx, by, width)(x, y));
  }
  return best;
};

double Function(double, double) _ring(
  double cx,
  double cy,
  double r,
  double width,
) =>
    (x, y) =>
        width / 2 -
        (math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - r).abs();

double Function(double, double) _disc(double cx, double cy, double r) =>
    (x, y) => r - math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));

/// 塗った多角形（縁からの距離。内側が正）。
double Function(double, double) _polygon(List<(double, double)> points) =>
    (x, y) {
      var inside = false;
      var nearest = double.infinity;
      for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
        final (xi, yi) = points[i];
        final (xj, yj) = points[j];
        if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
          inside = !inside;
        }
        final dx = xj - xi, dy = yj - yi;
        final t = (((x - xi) * dx + (y - yi) * dy) / (dx * dx + dy * dy)).clamp(
          0.0,
          1.0,
        );
        final px = xi + dx * t, py = yi + dy * t;
        nearest = math.min(
          nearest,
          math.sqrt((x - px) * (x - px) + (y - py) * (y - py)),
        );
      }
      return inside ? nearest : -nearest;
    };

/// 変換の結果をドットごとに読む（ドットの真ん中の画素、0xAARRGGBB）。
class _Dots {
  _Dots(Uint8List out, int w, int h, this.size)
    : columns = w ~/ size,
      rows = h ~/ size,
      _out = out,
      _w = w;

  final int size, columns, rows, _w;
  final Uint8List _out;

  int at(int cx, int cy) {
    final i = ((cy * size + size ~/ 2) * _w + cx * size + size ~/ 2) * 4;
    return _out[i + 3] << 24 | _out[i] << 16 | _out[i + 1] << 8 | _out[i + 2];
  }

  /// 線のドット（不透明で、線の色ほど暗いもの。服の青は入らない）。
  Set<(int, int)> ink() => {
    for (var cy = 0; cy < rows; cy++)
      for (var cx = 0; cx < columns; cx++)
        if (_isInk(at(cx, cy))) (cx, cy),
  };

  /// ドットの真ん中の画素の位置。
  (double, double) centre((int, int) cell) =>
      ((cell.$1 + 0.5) * size, (cell.$2 + 0.5) * size);

  static bool _isInk(int c) =>
      (c >>> 24) > 128 &&
      ((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255) < 3 * 90;
}

/// 8方向につながったまとまりの数。
int _groups(Set<(int, int)> cells) {
  final seen = <(int, int)>{};
  var groups = 0;
  for (final start in cells) {
    if (!seen.add(start)) continue;
    groups++;
    final stack = [start];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final n = (x + dx, y + dy);
          if (cells.contains(n) && seen.add(n)) stack.add(n);
        }
      }
    }
  }
  return groups;
}

/// 線のドットだけでできた2×2の塊（左上のドット）。
List<(int, int)> _blocks(Set<(int, int)> cells) => [
  for (final (x, y) in cells)
    if (cells.contains((x + 1, y)) &&
        cells.contains((x, y + 1)) &&
        cells.contains((x + 1, y + 1)))
      (x, y),
];

/// [from]のドットから、線のドットを通らずに縦横へたどれるドットに、[outside]
/// を満たすものがあるか（線のドットの輪が閉じていなければある）。
bool _leaks(
  Set<(int, int)> cells,
  (int, int) from,
  int columns,
  int rows,
  bool Function((int, int)) outside,
) {
  final seen = {from};
  final stack = [from];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    if (outside(c)) return true;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final n = (c.$1 + dx, c.$2 + dy);
      if (n.$1 < 0 || n.$2 < 0 || n.$1 >= columns || n.$2 >= rows) continue;
      if (cells.contains(n) || !seen.add(n)) continue;
      stack.add(n);
    }
  }
  return false;
}

double _distance((double, double) a, (double, double) b) =>
    math.sqrt((a.$1 - b.$1) * (a.$1 - b.$1) + (a.$2 - b.$2) * (a.$2 - b.$2));

Uint8List _convert(_Picture p, int size) => _engine.convert(
  p.data,
  p.w,
  p.h,
  pixelSize: size,
  colorMode: PixelColorMode.none,
);

/// 顔（肌色の円）を細い線で囲み、その下の端（あご）は服の塗りの上を通る絵。
/// 目は小さな塗った円、口は短い線。
const _side = 480.0;
const _face = (240.0, 220.0), _faceRadius = 110.0;
const _eyes = [(200.0, 205.0), (280.0, 205.0)];
const _mouth = ((215.0, 275.0), (265.0, 275.0));
const _shirtTop = [
  (90.0, 480.0),
  (120.0, 350.0),
  (200.0, 318.0),
  (280.0, 318.0),
  (360.0, 350.0),
  (390.0, 480.0),
];

_Picture _character({required bool paper}) {
  final p = _Picture(
    _side.toInt(),
    _side.toInt(),
    paper: paper ? (255, 255, 255) : null,
  );
  p.paint(_polygon(_shirtTop), _shirt);
  p.paint(_polyline(_shirtTop, 3));
  p.paint(_disc(_face.$1, _face.$2, _faceRadius), _skin);
  p.paint(_ring(_face.$1, _face.$2, _faceRadius, 3.5));
  for (final (x, y) in _eyes) {
    p.paint(_disc(x, y, 9));
  }
  final ((mx0, my0), (mx1, my1)) = _mouth;
  p.paint(_segment(mx0, my0, mx1, my1, 4));
  return p;
}

/// 顔の線と服の線が出会う所（肩）。
final _shoulders = [
  for (final sign in [-1.0, 1.0])
    () {
      // 服の上の斜めの辺（(120, 350)〜(200, 318)と鏡映し）と顔の円の交点。
      final (ax, ay) = sign < 0 ? (120.0, 350.0) : (360.0, 350.0);
      final (bx, by) = sign < 0 ? (200.0, 318.0) : (280.0, 318.0);
      var best = (0.0, 0.0), error = double.infinity;
      for (var t = 0.0; t <= 1.0; t += 0.001) {
        final x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
        final e = (_distance((x, y), _face) - _faceRadius).abs();
        if (e < error) {
          error = e;
          best = (x, y);
        }
      }
      return best;
    }(),
];

void main() {
  for (final paper in [true, false]) {
    final layer = paper ? 'on white paper' : 'on a transparent layer';
    for (final dots in [48, 24]) {
      final size = _side ~/ dots;
      group('a character $layer, $dots dots across', () {
        final out = _convert(_character(paper: paper), size);
        final grid = _Dots(out, _side.toInt(), _side.toInt(), size);
        final ink = grid.ink();
        // 顔の線のドット（円から1ドット半以内）。
        final ring = {
          for (final c in ink)
            if ((_distance(grid.centre(c), _face) - _faceRadius).abs() <=
                1.5 * size)
              c,
        };

        test('the face outline is closed all the way round, also between '
            'the skin and the shirt', () {
          expect(_groups(ring), 1);
          final centre = ((_face.$1 / size).floor(), (_face.$2 / size).floor());
          expect(
            _leaks(
              ink,
              centre,
              grid.columns,
              grid.rows,
              (c) => _distance(grid.centre(c), _face) > _faceRadius + 2 * size,
            ),
            isFalse,
          );
          // あご（服の上を通る所）にも線のドットがある。
          final chin = (_face.$1, _face.$2 + _faceRadius);
          expect(
            ring.any((c) => _distance(grid.centre(c), chin) <= size),
            isTrue,
          );
        });

        test('the outline is one dot thick: no 2×2 blocks of line dots '
            'except where the face meets the shirt', () {
          final lumps = [
            for (final b in _blocks(ink))
              if (_shoulders.every(
                    (s) => _distance(grid.centre(b), s) > 2.5 * size,
                  ) &&
                  _eyes.every((e) => _distance(grid.centre(b), e) > 2 * size))
                b,
          ];
          expect(lumps, isEmpty);
        });

        test('the eyes and the mouth are kept, apart from the outline', () {
          for (final e in _eyes) {
            final near = ink.where((c) => _distance(grid.centre(c), e) <= size);
            expect(near, isNotEmpty, reason: 'eye at $e');
            expect(near.any(ring.contains), isFalse, reason: 'eye at $e');
          }
          final ((mx0, my0), (mx1, my1)) = _mouth;
          final mouth = ((mx0 + mx1) / 2, (my0 + my1) / 2);
          expect(
            ink.any((c) => _distance(grid.centre(c), mouth) <= size),
            isTrue,
          );
        });
      });
    }
  }

  group('a circle outline', () {
    for (final paper in [true, false]) {
      for (final size in [4, 6, 8, 10, 12, 16]) {
        test(
          'on ${size}px dots ${paper ? 'on paper' : 'on a transparent '
                    'layer'} is a closed ring one dot thick',
          () {
            const side = 320;
            final p = _Picture(
              side,
              side,
              paper: paper ? (255, 255, 255) : null,
            )..paint(_ring(160, 160, 110, 3));
            final grid = _Dots(_convert(p, size), side, side, size);
            final ink = grid.ink();
            expect(_groups(ink), 1);
            // どのドットも、隣の線のドットが前後の2つだけ。
            for (final (x, y) in ink) {
              var around = 0;
              for (var dy = -1; dy <= 1; dy++) {
                for (var dx = -1; dx <= 1; dx++) {
                  if ((dx != 0 || dy != 0) && ink.contains((x + dx, y + dy))) {
                    around++;
                  }
                }
              }
              expect(around, 2, reason: 'dot ($x, $y)');
            }
            expect(
              _leaks(
                ink,
                (160 ~/ size, 160 ~/ size),
                grid.columns,
                grid.rows,
                (c) => c.$1 == 0 || c.$2 == 0,
              ),
              isFalse,
            );
          },
        );
      }
    }
  });
}
