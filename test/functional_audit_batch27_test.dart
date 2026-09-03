import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaで矩形選択の右下ハンドルを2倍へ拡大しUndo/Redoまで全RGBA検証する', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final project = await tester.runAsync(
      () => projects.createProject(
        name: 'selection-scale-functional',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 80,
      ),
    );
    expect(project, isNotNull);
    final p = project!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);

    final initial = Uint8List(96 * 80 * 4);
    // 選択範囲16..48 x 14..46の中央に、補間後の境界判定が明確な16x16単色矩形。
    for (var y = 22; y < 38; y++) {
      for (var x = 24; x < 40; x++) {
        final i = (y * 96 + x) * 4;
        initial[i] = 41;
        initial[i + 1] = 157;
        initial[i + 2] = 223;
        initial[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(key, initial);
    final before = _readCanvas(tm, key, 96, 80);

    final providers = await tester.runAsync(buildAppProviders);
    var selectionActive = false;
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
                child: CanvasArea(
                  project: p,
                  currentLayerId: layer.id,
                  currentTool: DrawingTool.selectRect,
                  currentFrame: 0,
                  sceneId: scene.id,
                  onSelectionActiveChanged: (v) => selectionActive = v,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    final origin = tester.getTopLeft(find.byType(CanvasArea));
    Offset at(Offset canvasPx) =>
        origin + Offset(canvasPx.dx * 3, canvasPx.dy * 3);

    // 選択範囲を確定。
    final select = await tester.startGesture(
      at(const Offset(16, 14)),
      kind: PointerDeviceKind.touch,
    );
    await select.moveTo(at(const Offset(48, 46)));
    await tester.pump();
    await select.up();
    await tester.pump();
    expect(selectionActive, isTrue);

    // bounds=(16,14)-(48,46), center=(32,30), 右下ハンドル=(48,46)。
    // centerからのベクトル(16,16)を(32,32)へ伸ばし、scale=2を厳密に作る。
    final scale = await tester.startGesture(
      at(const Offset(48, 46)),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(
      tm.recordingTouchedTiles,
      isNotNull,
      reason: '右下ハンドルで選択拡大縮小が開始されること',
    );
    await _waitForPixelAlpha(tester, tm, key, 24, 22, 0);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await scale.moveTo(at(const Offset(64, 62)));
    await tester.pump(const Duration(milliseconds: 40));
    await scale.up();
    await tester.pump();
    await _waitForUndo(tester, undo, 1);

    final actual = _readCanvas(tm, key, 96, 80);
    // 元16x16矩形は中心(32,30)基準の2倍変形で概ね32x32になる。
    // rasterizer境界の1px差を避け、内部点と元位置外の拡張点を検証する。
    expect(_alpha(actual, 96, 32, 30), 255);
    expect(_alpha(actual, 96, 18, 16), 255, reason: '2倍拡大で元矩形外まで実画素が広がること');
    expect(_alpha(actual, 96, 46, 44), 255, reason: '右下方向にも2倍拡大されること');
    expect(_alpha(actual, 96, 10, 10), 0);
    expect(
      actual,
      isNot(orderedEquals(before)),
      reason: '拡大縮小が実レイヤー画素へ確定されること',
    );

    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _readCanvas(tm, key, 96, 80),
      orderedEquals(before),
      reason: 'Undoで変形前全RGBAへ完全復元すること',
    );
    undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _readCanvas(tm, key, 96, 80),
      orderedEquals(actual),
      reason: 'Redoで拡大後全RGBAへ完全一致すること',
    );
  });
}

int _alpha(Uint8List rgba, int w, int x, int y) => rgba[(y * w + x) * 4 + 3];

Future<void> _waitForUndo(
  WidgetTester tester,
  app_undo.UndoManager undo,
  int count,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline) && undo.undoCount < count) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(undo.undoCount, count);
}

Future<void> _waitForPixelAlpha(
  WidgetTester tester,
  dynamic tm,
  String key,
  int x,
  int y,
  int expected,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    final tile = tm.getTile(key, x ~/ 256, y ~/ 256) as Uint8List?;
    final alpha = tile == null
        ? 0
        : tile[((y % 256) * 256 + (x % 256)) * 4 + 3];
    if (alpha == expected) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('pixel alpha did not become $expected at ($x,$y)');
}

Uint8List _readCanvas(dynamic tm, String key, int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final tile = tm.getTile(key, x ~/ 256, y ~/ 256) as Uint8List?;
      if (tile == null) continue;
      final si = ((y % 256) * 256 + (x % 256)) * 4;
      final di = (y * w + x) * 4;
      out.setRange(di, di + 4, tile, si);
    }
  }
  return out;
}
