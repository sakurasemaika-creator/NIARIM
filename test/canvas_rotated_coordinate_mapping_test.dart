import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

Project _project({double drawingAreaScale = 1.0}) => Project(
  id: 'rotated-coordinate-mapping',
  name: 'rotated-coordinate-mapping',
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

/// CanvasAreaの実装と同じ順序で、プロジェクトpxを変形前widget座標へ直す。
Offset _canvasPixelToWidget(Offset canvasPx, Size viewport, Project project) {
  final rect = canvasDrawingRectFor(viewport, project);
  final canvasSize = canvasPixelSizeOf(project);
  return Offset(
    rect.left + canvasPx.dx * rect.width / canvasSize.width,
    rect.top + canvasPx.dy * rect.height / canvasSize.height,
  );
}

/// _CanvasAreaState._canvasPositionと同じ計算。
/// screen -> viewTransform逆行列 -> widgetLocal -> project px。
Offset _screenToCanvasPixel(
  Offset screen,
  Size viewport,
  Project project,
  Matrix4 viewTransform,
) {
  final inverse = Matrix4.copy(viewTransform);
  expect(inverse.invert(), isNot(0));
  final widgetLocal = MatrixUtils.transformPoint(inverse, screen);
  final rect = canvasDrawingRectFor(viewport, project);
  final canvasSize = canvasPixelSizeOf(project);
  return Offset(
    (widgetLocal.dx - rect.left) * canvasSize.width / rect.width,
    (widgetLocal.dy - rect.top) * canvasSize.height / rect.height,
  );
}

Matrix4 _viewFor(
  Size viewport,
  Project project,
  double degrees, {
  double scale = kCanvasMinScale,
  Offset pan = Offset.zero,
}) {
  final rect = canvasDrawingRectFor(viewport, project);
  final c = rect.center;
  final radians = degrees * math.pi / 180;
  final candidate =
      (Matrix4.identity()..translateByDouble(pan.dx, pan.dy, 0, 1)) *
      (Matrix4.identity()
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..rotateZ(radians)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-c.dx, -c.dy, 0, 1));
  return constrainCanvasViewTransform(viewport, rect, candidate);
}

void main() {
  const viewport = Size(420, 520);
  const angles = <double>[30, 45, 60, 90, -30, -45, -60, -90, 135];
  const pans = <Offset>[
    Offset.zero,
    Offset(5000, 0),
    Offset(-5000, 0),
    Offset(0, 5000),
    Offset(0, -5000),
    Offset(5000, 5000),
    Offset(-5000, -5000),
  ];

  for (final drawingAreaScale in <double>[1.0, 2.0]) {
    final mode = drawingAreaScale == 1.0 ? '通常' : '拡張';

    test('$mode: 1/100縮小＋斜め回転＋極端パンでも画面→キャンバス座標が往復一致する', () {
      final project = _project(drawingAreaScale: drawingAreaScale);
      final canvasSize = canvasPixelSizeOf(project);
      final points = <Offset>[
        Offset.zero,
        Offset(canvasSize.width, 0),
        Offset(0, canvasSize.height),
        Offset(canvasSize.width, canvasSize.height),
        Offset(canvasSize.width / 2, canvasSize.height / 2),
        Offset(canvasSize.width * 0.23, canvasSize.height * 0.71),
      ];

      for (final degrees in angles) {
        for (final pan in pans) {
          final view = _viewFor(viewport, project, degrees, pan: pan);
          for (final original in points) {
            final widgetLocal = _canvasPixelToWidget(
              original,
              viewport,
              project,
            );
            final screen = MatrixUtils.transformPoint(view, widgetLocal);
            final recovered = _screenToCanvasPixel(
              screen,
              viewport,
              project,
              view,
            );
            expect(
              recovered.dx,
              closeTo(original.dx, 0.001),
              reason: '$mode $degrees° $pan x: $original',
            );
            expect(
              recovered.dy,
              closeTo(original.dy, 0.001),
              reason: '$mode $degrees° $pan y: $original',
            );
          }
        }
      }
    });

    test('$mode: 4倍拡大＋斜め回転でも座標変換が一致する', () {
      final project = _project(drawingAreaScale: drawingAreaScale);
      final canvasSize = canvasPixelSizeOf(project);
      final probes = <Offset>[
        Offset(canvasSize.width * 0.1, canvasSize.height * 0.1),
        Offset(canvasSize.width * 0.5, canvasSize.height * 0.5),
        Offset(canvasSize.width * 0.9, canvasSize.height * 0.8),
      ];

      for (final degrees in <double>[30, 45, -45, 60, -60]) {
        final view = _viewFor(
          viewport,
          project,
          degrees,
          scale: 4.0,
          pan: const Offset(100000, -100000),
        );
        for (final original in probes) {
          final local = _canvasPixelToWidget(original, viewport, project);
          final screen = MatrixUtils.transformPoint(view, local);
          final recovered = _screenToCanvasPixel(
            screen,
            viewport,
            project,
            view,
          );
          expect(recovered.dx, closeTo(original.dx, 0.001));
          expect(recovered.dy, closeTo(original.dy, 0.001));
        }
      }
    });
  }

  test('選択ハンドルは0.01倍でも画面上の見た目サイズが一定になる', () {
    // canvasToScreenScaleが1/100になるとキャンバスpx上の半径は100倍になり、
    // Transform後の画面pxでは元の7px / 11pxへ戻る。
    final scaleRadius = selectionHandleRadiusFor(kCanvasMinScale);
    final rotateRadius = selectionRotateHandleRadiusFor(kCanvasMinScale);
    expect(
      scaleRadius * kCanvasMinScale,
      closeTo(kSelectionHandleScreenRadius, 0.001),
    );
    expect(
      rotateRadius * kCanvasMinScale,
      closeTo(kSelectionRotateHandleScreenRadius, 0.001),
    );
  });

  test('選択回転ハンドルは斜め表示でも拡大縮小ハンドルと重ならない', () {
    const bounds = Rect.fromLTWH(100, 100, 220, 140);
    final handle = selectionHandleRadiusFor(kCanvasMinScale);
    final rotate = selectionRotateHandleRadiusFor(kCanvasMinScale);
    final rotatePoint = selectionRotateHandleOf(
      bounds,
      handle,
      rotateRadius: rotate,
      // 1/100では画面サイズ固定のハンドル半径がcanvas座標上で100倍になる。
      // 旧1/5向けの3000px枠では境界クランプ自体を測ってしまうため、
      // 非クランプ時の「四隅と重ならない」性質を十分広い領域で監査する。
      reachable: const Rect.fromLTWH(-5000, -5000, 10000, 10000),
    );
    for (final scalePoint in selectionScaleHandlesOf(bounds)) {
      expect(
        (rotatePoint - scalePoint).distance,
        greaterThan(handle + rotate),
        reason: '0.01倍でも回転ハンドルが四隅ハンドルと重ならないこと',
      );
    }
  });
}
