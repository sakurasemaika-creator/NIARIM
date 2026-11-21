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

/// セーブツリーで、親の保存が無い保存（親の保存を消した等）も描く。以前は
/// （X）A→C→DでCを消すとDがツリーから消え（データと容量は残る）、
/// （Y）保存Bを選んだままBを消してから「保存」すると、ダイアログは
/// 「選択中のノードの子として保存します」と言い、消したBの子として保存され、
/// 新しい保存はどこにも描かれなかった。親の保存を消したときの扱い（親の
/// 親へつなぐか、枝ごと消すか）は所有者の判断待ちで、ここでは決めない：
/// 親の無い保存は根として出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_tree_parent_');
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
  late Project project;
  late GlobalKey<NavigatorState> navKey;

  Future<SaveNode> save(
    WidgetTester tester,
    String comment, {
    String? parent,
  }) async {
    final node = (await tester.runAsync(
      () => saves.saveAsChild(
        projectId: project.id,
        project: project,
        scenes: projects.scenesOf(project.id),
        tileManager: projects.tileManagerOf(project.id),
        parentId: parent,
        comment: comment,
      ),
    ))!;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    return node;
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
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
    saves.setTreeMode(true);
    project = (await tester.runAsync(
      () => projects.createProject(
        name: 'ツリー',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
  }

  Future<void> showTree(WidgetTester tester) async {
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

  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile));

  Future<void> deleteFromMenu(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: row(name),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await settleIo(tester, 4);
    await tester.tap(find.text('削除').last);
    await settleIo(tester, 4);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '削除'),
      ),
    );
    await settleIo(tester, 6);
  }

  testWidgets('a save whose parent was deleted is still drawn (as a root), '
      'also in the selection screen of a mode change', (tester) async {
    await open(tester);
    final a = await save(tester, 'A');
    final c = await save(tester, 'C', parent: a.id);
    await save(tester, 'D', parent: c.id);
    await showTree(tester);
    expect(row('D'), findsOneWidget);
    await deleteFromMenu(tester, 'C');
    expect(row('C'), findsNothing);
    expect(
      row('D'),
      findsOneWidget,
      reason: 'the save on the deleted save vanished from the tree',
    );
    expect(row('A'), findsOneWidget);
    // 保存方式の変更で残す保存を選ぶ画面にも出る。
    final flow = showSaveModeChangeFlowIfNeeded(
      context: navKey.currentContext!,
      projectId: project.id,
      saveService: saves,
      newIsTreeMode: false,
      newSlotMax: 1,
    );
    await settleIo(tester, 3);
    await tester.tap(find.text('保存データを選択'));
    await settleIo(tester, 3);
    expect(find.widgetWithText(CheckboxListTile, 'D'), findsNothing);
    expect(
      find.ancestor(of: find.text('D'), matching: find.byType(ListTile)),
      findsOneWidget,
      reason: 'the save cannot be chosen to keep',
    );
    await tester.tap(find.byTooltip('戻る').last);
    await settleIo(tester, 2);
    await tester.tap(find.text('キャンセル').last);
    await settleIo(tester, 3);
    await tester.runAsync(() => flow);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('after deleting the selected save, Save makes a root that is '
      'drawn', (tester) async {
    await open(tester);
    await save(tester, 'A');
    await save(tester, 'B');
    await showTree(tester);
    await tester.tap(find.text('B'));
    await settleIo(tester, 1);
    await deleteFromMenu(tester, 'B');
    expect(row('B'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 2);
    expect(
      find.text('選択中のノードの子として保存します。'),
      findsNothing,
      reason: 'the dialog still saves under the deleted save',
    );
    expect(find.text('ルートノードとして保存します。'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'N',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 10);
    expect(find.byType(AlertDialog), findsNothing);
    expect(row('N'), findsOneWidget, reason: 'the new save is not drawn');
    expect(
      saves.getNodes(project.id).firstWhere((n) => n.comment == 'N').parentId,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
