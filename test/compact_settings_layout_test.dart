import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/font_settings_screen.dart';
import 'package:niarim/screens/settings/pc_workspace_layout_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/project_storage.dart';

void main() {
  useTemporaryProjectStorage();
  const locale = Locale('fr');
  final l10n = lookupAppLocalizations(locale);

  Future<void> openScreen(WidgetTester tester, Size size, Widget screen) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({'language': 'fr'});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeDataFor(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('short font tabs keep the catalog and import reachable', (
    tester,
  ) async {
    await openScreen(tester, const Size(520, 250), const FontSettingsScreen());
    expect(find.text(l10n.fontEmptyTitle).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    final tabs = find.byType(Tab);
    await tester.tap(tabs.at(2));
    await tester.pumpAndSettle();
    expect(find.text(l10n.fontSelectFileButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 230);
    await tester.pumpAndSettle();
    await tester.tap(tabs.at(1));
    await tester.pumpAndSettle();
    final categories = find.byTooltip(l10n.fontCatalogCategories);
    expect(categories.hitTestable(), findsOneWidget);
    await tester.tap(categories);
    await tester.pumpAndSettle();
    final sansSerif = find.text(l10n.fontCategorySansSerif);
    expect(sansSerif.hitTestable(), findsOneWidget);
    await tester.tap(sansSerif);
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.enterText(search, 'Abel');
    await tester.pumpAndSettle();
    final abel = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Abel'),
    );
    await tester.ensureVisible(abel);
    await tester.pumpAndSettle();
    expect(abel.hitTestable(), findsOneWidget);

    tester.view.physicalSize = const Size(390, 760);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Abel',
    );
    expect(abel.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short workspace windows fit the preview and expose reset', (
    tester,
  ) async {
    await openScreen(
      tester,
      const Size(600, 340),
      const PcWorkspaceLayoutSettingsScreen(),
    );
    final viewer = find.byKey(const Key('pcWorkspaceInteractivePreview'));
    expect(tester.getSize(viewer).height, greaterThanOrEqualTo(180));
    expect(
      find.byKey(const Key('desktopDockAutoCollapseSwitch')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final reset = find.byTooltip(l10n.pcLayoutResetWorkspace);
    expect(reset.hitTestable(), findsOneWidget);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);

    tester.view.physicalSize = const Size(600, 220);
    await tester.pumpAndSettle();
    final zoom = tester.widget<InteractiveViewer>(viewer);
    final scene = tester.getSize(find.byWidget(zoom.child!));
    final viewport = tester.getSize(viewer);
    final visibleScale = zoom.transformationController!.value.entry(0, 0);
    expect(scene.height * visibleScale, lessThanOrEqualTo(viewport.height + 1));
    expect(scene.width * visibleScale, lessThanOrEqualTo(viewport.width + 1));
    expect(tester.takeException(), isNull);
  });
}
