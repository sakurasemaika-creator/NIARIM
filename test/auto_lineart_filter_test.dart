import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';

Uint8List _canvas(int w, int h) => Uint8List(w * h * 4);

void _fillOpaque(Uint8List b, int shade) {
  for (var i = 0; i < b.length; i += 4) {
    b[i] = shade;
    b[i + 1] = shade;
    b[i + 2] = shade;
    b[i + 3] = 255;
  }
}

void _dot(
  Uint8List b,
  int w,
  int h,
  int cx,
  int cy,
  int radius, {
  int shade = 20,
}) {
  for (var y = cy - radius; y <= cy + radius; y++) {
    for (var x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || x >= w || y < 0 || y >= h) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy > radius * radius) continue;
      final i = (y * w + x) * 4;
      b[i] = shade;
      b[i + 1] = shade;
      b[i + 2] = shade;
      b[i + 3] = 255;
    }
  }
}

void _line(
  Uint8List b,
  int w,
  int h,
  int x0,
  int y0,
  int x1,
  int y1,
  int radius, {
  int shade = 20,
}) {
  final dx = (x1 - x0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final dy = -(y1 - y0).abs();
  final sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;
  var x = x0;
  var y = y0;
  while (true) {
    _dot(b, w, h, x, y, radius, shade: shade);
    if (x == x1 && y == y1) break;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
}

int _alpha(Uint8List b, int w, int x, int y) => b[(y * w + x) * 4 + 3];

int _opaqueCount(Uint8List b) {
  var count = 0;
  for (var i = 3; i < b.length; i += 4) {
    if (b[i] > 0) count++;
  }
  return count;
}

void main() {
  group('AutoLineartEngine', () {
    test('extracts one center path from a thick raster rough', () {
      const w = 96, h = 64;
      final src = _canvas(w, h);
      _line(src, w, h, 12, 32, 84, 32, 5);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 11);
      expect(graph.paths, isNotEmpty);

      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 8,
        smoothing: 45,
      );
      expect(_opaqueCount(out), greaterThan(30));
      expect(_alpha(out, w, 48, 32), greaterThan(100));
      // The output is a centerline, not the two outside edges of the rough.
      expect(_alpha(out, w, 48, 27), lessThan(50));
      expect(_alpha(out, w, 48, 37), lessThan(50));
    });

    test('extracts a dark rough from an opaque white background', () {
      const w = 96, h = 64;
      final src = _canvas(w, h);
      _fillOpaque(src, 255);
      _line(src, w, h, 12, 32, 84, 32, 5, shade: 24);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 11);
      expect(graph.paths, isNotEmpty);

      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 8,
        smoothing: 45,
      );
      expect(_alpha(out, w, 48, 32), greaterThan(100));
      expect(_alpha(out, w, 48, 10), lessThan(20));
    });

    test('extracts a light rough from an opaque dark background', () {
      const w = 96, h = 64;
      final src = _canvas(w, h);
      _fillOpaque(src, 8);
      _line(src, w, h, 12, 32, 84, 32, 5, shade: 235);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 11);
      expect(graph.paths, isNotEmpty);

      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 8,
        smoothing: 45,
      );
      expect(_alpha(out, w, 48, 32), greaterThan(100));
      expect(_alpha(out, w, 48, 10), lessThan(20));
    });

    test(
      'uniform opaque background does not become a full-canvas line graph',
      () {
        const w = 72, h = 48;
        final src = _canvas(w, h);
        _fillOpaque(src, 248);

        final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
        expect(graph.paths, isEmpty);
      },
    );

    test('keeps an X crossing as connected topology', () {
      const w = 96, h = 96;
      final src = _canvas(w, h);
      _line(src, w, h, 14, 14, 82, 82, 4);
      _line(src, w, h, 82, 14, 14, 82, 4);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
      expect(graph.paths.length, greaterThanOrEqualTo(4));
      expect(
        graph.paths.where((p) => p.startIsJunction || p.endIsJunction),
        isNotEmpty,
      );

      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 10,
        smoothing: 70,
      );
      expect(_alpha(out, w, 48, 48), greaterThan(100));
      expect(_alpha(out, w, 24, 24), greaterThan(20));
      expect(_alpha(out, w, 72, 24), greaterThan(20));
      expect(_alpha(out, w, 24, 72), greaterThan(20));
      expect(_alpha(out, w, 72, 72), greaterThan(20));
    });

    test('keeps a Y merge and does not taper at its junction', () {
      const w = 96, h = 96;
      final src = _canvas(w, h);
      _line(src, w, h, 20, 18, 48, 48, 4);
      _line(src, w, h, 76, 18, 48, 48, 4);
      _line(src, w, h, 48, 48, 48, 82, 4);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
      final junctionPaths = graph.paths
          .where((p) => p.startIsJunction || p.endIsJunction)
          .toList();
      expect(junctionPaths.length, greaterThanOrEqualTo(3));

      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 4,
        taperLengthPx: 18,
        smoothing: 55,
      );
      // Junction is a locked topology anchor; taper is only applied at free ends.
      expect(_alpha(out, w, 48, 48), greaterThan(200));
    });

    test('prunes a very short unstable terminal nub', () {
      const w = 120, h = 72;
      final src = _canvas(w, h);
      _line(src, w, h, 10, 36, 110, 36, 5);
      // Tiny accidental touch/nub on the main rough.
      _line(src, w, h, 60, 36, 60, 40, 2);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 12);
      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 8,
        smoothing: 50,
      );
      expect(_alpha(out, w, 60, 36), greaterThan(100));
      expect(_alpha(out, w, 60, 44), lessThan(30));
    });

    test(
      'smoothing changes geometry without moving locked endpoints far away',
      () {
        const w = 100, h = 80;
        final src = _canvas(w, h);
        // Deliberately wobbly thick rough.
        var lastX = 10;
        var lastY = 38;
        for (var x = 14; x <= 90; x += 4) {
          final y = 38 + ((x ~/ 4).isEven ? 3 : -3);
          _line(src, w, h, lastX, lastY, x, y, 4);
          lastX = x;
          lastY = y;
        }

        final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
        final raw = AutoLineartEngine.render(
          graph,
          w,
          h,
          outputWidthPx: 2,
          taperLengthPx: 0,
          smoothing: 0,
        );
        final smooth = AutoLineartEngine.render(
          graph,
          w,
          h,
          outputWidthPx: 2,
          taperLengthPx: 0,
          smoothing: 100,
        );
        expect(raw, isNot(equals(smooth)));
        expect(_opaqueCount(smooth), greaterThan(20));
      },
    );

    test('rasterizer always emits partial-alpha antialias coverage', () {
      const w = 80, h = 64;
      final src = _canvas(w, h);
      _line(src, w, h, 10, 16, 70, 49, 4);
      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 3,
        taperLengthPx: 0,
        smoothing: 60,
      );
      var partial = 0;
      for (var i = 3; i < out.length; i += 4) {
        if (out[i] > 0 && out[i] < 255) partial++;
      }
      expect(partial, greaterThan(0));
    });

    test('restricts expensive topology work to a sparse rough bounding box', () {
      const w = 512, h = 512;
      final src = _canvas(w, h);
      _line(src, w, h, 236, 252, 276, 252, 5);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 11);
      expect(graph.paths, isNotEmpty);
      expect(graph.analysisWidth * graph.analysisHeight, lessThan(w * h ~/ 20));

      // Paths must still use original canvas coordinates after local analysis.
      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 6,
        smoothing: 45,
      );
      expect(_alpha(out, w, 256, 252), greaterThan(100));
      expect(_alpha(out, w, 40, 40), 0);
    });

    test(
      'cropped analysis preserves coordinates near the bottom-right edge',
      () {
        const w = 320, h = 240;
        final src = _canvas(w, h);
        _line(src, w, h, 260, 210, 306, 210, 4);

        final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
        expect(graph.paths, isNotEmpty);
        expect(graph.analysisWidth, lessThan(w));
        expect(graph.analysisHeight, lessThan(h));

        final out = AutoLineartEngine.render(
          graph,
          w,
          h,
          outputWidthPx: 2,
          taperLengthPx: 4,
          smoothing: 30,
        );
        expect(_alpha(out, w, 283, 210), greaterThan(80));
        expect(_alpha(out, w, 123, 100), 0);
      },
    );

    test('0-10 smoothing progressively reduces editable control points', () {
      const w = 160, h = 100;
      final src = _canvas(w, h);
      var lastX = 10;
      var lastY = 50;
      for (var x = 14; x <= 146; x += 4) {
        final y = 50 + ((x ~/ 4).isEven ? 7 : -7);
        _line(src, w, h, lastX, lastY, x, y, 3);
        lastX = x;
        lastY = y;
      }
      final base = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 8);
      final low = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 1,
      );
      final high = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 9,
      );
      expect(
        AutoLineartEngine.controlPointCount(high),
        lessThan(AutoLineartEngine.controlPointCount(low)),
      );
    });

    test('level 10 leaves exactly two endpoints on every path', () {
      final graph = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 10),
              AutoLineartPoint(20, 18),
              AutoLineartPoint(35, 30),
              AutoLineartPoint(50, 50),
            ],
            startIsJunction: false,
            endIsJunction: true,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [
              AutoLineartPoint(50, 50),
              AutoLineartPoint(65, 34),
              AutoLineartPoint(80, 20),
              AutoLineartPoint(90, 10),
            ],
            startIsJunction: true,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final straight = AutoLineartEngine.prepareEditableGraph(
        graph,
        smoothingLevel: 10,
      );
      expect(straight.paths, hasLength(2));
      expect(straight.paths.every((path) => path.points.length == 2), isTrue);
      expect(straight.paths[0].points.last.x, 50);
      expect(straight.paths[0].points.last.y, 50);
      expect(straight.paths[1].points.first.x, 50);
      expect(straight.paths[1].points.first.y, 50);
    });

    test('levels 1-9 remove about 10%-90% of interior controls', () {
      final points = List<AutoLineartPoint>.generate(
        12,
        (i) => AutoLineartPoint(i.toDouble(), (i % 3).toDouble()),
      );
      final graph = AutoLineartGraph(
        width: 20,
        height: 20,
        paths: [
          AutoLineartPath(
            points: points,
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final level1 = AutoLineartEngine.prepareEditableGraph(
        graph,
        smoothingLevel: 1,
      );
      final level9 = AutoLineartEngine.prepareEditableGraph(
        graph,
        smoothingLevel: 9,
      );
      expect(level1.paths.single.points.length, 11);
      expect(level9.paths.single.points.length, 3);
    });

    test(
      'render uses the selected line-art color without changing AA alpha',
      () {
        final graph = AutoLineartGraph(
          width: 40,
          height: 20,
          paths: const [
            AutoLineartPath(
              points: [AutoLineartPoint(4, 10), AutoLineartPoint(36, 10)],
              startIsJunction: false,
              endIsJunction: false,
              persistence: 1,
            ),
          ],
        );
        final out = AutoLineartEngine.render(
          graph,
          40,
          20,
          outputWidthPx: 3,
          taperLengthPx: 0,
          smoothing: 0,
          color: 0xFF2A7BE4,
        );
        final i = (10 * 40 + 20) * 4;
        expect(out[i], 0x2A);
        expect(out[i + 1], 0x7B);
        expect(out[i + 2], 0xE4);
        expect(out[i + 3], greaterThan(200));
      },
    );

    test(
      'preview keeps the rough at about 40 percent under colored line art',
      () {
        final rough = Uint8List.fromList([
          200,
          100,
          50,
          255,
          200,
          100,
          50,
          255,
        ]);
        final line = Uint8List.fromList([0, 0, 0, 0, 20, 220, 80, 255]);
        final out = AutoLineartEngine.composePreview(
          rough,
          line,
          roughOpacity: .4,
        );
        expect(out[3], inInclusiveRange(100, 104));
        expect(out[0], 200);
        expect(out[1], 100);
        expect(out[2], 50);
        expect(out[4], 20);
        expect(out[5], 220);
        expect(out[6], 80);
        expect(out[7], 255);
      },
    );

    test('manual offsets survive smoothing changes', () {
      final baseline = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 50),
              AutoLineartPoint(30, 48),
              AutoLineartPoint(50, 50),
              AutoLineartPoint(70, 52),
              AutoLineartPoint(90, 50),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final edited = AutoLineartEngine.moveControlPoint(
        baseline,
        pathIndex: 0,
        pointIndex: 2,
        point: const AutoLineartPoint(50, 35),
      );
      final target = AutoLineartEngine.prepareEditableGraph(
        baseline,
        smoothingLevel: 5,
      );
      final transferred = AutoLineartEngine.transferControlEdits(
        baseline,
        edited,
        target,
      );
      expect(transferred.paths.single.points.any((p) => p.y < 42), isTrue);
    });

    test('rough-width topology refresh keeps edits and accepts new paths', () {
      final baseline = AutoLineartGraph(
        width: 120,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(90, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final edited = AutoLineartEngine.moveControlPoint(
        baseline,
        pathIndex: 0,
        pointIndex: 1,
        point: const AutoLineartPoint(50, 28),
      );
      final expanded = AutoLineartGraph(
        width: 120,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(5, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(105, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [AutoLineartPoint(70, 15), AutoLineartPoint(100, 15)],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final transferred = AutoLineartEngine.transferControlEdits(
        baseline,
        edited,
        expanded,
      );
      expect(transferred.paths, hasLength(2));
      expect(transferred.paths.first.points[1].y, lessThan(35));
      expect(transferred.paths[1].points, expanded.paths[1].points);
    });

    test(
      'rough-width topology refresh allows a persistent path to shorten',
      () {
        final baseline = AutoLineartGraph(
          width: 120,
          height: 80,
          paths: const [
            AutoLineartPath(
              points: [
                AutoLineartPoint(5, 40),
                AutoLineartPoint(50, 40),
                AutoLineartPoint(110, 40),
              ],
              startIsJunction: false,
              endIsJunction: false,
              persistence: 1,
            ),
          ],
        );
        final edited = AutoLineartEngine.moveControlPoint(
          baseline,
          pathIndex: 0,
          pointIndex: 1,
          point: const AutoLineartPoint(50, 30),
        );
        final shortened = AutoLineartGraph(
          width: 120,
          height: 80,
          paths: const [
            AutoLineartPath(
              points: [
                AutoLineartPoint(20, 40),
                AutoLineartPoint(50, 40),
                AutoLineartPoint(75, 40),
              ],
              startIsJunction: false,
              endIsJunction: false,
              persistence: 1,
            ),
          ],
        );
        final transferred = AutoLineartEngine.transferControlEdits(
          baseline,
          edited,
          shortened,
        );
        expect(transferred.paths.single.points.first.x, closeTo(20, .001));
        expect(transferred.paths.single.points.last.x, closeTo(75, .001));
        expect(transferred.paths.single.points[1].y, lessThan(35));
      },
    );

    test(
      'dragging a shared junction keeps coincident branch endpoints joined',
      () {
        final graph = AutoLineartGraph(
          width: 100,
          height: 100,
          paths: const [
            AutoLineartPath(
              points: [AutoLineartPoint(10, 10), AutoLineartPoint(50, 50)],
              startIsJunction: false,
              endIsJunction: true,
              persistence: 1,
            ),
            AutoLineartPath(
              points: [AutoLineartPoint(50, 50), AutoLineartPoint(90, 10)],
              startIsJunction: true,
              endIsJunction: false,
              persistence: 1,
            ),
          ],
        );
        final moved = AutoLineartEngine.moveControlPoint(
          graph,
          pathIndex: 0,
          pointIndex: 1,
          point: const AutoLineartPoint(54, 57),
        );
        expect(moved.paths[0].points.last.x, 54);
        expect(moved.paths[0].points.last.y, 57);
        expect(moved.paths[1].points.first.x, 54);
        expect(moved.paths[1].points.first.y, 57);
      },
    );

    test('manual control movement changes the rasterized line position', () {
      final graph = AutoLineartGraph(
        width: 100,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(90, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final moved = AutoLineartEngine.moveControlPoint(
        graph,
        pathIndex: 0,
        pointIndex: 1,
        point: const AutoLineartPoint(50, 25),
      );
      final out = AutoLineartEngine.render(
        moved,
        100,
        80,
        outputWidthPx: 3,
        taperLengthPx: 0,
        smoothing: 0,
      );
      expect(_alpha(out, 100, 50, 25), greaterThan(80));
      expect(_alpha(out, 100, 50, 40), lessThan(80));
    });
  });
}
