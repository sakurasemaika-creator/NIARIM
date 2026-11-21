import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

Rect transformed(Rect rect, Matrix4 matrix) =>
    MatrixUtils.transformRect(matrix, rect);

void main() {
  const viewport = Size(1000, 700);
  const drawing = Rect.fromLTWH(100, 100, 800, 500);

  group('キャンバス背景端のパン制限', () {
    test('縮小キャンバスは背景の右端より先へドラッグできない', () {
      final candidate = Matrix4.identity()
        ..scaleByDouble(0.5, 0.5, 1, 1)
        ..translateByDouble(2000, 0, 0, 1);
      final fixed = constrainCanvasViewTransform(viewport, drawing, candidate);
      final b = transformed(drawing, fixed);
      expect(b.right, lessThanOrEqualTo(viewport.width + 1e-6));
      expect(b.left, greaterThanOrEqualTo(-1e-6));
    });

    test('縮小キャンバスは背景の左上端より先へドラッグできない', () {
      final candidate = Matrix4.identity()
        ..scaleByDouble(0.2, 0.2, 1, 1)
        ..translateByDouble(-5000, -5000, 0, 1);
      final fixed = constrainCanvasViewTransform(viewport, drawing, candidate);
      final b = transformed(drawing, fixed);
      expect(b.left, greaterThanOrEqualTo(-1e-6));
      expect(b.top, greaterThanOrEqualTo(-1e-6));
    });

    test('回転＋最小倍率でも外接矩形は背景からはみ出さない', () {
      final candidate = Matrix4.identity()
        ..translateByDouble(900, 600, 0, 1)
        ..rotateZ(0.7)
        ..scaleByDouble(kCanvasMinScale, kCanvasMinScale, 1, 1);
      final fixed = constrainCanvasViewTransform(viewport, drawing, candidate);
      final b = transformed(drawing, fixed);
      expect(b.left, greaterThanOrEqualTo(-1e-6));
      expect(b.top, greaterThanOrEqualTo(-1e-6));
      expect(b.right, lessThanOrEqualTo(viewport.width + 1e-6));
      expect(b.bottom, lessThanOrEqualTo(viewport.height + 1e-6));
    });

    test('拡大キャンバスは反対側の端まで抜けられない', () {
      final candidate = Matrix4.identity()
        ..scaleByDouble(2, 2, 1, 1)
        ..translateByDouble(2000, 1500, 0, 1);
      final fixed = constrainCanvasViewTransform(viewport, drawing, candidate);
      final b = transformed(drawing, fixed);
      expect(b.left, lessThanOrEqualTo(1e-6));
      expect(b.right, greaterThanOrEqualTo(viewport.width - 1e-6));
      expect(b.top, lessThanOrEqualTo(1e-6));
      expect(b.bottom, greaterThanOrEqualTo(viewport.height - 1e-6));
    });
  });
}
