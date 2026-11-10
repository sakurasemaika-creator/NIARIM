import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ロックしたレイヤーへキャンバスで描こうとしたら、何も描かずに
/// 「ロック中のため描けません」と知らせる（以前は黙って何も起きず、
/// 描けない理由が分からなかった）。描く操作ではないもの（2本指の拡大・
/// 移動・2本指のタップ・右クリック）では知らせない（出すと、拡大のたびに
/// 誤った知らせが出て、ほかの知らせを閉じてしまう）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_locked_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const notice =
      'このレイヤーはロック中のため描けません。レイヤーの設定で「ロック」を'
      'オフにしてください。';

  /// 今のレイヤーをロックした作品をキャンバスで開き、キャンバスの矩形を返す。
  Future<({app_undo.UndoManager undo, Rect area})> openLocked(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    final undo = home.read<app_undo.UndoManager>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'ロック',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    final scene = service.scenesOf(id).first;
    final layer = service.layersOf(id, scene.id, 0).first;
    service.updateLayer(
      projectId: id,
      sceneId: scene.id,
      frameIndex: 0,
      layer: layer.copyWith(isLocked: true),
    );

    appRouter.push('/canvas/$id');
    await settleIo(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(find.text(notice), findsNothing);
    return (undo: undo, area: tester.getRect(find.byType(CanvasArea)));
  }

  // 操作ボタンの無い知らせなので、時間で消える（出てから6秒のうちに）。
  Future<void> expectNoticeTimesOut(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(notice), findsNothing);
  }

  testWidgets('drawing on a locked layer says why nothing is drawn', (
    tester,
  ) async {
    final (:undo, :area) = await openLocked(tester);

    // ペンで描く（マウス：画面端の前後フレーム用の帯を避けるため）。
    final stroke = await tester.startGesture(
      area.center - const Offset(40, 0),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    for (var dx = -30.0; dx <= 40; dx += 10) {
      await stroke.moveTo(area.center + Offset(dx, 0));
      await tester.pump();
    }
    await stroke.up();
    await settleIo(tester, 3);

    expect(find.text(notice), findsOneWidget);
    expect(undo.canUndo, isFalse, reason: 'nothing was drawn');
    await expectNoticeTimesOut(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a one-finger stroke on a locked layer says why', (tester) async {
    final (:undo, :area) = await openLocked(tester);

    final finger = await tester.startGesture(
      area.center - const Offset(40, 0),
      kind: PointerDeviceKind.touch,
      pointer: 21,
    );
    for (var dx = -30.0; dx <= 40; dx += 10) {
      await finger.moveTo(area.center + Offset(dx, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 指を動かして描こうとした時点で知らせる（離すまで待たない）。
    await settleIo(tester, 2);
    expect(find.text(notice), findsOneWidget);
    await finger.up();
    await settleIo(tester, 2);
    expect(find.text(notice), findsOneWidget);
    expect(undo.canUndo, isFalse, reason: 'nothing was drawn');
    await expectNoticeTimesOut(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a one-finger tap on a locked layer says why', (tester) async {
    final (:undo, :area) = await openLocked(tester);

    final finger = await tester.startGesture(
      area.center,
      kind: PointerDeviceKind.touch,
      pointer: 31,
    );
    await tester.pump(const Duration(milliseconds: 60));
    await finger.up();
    await settleIo(tester, 3);
    expect(find.text(notice), findsOneWidget);
    expect(undo.canUndo, isFalse, reason: 'nothing was drawn');
    await expectNoticeTimesOut(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinch-zooming over a locked layer does not say it cannot draw', (
    tester,
  ) async {
    final (:undo, :area) = await openLocked(tester);

    // 2本指でつまんで拡大する（描く操作ではない）。
    final a = await tester.startGesture(
      area.center - const Offset(30, 0),
      kind: PointerDeviceKind.touch,
      pointer: 11,
    );
    final b = await tester.startGesture(
      area.center + const Offset(30, 0),
      kind: PointerDeviceKind.touch,
      pointer: 12,
    );
    for (var i = 1; i <= 6; i++) {
      await a.moveTo(area.center - Offset(30.0 + i * 10, 0));
      await b.moveTo(area.center + Offset(30.0 + i * 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await settleIo(tester, 3);
    expect(find.text(notice), findsNothing, reason: 'a pinch is not drawing');
    expect(undo.canUndo, isFalse, reason: 'nothing was drawn');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a two-finger tap over a locked layer does not say it', (
    tester,
  ) async {
    final (:undo, :area) = await openLocked(tester);

    final a = await tester.startGesture(
      area.center - const Offset(30, 0),
      kind: PointerDeviceKind.touch,
      pointer: 41,
    );
    final b = await tester.startGesture(
      area.center + const Offset(30, 0),
      kind: PointerDeviceKind.touch,
      pointer: 42,
    );
    await tester.pump(const Duration(milliseconds: 60));
    await a.up();
    await b.up();
    await settleIo(tester, 3);
    expect(find.text(notice), findsNothing, reason: 'a two-finger tap');
    expect(undo.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a right-click over a locked layer does not say it', (
    tester,
  ) async {
    final (:undo, :area) = await openLocked(tester);

    final click = await tester.startGesture(
      area.center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 30));
    await click.up();
    await settleIo(tester, 3);
    expect(find.text(notice), findsNothing, reason: 'a right-click');
    expect(undo.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
}
