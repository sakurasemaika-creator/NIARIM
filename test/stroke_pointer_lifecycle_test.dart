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

/// ペンの線は、押した指（ペン・マウス）だけが描く。押した時点で描かな
/// かった指（手のひら・フィルターの調整中・ロック中）の動きは何も描かない。
/// 以前は動きだけで線を描き始め（取り消しの記録も無いまま）、OSが指を
/// 取り上げた（PointerCancel）ときは描きかけがそのまま残り、次の線の
/// 記録に混ざって取り消せなかった。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cancelled strokes and refused presses leave nothing', (
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
        name: 'pointer-lifecycle',
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
    var lockInput = false;
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
                  currentTool: DrawingTool.pen,
                  currentFrame: 0,
                  sceneId: scene.id,
                  lockToolInput: lockInput,
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

    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
    }

    Future<void> moveAlong(TestGesture g, double y) async {
      for (var x = 70.0; x <= 230; x += 10) {
        await g.moveTo(at(Offset(x, y)));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
    }

    int inked() {
      var n = 0;
      for (var ty = 0; ty < tm.tilesY; ty++) {
        for (var tx = 0; tx < tm.tilesX; tx++) {
          final tile = tm.getTile(key, tx, ty);
          if (tile == null) continue;
          for (var i = 3; i < tile.length; i += 4) {
            if (tile[i] > 0) n++;
          }
        }
      }
      return n;
    }

    // ── 描いている途中でOSが指を取り上げた：描きかけを残さない ──
    var g = await tester.startGesture(
      at(const Offset(60, 60)),
      kind: PointerDeviceKind.stylus,
    );
    await moveAlong(g, 60);
    expect(inked(), greaterThan(100), reason: '描いている途中は描かれている');
    await g.cancel();
    await settle();
    expect(inked(), 0);
    expect(undo.canUndo, isFalse);

    // 次の線は1回の取り消しでちょうど消える（取り上げた線が混ざらない）。
    g = await tester.startGesture(
      at(const Offset(60, 100)),
      kind: PointerDeviceKind.stylus,
    );
    await moveAlong(g, 100);
    await g.up();
    await settle();
    expect(inked(), greaterThan(100));
    undo.undo();
    await settle();
    expect(inked(), 0);
    expect(undo.canUndo, isFalse);

    // ── ペンを置いたまま手のひらが触れ、ペンを上げた後に手のひらが動く ──
    final pen = await tester.startGesture(
      at(const Offset(60, 140)),
      kind: PointerDeviceKind.stylus,
      pointer: 11,
    );
    await moveAlong(pen, 140);
    final palm = await tester.startGesture(
      at(const Offset(60, 30)),
      kind: PointerDeviceKind.touch,
      pointer: 12,
    );
    await tester.pump();
    await pen.up();
    await settle();
    final afterPen = inked();
    expect(afterPen, greaterThan(100));
    await moveAlong(palm, 30);
    await palm.up();
    await settle();
    expect(inked(), afterPen, reason: '手のひらの動きで線が描かれない');
    undo.undo();
    await settle();
    expect(inked(), 0, reason: 'ペンの線だけが記録されている');

    // ── フィルターの調整中（描画を止めている間）は動いても描かない ──
    rebuild(() => lockInput = true);
    await tester.pump();
    g = await tester.startGesture(
      at(const Offset(60, 80)),
      kind: PointerDeviceKind.touch,
    );
    await moveAlong(g, 80);
    await g.up();
    await settle();
    expect(inked(), 0);
    expect(undo.canUndo, isFalse);

    await tester.pumpWidget(const SizedBox());
  });
}
