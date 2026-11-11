import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/layer_thumbnail_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> sampleLayer() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 100, 50),
      ui.Paint()..color = const ui.Color(0x00FFFFFF),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 50, 50),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 50);
    picture.dispose();
    return image;
  }

  test('actual raster preview shows project paper and preserves aspect', () async {
    final source = await sampleLayer();
    final thumbnail = await renderLayerThumbnail(
      source, backgroundColor: 0xFF20B37F, size: 48,
    );
    source.dispose();
    final data = (await thumbnail.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    ui.Color color(int x, int y) {
      final base = (y * 48 + x) * 4;
      return ui.Color.fromARGB(
        data.getUint8(base + 3),
        data.getUint8(base),
        data.getUint8(base + 1),
        data.getUint8(base + 2),
      );
    }
    // A 2:1 layer is centered vertically, not distorted to a 1:1 canvas.
    expect(color(24, 2), const ui.Color(0xFF20B37F));
    expect(color(10, 24), const ui.Color(0xFFFF0000));
    expect(color(40, 24), const ui.Color(0xFF20B37F));
    thumbnail.dispose();
  });

  test('project paper remains visible at zero layer opacity', () async {
    final source = await sampleLayer();
    final thumbnail = await renderLayerThumbnail(
      source, backgroundColor: 0xFF2B4D91, opacity: 0, size: 48,
    );
    source.dispose();
    final data = (await thumbnail.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final i = (24 * 48 + 10) * 4;
    expect(data.getUint8(i), 0x2B);
    expect(data.getUint8(i + 1), 0x4D);
    expect(data.getUint8(i + 2), 0x91);
    expect(data.getUint8(i + 3), 255);
    thumbnail.dispose();
  });
}
