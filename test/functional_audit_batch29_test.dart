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

  testWidgets('実CanvasAreaで選択回転ハンドルを90度操作し色別位置とUndo/Redoを検証する', (tester) async {
    tester.view.physicalSize = const Size(480, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final project = await tester.runAsync(() => projects.createProject(
      name: 'selection-rotate-functional', fps: 24, durationSeconds: 1,
      backgroundColor: 0x00000000, exportWidth: 96, exportHeight: 96,
    ));
    final p = project!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);

    final initial = Uint8List(96 * 96 * 4);
    // selection bounds=(24,50)-(72,90), center=(48,70)。
    // 赤中心(36,62) -> +90deg後(56,58)、青中心(60,78) -> (40,82)。
    _rect(initial, 96, 33, 59, 39, 65, 230, 40, 30);
    _rect(initial, 96, 57, 75, 63, 81, 30, 80, 230);
    tm.replaceLayerPixels(key, initial);
    final before = _readCanvas(tm, key, 96, 96);

    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ...providers!,
        ChangeNotifierProvider<ProjectService>.value(value: projects),
        ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(
        width: 288, height: 288,
        child: RepaintBoundary(
          key: boundaryKey,
          child: CanvasArea(
            project: p, currentLayerId: layer.id,
            currentTool: DrawingTool.selectRect, currentFrame: 0, sceneId: scene.id,
          ),
        ),
      )))),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => _shot(boundaryKey, '${out.path}/selection_rotate_00_before.png'));
    final origin = tester.getTopLeft(find.byType(CanvasArea));
    Offset at(Offset px) => origin + Offset(px.dx * 3, px.dy * 3);

    final select = await tester.startGesture(at(const Offset(24, 50)), kind: PointerDeviceKind.touch);
    await select.moveTo(at(const Offset(72, 90)));
    await tester.pump();
    await select.up();
    await tester.pump();
    await tester.runAsync(() => _shot(boundaryKey, '${out.path}/selection_rotate_01_selected.png'));

    // 回転ハンドル=(center.x, top-40)=(48,10)。開始ベクトル(0,-60)から
    // current=(88,70)の(40,0)へ移すため +90° 回転になる。
    final rotate = await tester.startGesture(at(const Offset(48, 10)), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(tm.recordingTouchedTiles, isNotNull, reason: '上部回転ハンドルが実際に回転モードを開始すること');
    await _waitForAlpha(tester, tm, key, 36, 62, 0);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await rotate.moveTo(at(const Offset(88, 70)));
    await tester.pump(const Duration(milliseconds: 40));
    await rotate.up();
    await tester.pump();
    await _waitForUndo(tester, undo, 1);
    await tester.runAsync(() => _shot(boundaryKey, '${out.path}/selection_rotate_02_after.png'));

    final actual = _readCanvas(tm, key, 96, 96);
    _expectColorNear(actual, 96, 56, 58, red: true);
    _expectColorNear(actual, 96, 40, 82, red: false);
    expect(_alpha(actual, 96, 36, 62), 0, reason: '元の赤中心は90度回転後に空くこと');
    expect(_alpha(actual, 96, 60, 78), 0, reason: '元の青中心は90度回転後に空くこと');

    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_readCanvas(tm, key, 96, 96), orderedEquals(before));
    await tester.runAsync(() => _shot(boundaryKey, '${out.path}/selection_rotate_03_undo.png'));
    undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_readCanvas(tm, key, 96, 96), orderedEquals(actual));
    await tester.runAsync(() => _shot(boundaryKey, '${out.path}/selection_rotate_04_redo.png'));
  });
}

Future<void> _shot(GlobalKey key, String path) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}
void _rect(Uint8List d, int w, int x0, int y0, int x1, int y1, int r, int g, int b) {
  for (var y = y0; y < y1; y++) for (var x = x0; x < x1; x++) {
    final i = (y * w + x) * 4; d[i] = r; d[i + 1] = g; d[i + 2] = b; d[i + 3] = 255;
  }
}
int _alpha(Uint8List d, int w, int x, int y) => d[(y * w + x) * 4 + 3];
void _expectColorNear(Uint8List d, int w, int x, int y, {required bool red}) {
  final i = (y * w + x) * 4;
  expect(d[i + 3], greaterThan(200));
  if (red) { expect(d[i], greaterThan(180)); expect(d[i + 2], lessThan(100)); }
  else { expect(d[i + 2], greaterThan(180)); expect(d[i], lessThan(100)); }
}
Future<void> _waitForUndo(WidgetTester tester, app_undo.UndoManager undo, int n) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end) && undo.undoCount < n) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10))); await tester.pump();
  }
  expect(undo.undoCount, n);
}
Future<void> _waitForAlpha(WidgetTester tester, dynamic tm, String key, int x, int y, int a) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end)) {
    final tile = tm.getTile(key, 0, 0) as Uint8List?;
    final got = tile == null ? 0 : tile[(y * 256 + x) * 4 + 3];
    if (got == a) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10))); await tester.pump();
  }
  fail('alpha did not become $a at $x,$y');
}
Uint8List _readCanvas(dynamic tm, String key, int w, int h) {
  final out = Uint8List(w * h * 4); final tile = tm.getTile(key, 0, 0) as Uint8List?; if (tile == null) return out;
  for (var y = 0; y < h; y++) out.setRange(y * w * 4, (y + 1) * w * 4, tile, y * 256 * 4);
  return out;
}