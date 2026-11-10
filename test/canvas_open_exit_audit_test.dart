import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart';
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
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/widgets/project_not_found_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// キャンバス（A010）を開く・閉じるとき：存在しないIDでは空のキャンバスを
/// 出さず一覧へ戻せること、不足素材の通知が時間で消え次の画面へ付いて
/// こないこと、「保存して戻る」で保存せずに戻ったらキャンバス（タイムライン
/// も同じ）に残ること。
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

  // 一番長い仏語の文言・文字2倍・320pxでも、一覧へ戻るボタンの文字は
  // ボタンの中に収まり（折り返した見出しの書体の下の出っ張りがボタンの外へ
  // はみ出していた）、各行がボタンの中央にそろう。
  testWidgets('the way back fits in French at twice the text size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'fr',
    });
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    appRouter.push('/canvas/does-not-exist');
    await settleIo(tester);
    final button = find.byKey(const Key('canvasNotFoundHome'));
    final label = find.descendant(
      of: button,
      matching: find.text('Aller aux projets'),
    );
    expect(label, findsOneWidget);
    final buttonRect = tester.getRect(button);
    final paragraph = tester.renderObject<RenderParagraph>(label);
    final origin = paragraph.localToGlobal(Offset.zero);
    // 字の箱（行末の空白は中央そろえで数えないので除く）。
    const text = 'Aller aux projets';
    final lines = [
      for (var i = 0; i < text.length; i++)
        if (text[i] != ' ')
          ...paragraph.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          ),
    ];
    // 折り返して2行になる大きさで確かめる。
    expect(lines.map((b) => b.top).toSet().length, greaterThanOrEqualTo(2));
    // 上下とも、書体の出っ張りが収まるだけの余白がボタンの中にある。
    final textTop = origin.dy + lines.map((b) => b.top).reduce(math.min);
    final textBottom = origin.dy + lines.map((b) => b.bottom).reduce(math.max);
    expect(textTop - buttonRect.top, greaterThanOrEqualTo(8));
    expect(buttonRect.bottom - textBottom, greaterThanOrEqualTo(8));
    // 各行がボタンの中央にそろう（左寄せにならない）。
    final byLine = <double, Rect>{};
    for (final box in lines) {
      final rect = box.toRect().shift(origin);
      byLine.update(
        box.top,
        (r) => r.expandToInclude(rect),
        ifAbsent: () => rect,
      );
    }
    for (final line in byLine.values) {
      expect(
        (line.left - buttonRect.left) - (buttonRect.right - line.right),
        moreOrLessEquals(0, epsilon: 2),
      );
    }
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

  // タイムラインの「保存して戻る」も同じ：保存の画面から何も保存せずに
  // 戻ったら一覧へ移らず、タイムラインに残る（描きかけを保存したつもりで
  // 一覧へ移ってしまわない）。
  testWidgets('save-and-return stays on the timeline when nothing was saved', (
    tester,
  ) async {
    final s = await open(tester);
    appRouter.push('/timeline/${s.id}');
    await settleIo(tester, 10);
    expect(find.byType(TimelineScreen), findsOneWidget);

    Future<void> chooseSaveAndReturn() async {
      await tester.tap(find.byTooltip('プロジェクト一覧に戻る'));
      await settleIo(tester, 3);
      await tester.tap(find.widgetWithText(FilledButton, '保存して戻る'));
      await settleIo(tester, 6);
      expect(find.byType(SaveManagementScreen), findsOneWidget);
    }

    await chooseSaveAndReturn();
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(find.byType(SaveManagementScreen), findsNothing);
    expect(find.byType(TimelineScreen), findsOneWidget);
    // タイムラインが一番上の画面のまま（一覧へ移っていない）。
    expect(
      ModalRoute.of(tester.element(find.byType(TimelineScreen)))!.isCurrent,
      isTrue,
    );

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
    expect(find.byType(TimelineScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
