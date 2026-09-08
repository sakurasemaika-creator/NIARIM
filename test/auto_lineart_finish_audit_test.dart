import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _canvas(int w, int h) => Uint8List(w * h * 4);

void _fill(Uint8List b, int r, int g, int bl, int a) {
  for (var i = 0; i < b.length; i += 4) {
    b[i] = r;
    b[i + 1] = g;
    b[i + 2] = bl;
    b[i + 3] = a;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto line art finish audit', () {
    test('legacy persisted smoothing 0..100 migrates to 0..10 and persists', () async {
      final old = FilterDef(
        id: 'Filter0023',
        name: '自動線画',
        kind: FilterKind.autoLineart,
        autoLineartSmoothing: 85,
      ).toJson();
      old['autoLineartSmoothing'] = 85.0;
      old.remove('autoLineartColor');
      SharedPreferences.setMockInitialValues({
        'draw_filters': [jsonEncode(old)],
      });
      final service = FilterService();
      await service.init();
      final migrated = service.filters.singleWhere(
        (f) => f.kind == FilterKind.autoLineart,
      );
      expect(migrated.autoLineartSmoothing, 9);
      expect(migrated.autoLineartColor, 0xFF000000);

      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList('draw_filters')!;
      final persistedFilter = persisted
          .map((s) => FilterDef.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .singleWhere((f) => f.kind == FilterKind.autoLineart);
      expect(persistedFilter.autoLineartSmoothing, 9);
    });

    test('line color survives FilterDef JSON round trip', () {
      const color = 0xFF7B2FE0;
      final filter = const FilterDef(
        id: 'x',
        name: 'x',
        kind: FilterKind.autoLineart,
        autoLineartColor: color,
      );
      final decoded = FilterDef.fromJson(filter.toJson());
      expect(decoded.autoLineartColor, color);
    });

    test('level 10 keeps every X/Y/independent path as its own 2-point line', () {
      final graph = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 10),
              AutoLineartPoint(30, 30),
              AutoLineartPoint(50, 50),
            ],
            startIsJunction: false,
            endIsJunction: true,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [
              AutoLineartPoint(90, 10),
              AutoLineartPoint(70, 30),
              AutoLineartPoint(50, 50),
            ],
            startIsJunction: false,
            endIsJunction: true,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [
              AutoLineartPoint(50, 50),
              AutoLineartPoint(50, 70),
              AutoLineartPoint(50, 90),
            ],
            startIsJunction: true,
            endIsJunction: false,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [
              AutoLineartPoint(8, 82),
              AutoLineartPoint(20, 76),
              AutoLineartPoint(34, 78),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final straight = AutoLineartEngine.prepareEditableGraph(
        graph,
        smoothingLevel: 10,
      );
      expect(straight.paths, hasLength(4));
      expect(straight.paths.every((p) => p.points.length == 2), isTrue);
      expect(straight.paths[0].points.last.x, 50);
      expect(straight.paths[1].points.last.x, 50);
      expect(straight.paths[2].points.first.x, 50);
    });

    test('canvas-edge, tiny, very thick, many-lines and many-branch inputs stay safe', () {
      const w = 256, h = 256;

      final edge = _canvas(w, h);
      _line(edge, w, h, 0, 1, 252, 1, 3);
      final edgeGraph = AutoLineartEngine.analyze(edge, w, h, roughWidthPx: 8);
      expect(edgeGraph.paths, isNotEmpty);
      for (final path in edgeGraph.paths) {
        for (final p in path.points) {
          expect(p.x, inInclusiveRange(0, w - 1));
          expect(p.y, inInclusiveRange(0, h - 1));
        }
      }

      final tiny = _canvas(w, h);
      _line(tiny, w, h, 120, 128, 132, 128, 2);
      expect(
        () => AutoLineartEngine.analyze(tiny, w, h, roughWidthPx: 5),
        returnsNormally,
      );

      final thick = _canvas(w, h);
      _line(thick, w, h, 20, 128, 236, 128, 30);
      final thickGraph = AutoLineartEngine.analyze(
        thick,
        w,
        h,
        roughWidthPx: 64,
      );
      expect(thickGraph.paths, isNotEmpty);

      final dense = _canvas(w, h);
      for (var y = 16; y <= 240; y += 16) {
        _line(dense, w, h, 8, y, 248, y, 2);
      }
      for (var x = 16; x <= 240; x += 32) {
        _line(dense, w, h, x, 8, x, 248, 2);
      }
      final denseGraph = AutoLineartEngine.analyze(
        dense,
        w,
        h,
        roughWidthPx: 6,
      );
      expect(denseGraph.paths.length, greaterThan(10));
      final denseOut = AutoLineartEngine.render(
        AutoLineartEngine.prepareEditableGraph(
          denseGraph,
          smoothingLevel: 5,
        ),
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 4,
        smoothing: 0,
      );
      expect(denseOut.length, w * h * 4);
    });

    test('transparent, white and black rough backgrounds all apply through production isolate', () {
      const w = 128, h = 96;
      const filter = FilterDef(
        id: 'Filter0023',
        name: '自動線画',
        kind: FilterKind.autoLineart,
        autoLineartRoughWidth: 11,
        autoLineartOutputWidth: 3,
        autoLineartTaperLength: 5,
        autoLineartSmoothing: 5,
        autoLineartColor: 0xFF2864D7,
      );

      final transparent = _canvas(w, h);
      _line(transparent, w, h, 12, 48, 116, 48, 5);
      final t = applyDrawFilterInIsolate((transparent, w, h, filter, null));
      expect(_alpha(t, w, 64, 48), greaterThan(100));

      final white = _canvas(w, h);
      _fill(white, 255, 255, 255, 255);
      _line(white, w, h, 12, 48, 116, 48, 5, shade: 20);
      final wh = applyDrawFilterInIsolate((white, w, h, filter, null));
      expect(_alpha(wh, w, 64, 48), greaterThan(100));

      final black = _canvas(w, h);
      _fill(black, 8, 8, 8, 255);
      _line(black, w, h, 12, 48, 116, 48, 5, shade: 240);
      final bl = applyDrawFilterInIsolate((black, w, h, filter, null));
      expect(_alpha(bl, w, 64, 48), greaterThan(100));
    });

    test('large sparse canvas keeps expensive topology local with bounded runtime and RSS', () {
      const w = 2048, h = 2048;
      final src = _canvas(w, h);
      _line(src, w, h, 930, 1024, 1118, 1024, 7);
      final rssBefore = ProcessInfo.currentRss;
      final sw = Stopwatch()..start();
      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 16);
      sw.stop();
      final rssAfter = ProcessInfo.currentRss;
      final heavyPixels = graph.analysisWidth * graph.analysisHeight;
      // This asserts the algorithmic optimization directly; wall time/RSS are
      // deliberately broad CI guardrails rather than device-performance promises.
      expect(heavyPixels, lessThan(w * h ~/ 40));
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
      expect(rssAfter - rssBefore, lessThan(512 * 1024 * 1024));
      // ignore: avoid_print
      print(
        'AUTO_LINEART_PERF elapsed_ms=${sw.elapsedMilliseconds} '
        'analysis=${graph.analysisWidth}x${graph.analysisHeight} '
        'heavy_ratio=${heavyPixels / (w * h)} rss_delta=${rssAfter - rssBefore}',
      );
    });
  });
}
