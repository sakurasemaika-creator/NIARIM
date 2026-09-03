from pathlib import Path

# Premium: remove the obsolete per-month-equivalent block completely and keep
# all presentation colors theme-derived.
p = Path('lib/screens/premium/premium_screen.dart')
s = p.read_text()
s = s.replace("                  perMonthLabel: l10n.premiumYearlyPerMonthLabel,\n", "")
s = s.replace("    String? perMonthLabel,\n", "")
start = s.find("                      // 年額プランは総額だけだと月額と比べにくいので、")
if start >= 0:
    end_marker = "                        ),\n"
    end = s.find(end_marker, start)
    if end >= 0:
        s = s[:start] + s[end + len(end_marker):]
s = s.replace("    final premiumBg = scheme.primaryContainer;", "    final premiumBg = scheme.primary;")
s = s.replace("? scheme.onPrimaryContainer\n        : scheme.onSurface", "? scheme.onPrimary\n        : scheme.onSurface")
s = s.replace("premiumColumn ? scheme.primary : scheme.onSurfaceVariant", "premiumColumn ? scheme.onPrimary : scheme.onSurfaceVariant")
s = s.replace("? scheme.onPrimaryContainer.withValues(alpha: 0.55)", "? scheme.onPrimary.withValues(alpha: 0.72)")
p.write_text(s)

# Frame strip: runtime theme value cannot live inside a const ButtonStyle.
p = Path('lib/screens/canvas/widgets/frame_strip_widget.dart')
s = p.read_text()
s = s.replace("style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: WidgetStatePropertyAll(scheme.surface.withValues(alpha: 0)))", "style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: WidgetStatePropertyAll(scheme.surface.withValues(alpha: 0)))")
p.write_text(s)

# Settings: no standard emoji in visible text; the lock state is a Material icon.
# Category accent colors and shadows follow the current ColorScheme.
p = Path('lib/screens/settings/settings_screen.dart')
s = p.read_text()
s = s.replace("// 無料会員のみ🔒マーク付きで表示", "// 無料会員はMaterialのlockアイコンで表示")
s = s.replace("icon: Icons.water,\n        title: isPremium\n            ? l10n.settingsWatermarkTitle\n            : '${l10n.settingsWatermarkTitle} 🔒',", "icon: isPremium ? Icons.water : Icons.lock_outline,\n        title: l10n.settingsWatermarkTitle,")
for literal in [
    "const Color(0xFFFF5C7A)", "const Color(0xFF3DDC97)", "const Color(0xFFFFB020)",
    "const Color(0xFF3AA6FF)", "const Color(0xFFB15CFF)",
]:
    s = s.replace(literal, "Theme.of(context).colorScheme.primary")
s = s.replace("shadowColor: Colors.black.withValues(alpha: 0.15)", "shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15)")
p.write_text(s)
