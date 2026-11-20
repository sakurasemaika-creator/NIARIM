import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/keep_together_text.dart';
import 'tip_diagram_data.dart';

/// A localized diagram with a highlighted control or region for each step.
class TipDiagram extends StatelessWidget {
  const TipDiagram({
    super.key,
    required this.steps,
    required this.height,
    required this.isComparison,
  });

  final List<TipDiagramStep> steps;
  final double height;
  final bool isComparison;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final diagramHeight = math.max(height, scaler.scale(90) * 3 + 86);
    final largeText = scaler.scale(14) > 18;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SizedBox(
        height: diagramHeight,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  ExcludeSemantics(
                    child: SizedBox(
                      height: 18,
                      child: isComparison
                          ? null
                          : Icon(
                              Icons.arrow_downward_rounded,
                              color: scheme.onSurfaceVariant,
                              size: 16,
                            ),
                    ),
                  ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          if (!isComparison) ...[
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.onPrimaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                textScaler: TextScaler.noScaling,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            flex: 5,
                            child: messageText(
                              steps[i].$3,
                              keepLineStarts: true,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: largeText ? 3 : 4,
                            child: ExcludeSemantics(
                              child: _Miniature(
                                kind: steps[i].$1,
                                icon: steps[i].$2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Miniature extends StatelessWidget {
  const _Miniature({required this.kind, required this.icon});

  final TipDiagramKind kind;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final painter = _MiniaturePainter(kind, scheme);
    final target = painter.target;
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 112,
          height: 64,
          child: Stack(
            children: [
              CustomPaint(painter: painter, size: const Size(112, 64)),
              Positioned.fromRect(
                rect: target,
                child: Icon(icon, size: 15, color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniaturePainter extends CustomPainter {
  const _MiniaturePainter(this.kind, this.scheme);

  final TipDiagramKind kind;
  final ColorScheme scheme;

  Rect get target => switch (kind) {
    TipDiagramKind.timeline => const Rect.fromLTWH(44, 25, 29, 19),
    TipDiagramKind.range => const Rect.fromLTWH(53, 27, 27, 19),
    TipDiagramKind.layers => const Rect.fromLTWH(65, 25, 25, 18),
    TipDiagramKind.settings ||
    TipDiagramKind.filter => const Rect.fromLTWH(75, 24, 23, 19),
    TipDiagramKind.toolbar => const Rect.fromLTWH(45, 38, 25, 18),
    TipDiagramKind.text => const Rect.fromLTWH(72, 33, 23, 18),
    TipDiagramKind.vertical => const Rect.fromLTWH(71, 19, 24, 21),
    TipDiagramKind.color => const Rect.fromLTWH(72, 31, 25, 18),
    TipDiagramKind.save => const Rect.fromLTWH(20, 13, 25, 17),
    TipDiagramKind.savedVersions => const Rect.fromLTWH(64, 25, 28, 16),
    TipDiagramKind.devices => const Rect.fromLTWH(68, 27, 24, 18),
    TipDiagramKind.export => const Rect.fromLTWH(65, 32, 25, 19),
    TipDiagramKind.fineGrid ||
    TipDiagramKind.mediumGrid ||
    TipDiagramKind.wideGrid => const Rect.fromLTWH(75, 20, 22, 21),
    TipDiagramKind.canvas ||
    TipDiagramKind.media => const Rect.fromLTWH(57, 27, 26, 20),
    TipDiagramKind.curve ||
    TipDiagramKind.fade => const Rect.fromLTWH(65, 17, 25, 19),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final line = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = scheme.outlineVariant;
    final muted = scheme.surfaceContainerHighest;
    final ink = scheme.onSurfaceVariant.withValues(alpha: .58);
    final accent = scheme.primary;

    void box(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double r = 3,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        fill..color = color,
      );
    }

    void rule(double x, double y, double toX, double toY, [Color? color]) {
      canvas.drawLine(
        Offset(x, y),
        Offset(toX, toY),
        line..color = color ?? scheme.outlineVariant,
      );
    }

    void scene(double x, double y, double w, double h) {
      box(x, y, w, h, scheme.secondaryContainer);
      canvas.drawCircle(
        Offset(x + w * .72, y + h * .3),
        h * .11,
        fill..color = scheme.tertiary,
      );
      final ridge = Path()
        ..moveTo(x + 2, y + h * .83)
        ..lineTo(x + w * .32, y + h * .45)
        ..lineTo(x + w * .54, y + h * .72)
        ..lineTo(x + w * .76, y + h * .54)
        ..lineTo(x + w - 2, y + h * .83)
        ..close();
      canvas.drawPath(ridge, fill..color = scheme.secondary);
    }

    box(3, 2, 106, 60, scheme.surfaceContainer, 7);
    box(8, 7, 96, 50, scheme.surface, 5);
    for (var x = 14.0; x <= 23; x += 4) {
      canvas.drawCircle(Offset(x, 11), 1, fill..color = ink);
    }

    switch (kind) {
      case TipDiagramKind.timeline:
      case TipDiagramKind.range:
        for (var x = 14.0; x <= 98; x += 10) {
          rule(x, 17, x, 52);
        }
        box(16, 25, 24, 9, scheme.secondaryContainer);
        box(43, 25, 33, 9, scheme.tertiaryContainer);
        box(30, 41, 36, 8, muted);
        rule(49, 16, 49, 53, accent);
        if (kind == TipDiagramKind.range) {
          rule(34, 22, 34, 49, accent);
          rule(84, 22, 84, 49, accent);
        }
      case TipDiagramKind.layers:
      case TipDiagramKind.savedVersions:
        for (var y = 15.0; y <= 45; y += 13) {
          box(13, y, 86, 11, muted);
          scene(16, y + 1, 17, 9);
          rule(39, y + 4, 56, y + 4, ink);
        }
      case TipDiagramKind.settings:
      case TipDiagramKind.filter:
        for (var y = 20.0; y <= 48; y += 14) {
          rule(17, y, 40, y, ink);
          rule(48, y, 93, y);
          canvas.drawCircle(
            Offset(55 + (y - 20) / 2, y),
            2.7,
            fill..color = accent,
          );
        }
      case TipDiagramKind.toolbar:
        scene(14, 16, 84, 23);
        for (var x = 15.0; x <= 91; x += 17) {
          box(x, 42, 12, 11, muted);
        }
      case TipDiagramKind.text:
      case TipDiagramKind.vertical:
        final vertical = kind == TipDiagramKind.vertical;
        if (vertical) {
          for (var x = 29.0; x <= 63; x += 16) {
            rule(x, 18, x, 49, ink);
            rule(x + 4, 21, x + 4, 36);
          }
        } else {
          for (var y = 22.0; y <= 49; y += 8) {
            rule(18, y, 65 - (y % 3) * 8, y, ink);
          }
        }
      case TipDiagramKind.canvas:
      case TipDiagramKind.media:
        scene(13, 15, 86, 39);
        if (kind == TipDiagramKind.media) {
          rule(18, 48, 95, 48, scheme.onSecondaryContainer);
          rule(19, 48, 45, 48, accent);
        }
      case TipDiagramKind.color:
        for (var i = 0; i < 5; i++) {
          final color = [
            scheme.primary,
            scheme.secondary,
            scheme.tertiary,
            scheme.primaryContainer,
            scheme.tertiaryContainer,
          ][i];
          box(16 + 16 * i.toDouble(), 17, 12, 14, color);
        }
        box(16, 39, 49, 8, muted);
        rule(18, 43, 59, 43, accent);
      case TipDiagramKind.save:
        box(20, 16, 29, 10, muted);
        box(55, 16, 40, 10, scheme.secondaryContainer);
        scene(16, 34, 26, 16);
        rule(48, 39, 86, 39, ink);
        rule(48, 45, 73, 45);
      case TipDiagramKind.devices:
        box(13, 16, 18, 37, scheme.secondaryContainer);
        scene(15, 20, 14, 22);
        rule(35, 34, 52, 34, accent);
        box(55, 17, 43, 32, muted);
        scene(58, 20, 38, 22);
        rule(61, 52, 94, 52, ink);
      case TipDiagramKind.export:
        box(20, 15, 44, 38, muted, 4);
        rule(26, 24, 55, 24, ink);
        rule(26, 32, 52, 32, ink);
        rule(26, 40, 47, 40, ink);
        rule(50, 43, 84, 43, accent);
      case TipDiagramKind.curve:
      case TipDiagramKind.fade:
        for (var x = 15.0; x <= 98; x += 13) {
          rule(x, 16, x, 50);
        }
        for (var y = 17.0; y <= 50; y += 10) {
          rule(15, y, 98, y);
        }
        final path = Path()..moveTo(16, 49);
        if (kind == TipDiagramKind.fade) {
          path
            ..lineTo(35, 25)
            ..lineTo(74, 25)
            ..lineTo(97, 49);
        } else {
          path.cubicTo(43, 47, 54, 21, 94, 17);
        }
        canvas.drawPath(
          path,
          line
            ..color = accent
            ..style = PaintingStyle.stroke,
        );
        line.style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(35, 31), 2.3, fill..color = accent);
      case TipDiagramKind.fineGrid:
      case TipDiagramKind.mediumGrid:
      case TipDiagramKind.wideGrid:
        final spacing = switch (kind) {
          TipDiagramKind.fineGrid => 3.0,
          TipDiagramKind.mediumGrid => 6.0,
          _ => 10.0,
        };
        box(14, 15, 49, 39, scheme.secondaryContainer);
        for (var x = 17.0; x <= 60; x += spacing) {
          rule(x, 17, x, 51, ink);
        }
        for (var y = 18.0; y <= 50; y += spacing) {
          rule(16, y, 61, y, ink);
        }
    }

    final selected = RRect.fromRectAndRadius(target, const Radius.circular(4));
    canvas.drawRRect(selected, fill..color = scheme.primaryContainer);
    canvas.drawRRect(
      selected,
      line
        ..color = accent
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke,
    );
    final y = target.center.dy;
    final x = target.right + 1;
    canvas.drawPath(
      Path()
        ..moveTo(x + 7, y - 3.5)
        ..lineTo(x + 2, y)
        ..lineTo(x + 7, y + 3.5),
      line,
    );
  }

  @override
  bool shouldRepaint(_MiniaturePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.scheme != scheme;
}
