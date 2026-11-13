import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/save_file_faults.dart';

/// 保存のサムネイル（`{id}_thumb.png`）を書けない（空き容量が無い等）とき、
/// 保存（.niapro）は書けているので、サムネイル無しの保存として一覧に入れる。
/// 以前は保存全体を「保存に失敗しました」にし、書けた保存のファイルは一覧に
/// 無いまま残って、次の起動で名前の無い保存として空いたスロットへ戻った
/// （もう一度保存した利用者には同じ保存が2つになった）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final png = Uint8List.fromList(const [137, 80, 78, 71]);
  late Directory dir;
  late SaveFileFaults faults;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_thumb_failure_');
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

  late ProjectService projects;

  Future<Project> createProject(WidgetTester tester) async {
    projects = ProjectService();
    addTearDown(projects.dispose);
    return (await tester.runAsync(() async {
      await projects.init();
      return projects.createProject(
        name: 'サムネイル',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
    }))!;
  }

  Future<SaveTreeService> start(
    WidgetTester tester, {
    bool tree = false,
  }) async {
    final service = SaveTreeService()..setTreeMode(tree);
    addTearDown(service.dispose);
    await tester.runAsync(service.init);
    return service;
  }

  Future<Object?> attempt(WidgetTester tester, Future<void> Function() body) =>
      tester.runAsync<Object?>(() async {
        try {
          await body();
          return null;
        } catch (e) {
          return e;
        }
      });

  List<String> niapros(String id) => [
    for (final f in Directory(saveTree(id)).listSync().whereType<File>())
      if (f.path.endsWith('.niapro')) f.uri.pathSegments.last,
  ];

  testWidgets('a slot save whose thumbnail cannot be written is saved without '
      'a thumbnail, and a restart shows no extra save', (tester) async {
    final p = await createProject(tester);
    final s = await start(tester);
    await tester.runAsync(
      () => s.saveToSlot(
        projectId: p.id,
        slotIndex: 0,
        project: p,
        scenes: projects.scenesOf(p.id),
        tileManager: projects.tileManagerOf(p.id),
        comment: 'A',
        thumbnailPngBytes: png,
      ),
    );
    faults.failWrite = (path) => path.endsWith('_thumb.png');
    final error = await attempt(
      tester,
      () => s.saveToSlot(
        projectId: p.id,
        slotIndex: 1,
        project: p,
        scenes: projects.scenesOf(p.id),
        tileManager: projects.tileManagerOf(p.id),
        comment: 'B',
        thumbnailPngBytes: png,
      ),
    );
    expect(error, isNull, reason: 'the save was reported as failed');
    final b = s.getNodes(p.id).firstWhere((n) => n.comment == 'B');
    expect(b.slotIndex, 1);
    expect(b.thumbnailPath, isNull);
    expect(AppErrorReporter.recentErrors, isNotEmpty);
    expect(niapros(p.id), hasLength(2));
    faults.clear();
    final next = await start(tester);
    expect(
      {for (final n in next.getNodes(p.id)) n.slotIndex: n.comment},
      {0: 'A', 1: 'B'},
    );
  });

  testWidgets('a tree save whose thumbnail cannot be written is saved without '
      'a thumbnail, and a restart shows no extra save', (tester) async {
    final p = await createProject(tester);
    final s = await start(tester, tree: true);
    faults.failWrite = (path) => path.endsWith('_thumb.png');
    final error = await attempt(
      tester,
      () => s.saveAsChild(
        projectId: p.id,
        project: p,
        scenes: projects.scenesOf(p.id),
        tileManager: projects.tileManagerOf(p.id),
        comment: 'A',
        thumbnailPngBytes: png,
      ),
    );
    expect(error, isNull, reason: 'the save was reported as failed');
    expect([for (final n in s.getNodes(p.id)) n.comment], ['A']);
    faults.clear();
    final next = await start(tester, tree: true);
    expect([for (final n in next.getNodes(p.id)) n.comment], ['A']);
  });

  testWidgets('the save slot dialog closes as saved when only the thumbnail '
      'cannot be written', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService app;
    late SaveTreeService saves;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            app = context.read<ProjectService>();
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
    saves.setTreeMode(false);
    final p = (await tester.runAsync(
      () => app.createProject(
        name: 'サムネイル',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SaveManagementScreen(projectId: p.id),
      ),
    );
    Future<void> settleIo([int rounds = 12]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settleIo(4);
    faults.failWrite = (path) => path.endsWith('_thumb.png');
    await tester.tap(find.byTooltip('このスロットへ保存').first);
    await settleIo(3);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'B',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo();
    expect(find.byKey(const Key('saveSlotDialogFailure')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect([for (final n in saves.getNodes(p.id)) n.comment], ['B']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
