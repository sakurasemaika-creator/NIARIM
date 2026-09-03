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

  test('旧版に保存済みの標準Pen/Gペンの点線spacingを起動時に1へ移行する', () async {
    final seed = BrushService();
    await seed.init();
    final old = seed.brushes
        .map((b) {
          if (b.id == 'Brush0001') return b.copyWith(spacing: 10);
          if (b.id == 'Brush0002') return b.copyWith(spacing: 5);
          return b;
        })
        .map((b) => jsonEncode(b.toJson()))
        .toList();
    SharedPreferences.setMockInitialValues({'brushes': old});

    final migrated = BrushService();
    await migrated.init();
    expect(migrated.brushes.firstWhere((b) => b.id == 'Brush0001').spacing, 1);
    expect(migrated.brushes.firstWhere((b) => b.id == 'Brush0002').spacing, 1);

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs
        .getStringList('brushes')!
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
    expect(persisted.firstWhere((j) => j['id'] == 'Brush0001')['spacing'], 1);
    expect(persisted.firstWhere((j) => j['id'] == 'Brush0002')['spacing'], 1);
  });
}
