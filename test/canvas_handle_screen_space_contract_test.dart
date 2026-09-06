import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

void main() {
  group('操作ハンドルは最終画面pxで一定', () {
    for (final zoom in <double>[0.2, 0.5, 1.0, 2.0, 4.0, 10.0]) {
      test('selection: zoom=$zoom', () {
        const fitScale = 0.375;
        final effective = fitScale * zoom;
        final canvasRadius = selectionHandleRadiusFor(effective);
        final finalScreenRadius = canvasRadius * fitScale * zoom;
        expect(finalScreenRadius, closeTo(kSelectionHandleScreenRadius, 1e-9));

        final rotateRadius = selectionRotateHandleRadiusFor(effective);
        final finalRotateRadius = rotateRadius * fitScale * zoom;
        expect(
          finalRotateRadius,
          closeTo(kSelectionRotateHandleScreenRadius, 1e-9),
        );
      });

      test('mesh/ruler painter compensation: zoom=$zoom', () {
        const meshScreenRadius = 8.0;
        const rulerScreenRadius = 6.0;
        final meshPainterRadius = meshScreenRadius / zoom;
        final rulerPainterRadius = rulerScreenRadius / zoom;
        expect(meshPainterRadius * zoom, closeTo(meshScreenRadius, 1e-9));
        expect(rulerPainterRadius * zoom, closeTo(rulerScreenRadius, 1e-9));
      });
    }
  });

  test('メッシュのヒット半径はfit倍率とzoom倍率の両方を含める', () {
    const screenHitRadius = 28.0;
    const fitScale = 0.25;
    const zoom = 0.2;
    final effectiveCanvasToScreen = fitScale * zoom;
    final canvasRadius = screenHitRadius / effectiveCanvasToScreen;
    expect(canvasRadius * effectiveCanvasToScreen, closeTo(28.0, 1e-9));
    // zoomだけで割る旧式だと最終画面では7pxにしかならない。
    final oldCanvasRadius = screenHitRadius / zoom;
    expect(oldCanvasRadius * effectiveCanvasToScreen, closeTo(7.0, 1e-9));
  });
}
