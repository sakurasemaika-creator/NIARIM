import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/watermark_render.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a placed raster keeps its own center and survives clipping', () async {
    const width = 120;
    const height = 80;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(84, 60, 32, 16),
      ui.Paint()..color = const ui.Color(0xfff01668),
    );
    final picture = recorder.endRecording();
    final original = await picture.toImage(width, height);
    picture.dispose();
    addTearDown(original.dispose);

    final source = (await capturePlacedWatermark(
      original,
      angle: 0,
      scale: 0.25,
    ))!;
    expect(source.center, const ui.Offset(100, 68));

    Future<ui.Rect> bounds(double angle, double scale) async {
      final pixels = (await renderPlacedWatermark(
        PlacedWatermarkSource.fromJson(source.toJson())!,
        width: width,
        height: height,
        angle: angle,
        scale: scale,
      ))!;
      final points = <ui.Offset>[];
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (pixels[(y * width + x) * 4 + 3] >= 128) {
            points.add(ui.Offset(x.toDouble(), y.toDouble()));
          }
        }
      }
      final left = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final top = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final right = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final bottom = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      return ui.Rect.fromLTRB(left, top, right + 1, bottom + 1);
    }

    expect(await bounds(0, 0.50), const ui.Rect.fromLTRB(68, 52, 120, 80));
    expect(await bounds(90, 0.25), const ui.Rect.fromLTRB(92, 52, 108, 80));
    expect(await bounds(0, 0.25), const ui.Rect.fromLTRB(84, 60, 116, 76));
    expect(
      await renderPlacedWatermark(
        source,
        width: width,
        height: height,
        angle: 0,
        scale: .25,
      ),
      (await original.toByteData())!.buffer.asUint8List(),
    );
  });
}
