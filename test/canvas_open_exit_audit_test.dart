import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/widgets/project_not_found_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// キャンバス（A010）を開く・閉じるとき：存在しないIDでは空のキャンバスを
/// 出さず一覧へ戻せること、不足素材の通知が時間で消え次の画面へ付いて
/// こないこと、「保存して戻る」で保存せずに戻ったらキャンバスに残ること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_open_exit_');
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

  // ファイルの読み書きのような本物の非同期の処理を実時間で待つ。
  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String location() => appRouter.routerDelegate.currentConfiguration.uri.path;

  Future<({ProjectService service, String id})> open(
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
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'キャンバス',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
    });
    return (service: service, id: id);
  }

  testWidgets('an unknown id offers the way back instead of a blank canvas', (
    tester,
  ) async {
    await open(tester);
    appRouter.push('/canvas/does-not-exist');
    await settleIo(tester);
    expect(find.byType(ProjectNotFoundView), findsOneWidget);
    expect(find.text('プロジェクトが見つかりません'), findsOneWidget);
    await tester.tap(find.byKey(const Key('canvasNotFoundHome')));
    await settleIo(tester, 4);
    expect(location(), '/home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the missing-materials notice times out and stays behind', (
    tester,
  ) async {
    final s = await open(tester);
    final materials = tester
        .element(find.byType(HomeScreen))
        .read<MaterialService>();
    await tester.runAsync(() async {
      final source = File('${tempDir.path}/source.png')
        ..writeAsBytesSync([1, 2, 3]);
      final asset = await materials.addMaterial(
        projectId: s.id,
        sourcePath: source.path,
        type: MaterialType.image,
      );
      // 素材のファイルだけが無くなった状態にする。
      for (final file in tempDir.listSync(recursive: true).whereType<File>()) {
        if (file.path.endsWith(asset.storageName)) file.deleteSync();
      }
    });
    appRouter.push('/canvas/${s.id}');
    await settleIo(tester, 12);
    expect(find.text('不足素材があります'), findsOneWidget);
    // 6秒で消える（操作ボタン付きは既定では消えなかった）。
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('不足素材があります'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save-and-return stays on the canvas when nothing was saved', (
    tester,
  ) async {
    final s = await open(tester);
    appRouter.push('/canvas/${s.id}');
    await settleIo(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);

    Future<void> chooseSaveAndReturn() async {
      await tester.tap(find.byTooltip('プロジェクト一覧に戻る'));
      await settleIo(tester, 3);
      await tester.tap(find.widgetWithText(FilledButton, '保存して戻る'));
      await settleIo(tester, 6);
      expect(find.byType(SaveManagementScreen), findsOneWidget);
    }

    // 保存の画面から何も保存せずに戻る：取り消しとしてキャンバスに残る。
    await chooseSaveAndReturn();
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(find.byType(SaveManagementScreen), findsNothing);
    expect(find.byType(CanvasScreen), findsOneWidget);

    // 保存してから戻ると一覧へ移る。
    await chooseSaveAndReturn();
    final saves = tester
        .element(find.byType(Scaffold).last)
        .read<SaveTreeService>();
    await tester.runAsync(
      () => saves.saveToSlot(
        projectId: s.id,
        slotIndex: 0,
        project: s.service.projects.singleWhere((p) => p.id == s.id),
        scenes: s.service.scenesOf(s.id),
        tileManager: s.service.tileManagerOf(s.id),
      ),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(location(), '/home');
    expect(find.byType(CanvasScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
