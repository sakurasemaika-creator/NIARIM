import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 所有者の判断2：フォルダのメニュー（︙・右クリック）の「ゴミ箱へ移動」は、
/// 選んでゴミ箱へ移すときと同じく、中身（下の階層のフォルダ・作品）ごと
/// ゴミ箱へ移す。確かめるダイアログには中身の件数を出し、移した後は
/// 「元に戻す」で中身ごと戻せる。お気に入りの作品が中にあれば移さない。
/// 以前はメニューからだと件数の確認も「元に戻す」も無かった（DISC098の3）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_folder_menu_trash_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'home_view_mode': 'medium',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await settle(tester, rounds: 1);
    }
    await settle(tester);
  }

  Future<Project> work(ProjectService service, String name) async {
    final project = await service.createProject(
      name: name,
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return project;
  }

  /// 親 ─ 子 ─ 孫 の3階層に1作品ずつ、一番上に1作品、空のフォルダ1つ。
  Future<ProjectService> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final service = tester
        .element(find.byType(SplashScreen))
        .read<ProjectService>();
    await tester.runAsync(() async {
      final parent = await service.createFolder('親');
      final child = await service.createFolder('子', parentFolderId: parent.id);
      final grandchild = await service.createFolder(
        '孫',
        parentFolderId: child.id,
      );
      await service.createFolder('空');
      await work(service, '上の作品');
      for (final (name, folder) in [
        ('親の作品', parent.id),
        ('子の作品', child.id),
        ('孫の作品', grandchild.id),
      ]) {
        final project = await work(service, name);
        await service.moveToFolder(project.id, folder);
      }
    });
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    return service;
  }

  Finder card(String name) => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.text(name),
  );

  Future<void> trashFromMenu(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: card(name), matching: find.byType(Card)).first,
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    // メニューが開き終わるまで待つ。
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester, rounds: 3);
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester, rounds: 3);
  }

  Future<void> trashFromSelection(WidgetTester tester, String name) async {
    await tester.longPress(card(name).first);
    await settle(tester, rounds: 3);
    await tester.tap(find.byTooltip(l10n.homeMoveToTrash).first);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester, rounds: 3);
  }

  /// 開いている確かめるダイアログの文（見出し・対象・本文・ボタン）。
  List<String> dialogTexts(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Text),
      ),
    ))
      text.data ?? text.textSpan!.toPlainText(),
  ];

  testWidgets('the folder menu moves the folder with its contents to Trash '
      'with the same confirmation as a selection, and undo brings them back', (
    tester,
  ) async {
    final service = await boot(tester);

    // 選んでゴミ箱へ移すときの確かめるダイアログ（取り消す）。
    await trashFromSelection(tester, '親');
    final fromSelection = dialogTexts(tester);
    await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
    await settle(tester, rounds: 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, rounds: 3);

    // フォルダのメニューからも、同じ文で中身の件数を確かめる。
    await trashFromMenu(tester, '親');
    final fromMenu = dialogTexts(tester);
    expect(
      fromMenu,
      fromSelection,
      reason: 'the menu and the selection confirm in the same words',
    );
    expect(
      fromMenu.join('\n'),
      contains(
        l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(3, 2)),
      ),
    );
    expect(fromMenu, contains('親'));
    await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
    await waitFor(tester, () => service.trashedFolders.isNotEmpty);
    expect(service.folders.map((f) => f.name), ['空']);
    expect(service.projects.map((p) => p.name), ['上の作品']);
    expect(service.trashedFolders.single.folder.name, '親');
    expect(service.trashedFolders.single.projectIds, hasLength(3));

    // 「元に戻す」で中身ごと戻る。
    final snack = find.byType(SnackBar);
    expect(
      find.descendant(
        of: snack,
        matching: find.text(l10n.homeMovedToTrashSnackbar(1)),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: snack, matching: find.text(l10n.homeUndoAction)),
    );
    await waitFor(tester, () => service.projects.length == 4);
    await settle(tester);
    expect(service.trashedFolders, isEmpty);
    expect(service.trash, isEmpty);
    expect(service.folders, hasLength(4));
    expect(card('親'), findsOneWidget);

    // 空のフォルダでは中身の行を出さない。
    await trashFromMenu(tester, '空');
    expect(
      dialogTexts(tester).join('\n'),
      isNot(contains(l10n.homeMoveToTrashFolderContents(''))),
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(l10n.homeFolderContents(0, 0)),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
    await settle(tester, rounds: 3);
    expect(service.folders, hasLength(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the folder menu does not move a folder holding a favourite '
      'work, just like a selection', (tester) async {
    final service = await boot(tester);
    final favourite = service.projects.firstWhere((p) => p.name == '孫の作品');
    await tester.runAsync(() => service.toggleFavorite(favourite.id));
    await settle(tester);

    await trashFromMenu(tester, '親');
    expect(find.byKey(const Key('trash-dialog-confirm')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(l10n.commonFavoriteDeleteBlocked),
      ),
      findsOneWidget,
    );
    expect(service.trashedFolders, isEmpty);
    expect(service.folders, hasLength(4));
    expect(service.projects, hasLength(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
