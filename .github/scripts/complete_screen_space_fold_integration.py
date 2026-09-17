from pathlib import Path

p = Path('lib/engine/drawing_engine.dart')
s = p.read_text()

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

required = [
    'void beginStroke(StrokePoint point, String layerId, {ui.Offset? screenPosition})',
    'void continueStroke(StrokePoint point, String layerId, {ui.Offset? screenPosition})',
    'screenPosition: screenPosition ?? ui.Offset(point.x, point.y)',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'screen-space fold integration marker missing: {marker}')

p.write_text(s)
