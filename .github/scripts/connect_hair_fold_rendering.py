from pathlib import Path

path = Path('lib/engine/drawing_engine.dart')
s = path.read_text()

anchor = "import 'brush_stroke_geometry.dart';\n"
imports = "import 'brush_stroke_geometry.dart';\nimport 'hair_fold_render_resolver.dart';\nimport 'wave_hair_fold_geometry.dart';\n"
if "import 'hair_fold_render_resolver.dart';" not in s:
    if anchor not in s:
        raise SystemExit('brush geometry import anchor not found')
    s = s.replace(anchor, imports, 1)

constructor = "  DrawingEngine({required this.tileManager});\n"
resolver = r'''
  /// Test-visible production resolver. Keeping the selection here guarantees
  /// that the same Straight/Wave contract used by rendering is independently
  /// verifiable without rasterizing a full tile.
  static List<WaveFoldPathSample> debugResolveHairFoldPath({
    required FoldEvent event,
    required bool waveEnabled,
    required double curveStartRatio,
    required double depthRatio,
    required double lengthRatio,
    required double waveEndRatio,
    required double waveTriggerAngleDegrees,
    double taperRatio = .35,
    double outlineWidth = 1,
  }) {
    return resolveHairFoldRenderPath(
      event: event,
      waveEnabled: waveEnabled,
      curveStartRatio: curveStartRatio,
      depthRatio: depthRatio,
      lengthRatio: lengthRatio,
      waveEndRatio: waveEndRatio,
      waveTriggerAngleDegrees: waveTriggerAngleDegrees,
      taperRatio: taperRatio,
      outlineWidth: outlineWidth,
    );
  }
'''
if 'debugResolveHairFoldPath' not in s:
    if constructor not in s:
        raise SystemExit('DrawingEngine constructor anchor not found')
    s = s.replace(constructor, constructor + resolver, 1)

old = r'''    final branches = buildFoldY(
      event,
      branchAngleDegrees: brush.yBranchAngle,
      lengthRatio: brush.yBranchLengthRatio,
      widthRatio: brush.yBranchWidthRatio,
      taperRatio: brush.yBranchEndTaperRatio,
    );
    for (final branch in branches) {
      _renderFoldBranch(branch, layerId, ui.Color(brush.outlineColor));
    }
  }

  void _renderFoldBranch(FoldBranch branch, String layerId, ui.Color color) {
    final delta = branch.end - branch.start;
    final length = delta.distance;
    if (!length.isFinite || length <= 1e-9) return;
    final steps = math.max(1, length.ceil());
    const identityTilt = (scaleX: 1.0, scaleY: 1.0, angle: 0.0);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final center = branch.start + delta * t;
      final width = branch.widthAt(t);
      if (width <= 0.05) continue;
      _renderCircleStamp(
        center.dx,
        center.dy,
        width / 2,
        255,
        identityTilt,
        layerId,
        false,
        0,
        null,
        colorOverride: color,
        coverageNamespace: 'fold',
      );
    }
  }
'''
new = r'''    final path = debugResolveHairFoldPath(
      event: event,
      waveEnabled: brush.foldWaveEnabled,
      curveStartRatio: brush.foldCurveStartRatio,
      depthRatio: brush.foldDepthRatio,
      lengthRatio: brush.foldLengthRatio,
      waveEndRatio: brush.foldWaveEndRatio,
      waveTriggerAngleDegrees: brush.foldWaveTriggerAngle,
      taperRatio: brush.foldEndTaperRatio,
      outlineWidth: brush.outlineWidth,
    );
    _renderHairFoldPath(path, layerId, ui.Color(brush.outlineColor));
  }

  void _renderHairFoldPath(
    List<WaveFoldPathSample> path,
    String layerId,
    ui.Color color,
  ) {
    if (path.isEmpty) return;
    const identityTilt = (scaleX: 1.0, scaleY: 1.0, angle: 0.0);

    void stamp(ui.Offset center, double width) {
      if (!width.isFinite || width <= 0.05) return;
      _renderCircleStamp(
        center.dx,
        center.dy,
        width / 2,
        255,
        identityTilt,
        layerId,
        false,
        0,
        null,
        colorOverride: color,
        coverageNamespace: 'fold',
      );
    }

    stamp(path.first.position, path.first.width);
    for (var i = 1; i < path.length; i++) {
      final from = path[i - 1];
      final to = path[i];
      final delta = to.position - from.position;
      final length = delta.distance;
      if (!length.isFinite || length <= 1e-9) {
        stamp(to.position, to.width);
        continue;
      }
      // Interpolate at <=1 document-pixel intervals so tight crescent turns do
      // not develop stamp holes. This touches only the local fold path, never
      // scans the canvas, and remains bounded by the fixed geometry sample cap.
      final steps = math.max(1, length.ceil());
      for (var step = 1; step <= steps; step++) {
        final t = step / steps;
        final center = from.position + delta * t;
        final width = from.width + (to.width - from.width) * t;
        stamp(center, width);
      }
    }
  }
'''
if '_renderHairFoldPath(' not in s:
    if old not in s:
        raise SystemExit('legacy fold renderer block not found')
    s = s.replace(old, new, 1)

path.write_text(s)
