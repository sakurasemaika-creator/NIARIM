import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 保存のダイアログ（保存の管理の「スロットNに保存」、ツリーの「保存」）を、
/// 保存している間に端末の「戻る」で閉じたとき：保存が失敗したら画面に
/// 知らせを出す（以前はダイアログが無いので記録にだけ残り、誰にも知らされ
/// なかった）。保存が終わったときは、もう閉じたダイアログの代わりに下の
/// 画面を閉じない（自分のダイアログが一番上のときだけ閉じる）。保存中の
/// 戻るでダイアログを閉じられること自体は、他のセッションのテスト
/// （startup_unreadable_projects_folder_testの「Back during a slot save」）が
/// 使う道順なので変えない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_dialog_back_');
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

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<({SaveTreeService saves, String id})> open(
    WidgetTester tester, {
    required bool tree,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService projects;
    late SaveTreeService saves;
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
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: '戻る',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SaveManagementScreen(
          projectId: project.id,
          entryMode: SaveTreeEntryMode.projectDetail,
        ),
      ),
    );
    await settleIo(tester, 4);
    return (saves: saves, id: project.id);
  }

  String saveTree(String id) => '${dir.path}/niarim/projects/$id/SaveTree';

  Future<void> startSave(WidgetTester tester, {required bool tree}) async {
    if (tree) {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar).last,
          matching: find.widgetWithText(FilledButton, '保存'),
        ),
      );
    } else {
      await tester.tap(find.byTooltip('このスロットへ保存').first);
    }
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
    await tester.pump();
  }

  for (final tree in [false, true]) {
    final name = tree ? 'tree' : 'slot';
    testWidgets('$name save dialog closed with the system back while saving: '
        'a failed save is shown on the screen', (tester) async {
      final s = await open(tester, tree: tree);
      // 保存を失敗させる（SaveTreeのフォルダの場所がファイル）。
      await tester.runAsync(() async {
        final folder = Directory(saveTree(s.id));
        if (folder.existsSync()) folder.deleteSync(recursive: true);
        File(folder.path).writeAsStringSync('');
      });
      await startSave(tester, tree: tree);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await settleIo(tester, 12);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('保存に失敗しました'),
        ),
        findsOneWidget,
        reason: 'the failed save was not told to anybody',
      );
      expect(find.byType(SaveManagementScreen), findsOneWidget);
      expect(s.saves.getNodes(s.id), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$name save dialog closed with the system back while a save '
        'succeeds: the screen under it stays', (tester) async {
      final s = await open(tester, tree: tree);
      await startSave(tester, tree: tree);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await settleIo(tester, 12);
      expect(
        find.byType(SaveManagementScreen),
        findsOneWidget,
        reason: 'the end of the save closed the screen under the dialog',
      );
      expect(s.saves.getNodes(s.id), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
