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
/// 描けない理由が分からなかった）。
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

  testWidgets('drawing on a locked layer says why nothing is drawn', (
    tester,
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

    // ペンで描く（マウス：画面端の前後フレーム用の帯を避けるため）。
    final area = tester.getRect(find.byType(CanvasArea));
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
    // 操作ボタンの無い知らせなので、時間で消える。
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(notice), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
