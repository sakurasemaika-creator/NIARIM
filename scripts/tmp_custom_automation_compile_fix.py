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

# The manager must remember where recording began. Every semantic step also stores
# the frame where the actual state-changing operation occurred. This makes the
# current/all-frame radio available only when every recorded Canvas operation stayed
# on the starting frame.
replace_all(
    'lib/screens/canvas/canvas_screen.dart',
    '        onRecordingStarted: _showCustomAutomationRecordingOverlay,\n',
    '        onRecordingStarted: _showCustomAutomationRecordingOverlay,\n        recordingStartFrame: _currentFrame,\n',
)
replace_all(
    'lib/screens/timeline/timeline_screen.dart',
    '        onRecordingStarted: _showCustomAutomationRecordingOverlay,\n',
    '        onRecordingStarted: _showCustomAutomationRecordingOverlay,\n        recordingStartFrame: _currentFrame,\n',
)
for path in [
    'lib/screens/canvas/canvas_screen.dart',
    'lib/screens/timeline/timeline_screen.dart',
]:
    replace_all(
        path,
        '      changesFrame: changesFrame,\n    );',
        '      changesFrame: changesFrame,\n      recordedFrame: _currentFrame,\n    );',
    )

# Keep a single import when an existing screen already imported the premium lock.
p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()
line = "import '../../widgets/premium_lock_widget.dart';\n"
if s.count(line) > 1:
    first = s.find(line)
    s = s[: first + len(line)] + s[first + len(line):].replace(line, '')
p.write_text(s)

# Compatibility with an older manager-sheet revision, if present in the checkout.
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

print('custom automation compile/frame-context compatibility fixes applied')
