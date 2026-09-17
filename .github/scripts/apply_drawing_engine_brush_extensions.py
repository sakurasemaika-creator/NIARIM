from pathlib import Path

p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()
if "import 'brush_render_plan.dart';" not in s:
    s = s.replace("import 'brush_texture_cache.dart';\n", "import 'brush_texture_cache.dart';\nimport 'brush_render_plan.dart';\n")

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
