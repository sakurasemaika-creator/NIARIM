import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// キャンバスの「1/5縮小 + 斜め回転 + 背景端パン制限」を、実際のポインター
/// 操作とPNGの両方で監査する。
///
/// 通常描画範囲(drawingAreaScale=1)と拡張描画範囲(=2)を分け、
/// ±30/45/60/90度をそれぞれ独立状態から操作する。拡張描画範囲はCanvasArea
/// 本体のTransformに含まれるためキャンバスと一緒に回転し、そのさらに外側の
/// 安全背景はTransform外の固定レイヤーとして画面を覆い続ける。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final out = Directory('build/visual-reaudit/canvas-angle-boundary');

  setUpAll(() {
    out.createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const cases = <({int degrees, Offset pan})>[
    (degrees: 30, pan: Offset(5000, 0)),
    (degrees: 45, pan: Offset(-5000, -5000)),
    (degrees: 60, pan: Offset(5000, 5000)),
    (degrees: 90, pan: Offset(0, -5000)),
    (degrees: -30, pan: Offset(-5000, 0)),
    (degrees: -45, pan: Offset(5000, -5000)),
    (degrees: -60, pan: Offset(-5000, 5000)),
    (degrees: -90, pan: Offset(0, 5000)),
  ];

  Future<void> runMode(
    WidgetTester tester, {
    required double drawingAreaScale,
    required String mode,
  }) async {
    tester.view.physicalSize = const Size(600, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final project = await tester.runAsync(
      () => projects.createProject(
        name: 'angle-boundary-$mode',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 200,
        drawingAreaScale: drawingAreaScale,
      ),
    );
    final p = project!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final appProviders = await tester.runAsync(buildAppProviders);

    for (final testCase in cases) {
      final rootKey = GlobalKey();
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
                child: RepaintBoundary(
                  key: rootKey,
                  child: Builder(
                    builder: (context) => ColoredBox(
                      // CanvasScreenと同じ、Transform外の固定安全背景。
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: SizedBox(
                        width: 420,
                        height: 520,
                        child: CanvasArea(
                          key: ValueKey('$mode-${testCase.degrees}'),
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
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);

      final canvasFinder = find.byType(CanvasArea);
      expect(canvasFinder, findsOneWidget);
      final center = tester.getCenter(canvasFinder);

      // NIARIMの独自2本指変形は「動いた指」と「もう一方の固定アンカー」の
      // ベクトル差から倍率・角度を取る。片指を固定し、もう片方だけを動かす
      // ことで、相殺なしに指定角度へ回す。
      final anchor = center - const Offset(60, 0);
      final movingStart = center + const Offset(60, 0); // 初期間隔120px
      final radians = testCase.degrees * math.pi / 180;
      final movingEnd = anchor + Offset.fromDirection(radians, 24); // 24/120=0.2

      final fixed = await tester.startGesture(
        anchor,
        kind: PointerDeviceKind.touch,
      );
      final moving = await tester.startGesture(
        movingStart,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      await moving.moveTo(movingEnd);
      await tester.pump();
      await moving.up();
      await fixed.up();
      await tester.pump();

      Matrix4 matrix = _viewMatrix(tester);
      final scale = matrix.getMaxScaleOnAxis();
      expect(
        scale,
        closeTo(kCanvasMinScale, 0.015),
        reason: '$mode ${testCase.degrees}°: 実ジェスチャーで1/5まで縮小すること',
      );
      final actualAngle = math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
      expect(
        _angleDelta(actualAngle, radians).abs(),
        lessThan(0.035),
        reason: '$mode ${testCase.degrees}°: 指定した斜め角度が相殺されないこと',
      );

      // 回転後の状態から、実際の1本指panを5,000px相当まで押し込む。
      // どれだけ足掻いても描画可能領域の境界条件を越えないことを確認する。
      final pan = await tester.startGesture(
        center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      await pan.moveTo(center + testCase.pan);
      await tester.pump();
      await pan.up();
      await tester.pump();
      expect(tester.takeException(), isNull);

      matrix = _viewMatrix(tester);
      _expectDrawingBoundsConstrained(
        matrix: matrix,
        viewport: const Size(420, 520),
        project: p,
        reason: '$mode ${testCase.degrees}°',
      );

      final sign = testCase.degrees < 0 ? 'm' : 'p';
      final angle = testCase.degrees.abs().toString().padLeft(2, '0');
      await tester.runAsync(
        () => _capture(
          rootKey,
          '${out.path}/${mode}_${sign}${angle}.png',
        ),
      );
    }
  }

  testWidgets('通常背景固定: 1/5縮小と8方向斜め回転を実操作してPNG監査する', (tester) async {
    await runMode(tester, drawingAreaScale: 1.0, mode: 'normal');
  });

  testWidgets('拡張描画領域連動: 1/5縮小と8方向斜め回転を実操作してPNG監査する', (tester) async {
    await runMode(tester, drawingAreaScale: 2.0, mode: 'extended');
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
  // CanvasAreaの表示変形は最上位のTransform。内部描画要素に将来Transformが
  // 追加されても、CanvasArea直下側を使う。
  return transforms.first.transform.clone();
}

double _angleDelta(double a, double b) {
  var d = a - b;
  while (d > math.pi) d -= math.pi * 2;
  while (d < -math.pi) d += math.pi * 2;
  return d;
}

void _expectDrawingBoundsConstrained({
  required Matrix4 matrix,
  required Size viewport,
  required dynamic project,
  required String reason,
}) {
  final drawing = canvasDrawingRectFor(viewport, project);
  final transformed = MatrixUtils.transformRect(matrix, drawing);
  const epsilon = 1.5;

  if (transformed.width <= viewport.width) {
    expect(transformed.left, greaterThanOrEqualTo(-epsilon), reason: '$reason left');
    expect(
      transformed.right,
      lessThanOrEqualTo(viewport.width + epsilon),
      reason: '$reason right',
    );
  } else {
    expect(transformed.left, lessThanOrEqualTo(epsilon), reason: '$reason cover-left');
    expect(
      transformed.right,
      greaterThanOrEqualTo(viewport.width - epsilon),
      reason: '$reason cover-right',
    );
  }

  if (transformed.height <= viewport.height) {
    expect(transformed.top, greaterThanOrEqualTo(-epsilon), reason: '$reason top');
    expect(
      transformed.bottom,
      lessThanOrEqualTo(viewport.height + epsilon),
      reason: '$reason bottom',
    );
  } else {
    expect(transformed.top, lessThanOrEqualTo(epsilon), reason: '$reason cover-top');
    expect(
      transformed.bottom,
      greaterThanOrEqualTo(viewport.height - epsilon),
      reason: '$reason cover-bottom',
    );
  }
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  image.dispose();
}
