import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'filter_def.dart';

/// What a filter being edited shows on the canvas to be dragged, in canvas
/// pixels: a centre, and either an ellipse with a handle for each radius
/// (sphere shading's light) or a circle that only shows how far the filter
/// reaches (the fisheye).
@immutable
class FilterCanvasGizmo {
  const FilterCanvasGizmo({
    required this.center,
    this.radiusX,
    this.radiusY,
    this.reach,
  });

  final Offset center;
  final double? radiusX;
  final double? radiusY;
  final double? reach;

  /// Whether the ellipse's radii have handles.
  bool get resizable => radiusX != null && radiusY != null;

  /// The handles and where they are: the centre, and for an ellipse one on
  /// its right edge (width) and one on its bottom edge (height).
  Map<FilterGizmoHandle, Offset> get handles => {
    FilterGizmoHandle.center: center,
    if (resizable) ...{
      FilterGizmoHandle.radiusX: center + Offset(radiusX!, 0),
      FilterGizmoHandle.radiusY: center + Offset(0, radiusY!),
    },
  };

  FilterCanvasGizmo copyWith({
    Offset? center,
    double? radiusX,
    double? radiusY,
  }) => FilterCanvasGizmo(
    center: center ?? this.center,
    radiusX: radiusX ?? this.radiusX,
    radiusY: radiusY ?? this.radiusY,
    reach: reach,
  );

  @override
  bool operator ==(Object other) =>
      other is FilterCanvasGizmo &&
      other.center == center &&
      other.radiusX == radiusX &&
      other.radiusY == radiusY &&
      other.reach == reach;

  @override
  int get hashCode => Object.hash(center, radiusX, radiusY, reach);
}

enum FilterGizmoHandle { center, radiusX, radiusY }

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
