import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/models/ruler.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaの垂直直線定規でDownからUpまで全ストロークがx=48付近へ拘束される', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await brushes.init();
    // 通常描画系のCanvasAreaはBrushService.currentBrushを本番と同じ経路で読む。
    // テスト用の仮Brushを作らず、実組み込み既定ブラシをそのまま使う。
    expect(brushes.currentBrush, isNotNull);

    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'ruler-line-functional',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 80,
      ),
    ))!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);
    final providers = await tester.runAsync(buildAppProviders);

    const ruler = Ruler(
      type: RulerType.line,
      position: Offset(48, 40),
      rotation: 1.5707963267948966,
      settings: RulerSettings(),
    );
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
            body: Center(
              child: SizedBox(
                width: 288,
                height: 240,
                child: CanvasArea(
                  project: p,
                  currentLayerId: layer.id,
                  currentTool: DrawingTool.ruler,
                  currentFrame: 0,
                  sceneId: scene.id,
                  activeRuler: ruler,
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
    Offset at(double x, double y) => origin + Offset(x * 3, y * 3);

    // 意図的にガイドから22px右の位置をDown/Moveする。正しくスナップされれば
    // 描画は最初の1pxから最後までx=48近傍だけに現れる。
    final g = await tester.startGesture(
      at(70.0, 18.0),
      kind: PointerDeviceKind.touch,
    );
    for (final y in <double>[28.0, 38.0, 48.0, 58.0, 68.0]) {
      await g.moveTo(at(70.0, y));
      await tester.pump();
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    final rgba = _read(tm, key, 96, 80);
    var offGuide = 0;
    var onGuide = 0;
    var total = 0;
    for (var y = 10; y < 75; y++) {
      for (var x = 0; x < 96; x++) {
        if (rgba[(y * 96 + x) * 4 + 3] == 0) continue;
        total++;
        if ((x - 48).abs() <= 5) {
          onGuide++;
        } else {
          offGuide++;
        }
      }
    }
    expect(total, greaterThan(20), reason: '本番既定ブラシで実ストロークが描かれること');
    expect(onGuide, greaterThan(20), reason: '定規上に実際のブラシ画素が描かれること');
    expect(offGuide, 0, reason: 'Pointer Down直後を含め、定規から離れた画素を1pxも発生させないこと');
  });
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
