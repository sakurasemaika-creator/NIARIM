import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/screens/canvas/widgets/canvas_area.dart',
    ).readAsStringSync();
  });

  String methodBody(String signature, String nextMarker) {
    final start = source.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0), reason: '$signature が存在すること');
    final end = source.indexOf(nextMarker, start);
    expect(end, greaterThan(start), reason: '$signature の終端を取得できること');
    return source.substring(start, end);
  }

  test('pointer downは最初に画面座標を共通canvas座標へ変換する', () {
    final body = methodBody(
      'void _onPointerDown(PointerEvent event)',
      '\n  void _onPointerMove(PointerEvent event)',
    );

    expect(
      body,
      contains('final canvasPos = _canvasPosition(event.localPosition);'),
      reason: 'ツール分岐より前に共通の逆Transformを通すこと',
    );
  });

  test('タップ系・選択・図形・移動・メッシュ・定規は共通canvasPosを使う', () {
    final body = methodBody(
      'void _onPointerDown(PointerEvent event)',
      '\n  void _onPointerMove(PointerEvent event)',
    );

    for (final expected in <String>[
      'widget.onTapForText!(canvasPos);',
      '_pickColor(canvasPos);',
      '_beginSelectionTransformIfHit(canvasPos)',
      '_selectionStart = canvasPos;',
      '_lassoPoints = [canvasPos];',
      '_magicWandSelectAt(canvasPos);',
      '_shapeStart = canvasPos;',
      '_moveStart = canvasPos;',
      '_hitTestMeshPoint(canvasPos);',
      '_handleRulerDown(canvasPos)',
      '_handleBucketDown(canvasPos);',
      '_handleFingerDown(canvasPos);',
      '_handleBlurMosaicDown(canvasPos);',
    ]) {
      expect(body, contains(expected), reason: '$expected が共通canvas座標を使うこと');
    }
  });

  test('ドラッグ系ツールも毎moveで共通canvasPosを使う', () {
    final body = methodBody(
      'void _onPointerMove(PointerEvent event)',
      '\n  void _onPointerUp(PointerEvent event)',
    );

    expect(
      body,
      contains('final canvasPos = _canvasPosition(event.localPosition);'),
    );
    for (final expected in <String>[
      '_updateSelectionTransform(canvasPos);',
      '_selectionEnd = canvasPos',
      '_lassoPoints.add(canvasPos)',
      'canvasPos,\n          widget.shapeKind',
      '_moveDelta = canvasPos - _moveStart!',
      'updated[idx] = canvasPos;',
      '_handleRulerMove(canvasPos);',
      '_handleBucketMove(canvasPos);',
      '_subToolStrokePoints.add(canvasPos)',
      '_handleFingerMove(canvasPos);',
      '_handleBlurMosaicMove(canvasPos);',
    ]) {
      expect(body, contains(expected), reason: '$expected が共通canvas座標を使うこと');
    }
  });

  test('ペン・消しゴム・定規描画ストロークは_toCanvasPoint経由で逆Transformする', () {
    final down = methodBody(
      'void _onPointerDown(PointerEvent event)',
      '\n  void _onPointerMove(PointerEvent event)',
    );
    final move = methodBody(
      'void _onPointerMove(PointerEvent event)',
      '\n  void _onPointerUp(PointerEvent event)',
    );

    expect(
      down,
      contains('final point = _toCanvasPoint(_rawToStrokePoint(event));'),
    );
    expect(
      move,
      contains('final point = _toCanvasPoint(_rawToStrokePoint(event));'),
    );
  });

  test('_canvasPositionと_toCanvasPointは同じ逆Transform→fit変換順を維持する', () {
    final toPoint = methodBody(
      'StrokePoint _toCanvasPoint(StrokePoint screen)',
      '\n  Offset _canvasPosition(Offset screenPos)',
    );
    final canvasPosition = methodBody(
      'Offset _canvasPosition(Offset screenPos)',
      '\n\n  // ─── 合成',
    );

    for (final body in <String>[toPoint, canvasPosition]) {
      expect(body, contains('Matrix4.inverted(_transformController.value)'));
      expect(body, contains('MatrixUtils.transformPoint(inv,'));
      expect(body, contains('_widgetLocalToCanvasPixel(local)'));
    }
  });
}
