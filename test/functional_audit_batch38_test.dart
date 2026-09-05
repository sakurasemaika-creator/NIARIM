import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart'
    show DrawingTool, SelectionTransformMode;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 独立した「変形ツール」（DrawingTool.transform）は選択ツールへ統合した。
  // レイヤー全体の変形は「全選択」＋左下の拡大縮小モードで行う経路になったので、
  // その経路が実画素まで到達することをここで見張る。
  testWidgets('全選択＋拡大縮小モードでレイヤー全体をタッチ操作で縮小できUndo/Redoできる', (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ps = ProjectService();
    final undo = app_undo.UndoManager();
    ps.setUndoManager(undo);
    final p = (await tester.runAsync(
      () => ps.createProject(
        name: 'whole-transform-functional',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 80,
      ),
    ))!;
    final scene = ps.scenesOf(p.id).first;
    final layer = ps.layersOf(p.id, scene.id, 0).first;
    final key = ps.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = ps.tileManagerOf(p.id);
    final initial = Uint8List(96 * 80 * 4);
    // 中心(48,40)から右下側に非対称矩形。縮小後の位置/面積を判定しやすくする。
    for (var y = 44; y < 68; y++) {
      for (var x = 54; x < 86; x++) {
        final i = (y * 96 + x) * 4;
        initial[i] = 220;
        initial[i + 1] = 55;
        initial[i + 2] = 40;
        initial[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(key, initial);
    final before = _read(tm, key, 96, 80);
    final beforeCount = _opaque(before);

    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: ps),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 288,
                  height: 240,
                  child: _SelectionTransformHarness(
                    project: p,
                    layerId: layer.id,
                    sceneId: scene.id,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => _capture(boundaryKey, '${out.path}/transform_whole_before_ui.png'),
    );

    // 「全選択」ボタン相当（selectAllSelectionToken）でレイヤー全体を選択範囲にする。
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(CanvasArea));
    Offset at(double x, double y) => origin + Offset(x * 3, y * 3);

    // 拡大縮小モードでは選択範囲の内側どこを掴んでもよい。中心(48,40)から
    // 見て距離が0.6倍になる位置までドラッグし、約0.6倍へ縮小する。
    // キャンバス左右端32pxはダブルタップ専用ゾーンなので、掴む位置は
    // ウィジェット座標で32〜256pxの内側（＝キャンバス座標で約11〜85）に収める。
    final g = await tester.startGesture(
      at(80.0, 60.0),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    // 掴んだ瞬間に選択範囲の中身を切り取る「浮動画像」の生成
    // （compositeLayerToImage→toByteData→decodeImageFromPixels）が走る。
    // これはFakeAsyncでは進まないので実時間で待つ（CLAUDE.md参照）。
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await g.moveTo(at(67.2, 52.0));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump();
    await _waitUndo(tester, undo, 1);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(
      () => _capture(boundaryKey, '${out.path}/transform_whole_after_ui.png'),
    );

    final after = _read(tm, key, 96, 80);
    final afterCount = _opaque(after);
    expect(
      after,
      isNot(orderedEquals(before)),
      reason: '全選択＋拡大縮小モードのタッチドラッグが実画素変形へ到達すること',
    );
    expect(
      afterCount,
      lessThan(beforeCount * 0.65),
      reason: '中心へドラッグしたため実画素面積が明確に縮小すること',
    );
    expect(afterCount, greaterThan(beforeCount * 0.20));

    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm, key, 96, 80), orderedEquals(before));
    undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm, key, 96, 80), orderedEquals(after));
  });
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
}

int _opaque(Uint8List d) {
  var n = 0;
  for (var i = 3; i < d.length; i += 4) {
    if (d[i] != 0) n++;
  }
  return n;
}

Future<void> _waitUndo(WidgetTester t, app_undo.UndoManager u, int n) async {
  final e = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(e) && u.undoCount < n) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
  expect(u.undoCount, n, reason: '変形操作がUndo履歴へ確定すること');
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

/// 「全選択」ボタン（canvas_screen.dartの左下バー）に相当するトークン更新と、
/// 拡大縮小モードの指定を再現する最小のテスト用ラッパー。
class _SelectionTransformHarness extends StatefulWidget {
  const _SelectionTransformHarness({
    required this.project,
    required this.layerId,
    required this.sceneId,
  });

  final dynamic project;
  final String layerId;
  final String sceneId;

  @override
  State<_SelectionTransformHarness> createState() =>
      _SelectionTransformHarnessState();
}

class _SelectionTransformHarnessState
    extends State<_SelectionTransformHarness> {
  int _selectAllToken = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CanvasArea(
          project: widget.project,
          currentLayerId: widget.layerId,
          currentTool: DrawingTool.selectRect,
          currentFrame: 0,
          sceneId: widget.sceneId,
          selectAllSelectionToken: _selectAllToken,
          selectionTransformMode: SelectionTransformMode.scale,
        ),
        Positioned(
          right: 0,
          top: 0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: GestureDetector(
              key: const ValueKey('select-all'),
              onTap: () => setState(() => _selectAllToken++),
            ),
          ),
        ),
      ],
    );
  }
}
