from pathlib import Path


def must_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found < count:
        raise SystemExit(f'{label}: expected at least {count}, found {found}')
    return text.replace(old, new, count)

# Canvas frame navigation and color changes.
p = Path('lib/screens/canvas/canvas_screen.dart')
s = p.read_text()
s = must_replace(
    s,
    '    setState(() => _currentFrame += 1);\n  }\n\n  void _goToPreviousFrame() {',
    "    setState(() => _currentFrame += 1);\n    _recordCanvasAutomation(\n      'canvas.selectFrame',\n      'Frame ${_currentFrame + 1}',\n      args: {'frame': _currentFrame},\n      changesFrame: true,\n    );\n  }\n\n  void _goToPreviousFrame() {",
    'canvas next frame',
)
s = must_replace(
    s,
    '    setState(() => _currentFrame -= 1);\n  }\n',
    "    setState(() => _currentFrame -= 1);\n    _recordCanvasAutomation(\n      'canvas.selectFrame',\n      'Frame ${_currentFrame + 1}',\n      args: {'frame': _currentFrame},\n      changesFrame: true,\n    );\n  }\n",
    'canvas previous frame',
)
# Leaving the Canvas/Timeline workspace is not recordable.
s = must_replace(
    s,
    "                  context.push('/autofill-presets');",
    "                  _runAutomationBlockedAction(\n                    () => context.push('/autofill-presets'),\n                  );",
    'canvas autofill presets exit',
)
s = must_replace(
    s,
    "                  context.push('/settings/pen');",
    "                  _runAutomationBlockedAction(\n                    () => context.push('/settings/pen'),\n                  );",
    'canvas pen settings exit',
)
# Record color changes in both floating and docked color pickers.
color_old = '''              onColorChanged: (color) {
                setState(() => _currentColor = color);
                context.read<BrushService>().setCurrentColor(color);
              },'''
color_new = '''              onColorChanged: (color) {
                setState(() => _currentColor = color);
                context.read<BrushService>().setCurrentColor(color);
                _recordCanvasAutomation(
                  'canvas.color',
                  'Color',
                  args: {'argb': color.toARGB32()},
                );
              },'''
if color_old in s:
    s = s.replace(color_old, color_new, 1)
# Standalone floating picker has slightly different indentation.
color_old2 = '''    onColorChanged: (color) {
      setState(() => _currentColor = color);
      context.read<BrushService>().setCurrentColor(color);
    },'''
color_new2 = '''    onColorChanged: (color) {
      setState(() => _currentColor = color);
      context.read<BrushService>().setCurrentColor(color);
      _recordCanvasAutomation(
        'canvas.color',
        'Color',
        args: {'argb': color.toARGB32()},
      );
    },'''
if color_old2 in s:
    s = s.replace(color_old2, color_new2, 1)
p.write_text(s)

# Timeline: record frame navigation/addition and protect external exits.
p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()
# Add a reusable blocker after record helper.
marker = '''  void _recordTimelineAutomation(
    String command,
    String label, {
    Map<String, Object?> args = const {},
    bool changesFrame = false,
    bool changesScene = false,
  }) {
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.timeline,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      changesScene: changesScene,
    );
  }

'''
blocker = marker + r'''  Future<void> _runAutomationBlockedAction(VoidCallback action) async {
    final service = context.read<CustomAutomationService>();
    if (!service.isRecording) {
      action();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final stop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationStopConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.customAutomationStopConfirmStop),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.customAutomationStopConfirmContinue),
          ),
        ],
      ),
    );
    if (stop != true || !mounted) return;
    service.cancelDraft();
    _customAutomationRecordingOverlay?.remove();
    _customAutomationRecordingOverlay = null;
    action();
  }

'''
s = must_replace(s, marker, blocker, 'timeline blocker')
# Frame selection in normal mode.
s = must_replace(
    s,
    '                                        setState(() => _currentFrame = index);',
    "                                        setState(() => _currentFrame = index);\n                                        _recordTimelineAutomation(\n                                          'timeline.selectFrame',\n                                          'Frame ${index + 1}',\n                                          args: {'frame': index},\n                                          changesFrame: true,\n                                        );",
    'timeline frame selection',
)
# Add-frame button.
add_old = '''                                        context.read<ProjectService>().addFrame(
                                          widget.projectId,
                                          sceneId,
                                        );'''
add_new = '''                                        context.read<ProjectService>().addFrame(
                                          widget.projectId,
                                          sceneId,
                                        );
                                        _recordTimelineAutomation(
                                          'timeline.addFrame',
                                          'Add frame',
                                        );'''
s = must_replace(s, add_old, add_new, 'timeline add frame')
# Save-tree/export leave Timeline; while recording they need the stop/continue dialog.
s = must_replace(
    s,
    "                context.push('/save-tree/${widget.projectId}?entry=timeline');",
    "                _runAutomationBlockedAction(\n                  () => context.push('/save-tree/${widget.projectId}?entry=timeline'),\n                );",
    'timeline save exit',
)
s = must_replace(
    s,
    "                context.push('/export/${widget.projectId}');",
    "                _runAutomationBlockedAction(\n                  () => context.push('/export/${widget.projectId}'),\n                );",
    'timeline export exit',
)
p.write_text(s)
print('custom automation recording coverage patch applied')
