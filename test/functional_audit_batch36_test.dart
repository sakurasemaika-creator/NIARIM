import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('全7種類の定規を本番RulerEngine→DrawingEngineで実描画しPNGと幾何拘束を検査する', () async {
    final brushes = BrushService();
    await brushes.init();
    final baseBrush = brushes.brushes.firstWhere((b) => b.id == 'Brush0002').copyWith(size: 3, opacity: 100);

    final cases = <({String name, Ruler ruler, List<ui.Offset> raw, double Function(double,double) distance})>[
      (
        name: 'line',
        ruler: const Ruler(type: RulerType.line, position: ui.Offset(64, 64), rotation: math.pi / 2, settings: RulerSettings()),
        raw: [for (double y = 15; y <= 112; y += 8) ui.Offset(90 + math.sin(y) * 8, y)],
        distance: (x, y) => (x - 64).abs(),
      ),
      (
        name: 'circle',
        ruler: const Ruler(type: RulerType.circle, position: ui.Offset(64, 64), settings: RulerSettings(radiusX: 36)),
        raw: [for (int i = 0; i <= 24; i++) ui.Offset(64 + 45 * math.cos(i * math.pi * 2 / 24), 64 + 28 * math.sin(i * math.pi * 2 / 24))],
        distance: (x, y) => ((ui.Offset(x, y) - const ui.Offset(64, 64)).distance - 36).abs(),
      ),
      (
        name: 'ellipse',
        ruler: const Ruler(type: RulerType.ellipse, position: ui.Offset(64, 64), rotation: 0.35, settings: RulerSettings(radiusX: 40, radiusY: 23)),
        raw: [for (int i = 0; i <= 28; i++) ui.Offset(64 + 48 * math.cos(i * math.pi * 2 / 28), 64 + 30 * math.sin(i * math.pi * 2 / 28))],
        distance: (x, y) {
          final dx = x - 64, dy = y - 64;
          final c = math.cos(-0.35), s = math.sin(-0.35);
          final lx = dx * c - dy * s, ly = dx * s + dy * c;
          return (((lx * lx) / (40 * 40) + (ly * ly) / (23 * 23)) - 1).abs() * 20;
        },
      ),
      (
        name: 'radial',
        ruler: const Ruler(type: RulerType.radial, position: ui.Offset(64, 64), rotation: 0, settings: RulerSettings(divisions: 8)),
        raw: [for (double r = 12; r <= 55; r += 4) ui.Offset(64 + r * math.cos(0.48), 64 + r * math.sin(0.48))],
        distance: (x, y) => _distanceToNearestSpoke(ui.Offset(x, y), const ui.Offset(64, 64), 8, 0),
      ),
      (
        name: 'perspective1',
        ruler: const Ruler(type: RulerType.onePointPerspective, position: ui.Offset(20, 20), settings: RulerSettings(vanishingPoint1: ui.Offset(20, 20))),
        raw: [for (double t = 0; t <= 1.0; t += 0.08) ui.Offset(88 - 50 * t + 8 * math.sin(t * 15), 102 - 60 * t + 5 * math.cos(t * 11))],
        distance: (x, y) => _distanceToInfiniteLine(ui.Offset(x, y), const ui.Offset(20, 20), const ui.Offset(88, 102)),
      ),
      (
        name: 'perspective2',
        ruler: const Ruler(type: RulerType.twoPointPerspective, position: ui.Offset(64, 64), settings: RulerSettings(vanishingPoint1: ui.Offset(15, 35), vanishingPoint2: ui.Offset(113, 35))),
        raw: [for (double t = 0; t <= 1.0; t += 0.08) ui.Offset(92 - 35 * t, 100 - 25 * t + 6 * math.sin(t * 12))],
        // First anchor(92,100) is nearer VP2=(113,35), so the full stroke must stay on that ray.
        distance: (x, y) => _distanceToInfiniteLine(ui.Offset(x, y), const ui.Offset(113, 35), const ui.Offset(92, 100)),
      ),
      (
        name: 'perspective3',
        ruler: const Ruler(type: RulerType.threePointPerspective, position: ui.Offset(64, 64), settings: RulerSettings(vanishingPoint1: ui.Offset(15, 40), vanishingPoint2: ui.Offset(113, 40), vanishingPoint3: ui.Offset(64, 8))),
        raw: [for (double t = 0; t <= 1.0; t += 0.08) ui.Offset(70 + 12 * math.sin(t * 8), 92 - 35 * t)],
        // Anchor around (70,92) is closest to the bottom/top VP3=(64,8) in this compact test scene.
        distance: (x, y) => _distanceToInfiniteLine(ui.Offset(x, y), const ui.Offset(64, 8), const ui.Offset(70, 92)),
      ),
    ];

    for (final c in cases) {
      const w = 128, h = 128;
      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      final draw = DrawingEngine(tileManager: tm)
        ..currentBrush = baseBrush
        ..currentColor = const ui.Color(0xFFDB3F2E);
      final re = RulerEngine()..setActiveRuler(c.ruler);
      re.beginStroke();
      final snapped = c.raw.map(re.snapToRuler).toList();
      draw.beginStroke(StrokePoint(x: snapped.first.dx, y: snapped.first.dy, pressure: 1), 'paint');
      for (final p in snapped.skip(1)) {
        draw.continueStroke(StrokePoint(x: p.dx, y: p.dy, pressure: 1), 'paint');
      }
      draw.endStroke();

      final img = await tm.compositeLayerToImage('paint');
      final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('${out.path}/ruler_${c.name}_rendered.png').writeAsBytes(png!.buffer.asUint8List());

      var painted = 0;
      var far = 0;
      var maxDistance = 0.0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (rgba[(y * w + x) * 4 + 3] == 0) continue;
          painted++;
          final d = c.distance(x + 0.5, y + 0.5);
          if (d > maxDistance) maxDistance = d;
          if (d > 5.0) far++;
        }
      }
      expect(painted, greaterThan(20), reason: '${c.name}: actual raster stroke must be visible');
      expect(far, 0, reason: '${c.name}: every rasterized brush pixel must remain within 5px of the ruler geometry (max=$maxDistance)');
      img.dispose();
      tm.dispose();
    }
  });
}

double _distanceToInfiniteLine(ui.Offset p, ui.Offset a, ui.Offset b) {
  final ab = b - a;
  if (ab.distance < 1e-9) return (p - a).distance;
  return ((ab.dx * (a.dy - p.dy) - (a.dx - p.dx) * ab.dy).abs()) / ab.distance;
}

double _distanceToNearestSpoke(ui.Offset p, ui.Offset center, int divisions, double rotation) {
  final rel = p - center;
  if (rel.distance < 1e-9) return 0;
  var best = double.infinity;
  for (var i = 0; i < divisions; i++) {
    final a = rotation + i * math.pi * 2 / divisions;
    final dir = ui.Offset(math.cos(a), math.sin(a));
    final d = (rel.dx * dir.dy - rel.dy * dir.dx).abs();
    if (d < best) best = d;
  }
  return best;
}
