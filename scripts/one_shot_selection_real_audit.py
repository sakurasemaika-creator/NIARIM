#!/usr/bin/env python3
from pathlib import Path

p = Path('test/functional_audit_batch20_test.dart')
text = p.read_text(encoding='utf-8')

# Permanent imports / real app provider bootstrap.
old = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;\n"
new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/app_bootstrap.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;\n"
if text.count(old) != 1:
    raise SystemExit('guard failed for app_bootstrap import')
text = text.replace(old, new)

old = "    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
new = "    final appProviders = await tester.runAsync(buildAppProviders);\n    // 本番と同じProvider一式を使い、ProjectService/UndoManagerだけはこの\n    // テストで画素状態を直接検査するインスタンスへ差し替える。\n    final providers = appProviders!\n        .where((p) =>\n            p.runtimeType.toString() !=\n                'ChangeNotifierProvider<ProjectService>' &&\n            p.runtimeType.toString() !=\n                'ChangeNotifierProvider<UndoManager>')\n        .toList();\n    providers.add(ChangeNotifierProvider<ProjectService>.value(value: projects));\n    providers.add(\n        ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo));\n\n    await tester.pumpWidget(\n      MultiProvider(\n        providers: providers,\n"
if text.count(old) != 1:
    raise SystemExit('guard failed for provider replacement')
text = text.replace(old, new)

p.write_text(text, encoding='utf-8', newline='\n')
print('patched batch20 to use real app providers')
