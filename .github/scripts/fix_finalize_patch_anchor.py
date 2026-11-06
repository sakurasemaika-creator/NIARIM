from pathlib import Path

p = Path('.github/scripts/finalize_post_baseline_features.py')
s = p.read_text()
old_old = '''    "    final l10n = AppLocalizations.of(context)!;\\n    showDialog(\\n",'''
new_old = '''    "    final fontService = context.read<FontService>();\\n    final l10n = AppLocalizations.of(context)!;\\n    showDialog(\\n",'''
old_new = '''    "    final l10n = AppLocalizations.of(context)!;\\n\\n    model.TextObject textDraft() {'''
new_new = '''    "    final fontService = context.read<FontService>();\\n    final l10n = AppLocalizations.of(context)!;\\n\\n    model.TextObject textDraft() {'''
for old, new in ((old_old, new_old), (old_new, new_new)):
    if s.count(old) != 1:
        raise SystemExit(f'anchor source match count={s.count(old)} for {old[:80]!r}')
    s = s.replace(old, new, 1)
p.write_text(s)
