from pathlib import Path

canvas_path = Path('lib/screens/canvas/canvas_screen.dart')
canvas = canvas_path.read_text(encoding='utf-8')

bad_handler = """  void _handleCanvasEyedropper(Color color) {
    final pendingBrushOutline = _pendingBrushOutlineEyedropper;
    if (pendingBrushOutline != null) {
      setState(() => _pendingBrushOutlineEyedropper = null);
      if (!pendingBrushOutline.isCompleted) {
        _pendingBrushOutlineEyedropper?.complete(color.toARGB32());
        pendingBrushOutline.complete(color.toARGB32());
      }
      return;
    }
"""
good_handler = """  void _handleCanvasEyedropper(Color color) {
    final pendingBrushOutline = _pendingBrushOutlineEyedropper;
    if (pendingBrushOutline != null) {
      setState(() => _pendingBrushOutlineEyedropper = null);
      if (!pendingBrushOutline.isCompleted) {
        pendingBrushOutline.complete(color.toARGB32());
      }
      return;
    }
"""
if bad_handler in canvas:
    canvas = canvas.replace(bad_handler, good_handler, 1)
elif good_handler not in canvas:
    raise SystemExit('brush outline canvas handler anchor missing')

canvas_path.write_text(canvas, encoding='utf-8', newline='\n')

brush_path = Path('lib/screens/canvas/widgets/brush_panel.dart')
brush = brush_path.read_text(encoding='utf-8')
old_method = """  Future<void> _eyedropOutlineColor() async {
    final callback = widget.onEyedropOutlineColor;
    if (callback == null) return;
    final sampled = await callback();
    if (!mounted || sampled == null) return;
    setState(() => _brush = _brush.copyWith(outlineColor: sampled));
  }
"""
new_method = """  Future<void> _eyedropOutlineColor() async {
    final callback = widget.onEyedropOutlineColor;
    if (callback == null) return;
    final service = context.read<BrushService>();
    final draft = _brush;
    Navigator.of(context).pop();
    final sampled = await callback();
    if (sampled == null) return;
    service.updateBrush(draft.copyWith(outlineColor: sampled));
  }
"""
if old_method in brush:
    brush = brush.replace(old_method, new_method, 1)
elif new_method not in brush:
    raise SystemExit('brush outline settings eyedropper anchor missing')

brush_path.write_text(brush, encoding='utf-8', newline='\n')
