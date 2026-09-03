from pathlib import Path
import re

# ---- Known requested fixes -------------------------------------------------
p = Path('lib/screens/premium/premium_screen.dart')
s = p.read_text()
s = s.replace("                  perMonthLabel: l10n.premiumYearlyPerMonthLabel,\n", "")
s = s.replace("    String? perMonthLabel,\n", "")
start = s.find("                      // 年額プランは総額だけだと月額と比べにくいので、")
if start >= 0:
    end = s.find("                        ),\n", start)
    if end >= 0:
        s = s[:start] + s[end + len("                        ),\n"):]
s = s.replace("    final premiumBg = scheme.primaryContainer;", "    final premiumBg = scheme.primary;")
p.write_text(s)

p = Path('lib/screens/canvas/widgets/frame_strip_widget.dart')
s = p.read_text().replace(
    "style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: WidgetStatePropertyAll(scheme.surface.withValues(alpha: 0)))",
    "style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: WidgetStatePropertyAll(scheme.surface.withValues(alpha: 0)))",
)
p.write_text(s)

p = Path('lib/screens/settings/settings_screen.dart')
s = p.read_text()
s = s.replace("// 無料会員のみ🔒マーク付きで表示", "// 無料会員はMaterialのlockアイコンで表示")
s = s.replace("icon: Icons.water,\n        title: isPremium\n            ? l10n.settingsWatermarkTitle\n            : '${l10n.settingsWatermarkTitle} 🔒',", "icon: isPremium ? Icons.water : Icons.lock_outline,\n        title: l10n.settingsWatermarkTitle,")
for literal in ["const Color(0xFFFF5C7A)", "const Color(0xFF3DDC97)", "const Color(0xFFFFB020)", "const Color(0xFF3AA6FF)", "const Color(0xFFB15CFF)"]:
    s = s.replace(literal, "Theme.of(context).colorScheme.primary")
s = s.replace("shadowColor: Colors.black.withValues(alpha: 0.15)", "shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15)")
p.write_text(s)

# ---- Theme-derived colors usable even from painters/helpers without context -
theme = Path('lib/services/theme_service.dart')
s = theme.read_text()
old = "  ThemeData get themeData => _buildTheme(_current);"
new = "  static ColorScheme activeColorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFFFF5C7A));\n\n  ThemeData get themeData {\n    final data = _buildTheme(_current);\n    activeColorScheme = data.colorScheme;\n    return data;\n  }"
if old in s:
    s = s.replace(old, new)
theme.write_text(s)

# Hardcoded chroma used as app chrome/status styling is theme-derived. Functional
# colors (user artwork/color pickers, fade-color choices, onion-skin swatches,
# QR/checkerboard/instructional artwork) are deliberately excluded.
exclude_files = {
    'lib/screens/canvas/widgets/hsv_color_wheel.dart',
    'lib/widgets/background_color_picker.dart',
    'lib/screens/tips/tip_diagrams.dart',
    'lib/screens/help/help_diagrams.dart',
}
functional_tokens = (
    '_currentColor =', '_backgroundColor =', 'fadeColor', 'Color(0xFFFFFFFF)',
    'Color(0xFF000000)', 'ui.Paint()', 'Paint()..color', 'canvas.draw',
)
# User-selectable onion colors are functional data, not app chrome.
functional_files = {'lib/screens/canvas/widgets/onion_skin_panel.dart'}

mapping = {
    'red': 'error',
    'amber': 'tertiary', 'orange': 'tertiary', 'yellow': 'tertiary',
    'blue': 'primary', 'indigo': 'primary', 'purple': 'secondary', 'pink': 'secondary',
    'green': 'secondary', 'teal': 'secondary', 'cyan': 'secondary',
    'grey': 'onSurfaceVariant', 'gray': 'onSurfaceVariant',
    'black': 'onSurface', 'white': 'onSurface',
}
rx_index = re.compile(r'Colors\.(black|white|grey|gray|amber|pink|red|blue|green|orange|purple|yellow|brown|cyan|teal|indigo|lime)(?:\[\d+\])?!?')

for root in [Path('lib/screens'), Path('lib/widgets')]:
    for path in root.rglob('*.dart'):
        rel = path.as_posix()
        if rel in exclude_files or rel in functional_files:
            continue
        text = path.read_text()
        changed = False
        out = []
        for line in text.splitlines(True):
            if not rx_index.search(line):
                out.append(line); continue
            if any(tok in line for tok in functional_tokens):
                out.append(line); continue
            # Media/content overlays are intentionally contrast colors rather than
            # app chrome; their source imagery determines contrast.
            if 'community_' in rel and ('Colors.black' in line or 'Colors.white' in line):
                out.append(line); continue
            def repl(m):
                nonlocal_dummy = None
                name = m.group(1)
                role = mapping.get(name, 'primary')
                # shadowColor is explicitly the theme shadow role.
                if 'shadowColor:' in line and name == 'black': role = 'shadow'
                return f'ThemeService.activeColorScheme.{role}'
            new_line = rx_index.sub(repl, line)
            if new_line != line:
                changed = True
                # A runtime theme value cannot occur in a const expression on the same line.
                new_line = new_line.replace('const Icon(', 'Icon(').replace('const TextStyle(', 'TextStyle(').replace('const ColorFilter.mode(', 'ColorFilter.mode(')
            out.append(new_line)
        if not changed:
            continue
        text = ''.join(out)
        imp = "import 'package:niarim/services/theme_service.dart';\n"
        if imp not in text:
            # package import is valid from every lib/ location.
            text = imp + text
        path.write_text(text)
