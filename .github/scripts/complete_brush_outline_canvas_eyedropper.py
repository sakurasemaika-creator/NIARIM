from pathlib import Path

p = Path('lib/screens/canvas/canvas_screen.dart')
s = p.read_text(encoding='utf-8')

if "import 'dart:async';" not in s:
    s = "import 'dart:async';\n\n" + s

field_anchor = "  ValueChanged<Color>? _pendingTextColorEyedropper;\n"
if "Completer<int?>? _pendingBrushOutlineEyedropper;" not in s:
    if field_anchor not in s:
        raise SystemExit('brush eyedropper field anchor missing')
    s = s.replace(
        field_anchor,
        field_anchor + "  Completer<int?>? _pendingBrushOutlineEyedropper;\n\n  bool get _brushOutlineEyedropperActive =>\n      _pendingBrushOutlineEyedropper != null;\n",
        1,
    )

handler_anchor = "  void _handleCanvasEyedropper(Color color) {\n"
if "Future<int?> _startBrushOutlineEyedropper()" not in s:
    if handler_anchor not in s:
        raise SystemExit('canvas eyedropper handler anchor missing')
    helper = """  Future<int?> _startBrushOutlineEyedropper() {
    final previous = _pendingBrushOutlineEyedropper;
    if (previous != null && !previous.isCompleted) {
      previous.complete(null);
    }
    final completer = Completer<int?>();
    setState(() => _pendingBrushOutlineEyedropper = completer);
    return completer.future;
  }

"""
    s = s.replace(handler_anchor, helper + handler_anchor, 1)

handler_body = "  void _handleCanvasEyedropper(Color color) {\n"
if "_pendingBrushOutlineEyedropper?.complete(color.toARGB32())" not in s:
    replacement = """  void _handleCanvasEyedropper(Color color) {
    final brushOutline = _pendingBrushOutlineEyedropper;
    if (brushOutline != null) {
      setState(() => _pendingBrushOutlineEyedropper = null);
      if (!brushOutline.isCompleted) {
        brushOutline.complete(color.toARGB32());
      }
      return;
    }
"""
    s = s.replace(handler_body, replacement, 1)

hint_anchor = "    if (_textColorEyedropperTarget != null) {\n      return l10n.filterCanvasEyedropperTooltip;\n    }\n"
if "if (_brushOutlineEyedropperActive)" not in s:
    if hint_anchor not in s:
        raise SystemExit('eyedropper hint anchor missing')
    s = s.replace(
        hint_anchor,
        hint_anchor + "    if (_brushOutlineEyedropperActive) {\n      return l10n.filterCanvasEyedropperTooltip;\n    }\n",
        1,
    )

old_brush = "  Widget _brushPanel() =>\n      BrushPanel(onClose: () => setState(() => _showBrushPanel = false));\n"
if "onEyedropOutlineColor: _startBrushOutlineEyedropper" not in s:
    if old_brush not in s:
        raise SystemExit('brush panel anchor missing')
    s = s.replace(
        old_brush,
        """  Widget _brushPanel() => BrushPanel(
    onClose: () => setState(() => _showBrushPanel = false),
    onEyedropOutlineColor: _startBrushOutlineEyedropper,
  );
""",
        1,
    )

old_active = """                                  filterEyedropperActive:
                                      _filterColorEyedropperTarget != null ||
                                      _textColorEyedropperTarget != null,
"""
new_active = """                                  filterEyedropperActive:
                                      _filterColorEyedropperTarget != null ||
                                      _textColorEyedropperTarget != null ||
                                      _brushOutlineEyedropperActive,
"""
if old_active in s:
    s = s.replace(old_active, new_active, 1)
elif new_active not in s:
    raise SystemExit('canvas eyedropper active anchor missing')

old_overlay = """                                if (_filterColorEyedropperTarget != null ||
                                    _textColorEyedropperTarget != null)
"""
new_overlay = """                                if (_filterColorEyedropperTarget != null ||
                                    _textColorEyedropperTarget != null ||
                                    _brushOutlineEyedropperActive)
"""
if old_overlay in s:
    s = s.replace(old_overlay, new_overlay, 1)
elif new_overlay not in s:
    raise SystemExit('eyedropper overlay anchor missing')

p.write_text(s, encoding='utf-8', newline='\n')
