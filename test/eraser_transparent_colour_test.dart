import 'helpers/project_storage.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 300;
const _h = 160;

/// 消しゴム・透明色（A015）。選んだ色の不透明度は線に効き、透明色を
/// 選んだペンは消しゴムとして消す（以前は色の不透明度を無視して不透明に
/// 塗り、透明色では下に隠れていた色で塗っていた）。消しゴムは不透明度
/// だけを下げ、色はそのまま。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'pen_pressure_enabled': false}),
  );

  test('a half-transparent colour paints at half strength', () async {
    final service = BrushService();
    await service.init();
    final tm = TileManager(canvasWidth: 100, canvasHeight: 100);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = service.brushes.first.copyWith(size: 20, opacity: 100)
      ..currentColor = const ui.Color(0x80FF0000)
      ..pressureEnabled = false;
    StrokePoint p(double x) =>
        StrokePoint(x: x, y: 50, pressure: 1, tiltX: 0, tiltY: 0);
    engine.beginStroke(p(10), 'L');
    engine.continueStroke(p(50), 'L');
    engine.continueStroke(p(90), 'L');
    engine.endStroke();
    final tile = tm.getTile('L', 0, 0)!;
    final i = (50 * 256 + 50) * 4;
    expect(tile[i + 3], inInclusiveRange(110, 150), reason: '不透明度は約半分');
    expect(tile[i], lessThanOrEqualTo(tile[i + 3]));
  });

  testWidgets('a transparent pen erases; the eraser keeps the colour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'eraser',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);
    // 不透明な緑の帯（乗算済み）。
    final original = Uint8List(_w * _h * 4);
    for (var y = 50; y < 110; y++) {
      for (var x = 0; x < _w; x++) {
        final i = (y * _w + x) * 4;
        original[i + 1] = 200;
        original[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(key, Uint8List.fromList(original));
    final providers = await tester.runAsync(buildAppProviders);
    var eraser = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return CanvasArea(
                  project: p,
                  currentLayerId: layer.id,
                  currentTool: eraser ? DrawingTool.eraser : DrawingTool.pen,
                  isEraser: eraser,
                  currentFrame: 0,
                  sceneId: scene.id,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final area = find.byType(CanvasArea);
    Offset at(Offset c) {
      final r = canvasDrawingRectFor(tester.getSize(area), p);
      return tester.getTopLeft(area) + r.topLeft + c * (r.width / _w);
    }

    Future<void> stroke() async {
      final g = await tester.startGesture(
        at(const Offset(30, 80)),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      for (var x = 40.0; x <= 270; x += 10) {
        await g.moveTo(at(Offset(x, 80)));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
    }

    List<int> pixel(int x, int y) {
      final tile = tm.getTile(key, x ~/ 256, y ~/ 256)!;
      final i = (((y % 256) * 256) + (x % 256)) * 4;
      return tile.sublist(i, i + 4);
    }

    // ── 透明色のペン：消える（赤で塗らない） ──
    brushes.setCurrentColor(const Color(0x00FF0000));
    await stroke();
    expect(pixel(150, 80)[3], 0, reason: '透明色のペンは消す');
    expect(pixel(150, 80)[0], 0, reason: '隠れた赤で塗らない');
    expect(pixel(150, 105)[3], 255, reason: '線の外は残る');
    undo.undo();
    await tester.pump();
    expect(pixel(150, 80), [0, 200, 0, 255], reason: '1回の取り消しで戻る');

    // ── 消しゴム（不透明度50%）：不透明度だけ下がり、色は緑のまま ──
    brushes.setCurrentColor(const Color(0xFFFF0000));
    final pen = brushes.currentBrush!;
    brushes.addBrush(pen.copyWith(id: 'half-eraser', opacity: 50));
    brushes.selectBrush('half-eraser');
    rebuild(() => eraser = true);
    await tester.pump();
    await stroke();
    final erased = pixel(150, 80);
    expect(erased[3], inExclusiveRange(60, 200), reason: '半分ほど消える');
    expect(erased[0], 0, reason: '赤が混ざらない');
    expect(erased[2], 0);
    // 色（割り戻した緑）は元のまま。
    expect(erased[1] * 255 / erased[3], closeTo(200, 3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
