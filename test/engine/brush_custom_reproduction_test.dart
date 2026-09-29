import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

Map<String, Uint8List> drawBrush(Brush brush) {
  final tiles = TileManager(canvasWidth: 160, canvasHeight: 160);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush.copyWith(
      size: 24,
      stabilization: false,
      fadeMode: FadeMode.off,
    )
    ..pressureEnabled = false;
  StrokePoint point(double x) =>
      StrokePoint(x: x, y: 80, pressure: 1, tiltX: 0, tiltY: 0);
  engine.beginStroke(point(25), 'ink');
  for (var x = 30.0; x <= 130; x += 5) engine.continueStroke(point(x), 'ink');
  engine.endStroke();
  final result = tiles.exportAll()['ink']!.map(
    (key, value) => MapEntry(key, Uint8List.fromList(value)),
  );
  tiles.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('changing a preset identity never changes the rendered brush', () async {
    SharedPreferences.setMockInitialValues({});
    final service = BrushService();
    await service.init();
    for (final id in [
      'Brush0016',
      'Brush0018',
      'Brush0019',
      'Brush0020',
      'Brush0021',
    ]) {
      final preset = service.brushes.singleWhere((b) => b.id == id);
      final custom = Brush.fromJson(
        preset.copyWith(id: 'user-$id', name: 'My brush').toJson(),
      );
      expect(
        drawBrush(custom),
        drawBrush(preset),
        reason: 'same public settings: $id',
      );
    }
    service.dispose();
  });
  test(
    'an identical source image is interpreted equally at any path',
    () async {
      const asset = 'assets/brushes/bangs_01.png';
      final dir = await Directory.systemTemp.createTemp('niarim-common-ink-');
      addTearDown(() => dir.delete(recursive: true));
      final data = await rootBundle.load(asset);
      final file = File('${dir.path}/user-image.png');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      for (final mode in BrushImageInkMode.values) {
        await preloadBrushTextures([asset, file.path], mode: mode);
        expect(getCachedBrushTexture(asset, mode: mode), isNotNull);
        expect(
          getCachedBrushTexture(file.path, mode: mode),
          getCachedBrushTexture(asset, mode: mode),
        );
      }
      expect(
        getCachedBrushTexture(asset, mode: BrushImageInkMode.dark),
        isNot(getCachedBrushTexture(asset, mode: BrushImageInkMode.light)),
      );
      expect(
        getCachedBrushTexture(asset, mode: BrushImageInkMode.alpha),
        isNot(getCachedBrushTexture(asset, mode: BrushImageInkMode.light)),
      );
    },
  );
}
