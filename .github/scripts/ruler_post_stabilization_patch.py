from pathlib import Path

p = Path("lib/engine/drawing_engine.dart")
s = p.read_text(encoding="utf-8")
if "ui.Offset Function(ui.Offset)? pointConstraint;" not in s:
    anchor = "  bool isEraser = false;\n\n  // 手ブレ補正用：直近の平滑化済み座標（ON/OFF・強度調整）\n"
    if anchor not in s:
        raise SystemExit("drawing field anchor missing")
    s = s.replace(
        anchor,
        "  bool isEraser = false;\n\n  // 定規など、手ブレ補正より後に必ず満たすべき最終座標制約。\n  ui.Offset Function(ui.Offset)? pointConstraint;\n\n  // 手ブレ補正用：直近の平滑化済み座標（ON/OFF・強度調整）\n",
        1,
    )
    start = s.index("  void beginStroke(StrokePoint point, String layerId) {")
    end = s.index("\n  void continueStroke(StrokePoint point, String layerId) {", start)
    begin_lines = [
        "  void beginStroke(StrokePoint point, String layerId) {",
        "    _currentStroke.clear();",
        "    _strokeCoverageByTile.clear();",
        "    _smoothed = point;",
        "    final effective = _applyPointConstraint(point);",
        "    _activeLayerId = layerId;",
        "    _distanceSinceLastBrushStamp = 0.0;",
        "    _hasStampedCurrentStroke = false;",
        "    _scatterRng = math.Random(0);",
        "    _currentStroke.add(effective);",
        "    final brush = currentBrush;",
        "    final needsDirection =",
        "        brush != null && (brush.rotation || brush.scatter > 0.0);",
        "    if (!needsDirection) {",
        "      _stampBrush(",
        "        effective.x,",
        "        effective.y,",
        "        effective.pressure,",
        "        effective.tiltX,",
        "        effective.tiltY,",
        "        layerId,",
        "        strokeLengthOverride: 0.0,",
        "      );",
        "      _hasStampedCurrentStroke = true;",
        "    }",
        "  }",
        "",
    ]
    s = s[:start] + "\n".join(begin_lines) + s[end:]
    old = "    final effective = _applyStabilization(point);\n    final from = _currentStroke.last;\n"
    if old not in s:
        raise SystemExit("drawing continue anchor missing")
    s = s.replace(
        old,
        "    final effective = _applyPointConstraint(_applyStabilization(point));\n    final from = _currentStroke.last;\n",
        1,
    )
    marker = (
        "  /// 手ブレ補正：入力座標を直近の平滑化済み座標へ指数移動平均で追従させる。\n"
    )
    if marker not in s:
        raise SystemExit("drawing helper marker missing")
    helper_lines = [
        "  StrokePoint _applyPointConstraint(StrokePoint point) {",
        "    final constraint = pointConstraint;",
        "    if (constraint == null) return point;",
        "    final constrained = constraint(ui.Offset(point.x, point.y));",
        "    return StrokePoint(",
        "      x: constrained.dx,",
        "      y: constrained.dy,",
        "      pressure: point.pressure,",
        "      tiltX: point.tiltX,",
        "      tiltY: point.tiltY,",
        "      inputType: point.inputType,",
        "    );",
        "  }",
        "",
        "",
    ]
    s = s.replace(marker, "\n".join(helper_lines) + marker, 1)
p.write_text(s, encoding="utf-8", newline="\n")

p = Path("lib/screens/canvas/widgets/canvas_area.dart")
s = p.read_text(encoding="utf-8")
if "..pointConstraint = _rulerEngine.snapToRuler;" not in s:
    old = "    _drawingEngine = DrawingEngine(tileManager: _tileManager);\n"
    if old not in s:
        raise SystemExit("canvas engine anchor missing")
    s = s.replace(
        old,
        "    _drawingEngine = DrawingEngine(tileManager: _tileManager)\n      ..pointConstraint = _rulerEngine.snapToRuler;\n",
        1,
    )
    old = "    final snapped = _applyRulerSnap(_toCanvasPoint(_rawToStrokePoint(event)));\n    _beginTileUndo();\n    _drawingEngine.beginStroke(snapped, _tileKeyFor(_layerId));\n"
    if old not in s:
        raise SystemExit("canvas down anchor missing")
    s = s.replace(
        old,
        "    final point = _toCanvasPoint(_rawToStrokePoint(event));\n    _beginTileUndo();\n    _drawingEngine.beginStroke(point, _tileKeyFor(_layerId));\n",
        1,
    )
    old = "    final snapped = _applyRulerSnap(_toCanvasPoint(_rawToStrokePoint(event)));\n    _drawingEngine.continueStroke(snapped, _tileKeyFor(_layerId));\n"
    if old not in s:
        raise SystemExit("canvas move anchor missing")
    s = s.replace(
        old,
        "    final point = _toCanvasPoint(_rawToStrokePoint(event));\n    _drawingEngine.continueStroke(point, _tileKeyFor(_layerId));\n",
        1,
    )
p.write_text(s, encoding="utf-8", newline="\n")

p = Path("test/functional_audit_batch36_test.dart")
s = p.read_text(encoding="utf-8")
old = """      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      final draw = DrawingEngine(tileManager: tm)
        ..currentBrush = baseBrush
        ..currentColor = const ui.Color(0xFFDB3F2E);
      final re = RulerEngine()..setActiveRuler(c.ruler);
      re.beginStroke();
      final snapped = c.raw.map(re.snapToRuler).toList();
      draw.beginStroke(StrokePoint(x: snapped.first.dx, y: snapped.first.dy, pressure: 1), 'paint');
      for (final p in snapped.skip(1)) {
        draw.continueStroke(StrokePoint(x: p.dx, y: p.dy, pressure: 1), 'paint');
      }
"""
if old in s:
    new = """      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      final re = RulerEngine()..setActiveRuler(c.ruler);
      re.beginStroke();
      final draw = DrawingEngine(tileManager: tm)
        ..currentBrush = baseBrush
        ..currentColor = const ui.Color(0xFFDB3F2E)
        ..pointConstraint = re.snapToRuler;
      final first = c.raw.first;
      draw.beginStroke(StrokePoint(x: first.dx, y: first.dy, pressure: 1), 'paint');
      for (final p in c.raw.skip(1)) {
        draw.continueStroke(StrokePoint(x: p.dx, y: p.dy, pressure: 1), 'paint');
      }
"""
    s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8", newline="\n")
