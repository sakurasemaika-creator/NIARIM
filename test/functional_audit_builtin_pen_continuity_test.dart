import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('標準ペン/Gペンは実プリセットのまま連続線になり透明ギャップを作らない', () async {
    final service = BrushService();
    await service.init();
    for (final id in const ['Brush0001', 'Brush0002']) {
      final brush = service.brushes.firstWhere((b) => b.id == id);
      expect(brush.spacing, 1, reason: '${brush.name}の標準間隔は連続線になる1pxであること');

      const w = 220, h = 80, y = 40.0;
      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = brush
        ..currentColor = const ui.Color(0xFFD83A28);
      engine.beginStroke(const StrokePoint(x: 15, y: y, pressure: 1), 'paint');
      for (var x = 19.0; x <= 205; x += 4) {
        engine.continueStroke(StrokePoint(x: x, y: y, pressure: 1), 'paint');
      }
      engine.endStroke();

      final image = await tm.compositeLayerToImage('paint');
      final raw = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      await File(
        '${out.path}/builtin_${id}_continuous_line.png',
      ).writeAsBytes(png);

      // 手ブレ補正の追従遅れを避けて中央区間のみ見る。各x列の中心±3pxに
      // 少なくとも1画素が存在し、目視で点線になる透明列が1本も無いこと。
      for (var x = 30; x <= 175; x++) {
        var painted = false;
        for (var yy = 37; yy <= 43; yy++) {
          if (raw[(yy * w + x) * 4 + 3] != 0) {
            painted = true;
            break;
          }
        }
        expect(painted, isTrue, reason: '${brush.name}: x=$x に透明な縦ギャップを作らないこと');
      }
      image.dispose();
      tm.dispose();
    }
  });

  test('混色ブラシは弱い筆圧でも濃さが周期的に落ち込まない', () {
    final brush = BrushService.builtInBrushes.firstWhere(
      (brush) => brush.id == 'Brush0004',
    );
    final tm = TileManager(canvasWidth: 120, canvasHeight: 80);
    addTearDown(tm.dispose);
    final engine = DrawingEngine(tileManager: tm)..currentBrush = brush;
    engine.beginStroke(
      const StrokePoint(x: 12.5, y: 40.5, pressure: 0.4),
      'paint',
    );
    engine.continueStroke(
      const StrokePoint(x: 107.5, y: 40.5, pressure: 0.4),
      'paint',
    );
    engine.endStroke();
    final tile = tm.getTile('paint', 0, 0)!;
    final alphas = [
      for (var x = 25; x <= 95; x++)
        tile[(40 * TileManager.tileSize + x) * 4 + 3],
    ]..sort();
    expect(alphas.first, greaterThan(0));
    expect(alphas.last - alphas.first, lessThanOrEqualTo(3));
  });

  test('旧版に保存済みの標準ペンと混色ブラシの間隔を起動時に1へ移行する', () async {
    final seed = BrushService();
    await seed.init();
    const oldSpacings = {'Brush0001': 10, 'Brush0002': 5, 'Brush0004': 8};
    final custom = seed.brushes
        .firstWhere((b) => b.id == 'Brush0004')
        .copyWith(id: 'custom-mixer', spacing: 8);
    final old = [...seed.brushes, custom]
        .map((b) => b.copyWith(spacing: oldSpacings[b.id]))
        .map((b) => jsonEncode(b.toJson()))
        .toList();
    SharedPreferences.setMockInitialValues({'brushes': old});

    final migrated = BrushService();
    await migrated.init();

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs
        .getStringList('brushes')!
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
    for (final (id, spacing) in [
      for (final id in oldSpacings.keys) (id, 1),
      (custom.id, custom.spacing),
    ]) {
      expect(migrated.brushes.firstWhere((b) => b.id == id).spacing, spacing);
      expect(persisted.firstWhere((j) => j['id'] == id)['spacing'], spacing);
    }
  });
}
