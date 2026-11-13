import 'dart:async';
import 'dart:convert';
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
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/save_file_faults.dart';

/// 保存（.niapro）を消せないとき（権限が無い等）の扱い（DISC104の残り）。
/// - 保存を消せなければ一覧から外さず、保存の画面は「保存データを削除
///   できませんでした」と知らせる（以前は先に一覧から外し、例外は誰も
///   受けず、スロットは空に見え、次の起動で保存が戻った）。
/// - 保存方式の変更（選ばなかった保存を完全に削除）で1つ消せなくても、
///   残すと選んだ保存はスロットに入り、消せなかった保存は退避に残して
///   知らせる（以前は変更の画面が待たずに閉じ、先に消した保存が中身の無い
///   一覧に残り、残すと選んだ保存はどのスロットにも出なかった）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const failedText = '保存データを削除できませんでした';
  late Directory dir;
  late SaveFileFaults faults;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_delete_failure_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    AppErrorReporter.recentErrors.clear();
    faults = SaveFileFaults();
    IOOverrides.global = faults;
  });

  tearDown(() {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String saveTree(String id) => '${dir.path}/niarim/projects/$id/SaveTree';

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 次の起動：新しいサービスで保存の一覧を読む。
  Future<SaveTreeService> restart(
    WidgetTester tester, {
    bool tree = false,
    int slotMax = 10,
  }) async {
    final next = SaveTreeService()
      ..setTreeMode(tree)
      ..setSlotMax(slotMax);
    addTearDown(next.dispose);
    await tester.runAsync(next.init);
    return next;
  }

  List<String> slotsOf(SaveTreeService s, String id) =>
      [for (final n in s.getNodes(id)) '${n.slotIndex}:${n.comment}']..sort();

  ({
    SaveTreeService saves,
    ProjectService projects,
    Project project,
    GlobalKey<NavigatorState> nav,
  })?
  app;

  Future<void> open(
    WidgetTester tester, {
    bool tree = false,
    List<String> saves = const [],
    bool push = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService projects;
    late SaveTreeService service;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            projects = context.read<ProjectService>();
            service = context.read<SaveTreeService>();
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
    service.setTreeMode(tree);
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: '削除',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    String? parent;
    for (final (i, comment) in saves.indexed) {
      final node = (await tester.runAsync<SaveNode>(
        () => tree
            ? service.saveAsChild(
                projectId: project.id,
                project: project,
                scenes: projects.scenesOf(project.id),
                tileManager: projects.tileManagerOf(project.id),
                parentId: parent,
                comment: comment,
              )
            : service.saveToSlot(
                projectId: project.id,
                slotIndex: i,
                project: project,
                scenes: projects.scenesOf(project.id),
                tileManager: projects.tileManagerOf(project.id),
                comment: comment,
              ),
      ))!;
      parent = node.id;
      // 保存の時刻（ミリ秒）がそろわないように少し待つ。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    app = (saves: service, projects: projects, project: project, nav: navKey);
    if (push) {
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SaveManagementScreen(
            projectId: project.id,
            entryMode: SaveTreeEntryMode.projectDetail,
          ),
        ),
      );
      await settleIo(tester, 4);
    }
  }

  SaveNode named(String comment) => app!.saves
      .getNodes(app!.project.id)
      .firstWhere((n) => n.comment == comment);

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    app = null;
  }

  testWidgets('save slots: a save that cannot be deleted stays in its slot '
      'and the screen says it could not be deleted', (tester) async {
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      await open(tester, saves: ['A', 'B']);
      final id = app!.project.id;
      faults.undeletable.add('${saveTree(id)}/${named('A').id}.niapro');
      await tester.tap(find.byTooltip('このスロットを削除').first);
      await settleIo(tester, 3);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, '削除'),
        ),
      );
      await settleIo(tester, 8);
    }, (error, _) => uncaught.add(error));
    final id = app!.project.id;
    expect(uncaught, isEmpty, reason: 'nobody caught the failed delete');
    expect(find.text(failedText), findsOneWidget);
    expect(slotsOf(app!.saves, id), ['0:A', '1:B']);
    expect(find.text('A'), findsOneWidget, reason: 'the slot looks empty');
    final index = jsonDecode(
      File('${saveTree(id)}/index.json').readAsStringSync(),
    );
    expect([for (final n in index['nodes'] as List) n['comment']], ['A', 'B']);
    expect(AppErrorReporter.recentErrors, isNotEmpty);
    await close(tester);
    faults.clear();
    final next = await restart(tester);
    expect(slotsOf(next, id), ['0:A', '1:B']);
  });

  testWidgets('save tree: a save that cannot be deleted stays in the tree '
      'and the screen says it could not be deleted', (tester) async {
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      await open(tester, tree: true, saves: ['A', 'B']);
      final id = app!.project.id;
      faults.undeletable.add('${saveTree(id)}/${named('B').id}.niapro');
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('B'),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await settleIo(tester, 3);
      await tester.tap(find.text('削除').last);
      await settleIo(tester, 3);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, '削除'),
        ),
      );
      await settleIo(tester, 8);
    }, (error, _) => uncaught.add(error));
    expect(uncaught, isEmpty, reason: 'nobody caught the failed delete');
    expect(find.text(failedText), findsOneWidget);
    expect(find.text('B'), findsOneWidget, reason: 'B vanished from the tree');
    expect(
      [for (final n in app!.saves.getNodes(app!.project.id)) n.comment],
      ['A', 'B'],
    );
    await close(tester);
  });

  testWidgets('deleting a save whose file cannot be deleted keeps it listed '
      '(service), also after a restart', (tester) async {
    await open(tester, saves: ['A', 'B'], push: false);
    final id = app!.project.id;
    final a = named('A');
    faults.undeletable.add('${saveTree(id)}/${a.id}.niapro');
    final error = await tester.runAsync<Object?>(() async {
      try {
        await app!.saves.deleteNode(id, a.id);
        return null;
      } catch (e) {
        return e;
      }
    });
    expect(error, isA<FileSystemException>());
    expect(slotsOf(app!.saves, id), ['0:A', '1:B']);
    await close(tester);
    faults.clear();
    final next = await restart(tester);
    expect(slotsOf(next, id), ['0:A', '1:B']);
  });

  testWidgets('changing to 1 slot and deleting the rest with one save that '
      'cannot be deleted: the kept save is in the slot, the undeletable one '
      'is archived, and the screen says so', (tester) async {
    await open(tester, tree: true, saves: ['A', 'B', 'C'], push: false);
    final id = app!.project.id;
    final a = named('A');
    final b = named('B');
    faults.undeletable.add('${saveTree(id)}/${b.id}.niapro');
    // 設定の画面と同じ順：作品ごとに変更の流れを通し、最後に方式を決める。
    final flow = showSaveModeChangeFlowIfNeeded(
      context: app!.nav.currentContext!,
      projectId: id,
      saveService: app!.saves,
      newIsTreeMode: false,
      newSlotMax: 1,
    );
    await settleIo(tester, 3);
    await tester.tap(find.text('最新1件を保存'));
    await settleIo(tester, 3);
    await tester.tap(find.text('完全に削除する'));
    await tester.pump();
    await tester.tap(find.text('変更する'));
    await settleIo(tester, 8);
    await tester.runAsync(() => flow);
    app!.saves
      ..setTreeMode(false)
      ..setSlotMax(1);
    await settleIo(tester, 2);
    expect(find.text('変更する'), findsNothing);
    expect(find.text('保持できる保存数：1件'), findsNothing);
    expect(find.text(failedText), findsOneWidget);
    expect(slotsOf(app!.saves, id), ['0:C']);
    expect([for (final n in app!.saves.getArchivedNodes(id)) n.comment], ['B']);
    expect(File('${saveTree(id)}/${a.id}.niapro').existsSync(), isFalse);
    await close(tester);
    faults.clear();
    final next = await restart(tester, slotMax: 1);
    expect(slotsOf(next, id), ['0:C']);
    expect([for (final n in next.getArchivedNodes(id)) n.comment], ['B']);
  });
}
