from pathlib import Path

p = Path('lib/services/autofill_preset_service.dart')
s = p.read_text()

needle = """  static List<AutofillPreset> _defaultPresets() => [\n"""
insert = """  static const AutofillPreset _grayUnderpaintPreset = AutofillPreset(\n    id: 'builtin_gray_underpaint',\n    name: 'グレー単色の下塗り',\n    parts: [\n      AutofillPart(\n        id: 'builtin_gray_underpaint_base',\n        name: '下塗り',\n        color: 0xFF808080,\n      ),\n    ],\n  );\n\n  static List<AutofillPreset> _defaultPresets() => [\n    _grayUnderpaintPreset,\n"""
if needle not in s:
    raise SystemExit('default preset anchor not found')
s = s.replace(needle, insert, 1)

old = """      var changed = _dedupeIds();\n      if (_upgradeSampleContent()) changed = true;\n      if (changed) await _persist();\n"""
new = """      var changed = _dedupeIds();\n      if (_upgradeSampleContent()) changed = true;\n      if (_presets.every((preset) => preset.id != _grayUnderpaintPreset.id)) {\n        _presets.insert(0, _grayUnderpaintPreset);\n        changed = true;\n      }\n      if (changed) await _persist();\n"""
if old not in s:
    raise SystemExit('migration anchor not found')
s = s.replace(old, new, 1)
p.write_text(s)
