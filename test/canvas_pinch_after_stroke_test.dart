import 'helpers/project_storage.dart';

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

const _w = 300;
const _h = 200;

/// 1本目の指で線を描き始めてから2本目の指を置いてピンチ・パンしたら、
/// それは描く操作ではないので、1本目の指の描きかけの線を残さない
/// （DISC080：線が残り、取り消しの記録にもなった）。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a pinch that starts during a stroke leaves no ink', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    brushes.setCurrentColor(const Color(0xFF000000));
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'pinch-after-stroke',
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
    final providers = await tester.runAsync(buildAppProviders);
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
            body: CanvasArea(
              project: p,
              currentLayerId: layer.id,
              currentTool: DrawingTool.pen,
              currentFrame: 0,
              sceneId: scene.id,
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

    Future<void> step() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
    }

    int inked() {
      var n = 0;
      for (var ty = 0; ty < tm.tilesY; ty++) {
        for (var tx = 0; tx < tm.tilesX; tx++) {
          final tile = tm.getTile(key, tx, ty);
          if (tile == null) continue;
          for (var i = 3; i < tile.length; i += 4) {
            if (tile[i] != 0) n++;
          }
        }
      }
      return n;
    }

    final canUndoBefore = undo.canUndo;
    // 1本目の指で線を描き始める。
    final first = await tester.startGesture(
      at(const Offset(80, 100)),
      kind: PointerDeviceKind.touch,
      pointer: 1,
    );
    for (var x = 90.0; x <= 140; x += 10) {
      await first.moveTo(at(Offset(x, 100)));
      await step();
    }
    // 2本目の指を置いて、2本で広げる（ピンチ）。
    final second = await tester.startGesture(
      at(const Offset(200, 120)),
      kind: PointerDeviceKind.touch,
      pointer: 2,
    );
    await step();
    for (var d = 0.0; d <= 40; d += 10) {
      await first.moveTo(at(Offset(140 - d, 100 - d / 2)));
      await second.moveTo(at(Offset(200 + d, 120 + d / 2)));
      await step();
    }
    await first.up();
    await second.up();
    for (var i = 0; i < 6; i++) {
      await step();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();

    expect(inked(), 0, reason: 'the first finger left ink after the pinch');
    expect(undo.canUndo, canUndoBefore, reason: 'the pinch left an undo step');
  });
}
