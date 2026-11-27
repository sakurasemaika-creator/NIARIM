import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/engine/pixel_art_lines.dart';
import 'package:niarim/models/pixel_color_mode.dart';

const _engine = PixelArtEngine();
const _ink = (42, 34, 51);

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

double Function(double, double) _ring(
  double cx,
  double cy,
  double r,
  double width,
) =>
    (x, y) =>
        width / 2 -
        (math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - r).abs();

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

/// [cx]・[cy]を中心に、半径[outer]の先と[inner]のくびれを交互に[points]組
/// 並べた星。
List<(double, double)> _star(
  double cx,
  double cy,
  int points,
  double outer,
  double inner,
) => [
  for (var k = 0; k < 2 * points; k++)
    (
      cx +
          (k.isEven ? outer : inner) *
              math.cos(-math.pi / 2 + k * math.pi / points),
      cy +
          (k.isEven ? outer : inner) *
              math.sin(-math.pi / 2 + k * math.pi / points),
    ),
];

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

  /// 線のドット（不透明で暗いもの）。
  Set<(int, int)> ink() => {
    for (var cy = 0; cy < rows; cy++)
      for (var cx = 0; cx < columns; cx++)
        if (_isInk(at(cx, cy))) (cx, cy),
  };

  static bool _isInk(int c) =>
      (c >>> 24) > 128 &&
      ((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255) < 3 * 160;
}

Uint8List _convert(
  _Picture p,
  int size, {
  PixelColorMode mode = PixelColorMode.count,
  int levels = 4,
  List<int> palette = const [],
  bool dither = true,
}) => _engine.convert(
  p.data,
  p.w,
  p.h,
  pixelSize: size,
  colorMode: mode,
  colorLevels: levels,
  paletteColors: palette,
  dither: dither,
);

/// 線のドットのうち、L字の角（縦横に隣り合う2つの線のドットが互いに斜めに
/// 隣り合う：取り除いてもつながったまま）と、線の横に付いた余分なドット
/// （隣の線のドットが3つ以上）。
List<(int, int)> _clumps(Set<(int, int)> cells) {
  final found = <(int, int)>[];
  for (final (x, y) in cells) {
    final around = [
      for (var dy = -1; dy <= 1; dy++)
        for (var dx = -1; dx <= 1; dx++)
          if ((dx != 0 || dy != 0) && cells.contains((x + dx, y + dy)))
            (dx, dy),
    ];
    if (around.length > 2) {
      found.add((x, y));
      continue;
    }
    if (around.length == 2) {
      final (ax, ay) = around[0];
      final (bx, by) = around[1];
      if ((ax - bx).abs() == 1 && (ay - by).abs() == 1) found.add((x, y));
    }
  }
  return found;
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

/// ドット絵フィルターの細い線：線ごとに1つの色（数珠つなぎのまだらに
/// ならない）、L字の角や横の余分なドットの無い線、元の太さが同じなら
/// どこも同じドット数。塗り・グラデーション・ディザの模様は変えない。
void main() {
  group('one colour per line', () {
    for (final size in [4, 8]) {
      for (final width in [2.0, 3.0, 6.0]) {
        if (width / size >= 1.5) continue;
        test('a ${width}px line on ${size}px dots: every dot of the line is '
            'the same colour, at every angle', () {
          for (final degrees in [0, 7, 20, 33, 45, 58, 71, 84, 90]) {
            final p = _Picture(160, 160, paper: (255, 255, 255));
            final a = degrees * math.pi / 180;
            final dx = math.cos(a) * 60, dy = math.sin(a) * 60;
            p.paint(_segment(80 - dx, 80 - dy, 80 + dx, 80 + dy, width));
            final dots = _Dots(_convert(p, size), 160, 160, size);
            final colours = {for (final (x, y) in dots.ink()) dots.at(x, y)};
            expect(colours, hasLength(1), reason: '$degrees°');
            // それ以外は紙の色だけ（線の横に薄い色のドットが残らない）。
            final others = <int>{
              for (var cy = 0; cy < dots.rows; cy++)
                for (var cx = 0; cx < dots.columns; cx++)
                  if (!dots.ink().contains((cx, cy))) dots.at(cx, cy),
            };
            expect(others, hasLength(1), reason: '$degrees°: paper');
          }
        });
      }
    }

    test('the line keeps its own colour, not a mix with the paper', () {
      final p = _Picture(192, 192, paper: (255, 255, 255));
      p.paint(_ring(96, 96, 70, 3));
      final dots = _Dots(
        _convert(p, 8, mode: PixelColorMode.none),
        192,
        192,
        8,
      );
      for (final (x, y) in dots.ink()) {
        final c = dots.at(x, y);
        expect(
          [(c >> 16) & 255, (c >> 8) & 255, c & 255],
          [_ink.$1, _ink.$2, _ink.$3],
        );
      }
    });
  });

  group('pixel-perfect lines', () {
    for (final size in [4, 6, 8]) {
      test('circles and slopes on ${size}px dots have no L-corners or side '
          'dots, and stay connected', () {
        for (final width in [2.0, 3.0, size * 0.8]) {
          final p = _Picture(256, 256, paper: (255, 255, 255));
          p.paint(_ring(128, 128, 90, width));
          var dots = _Dots(_convert(p, size), 256, 256, size);
          var cells = dots.ink();
          expect(_clumps(cells), isEmpty, reason: 'circle, ${width}px');
          expect(_groups(cells), 1, reason: 'circle, ${width}px');
          for (final degrees in [9, 26, 45, 63]) {
            final q = _Picture(256, 256, paper: (255, 255, 255));
            final a = degrees * math.pi / 180;
            final dx = math.cos(a) * 100, dy = math.sin(a) * 100;
            q.paint(_segment(128 - dx, 128 - dy, 128 + dx, 128 + dy, width));
            dots = _Dots(_convert(q, size), 256, 256, size);
            cells = dots.ink();
            expect(_clumps(cells), isEmpty, reason: '$degrees°, ${width}px');
            expect(_groups(cells), 1, reason: '$degrees°, ${width}px');
          }
        }
      });
    }

    test('on a transparent layer too: no L-corners, one colour, fully opaque '
        'or fully clear', () {
      final p = _Picture(256, 256);
      p.paint(_ring(128, 128, 90, 4));
      final out = _convert(p, 8);
      final cells = _Dots(out, 256, 256, 8).ink();
      expect(_clumps(cells), isEmpty);
      expect(_groups(cells), 1);
      expect({for (var i = 3; i < out.length; i += 4) out[i]}, {0, 255});
    });

    test('a T junction and an X crossing are kept, and the lines reach '
        'their ends', () {
      final p = _Picture(256, 256, paper: (255, 255, 255));
      p.paint(_segment(32, 64, 224, 64, 3));
      p.paint(_segment(128, 64, 128, 224, 3));
      p.paint(_segment(40, 120, 216, 210, 3));
      final cells = _Dots(_convert(p, 8), 256, 256, 8).ink();
      expect(_groups(cells), 1);
      // The junction of the T and the crossing are drawn.
      expect(cells, contains((16, 8)));
      expect(
        cells.where((c) => c.$1 == 16 && c.$2 >= 20 && c.$2 <= 22),
        isNotEmpty,
      );
      // The ends of the bar and the stem are within a dot of the source.
      expect(cells.map((c) => c.$1).reduce(math.min), inInclusiveRange(3, 4));
      expect(cells.map((c) => c.$1).reduce(math.max), inInclusiveRange(27, 28));
      final stem = cells.where((c) => c.$1 == 16).map((c) => c.$2);
      expect(stem.reduce(math.max), inInclusiveRange(27, 28));
    });

    test('the corner of a right angle is kept', () {
      final p = _Picture(192, 192, paper: (255, 255, 255));
      p.paint(_polyline([(36, 36), (156, 36), (156, 156)], 3));
      final cells = _Dots(_convert(p, 8), 192, 192, 8).ink();
      expect(cells, contains((19, 4)), reason: 'the corner dot');
      expect(_groups(cells), 1);
    });
  });

  group('uniform thickness', () {
    test('a line thinner than one and a half dots is one dot thick wherever '
        'it falls on the grid', () {
      for (final width in [3.0, 6.0, 10.0]) {
        for (var offset = 0.0; offset < 8; offset += 1.25) {
          final p = _Picture(192, 96, paper: (255, 255, 255));
          // A gentle slope: it crosses rows of dots at many sub-dot places.
          p.paint(_segment(12, 30 + offset, 180, 60 + offset, width));
          final dots = _Dots(_convert(p, 8), 192, 96, 8);
          final cells = dots.ink();
          for (var cx = 3; cx < 21; cx++) {
            expect(
              cells.where((c) => c.$1 == cx),
              hasLength(1),
              reason: '${width}px, offset $offset, column $cx',
            );
          }
        }
      }
    });

    test('a line between one and a half and two and a half dots is two dots '
        'thick wherever it falls on the grid', () {
      for (final width in [13.0, 15.0, 17.5, 19.0]) {
        for (var offset = 0.0; offset < 8; offset += 1.25) {
          final p = _Picture(192, 96, paper: (255, 255, 255));
          p.paint(_segment(12, 44 + offset, 180, 44 + offset, width));
          final cells = _Dots(_convert(p, 8), 192, 96, 8).ink();
          for (var cx = 4; cx < 20; cx++) {
            expect(
              cells.where((c) => c.$1 == cx),
              hasLength(2),
              reason: '${width}px, offset $offset, column $cx',
            );
          }
        }
      }
    });

    test('lines drawn with one pen are all the same number of dots, even '
        'right at the boundary between two thicknesses', () {
      // 6 px on 4 px dots: one and a half dots.
      final p = _Picture(320, 320, paper: (255, 255, 255));
      for (var k = 0; k < 6; k++) {
        p.paint(_segment(20, 30.0 + k * 48, 300, 12.0 + k * 52, 6));
      }
      final cells = _Dots(_convert(p, 4), 320, 320, 4).ink();
      // Each line's usual number of dots per column of dots.
      final usual = <int>[];
      for (var k = 0; k < 6; k++) {
        final counts = <int>[];
        for (var cx = 10; cx < 70; cx++) {
          final y0 = 30.0 + k * 48, y1 = 12.0 + k * 52;
          final y = y0 + (y1 - y0) * ((cx * 4 + 2 - 20) / 280);
          final row = (y / 4).floor();
          counts.add(
            cells.where((c) => c.$1 == cx && (c.$2 - row).abs() <= 3).length,
          );
        }
        counts.sort();
        usual.add(counts[counts.length ~/ 2]);
      }
      expect(usual.toSet(), hasLength(1), reason: '$usual');
    });
  });

  group('left as before', () {
    test('pictures without thin lines are not touched at all', () {
      Uint8List picture(
        int w,
        int h,
        (int, int, int, int) Function(int, int) at,
      ) {
        final data = Uint8List(w * h * 4);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final (r, g, b, a) = at(x, y);
            data.setAll((y * w + x) * 4, [
              r * a ~/ 255,
              g * a ~/ 255,
              b * a ~/ 255,
              a,
            ]);
          }
        }
        return data;
      }

      final cases = <String, Uint8List>{
        'grey ramp': picture(256, 32, (x, _) => (x, x, x, 255)),
        'sky to ground': picture(
          160,
          160,
          (x, y) => y < 100
              ? (40 + y, 90 + y, 230, 255)
              : (90 - (y - 100) ~/ 2, 160 - (y - 100), 70, 255),
        ),
        'discs on a ground': () {
          final p = _Picture(160, 160, paper: (120, 150, 245));
          p.paint(
            (x, y) => 50 - math.sqrt((x - 70) * (x - 70) + (y - 80) * (y - 80)),
            (255, 140, 0),
          );
          p.paint(
            (x, y) =>
                25 - math.sqrt((x - 120) * (x - 120) + (y - 40) * (y - 40)),
            (40, 30, 60),
          );
          return p.data;
        }(),
        'a soft disc on a transparent layer': () {
          final p = _Picture(96, 96);
          p.paint(
            (x, y) => 30 - math.sqrt((x - 48) * (x - 48) + (y - 48) * (y - 48)),
            (20, 30, 40),
          );
          return p.data;
        }(),
        'rectangles': picture(
          128,
          128,
          (x, y) => x < 64 == y < 64 ? (230, 30, 40, 255) : (20, 20, 30, 255),
        ),
        'a one-pixel checker (a dither pattern)': picture(
          96,
          96,
          (x, y) => (x + y).isEven ? (0, 0, 0, 255) : (255, 255, 255, 255),
        ),
        'a two-pixel checker': picture(
          96,
          96,
          (x, y) =>
              (x ~/ 2 + y ~/ 2).isEven ? (0, 0, 0, 255) : (255, 255, 255, 255),
        ),
        'an ordered dither of a ramp': picture(128, 64, (x, y) {
          const bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
          final on = x * 16 ~/ 128 > bayer[(y & 3) * 4 + (x & 3)];
          return on ? (255, 255, 255, 255) : (0, 0, 0, 255);
        }),
        'hatching closer than a dot': () {
          final p = _Picture(128, 128, paper: (255, 255, 255));
          for (var y = 2.0; y < 128; y += 4) {
            p.paint(_segment(-4, y, 132, y, 1.5));
          }
          return p.data;
        }(),
        'a thick stroke (three dots)': () {
          final p = _Picture(192, 96, paper: (255, 255, 255));
          p.paint(_segment(20, 48, 172, 48, 26));
          return p.data;
        }(),
      };
      for (final MapEntry(key: name, value: data) in cases.entries) {
        final w = switch (name) {
          'grey ramp' => 256,
          'a soft disc on a transparent layer' => 96,
          'a one-pixel checker (a dither pattern)' ||
          'a two-pixel checker' => 96,
          'an ordered dither of a ramp' || 'rectangles' => 128,
          'hatching closer than a dot' => 128,
          'a thick stroke (three dots)' => 192,
          _ => 160,
        };
        final h = data.length ~/ 4 ~/ w;
        for (final size in [4.0, 8.0, 9.6]) {
          final xs = PixelArtEngine.cellEdges(w, size);
          final ys = PixelArtEngine.cellEdges(h, size);
          expect(
            PixelArtLines.find(data, w, h, xs, ys, size),
            isNull,
            reason: '$name, ${size}px dots',
          );
        }
      }
    });

    test('filled shapes with points (stars, a sparkle, an arrow, a thin '
        'line running into a fill of its own colour) are not redrawn', () {
      final shapes = <String, List<double Function(double, double)>>{
        'a five-point star': [_polygon(_star(64, 66, 5, 56, 22))],
        'a four-point sparkle': [_polygon(_star(64, 64, 4, 58, 10))],
        'an arrow': [
          _polygon([
            (8, 64),
            (40, 32),
            (40, 56),
            (88, 56),
            (88, 32),
            (120, 64),
            (88, 96),
            (88, 72),
            (40, 72),
            (40, 96),
          ]),
        ],
        'a line into a disc': [
          (x, y) => 30 - math.sqrt((x - 84) * (x - 84) + (y - 84) * (y - 84)),
          _segment(10, 10, 70, 70, 3),
        ],
      };
      for (final MapEntry(key: name, value: parts) in shapes.entries) {
        for (final transparent in [false, true]) {
          final p = transparent
              ? _Picture(128, 128)
              : _Picture(128, 128, paper: (255, 255, 255));
          for (final part in parts) {
            p.paint(part, (34, 34, 34));
          }
          final xs = PixelArtEngine.cellEdges(128, 8);
          expect(
            PixelArtLines.find(p.data, 128, 128, xs, xs, 8),
            isNull,
            reason: '$name${transparent ? ', transparent layer' : ''}',
          );
        }
      }
    });

    test('stamps keep their pixel art without redrawn lines', () {
      final source = File(
        'lib/engine/procedural_texture.dart',
      ).readAsStringSync();
      expect(source, contains('redrawLines: false'));
      final p = _Picture(128, 128);
      p.paint(_ring(64, 64, 40, 3));
      final engine = FilterEngine();
      expect(
        engine.applyPixelate(
          p.data,
          128,
          128,
          dither: false,
          redrawLines: false,
        ),
        isNot(
          orderedEquals(engine.applyPixelate(p.data, 128, 128, dither: false)),
        ),
        reason: 'the ring is a line the filter redraws, but a stamp does not',
      );
    });

    test('the brush pixel mode only recolours: a thin line keeps every '
        'pixel of its shape', () {
      final p = _Picture(64, 64);
      p.paint(_ring(32, 32, 20, 2));
      final out = _engine.convert(
        p.data,
        64,
        64,
        pixelSize: 1,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [0xFF000000, 0xFFFFFFFF],
        squareBlocks: false,
      );
      for (var i = 3; i < out.length; i += 4) {
        expect(out[i], p.data[i]);
      }
    });

    test('one-pixel dots are not redrawn', () {
      final p = _Picture(64, 64, paper: (255, 255, 255));
      p.paint(_ring(32, 32, 20, 2));
      final xs = PixelArtEngine.cellEdges(64, 1);
      expect(PixelArtLines.find(p.data, 64, 64, xs, xs, 1), isNull);
    });
  });

  group('animation', () {
    test('a drawing moving by a fraction of a dot each frame keeps its line '
        'colour and thickness, and no dot flickers back and forth', () {
      List<Set<(int, int)>> frames(
        double Function(int) dx,
        double Function(int) dy,
      ) {
        final result = <Set<(int, int)>>[];
        final colours = <int>{};
        for (var f = 0; f < 10; f++) {
          final p = _Picture(256, 256, paper: (255, 255, 255));
          final ox = dx(f), oy = dy(f);
          p.paint(_ring(110 + ox, 120 + oy, 70, 4));
          p.paint(_segment(30 + ox, 220 + oy, 230 + ox, 190 + oy, 4));
          p.paint(
            _polyline([
              (60 + ox, 40 + oy),
              (130 + ox, 20 + oy),
              (200 + ox, 60 + oy),
            ], 4),
          );
          final dots = _Dots(_convert(p, 8), 256, 256, 8);
          final cells = dots.ink();
          for (final (x, y) in cells) {
            colours.add(dots.at(x, y));
          }
          result.add(cells);
        }
        expect(colours, hasLength(1), reason: 'the line colour');
        return result;
      }

      for (final g in [
        frames((f) => f * 1.0, (f) => f * 0.5),
        frames((f) => f * 0.3, (f) => -f * 0.7),
      ]) {
        final counts = [for (final cells in g) cells.length];
        final mean = counts.reduce((a, b) => a + b) / counts.length;
        for (final n in counts) {
          expect(
            (n - mean).abs(),
            lessThanOrEqualTo(mean * 0.04),
            reason: '$counts',
          );
        }
        var toggles = 0;
        for (var f = 2; f < g.length; f++) {
          final back = g[f].difference(g[f - 1]).intersection(g[f - 2]);
          final forth = g[f - 1].difference(g[f]).difference(g[f - 2]);
          toggles += back.length + forth.length;
        }
        expect(toggles, lessThanOrEqualTo(4), reason: 'dots flicking back');
      }
    });

    test('a straight line moving across the grid stays one dot thick in '
        'every frame', () {
      for (var f = 0; f < 16; f++) {
        final p = _Picture(192, 96, paper: (255, 255, 255));
        p.paint(_segment(12, 30 + f * 0.5, 180, 50 + f * 0.5, 4));
        final cells = _Dots(_convert(p, 8), 192, 96, 8).ink();
        for (var cx = 3; cx < 21; cx++) {
          expect(
            cells.where((c) => c.$1 == cx),
            hasLength(1),
            reason: 'frame $f, column $cx',
          );
        }
      }
    });
  });
}
