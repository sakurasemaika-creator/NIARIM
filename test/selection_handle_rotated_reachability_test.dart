import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

Project _project({double drawingAreaScale = 1.0}) => Project(
      id: 'selection-handle-reachability',
      name: 'selection-handle-reachability',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      totalWorkSeconds: 0,
      exportWidth: 640,
      exportHeight: 360,
      drawingAreaScale: drawingAreaScale,
    );

Matrix4 _view(Size viewport, Project project, double degrees) {
  final rect = canvasDrawingRectFor(viewport, project);
  final c = rect.center;
  final radians = degrees * math.pi / 180;
  final candidate = Matrix4.identity()
    ..translateByDouble(c.dx, c.dy, 0, 1)
    ..rotateZ(radians)
    ..scaleByDouble(kCanvasMinScale, kCanvasMinScale, 1, 1)
    ..translateByDouble(-c.dx, -c.dy, 0, 1);
  return constrainCanvasViewTransform(viewport, rect, candidate);
}

void main() {
  const viewport = Size(420, 520);

  for (final drawingAreaScale in <double>[1.0, 2.0]) {
    final mode = drawingAreaScale == 1.0 ? '通常' : '拡張';

    test('$mode: 0.2倍＋斜め回転でも選択回転ハンドルを到達可能範囲へ寄せられる', () {
      final project = _project(drawingAreaScale: drawingAreaScale);
      final canvasSize = canvasPixelSizeOf(project);
      final selection = Rect.fromLTWH(
        0,
        0,
        canvasSize.width,
        canvasSize.height,
      );

      for (final degrees in <double>[30, 45, 60, 90, -30, -45, -60, -90]) {
        final view = _view(viewport, project, degrees);
        final visibleWidget = visibleWidgetRectFor(viewport, view);
        final drawingRect = canvasDrawingRectFor(viewport, project);
        final reachable = reachableCanvasRectFor(
          visibleWidget,
          drawingRect,
          project,
        );

        final fitScale = drawingRect.width / canvasSize.width;
        final canvasToScreenScale = fitScale * kCanvasMinScale;
        final handleRadius = selectionHandleRadiusFor(canvasToScreenScale);
        final rotateRadius = selectionRotateHandleRadiusFor(canvasToScreenScale);
        final rotatePoint = selectionRotateHandleOf(
          selection,
          handleRadius,
          rotateRadius: rotateRadius,
          reachable: reachable,
        );

        expect(
          rotatePoint.dx,
          greaterThanOrEqualTo(reachable.left + rotateRadius - 0.001),
          reason: '$mode $degrees° left',
        );
        expect(
          rotatePoint.dx,
          lessThanOrEqualTo(reachable.right - rotateRadius + 0.001),
          reason: '$mode $degrees° right',
        );
        // 上方向へ意図的に選択範囲外へ出すケースではreachable.topより外になる
        // ことを許す設計だが、その場合でも四隅ハンドルとは重ならないことを確認する。
        for (final scalePoint in selectionScaleHandlesOf(selection)) {
          expect(
            (rotatePoint - scalePoint).distance,
            greaterThan(handleRadius + rotateRadius),
            reason: '$mode $degrees° scale/rotate handles must not overlap',
          );
        }
      }
    });
  }
}
