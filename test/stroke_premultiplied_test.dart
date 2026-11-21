import 'helpers/project_storage.dart';

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 300;
const _h = 200;

/// レイヤーのタイルは乗算済み（premultiplied）RGBAで、画像にするときも
/// そう読まれる。以前はペン・消しゴム・油彩風・水彩風・折り畳みが乗算前の
/// 色を書いていて、半透明の所（不透明度を下げた線・柔らかい縁）が暗い紙の
/// 上で明るく光った（黒い紙の上の不透明度50%の赤が真っ赤に見えた）。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  // 筆圧を切ると「筆圧なし」の混色設定が使われる（マウスで描くので）。
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'pen_pressure_enabled': false}),
  );

  group('TileManager pixel writes stay premultiplied', () {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);

    test('half-opacity paint on a transparent pixel', () {
      final tile = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
      tm.blendPixel(tile, 0, 0, 255, 0, 0, 128);
      expect(tile.sublist(0, 4), [128, 0, 0, 128]);
      // その上へもう一度50%：source-over の乗算済みの式どおり。
      tm.blendPixel(tile, 0, 0, 0, 0, 255, 128);
      expect(tile.sublist(0, 4), [64, 0, 128, 192]);
    });

    test('erasing thins the colour with the alpha', () {
      final tile = Uint8List(TileManager.tileSize * TileManager.tileSize * 4)
        ..setAll(0, [0, 0, 255, 255]);
      tm.erasePixel(tile, 0, 0, 128);
      expect(tile.sublist(0, 4), [0, 0, 127, 127]);
      tm.erasePixel(tile, 0, 0, 255);
      expect(tile.sublist(0, 4), [0, 0, 0, 0]);
    });

    test('premultiplied source keeps itself', () {
      final tile = Uint8List(TileManager.tileSize * TileManager.tileSize * 4)
        ..setAll(0, [0, 0, 255, 255]);
      tm.blendPremultipliedPixel(tile, 0, 0, 128, 0, 0, 128);
      expect(tile.sublist(0, 4), [128, 0, 127, 255]);
    });

    test('a picked colour is the straight colour', () {
      final t = TileManager(canvasWidth: 4, canvasHeight: 4);
      t.getOrCreateTile('L', 0, 0).setAll(0, [128, 0, 0, 128]);
      final c = t.getPixelColorAt('L', 0, 0)!;
      expect((c.r * 255).round(), 255);
      expect((c.a * 255).round(), 128);
    });
  });

  for (final mode in [
    BrushMixingMode.off,
    BrushMixingMode.oil,
    BrushMixingMode.watercolor,
  ]) {
    testWidgets('a half-opacity stroke on black paper (${mode.name})', (
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
      // 組み込みのブラシは書き換えられないので、複製を足して使う。
      var serial = 0;
      void useBrush(Brush brush) {
        final id = 'premultiplied-${serial++}';
        brushes.addBrush(brush.copyWith(id: id));
        brushes.selectBrush(id);
      }

      final base = brushes.currentBrush!;
      useBrush(
        base.copyWith(
          opacity: 50,
          size: 24,
          pressureOff: base.pressureOff.copyWith(
            mixing: base.pressureOff.mixing.copyWith(
              enabled: mode != BrushMixingMode.off,
              mode: mode,
              rate: 50,
            ),
          ),
        ),
      );
      brushes.setCurrentColor(const Color(0xFFFF0000));
      final p = (await tester.runAsync(
        () => projects.createProject(
          name: 'premultiplied',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFF000000,
          exportWidth: _w,
          exportHeight: _h,
        ),
      ))!;
      final scene = projects.scenesOf(p.id).first;
      final layer = projects.layersOf(p.id, scene.id, 0).first;
      final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
      final tm = projects.tileManagerOf(p.id);
      final providers = await tester.runAsync(buildAppProviders);
      var eraser = false;
      late StateSetter rebuild;
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
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return CanvasArea(
                      project: p,
                      currentLayerId: layer.id,
                      currentTool: DrawingTool.pen,
                      isEraser: eraser,
                      currentFrame: 0,
                      sceneId: scene.id,
                    );
                  },
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

      Future<void> stroke(double y) async {
        final g = await tester.startGesture(
          at(Offset(40, y)),
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton,
        );
        for (var x = 45.0; x <= 260; x += 5) {
          await g.moveTo(at(Offset(x, y)));
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
        }
        await g.up();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump();
      }

      void expectPremultiplied(String when) {
        var bad = 0;
        var inked = 0;
        final tile = tm.getTile(key, 0, 0);
        expect(tile, isNotNull, reason: when);
        for (var i = 0; i < tile!.length; i += 4) {
          final a = tile[i + 3];
          if (a > 0) inked++;
          if (tile[i] > a || tile[i + 1] > a || tile[i + 2] > a) bad++;
        }
        expect(inked, greaterThan(500), reason: when);
        expect(bad, 0, reason: '$when：色が不透明度より大きい画素');
      }

      await stroke(100);
      expect(tester.takeException(), isNull);
      expectPremultiplied('描いた後');

      final shot = await tester.runAsync(() async {
        final ro =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await ro.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final width = image.width;
        image.dispose();
        return (data!.buffer.asUint8List(), png!.buffer.asUint8List(), width);
      });
      final dir = Directory('build/stroke-premultiplied')
        ..createSync(recursive: true);
      File('${dir.path}/${mode.name}.png').writeAsBytesSync(shot!.$2);
      final pos = at(const Offset(150, 100));
      final j = (pos.dy.round() * shot.$3 + pos.dx.round()) * 4;
      final red = shot.$1[j];
      // 黒の上の50%の赤は暗い赤（水彩風は紙の目で濃さが揺れるので幅を持たせる）。
      expect(red, inInclusiveRange(40, 200), reason: '画面の赤 $red');
      expect(shot.$1[j + 1], lessThan(40));

      // 柔らかい消しゴムで線の真ん中を消しても、縁は正しい乗算済みのまま。
      rebuild(() => eraser = true);
      final current = brushes.currentBrush!;
      useBrush(
        current.copyWith(
          opacity: 60,
          pressureOff: current.pressureOff.copyWith(
            mixing: current.pressureOff.mixing.copyWith(enabled: false),
          ),
        ),
      );
      await tester.pump();
      await stroke(104);
      expectPremultiplied('消した後');

      await tester.pumpWidget(const SizedBox());
    });
  }
}
