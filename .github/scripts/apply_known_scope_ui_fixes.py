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
# Repair the orphaned close left by the old per-month block removal.
s = s.replace(
    "                      Text(\n                        price,\n                        textAlign: TextAlign.end,\n                        style: TextStyle(\n                          fontSize: 18,\n                          fontWeight: FontWeight.bold,\n                          color: scheme.onSurface,\n                        ),\n                      ),\n                        ),\n                    ],",
    "                      Text(\n                        price,\n                        textAlign: TextAlign.end,\n                        style: TextStyle(\n                          fontSize: 18,\n                          fontWeight: FontWeight.bold,\n                          color: scheme.onSurface,\n                        ),\n                      ),\n                    ],",
)
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
# checkerboards and instructional/content artwork) are deliberately excluded.
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
functional_files = {'lib/screens/canvas/widgets/onion_skin_panel.dart'}

mapping = {
    'red': 'error',
    'amber': 'tertiary', 'orange': 'tertiary', 'yellow': 'tertiary',
    'blue': 'primary', 'indigo': 'primary', 'purple': 'secondary', 'pink': 'secondary',
    'green': 'secondary', 'teal': 'secondary', 'cyan': 'secondary',
    'grey': 'onSurfaceVariant', 'gray': 'onSurfaceVariant',
    'black': 'onSurface', 'white': 'onSurface',
}
# Include Material opacity suffixes (black54, white70, etc.) so no bogus
# ColorScheme getters such as onSurface54 are created.
rx_index = re.compile(r'Colors\.(black|white|grey|gray|amber|pink|red|blue|green|orange|purple|yellow|brown|cyan|teal|indigo|lime)(?:(12|24|26|30|38|45|54|60|70|87))?(?:\[\d+\])?!?')

def theme_replacement(name, suffix, line):
    role = mapping.get(name, 'primary')
    if 'shadowColor:' in line and name == 'black':
        role = 'shadow'
    base = f'ThemeService.activeColorScheme.{role}'
    if suffix:
        return f'{base}.withValues(alpha: {int(suffix) / 100:.2f})'
    return base

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
            def repl(m):
                return theme_replacement(m.group(1), m.group(2), line)
            new_line = rx_index.sub(repl, line)
            if new_line != line:
                changed = True
            out.append(new_line)
        if changed:
            text = ''.join(out)
            # Prefer an existing relative ThemeService import if present; only add
            # a package import when the file did not already import the service.
            if 'theme_service.dart' not in text:
                text = "import 'package:niarim/services/theme_service.dart';\n" + text
            path.write_text(text)

# ---- Repair bad substitutions from the first migration pass -----------------
opacity_suffix = re.compile(r'ThemeService\.activeColorScheme\.(onSurface|onSurfaceVariant|primary|secondary|tertiary|error|shadow)(12|24|26|30|38|45|54|60|70|87)\b')
for root in [Path('lib/screens'), Path('lib/widgets')]:
    for path in root.rglob('*.dart'):
        text = path.read_text()
        text = opacity_suffix.sub(lambda m: f'ThemeService.activeColorScheme.{m.group(1)}.withValues(alpha: {int(m.group(2))/100:.2f})', text)

        # Remove duplicate ThemeService imports introduced when the file already
        # used a relative import of the same library.
        lines = text.splitlines(True)
        theme_imports = [i for i,l in enumerate(lines) if l.lstrip().startswith('import ') and 'theme_service.dart' in l]
        if len(theme_imports) > 1:
            keep = theme_imports[-1]  # Prefer the pre-existing local import.
            lines = [l for i,l in enumerate(lines) if i == keep or i not in theme_imports]

        # Runtime theme values cannot live inside const expressions. Remove the
        # closest enclosing const for every ThemeService reference. This is
        # intentionally local (max 8 lines) so unrelated model constants remain.
        for i, line in enumerate(lines):
            if 'ThemeService.activeColorScheme' not in line:
                continue
            if 'const ' in lines[i]:
                lines[i] = lines[i].replace('const ', '')
            for j in range(i - 1, max(-1, i - 9), -1):
                st = lines[j].strip()
                if 'const ' in lines[j]:
                    lines[j] = lines[j].replace('const ', '', 1)
                    break
                if st.endswith(';') or st.startswith('return '):
                    break
        path.write_text(''.join(lines))

# _CanvasPainter defaults cannot be runtime colors. Make them required and pass
# the active theme explicitly at the only construction site.
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = p.read_text()
s = s.replace('    this.handleColor = ThemeService.activeColorScheme.primary,\n    this.handleOutlineColor = ThemeService.activeColorScheme.onSurface,\n    this.extendedAreaWarningColor = ThemeService.activeColorScheme.error,',
              '    required this.handleColor,\n    required this.handleOutlineColor,\n    required this.extendedAreaWarningColor,')
needle = '                  painter: _CanvasPainter(\n'
if needle in s and 'handleColor: ThemeService.activeColorScheme.primary' not in s:
    s = s.replace(needle, needle +
        '                    handleColor: ThemeService.activeColorScheme.primary,\n'
        '                    handleOutlineColor: ThemeService.activeColorScheme.onSurface,\n'
        '                    extendedAreaWarningColor: ThemeService.activeColorScheme.error,\n', 1)
# Canvas outside is application chrome; derive it from active appearance.
s = s.replace('const Color kCanvasOutsideColor = Color(0xFF3A3A3A);',
              'Color get kCanvasOutsideColor => ThemeService.activeColorScheme.surfaceContainerHighest;')
p.write_text(s)

# Onion-skin swatch colors are user-configurable functional data, but its border
# is UI chrome and must follow the theme.
p = Path('lib/screens/canvas/widgets/onion_skin_panel.dart')
s = p.read_text().replace('border: Border.all(color: Colors.grey),',
                          'border: Border.all(color: Theme.of(context).colorScheme.outline),')
p.write_text(s)
