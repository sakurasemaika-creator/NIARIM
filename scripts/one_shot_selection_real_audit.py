#!/usr/bin/env python3
from pathlib import Path

p = Path('test/functional_audit_batch20_test.dart')
text = p.read_text(encoding='utf-8')

# Imports.
old = "import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/models/project.dart';\n"
new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/app_bootstrap.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
if text.count(old) == 1:
    text = text.replace(old, new)
elif "import 'package:niarim/app_bootstrap.dart';" not in text:
    raise SystemExit('guard failed imports')

# PNG calls in real async and stage diagnostics.
repls = {
"    await _save(before, 96, 80, '${out.path}/selection_real_before.png');\n":
"    print('B20 stage 1: initial pixels ready');\n    await tester.runAsync(() => _save(before, 96, 80, '${out.path}/selection_real_before.png'));\n    print('B20 stage 2: initial PNG saved');\n",
"    await _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png');\n":
"    print('B20 stage 5: first move verified');\n    await tester.runAsync(() => _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png'));\n",
"    await _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png');\n":
"    print('B20 stage 7: second move verified');\n    await tester.runAsync(() => _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png'));\n",
"    await _save(_readCanvas(tm, key, 96, 80), 96, 80,\n        '${out.path}/selection_real_undo_original.png');\n":
"    print('B20 stage 8: undo verified');\n    await tester.runAsync(() => _save(_readCanvas(tm, key, 96, 80), 96, 80, '${out.path}/selection_real_undo_original.png'));\n",
"    await tester.pump(const Duration(milliseconds: 200));\n    expect(tester.takeException(), isNull);\n":
"    await tester.pump(const Duration(milliseconds: 200));\n    expect(tester.takeException(), isNull);\n    print('B20 stage 3: CanvasArea mounted');\n",
"    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2),\n        reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');\n":
"    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2), reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');\n    print('B20 stage 9: redo verified - complete');\n",
}
for a,b in repls.items():
    if text.count(a)==1: text=text.replace(a,b)

# Real app providers.
old_provider = "    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
new_provider = "    final appProviders = await tester.runAsync(buildAppProviders);\n    var selectionActive = false;\n    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ...appProviders!,\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
if text.count(old_provider)==1: text=text.replace(old_provider,new_provider)

# Inject callback in CanvasArea.
needle = "                  sceneId: scene.id,\n                ),\n"
replace = "                  sceneId: scene.id,\n                  onSelectionActiveChanged: (v) => selectionActive = v,\n                ),\n"
if text.count(needle)!=1: raise SystemExit('guard callback')
text=text.replace(needle,replace)

# Realistic 3x screen geometry.
text=text.replace("    tester.view.physicalSize = const Size(320, 240);\n","    tester.view.physicalSize = const Size(480, 360);\n")
text=text.replace("                width: 96,\n                height: 80,\n","                width: 288,\n                height: 240,\n")
anchor="    final area = find.byType(CanvasArea);\n    final origin = tester.getTopLeft(area);\n"
rep="    final area = find.byType(CanvasArea);\n    final origin = tester.getTopLeft(area);\n    Offset at(Offset canvasPx) => origin + Offset(canvasPx.dx * 3, canvasPx.dy * 3);\n"
if text.count(anchor)!=1: raise SystemExit('guard map')
text=text.replace(anchor,rep)
text=text.replace("origin + const Offset(16, 14)","at(const Offset(16, 14))")
text=text.replace("origin + const Offset(48, 46)","at(const Offset(48, 46))")

# After initial rectangle selection, prove mask activation callback fired.
needle="    expect(tester.takeException(), isNull);\n\n    // 2) 選択内を掴む。"
rep="    expect(tester.takeException(), isNull);\n    expect(selectionActive, isTrue, reason: '矩形選択のPointer操作で選択マスクが実際に確定すること');\n    print('B20 stage 4: rectangle selection mask confirmed active');\n\n    // 2) 選択内を掴む。"
if text.count(needle)!=1: raise SystemExit('guard selection activation')
text=text.replace(needle,rep)

# First transform: actual source cut readiness + assert Undo recording starts on down.
old_first="""    await _dragWithWait(
      tester,
      origin + const Offset(30, 28),
      origin + const Offset(46, 38),
      waitBeforeMove: const Duration(milliseconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 250));
"""
new_first="""    final move1Gesture = await tester.startGesture(
      at(const Offset(30, 28)),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(tm.recordingTouchedTiles, isNotNull,
        reason: '選択内Pointer Downで選択変形のUndo記録が開始されること');
    print('B20 stage 4b: selection transform begin confirmed');
    await _waitForPixelAlpha(tester, tm, key, 20, 19, 0);
    await move1Gesture.moveTo(at(const Offset(46, 38)));
    await tester.pump(const Duration(milliseconds: 40));
    await move1Gesture.up();
    await tester.pump();
    await _waitForPixelAlpha(tester, tm, key, 36, 29, 255);
"""
if text.count(old_first)!=1: raise SystemExit('guard first drag')
text=text.replace(old_first,new_first)

# Second transform at a point exclusively inside moved mask.
old_second="""    await _dragWithWait(
      tester,
      origin + const Offset(46, 38),
      origin + const Offset(51, 38),
      waitBeforeMove: const Duration(milliseconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 250));
"""
new_second="""    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final move2Gesture = await tester.startGesture(
      at(const Offset(60, 50)),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(tm.recordingTouchedTiles, isNotNull,
        reason: '旧範囲外・移動後範囲内の点で2回目の選択変形が開始できること');
    await _waitForPixelAlpha(tester, tm, key, 36, 29, 0);
    await move2Gesture.moveTo(at(const Offset(65, 50)));
    await tester.pump(const Duration(milliseconds: 40));
    await move2Gesture.up();
    await tester.pump();
    await _waitForPixelAlpha(tester, tm, key, 41, 29, 255);
"""
if text.count(old_second)!=1: raise SystemExit('guard second drag')
text=text.replace(old_second,new_second)

# readiness helper
helper_anchor="Future<void> _dragWithWait(\n"
helper="""Future<void> _waitForPixelAlpha(
  WidgetTester tester,
  dynamic tm,
  String layer,
  int x,
  int y,
  int expectedAlpha,
) async {
  final ok = await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      final tile = tm.getTile(layer, x ~/ 256, y ~/ 256) as Uint8List?;
      final alpha = tile == null ? 0 : tile[((y % 256) * 256 + (x % 256)) * 4 + 3];
      if (alpha == expectedAlpha) return true;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return false;
  });
  expect(ok, isTrue,
      reason: '選択変形の非同期切り取り/貼り戻しが3秒以内に実画素へ反映されること');
  await tester.pump();
}

"""
if text.count(helper_anchor)!=1: raise SystemExit('guard helper')
text=text.replace(helper_anchor,helper+helper_anchor)

p.write_text(text,encoding='utf-8',newline='\n')
print('patched Batch20 with mask activation and undo-recording diagnostics')
