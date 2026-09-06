import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

Project _project({double drawingAreaScale = 1.0}) => Project(
  id: 'rotation-contract',
  name: 'rotation-contract',
  fps: 12,
  durationSeconds: 1,
  backgroundColor: 0xFFFFFFFF,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  totalWorkSeconds: 0,
  exportWidth: 640,
  exportHeight: 480,
  drawingAreaScale: drawingAreaScale,
);

void main() {
  test('拡張描画範囲は書き出し範囲より大きい同一キャンバス座標系になる', () {
    final project = _project(drawingAreaScale: 2.0);
    expect(project.hasExtendedDrawingArea, isTrue);
    expect(project.drawingWidth, 1280);
    expect(project.drawingHeight, 960);

    const viewport = Size(1080, 1920);
    final drawingRect = canvasDrawingRectFor(viewport, project);
    final exportRect = exportWarningRectFor(drawingRect, project);
    expect(exportRect.center, drawingRect.center);
    expect(exportRect.width, closeTo(drawingRect.width / 2, 0.001));
    expect(exportRect.height, closeTo(drawingRect.height / 2, 0.001));
  });

  test('1/5縮小＋複数斜め角度でも拡張描画範囲と書き出し枠は同じ変換へ追従する', () {
    final project = _project(drawingAreaScale: 2.0);
    const viewport = Size(1080, 1920);
    final drawingRect = canvasDrawingRectFor(viewport, project);
    final exportRect = exportWarningRectFor(drawingRect, project);
    final center = drawingRect.center;

    for (final degrees in <double>[30, 45, 60, 90, -30, -45, -60, -90, 135]) {
      final rad = degrees * math.pi / 180.0;
      final candidate = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..rotateZ(rad)
        ..scaleByDouble(kCanvasMinScale, kCanvasMinScale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
      final constrained = constrainCanvasViewTransform(
        viewport,
        drawingRect,
        candidate,
      );
      final transformedDrawing = MatrixUtils.transformRect(constrained, drawingRect);
      final transformedExport = MatrixUtils.transformRect(constrained, exportRect);

      expect(
        transformedDrawing.contains(transformedExport.center),
        isTrue,
        reason: '$degrees° export center must remain inside extended drawing area',
      );
      expect(transformedExport.width, lessThanOrEqualTo(transformedDrawing.width));
      expect(transformedExport.height, lessThanOrEqualTo(transformedDrawing.height));
      expect(transformedDrawing.left, greaterThanOrEqualTo(-0.001));
      expect(transformedDrawing.top, greaterThanOrEqualTo(-0.001));
      expect(transformedDrawing.right, lessThanOrEqualTo(viewport.width + 0.001));
      expect(transformedDrawing.bottom, lessThanOrEqualTo(viewport.height + 0.001));
    }
  });

  test('通常/拡張の1/5縮小＋斜め回転後も極端なパンは背景端を越えない', () {
    const viewport = Size(1080, 1920);

    for (final drawingAreaScale in <double>[1.0, 2.0]) {
      final project = _project(drawingAreaScale: drawingAreaScale);
      final drawingRect = canvasDrawingRectFor(viewport, project);
      final center = drawingRect.center;

      for (final degrees in <double>[30, 45, 60, 90, -30, -45, -60, -90]) {
        final rad = degrees * math.pi / 180.0;
        final rotated = Matrix4.identity()
          ..translateByDouble(center.dx, center.dy, 0, 1)
          ..rotateZ(rad)
          ..scaleByDouble(kCanvasMinScale, kCanvasMinScale, 1, 1)
          ..translateByDouble(-center.dx, -center.dy, 0, 1);

        for (final delta in <Offset>[
          const Offset(100000, 0),
          const Offset(-100000, 0),
          const Offset(0, 100000),
          const Offset(0, -100000),
          const Offset(100000, 100000),
          const Offset(-100000, -100000),
          const Offset(100000, -100000),
          const Offset(-100000, 100000),
        ]) {
          final moved =
              (Matrix4.identity()
                    ..translateByDouble(delta.dx, delta.dy, 0, 1)) *
              rotated;
          final constrained = constrainCanvasViewTransform(
            viewport,
            drawingRect,
            moved,
          );
          final bounds = MatrixUtils.transformRect(constrained, drawingRect);
          expect(
            bounds.left,
            greaterThanOrEqualTo(-0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta left',
          );
          expect(
            bounds.top,
            greaterThanOrEqualTo(-0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta top',
          );
          expect(
            bounds.right,
            lessThanOrEqualTo(viewport.width + 0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta right',
          );
          expect(
            bounds.bottom,
            lessThanOrEqualTo(viewport.height + 0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta bottom',
          );
        }
      }
    }
  });

  test('拡大＋斜め回転後は通常/拡張とも極端パンしても反対側から背景が露出しない', () {
    const viewport = Size(1080, 1920);

    for (final drawingAreaScale in <double>[1.0, 2.0]) {
      final project = _project(drawingAreaScale: drawingAreaScale);
      final drawingRect = canvasDrawingRectFor(viewport, project);
      final center = drawingRect.center;

      for (final degrees in <double>[30, 45, 60, -30, -45, -60]) {
        final rad = degrees * math.pi / 180.0;
        final rotated = Matrix4.identity()
          ..translateByDouble(center.dx, center.dy, 0, 1)
          ..rotateZ(rad)
          ..scaleByDouble(4, 4, 1, 1)
          ..translateByDouble(-center.dx, -center.dy, 0, 1);

        for (final delta in <Offset>[
          const Offset(100000, 100000),
          const Offset(-100000, -100000),
          const Offset(100000, -100000),
          const Offset(-100000, 100000),
        ]) {
          final moved =
              (Matrix4.identity()
                    ..translateByDouble(delta.dx, delta.dy, 0, 1)) *
              rotated;
          final constrained = constrainCanvasViewTransform(
            viewport,
            drawingRect,
            moved,
          );
          final bounds = MatrixUtils.transformRect(constrained, drawingRect);

          expect(
            bounds.left,
            lessThanOrEqualTo(0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta must cover left',
          );
          expect(
            bounds.right,
            greaterThanOrEqualTo(viewport.width - 0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta must cover right',
          );

          // 4倍では4:3キャンバスの回転外接矩形が縦にもviewportを覆う。
          expect(
            bounds.top,
            lessThanOrEqualTo(0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta must cover top',
          );
          expect(
            bounds.bottom,
            greaterThanOrEqualTo(viewport.height - 0.001),
            reason: 'scale=$drawingAreaScale $degrees° $delta must cover bottom',
          );
        }
      }
    }
  });
}
