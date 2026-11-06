from pathlib import Path

p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()

# Migration + idempotent verifier. dart format may split named parameters over
# multiple lines, so verification must not depend on one exact signature layout.
if 'ui.Offset? screenPosition' not in s:
    s = s.replace(
        '  void beginStroke(StrokePoint point, String layerId) {',
        '  void beginStroke(StrokePoint point, String layerId, {ui.Offset? screenPosition}) {',
        1,
    )
    s = s.replace(
        '    _feedFoldDetector(effective, layerId);',
        '    _feedFoldDetector(effective, layerId, screenPosition: screenPosition);',
        1,
    )
    s = s.replace(
        '  void continueStroke(StrokePoint point, String layerId) {',
        '  void continueStroke(StrokePoint point, String layerId, {ui.Offset? screenPosition}) {',
        1,
    )
    s = s.replace(
        '      beginStroke(point, layerId);',
        '      beginStroke(point, layerId, screenPosition: screenPosition);',
        1,
    )
    s = s.replace(
        '    _feedFoldDetector(effective, layerId);',
        '    _feedFoldDetector(effective, layerId, screenPosition: screenPosition);',
        1,
    )
    s = s.replace(
        '  void _feedFoldDetector(StrokePoint point, String layerId) {',
        '  void _feedFoldDetector(StrokePoint point, String layerId, {ui.Offset? screenPosition}) {',
        1,
    )

s = s.replace(
    "        // DrawingEngine accepts document coordinates. Canvas may supply a\n        // screen-space mapper separately; at 1x these coordinates are identical.\n        screenPosition: ui.Offset(point.x, point.y),",
    "        // Fold thresholds are defined in physical screen-space travel. The\n        // caller supplies pointer screen coordinates when document zoom differs\n        // from 1x; direct engine callers retain the 1x-compatible fallback.\n        screenPosition: screenPosition ?? ui.Offset(point.x, point.y),",
    1,
)

resolver_import = "import 'hair_fold_render_resolver.dart';\n"
wave_import = "import 'wave_hair_fold_geometry.dart';\n"
anchor_import = "import 'brush_stroke_geometry.dart';\n"
if resolver_import not in s:
    if anchor_import not in s:
        raise SystemExit('brush_stroke_geometry import marker missing')
    s = s.replace(anchor_import, anchor_import + resolver_import + wave_import, 1)
elif wave_import not in s:
    s = s.replace(resolver_import, resolver_import + wave_import, 1)

legacy = """    final branches = buildFoldY(
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
"""
current = """    final path = resolveHairFoldRenderPath(
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
    for (final sample in path) {
      final width = sample.width;
      if (!width.isFinite || width <= 0.05) continue;
      _renderCircleStamp(
        sample.position.dx,
        sample.position.dy,
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
    int sampleCount = 48,
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
      sampleCount: sampleCount,
    );
  }
"""
if current not in s:
    if legacy not in s:
        raise SystemExit('legacy Y fold renderer marker missing')
    s = s.replace(legacy, current, 1)

required = [
    'void beginStroke(',
    'void continueStroke(',
    'ui.Offset? screenPosition',
    '_feedFoldDetector(effective, layerId, screenPosition: screenPosition)',
    'screenPosition: screenPosition ?? ui.Offset(point.x, point.y)',
    "import 'hair_fold_render_resolver.dart';",
    "import 'wave_hair_fold_geometry.dart';",
    'final path = resolveHairFoldRenderPath(',
    'waveEnabled: brush.foldWaveEnabled',
    'outlineWidth: brush.outlineWidth',
    '_renderHairFoldPath(path, layerId, ui.Color(brush.outlineColor))',
    'static List<WaveFoldPathSample> debugResolveHairFoldPath(',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'screen-space fold integration marker missing: {marker}')

if 'final branches = buildFoldY(' in s:
    raise SystemExit('legacy Y fold renderer is still active')

p.write_text(s)
