import 'helpers/project_storage.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 600;
const _h = 300;

/// レイヤーの「ロック」は描画・移動・変形を止め、「不透明度ロック」は
/// 透明な所へ描かず各画素の不透明度を変えない（レイヤー仕様）。
/// 以前はどちらもスイッチと印だけで、描くと普通に描けていた。
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TileManager.opacityLocked', () {
    Uint8List px(List<int> rgba) => Uint8List.fromList(rgba);

    test('transparent stays transparent, opaque takes the paint', () {
      expect(TileManager.opacityLocked(px([200, 0, 0, 200]), null), isNull);
      expect(
        TileManager.opacityLocked(px([200, 0, 0, 200]), px([0, 0, 0, 0])),
        [0, 0, 0, 0],
      );
      expect(
        TileManager.opacityLocked(px([255, 0, 0, 255]), px([0, 0, 255, 255])),
        [255, 0, 0, 255],
      );
    });

    test('half-transparent keeps its alpha and takes the colour (atop)', () {
      // 半透明（50%）の青に、不透明な赤を source-over で描いた後の画素。
      final locked = TileManager.opacityLocked(
        px([255, 0, 0, 255]),
        px([0, 0, 128, 128]),
      )!;
      expect(locked[3], 128);
      expect(locked[0], 128, reason: '赤が不透明度の中にだけ乗る');
      expect(locked[2], 0);
      // 50%の赤を source-over で描いた後：source-atop と同じ結果になる。
      // 前：青(0,0,128,128)。赤50%を重ねると(128,0,64,192)。
      final half = TileManager.opacityLocked(
        px([128, 0, 64, 192]),
        px([0, 0, 128, 128]),
      )!;
      expect(half[3], 128);
      expect(half[0], closeTo(64, 1));
      expect(half[2], closeTo(64, 1));
    });

    test('erasing changes nothing', () {
      final before = px([0, 0, 200, 200]);
      final erased = px([0, 0, 50, 50]);
      expect(TileManager.opacityLocked(erased, before), before);
      expect(TileManager.opacityLocked(null, before), before);
    });
  });

  testWidgets('drawing on locked / opacity-locked layers', (tester) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    brushes.setCurrentColor(const Color(0xFFFF0000));
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'layer-lock',
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

    // 不透明な青（タイルの境目x=256をまたぐ）と半透明の青を置いておく。
    final original = Uint8List(_w * _h * 4);
    for (var y = 100; y < 200; y++) {
      for (var x = 150; x < 350; x++) {
        final i = (y * _w + x) * 4;
        original[i + 2] = 255;
        original[i + 3] = 255;
      }
      for (var x = 400; x < 450; x++) {
        final i = (y * _w + x) * 4;
        original[i + 2] = 128;
        original[i + 3] = 128;
      }
    }
    void resetPixels() {
      tm.replaceLayerPixels(key, Uint8List.fromList(original));
      undo.clear();
    }

    resetPixels();
    final providers = await tester.runAsync(buildAppProviders);
    var tool = DrawingTool.pen;
    var eraser = false;
    var lockedNotices = 0;
    var selectionActive = false;
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
                  project: projects.projects.firstWhere((e) => e.id == p.id),
                  currentLayerId: layer.id,
                  currentTool: tool,
                  isEraser: eraser,
                  currentFrame: 0,
                  sceneId: scene.id,
                  onLockedLayerEdit: () => lockedNotices++,
                  onSelectionActiveChanged: (v) => selectionActive = v,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    final area = find.byType(CanvasArea);
    Offset onScreen(Offset canvasPoint) {
      final rect = canvasDrawingRectFor(tester.getSize(area), p);
      return tester.getTopLeft(area) +
          rect.topLeft +
          canvasPoint * (rect.width / _w);
    }

    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
    }

    /// y=150を左から右へ（透明→不透明→タイルの境目→半透明→透明）。
    Future<TestGesture> strokeAcross({bool lift = true}) async {
      final g = await tester.startGesture(
        onScreen(const Offset(100, 150)),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      for (var x = 110.0; x <= 500; x += 10) {
        await g.moveTo(onScreen(Offset(x, 150)));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      if (lift) {
        await g.up();
        await settle();
      }
      return g;
    }

    Uint8List read() => _readLayer(tm, key);
    int alphaAt(Uint8List rgba, int x, int y) => rgba[(y * _w + x) * 4 + 3];

    Future<void> setLayer({bool locked = false, bool opacity = false}) async {
      final current = projects.layersOf(p.id, scene.id, 0).first;
      projects.updateLayer(
        projectId: p.id,
        sceneId: scene.id,
        frameIndex: 0,
        layer: current.copyWith(isLocked: locked, opacityLocked: opacity),
      );
      rebuild(() {});
      await tester.pump();
    }

    // ── 何もロックしていなければ、透明な所にも描ける（対照） ──
    await strokeAcross();
    var rgba = read();
    expect(alphaAt(rgba, 120, 150), greaterThan(200));
    expect(undo.canUndo, isTrue);
    resetPixels();
    await settle();

    // ── 不透明度ロック：描いている途中から、透明な所は透明のまま ──
    await setLayer(opacity: true);
    final g = await strokeAcross(lift: false);
    final live = await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    expect(
      alphaAt(read(), 120, 150),
      greaterThan(0),
      reason: 'タイルにはロック前の描きかけがある',
    );
    expect(alphaAt(live!, 120, 150), 0, reason: '画面に出る合成ではロック済み');
    expect(live[(150 * _w + 300) * 4], greaterThan(200), reason: '不透明な所は赤');
    await g.up();
    await settle();
    expect(tester.takeException(), isNull);

    rgba = read();
    var changedAlpha = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != original[i]) changedAlpha++;
    }
    expect(changedAlpha, 0, reason: 'どの画素の不透明度も変わらない');
    for (final x in [200, 255, 256, 300]) {
      final i = (150 * _w + x) * 4;
      expect(rgba[i], greaterThan(200), reason: 'x=$x：赤くなる');
      expect(rgba[i + 2], lessThan(60), reason: 'x=$x：青が残らない');
    }
    final half = (150 * _w + 425) * 4;
    expect(rgba[half + 3], 128);
    expect(rgba[half], greaterThan(100), reason: '半透明の所も赤くなる');
    expect(alphaAt(rgba, 120, 150), 0);
    expect(alphaAt(rgba, 480, 150), 0);
    // 塗っていない所の色は元のまま。
    expect(rgba[(110 * _w + 200) * 4 + 2], 255);

    // 1回の取り消しで元どおり。
    undo.undo();
    await settle();
    expect(read(), original);
    expect(undo.canUndo, isFalse);

    // ── 不透明度ロックの消しゴムは何も変えない ──
    rebuild(() => eraser = true);
    await tester.pump();
    await strokeAcross();
    expect(read(), original);
    rebuild(() => eraser = false);
    await tester.pump();
    resetPixels();
    await settle();

    // ── ロック：描く・塗る・動かすは何もせずに知らせる ──
    await setLayer(locked: true);
    for (final t in [DrawingTool.pen, DrawingTool.bucket, DrawingTool.move]) {
      rebuild(() => tool = t);
      await tester.pump();
      final before = lockedNotices;
      await strokeAcross();
      expect(read(), original, reason: '$t');
      expect(lockedNotices, greaterThan(before), reason: '$t');
    }
    expect(undo.canUndo, isFalse);
    // 範囲を選ぶだけなら絵は変わらないので使える。
    rebuild(() => tool = DrawingTool.selectRect);
    await tester.pump();
    final notices = lockedNotices;
    final drag = await tester.startGesture(
      onScreen(const Offset(160, 110)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await drag.moveTo(onScreen(const Offset(220, 140)));
    await tester.pump();
    await drag.moveTo(onScreen(const Offset(300, 190)));
    await tester.pump();
    await drag.up();
    await settle();
    await tester.pump();
    expect(selectionActive, isTrue);
    expect(lockedNotices, notices);
    // 選んだ範囲の中を押して動かそうとすると止める。
    final move = await tester.startGesture(
      onScreen(const Offset(230, 150)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await move.moveTo(onScreen(const Offset(260, 160)));
    await tester.pump();
    await move.up();
    await settle();
    expect(lockedNotices, greaterThan(notices));
    expect(read(), original);

    await tester.pumpWidget(const SizedBox());
  });
}

Uint8List _readLayer(TileManager tm, String key) {
  final out = Uint8List(_w * _h * 4);
  for (var ty = 0; ty < tm.tilesY; ty++) {
    for (var tx = 0; tx < tm.tilesX; tx++) {
      final tile = tm.getTile(key, tx, ty);
      if (tile == null) continue;
      for (var y = 0; y < TileManager.tileSize; y++) {
        final cy = ty * TileManager.tileSize + y;
        if (cy >= _h) break;
        for (var x = 0; x < TileManager.tileSize; x++) {
          final cx = tx * TileManager.tileSize + x;
          if (cx >= _w) break;
          final s = (y * TileManager.tileSize + x) * 4;
          final d = (cy * _w + cx) * 4;
          out[d] = tile[s];
          out[d + 1] = tile[s + 1];
          out[d + 2] = tile[s + 2];
          out[d + 3] = tile[s + 3];
        }
      }
    }
  }
  return out;
}
