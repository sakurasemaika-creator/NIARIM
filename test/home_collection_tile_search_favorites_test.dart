import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('default Works tiles, persisted favorites and search on all tabs',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('home-collections-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => tempDir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final alphaPath = (await tester.runAsync(() async {
      final exports = await ExportEngine.exportsDir();
      final gif = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
      for (final name in ['Alpha.gif', 'Beta.gif', 'Deleted.gif']) {
        await File(exports.path + '/' + name).writeAsBytes(gif);
      }
      await LocalFileTrashService.move(
        File(exports.path + '/Deleted.gif'), LocalTrashKind.exportedWork);
      await ExportEngine.listExportedFiles(forceRefresh: true);
      return exports.path + '/Alpha.gif';
    }))!;

    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(MultiProvider(
      providers: providers!, child: const NiarimApp()));
    await pumpRealAsync(tester, const Duration(milliseconds: 450));

    Future<void> openTab(int i) async {
      final target = find.byKey(ValueKey('home_tab_$i'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await pumpRealAsync(tester, const Duration(milliseconds: 350));
    }
    void checkSearchPlacement() {
      final search = tester.getRect(find.byKey(const Key('homeSearchButton')));
      final menu = tester.getRect(find.byKey(const Key('homeMenuButton')));
      expect(search.right, lessThanOrEqualTo(menu.left));
    }
    Future<void> search(String query) async {
      checkSearchPlacement();
      await tester.tap(find.byKey(const Key('homeSearchButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homeSearchInput')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('homeSearchInput')), query);
      await pumpRealAsync(tester, const Duration(milliseconds: 170));
    }
    Future<void> closeSearch() async {
      await tester.tap(find.byKey(const Key('homeSearchCloseButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homeSearchButton')), findsOneWidget);
    }
    checkSearchPlacement();
    await search('unused');
    expect(find.byKey(const Key('homeSearchTagToggle')), findsOneWidget);
    await closeSearch();

    await openTab(1);
    for (var attempt = 0;
         attempt < 8 && find.byType(ExportedWorkCard).evaluate().isEmpty;
         attempt++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 150));
    }
    Finder work(String name) => find.byWidgetPredicate(
      (w) => w is ExportedWorkCard && w.name == name);
    expect(find.byType(ExportedWorkCard), findsNWidgets(2));
    expect(tester.widget<ExportedWorkCard>(
      work('Alpha.gif')).gridTile, isTrue);
    // Exported Works must share the Projects layout: top-right menu and
    // bottom-left favorite, not two controls side by side at the top.
    final favorite = find.descendant(
      of: work('Alpha.gif'),
      matching: find.byType(CollectionFavoriteButton));
    final menu = find.descendant(
      of: work('Alpha.gif'),
      matching: find.byKey(const Key('exportedWorkMoreMenu')));
    expect(favorite, findsOneWidget);
    expect(menu, findsOneWidget);
    final favoriteRect = tester.getRect(favorite);
    final menuRect = tester.getRect(menu);
    expect(favoriteRect.left, lessThan(menuRect.left));
    expect(favoriteRect.center.dy, greaterThan(menuRect.center.dy));
    await tester.tap(favorite);
    await pumpRealAsync(tester, const Duration(milliseconds: 150));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home.works.favoritePaths.v1'),
        contains(alphaPath));
    await tester.tap(find.byKey(const Key('worksFavoritesOnlyFilter')));
    await tester.pumpAndSettle();
    expect(work('Alpha.gif'), findsOneWidget);
    expect(work('Beta.gif'), findsNothing);
    await tester.tap(find.byKey(const Key('worksFavoritesOnlyFilter')));
    await tester.pumpAndSettle();
    await search('Beta');
    expect(work('Alpha.gif'), findsNothing);
    expect(work('Beta.gif'), findsOneWidget);
    await closeSearch();

    await openTab(2);
    expect(find.byKey(const Key('homeCollectionViewModeMenu')),
        findsOneWidget);
    await search('share');
    await closeSearch();

    await openTab(3);
    for (var attempt = 0;
         attempt < 8 && find.text('Deleted.gif').evaluate().isEmpty;
         attempt++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 120));
    }
    expect(find.text('Deleted.gif'), findsOneWidget);
    await search('Alpha');
    expect(find.text('Deleted.gif'), findsNothing);
    await closeSearch();
    expect(find.text('Deleted.gif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
