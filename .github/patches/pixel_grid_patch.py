from pathlib import Path

path = Path('lib/screens/canvas/widgets/canvas_area.dart')
text = path.read_text()

marker = "const double kCanvasMaxScale = 10.0;\n"
insert = '''const double kCanvasMaxScale = 10.0;

/// A one-project-pixel grid is useful only when a pixel is large enough to be
/// visually distinguishable on screen. Below this threshold the lines would
/// alias into a moire pattern and cost thousands of draw calls without helping
/// pixel placement.
bool shouldPaintPixelGrid(double pixelScreenSize) => pixelScreenSize >= 3.0;
'''
if text.count(marker) != 1:
    raise SystemExit(f'grid helper marker count={text.count(marker)}')
text = text.replace(marker, insert, 1)

marker = "    final settings = context.watch<SettingsService>();\n    final theme = context.watch<ThemeService>().current;"
insert = '''    final settings = context.watch<SettingsService>();
    final theme = context.watch<ThemeService>().current;
    final currentBrush = context.watch<BrushService>().currentBrush;
    final pixelBrushActive = currentBrush?.pixelMode == true &&
        ((widget.currentTool == DrawingTool.pen &&
                widget.currentSubTool == PenSubTool.brush) ||
            widget.currentTool == DrawingTool.eraser ||
            widget.currentTool == DrawingTool.ruler ||
            widget.currentTool == DrawingTool.shape);'''
if text.count(marker) != 1:
    raise SystemExit(f'build brush marker count={text.count(marker)}')
text = text.replace(marker, insert, 1)

marker = '''                    viewTransform: _transformController.value,
                  ),
                  size: Size.infinite,
'''
replacement = '''                    viewTransform: _transformController.value,
                  ),
                  foregroundPainter: _PixelGridPainter(
                    project: widget.project,
                    enabled: pixelBrushActive,
                    color: theme.menuTextColor,
                    viewTransform: _transformController.value,
                  ),
                  size: Size.infinite,
'''
if text.count(marker) != 1:
    raise SystemExit(f'foreground marker count={text.count(marker)}')
text = text.replace(marker, replacement, 1)

marker = "// ─── Painter ──────────────────────────────────────────────────────────────\n\nclass _CanvasPainter extends CustomPainter {"
painter = r'''// ─── Painter ──────────────────────────────────────────────────────────────

/// Screen-only one-project-pixel grid for pixel-mode brushes. It is attached
/// as CustomPaint.foregroundPainter, so it never enters tiles, previews,
/// thumbnails, or exports.
class _PixelGridPainter extends CustomPainter {
  final Project? project;
  final bool enabled;
  final Color color;
  final Matrix4 viewTransform;

  const _PixelGridPainter({
    required this.project,
    required this.enabled,
    required this.color,
    required this.viewTransform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final drawingRect = canvasDrawingRectFor(size, project);
    final canvasPx = canvasPixelSizeOf(project);
    if (drawingRect.isEmpty || canvasPx.width <= 0 || canvasPx.height <= 0) {
      return;
    }
    final stepX = drawingRect.width / canvasPx.width;
    final stepY = drawingRect.height / canvasPx.height;
    final zoom = viewTransform.getMaxScaleOnAxis();
    final pixelScreenSize = math.min(stepX, stepY) * zoom;
    if (!shouldPaintPixelGrid(pixelScreenSize)) return;

    final visible = visibleWidgetRectFor(size, viewTransform).intersect(
      drawingRect,
    );
    if (visible.isEmpty) return;
    final startX = math.max(
      0,
      ((visible.left - drawingRect.left) / stepX).floor(),
    );
    final endX = math.min(
      canvasPx.width.round(),
      ((visible.right - drawingRect.left) / stepX).ceil(),
    );
    final startY = math.max(
      0,
      ((visible.top - drawingRect.top) / stepY).floor(),
    );
    final endY = math.min(
      canvasPx.height.round(),
      ((visible.bottom - drawingRect.top) / stepY).ceil(),
    );

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65 / math.max(zoom, 0.001)
      ..isAntiAlias = false;

    canvas.save();
    canvas.clipRect(drawingRect);
    for (int x = startX; x <= endX; x++) {
      final px = drawingRect.left + x * stepX;
      canvas.drawLine(
        Offset(px, drawingRect.top),
        Offset(px, drawingRect.bottom),
        gridPaint,
      );
    }
    for (int y = startY; y <= endY; y++) {
      final py = drawingRect.top + y * stepY;
      canvas.drawLine(
        Offset(drawingRect.left, py),
        Offset(drawingRect.right, py),
        gridPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) =>
      oldDelegate.enabled != enabled ||
      oldDelegate.project != project ||
      oldDelegate.color != color ||
      oldDelegate.viewTransform != viewTransform;
}

class _CanvasPainter extends CustomPainter {'''
if text.count(marker) != 1:
    raise SystemExit(f'painter class marker count={text.count(marker)}')
text = text.replace(marker, painter, 1)
path.write_text(text)

Path('test/pixel_mode_grid_test.dart').write_text('''import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

void main() {
  test('pixel grid appears only once project pixels are visually separable', () {
    expect(shouldPaintPixelGrid(2.99), isFalse);
    expect(shouldPaintPixelGrid(3.0), isTrue);
    expect(shouldPaintPixelGrid(12.0), isTrue);
  });
}
''')
