#!/usr/bin/env python3
from pathlib import Path

p = Path('test/functional_audit_batch20_test.dart')
text = p.read_text(encoding='utf-8')

old = "import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\nimport 'package:niarim/models/project.dart';\n"
new = "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:niarim/app_bootstrap.dart';\nimport 'package:niarim/engine/undo_manager.dart' as app_undo;\n"
if text.count(old)==1: text=text.replace(old,new)
elif "import 'package:niarim/app_bootstrap.dart';" not in text: raise SystemExit('imports')

for a,b in {
"    await _save(before, 96, 80, '${out.path}/selection_real_before.png');\n":"    print('B20 stage 1: initial pixels ready');\n    await tester.runAsync(() => _save(before, 96, 80, '${out.path}/selection_real_before.png'));\n    print('B20 stage 2: initial PNG saved');\n",
"    await _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png');\n":"    print('B20 stage 5: first move verified');\n    await tester.runAsync(() => _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png'));\n",
"    await _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png');\n":"    print('B20 stage 7: second move verified');\n    await tester.runAsync(() => _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png'));\n",
"    await _save(_readCanvas(tm, key, 96, 80), 96, 80,\n        '${out.path}/selection_real_undo_original.png');\n":"    print('B20 stage 8: undo verified');\n    await tester.runAsync(() => _save(_readCanvas(tm, key, 96, 80), 96, 80, '${out.path}/selection_real_undo_original.png'));\n",
}.items():
    if text.count(a)==1: text=text.replace(a,b)

oldp="    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
newp="    final appProviders = await tester.runAsync(buildAppProviders);\n    var selectionActive = false;\n    await tester.pumpWidget(\n      MultiProvider(\n        providers: [\n          ...appProviders!,\n          ChangeNotifierProvider<ProjectService>.value(value: projects),\n          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),\n        ],\n"
if text.count(oldp)==1: text=text.replace(oldp,newp)
needle="                  sceneId: scene.id,\n                ),\n"
rep="                  sceneId: scene.id,\n                  onSelectionActiveChanged: (v) => selectionActive = v,\n                ),\n"
if text.count(needle)!=1: raise SystemExit('callback')
text=text.replace(needle,rep)

text=text.replace("    tester.view.physicalSize = const Size(320, 240);\n","    tester.view.physicalSize = const Size(480, 360);\n")
text=text.replace("                width: 96,\n                height: 80,\n","                width: 288,\n                height: 240,\n")
a="    final area = find.byType(CanvasArea);\n    final origin = tester.getTopLeft(area);\n"
b="    final area = find.byType(CanvasArea);\n    final origin = tester.getTopLeft(area);\n    Offset at(Offset canvasPx) => origin + Offset(canvasPx.dx * 3, canvasPx.dy * 3);\n"
if text.count(a)!=1: raise SystemExit('map')
text=text.replace(a,b)
text=text.replace("origin + const Offset(16, 14)","at(const Offset(16, 14))")
text=text.replace("origin + const Offset(48, 46)","at(const Offset(48, 46))")

n="    expect(tester.takeException(), isNull);\n\n    // 2) 選択内を掴む。"
r="    expect(tester.takeException(), isNull);\n    expect(selectionActive, isTrue, reason: '矩形選択のPointer操作で選択マスクが実際に確定すること');\n    print('B20 stage 4: rectangle selection mask confirmed active');\n\n    // 2) 選択内を掴む。"
if text.count(n)!=1: raise SystemExit('active')
text=text.replace(n,r)

old1="""    await _dragWithWait(
      tester,
      origin + const Offset(30, 28),
      origin + const Offset(46, 38),
      waitBeforeMove: const Duration(milliseconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 250));
"""
new1="""    final move1Gesture = await tester.startGesture(
      at(const Offset(30, 28)), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(tm.recordingTouchedTiles, isNotNull,
        reason: '選択内Pointer Downで選択変形のUndo記録が開始されること');
    print('B20 stage 4b: selection transform begin confirmed');
    await _waitForAnyCanvasDifference(tester, tm, key, before, 96, 80);
    await _waitForPixelAlpha(tester, tm, key, 20, 19, 0);
    await move1Gesture.moveTo(at(const Offset(46, 38)));
    await tester.pump(const Duration(milliseconds: 40));
    await move1Gesture.up();
    await tester.pump();
    await _waitForPixelAlpha(tester, tm, key, 36, 29, 255);
"""
if text.count(old1)!=1: raise SystemExit('first')
text=text.replace(old1,new1)

old_expected="""    final expected1 = _translatedSelection(before, 96, 80,
        left: 16, top: 14, right: 48, bottom: 46, dx: 16, dy: 10);
    expect(moved1, orderedEquals(expected1),
"""
new_expected="""    final expected1 = _translatedSelection(before, 96, 80,
        left: 16, top: 14, right: 48, bottom: 46, dx: 16, dy: 10);
    _printCanvasDiagnostics('after-first-commit', moved1, expected1, 96, 80);
    expect(moved1, orderedEquals(expected1),
"""
if text.count(old_expected)!=1: raise SystemExit('first expected diagnostics')
text=text.replace(old_expected,new_expected)

old2="""    await _dragWithWait(
      tester,
      origin + const Offset(46, 38),
      origin + const Offset(51, 38),
      waitBeforeMove: const Duration(milliseconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 250));
"""
new2="""    await _pumpRealAsyncUntil(tester, () => tm.recordingTouchedTiles == null, timeout: const Duration(seconds: 3));
    final move2Gesture = await tester.startGesture(
      at(const Offset(60, 50)), kind: PointerDeviceKind.touch);
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
if text.count(old2)!=1: raise SystemExit('second')
text=text.replace(old2,new2)

text=text.replace("    await tester.pump(const Duration(milliseconds: 200));\n    expect(tester.takeException(), isNull);\n",
                  "    await tester.pump(const Duration(milliseconds: 200));\n    expect(tester.takeException(), isNull);\n    print('B20 stage 3: CanvasArea mounted');\n")
text=text.replace("    expect(tester.takeException(), isNull);\n    final moved2 = _readCanvas",
                  "    expect(tester.takeException(), isNull);\n    print('B20 stage 6: second drag completed');\n    final moved2 = _readCanvas")
text=text.replace("    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2),\n        reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');\n",
                  "    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2), reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');\n    print('B20 stage 9: redo verified - complete');\n")

ha="Future<void> _dragWithWait(\n"
helpers="""Future<void> _pumpRealAsyncUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(condition(), isTrue, reason: '実時間イベントとWidget fake-asyncを交互に進めても期限内に完了すること');
}

Future<void> _waitForAnyCanvasDifference(
  WidgetTester tester, dynamic tm, String layer, Uint8List before, int w, int h,
) async {
  bool differs() {
    final now = _readCanvas(tm, layer, w, h);
    for (int i = 0; i < now.length; i++) {
      if (now[i] != before[i]) return true;
    }
    return false;
  }
  await _pumpRealAsyncUntil(tester, differs, timeout: const Duration(seconds: 3));
  final now = _readCanvas(tm, layer, w, h);
  int minX = w, minY = h, maxX = -1, maxY = -1, changed = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      var diff = false;
      for (int c = 0; c < 4; c++) {
        if (now[i + c] != before[i + c]) diff = true;
      }
      if (!diff) continue;
      changed++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  print('B20 diagnostic: changedPixels=$changed bbox=[$minX,$minY]-[$maxX,$maxY]');
}

void _printCanvasDiagnostics(
  String label, Uint8List actual, Uint8List expected, int w, int h,
) {
  int minAX=w, minAY=h, maxAX=-1, maxAY=-1, opaqueA=0;
  int minDX=w, minDY=h, maxDX=-1, maxDY=-1, diff=0;
  for (int y=0; y<h; y++) {
    for (int x=0; x<w; x++) {
      final i=(y*w+x)*4;
      if (actual[i+3] != 0) {
        opaqueA++;
        if (x<minAX) minAX=x; if (x>maxAX) maxAX=x;
        if (y<minAY) minAY=y; if (y>maxAY) maxAY=y;
      }
      var d=false;
      for (int c=0;c<4;c++) { if (actual[i+c] != expected[i+c]) d=true; }
      if (d) {
        diff++;
        if (x<minDX) minDX=x; if (x>maxDX) maxDX=x;
        if (y<minDY) minDY=y; if (y>maxDY) maxDY=y;
      }
    }
  }
  int alphaAt(int x,int y)=>actual[(y*w+x)*4+3];
  print('B20 $label: occupied=$opaqueA bbox=[$minAX,$minAY]-[$maxAX,$maxAY] diff=$diff diffBbox=[$minDX,$minDY]-[$maxDX,$maxDY] alphaOld=${alphaAt(20,19)} alphaMoved=${alphaAt(36,29)} alphaMovedFar=${alphaAt(57,47)}');
}

Future<void> _waitForPixelAlpha(
  WidgetTester tester, dynamic tm, String layer,
  int x, int y, int expectedAlpha,
) async {
  bool matches() {
    final tile = tm.getTile(layer, x ~/ 256, y ~/ 256) as Uint8List?;
    final alpha = tile == null ? 0 : tile[((y % 256) * 256 + (x % 256)) * 4 + 3];
    return alpha == expectedAlpha;
  }
  await _pumpRealAsyncUntil(tester, matches, timeout: const Duration(seconds: 3));
}

"""
if text.count(ha)!=1: raise SystemExit('helper')
text=text.replace(ha,helpers+ha)

p.write_text(text,encoding='utf-8',newline='\n')
print('patched Batch20 with post-commit transform diagnostics')
