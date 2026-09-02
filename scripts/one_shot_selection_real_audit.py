#!/usr/bin/env python3
from pathlib import Path

p = Path('test/functional_audit_batch20_test.dart')
text = p.read_text(encoding='utf-8')

# Permanent import cleanup applied only after the functional test succeeds.
old = "import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/models/project.dart';\n"
new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
if text.count(old) == 1:
    text = text.replace(old, new)
elif "import 'package:flutter/gestures.dart';" not in text:
    raise SystemExit('guard failed for batch20 imports')

# ui.Image codec/file I/O must run outside WidgetTester's fake-async zone.
repls = {
"    await _save(before, 96, 80, '${out.path}/selection_real_before.png');\n":
"    print('B20 stage 1: initial pixels ready');\n    await tester.runAsync(() =>\n        _save(before, 96, 80, '${out.path}/selection_real_before.png'));\n    print('B20 stage 2: initial PNG saved');\n",
"    await _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png');\n":
"    print('B20 stage 5: first move verified');\n    await tester.runAsync(() =>\n        _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png'));\n",
"    await _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png');\n":
"    print('B20 stage 7: second move verified');\n    await tester.runAsync(() =>\n        _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png'));\n",
"    await _save(_readCanvas(tm, key, 96, 80), 96, 80,\n        '${out.path}/selection_real_undo_original.png');\n":
"    print('B20 stage 8: undo verified');\n    await tester.runAsync(() => _save(_readCanvas(tm, key, 96, 80), 96, 80,\n        '${out.path}/selection_real_undo_original.png'));\n",
"    await tester.pump(const Duration(milliseconds: 200));\n    expect(tester.takeException(), isNull);\n":
"    await tester.pump(const Duration(milliseconds: 200));\n    expect(tester.takeException(), isNull);\n    print('B20 stage 3: CanvasArea mounted');\n",
"    expect(tester.takeException(), isNull);\n\n    // 2) 選択内を掴む。":
"    expect(tester.takeException(), isNull);\n    print('B20 stage 4: rectangle selection created');\n\n    // 2) 選択内を掴む。",
"    expect(tester.takeException(), isNull);\n    final moved2 = _readCanvas":
"    expect(tester.takeException(), isNull);\n    print('B20 stage 6: second drag completed');\n    final moved2 = _readCanvas",
"    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2),\n        reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');\n":
"    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2),\n        reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');\n    print('B20 stage 9: redo verified - complete');\n",
}
for old_s, new_s in repls.items():
    count = text.count(old_s)
    if count != 1:
        raise SystemExit(f'guard failed for diagnostic replacement: {old_s[:60]!r}, count={count}')
    text = text.replace(old_s, new_s)

p.write_text(text, encoding='utf-8', newline='\n')
print('patched batch20 fake-async PNG handling and diagnostics')
