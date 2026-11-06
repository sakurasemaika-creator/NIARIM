import 'helpers/project_storage.dart';

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
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 480;
const _h = 200;

/// 組み込みブラシを1つずつ選んで本物のキャンバスへ同じ曲線を描く。
/// どれも例外なく描け、描いた後のタイルが正しい乗算済み（色≤不透明度）で
/// あること、1回の取り消しで消えることを見て、見本を
/// `build/brush-sweep/`へ撮る。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'pen_pressure_enabled': false}),
  );

  testWidgets('every built-in brush draws on the canvas', (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    brushes.setCurrentColor(const Color(0xFF2050C0));
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'brush-sweep',
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
    final boundary = GlobalKey();
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
            body: RepaintBoundary(
              key: boundary,
              child: CanvasArea(
                project: p,
                currentLayerId: layer.id,
                currentTool: DrawingTool.pen,
                currentFrame: 0,
                sceneId: scene.id,
              ),
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

    Future<void> wait(int ms) async {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await tester.pump();
    }

    ({int inked, int invalid}) inspect() {
      var inked = 0;
      var invalid = 0;
      for (var ty = 0; ty < tm.tilesY; ty++) {
        for (var tx = 0; tx < tm.tilesX; tx++) {
          final tile = tm.getTile(key, tx, ty);
          if (tile == null) continue;
          for (var i = 0; i < tile.length; i += 4) {
            final a = tile[i + 3];
            if (a > 0) inked++;
            if (tile[i] > a || tile[i + 1] > a || tile[i + 2] > a) invalid++;
          }
        }
      }
      return (inked: inked, invalid: invalid);
    }

    final out = Directory('build/brush-sweep')..createSync(recursive: true);
    final builtIns = [
      for (final b in brushes.brushes)
        if (brushes.isBuiltIn(b.id)) b,
    ];
    expect(builtIns.length, greaterThanOrEqualTo(25));
    final empty = <String>[];
    for (final brush in builtIns) {
      brushes.selectBrush(brush.id);
      // 画像を使うブラシは選んだときに画像を読み込む。
      await wait(150);
      final g = await tester.startGesture(
        at(const Offset(40, 120)),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      for (var i = 1; i <= 40; i++) {
        final x = 40 + i * 10.0;
        final y = 100 + 50 * (i.isEven ? 0.6 : -0.6) * (i / 40) + i;
        await g.moveTo(at(Offset(x, y.clamp(20, 180))));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      await g.up();
      await wait(150);
      expect(tester.takeException(), isNull, reason: brush.name);
      final r = inspect();
      {
        var minY = 1 << 30, maxY = -1;
        for (var ty = 0; ty < tm.tilesY; ty++) {
          for (var tx = 0; tx < tm.tilesX; tx++) {
            final tile = tm.getTile(key, tx, ty);
            if (tile == null) continue;
            for (var i = 3; i < tile.length; i += 4) {
              if (tile[i] < 8) continue;
              final y = ty * 256 + (i ~/ 4) ~/ 256;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        debugPrint(
          'BBOX ${brush.id} ${brush.name} size=${brush.size} y=$minY..$maxY',
        );
      }
      if (r.inked == 0) empty.add(brush.name);
      expect(r.invalid, 0, reason: '${brush.name}：色が不透明度より大きい画素');
      final png = await tester.runAsync(() async {
        final ro =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await ro.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      File('${out.path}/${brush.id}.png').writeAsBytesSync(png!);
      // 1回の取り消しで消える（次のブラシは白紙から）。
      if (r.inked > 0) {
        expect(undo.canUndo, isTrue, reason: brush.name);
        undo.undo();
        await wait(60);
        expect(inspect().inked, 0, reason: '${brush.name}：取り消し');
      }
      tm.replaceLayerPixels(key, Uint8List(_w * _h * 4));
      undo.clear();
      await wait(30);
    }
    expect(empty, isEmpty, reason: '何も描かれなかったブラシ');
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 8)));
}
