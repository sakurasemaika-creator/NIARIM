import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaぼかしツールで高周波チェッカーの局所コントラストが下がり範囲外は不変', (tester) async {
    final r = await _operate(tester, DrawingTool.blur, brushSize: 20);
    await tester.runAsync(
      () => _save(r.after, 96, 80, '${out.path}/canvas_blur_real.png'),
    );
    final c0 = _rgb(r.before, 96, 48, 40);
    final c1 = _rgb(r.before, 96, 49, 40);
    final a0 = _rgb(r.after, 96, 48, 40);
    final a1 = _rgb(r.after, 96, 49, 40);
    expect(
      _distance(a0, a1),
      lessThan(_distance(c0, c1) * 0.5),
      reason: 'ぼかし中心では隣接白黒の色差が大きく減ること',
    );
    expect(
      _rgba(r.after, 96, 5, 5),
      _rgba(r.before, 96, 5, 5),
      reason: 'ブラシ円から遠い画素は1byteも変わらないこと',
    );
    r.undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(r.tm, r.key, 96, 80), orderedEquals(r.before));
    r.undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(r.tm, r.key, 96, 80), orderedEquals(r.after));
  });

  testWidgets('実CanvasAreaモザイクツールで隣接画素が同一ブロック色へ量子化され範囲外は不変', (tester) async {
    final r = await _operate(tester, DrawingTool.mosaic, brushSize: 20);
    await tester.runAsync(
      () => _save(r.after, 96, 80, '${out.path}/canvas_mosaic_real.png'),
    );
    // radius=30, region minX=18/minY=10, blockSize=2。中心local(30,30)と右隣は同じ2pxブロック。
    expect(
      _rgb(r.after, 96, 48, 40),
      _rgb(r.after, 96, 49, 40),
      reason: 'モザイク中心で元は異なる隣接画素が同一ブロック色になること',
    );
    expect(_rgb(r.before, 96, 48, 40), isNot(_rgb(r.before, 96, 49, 40)));
    expect(_rgba(r.after, 96, 5, 5), _rgba(r.before, 96, 5, 5));
    r.undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(r.tm, r.key, 96, 80), orderedEquals(r.before));
    r.undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(r.tm, r.key, 96, 80), orderedEquals(r.after));
  });
}

typedef _Result = ({
  dynamic tm,
  String key,
  Uint8List before,
  Uint8List after,
  app_undo.UndoManager undo,
});
Future<_Result> _operate(
  WidgetTester tester,
  DrawingTool tool, {
  required double brushSize,
}) async {
  tester.view.physicalSize = const Size(480, 360);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final projects = ProjectService();
  final undo = app_undo.UndoManager();
  projects.setUndoManager(undo);
  final bs = BrushService();
  await bs.init();
  bs.updateCurrentBrushSize(brushSize);
  final p = (await tester.runAsync(
    () => projects.createProject(
      name: 'blur-mosaic',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0x00000000,
      exportWidth: 96,
      exportHeight: 80,
    ),
  ))!;
  final scene = projects.scenesOf(p.id).first,
      layer = projects.layersOf(p.id, scene.id, 0).first;
  final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id),
      tm = projects.tileManagerOf(p.id);
  final initial = Uint8List(96 * 80 * 4);
  for (var y = 0; y < 80; y++)
    for (var x = 0; x < 96; x++) {
      final i = (y * 96 + x) * 4;
      final v = (x + y).isEven ? 20 : 235;
      initial[i] = v;
      initial[i + 1] = v;
      initial[i + 2] = v;
      initial[i + 3] = 255;
    }
  tm.replaceLayerPixels(key, initial);
  final before = _read(tm, key, 96, 80);
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ...providers!,
        ChangeNotifierProvider<ProjectService>.value(value: projects),
        ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
        ChangeNotifierProvider<BrushService>.value(value: bs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              height: 240,
              child: CanvasArea(
                project: p,
                currentLayerId: layer.id,
                currentTool: tool,
                currentFrame: 0,
                sceneId: scene.id,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  final origin = tester.getTopLeft(find.byType(CanvasArea));
  final pos = origin + const Offset(48 * 3, 40 * 3);
  final g = await tester.startGesture(pos, kind: PointerDeviceKind.touch);
  await tester.pump();
  await g.up();
  await tester.pump();
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end) && undo.undoCount < 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(undo.undoCount, 1);
  final after = _read(tm, key, 96, 80);
  expect(after, isNot(orderedEquals(before)));
  return (tm: tm, key: key, before: before, after: after, undo: undo);
}

List<int> _rgb(Uint8List d, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return [d[i], d[i + 1], d[i + 2]];
}

List<int> _rgba(Uint8List d, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return [d[i], d[i + 1], d[i + 2], d[i + 3]];
}

double _distance(List<int> a, List<int> b) =>
    ((a[0] - b[0]).abs() + (a[1] - b[1]).abs() + (a[2] - b[2]).abs())
        .toDouble();
Uint8List _read(dynamic tm, String key, int w, int h) {
  final o = Uint8List(w * h * 4);
  final tile = tm.getTile(key, 0, 0) as Uint8List?;
  if (tile == null) return o;
  for (var y = 0; y < h; y++)
    o.setRange(y * w * 4, (y + 1) * w * 4, tile, y * 256 * 4);
  return o;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final b = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    b,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final c = await desc.instantiateCodec();
  final f = await c.getNextFrame();
  final png = await f.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  f.image.dispose();
  c.dispose();
  desc.dispose();
  b.dispose();
}
