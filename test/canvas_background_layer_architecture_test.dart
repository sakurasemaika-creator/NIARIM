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

    // キャンバス本体（CanvasArea）は`canvasView`として1度だけ作り、スマホでは
    // 画面いっぱいの層、PC/DeXではドックの間に、どちらも固定背景の上へ置く
    // （2026-11-27、スマホのキャンバスを画面いっぱいにした）。
    expect(screen, contains('final canvasView = Listener('));
    final viewIndex = screen.indexOf('final canvasView = Listener(');
    expect(screen.indexOf('CanvasArea(', viewIndex), greaterThan(viewIndex));
    for (final background in [
      'ColoredBox(color: kCanvasOutsideColor)',
      'Container(color: kCanvasOutsideColor)',
    ]) {
      final colorIndex = screen.indexOf(background);
      expect(colorIndex, greaterThanOrEqualTo(0), reason: background);
      expect(
        screen.indexOf('canvasView', colorIndex),
        greaterThan(colorIndex),
        reason: 'the canvas is placed on top of $background',
      );
    }
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
