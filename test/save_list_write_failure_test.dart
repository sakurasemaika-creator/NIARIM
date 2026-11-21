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

/// 保存の一覧（index.json）を書けない（空き容量が無い等）とき、メモ・名前の
/// 変更は次の起動に残らないので、成功と言わず「メモを保存できませんでした」と
/// 知らせる。以前はsetSlotMemo・renameSaveがtrueを返し、ダイアログは何も
/// 言わずに閉じ、次の起動でメモ・名前が消えていた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const notSaved = 'メモを保存できませんでした。空き容量などを確認してください';
  late Directory dir;
  late SaveFileFaults faults;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_list_write_');
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

  bool indexTmp(String path) => path.endsWith('/index.json.tmp');

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  late SaveTreeService saves;
  late ProjectService projects;
  late Project project;

  Future<void> open(
    WidgetTester tester, {
    bool tree = false,
    List<String> slots = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
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
    saves.setTreeMode(tree);
    project = (await tester.runAsync(
      () => projects.createProject(
        name: '一覧',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    for (final (i, comment) in slots.indexed) {
      await tester.runAsync(
        () => saves.saveToSlot(
          projectId: project.id,
          slotIndex: i,
          project: project,
          scenes: projects.scenesOf(project.id),
          tileManager: projects.tileManagerOf(project.id),
          comment: comment,
        ),
      );
    }
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SaveManagementScreen(projectId: project.id),
      ),
    );
    await settleIo(tester, 4);
  }

  /// 次の起動：新しいサービスで保存の一覧を読む。
  Future<SaveTreeService> restart(WidgetTester tester) async {
    final next = SaveTreeService()..setTreeMode(false);
    addTearDown(next.dispose);
    await tester.runAsync(next.init);
    return next;
  }

  testWidgets('a memo or a name that cannot be written to the list is not '
      'reported as kept, and a later write that works keeps it', (
    tester,
  ) async {
    await open(tester, slots: ['A']);
    final a = saves.getNodes(project.id).single;
    faults.failWrite = indexTmp;
    final memo = (await tester.runAsync(
      () => saves.setSlotMemo(project.id, 3, '次はここ'),
    ))!;
    final renamed = (await tester.runAsync(
      () => saves.renameSave(project.id, a.id, '線画まで'),
    ))!;
    expect(memo, isFalse, reason: 'the memo was reported as kept');
    expect(renamed, isFalse, reason: 'the name was reported as kept');
    // 同じメモをもう一度確定すると、書けるようになっていれば書く。
    faults.clear();
    final again = (await tester.runAsync(
      () => saves.setSlotMemo(project.id, 3, '次はここ'),
    ))!;
    expect(again, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    final next = await restart(tester);
    expect(next.slotMemoOf(project.id, 3), '次はここ');
    expect(next.getNodes(project.id).single.comment, '線画まで');
  });

  testWidgets('the pencil memo dialog says the memo could not be saved', (
    tester,
  ) async {
    await open(tester);
    faults.failWrite = indexTmp;
    await tester.tap(find.byKey(Key('saveSlotMemo_${project.id}_2')));
    await settleIo(tester, 3);
    tester.testTextInput.enterText('次はここ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleIo(tester, 6);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(notSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the save slot dialog says the memo could not be saved when '
      'the save is written but the list is not', (tester) async {
    await open(tester);
    faults.failWrite = indexTmp;
    await tester.tap(find.byTooltip('このスロットへ保存').first);
    await settleIo(tester, 3);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '線画まで',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 12);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(notSaved), findsOneWidget);
    expect(find.text('保存データの読み込みに失敗しました'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the tree save dialog says the memo could not be saved when '
      'the save is written but the list is not', (tester) async {
    await open(tester, tree: true);
    faults.failWrite = indexTmp;
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 3);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '線画まで',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 12);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(notSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
