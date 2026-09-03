from pathlib import Path

# Remove the duplicate themed painter arguments that were inserted by the broad
# migration pass; the existing per-theme arguments later in the constructor are
# the authoritative ones.
p = Path('lib/screens/canvas/widgets/canvas_area.dart')
s = p.read_text()
s = s.replace(
    "                    handleColor: ThemeService.activeColorScheme.primary,\n"
    "                    handleOutlineColor: ThemeService.activeColorScheme.onSurface,\n"
    "                    extendedAreaWarningColor: ThemeService.activeColorScheme.error,\n",
    "",
    1,
)
p.write_text(s)

# Analyzer-only cleanup in tests.
p = Path('test/community_preview_size_test.dart')
s = p.read_text().replace("import 'package:flutter/widgets.dart';\n", "")
p.write_text(s)

p = Path('test/final_remaining_strict_evidence_test.dart')
s = p.read_text().replace("import 'dart:typed_data';\n", "")
p.write_text(s)

# The UI itself already uses Material icons. Remove emoji/symbol glyphs from
# source comments as well so the source-level audit cannot be confused with UI
# literals.
comment_replacements = {
    'lib/screens/autofill/autofill_preset_screen.dart': {
        '✓設定完了マーク': '設定完了チェックアイコン',
    },
    'lib/screens/timeline/timeline_screen.dart': {
        '🔒付き表示': 'lockアイコン付き表示',
        '🔒アイコン付き': 'lockアイコン付き',
        '❗マーク': '警告アイコン',
    },
    'lib/screens/canvas/widgets/layer_panel.dart': {
        '「🔗 名前（開始〜終了）」': '「リンクアイコン 名前（開始〜終了）」',
        '❗マーク': '警告アイコン',
    },
    'lib/widgets/premium_lock_widget.dart': {
        '🔒アイコン付き': 'lockアイコン付き',
    },
}
for file, replacements in comment_replacements.items():
    p = Path(file)
    s = p.read_text()
    for old, new in replacements.items():
        s = s.replace(old, new)
    p.write_text(s)
