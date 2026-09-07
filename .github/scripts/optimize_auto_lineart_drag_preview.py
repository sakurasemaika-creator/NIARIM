from pathlib import Path

path = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = path.read_text(encoding='utf-8')

if '_autoLineartPreviewUpdateScheduled' not in s:
    s = s.replace(
        '  bool _autoLineartManualEdited = false;\n',
        '  bool _autoLineartManualEdited = false;\n'
        '  bool _autoLineartPreviewUpdateScheduled = false;\n'
        '  int _autoLineartPreviewRevision = 0;\n',
        1,
    )

if 'void _scheduleAutoLineartPreviewUpdate()' not in s:
    anchor = '  Future<void> _updatePreview() async {\n'
    helper = '''  void _scheduleAutoLineartPreviewUpdate() {\n    if (_autoLineartPreviewUpdateScheduled) return;\n    _autoLineartPreviewUpdateScheduled = true;\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      _autoLineartPreviewUpdateScheduled = false;\n      if (mounted) _updatePreview();\n    });\n  }\n\n'''
    if anchor not in s:
        raise SystemExit('update preview anchor not found')
    s = s.replace(anchor, helper + anchor, 1)

start = '''  Future<void> _updatePreview() async {\n    final base = _previewBase;\n    final filter = context.read<FilterService>().currentFilter;\n    if (base == null || filter == null || !mounted) return;\n'''
replacement = '''  Future<void> _updatePreview() async {\n    final base = _previewBase;\n    final filter = context.read<FilterService>().currentFilter;\n    if (base == null || filter == null || !mounted) return;\n    final previewRevision = ++_autoLineartPreviewRevision;\n'''
if start not in s:
    raise SystemExit('preview start anchor not found')
s = s.replace(start, replacement, 1)

old = '''    final image = await completer.future;\n    if (!mounted) {\n      image.dispose();\n      return;\n    }\n'''
new = '''    final image = await completer.future;\n    if (!mounted || previewRevision != _autoLineartPreviewRevision) {\n      image.dispose();\n      return;\n    }\n'''
if old not in s:
    raise SystemExit('preview revision completion anchor not found')
s = s.replace(old, new, 1)

old_drag = '''                                          _autoLineartManualEdited = true;\n                                          _updatePreview();\n'''
new_drag = '''                                          _autoLineartManualEdited = true;\n                                          _scheduleAutoLineartPreviewUpdate();\n'''
if old_drag not in s:
    raise SystemExit('drag preview anchor not found')
s = s.replace(old_drag, new_drag, 1)

path.write_text(s, encoding='utf-8')
print('Auto Line Art drag preview optimization applied')
