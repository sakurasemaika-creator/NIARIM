from pathlib import Path

p = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = p.read_text()

old_begin = "    _drawingEngine.beginStroke(point, _tileKeyFor(_layerId));"
new_begin = """    _drawingEngine.beginStroke(
      point,
      _tileKeyFor(_layerId),
      screenPosition: event.localPosition,
    );"""
old_continue = "    _drawingEngine.continueStroke(point, _tileKeyFor(_layerId));"
new_continue = """    _drawingEngine.continueStroke(
      point,
      _tileKeyFor(_layerId),
      screenPosition: event.localPosition,
    );"""

if old_begin in s:
    s = s.replace(old_begin, new_begin, 1)
elif 'screenPosition: event.localPosition' not in s:
    raise SystemExit('beginStroke canvas input marker not found')

if old_continue in s:
    s = s.replace(old_continue, new_continue, 1)
elif s.count('screenPosition: event.localPosition') < 2:
    raise SystemExit('continueStroke canvas input marker not found')

if s.count('screenPosition: event.localPosition') < 2:
    raise SystemExit('explicit screen-space pointer input not wired for down and move')

p.write_text(s)
