from pathlib import Path

p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()
if "import 'brush_render_plan.dart';" not in s:
    s = s.replace("import 'brush_texture_cache.dart';\n", "import 'brush_texture_cache.dart';\nimport 'brush_render_plan.dart';\n")
if "import 'brush_stroke_geometry.dart';" not in s:
    s = s.replace("import 'brush_render_plan.dart';\n", "import 'brush_render_plan.dart';\nimport 'brush_stroke_geometry.dart';\n")

field_marker = "  math.Random _scatterRng = math.Random(0);\n"
if "ScreenSpaceFoldDetector? _foldDetector;" not in s:
    s = s.replace(field_marker, field_marker + "  ScreenSpaceFoldDetector? _foldDetector;\n")

begin_marker = "    _scatterRng = math.Random(0);\n    _currentStroke.add(effective);"
begin_replacement = """    _scatterRng = math.Random(0);
    final brush = currentBrush;
    _foldDetector = brush != null && brush.outlineEnabled && brush.foldEnabled
        ? ScreenSpaceFoldDetector(triggerAngleDegrees: brush.foldTriggerAngle)
        : null;
    _feedFoldDetector(effective, layerId);
    _currentStroke.add(effective);"""
if begin_marker in s:
    s = s.replace(begin_marker, begin_replacement, 1)

# beginStroke already declares brush immediately after the insertion point.
s = s.replace("    final brush = currentBrush;\n    final needsDirection =\n", "    final needsDirection =\n", 1)

continue_marker = "    _renderStrokeSegment(from, effective, layerId);\n    _currentStroke.add(effective);"
continue_replacement = """    _renderStrokeSegment(from, effective, layerId);
    _feedFoldDetector(effective, layerId);
    _currentStroke.add(effective);"""
if continue_marker in s:
    s = s.replace(continue_marker, continue_replacement, 1)

end_marker = "    _hasStampedCurrentStroke = false;\n  }\n\n  StrokePoint _applyPointConstraint"
end_replacement = """    _hasStampedCurrentStroke = false;
    _foldDetector = null;
  }

  void _feedFoldDetector(StrokePoint point, String layerId) {
    final detector = _foldDetector;
    final brush = currentBrush;
    if (detector == null || brush == null || !brush.outlineEnabled || !brush.foldEnabled) return;
    final resolved = resolveBrushPressure(
      brush: brush,
      pressureEnabled: pressureEnabled,
      curvedPressure: point.pressure,
    );
    final effectiveWidth = (brush.size * resolved.sizeScale).clamp(0.5, 2000.0).toDouble();
    final event = detector.add(BrushStrokeSample(
      // DrawingEngine accepts document coordinates. Canvas may supply a
      // screen-space mapper separately; at 1x these coordinates are identical.
      screenPosition: ui.Offset(point.x, point.y),
      documentPosition: ui.Offset(point.x, point.y),
      effectiveWidth: effectiveWidth,
    ));
    if (event == null) return;
    final branches = buildFoldY(
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

  StrokePoint _applyPointConstraint"""
if end_marker in s:
    s = s.replace(end_marker, end_replacement, 1)
elif "void _feedFoldDetector(" not in s:
    raise SystemExit('fold helper insertion marker not found')

old_call = '''    _renderCircleStamp(
      stampX,
      stampY,
      radius,
      alphaInt,
      tilt,
      layerId,
      brush.pixelMode,
      resolvedPressure.blur,
      customTexture,
      stylusTiltMagnitude: stylusTiltMagnitude,
      edgeJitter: resolvedPressure.edgeJitterEnabled,
      edgeJitterStrength: resolvedPressure.edgeJitterStrength,
      mixingMode: resolvedPressure.mixingMode,
      mixingRate: resolvedPressure.mixingRate,
      hexagon: isGlitterHexagon,
      particleRotation: particleRotation,
      chainLink: isChainLink,
      chainAspect: chainAspect,
      chainThickness: chainThickness,
      ballChain: isBallChain,
    );'''
new_call = '''    final extensionPlan = buildBrushStampPlan(
      brush: brush,
      center: ui.Offset(stampX, stampY),
      pathAngle: pathAngle,
      effectiveSize: size,
    );
    final usesExtensionRaster = brush.lateralRepeatEnabled ||
        brush.outlineEnabled || extensionPlan.hollowSquare;
    final centers = usesExtensionRaster
        ? extensionPlan.centers
        : <ui.Offset>[ui.Offset(stampX, stampY)];
    for (final center in centers) {
      final outlineRadius = extensionPlan.outlineRadius;
      if (usesExtensionRaster && outlineRadius != null) {
        _renderCircleStamp(
          center.dx, center.dy, outlineRadius, alphaInt, tilt, layerId,
          brush.pixelMode, resolvedPressure.blur, customTexture,
          stylusTiltMagnitude: stylusTiltMagnitude,
          edgeJitter: resolvedPressure.edgeJitterEnabled,
          edgeJitterStrength: resolvedPressure.edgeJitterStrength,
          mixingMode: resolvedPressure.mixingMode,
          mixingRate: resolvedPressure.mixingRate,
          hexagon: isGlitterHexagon,
          particleRotation: particleRotation,
          chainLink: isChainLink,
          chainAspect: chainAspect,
          chainThickness: chainThickness,
          ballChain: isBallChain,
          hollowSquare: extensionPlan.hollowSquare,
          hollowSquareInnerRatio: extensionPlan.hollowSquareInnerRatio,
          colorOverride: ui.Color(brush.outlineColor),
          coverageNamespace: 'outline',
        );
      }
      _renderCircleStamp(
        center.dx, center.dy, extensionPlan.fillRadius, alphaInt, tilt, layerId,
        brush.pixelMode, resolvedPressure.blur, customTexture,
        stylusTiltMagnitude: stylusTiltMagnitude,
        edgeJitter: resolvedPressure.edgeJitterEnabled,
        edgeJitterStrength: resolvedPressure.edgeJitterStrength,
        mixingMode: resolvedPressure.mixingMode,
        mixingRate: resolvedPressure.mixingRate,
        hexagon: isGlitterHexagon,
        particleRotation: particleRotation,
        chainLink: isChainLink,
        chainAspect: chainAspect,
        chainThickness: chainThickness,
        ballChain: isBallChain,
        hollowSquare: usesExtensionRaster && extensionPlan.hollowSquare,
        hollowSquareInnerRatio: extensionPlan.hollowSquareInnerRatio,
        coverageNamespace: usesExtensionRaster ? 'fill' : 'legacy',
      );
    }'''
if old_call in s:
    s = s.replace(old_call, new_call, 1)
elif 'final extensionPlan = buildBrushStampPlan(' not in s:
    raise SystemExit('render call marker not found')

s = s.replace('    final radius = size / 2;\n', '', 1)

old_sig = '''    bool ballChain = false,
  }) {
    final r = currentColor.r;
    final g = currentColor.g;
    final b = currentColor.b;'''
new_sig = '''    bool ballChain = false,
    bool hollowSquare = false,
    double hollowSquareInnerRatio = 0.5,
    ui.Color? colorOverride,
    String coverageNamespace = 'legacy',
  }) {
    final paintColor = colorOverride ?? currentColor;
    final r = paintColor.r;
    final g = paintColor.g;
    final b = paintColor.b;'''
if old_sig in s:
    s = s.replace(old_sig, new_sig, 1)
elif 'String coverageNamespace' not in s:
    raise SystemExit('signature marker not found')

legacy_key = "final coverageKey = '$layerId:$tx:$ty';"
if legacy_key in s:
    s = s.replace(legacy_key, "final coverageKey = '$coverageNamespace:$layerId:$tx:$ty';", 1)

marker = '''            } else if (chainLink) {
              // 中抜き楕円リンク。'''
hollow = '''            } else if (hollowSquare) {
              final outerDistance = math.max(ux.abs(), uy.abs());
              final innerRadius = radius *
                  hollowSquareInnerRatio.clamp(0.0, 0.95).toDouble();
              final outerAa = (radius + 0.5 - outerDistance).clamp(0.0, 1.0);
              final innerAa = (outerDistance - innerRadius + 0.5).clamp(0.0, 1.0);
              pixelAlpha = math.min(outerAa, innerAa);
            } else if (chainLink) {
              // 中抜き楕円リンク。'''
if marker in s:
    s = s.replace(marker, hollow, 1)
elif 'else if (hollowSquare)' not in s:
    raise SystemExit('hollow-square insertion marker not found')

p.write_text(s)
