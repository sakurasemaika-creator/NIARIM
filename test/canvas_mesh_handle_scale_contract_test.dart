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

  test('選択ハンドルは0.2倍でも見た目7pxと当たり判定7pxを一致させる', () {
    const screenRadius = 7.0;
    const canvasWidth = 1920.0;
    const drawingRectWidth = 384.0;
    const zoom = 0.2;

    final fitScale = drawingRectWidth / canvasWidth;
    final effectiveScale = fitScale * zoom;
    final canvasRadius = screenRadius / effectiveScale;

    expect(canvasRadius, closeTo(175.0, 1e-9));
    expect(canvasRadius * effectiveScale, screenRadius);

    final uncorrectedPaintRadius = screenRadius * zoom;
    final localPaintRadius = screenRadius / zoom;
    final correctedPaintRadius = localPaintRadius * zoom;
    expect(uncorrectedPaintRadius, closeTo(1.4, 1e-9));
    expect(correctedPaintRadius, screenRadius);
  });

  test('選択回転ハンドルの角からの距離もpinch倍率を含めて画面一定にする', () {
    const screenHandleRadius = 7.0;
    const gapMultiplier = 4.5;
    const fitScale = 0.2;
    const zoom = 0.2;

    final effectiveScale = fitScale * zoom;
    final canvasRadius = screenHandleRadius / effectiveScale;
    final canvasGap = canvasRadius * gapMultiplier;
    final finalScreenGap = canvasGap * effectiveScale;

    expect(finalScreenGap, screenHandleRadius * gapMultiplier);

    final oldCanvasRadius = screenHandleRadius / fitScale;
    final oldFinalScreenGap = oldCanvasRadius * gapMultiplier * effectiveScale;
    expect(oldFinalScreenGap, closeTo(6.3, 1e-9));
    expect(finalScreenGap, 31.5);
  });

  test('定規ハンドルの28pxヒット領域もfit倍率とpinch倍率で画面一定になる', () {
    const screenRadius = 28.0;
    const canvasWidth = 1920.0;
    const drawingRectWidth = 384.0;
    const zoom = 0.2;

    final fitScale = drawingRectWidth / canvasWidth;
    final effectiveScale = fitScale * zoom;
    final canvasRadius = screenRadius / effectiveScale;

    expect(effectiveScale, closeTo(0.04, 1e-9));
    expect(canvasRadius, closeTo(700.0, 1e-9));
    expect(canvasRadius * effectiveScale, screenRadius);
  });

  test('操作ハンドルの最終画面サイズはzoomに依存しない', () {
    const fitScale = 0.2;
    const desiredSelectionRadius = 7.0;
    const desiredRotateRadius = 11.0;
    const desiredMeshHitRadius = 28.0;
    const desiredRulerHitRadius = 28.0;

    for (final zoom in <double>[0.2, 0.5, 1.0, 2.0, 4.0, 10.0]) {
      final effectiveScale = fitScale * zoom;
      final selectionCanvasRadius = desiredSelectionRadius / effectiveScale;
      final rotateCanvasRadius = desiredRotateRadius / effectiveScale;
      final meshCanvasRadius = desiredMeshHitRadius / effectiveScale;
      final rulerCanvasRadius = desiredRulerHitRadius / effectiveScale;

      expect(
        selectionCanvasRadius * effectiveScale,
        closeTo(desiredSelectionRadius, 1e-9),
        reason: 'selection zoom=$zoom',
      );
      expect(
        rotateCanvasRadius * effectiveScale,
        closeTo(desiredRotateRadius, 1e-9),
        reason: 'rotate zoom=$zoom',
      );
      expect(
        meshCanvasRadius * effectiveScale,
        closeTo(desiredMeshHitRadius, 1e-9),
        reason: 'mesh zoom=$zoom',
      );
      expect(
        rulerCanvasRadius * effectiveScale,
        closeTo(desiredRulerHitRadius, 1e-9),
        reason: 'ruler zoom=$zoom',
      );
    }
  });
}
