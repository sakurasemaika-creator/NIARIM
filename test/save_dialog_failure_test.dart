import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 手動の保存（セーブスロット・セーブツリー）に失敗したとき、保存の
/// ダイアログは開いたまま失敗を出し、打ったコメントを残すこと。以前は
/// ダイアログを閉じてSnackBarを出していたので、もう一度試すにはコメントを
/// 打ち直すしかなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_save_failure_');
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

  // 保存の置き場所をファイルにして、保存が必ず失敗するようにした作品を開く。
  Future<({SaveTreeService saves, String id, File blocker})> open(
    WidgetTester tester, {
    required bool tree,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    final saves = home.read<SaveTreeService>()..setTreeMode(tree);
    late String id;
    late File blocker;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: '保存',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
      blocker = File('${tempDir.path}/niarim/projects/$id/SaveTree')
        ..writeAsStringSync('');
    });
    appRouter.push('/save-tree/$id');
    await settleIo(tester, 6);
    return (saves: saves, id: id, blocker: blocker);
  }

  Future<void> typeAndSave(WidgetTester tester, String comment) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      comment,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 10);
  }

  Future<void> expectFailureKept(WidgetTester tester, Key failure) async {
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(failure), findsOneWidget);
    expect(find.textContaining('保存に失敗しました'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '線画まで',
    );
  }

  testWidgets('a failed slot save keeps the dialog and the comment', (
    tester,
  ) async {
    final s = await open(tester, tree: false);
    await tester.tap(find.byTooltip('このスロットへ保存').first);
    await settleIo(tester, 3);
    await typeAndSave(tester, '線画まで');
    await expectFailureKept(tester, const Key('saveSlotDialogFailure'));
    expect(s.saves.getNodes(s.id), isEmpty);

    // 置き場所を直してもう一度押すと、打ったコメントのまま保存できる。
    await tester.runAsync(() async => s.blocker.deleteSync());
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 10);
    expect(find.byType(AlertDialog), findsNothing);
    expect(s.saves.getNodes(s.id).single.comment, '線画まで');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed tree save keeps the dialog and the comment', (
    tester,
  ) async {
    final s = await open(tester, tree: true);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await settleIo(tester, 3);
    await typeAndSave(tester, '線画まで');
    await expectFailureKept(tester, const Key('saveTreeDialogFailure'));
    expect(s.saves.getNodes(s.id), isEmpty);

    await tester.runAsync(() async => s.blocker.deleteSync());
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settleIo(tester, 10);
    expect(find.byType(AlertDialog), findsNothing);
    expect(s.saves.getNodes(s.id).single.comment, '線画まで');
    expect(tester.takeException(), isNull);
  });
}
