import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

Widget host(
  ThemeService themes,
  CommunityService community,
  CommunityPreviewService preview, {
  Locale locale = const Locale('fr'),
  double scale = 1.3,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: community),
    ChangeNotifierProvider.value(value: preview),
    ChangeNotifierProvider(create: (_) => SettingsService()),
    ChangeNotifierProvider(create: (_) => PremiumService()),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: themes.themeData,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Stack(children: [child!, const CommunityFloatingPreview()]),
    ),
    home: const CommunityScreen(),
  ),
);

void main() {
  testWidgets(
    'plaza title and controls preserve configured colors and complete labels',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await themes.init();
      themes.previewCurrent(
        AppThemePreset.defaultLight.copyWith(
          accentColor: Colors.white,
          selectionColor: Colors.black,
        ),
      );
      final community = CommunityService();
      final preview = CommunityPreviewService();
      addTearDown(themes.dispose);
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);
      await tester.pumpWidget(host(themes, community, preview));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CommunityScreen)),
      )!;
      final theme = Theme.of(tester.element(find.byType(AppBar)));
      final failures = <String>[];
      for (final label in [
        l10n.communityScreenTitle,
        l10n.communityTabNew,
        l10n.communityTabRanking,
        l10n.communityTabFavoriteAuthors,
      ]) {
        final finder = find.descendant(
          of: find.byType(AppBar),
          matching: find.text(label),
        );
        expect(finder, findsOneWidget);
        final p = tester.renderObject<RenderParagraph>(finder);
        if (p.didExceedMaxLines) failures.add('$label ellipsized');
        final expected = label == l10n.communityScreenTitle
            ? theme.appBarTheme.foregroundColor
            : label == l10n.communityTabNew
            ? theme.colorScheme.primary
            : theme.tabBarTheme.unselectedLabelColor ??
                  theme.colorScheme.onSurfaceVariant;
        expect(
          p.text.style?.color,
          expected,
          reason: '$label configured color role',
        );
      }
      for (final tooltip in [
        l10n.communityFollowNotificationsTooltip,
        l10n.communitySortLabel,
        l10n.communityTileSize,
        l10n.communityContentFilterTitle,
        l10n.layerPanelHelpTooltip,
      ]) {
        final finder = find.byTooltip(tooltip);
        expect(finder, findsOneWidget);
        final rect = tester.getRect(finder);
        if (rect.width < 48 ||
            rect.height < 48 ||
            rect.left < 0 ||
            rect.right > 390) {
          failures.add('$tooltip target $rect');
        }
      }
      final titleRect = tester.getRect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(l10n.communityScreenTitle),
        ),
      );
      final searchRow = tester.getRect(
        find.byKey(const Key('communitySearchRow')),
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('communitySearchRow')),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
        reason: 'search and filters must scroll with the works',
      );
      final tabs = tester.getRect(find.byType(TabBar));
      final notification = tester.getRect(
        find.byTooltip(l10n.communityFollowNotificationsTooltip),
      );
      final sortButton = tester.getRect(
        find.byKey(const Key('communitySortButton')),
      );
      final contentFilter = tester.getRect(
        find.byKey(const Key('communityContentFilterButton')),
      );
      if (titleRect.bottom > tabs.top ||
          notification.bottom > tabs.top ||
          sortButton.top < searchRow.top ||
          sortButton.bottom > searchRow.bottom ||
          contentFilter.top < searchRow.top ||
          contentFilter.bottom > searchRow.bottom ||
          tabs.bottom > searchRow.top + .01) {
        failures.add(
          'Header keeps title/actions and tabs fixed, with page-level '
          'search controls immediately below.',
        );
      }
      expect(failures, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'floating preview controls contrast with the actual control bar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themes = ThemeService();
      await themes.init();
      final community = CommunityService();
      final preview = CommunityPreviewService();
      preview.show(community.discoverableWorks.first);
      addTearDown(themes.dispose);
      addTearDown(community.dispose);
      addTearDown(preview.dispose);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final failures = <String>[];
      for (final preset in [
        ...themes.presets,
        AppThemePreset.defaultLight.copyWith(
          accentColor: Colors.white,
          selectionColor: Colors.black,
        ),
      ]) {
        themes.previewCurrent(preset);
        await tester.pumpWidget(
          host(
            themes,
            community,
            preview,
            locale: const Locale('en'),
            scale: 1,
          ),
        );
        await tester.pumpAndSettle();
        final root = find.byType(CommunityFloatingPreview);
        final bar = find.descendant(
          of: root,
          matching: find.byKey(const Key('communityPreviewControls')),
        );
        expect(bar, findsOneWidget);
        final container = tester.widget<Container>(bar);
        final bg = opaqueOver(
          container.color!,
          themes.themeData.colorScheme.surface,
        );
        for (final button in tester.widgetList<IconButton>(
          find.descendant(of: bar, matching: find.byType(IconButton)),
        )) {
          final fg = opaqueOver((button.icon as Icon).color!, bg);
          if (contrastRatio(fg, bg) < 3) {
            failures.add('${preset.id} icon ${contrastRatio(fg, bg)}');
          }
        }
        final label = find.descendant(of: bar, matching: find.text('Details'));
        final p = tester.renderObject<RenderParagraph>(label);
        if (contrastRatio(opaqueOver(p.text.style!.color!, bg), bg) < 4.5) {
          failures.add('${preset.id} Details');
        }
      }
      expect(failures, isEmpty);
      final previewSurface = tester.widget<Material>(
        find.byKey(const Key('communityPreviewSurface')),
      );
      expect(
        previewSurface.elevation,
        0,
        reason: 'No thick black shadow/outline around the popup',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
