import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'chain and ball-chain presets are installed with distinct practical scales',
    () async {
      final service = BrushService();
      await service.init();
      final thick = service.brushes.firstWhere((b) => b.id == 'Brush0018');
      final medium = service.brushes.firstWhere((b) => b.id == 'Brush0019');
      final thin = service.brushes.firstWhere((b) => b.id == 'Brush0020');
      final ball = service.brushes.firstWhere((b) => b.id == 'Brush0021');
      expect(
        [thick.name, medium.name, thin.name, ball.name],
        ['チェーン（太）', 'チェーン（中）', 'チェーン（細）', 'ボールチェーン'],
      );
      expect(thick.size, greaterThan(medium.size));
      expect(medium.size, greaterThan(thin.size));
      expect(thin.size, greaterThan(ball.size));
      expect(thick.rotation, isTrue);
      expect(medium.rotation, isTrue);
      expect(thin.rotation, isTrue);
      expect(ball.rotation, isFalse);
    },
  );

  test(
    'procedural chain renders repeated hollow links instead of a solid stroke',
    () async {
      final service = BrushService();
      await service.init();
      final brush = service.brushes.firstWhere((b) => b.id == 'Brush0019');
      const w = 260, h = 100, y = 50.0;
      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = brush
        ..currentColor = const ui.Color(0xFF303030);
      engine.beginStroke(const StrokePoint(x: 25, y: y), 'chain');
      for (var x = 30.0; x <= 235; x += 5) {
        engine.continueStroke(StrokePoint(x: x, y: y), 'chain');
      }
      engine.endStroke();
      final image = await tm.compositeLayerToImage('chain');
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      image.dispose();
      var painted = 0;
      var transparentInsideBand = 0;
      for (var x = 35; x < 225; x++) {
        for (var yy = 42; yy <= 58; yy++) {
          final a = data[(yy * w + x) * 4 + 3];
          if (a > 0) {
            painted++;
          } else {
            transparentInsideBand++;
          }
        }
      }
      expect(painted, greaterThan(300));
      expect(transparentInsideBand, greaterThan(300), reason: '中抜きリンクの穴が残ること');
      tm.dispose();
    },
  );

  test(
    'leaf and grass background stamps are multicolor dense procedural textures',
    () async {
      final service = StampService();
      await service.init();
      final leaf = service.stamps.firstWhere((s) => s.id == 'Stamp0025');
      final grass = service.stamps.firstWhere((s) => s.id == 'Stamp0026');
      expect(leaf.name, '葉っぱ（背景）');
      expect(grass.name, '草（背景）');
      expect(leaf.density, greaterThan(2));
      expect(grass.density, greaterThan(2));
      expect(leaf.scatter, greaterThan(0));
      expect(grass.scatter, greaterThan(0));

      for (final stamp in [leaf, grass]) {
        final texture = await generateBuiltInStampTexture(stamp, size: 128);
        var nonTransparent = 0;
        final colors = <int>{};
        for (var i = 0; i < texture.length; i += 4) {
          if (texture[i + 3] == 0) continue;
          nonTransparent++;
          colors.add(
            (texture[i] << 16) | (texture[i + 1] << 8) | texture[i + 2],
          );
        }
        expect(nonTransparent, greaterThan(900));
        expect(
          colors.length,
          greaterThanOrEqualTo(4),
          reason: '${stamp.name}に複数の緑色があること',
        );
      }
    },
  );

  test(
    'existing-user stores receive the new built-ins without losing old items',
    () async {
      final seedBrushes = BrushService();
      await seedBrushes.init();
      final oldBrushJson = (await SharedPreferences.getInstance())
          .getStringList('brushes')!;
      final oldOnly = oldBrushJson
          .where(
            (s) =>
                !s.contains('Brush0018') &&
                !s.contains('Brush0019') &&
                !s.contains('Brush0020') &&
                !s.contains('Brush0021'),
          )
          .toList();
      SharedPreferences.setMockInitialValues({'brushes': oldOnly});
      final migratedBrushes = BrushService();
      await migratedBrushes.init();
      for (final id in ['Brush0018', 'Brush0019', 'Brush0020', 'Brush0021']) {
        expect(migratedBrushes.brushes.any((b) => b.id == id), isTrue);
      }

      SharedPreferences.setMockInitialValues({});
      final seedStamps = StampService();
      await seedStamps.init();
      final oldStampJson = (await SharedPreferences.getInstance())
          .getStringList('stamps')!
          .where((s) => !s.contains('Stamp0025') && !s.contains('Stamp0026'))
          .toList();
      SharedPreferences.setMockInitialValues({'stamps': oldStampJson});
      final migratedStamps = StampService();
      await migratedStamps.init();
      expect(migratedStamps.stamps.any((s) => s.id == 'Stamp0025'), isTrue);
      expect(migratedStamps.stamps.any((s) => s.id == 'Stamp0026'), isTrue);
    },
  );
}
