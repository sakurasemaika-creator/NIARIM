from pathlib import Path


def replace_all(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text()
    if old in s:
        s = s.replace(old, new)
        p.write_text(s)

# Scene context is intentionally not part of automation eligibility. The recorded
# frame is the single source of truth.
for path in [
    'lib/screens/canvas/canvas_screen.dart',
    'lib/screens/timeline/timeline_screen.dart',
]:
    replace_all(path, '    bool changesScene = false,\n', '')
    replace_all(path, '      changesScene: changesScene,\n', '')

# Keep a single import when an existing screen already imported the premium lock.
p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()
line = "import '../../widgets/premium_lock_widget.dart';\n"
if s.count(line) > 1:
    first = s.find(line)
    s = s[: first + len(line)] + s[first + len(line):].replace(line, '')
p.write_text(s)

# The project has no commonYes/commonNo l10n keys. Use Flutter's localized
# standard action labels rather than introducing untranslated strings.
p = Path('lib/widgets/custom_automation_manager_sheet.dart')
s = p.read_text()
s = s.replace(
    'child: Text(l10n.commonNo),',
    'child: Text(MaterialLocalizations.of(context).cancelButtonLabel),',
)
s = s.replace(
    'child: Text(l10n.commonYes),',
    'child: Text(MaterialLocalizations.of(context).okButtonLabel),',
)
p.write_text(s)

print('custom automation compile compatibility fixes applied')
