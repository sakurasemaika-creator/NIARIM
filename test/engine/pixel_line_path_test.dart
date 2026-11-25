import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/pixel_line_path.dart';

/// ピクセルモードの線の部品（たどり方・ランの整え・楕円・形）を確かめる。
void main() {
  List<PixelPoint> walk(
    List<Offset> points, {
    double hysteresis = kPixelLineHysteresis,
    double reverse = kPixelLineReverseHysteresis,
  }) {
    final walker = PixelLineWalker(
      points.first,
      hysteresis: hysteresis,
      reverseHysteresis: reverse,
    );
    final cells = <PixelPoint>[(x: walker.x, y: walker.y)];
    for (var i = 1; i < points.length; i++) {
      walker.walk(
        points[i - 1],
        points[i],
        (x, y, _) => cells.add((x: x, y: y)),
      );
    }
    return cells;
  }

  test('stepping back the way the line came needs a wider margin', () {
    // 行の境目の上を±0.5pxで震えても、1度下の行へ移ったら戻らない。
    final rng = math.Random(4);
    final points = [
      for (var x = 10.0; x < 200; x += 0.1)
        Offset(x, 50.0 + (rng.nextDouble() * 2 - 1) * 0.5),
    ];
    final rows = walk(points).map((c) => c.y).toList();
    var changes = 0;
    for (var i = 1; i < rows.length; i++) {
      if (rows[i] != rows[i - 1]) changes++;
    }
    expect(changes, lessThanOrEqualTo(1));
    // 遊びが同じだと、何度も行き来する。
    final same = walk(
      points,
      reverse: kPixelLineHysteresis,
    ).map((c) => c.y).toList();
    var zigzag = 0;
    for (var i = 1; i < same.length; i++) {
      if (same[i] != same[i - 1]) zigzag++;
    }
    expect(zigzag, greaterThan(20));
    // はっきり戻る動き（0.65pxを越える）には従う。
    final back = walk([
      const Offset(10.5, 10.5),
      const Offset(20.5, 10.5),
      const Offset(20.5, 11.5),
      const Offset(30.5, 11.5),
      const Offset(30.5, 10.2),
    ]);
    expect(back.last, (x: 30, y: 10));
  });

  test('the run regularizer evens out a 3-1-3 run and never makes an L', () {
    // 横に3・1・3と並ぶ線（傾きが急に変わって見える）を、2つめの段を
    // ずらして並べ直す。
    final steps = <(int, int)>[
      for (final run in [4, 4, 3, 1, 3, 4, 4, 3, 1, 4, 4, 3, 4]) ...[
        for (var i = 0; i < run; i++) (1, 0),
        (1, 1),
      ],
    ];
    var p = (x: 0, y: 0);
    final regularizer = PixelRunRegularizer<int>();
    regularizer.add(p.x, p.y, 0);
    final input = [p];
    for (final (dx, dy) in steps) {
      p = (x: p.x + dx, y: p.y + dy);
      input.add(p);
      regularizer.add(p.x, p.y, 0);
    }
    final chain = regularizer.finish(const []);
    final out = [for (var i = 0; i < chain.length; i++) chain[i]];
    expect(out.first, input.first);
    expect(out.last, input.last);
    expect(out.length, input.length);
    final runs = <int>[];
    var run = 1;
    for (var i = 1; i < out.length; i++) {
      final dx = out[i].x - out[i - 1].x, dy = out[i].y - out[i - 1].y;
      // つながったまま、L字の角も後戻りも無い。
      expect(dx, 1);
      expect(dy, anyOf(0, 1));
      if (dy == 0) {
        run++;
      } else {
        runs.add(run);
        run = 1;
      }
    }
    for (var i = 1; i + 1 < runs.length; i++) {
      expect(
        runs[i] > math.min(runs[i - 1], runs[i + 1]) - 2 &&
            runs[i] < math.max(runs[i - 1], runs[i + 1]) + 2,
        isTrue,
        reason: '$runs',
      );
    }
    // ずらした点は元の線から1画素以内。
    for (var i = 0; i < out.length; i++) {
      expect((out[i].y - input[i].y).abs(), lessThanOrEqualTo(1));
    }
  });

  test('the regularizer leaves frozen points and gives the same line '
      'however the points arrive', () {
    final rng = math.Random(8);
    final points = <PixelPoint>[(x: 0, y: 0)];
    for (var i = 0; i < 300; i++) {
      final last = points.last;
      points.add((x: last.x + 1, y: last.y + (rng.nextDouble() < 0.3 ? 1 : 0)));
    }
    // 1点ずつ足しながら、確定した点が後で変わらないこと。
    final regularizer = PixelRunRegularizer<int>();
    final frozen = <int, PixelPoint>{};
    for (final p in points) {
      regularizer.add(p.x, p.y, 0);
      final shown = regularizer.resolve(const []);
      for (var i = 0; i < regularizer.frozen; i++) {
        frozen.putIfAbsent(i, () => shown[i]);
        expect(shown[i], frozen[i], reason: 'point $i');
      }
    }
    final finished = regularizer.finish(const []);
    for (final entry in frozen.entries) {
      expect(finished[entry.key], entry.value);
    }
    // 途中の点を足してから終えても、まとめて終えても同じ。
    final other = PixelRunRegularizer<int>();
    for (final p in points.take(200)) {
      other.add(p.x, p.y, 0);
    }
    final rest = [for (final p in points.skip(200)) (x: p.x, y: p.y, data: 0)];
    final shown = other.resolve(rest);
    final done = other.finish(rest);
    expect(done.length, finished.length);
    for (var i = 0; i < done.length; i++) {
      expect(done[i], finished[i]);
      expect(shown[i], finished[i]);
    }
  });

  test('pixel ellipses are closed, thin, symmetric and fill their box', () {
    final rng = math.Random(2);
    for (var k = 0; k < 60; k++) {
      final x0 = rng.nextInt(20), y0 = rng.nextInt(20);
      final x1 = x0 + rng.nextInt(120), y1 = y0 + rng.nextInt(80);
      final ring = pixelEllipse(x0, y0, x1, y1);
      final set = {for (final p in ring) (p.x, p.y)};
      final reason = '($x0,$y0)-($x1,$y1)';
      expect(set.length, ring.length, reason: '$reason repeats a pixel');
      // 輪：隣の点と縦横斜めにつながり、最後の点は最初の点の隣（幅か高さが
      // 4画素以下の楕円は、端の1画素の幅の所を行って戻る）。
      for (var i = 0; i < ring.length; i++) {
        if (x1 - x0 <= 4 || y1 - y0 <= 4) break;
        final a = ring[i], b = ring[(i + 1) % ring.length];
        expect(
          (a.x - b.x).abs() <= 1 && (a.y - b.y).abs() <= 1,
          isTrue,
          reason: '$reason at $i',
        );
      }
      // 四角いっぱいに描き、上下・左右に対称。
      expect(set.map((c) => c.$1).reduce(math.min), x0, reason: reason);
      expect(set.map((c) => c.$1).reduce(math.max), x1, reason: reason);
      expect(set.map((c) => c.$2).reduce(math.min), y0, reason: reason);
      expect(set.map((c) => c.$2).reduce(math.max), y1, reason: reason);
      for (final (x, y) in set) {
        expect(set.contains((x0 + x1 - x, y)), isTrue, reason: reason);
        expect(set.contains((x, y0 + y1 - y)), isTrue, reason: reason);
      }
    }
  });

  test('a thick pixel line band has the same thickness at every angle', () {
    for (var d = 2; d <= 8; d++) {
      for (var degrees = 0; degrees <= 90; degrees += 5) {
        final direction = Offset.fromDirection(-degrees * math.pi / 180, 1);
        final from = const Offset(40.3, 160.6);
        final to = from + direction * 120;
        final tracer = PixelLineTracer<int>(
          from,
          0,
          corners: d.isEven,
          hysteresis: 0,
          reverseHysteresis: 0,
          window: 0,
        )..walk(from, to, (_) => 0);
        final chain = tracer.finish();
        final pixels = <(int, int)>{
          for (var k = 0; k < chain.length; k++)
            for (final p in pixelLineMask(
              chain,
              k,
              d,
              corners: d.isEven,
            ).pixels)
              (p.x, p.y),
        };
        var area = 0;
        for (final (x, y) in pixels) {
          final c = Offset(x + 0.5, y + 0.5) - from;
          final along = c.dx * direction.dx + c.dy * direction.dy;
          if (along >= 15 && along < 105) area++;
        }
        expect(
          area / 90 / d,
          inInclusiveRange(0.88, 1.12),
          reason: 'size $d at $degrees°',
        );
      }
    }
  });

  test('a dilated mask is an outline ring one pixel wide', () {
    final dot = PixelMask.dot((x: 10, y: 10), 4);
    final ring = dot.dilate(1);
    for (final p in ring.pixels) {
      if (dot.contains(p.x, p.y)) continue;
      expect(
        [
          (1, 0),
          (-1, 0),
          (0, 1),
          (0, -1),
        ].any((d) => dot.contains(p.x + d.$1, p.y + d.$2)),
        isTrue,
      );
    }
    // 塗りの縦横の隣はどれも、塗りか縁取り。
    for (final p in dot.pixels) {
      for (final d in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        expect(ring.contains(p.x + d.$1, p.y + d.$2), isTrue);
      }
    }
  });
}
