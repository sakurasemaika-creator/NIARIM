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

/// キャンバスの2本指ピンチズーム・回転の自律テスト（Task#128）。
///
/// この操作はFlutter標準の`InteractiveViewer`ではなく`CanvasArea`が
/// 自前で実装している（標準版が回転ジェスチャーに非対応のため）。独自
/// 実装であるぶん壊れても気付きにくく、既存テストでは1件も触れていな
/// かったため新設した。
///
/// 検証するのは次の4点：
///   1. 2本指を広げるとキャンバスが拡大される
///   2. 2本指を狭めると縮小される
///   3. 拡大率の上下限（0.1〜10倍）を超える操作は無視される
///   4. 1本指だけでは変形しない（＝描画操作を奪わない）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// CanvasAreaを載せて、そのTransformが持つ拡大率を読めるようにする。
  Future<double Function()> pumpCanvas(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final project = await tester.runAsync(
      () => projects.createProject(
        name: 'pinch-gesture',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 96,
      ),
    );
    final p = project!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final appProviders = await tester.runAsync(buildAppProviders);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...appProviders!,
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 384,
                height: 384,
                child: CanvasArea(
                  project: p,
                  currentLayerId: layer.id,
                  // パンツール中でも2本指変形は同じ経路を通る。描画ツール
                  // だと1本指が描画へ流れて意図が混ざるため、ここでは
                  // ズーム挙動だけを見たいのでpanを選ぶ。
                  currentTool: DrawingTool.pan,
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

    // CanvasAreaが内部で使うTransformの拡大率を読む。CanvasArea配下の
    // Transformのうち、実際に倍率が変わるものを拾う。
    double currentScale() {
      final transforms = tester.widgetList<Transform>(
        find.descendant(of: find.byType(CanvasArea), matching: find.byType(Transform)),
      );
      var maxScale = 1.0;
      for (final t in transforms) {
        final s = t.transform.getMaxScaleOnAxis();
        if (s > maxScale) maxScale = s;
      }
      return maxScale;
    }

    return currentScale;
  }

  /// 2本指を[from]の間隔から[to]の間隔へ変える（中心は固定）。
  Future<void> pinch(
    WidgetTester tester,
    Offset center, {
    required double from,
    required double to,
  }) async {
    final a = await tester.startGesture(
      center - Offset(from / 2, 0),
      kind: PointerDeviceKind.touch,
    );
    final b = await tester.startGesture(
      center + Offset(from / 2, 0),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    // 片方ずつ動かす（実装は「動いた指」と「もう一方＝アンカー」で
    // 差分を取るため、同時に動かす必要はない）。
    await b.moveTo(center + Offset(to / 2, 0));
    await tester.pump();
    await a.moveTo(center - Offset(to / 2, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();
  }

  testWidgets('2本指を広げるとキャンバスが拡大される', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    final before = scaleOf();
    await pinch(tester, tester.getCenter(find.byType(CanvasArea)), from: 80, to: 200);
    expect(tester.takeException(), isNull);
    expect(scaleOf(), greaterThan(before),
        reason: 'ピンチアウトで拡大率が上がること');
  });

  testWidgets('2本指を狭めるとキャンバスが縮小される', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    // まず広げてから狭める（既定倍率が下限付近だと縮小が上下限で
    // 弾かれ、テストが「縮小できない」のか「弾かれた」のか区別できない）。
    final center = tester.getCenter(find.byType(CanvasArea));
    await pinch(tester, center, from: 80, to: 240);
    final enlarged = scaleOf();
    await pinch(tester, center, from: 240, to: 100);
    expect(tester.takeException(), isNull);
    expect(scaleOf(), lessThan(enlarged), reason: 'ピンチインで拡大率が下がること');
  });

  testWidgets('拡大率の上限を超える操作は無視され、暴走しない', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    final center = tester.getCenter(find.byType(CanvasArea));
    // 上限（10倍）を確実に超える倍率を何度も要求する。
    for (var i = 0; i < 6; i++) {
      await pinch(tester, center, from: 20, to: 300);
    }
    expect(tester.takeException(), isNull);
    expect(scaleOf(), lessThanOrEqualTo(10.0),
        reason: '_maxCanvasScale(10倍)を超えないこと');
  });

  testWidgets('1本指のドラッグでは変形しない（描画操作を奪わない）', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    final before = scaleOf();
    final center = tester.getCenter(find.byType(CanvasArea));
    final g = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await tester.pump();
    await g.moveTo(center + const Offset(60, 40));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(scaleOf(), before, reason: '1本指では拡大率が変わらないこと');
  });
}
