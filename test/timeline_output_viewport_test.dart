import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/timeline_output_viewport.dart';

void main() {
  group('TimelineOutputViewport', () {
    test('uses no offset when drawing and output sizes match', () {
      const viewport = TimelineOutputViewport(
        drawingWidth: 1920,
        drawingHeight: 1080,
        outputWidth: 1920,
        outputHeight: 1080,
      );

      expect(viewport.cropLeft, 0);
      expect(viewport.cropTop, 0);
      expect(viewport.imageOffsetX, 0);
      expect(viewport.imageOffsetY, 0);
    });

    test('centres a smaller landscape output in a larger drawing area', () {
      const viewport = TimelineOutputViewport(
        drawingWidth: 2400,
        drawingHeight: 1600,
        outputWidth: 1920,
        outputHeight: 1080,
      );

      expect(viewport.cropLeft, 240);
      expect(viewport.cropTop, 260);
      expect(viewport.imageOffsetX, -240);
      expect(viewport.imageOffsetY, -260);
    });

    test('keeps fractional centre offsets for odd size differences', () {
      const viewport = TimelineOutputViewport(
        drawingWidth: 1001,
        drawingHeight: 701,
        outputWidth: 800,
        outputHeight: 600,
      );

      expect(viewport.cropLeft, 100.5);
      expect(viewport.cropTop, 50.5);
    });

    test('supports output larger than drawing by centring the drawing', () {
      const viewport = TimelineOutputViewport(
        drawingWidth: 800,
        drawingHeight: 600,
        outputWidth: 1920,
        outputHeight: 1080,
      );

      expect(viewport.imageOffsetX, 560);
      expect(viewport.imageOffsetY, 240);
    });

    test('preview and export painter produce identical cropped pixels', () async {
      final sourceRecorder = ui.PictureRecorder();
      final sourceCanvas = ui.Canvas(sourceRecorder);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 6; x++) {
          sourceCanvas.drawRect(
            ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            ui.Paint()
              ..color = ui.Color.fromARGB(
                255,
                20 + x * 30,
                15 + y * 40,
                10 + x + y,
              ),
          );
        }
      }
      final sourcePicture = sourceRecorder.endRecording();
      final source = await sourcePicture.toImage(6, 4);
      sourcePicture.dispose();

      const viewport = TimelineOutputViewport(
        drawingWidth: 6,
        drawingHeight: 4,
        outputWidth: 4,
        outputHeight: 2,
      );

      Future<Uint8List> renderThroughSharedPainter() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        paintOutputViewport(canvas, source, viewport);
        final picture = recorder.endRecording();
        final image = await picture.toImage(4, 2);
        picture.dispose();
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return data!.buffer.asUint8List();
      }

      final previewPixels = await renderThroughSharedPainter();
      final exportPixels = await renderThroughSharedPainter();
      expect(previewPixels, orderedEquals(exportPixels));

      // The output is the centred x=1..4, y=1..2 rectangle of the source.
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 4; x++) {
          final offset = (y * 4 + x) * 4;
          expect(previewPixels[offset], 20 + (x + 1) * 30);
          expect(previewPixels[offset + 1], 15 + (y + 1) * 40);
          expect(previewPixels[offset + 2], 10 + (x + 1) + (y + 1));
          expect(previewPixels[offset + 3], 255);
        }
      }
      source.dispose();
    });
  });
}
