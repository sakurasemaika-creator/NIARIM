// 描いている途中にアプリが閉じた作品（作品ファイルより新しい自動保存が残る）は、
// 開かなくてもホームの絵と最終保存の日時が新しくなる。
//
// 以前は作品を開いたとき（作品詳細・キャンバス・タイムライン）に初めて自動保存の
// 内容になり、それまでホームのカードは落ちる前の絵と日時のままだった（実際に
// 使ってみて発見）。起動の後に、自動保存の枠にある作品だけを読んで当てる
// （ほかの作品の絵は読まない）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

const _drawn = [30, 60, 220, 255];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-startup-autosave-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// 1回目の起動：作品を2つ作り、片方にだけ描いて自動保存し、作品ファイルへ
  /// 書く前に閉じる（強制終了）。描いた作品・もう1つの作品・前のサムネイル・
  /// 自動保存の日時。
  Future<
    ({String crashed, String other, String oldThumbnail, DateTime savedAt})
  >
  launchAndCrash() async {
    final autosaves = AutosaveService();
    await autosaves.init();
    final projects = ProjectService(autosaves);
    await projects.init();
    Future<String> create(String name) async => (await projects.createProject(
      name: name,
      fps: 2,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    )).id;
    final crashed = await create('落ちた作品');
    final other = await create('ほかの作品');
    await projects.generateAndSaveThumbnail(crashed, force: true);
    final oldThumbnail = projects.projects
        .singleWhere((p) => p.id == crashed)
        .thumbnailPath!;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final scene = projects.scenesOf(crashed).single;
    final key = projects.tileKeyFor(
      crashed,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    projects
        .tileManagerOf(crashed)
        .getOrCreateTile(key, 0, 0)
        .setRange(0, 4, _drawn);
    await autosaves.save(crashed, projects);
    final savedAt = autosaves.slotsForProject(crashed).first.savedAt;
    // 作品ファイルへは書かないまま終わる（サービスは捨てるだけ）。
    return (
      crashed: crashed,
      other: other,
      oldThumbnail: oldThumbnail,
      savedAt: savedAt,
    );
  }

  Future<(ProjectService, UndoManager)> relaunch() async {
    final autosaves = AutosaveService();
    await autosaves.init();
    final projects = ProjectService(autosaves);
    await projects.init();
    final undo = UndoManager();
    projects.setUndoManager(undo);
    return (projects, undo);
  }

  List<int>? drawnPixel(ProjectService projects, String id) {
    final scene = projects.scenesOf(id).single;
    final key = projects.tileKeyFor(
      id,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    return projects.tileManagerOf(id).getTile(key, 0, 0)?.take(4).toList();
  }

  test(
    'the crashed work takes its newer autosave at start-up, with the '
    'autosave’s time and a new list picture; other works stay unread',
    () async {
      final before = await launchAndCrash();
      final (projects, undo) = await relaunch();
      expect(projects.tilesRead(before.crashed), isFalse);

      final watch = Stopwatch()..start();
      await projects.settleNewerAutosaves();
      watch.stop();
      await projects.settleWrites();
      debugPrint('settleNewerAutosaves (one crashed work): ${watch.elapsed}');

      final work = projects.projects.singleWhere((p) => p.id == before.crashed);
      expect(drawnPixel(projects, before.crashed), _drawn);
      expect(
        work.updatedAt.millisecondsSinceEpoch,
        before.savedAt.millisecondsSinceEpoch,
        reason: '最終保存は自動保存の日時（起動した時刻ではない）',
      );
      expect(work.thumbnailPath, isNot(before.oldThumbnail));
      expect(File(work.thumbnailPath!).existsSync(), isTrue);
      expect(projects.tilesRead(before.other), isFalse, reason: 'ほかの作品の絵は読まない');
      // 開いたときと同じく、取り消すと作品ファイルの内容に戻る。
      expect(undo.canUndoFor(before.crashed), isTrue);
      undo.undo(projectId: before.crashed);
      expect(drawnPixel(projects, before.crashed), isNull);
      undo.redo(projectId: before.crashed);
      expect(drawnPixel(projects, before.crashed), _drawn);
      await projects.settleWrites();

      // 次の起動では、もう当てる物は無い（作品の絵も読まない）。
      final (again, _) = await relaunch();
      final second = Stopwatch()..start();
      await again.settleNewerAutosaves();
      second.stop();
      debugPrint('settleNewerAutosaves (nothing to settle): ${second.elapsed}');
      expect(again.tilesRead(before.crashed), isFalse);
      expect(drawnPixel(again, before.crashed), _drawn);
    },
  );

  test('a work drawn on while its autosave is being read keeps the new '
      'strokes', () async {
    final before = await launchAndCrash();
    final (projects, _) = await relaunch();
    final settling = projects.settleNewerAutosaves();
    // 読み比べている間に描いた。
    final scene = projects.scenesOf(before.crashed).single;
    final key = projects.tileKeyFor(
      before.crashed,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    const later = [200, 10, 10, 255];
    projects
        .tileManagerOf(before.crashed)
        .getOrCreateTile(key, 0, 0)
        .setRange(0, 4, later);
    await settling;
    expect(drawnPixel(projects, before.crashed), later);
  });

  testWidgets('the home list shows it right after start-up', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = (await tester.runAsync(launchAndCrash))!;
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    final projects = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    final work = projects.projects.singleWhere((p) => p.id == before.crashed);
    expect(
      work.updatedAt.millisecondsSinceEpoch,
      before.savedAt.millisecondsSinceEpoch,
    );
    expect(work.thumbnailPath, isNot(before.oldThumbnail));
    final shown = [
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        if (image.image case FileImage(:final file)) file.path,
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        if (image.image case ResizeImage(imageProvider: FileImage(:final file)))
          file.path,
    ];
    expect(shown, contains(work.thumbnailPath));
    expect(shown, isNot(contains(before.oldThumbnail)));
    expect(projects.tilesRead(before.other), isFalse);
    expect(tester.takeException(), isNull);
  });
}
