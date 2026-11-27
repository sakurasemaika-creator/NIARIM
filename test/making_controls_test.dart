// メイキングの操作（所有者の指定、2026-11-27）：
// - 作品詳細では、記録の入切を編集の操作より下の「メイキング」の欄に置き、
//   その下に「メイキング再生」（押すと再生の画面を開いてすぐ再生する）。
// - キャンバスの設定/編集メニューからも記録を入切できる（作品詳細と同じ設定）。
// - 1秒以内に続けて描いた最後の線も記録に残る（以前は1秒に1枚に抑えたまま
//   後から撮り直さず、素早く続けた最後の線がメイキングに入らなかった）。
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/project/making_screen.dart';
import 'package:niarim/services/making_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_making_controls_');
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
        name: 'メイキング',
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

  bool recording(ProjectService projects, String id) =>
      projects.projects.singleWhere((p) => p.id == id).makingEnabled;

  testWidgets('the work\'s details put the making switch below the editing '
      'actions, with 「メイキング再生」 under it', (tester) async {
    final (service: projects, :id) = await open(tester);
    appRouter.go('/project/$id');
    await settleIo(tester, 4);

    final sheet = find.byKey(const Key('projectDetailMakingSheet'));
    await tester.ensureVisible(sheet);
    await tester.pump();
    final saveRow = find.byKey(const Key('projectDetailSaveRow'));
    final makingSwitch = find.byKey(const Key('projectDetailMakingEnabled'));
    final play = find.byKey(const Key('projectDetailPlayMaking'));
    expect(
      tester.getTopLeft(sheet).dy,
      greaterThan(tester.getBottomLeft(saveRow).dy),
    );
    expect(
      tester.getTopLeft(play).dy,
      greaterThan(tester.getBottomLeft(makingSwitch).dy),
    );
    expect(
      find.descendant(of: sheet, matching: find.text(l10n.makingTitle)),
      findsOneWidget,
    );
    expect(find.text(l10n.makingPlay), findsOneWidget);

    expect(recording(projects, id), isFalse);
    await tester.tap(makingSwitch);
    await settleIo(tester, 2);
    expect(recording(projects, id), isTrue);

    await tester.tap(play);
    await settleIo(tester, 4);
    final making = tester.widget<MakingScreen>(find.byType(MakingScreen));
    expect(making.projectId, id);
    expect(making.playOnOpen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the canvas settings menu switches the making on and off', (
    tester,
  ) async {
    final (service: projects, :id) = await open(tester);
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    await tester.tap(find.byTooltip(l10n.canvasSettingsMenuTooltip));
    await settleIo(tester, 3);
    final menuSwitch = find.byKey(const Key('canvasEditMenuMakingSwitch'));
    await tester.ensureVisible(menuSwitch);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(menuSwitch).value, isFalse);

    await tester.tap(menuSwitch);
    await settleIo(tester, 2);
    expect(recording(projects, id), isTrue);
    // The open menu shows the new state at once.
    expect(tester.widget<SwitchListTile>(menuSwitch).value, isTrue);

    await tester.tap(menuSwitch);
    await settleIo(tester, 2);
    expect(recording(projects, id), isFalse);
    expect(tester.widget<SwitchListTile>(menuSwitch).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('strokes drawn within a second of each other: the last one '
      'still reaches the making', (tester) async {
    final (service: projects, :id) = await open(tester);
    await projects.setMakingEnabled(id, true);
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    final area = find.byType(CanvasArea);
    final center = tester.getCenter(area);

    Future<void> stroke(double dy) async {
      final gesture = await tester.startGesture(
        center + Offset(-40, dy),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      for (var x = -30.0; x <= 40; x += 10) {
        await gesture.moveTo(center + Offset(x, dy));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    Future<List<MakingSnapshot>> snapshots() async =>
        (await tester.runAsync(() => MakingService.history(id)))!.snapshots;

    // Three strokes in quick succession: the first is captured at once, the
    // next two fall inside the one-per-second limit.
    await stroke(-60);
    await stroke(0);
    await stroke(60);
    // Let the first capture finish and the held-back one fire (the capture
    // and its file work are real asynchronous work).
    var taken = await snapshots();
    for (var i = 0; i < 120 && taken.length < 2; i++) {
      await settleIo(tester, 1);
      await tester.pump(const Duration(milliseconds: 300));
      taken = await snapshots();
    }
    // One capture right away and one held back for the later strokes (before,
    // the held-back strokes were never captured: one picture only).
    expect(taken, hasLength(2));
    // Nothing more is pending: no further captures come.
    for (var i = 0; i < 6; i++) {
      await settleIo(tester, 1);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(await snapshots(), hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
