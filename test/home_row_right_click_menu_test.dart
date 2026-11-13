import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホームの一覧の行・カードを右クリックすると、その行の︙と同じメニューが
/// 押した所に出ること（PC・DeX・マウス）。以前は「大・中・小」のカードの
/// プロジェクトだけで、一覧表示の行・共有の受け取ったもの・作成したもの・
/// 共有と作品のフォルダでは何も起きなかった。作品の書き出したファイルの
/// 右クリック（選ぶ）は変えない。本物のNiarimAppを起動処理から組み立てる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_home_rclick_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProjectService> boot(WidgetTester tester, String viewMode) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      'home.projectViewMode.v1': viewMode,
      'home.sharedViewMode.v1': viewMode,
      'home.worksViewMode.v1': viewMode,
    });
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ExportStorage.invalidate();
    Directory('${tempDir.path}/exports').createSync();
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    final workFolders = home.read<WorkFolderService>();
    await tester.runAsync(() async {
      await service.createProject(
        name: 'apple',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await service.createFolder('box');
      await service.createSharedFolder('inbox');
      final gift = await service.importSharedProject(
        NiaproData(
          project: Project(
            id: 'source',
            name: 'gift',
            fps: 1,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 64,
            exportHeight: 64,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            totalWorkSeconds: 0,
          ),
          scenes: const [],
          tileData: const {},
        ),
      );
      await service.saveProject(gift.id);
      final outgoing = await service.createProject(
        name: 'letter',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      await service.saveProject(outgoing.id);
      await service.createOutgoingShare(project: outgoing);
      await workFolders.createFolder('reel');
    });
    await settleIo(tester);
    return service;
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;

  Future<void> showTab(WidgetTester tester, int index) async {
    tester
        .widget<TabBarView>(find.byType(TabBarView))
        .controller!
        .animateTo(index);
    await settle(tester);
    await settleIo(tester);
  }

  Future<Offset> rightClick(WidgetTester tester, Finder target) async {
    final at = tester.getCenter(target);
    await tester.tapAt(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await settle(tester);
    return at;
  }

  /// 押した所に出たポップアップのメニュー（項目の文字）。
  List<String> popupAt(WidgetTester tester, Offset at) {
    final items = find.byWidgetPredicate((w) => w is PopupMenuItem<String>);
    if (items.evaluate().isEmpty) return const [];
    final first = tester.getRect(items.first);
    // メニューは押した所から出る（画面の端で入らないときだけずれる）。
    expect(
      (first.topLeft - at).distance,
      lessThan(48),
      reason: 'menu at ${first.topLeft}, click at $at',
    );
    return [
      for (final element in items.evaluate())
        if ((element.widget as PopupMenuItem<String>).child case final Text t)
          t.data ?? '',
    ];
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
  }

  testWidgets('Projects list rows open their menu at the pointer', (
    tester,
  ) async {
    final service = await boot(tester, 'detail');
    final text = l10n(tester);
    final apple = find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.widgetWithText(ListTile, 'apple'),
    );
    expect(apple, findsOneWidget);
    var at = await rightClick(tester, apple);
    final items = popupAt(tester, at);
    expect(items, contains(text.projectListOpenAction));
    expect(items, contains(text.commonRename));
    // ︙と同じ処理が動く（お気に入りへ追加）。
    await tester.tap(find.text(text.colorPickerFavoriteAdd).last);
    await settleIo(tester);
    expect(
      service.projects.firstWhere((p) => p.name == 'apple').isFavorite,
      true,
    );

    final box = find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.widgetWithText(ListTile, 'box'),
    );
    at = await rightClick(tester, box);
    expect(popupAt(tester, at), contains(text.projectListOpenAction));
    await closeMenu(tester);

    // 選んでいる間は右クリックでメニューを出さない（カードと同じ）。
    await tester.longPress(apple);
    await settle(tester);
    at = await rightClick(tester, apple);
    expect(popupAt(tester, at), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final view in ['detail', 'medium']) {
    testWidgets('Shared rows ($view) open their menu on right click', (
      tester,
    ) async {
      await boot(tester, view);
      final text = l10n(tester);
      await showTab(tester, 2);
      // 受け取ったもの：作品のメニューを押した所に出す。同じ名前の項目は
      // 並べない（以前は「複製」が2つあった）。
      var at = await rightClick(tester, find.text('gift').first);
      var items = popupAt(tester, at);
      expect(items, contains(text.projectListCreateShareAction));
      expect(items.toSet(), hasLength(items.length), reason: '$items');
      await closeMenu(tester);
      // 共有のフォルダ：︙と同じフォルダのメニュー（下から出るシート）。
      await rightClick(tester, find.text('inbox').first);
      expect(find.byType(BottomSheet), findsOneWidget);
      await closeMenu(tester);
      expect(find.byType(BottomSheet), findsNothing);
      // 自分が作成したもの：共有ファイルのメニューを押した所に出す。
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await settleIo(tester);
      at = await rightClick(tester, find.text('letter').first);
      items = popupAt(tester, at);
      expect(items, contains(text.projectDetailShareQuickAction));
      expect(items.toSet(), hasLength(items.length), reason: '$items');
      await closeMenu(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Works folders open their menu on right click; a right click '
      'on an exported file still selects it', (tester) async {
    // 書き出したファイル（1×1の画像）。
    File('${tempDir.path}/niarim/exports/clip.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        ),
      );
    await boot(tester, 'detail');
    await showTab(tester, 1);
    await rightClick(tester, find.text('reel').first);
    expect(find.byType(BottomSheet), findsOneWidget);
    await closeMenu(tester);
    // 書き出したファイルの右クリックは選ぶ（メニューは出さない）。
    final clip = find.textContaining('clip').first;
    final at = await rightClick(tester, clip);
    expect(popupAt(tester, at), isEmpty);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'homeSelectedMarker_work_file:',
            ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
