import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'filter_def.dart';

/// What a filter being edited shows on the canvas to be dragged, in canvas
/// pixels: a centre, and either an ellipse with a handle for each radius
/// (sphere shading's light) or a circle with a handle for how far the
/// filter reaches (the fisheye).
@immutable
class FilterCanvasGizmo {
  const FilterCanvasGizmo({
    required this.center,
    this.radiusX,
    this.radiusY,
    this.reach,
    this.reachAngle = 0,
  });

  final Offset center;
  final double? radiusX;
  final double? radiusY;
  final double? reach;

  /// Where on the reach circle its handle sits, in radians clockwise from
  /// the right. Only where the handle is drawn: any point of the circle
  /// sets the same radius, so the canvas moves it to one the finger can
  /// reach ([reachHandleAngleWithin]).
  final double reachAngle;

  /// Whether the ellipse's radii have handles.
  bool get resizable => radiusX != null && radiusY != null;

  /// The handles and where they are: the centre, for an ellipse one on its
  /// right edge (width) and one on its bottom edge (height), and for a
  /// reach circle one on it at [reachAngle] (radius).
  Map<FilterGizmoHandle, Offset> get handles => {
    FilterGizmoHandle.center: center,
    if (resizable) ...{
      FilterGizmoHandle.radiusX: center + Offset(radiusX!, 0),
      FilterGizmoHandle.radiusY: center + Offset(0, radiusY!),
    },
    if (reach != null)
      FilterGizmoHandle.reach:
          center + Offset.fromDirection(reachAngle, reach!),
  };

  FilterCanvasGizmo copyWith({
    Offset? center,
    double? radiusX,
    double? radiusY,
    double? reach,
    double? reachAngle,
  }) => FilterCanvasGizmo(
    center: center ?? this.center,
    radiusX: radiusX ?? this.radiusX,
    radiusY: radiusY ?? this.radiusY,
    reach: reach ?? this.reach,
    reachAngle: reachAngle ?? this.reachAngle,
  );

  @override
  bool operator ==(Object other) =>
      other is FilterCanvasGizmo &&
      other.center == center &&
      other.radiusX == radiusX &&
      other.radiusY == radiusY &&
      other.reach == reach &&
      other.reachAngle == reachAngle;

  @override
  int get hashCode => Object.hash(center, radiusX, radiusY, reach, reachAngle);
}

/// Where on [gizmo]'s reach circle to put its handle so that it is inside
/// [bounds] (what the finger can reach, in canvas pixels): [preferred]
/// while that is inside, otherwise the inside point nearest the right of
/// the circle. A large reach runs off the screen on the right (at 100 % it
/// is the canvas's half-diagonal), where a handle could not be grabbed.
/// Falls back to [preferred] (or the right) when no point of the circle is
/// inside.
double reachHandleAngleWithin(
  FilterCanvasGizmo gizmo,
  Rect bounds, {
  double? preferred,
}) {
  final reach = gizmo.reach;
  if (reach == null) return preferred ?? 0;
  bool inside(double angle) =>
      bounds.contains(gizmo.center + Offset.fromDirection(angle, reach));
  if (preferred != null && inside(preferred)) return preferred;
  const steps = 72;
  for (var i = 0; i <= steps / 2; i++) {
    for (final sign in const [-1, 1]) {
      final angle = sign * i * 2 * math.pi / steps;
      if (inside(angle)) return angle;
    }
  }
  return preferred ?? 0;
}

enum FilterGizmoHandle { center, radiusX, radiusY, reach }

/// Whether a filter of this kind has something to drag on the canvas.
bool filterHasCanvasGizmo(FilterKind kind) =>
    kind == FilterKind.sphereShading || kind == FilterKind.fisheye;

/// The gizmo [filter] shows on a canvas of this size, or null for a filter
/// that has nothing to drag on the canvas.
FilterCanvasGizmo? filterCanvasGizmoFor(
  FilterDef filter,
  int width,
  int height,
) {
  switch (filter.kind) {
    case FilterKind.sphereShading:
      final light = filter.sphereLight(width, height);
      return FilterCanvasGizmo(
        center: Offset(light.centerX, light.centerY),
        radiusX: light.radiusX,
        radiusY: light.radiusY,
      );
    case FilterKind.fisheye:
      final center = filter.fisheyeCenter(width, height);
      final halfDiagonal = math.sqrt(width * width + height * height) / 2;
      return FilterCanvasGizmo(
        center: Offset(center.x, center.y),
        reach: halfDiagonal * filter.fisheyeRadius.clamp(1, 100) / 100,
      );
    default:
      return null;
  }
}
