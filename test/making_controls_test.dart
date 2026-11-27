// メイキングの操作（所有者の指定、2026-11-27）：
// - 作品詳細では、記録の入切を編集の操作より下の「メイキング」の欄に置き、
//   その下に「メイキング再生」（押すと再生の画面を開いてすぐ再生する。記録を
//   切っている間は薄く描き、押せない）。
// - キャンバスの設定/編集メニューからも記録を入切できる（作品詳細と同じ設定）。
// - キャンバスで描いた線の1本ずつと取り消しが、メイキングの1コマずつになる
//   （以前は描いた後に1秒に1枚だけ撮り、続けた線と取り消しが入らなかった）。
//   再生の画面は記録から絵を作って見せる。
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/making_log.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/project/making_screen.dart';
import 'package:niarim/services/making_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/grouped_sheet.dart';
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

    // While the making is not recorded, 「メイキング再生」 is greyed out and
    // does nothing.
    expect(recording(projects, id), isFalse);
    expect(tester.widget<SheetRow>(play).enabled, isFalse);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: play, matching: find.byType(Opacity)).first,
          )
          .opacity,
      lessThan(1),
    );
    await tester.tap(play, warnIfMissed: false);
    await settleIo(tester, 2);
    expect(find.byType(MakingScreen), findsNothing);

    await tester.tap(makingSwitch);
    await settleIo(tester, 2);
    expect(recording(projects, id), isTrue);
    expect(tester.widget<SheetRow>(play).enabled, isTrue);

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

  testWidgets('each stroke on the canvas and each Undo is a step of the '
      'making, and the making screen shows its picture', (tester) async {
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

    // The steps are stored in the background: read the log as it is (the
    // recorder's work advances while the test clock is pumped).
    final logDir = (await tester.runAsync(
      () => MakingService.logDirectory(id),
    ))!;
    Future<List<MakingLogStep>> steps() async =>
        (await tester.runAsync(() async => MakingLogData.read(logDir)))!.steps;

    // Three strokes in quick succession, then Undo.
    await stroke(-60);
    await stroke(0);
    await stroke(60);
    await settleIo(tester, 2);
    await tester.tap(find.byTooltip(l10n.commonUndo));
    await settleIo(tester, 2);
    var recorded = await steps();
    for (var i = 0; i < 40 && recorded.length < 4; i++) {
      await settleIo(tester, 1);
      recorded = await steps();
    }
    expect(recorded, hasLength(4));

    appRouter.go('/making/$id');
    await settleIo(tester, 4);
    final picture = find.byKey(const Key('makingStepPicture'));
    for (var i = 0; i < 40 && picture.evaluate().isEmpty; i++) {
      await settleIo(tester, 1);
    }
    expect(picture, findsOneWidget);
    expect(find.text(l10n.makingFrameCounter(1, 4)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
