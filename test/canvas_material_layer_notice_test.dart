// タイムラインの素材（文字・画像・動画）のレイヤーには、キャンバスで描かない。
// 描こうとしたら理由を知らせ、キャンバスは描けるレイヤーから始まる。
//
// 実際に使ってみたとき（2026-11-27）、タイムラインから戻ったキャンバスで文字の
// 素材のレイヤーが選ばれたままになり、ペンの線が文字に描き込まれた。線は文字の
// 全部のコマに出て、文字の色を変えると何も言わずに消えた（素材の絵は文字から
// 作り直す）。
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_material_');
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
      'このレイヤーはタイムラインの素材のため、キャンバスでは編集できません。'
      '素材はタイムラインで編集し、絵はほかのレイヤーに描いてください。';

  /// A work whose first frame has a timeline text on top (and, unless
  /// [onlyText], its first drawing layer under it), opened on the canvas.
  Future<
    ({
      app_undo.UndoManager undo,
      Rect area,
      ProjectService service,
      String textKey,
      String? drawingKey,
    })
  >
  open(WidgetTester tester, {bool onlyText = false}) async {
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
        name: '素材',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    final scene = service.scenesOf(id).first;
    final drawing = service.layersOf(id, scene.id, 0).first;
    final text = service.addLayer(
      projectId: id,
      sceneId: scene.id,
      frameIndex: 0,
      type: LayerType.timelineText,
      name: '文字',
    );
    if (onlyText) {
      service.removeLayer(
        projectId: id,
        sceneId: scene.id,
        frameIndex: 0,
        layerId: drawing.id,
      );
    }
    expect(service.layersOf(id, scene.id, 0).first.id, text.id);
    undo.clear();

    appRouter.push('/canvas/$id');
    await settleIo(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
    return (
      undo: undo,
      area: tester.getRect(find.byType(CanvasArea)),
      service: service,
      textKey: service.tileKeyFor(id, scene.id, 0, text.id),
      drawingKey: onlyText
          ? null
          : service.tileKeyFor(id, scene.id, 0, drawing.id),
    );
  }

  Future<void> drawLine(WidgetTester tester, Rect area) async {
    // マウスで描く（画面端の前後フレーム用の帯を避けるため）。
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
    await settleIo(tester, 4);
  }

  testWidgets('the canvas starts on the drawing layer, not on a timeline '
      'text above it', (tester) async {
    final opened = await open(tester);
    await drawLine(tester, opened.area);
    final tiles = opened.service.tileManagerOf(
      opened.service.projects.single.id,
    );
    expect(tiles.exportAll()[opened.drawingKey] ?? const {}, isNotEmpty);
    expect(tiles.exportAll()[opened.textKey] ?? const {}, isEmpty);
    expect(find.text(notice), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawing on a timeline material says why nothing is drawn', (
    tester,
  ) async {
    final opened = await open(tester, onlyText: true);
    await drawLine(tester, opened.area);
    expect(find.text(notice), findsOneWidget);
    expect(opened.undo.canUndo, isFalse, reason: 'nothing was drawn');
    final tiles = opened.service.tileManagerOf(
      opened.service.projects.single.id,
    );
    expect(tiles.exportAll()[opened.textKey] ?? const {}, isEmpty);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(notice), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
