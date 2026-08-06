import 'package:flutter/material.dart';
import '../../../models/ruler.dart';

class RulerPanel extends StatelessWidget {
  final Ruler? activeRuler;
  final ValueChanged<Ruler?> onRulerChanged;
  final VoidCallback onClose;

  const RulerPanel({
    super.key,
    required this.activeRuler,
    required this.onRulerChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('定規', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  if (activeRuler != null)
                    TextButton(
                      onPressed: () => onRulerChanged(null),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('削除', style: TextStyle(fontSize: 11)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _rulerTile(context, RulerType.line,                  Icons.straighten,        '直線定規'),
            _rulerTile(context, RulerType.ellipse,               Icons.circle_outlined,   '楕円定規'),
            _rulerTile(context, RulerType.radial,                Icons.hub_outlined,      '集中線定規'),
            const Divider(height: 1),
            _rulerTile(context, RulerType.onePointPerspective,   Icons.filter_center_focus, '1点透視'),
            _rulerTile(context, RulerType.twoPointPerspective,   Icons.compare_arrows,    '2点透視'),
            _rulerTile(context, RulerType.threePointPerspective, Icons.grid_3x3,          '3点透視'),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _rulerTile(BuildContext context, RulerType type, IconData icon, String label) {
    final isActive = activeRuler?.type == type;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: isActive ? Colors.blue : null),
      title: Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.blue : null)),
      selected: isActive,
      selectedTileColor: Colors.blue.withValues(alpha: 0.1),
      onTap: () {
        if (isActive) {
          onRulerChanged(null);
        } else {
          onRulerChanged(_defaultRuler(type));
        }
        onClose();
      },
    );
  }

  Ruler _defaultRuler(RulerType type) {
    final center = const Offset(960, 540); // キャンバス中央
    return switch (type) {
      RulerType.line => Ruler(
          type: type, position: center,
          settings: const RulerSettings()),
      RulerType.ellipse => Ruler(
          type: type, position: center,
          settings: const RulerSettings(radiusX: 200, radiusY: 120)),
      RulerType.radial => Ruler(
          type: type, position: center,
          settings: const RulerSettings(divisions: 12)),
      RulerType.onePointPerspective => Ruler(
          type: type, position: center,
          settings: RulerSettings(vanishingPoint1: center)),
      RulerType.twoPointPerspective => Ruler(
          type: type, position: center,
          settings: RulerSettings(
            vanishingPoint1: const Offset(200, 540),
            vanishingPoint2: const Offset(1720, 540),
          )),
      RulerType.threePointPerspective => Ruler(
          type: type, position: center,
          settings: RulerSettings(
            vanishingPoint1: const Offset(200, 540),
            vanishingPoint2: const Offset(1720, 540),
            vanishingPoint3: const Offset(960, 100),
          )),
      _ => Ruler(type: type, position: center, settings: const RulerSettings()),
    };
  }
}

/// キャンバス上に定規を半透明で描画するPainter
class RulerOverlayPainter extends CustomPainter {
  final Ruler? ruler;
  final Rect drawingRect;
  final int canvasW;
  final int canvasH;

  const RulerOverlayPainter({
    required this.ruler,
    required this.drawingRect,
    required this.canvasW,
    required this.canvasH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = ruler;
    if (r == null || !r.isVisible) return;

    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final sx = drawingRect.width / canvasW;
    final sy = drawingRect.height / canvasH;

    Offset toScreen(Offset p) =>
        drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);

    switch (r.type) {
      case RulerType.line:
        final angle = r.rotation;
        final len = 3000.0;
        final dx = len * (angle == 0 ? 1 : (angle == 1.5708 ? 0 : 1));
        final dy = len * (angle == 0 ? 0 : (angle == 1.5708 ? 1 : 0));
        final c = toScreen(r.position);
        canvas.drawLine(
          Offset(c.dx - dx * sx, c.dy - dy * sy),
          Offset(c.dx + dx * sx, c.dy + dy * sy),
          paint,
        );
        _drawHandle(canvas, c);

      case RulerType.ellipse:
        final rx = (r.settings.radiusX ?? 200) * sx;
        final ry = (r.settings.radiusY ?? 120) * sy;
        final c = toScreen(r.position);
        canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), paint);
        _drawHandle(canvas, c);

      case RulerType.radial:
        final divisions = r.settings.divisions ?? 12;
        final c = toScreen(r.position);
        final len = 2000.0 * sx;
        for (int i = 0; i < divisions; i++) {
          final angle = (i / divisions) * 3.14159265 * 2;
          canvas.drawLine(
            c,
            Offset(c.dx + len * (angle == 0 ? 1 : 0.9), c.dy + len * 0.1),
            paint,
          );
          // 実際の角度計算
          final a = angle;
          canvas.drawLine(c,
            Offset(c.dx + len * _cos(a), c.dy + len * _sin(a)), paint);
        }
        _drawHandle(canvas, c);

      case RulerType.onePointPerspective:
        final vp = r.settings.vanishingPoint1 ?? r.position;
        final vpS = toScreen(vp);
        _drawVanishingLines(canvas, vpS, paint, size);
        _drawHandle(canvas, vpS);

      case RulerType.twoPointPerspective:
        final vp1 = r.settings.vanishingPoint1 ?? const Offset(200, 540);
        final vp2 = r.settings.vanishingPoint2 ?? const Offset(1720, 540);
        _drawVanishingLines(canvas, toScreen(vp1), paint, size);
        _drawVanishingLines(canvas, toScreen(vp2), paint, size);
        _drawHandle(canvas, toScreen(vp1));
        _drawHandle(canvas, toScreen(vp2));

      case RulerType.threePointPerspective:
        final vp1 = r.settings.vanishingPoint1 ?? const Offset(200, 540);
        final vp2 = r.settings.vanishingPoint2 ?? const Offset(1720, 540);
        final vp3 = r.settings.vanishingPoint3 ?? const Offset(960, 100);
        _drawVanishingLines(canvas, toScreen(vp1), paint, size);
        _drawVanishingLines(canvas, toScreen(vp2), paint, size);
        _drawVanishingLines(canvas, toScreen(vp3), paint, size);
        _drawHandle(canvas, toScreen(vp1));
        _drawHandle(canvas, toScreen(vp2));
        _drawHandle(canvas, toScreen(vp3));

      case RulerType.circle:
        break;
    }
  }

  void _drawVanishingLines(Canvas canvas, Offset vp, Paint paint, Size size) {
    const steps = 8;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final edge = Offset(size.width * t, t < 0.5 ? 0 : size.height);
      canvas.drawLine(vp, edge, paint);
    }
  }

  void _drawHandle(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 6,
        Paint()..color = Colors.blue.withValues(alpha: 0.8));
    canvas.drawCircle(center, 6,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  double _cos(double a) {
    // dart:math を import せずに近似
    return Offset(a, 0).direction == 0 ? 1.0 : (Offset.fromDirection(a)).dx;
  }

  double _sin(double a) {
    return (Offset.fromDirection(a)).dy;
  }

  @override
  bool shouldRepaint(RulerOverlayPainter old) =>
      old.ruler != ruler || old.drawingRect != drawingRect;
}
