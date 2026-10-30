import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// ホームの一覧のスクロール位置（DISC007の関連一覧）：作品一覧・ブクマ済みも
/// タブを行き来して戻ると同じ位置。プロジェクトはフォルダの中と外、
/// お気に入りの絞り込みで位置を共有しない（フォルダから戻ると外の位置、
/// もう一度入るとフォルダの中の位置）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1×1の透明なPNG。
  const png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  Future<Directory> open(
    WidgetTester tester, {
    required bool pc,
    Future<void> Function(Directory documents)? seed,
    String? viewMode,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': pc ? 1 : 0,
      'home_view_mode': ?viewMode,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('home-related-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    await tester.runAsync(() async => seed?.call(directory));
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    tester.view.physicalSize = pc
        ? const Size(1440, 900)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    return directory;
  }

  Future<void> tab(WidgetTester tester, int index) async {
    final finder = find.byKey(ValueKey('home_tab_$index'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // 縦に送る一覧（タブを切り替える横のページではない方）。
  Finder scrollableIn(Finder parent) => find
      .descendant(
        of: parent,
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      )
      .first;

  double offset(WidgetTester tester, Finder scrollable) =>
      tester.state<ScrollableState>(scrollable).position.pixels;

  for (final pc in [false, true]) {
    final mode = pc ? 'PC' : 'SP';

    testWidgets('$mode works list keeps its place across tabs and the menu', (
      tester,
    ) async {
      await open(
        tester,
        pc: pc,
        seed: (documents) async {
          final exports = Directory('${documents.path}/exports')
            ..createSync(recursive: true);
          for (var i = 0; i < 60; i++) {
            File(
              '${exports.path}/work_${i.toString().padLeft(3, '0')}.png',
            ).writeAsBytesSync(png);
          }
        },
      );
      await tab(tester, 1);
      final works = find.byKey(const PageStorageKey('home-works'));
      final list = scrollableIn(works);
      await tester.drag(list, const Offset(0, -1200));
      await tester.pumpAndSettle();
      final before = offset(tester, list);
      expect(before, greaterThan(300));
      await tab(tester, 0);
      await tab(tester, 2);
      await tab(tester, 1);
      expect(offset(tester, scrollableIn(works)), closeTo(before, .1));
      await tester.tap(find.byKey(const Key('homeMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text('設定')),
      );
      await tester.pumpAndSettle();
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(offset(tester, scrollableIn(works)), closeTo(before, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$mode bookmarks keep their place across tabs', (tester) async {
      await open(tester, pc: pc);
      final community = tester
          .element(find.byType(HomeScreen))
          .read<CommunityService>();
      for (final work in community.works) {
        if (!community.bookmarkedIds.contains(work.id)) {
          await tester.runAsync(() => community.toggleBookmark(work.id));
        }
      }
      await tester.pumpAndSettle();
      expect(community.bookmarkedWorksForViewer.length, greaterThan(8));
      await tab(tester, 2);
      final bookmarks = find.byKey(const PageStorageKey('home-bookmarks'));
      final list = scrollableIn(bookmarks);
      await tester.drag(list, const Offset(0, -900));
      await tester.pumpAndSettle();
      final before = offset(tester, list);
      expect(before, greaterThan(pc ? 100 : 200));
      await tab(tester, 0);
      await tab(tester, 2);
      expect(offset(tester, scrollableIn(bookmarks)), closeTo(before, .1));
      expect(community.bookmarkedIds, isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      '$mode projects keep separate places inside and outside a folder',
      (tester) async {
        // PCの格子は1行に多く並びスクロールしないので、一覧（詳細）表示で。
        await open(tester, pc: pc, viewMode: pc ? 'detail' : null);
        final service = tester
            .element(find.byType(ProjectListWidget))
            .read<ProjectService>();
        late final String folderName;
        await tester.runAsync(() async {
          final folder = await service.createFolder('A003 フォルダ');
          folderName = folder.name;
          for (var i = 0; i < 90; i++) {
            final project = await service.createProject(
              name: 'A003 ${i.toString().padLeft(3, '0')}',
              fps: 1,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 32,
              exportHeight: 32,
            );
            if (i.isOdd) await service.moveToFolder(project.id, folder.id);
            if (i % 30 == 0) await service.toggleFavorite(project.id);
          }
        });
        await tester.pumpAndSettle();
        Finder list() => scrollableIn(find.byType(ProjectListWidget));

        // フォルダの中で下へ送ってから戻っても、外は先頭のまま
        // （フォルダの中の位置を持ち出さない）。
        await tester.tap(find.text(folderName).first);
        await tester.pumpAndSettle();
        expect(offset(tester, list()), 0, reason: 'a folder starts at the top');
        await tester.drag(list(), const Offset(0, -600));
        await tester.pumpAndSettle();
        final inside = offset(tester, list());
        expect(inside, greaterThan(100));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(folderName), findsWidgets);
        expect(offset(tester, list()), 0, reason: 'outside keeps its place');

        // もう一度入るとフォルダの中の位置。
        await tester.tap(find.text(folderName).first);
        await tester.pumpAndSettle();
        expect(offset(tester, list()), closeTo(inside, .1));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // お気に入りだけにすると先頭から、戻すと元の位置。絞り込みは一覧と
        // 一緒にスクロールするので、絞り込みが見えている所で押す。
        await tester.drag(list(), const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(offset(tester, list()), greaterThan(300));
        await tester.drag(list(), const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.drag(list(), const Offset(0, -40));
        await tester.pumpAndSettle();
        final outside = offset(tester, list());
        expect(outside, greaterThan(5));
        final l10n = AppLocalizations.of(
          tester.element(find.byType(HomeScreen)),
        )!;
        final favorites = find.widgetWithText(
          FilterChip,
          l10n.homeFavoritesOnly,
        );
        await tester.tap(favorites);
        await tester.pumpAndSettle();
        expect(offset(tester, list()), 0, reason: 'favorites start at the top');
        await tester.tap(favorites);
        await tester.pumpAndSettle();
        expect(offset(tester, list()), closeTo(outside, .1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
