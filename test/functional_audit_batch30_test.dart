import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaの投げ縄選択で囲んだ赤図形だけを移動し外の青図形は全RGBA不変', (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'lasso-selection-functional',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 80,
      ),
    ))!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);

    final initial = Uint8List(96 * 80 * 4);
    _rect(initial, 96, 30, 30, 39, 39, 230, 45, 30);
    _rect(initial, 96, 70, 55, 79, 64, 25, 80, 230);
    tm.replaceLayerPixels(key, initial);
    final before = _read(tm, key, 96, 80);

    final providers = await tester.runAsync(buildAppProviders);
    var active = false;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 288,
                height: 240,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: CanvasArea(
                    project: p,
                    currentLayerId: layer.id,
                    currentTool: DrawingTool.selectLasso,
                    currentFrame: 0,
                    sceneId: scene.id,
                    onSelectionActiveChanged: (v) => active = v,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_lasso_00_before.png'),
    );
    final origin = tester.getTopLeft(find.byType(CanvasArea));
    Offset at(double x, double y) => origin + Offset(x * 3, y * 3);

    // 不規則5角形で赤だけを囲う。
    final g = await tester.startGesture(
      at(18, 24),
      kind: PointerDeviceKind.touch,
    );
    for (final pnt in const [
      Offset(48, 19),
      Offset(56, 44),
      Offset(36, 54),
      Offset(17, 43),
      Offset(18, 24),
    ]) {
      await g.moveTo(at(pnt.dx, pnt.dy));
      await tester.pump();
    }
    await g.up();
    await tester.pump();
    expect(active, isTrue, reason: '投げ縄Pointer操作で選択マスクが確定すること');
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_lasso_01_selected.png'),
    );

    final move = await tester.startGesture(
      at(34, 34),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(tm.recordingTouchedTiles, isNotNull);
    await _waitAlpha(tester, tm, key, 34, 34, 0);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await move.moveTo(at(54, 44));
    await tester.pump(const Duration(milliseconds: 40));
    await move.up();
    await tester.pump();
    await _waitUndo(tester, undo, 1);
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_lasso_02_after.png'),
    );

    final actual = _read(tm, key, 96, 80);
    final expected = Uint8List.fromList(before);
    // 赤矩形だけ+20,+10移動。元を透明化し新位置へコピー。
    for (var y = 30; y < 39; y++) {
      for (var x = 30; x < 39; x++) {
        final si = (y * 96 + x) * 4;
        final di = ((y + 10) * 96 + (x + 20)) * 4;
        expected.setRange(di, di + 4, before, si);
        expected.fillRange(si, si + 4, 0);
      }
    }
    expect(
      actual,
      orderedEquals(expected),
      reason: '投げ縄外の青図形を含む全画素は変えず、囲った赤だけ移動すること',
    );

    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm, key, 96, 80), orderedEquals(before));
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_lasso_03_undo.png'),
    );
    undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm, key, 96, 80), orderedEquals(actual));
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_lasso_04_redo.png'),
    );
  });
}

Future<void> _shot(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}

void _rect(
  Uint8List d,
  int w,
  int x0,
  int y0,
  int x1,
  int y1,
  int r,
  int g,
  int b,
) {
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * w + x) * 4;
      d[i] = r;
      d[i + 1] = g;
      d[i + 2] = b;
      d[i + 3] = 255;
    }
  }
}

Future<void> _waitUndo(WidgetTester t, app_undo.UndoManager u, int n) async {
  final e = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(e) && u.undoCount < n) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
  expect(u.undoCount, n);
}

Future<void> _waitAlpha(
  WidgetTester t,
  dynamic tm,
  String key,
  int x,
  int y,
  int a,
) async {
  final e = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(e)) {
    final tile = tm.getTile(key, 0, 0) as Uint8List?;
    final got = tile == null ? 0 : tile[(y * 256 + x) * 4 + 3];
    if (got == a) return;
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
  fail('alpha wait failed');
}

Uint8List _read(dynamic tm, String key, int w, int h) {
  final o = Uint8List(w * h * 4);
  final tile = tm.getTile(key, 0, 0) as Uint8List?;
  if (tile == null) return o;
  for (var y = 0; y < h; y++) {
    o.setRange(y * w * 4, (y + 1) * w * 4, tile, y * 256 * 4);
  }
  return o;
}
