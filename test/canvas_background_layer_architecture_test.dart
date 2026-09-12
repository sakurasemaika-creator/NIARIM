import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('固定安全背景はCanvasAreaの外側に置き、CanvasAreaと一緒に回転させない', () {
    final screen = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('backgroundColor: kCanvasOutsideColor'));
    expect(screen, contains('color: kCanvasOutsideColor'));
    expect(screen, contains('CanvasArea('));

    final colorIndex = screen.indexOf('color: kCanvasOutsideColor');
    final canvasIndex = screen.indexOf('CanvasArea(', colorIndex);
    expect(colorIndex, greaterThanOrEqualTo(0));
    expect(canvasIndex, greaterThan(colorIndex));
  });

  test('CanvasAreaは固定背景を二重描画せず、描画矩形だけをTransform内で描く', () {
    final area = File(
      'lib/screens/canvas/widgets/canvas_area.dart',
    ).readAsStringSync();

    expect(area, contains('child: Transform('));
    expect(area, contains('transform: _transformController.value'));
    expect(area, contains('_paintBackground(canvas, drawingRect);'));
    expect(
      area,
      contains('親の固定背景をそのまま透過させる'),
      reason: '安全背景はTransform外、描画可能領域だけが回転する二層構造を維持する',
    );
  });

  test('拡張描画範囲は実描画pxを拡張し、書き出し枠だけ中央1/倍率になる', () {
    final area = File(
      'lib/screens/canvas/widgets/canvas_area.dart',
    ).readAsStringSync();

    expect(area, contains('(project?.drawingWidth ?? 1920).toDouble()'));
    expect(area, contains('(project?.drawingHeight ?? 1080).toDouble()'));
    expect(area, contains('final w = drawingRect.width / scale;'));
    expect(area, contains('final h = drawingRect.height / scale;'));
    expect(
      area,
      contains(
        'Rect.fromCenter(center: drawingRect.center, width: w, height: h)',
      ),
    );
  });
}
