import 'dart:math' as math;

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
/// 実装であるぶん壊れても気付きにくいため、倍率境界と最小倍率時の回転を
/// 実ポインター入力で固定する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

    double currentScale() => canvasViewScaleOf(_viewMatrix(tester));
    return currentScale;
  }

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
    await pinch(
      tester,
      tester.getCenter(find.byType(CanvasArea)),
      from: 80,
      to: 200,
    );
    expect(tester.takeException(), isNull);
    expect(scaleOf(), greaterThan(before), reason: 'ピンチアウトで拡大率が上がること');
  });

  testWidgets('2本指を狭めるとキャンバスが縮小される', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    final center = tester.getCenter(find.byType(CanvasArea));
    await pinch(tester, center, from: 80, to: 240);
    final enlarged = scaleOf();
    await pinch(tester, center, from: 240, to: 100);
    expect(tester.takeException(), isNull);
    expect(scaleOf(), lessThan(enlarged), reason: 'ピンチインで拡大率が下がること');
  });

  testWidgets('下限未満の縮小要求は0.2倍へ正確にクランプされる', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    final center = tester.getCenter(find.byType(CanvasArea));
    // CanvasAreaは指間4px未満を角度計算の不安定域として無視する。
    // その有効域の端（4px）でも要求倍率は4/200=0.02で十分に下限未満。
    await pinch(tester, center, from: 200, to: 4);
    expect(tester.takeException(), isNull);
    expect(
      scaleOf(),
      closeTo(kCanvasMinScale, 0.001),
      reason: '下限未満を要求しても1/5より小さくならず、境界値へ到達すること',
    );
  });

  testWidgets('0.2倍へ到達する同一ジェスチャーでも45度回転は保持される', (tester) async {
    await pumpCanvas(tester);
    final center = tester.getCenter(find.byType(CanvasArea));
    final anchor = center - const Offset(60, 0);
    final movingStart = center + const Offset(60, 0);
    final atMinScale = anchor + const Offset(24, 0);
    final rotatedAtMinScale = anchor + Offset.fromDirection(math.pi / 4, 24);

    final fixed = await tester.startGesture(
      anchor,
      kind: PointerDeviceKind.touch,
    );
    final moving = await tester.startGesture(
      movingStart,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    // 実際の連続ピンチと同様、まず下限へ到達してから同じ2本指を離さず回す。
    await moving.moveTo(atMinScale);
    await tester.pump();
    await moving.moveTo(rotatedAtMinScale);
    await tester.pump();
    await moving.up();
    await fixed.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final matrix = _viewMatrix(tester);
    expect(canvasViewScaleOf(matrix), closeTo(kCanvasMinScale, 0.001));
    final angle = math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
    expect(
      _angleDelta(angle, math.pi / 4).abs(),
      lessThan(0.02),
      reason: '最小倍率へのクランプで同時入力された回転を捨てないこと',
    );
  });

  testWidgets('拡大率の上限を超える要求は10倍へクランプされ、暴走しない', (tester) async {
    final scaleOf = await pumpCanvas(tester);
    final center = tester.getCenter(find.byType(CanvasArea));
    for (var i = 0; i < 6; i++) {
      await pinch(tester, center, from: 20, to: 300);
    }
    expect(tester.takeException(), isNull);
    expect(
      scaleOf(),
      lessThanOrEqualTo(kCanvasMaxScale + 0.001),
      reason: '10倍を超えないこと',
    );
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

Matrix4 _viewMatrix(WidgetTester tester) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(CanvasArea),
      matching: find.byType(Transform),
    ),
  );
  expect(transforms, isNotEmpty, reason: 'CanvasArea内部の表示Transformが存在すること');
  return transforms.first.transform.clone();
}

double _angleDelta(double a, double b) {
  var d = a - b;
  while (d > math.pi) {
    d -= math.pi * 2;
  }
  while (d < -math.pi) {
    d += math.pi * 2;
  }
  return d;
}
