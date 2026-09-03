from pathlib import Path

# Premium: remove monthly-equivalent label and use the strong theme accent for the
# complete Premium column, including matching onPrimary foregrounds.
p = Path('lib/screens/premium/premium_screen.dart')
s = p.read_text()
s = s.replace("                  perMonthLabel: l10n.premiumYearlyPerMonthLabel,\n", "")
s = s.replace("    String? perMonthLabel,\n", "")
s = s.replace("              if (perMonthLabel != null)\n                Text(\n                  perMonthLabel,\n", "              if (false)\n                Text(\n                  '',\n")
# Remove the disabled placeholder block cleanly if its formatting matches the current file.
s = s.replace("              if (false)\n                Text(\n                  '',\n                  textAlign: TextAlign.end,\n                  style: TextStyle(\n                    fontSize: 10,\n                    color: scheme.onSurfaceVariant,\n                  ),\n                ),\n", "")
s = s.replace("    final premiumBg = scheme.primaryContainer;", "    final premiumBg = scheme.primary;")
s = s.replace("? scheme.onPrimaryContainer\n        : scheme.onSurface", "? scheme.onPrimary\n        : scheme.onSurface")
s = s.replace("premiumColumn ? scheme.primary : scheme.onSurfaceVariant", "premiumColumn ? scheme.onPrimary : scheme.onSurfaceVariant")
s = s.replace("? scheme.onPrimaryContainer.withValues(alpha: 0.55)", "? scheme.onPrimary.withValues(alpha: 0.72)")
s = s.replace("color: scheme.onPrimaryContainer,\n                      ),", "color: scheme.onPrimary,\n                      ),")
s = s.replace("color: scheme.primary,\n                    ),\n                    const SizedBox(height: 2),", "color: scheme.onPrimary,\n                    ),\n                    const SizedBox(height: 2),")
p.write_text(s)

# Frame strip: keep transparent surfaces theme-derived and make flow-control lint clean.
p = Path('lib/screens/canvas/widgets/frame_strip_widget.dart')
s = p.read_text()
s = s.replace("    return Container(height: 64, color: Colors.transparent, child: Row(children: [", "    return Container(height: 64, color: scheme.surface.withValues(alpha: 0), child: Row(children: [")
s = s.replace("backgroundColor: WidgetStatePropertyAll(Colors.transparent)", "backgroundColor: WidgetStatePropertyAll(scheme.surface.withValues(alpha: 0))")
s = s.replace("if (nearest != widget.currentFrame) widget.onFrameSelected(nearest); else _scrollToCurrent(animate: true);", "if (nearest != widget.currentFrame) { widget.onFrameSelected(nearest); } else { _scrollToCurrent(animate: true); }")
p.write_text(s)
