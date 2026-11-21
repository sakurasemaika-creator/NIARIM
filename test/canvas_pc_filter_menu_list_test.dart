import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// PCの作業画面で設定/編集メニューの「フィルター」を押したら、まずフィルターの
/// 一覧を窓に出す（DISC149：一覧を出さずに前に選んだフィルターの調整へ入り、
/// スマホと同じ調整モードになってドック・ツールバーが消えた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('PC: the edit menu opens the filter list, not a filter', (
    tester,
  ) async {
    tempDir = Directory.systemTemp.createTempSync('niarim_pc_filter_menu_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
    });
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    final filters = home.read<FilterService>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'フィルターの一覧',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      );
      id = project.id;
    });
    appRouter.push('/canvas/$id');
    await settle(tester, 12);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;

    Future<void> openFromMenu() async {
      await tester.tap(find.byIcon(Icons.settings).first);
      await settle(tester, 3);
      await tester.tap(find.text(l10n.filterPanelTitle).last);
      await settle(tester, 4);
    }

    for (final round in ['first', 'after a filter was chosen and closed']) {
      await openFromMenu();
      expect(tester.takeException(), isNull, reason: round);
      expect(find.byType(FilterPanel), findsOneWidget, reason: round);
      expect(filters.currentFilter, isNull, reason: round);
      expect(
        find.byKey(const ValueKey('filter-tile-grid')),
        findsOneWidget,
        reason: '$round: the list is shown',
      );
      expect(
        find.byKey(const ValueKey('filter-bottom-bar')),
        findsNothing,
        reason: '$round: not the phone adjusting mode',
      );
      // Choose a filter (enters adjusting), then close the panel from the
      // menu without applying.
      filters.selectFilter('Filter0001');
      await settle(tester, 3);
      expect(filters.currentFilter?.id, 'Filter0001');
      await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
      await settle(tester, 4);
      if (find.byType(FilterPanel).evaluate().isNotEmpty) {
        // Back on the list: close the window through the menu.
        await openFromMenu();
      }
      expect(find.byType(FilterPanel), findsNothing, reason: round);
    }
  });
}
