#!/usr/bin/env python3
from pathlib import Path

p = Path('test/functional_audit_batch20_test.dart')
text = p.read_text(encoding='utf-8')

# Normalize imports.
old = "import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/models/project.dart';\n"
new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/app_bootstrap.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
if text.count(old) == 1:
    text = text.replace(old, new)
else:
    partial = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
    partial_new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/app_bootstrap.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
    if text.count(partial) == 1:
        text = text.replace(partial, partial_new)
    elif "import 'package:niarim/app_bootstrap.dart';" not in text:
        raise SystemExit('guard failed for Batch20 imports')

# Run image codec/file I/O in real async.
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
    if text.count(old_s) == 1:
        text = text.replace(old_s, new_s)

# Real app providers.
old_provider = "    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
new_provider = "    final appProviders = await tester.runAsync(buildAppProviders);\n    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ...appProviders!,\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
if text.count(old_provider) == 1:
    text = text.replace(old_provider, new_provider)

# Realistic on-screen size: project canvas 96x80 is displayed at exactly 3x.
text = text.replace("    tester.view.physicalSize = const Size(320, 240);\n",
                    "    tester.view.physicalSize = const Size(480, 360);\n")
text = text.replace("                width: 96,\n                height: 80,\n",
                    "                width: 288,\n                height: 240,\n")
anchor = "    final area = find.byType(CanvasArea);\n    final origin = tester.getTopLeft(area);\n"
replacement = "    final area = find.byType(CanvasArea);\n    final origin = tester.getTopLeft(area);\n    Offset at(Offset canvasPx) =>\n        origin + Offset(canvasPx.dx * 3, canvasPx.dy * 3);\n"
if text.count(anchor) != 1:
    raise SystemExit('guard failed for screen coordinate mapper')
text = text.replace(anchor, replacement)
for pt in ["16, 14", "48, 46", "30, 28"]:
    text = text.replace(f"origin + const Offset({pt})", f"at(const Offset({pt}))")

old_first = """    await _dragWithWait(\n      tester,\n      origin + const Offset(30, 28),\n      origin + const Offset(46, 38),\n      waitBeforeMove: const Duration(milliseconds: 180),\n    );\n    await tester.pump(const Duration(milliseconds: 250));\n"""
if text.count(old_first) == 0:
    old_first = """    await _dragWithWait(\n      tester,\n      at(const Offset(30, 28)),\n      origin + const Offset(46, 38),\n      waitBeforeMove: const Duration(milliseconds: 180),\n    );\n    await tester.pump(const Duration(milliseconds: 250));\n"""
new_first = """    final move1Gesture = await tester.startGesture(\n      at(const Offset(30, 28)),\n      kind: PointerDeviceKind.touch,\n    );\n    await tester.pump();\n    await _waitForPixelAlpha(tester, tm, key, 20, 19, 0);\n    await move1Gesture.moveTo(at(const Offset(46, 38)));\n    await tester.pump(const Duration(milliseconds: 40));\n    await move1Gesture.up();\n    await tester.pump();\n    await _waitForPixelAlpha(tester, tm, key, 36, 29, 255);\n"""
if text.count(old_first) != 1:
    # original untouched form
    old_first = """    await _dragWithWait(\n      tester,\n      at(const Offset(30, 28)),\n      at(const Offset(46, 38)),\n      waitBeforeMove: const Duration(milliseconds: 180),\n    );\n    await tester.pump(const Duration(milliseconds: 250));\n"""
if text.count(old_first) != 1:
    raise SystemExit('guard failed for first transform drag')
text = text.replace(old_first, new_first)

# Second grab deliberately uses a point that is OUTSIDE the original selection
# (x>=48) but INSIDE the translated selection (32<=x<64). This proves that the
# selection mask itself followed the first transform before the second drag.
old_second_candidates = [
"""    await _dragWithWait(\n      tester,\n      origin + const Offset(46, 38),\n      origin + const Offset(51, 38),\n      waitBeforeMove: const Duration(milliseconds: 180),\n    );\n    await tester.pump(const Duration(milliseconds: 250));\n""",
"""    await _dragWithWait(\n      tester,\n      at(const Offset(46, 38)),\n      at(const Offset(51, 38)),\n      waitBeforeMove: const Duration(milliseconds: 180),\n    );\n    await tester.pump(const Duration(milliseconds: 250));\n""",
]
old_second = next((s for s in old_second_candidates if text.count(s) == 1), None)
if old_second is None:
    raise SystemExit('guard failed for second transform drag')
new_second = """    // Give the mask rasterization callback an event turn, then require that a\n    // new-only point actually begins a transform by observing the source cut.\n    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));\n    await tester.pump();\n    final move2Gesture = await tester.startGesture(\n      at(const Offset(60, 50)),\n      kind: PointerDeviceKind.touch,\n    );\n    await tester.pump();\n    await _waitForPixelAlpha(tester, tm, key, 36, 29, 0);\n    await move2Gesture.moveTo(at(const Offset(65, 50)));\n    await tester.pump(const Duration(milliseconds: 40));\n    await move2Gesture.up();\n    await tester.pump();\n    await _waitForPixelAlpha(tester, tm, key, 41, 29, 255);\n"""
text = text.replace(old_second, new_second)

helper_anchor = "Future<void> _dragWithWait(\n"
helper = """Future<void> _waitForPixelAlpha(\n  WidgetTester tester,\n  dynamic tm,\n  String layer,\n  int x,\n  int y,\n  int expectedAlpha,\n) async {\n  final ok = await tester.runAsync(() async {\n    final deadline = DateTime.now().add(const Duration(seconds: 3));\n    while (DateTime.now().isBefore(deadline)) {\n      final tile = tm.getTile(layer, x ~/ 256, y ~/ 256) as Uint8List?;\n      final alpha = tile == null\n          ? 0\n          : tile[((y % 256) * 256 + (x % 256)) * 4 + 3];\n      if (alpha == expectedAlpha) return true;\n      await Future<void>.delayed(const Duration(milliseconds: 10));\n    }\n    return false;\n  });\n  expect(ok, isTrue,\n      reason: '選択変形の非同期切り取り/貼り戻しが3秒以内に実画素へ反映されること');\n  await tester.pump();\n}\n\n"""
if text.count(helper_anchor) != 1:
    raise SystemExit('guard failed for readiness helper insertion')
text = text.replace(helper_anchor, helper + helper_anchor)

p.write_text(text, encoding='utf-8', newline='\n')
print('patched Batch20 with realistic geometry, state readiness, and non-overlap mask tracking')
