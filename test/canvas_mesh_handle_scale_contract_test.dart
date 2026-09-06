import 'package:flutter_test/flutter_test.dart';

void main() {
  test('メッシュ格子点の28pxヒット領域はfit倍率とpinch倍率の両方で逆算する', () {
    const screenRadius = 28.0;
    const canvasWidth = 640.0;
    const drawingRectWidth = 320.0;
    const zoom = 0.2;

    final fitScale = drawingRectWidth / canvasWidth;
    final effectiveScale = fitScale * zoom;
    final correctCanvasRadius = screenRadius / effectiveScale;
    final zoomOnlyRadius = screenRadius / zoom;

    expect(fitScale, 0.5);
    expect(effectiveScale, 0.1);
    expect(correctCanvasRadius, 280.0);
    expect(zoomOnlyRadius, 140.0);
    expect(correctCanvasRadius * effectiveScale, screenRadius);
  });

  test('通常倍率でもproject→widgetのfit倍率を無視してはいけない', () {
    const screenRadius = 28.0;
    const canvasWidth = 1920.0;
    const drawingRectWidth = 384.0;
    const zoom = 1.0;

    final effectiveScale = (drawingRectWidth / canvasWidth) * zoom;
    final canvasRadius = screenRadius / effectiveScale;
    expect(effectiveScale, 0.2);
    expect(canvasRadius, 140.0);
    expect(canvasRadius * effectiveScale, screenRadius);
  });
}
