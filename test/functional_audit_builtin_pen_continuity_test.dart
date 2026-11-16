import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/utils/brush_image_source.dart';
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

  test('画像ペン先は初回から描け、ユーザーブラシとして再現できる', () async {
    final service = BrushService();
    addTearDown(service.dispose);
    await service.init();
    final temp = await Directory.systemTemp.createTemp('niarim-image-tips-');
    addTearDown(() => temp.delete(recursive: true));

    List<int> pixels(Brush brush, {required bool horizontal}) {
      final tiles = TileManager(canvasWidth: 112, canvasHeight: 112);
      try {
        final engine = DrawingEngine(tileManager: tiles)..currentBrush = brush;
        StrokePoint point(double along) => StrokePoint(
          x: horizontal ? along : 56,
          y: horizontal ? 56 : along,
          pressure: 1,
        );
        engine.beginStroke(point(20), 'paint');
        for (var along = 24.0; along <= 92; along += 4) {
          engine.continueStroke(point(along), 'paint');
        }
        engine.endStroke();
        return tiles.getTile('paint', 0, 0)!.toList();
      } finally {
        tiles.dispose();
      }
    }

    int width(List<int> tile, {required bool horizontal}) {
      int alpha(int x, int y) => tile[(y * TileManager.tileSize + x) * 4 + 3];
      return [
        for (var across = 20; across <= 92; across++)
          horizontal ? alpha(56, across) : alpha(across, 56),
      ].where((alpha) => alpha >= 64).length;
    }

    for (final id in ['Brush0005', 'Brush0006', 'Brush0009']) {
      service.selectBrush(id);
      final preset = service.currentBrush!;
      final asset = preset.resolvedCustomImagePaths.single;
      expect(preset.calligraphyAngle, isNull);
      expect(
        getCachedBrushTexture(asset, mode: preset.imageInkMode),
        isNotNull,
      );

      final originalHorizontal = pixels(preset, horizontal: true);
      final originalVertical = pixels(preset, horizontal: false);
      final bundle = await service.exportBrushToPath(
        id,
        '${temp.path}/$id.niabrush',
      );
      final custom = await service.importBrushFile(
        bundle.path,
        imagesDirectory: '${temp.path}/$id',
      );
      final path = custom.resolvedCustomImagePaths.single;
      expect(await File(path).readAsBytes(), await readBrushImageSource(asset));
      await preloadBrushTexture(path, mode: custom.imageInkMode);
      expect(
        listEquals(originalHorizontal, pixels(custom, horizontal: true)),
        isTrue,
      );
      expect(
        listEquals(originalVertical, pixels(custom, horizontal: false)),
        isTrue,
      );

      final horizontal = width(originalHorizontal, horizontal: true);
      final vertical = width(originalVertical, horizontal: false);
      expect(horizontal, greaterThan(0));
      expect(vertical, greaterThan(0));
      if (id == 'Brush0009') {
        expect(horizontal, greaterThan(vertical * 2));
      } else {
        expect(vertical, greaterThan(horizontal * 2));
      }
    }
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
