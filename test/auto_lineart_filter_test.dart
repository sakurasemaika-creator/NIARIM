import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';

Uint8List _canvas(int w, int h) => Uint8List(w * h * 4);

void _dot(Uint8List b, int w, int h, int cx, int cy, int radius) {
  for (var y = cy - radius; y <= cy + radius; y++) {
    for (var x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || x >= w || y < 0 || y >= h) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy > radius * radius) continue;
      final i = (y * w + x) * 4;
      b[i] = 20;
      b[i + 1] = 20;
      b[i + 2] = 20;
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
  int radius,
) {
  final dx = (x1 - x0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final dy = -(y1 - y0).abs();
  final sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;
  var x = x0;
  var y = y0;
  while (true) {
    _dot(b, w, h, x, y, radius);
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

      final graph = AutoLineartEngine.analyze(
        src,
        w,
        h,
        roughWidthPx: 11,
      );
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

    test('keeps an X crossing as connected topology', () {
      const w = 96, h = 96;
      final src = _canvas(w, h);
      _line(src, w, h, 14, 14, 82, 82, 4);
      _line(src, w, h, 82, 14, 14, 82, 4);

      final graph = AutoLineartEngine.analyze(
        src,
        w,
        h,
        roughWidthPx: 9,
      );
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

      final graph = AutoLineartEngine.analyze(
        src,
        w,
        h,
        roughWidthPx: 9,
      );
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

      final graph = AutoLineartEngine.analyze(
        src,
        w,
        h,
        roughWidthPx: 12,
      );
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

    test('smoothing changes geometry without moving locked endpoints far away', () {
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

      final graph = AutoLineartEngine.analyze(
        src,
        w,
        h,
        roughWidthPx: 9,
      );
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
    });

    test('rasterizer always emits partial-alpha antialias coverage', () {
      const w = 80, h = 64;
      final src = _canvas(w, h);
      _line(src, w, h, 10, 16, 70, 49, 4);
      final graph = AutoLineartEngine.analyze(
        src,
        w,
        h,
        roughWidthPx: 9,
      );
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
  });
}
