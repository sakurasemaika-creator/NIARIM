import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 保存方式・スロット数を変えたとき、保存がスロットの画面から消えないこと。
/// 以前は（1）ツリー方式からスロット方式へ変える（保存がスロット数以下で
/// 選ぶ画面が出ない）と、どの保存もスロット-1のままで、スロットの画面は
/// すべて「保存データなし」、次の起動でも同じだった。（2）スロット数を
/// 減らす（保存は新しい数以下）と、消えるスロットにあった保存がどの
/// スロットにも退避にも出なかった。（3）設定は作品ごとに順に当てるが、
/// 前の作品で方式を変えた後の作品は「同じ方式でスロットを増やすだけ」と
/// 見なされ、保存がスロット数より多くても選ぶ画面が出なかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_mode_change_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  late SaveTreeService saves;
  late ProjectService projects;
  late GlobalKey<NavigatorState> navKey;

  Future<void> open(WidgetTester tester, {required bool tree}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            projects = context.read<ProjectService>();
            saves = context.read<SaveTreeService>();
            return MaterialApp(
              navigatorKey: navKey,
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(body: SizedBox.shrink()),
            );
          },
        ),
      ),
    );
    saves
      ..setSlotMax(5)
      ..setTreeMode(tree);
  }

  Future<Project> newProject(WidgetTester tester, String name) async =>
      (await tester.runAsync(
        () => projects.createProject(
          name: name,
          fps: 2,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 36,
        ),
      ))!;

  Future<SaveNode> save(
    WidgetTester tester,
    Project project,
    String comment, {
    int? slot,
    String? parent,
  }) async {
    final node = (await tester.runAsync<SaveNode>(
      () => slot == null
          ? saves.saveAsChild(
              projectId: project.id,
              project: project,
              scenes: projects.scenesOf(project.id),
              tileManager: projects.tileManagerOf(project.id),
              parentId: parent,
              comment: comment,
            )
          : saves.saveToSlot(
              projectId: project.id,
              slotIndex: slot,
              project: project,
              scenes: projects.scenesOf(project.id),
              tileManager: projects.tileManagerOf(project.id),
              comment: comment,
            ),
    ))!;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    return node;
  }

  /// 設定の画面（_applyToAllProjects）と同じ：作品ごとに変更の流れを通し、
  /// 最後に方式とスロット数を決める。選ぶ画面が出たら[choose]で操作する。
  Future<void> applyToAll(
    WidgetTester tester,
    List<Project> list, {
    required int slotMax,
    Future<void> Function(Project project)? choose,
  }) async {
    for (final project in list) {
      final flow = showSaveModeChangeFlowIfNeeded(
        context: navKey.currentContext!,
        projectId: project.id,
        saveService: saves,
        newIsTreeMode: false,
        newSlotMax: slotMax,
        projectName: project.name,
      );
      await settleIo(tester, 3);
      if (find.text('保存データ変更（${project.name}）').evaluate().isNotEmpty) {
        await choose!(project);
      }
      await tester.runAsync(() => flow);
    }
    saves
      ..setTreeMode(false)
      ..setSlotMax(slotMax);
    await settleIo(tester, 3);
  }

  Future<void> showSlots(WidgetTester tester, Project project) async {
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SaveManagementScreen(
          projectId: project.id,
          entryMode: SaveTreeEntryMode.projectDetail,
        ),
      ),
    );
    await settleIo(tester, 3);
  }

  /// 次の起動：新しいサービスで保存の一覧を読む。
  Future<SaveTreeService> restart(
    WidgetTester tester, {
    required int slotMax,
  }) async {
    final next = SaveTreeService()
      ..setTreeMode(false)
      ..setSlotMax(slotMax);
    addTearDown(next.dispose);
    await tester.runAsync(next.init);
    return next;
  }

  List<String> slotNames(SaveTreeService s, String id, int slotMax) => [
    for (final n in s.getNodes(id))
      if (n.slotIndex >= 0 && n.slotIndex < slotMax)
        s.slotDisplayMemoOf(id, n.slotIndex) ?? '',
  ]..sort();

  testWidgets('tree -> slots with fewer saves than slots: the saves are in '
      'the slot screen, also after a restart', (tester) async {
    await open(tester, tree: true);
    final p = await newProject(tester, '木');
    final a = await save(tester, p, '木A');
    await save(tester, p, '木B', parent: a.id);
    await applyToAll(tester, [p], slotMax: 5);
    expect(slotNames(saves, p.id, 5), ['木A', '木B']);
    await showSlots(tester, p);
    expect(find.text('木A'), findsOneWidget, reason: 'the save is hidden');
    expect(find.text('木B'), findsOneWidget, reason: 'the save is hidden');
    expect(find.text('保存データなし'), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
    final next = await restart(tester, slotMax: 5);
    expect(slotNames(next, p.id, 5), ['木A', '木B']);
  });

  testWidgets('fewer slots (the saves fit): a save in a removed slot moves '
      'into a kept slot with its name, also after a restart', (tester) async {
    await open(tester, tree: false);
    final p = await newProject(tester, 'スロット');
    await save(tester, p, '', slot: 0);
    await save(tester, p, '五', slot: 3);
    await tester.runAsync(
      () => saves.deleteNode(
        p.id,
        saves.getNodes(p.id).firstWhere((n) => n.slotIndex == 0).id,
      ),
    );
    await applyToAll(tester, [p], slotMax: 2);
    expect(saves.slotMax, 2);
    expect(slotNames(saves, p.id, 2), ['五']);
    expect(saves.getArchivedNodes(p.id), isEmpty);
    await showSlots(tester, p);
    expect(find.text('五'), findsOneWidget, reason: 'the save is hidden');
    await tester.pumpWidget(const SizedBox.shrink());
    final next = await restart(tester, slotMax: 2);
    expect(slotNames(next, p.id, 2), ['五']);
  });

  testWidgets('a list saved by the earlier version with saves in no slot '
      'puts them into free slots when read in slot mode', (tester) async {
    await open(tester, tree: true);
    final p = await newProject(tester, '前の版');
    final a = await save(tester, p, '木A');
    await save(tester, p, '木B', parent: a.id);
    // 以前の版：方式だけ変わり、保存はスロット-1のまま一覧に書かれていた。
    await tester.pumpWidget(const SizedBox.shrink());
    final next = await restart(tester, slotMax: 5);
    expect(slotNames(next, p.id, 5), ['木A', '木B']);
    final again = await restart(tester, slotMax: 5);
    expect(slotNames(again, p.id, 5), ['木A', '木B']);
  });

  testWidgets('the second project with more saves than slots still gets the '
      'screen to choose which saves to keep', (tester) async {
    await open(tester, tree: true);
    final p1 = await newProject(tester, '一');
    final p2 = await newProject(tester, '二');
    await save(tester, p1, '一A');
    await save(tester, p1, '一B');
    await save(tester, p2, '二A');
    await save(tester, p2, '二B');
    await save(tester, p2, '二C');
    final chosen = <String>[];
    await applyToAll(
      tester,
      [p1, p2],
      slotMax: 2,
      choose: (project) async {
        chosen.add(project.name);
        await tester.tap(find.text('最新2件を保存'));
        await settleIo(tester, 3);
        await tester.tap(find.text('変更する'));
        await settleIo(tester, 6);
      },
    );
    expect(chosen, ['二'], reason: 'no screen to choose the saves to keep');
    expect(slotNames(saves, p1.id, 2), ['一A', '一B']);
    expect(slotNames(saves, p2.id, 2), ['二B', '二C']);
    expect([for (final n in saves.getArchivedNodes(p2.id)) n.comment], ['二A']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
