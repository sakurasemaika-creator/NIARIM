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
  });
}
