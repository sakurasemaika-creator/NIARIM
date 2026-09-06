import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('メッシュ格子点の当たり判定はフィット倍率込みのcanvas-to-screen倍率を使う', () {
    final source = File(
      'lib/screens/canvas/widgets/canvas_area.dart',
    ).readAsStringSync();
    final start = source.indexOf('int? _hitTestMeshPoint');
    expect(start, greaterThanOrEqualTo(0));
    final end = source.indexOf('\n  /// 確定', start);
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(
      body,
      contains('final scale = _canvasToScreenScale;'),
      reason: 'project px→widget pxのfit倍率とpinch倍率の両方を含めること',
    );
    expect(
      body,
      isNot(contains('getMaxScaleOnAxis()')),
      reason: 'pinch倍率だけでは高解像度キャンバスでヒット半径が小さくなりすぎる',
    );
  });

  test('fit倍率を無視すると0.2倍表示時の28pxヒット領域が半分になる例を固定する', () {
    const screenRadius = 28.0;
    const canvasWidth = 640.0;
    const drawingRectWidth = 320.0;
    const zoom = 0.2;

    final fitScale = drawingRectWidth / canvasWidth;
    final correctCanvasRadius = screenRadius / (fitScale * zoom);
    final zoomOnlyRadius = screenRadius / zoom;

    expect(correctCanvasRadius, 280.0);
    expect(zoomOnlyRadius, 140.0);
    expect(correctCanvasRadius * fitScale * zoom, screenRadius);
  });
}
