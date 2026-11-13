import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('works uses project-like sort, view mode and contextual menus', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      // This test compares vertical detail-list sorting; default mode is now
      // a responsive tile grid, covered by separate tests.
      'home.worksViewMode.v1': 'detail',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('works-controls-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, (_) async => dir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathProvider, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    await tester.runAsync(() async {
      final directory = await ExportEngine.exportsDir();
      final data = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      for (final (index, name) in [
        (0, 'Charlie.gif'),
        (1, 'Alpha.gif'),
        (2, 'Bravo.gif'),
      ]) {
        final file = File(directory.path + '/' + name);
        await file.writeAsBytes(data);
        await file.setLastModified(DateTime.utc(2026, 10, 1 + index));
      }
      await ExportEngine.listExportedFiles(forceRefresh: true);
    });

    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 700));
    // The project and exported-work sort controls must use the exact same
    // header placement and tap-target geometry, not a 96px Works-only strip.
    final projectHeaderRect = tester.getRect(
      find.byKey(const Key('homeCollectionSortHeader')),
    );
    final projectSortRect = tester.getRect(find.byType(SortModeControl));
    final projectSizeButtonRect = tester.getRect(
      find.byKey(const Key('homeCollectionViewModeMenu')),
    );
    final worksTab = find.byKey(const ValueKey('home_tab_1'));
    await tester.ensureVisible(worksTab);
    await tester.tap(worksTab);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    for (
      var attempt = 0;
      attempt < 8 && find.byType(ExportedWorkCard).evaluate().isEmpty;
      attempt++
    ) {
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
    }
    expect(find.byType(ExportedWorkCard), findsNWidgets(3));
    final context = tester.element(find.byType(ExportedWorkCard).first);
    final l10n = AppLocalizations.of(context)!;
    final worksHeaderRect = tester.getRect(
      find.byKey(const Key('homeCollectionSortHeader')),
    );
    final worksSortRect = tester.getRect(find.byType(SortModeControl));
    final worksSizeButtonRect = tester.getRect(
      find.byKey(const Key('homeCollectionViewModeMenu')),
    );
    expect(worksHeaderRect.top, closeTo(projectHeaderRect.top, 1));
    expect(worksHeaderRect.height, closeTo(projectHeaderRect.height, 1));
    expect(worksSortRect.right, closeTo(projectSortRect.right, 1));
    expect(worksSizeButtonRect.size, projectSizeButtonRect.size);
    expect(worksSizeButtonRect.top, closeTo(projectSizeButtonRect.top, 1));
    // Search is now available in every Home tab, so size controls share
    // identical coordinates as well as dimensions.
    expect(worksSizeButtonRect.left, closeTo(projectSizeButtonRect.left, 1));
    expect(
      find.text(l10n.homeSortFieldUpdated),
      findsOneWidget,
      reason: 'Works should display the same readable sort label as Projects',
    );
    // When the field label fits, the small clock icon fallback is not needed.
    expect(
      find.descendant(
        of: find.byType(SortModeControl),
        matching: find.byIcon(Icons.update),
      ),
      findsNothing,
    );

    Finder card(String filename) => find.byWidgetPredicate(
      (w) => w is ExportedWorkCard && w.name == filename,
    );
    List<String> visualOrder() {
      final names = ['Alpha.gif', 'Bravo.gif', 'Charlie.gif'];
      names.sort(
        (a, b) => tester
            .getTopLeft(card(a))
            .dy
            .compareTo(tester.getTopLeft(card(b)).dy),
      );
      return names;
    }

    expect(find.byType(ExportedWorkCard), findsNWidgets(3));
    expect(visualOrder(), ['Bravo.gif', 'Alpha.gif', 'Charlie.gif']);
    await tester.tap(
      find.byTooltip(l10n.homeSortFieldUpdated).hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.homeSortFieldName).last);
    await tester.pumpAndSettle();
    expect(visualOrder(), ['Charlie.gif', 'Bravo.gif', 'Alpha.gif']);
    await tester.tap(
      find.byTooltip(l10n.homeSortDirectionDescTooltip).hitTestable().first,
    );
    await tester.pumpAndSettle();
    expect(visualOrder(), ['Alpha.gif', 'Bravo.gif', 'Charlie.gif']);

    final viewMenu = find.byKey(const Key('homeCollectionViewModeMenu'));
    expect(viewMenu, findsOneWidget);
    await tester.tap(viewMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.homeViewModeSmall).last);
    await tester.pumpAndSettle();
    expect(tester.widget<ExportedWorkCard>(card('Alpha.gif')).gridTile, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('home.worksViewMode.v1'), 'small');

    final menu = find.byKey(const Key('exportedWorkMoreMenu')).first;
    await tester.tap(menu);
    await tester.pumpAndSettle();
    for (final text in ['開く', 'コピー', 'サムネイル変更', '削除']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // The Home tab bar includes its Trash icon; only the export card itself
    // must omit an inline delete button.
    expect(
      find.descendant(
        of: find.byType(ExportedWorkCard).first,
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
