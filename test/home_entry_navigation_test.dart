import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = GlobalKey();
  final captureRoot = Platform.environment['NIARIM_AUDIT_CAPTURE'];
  final manifest = <Map<String, Object?>>[];

  Future<AppLocalizations> open(
    WidgetTester tester, {
    bool first = false,
    String language = 'ja',
    bool pc = false,
    Size size = const Size(390, 844),
    double scale = 1,
    AppThemePreset? theme,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      'first_launch': first,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      // These UI tests exercise an EXISTING user's custom theme, not the
      // first-run migration which restores the original built-in palettes.
      // Without this marker, ThemeService.init replaces an id=default_light
      // custom theme before the UI under test is even built.
      'theme_original_builtin_palette_restored_v1': true,
      if (theme != null) 'theme_current_json': jsonEncode(theme.toJson()),
    });
    final directory = Directory.systemTemp.createTempSync('home-entry-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
  }

  tearDown(() {
    final tester = TestWidgetsFlutterBinding.instance;
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> switchTab(WidgetTester tester, int index) async {
    final tab = find.byKey(ValueKey('home_tab_$index'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull, reason: name);
    if (captureRoot == null) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(captureRoot)..createSync(recursive: true);
      File(
        '${directory.path}/$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    manifest.add({
      'image': '$name.png',
      'automated_layout': 'pass',
      'direct_visual': false,
    });
  }

  testWidgets(
    'guidance requires Start and acknowledged home revisits skip it',
    (tester) async {
      final l10n = await open(tester, first: true);
      await tester.tapAt(const Offset(3, 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFirstLaunchStart), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isTrue,
      );
      await tester.tap(find.text(l10n.homeFirstLaunchStart));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isFalse,
      );
      appRouter.go('/');
      await tester.pumpAndSettle();
      appRouter.go('/home');
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFirstLaunchStart), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('home drawer uses the configured menu surface and foreground', (
    tester,
  ) async {
    final preset = AppThemePreset.defaultLight.copyWith(
      textColor: const Color(0xFF16593A),
      menuTextColor: const Color(0xFF17325A),
      menuBgColor: const Color(0xFFFFE5B7),
    );
    final l10n = await open(
      tester,
      language: 'en',
      pc: true,
      size: const Size(1440, 900),
      theme: preset,
    );
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    expect(tester.widget<Drawer>(drawer).backgroundColor, preset.menuBgColor);
    final label = find.descendant(
      of: drawer,
      matching: find.text(l10n.homeDrawerSettings),
    );
    expect(
      tester.renderObject<RenderParagraph>(label).text.style!.color,
      preset.menuTextColor,
    );
    final icon = find.descendant(
      of: drawer,
      matching: find.byIcon(Icons.settings_outlined),
    );
    expect(tester.widget<Icon>(icon).color, preset.accentColor);
    // Menu labels retain the independently configured menu text color.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('drawer icons and selected tab follow live red/blue/purple accents', (
    tester,
  ) async {
    final l10n = await open(
      tester,
      language: 'ja',
      size: const Size(390, 844),
    );
    final service = tester.element(find.byType(HomeScreen))
        .read<ThemeService>();
    final presets = [
      const Color(0xFFFF5C7A),
      const Color(0xFF2C99F0),
      const Color(0xFFDD00EE),
    ];
    for (final accent in presets) {
      service.previewCurrent(
        AppThemePreset.defaultLight.copyWith(accentColor: accent),
      );
      await tester.pumpAndSettle();

      // The selected tab's glyph and its underline must use this very
      // accent, not a cached copy of the default pink.
      final tab = find.byKey(const ValueKey('home_tab_0'));
      final tabTitle = find.descendant(
        of: tab,
        matching: find.text(l10n.homeTabProjects),
      );
      expect(tester.widget<Text>(tabTitle).style?.color, accent);
      final border = tester.widget<Container>(
        find.descendant(
          of: tab,
          matching: find.byType(Container),
        ).first,
      ).decoration as BoxDecoration;
      expect(border.border!.bottom.color, accent);

      final opener = find.byIcon(Icons.menu);
      await tester.tap(opener);
      await tester.pumpAndSettle();
      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);
      final expectedIcons = [
        Icons.share_outlined,
        Icons.delete_outline,
        Icons.palette_outlined,
        Icons.cleaning_services_outlined,
        Icons.settings_outlined,
        Icons.help_outline,
        Icons.lightbulb_outline,
        Icons.workspace_premium_outlined,
      ];
      for (final glyph in expectedIcons) {
        final found = find.descendant(of: drawer, matching: find.byIcon(glyph));
        expect(found, findsOneWidget, reason: '$glyph for $accent');
        expect(tester.widget<Icon>(found).color, accent);
      }
      final menuTitle = find.descendant(
        of: drawer,
        matching: find.text(l10n.homeDrawerSettings),
      );
      expect(
        tester.renderObject<RenderParagraph>(menuTitle).text.style?.color,
        service.current.menuTextColor,
      );
      Scaffold.of(tester.element(drawer)).closeEndDrawer();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selected favorite filter has white label on the current accent', (
    tester,
  ) async {
    final l10n = await open(tester);
    final finder = find.widgetWithText(FilterChip, l10n.homeFavoritesOnly);
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    final chip = tester.widget<FilterChip>(finder);
    final scheme = Theme.of(tester.element(finder)).colorScheme;
    expect(chip.selected, isTrue);
    expect(chip.selectedColor, scheme.primary);
    expect((chip.label as Text).style?.color, Colors.white);
    expect(chip.checkmarkColor, Colors.white);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect((tester.widget<FilterChip>(finder).label as Text).style?.color,
        isNull, reason: 'Unselected chip follows ordinary theme text');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home selected tab outline uses its actual menu background', (
    tester,
  ) async {
    const menu = Color(0xFFFFE5B7), ink = Color(0xFF17325A);
    final preset = AppThemePreset.defaultLight.copyWith(
      panelBgColor: const Color(0xFF16593A),
      textColor: const Color(0xFFF0F0FF),
      accentColor: menu,
      menuBgColor: menu,
      menuTextColor: ink,
    );
    final l10n = await open(
      tester,
      language: 'en',
      pc: true,
      size: const Size(1440, 900),
      theme: preset,
    );
    final label = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(l10n.homeTabProjects),
    );
    final style = tester.renderObject<RenderParagraph>(label).text.style!;
    expect(style.color, menu);
    expect(style.shadows, hasLength(8));
    expect(style.shadows!.every((s) => s.color == ink), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home back arrow, right drawer and scroll-to-top obey layout', (
    tester,
  ) async {
    final l10n = await open(tester);
    final backFinder = find.byKey(const Key('homeBackToSplashButton'));
    final scrollFinder = find.byKey(const Key('homeScrollToTopFab'));
    expect(backFinder, findsOneWidget);
    expect(scrollFinder, findsOneWidget);
    expect(find.text(l10n.homeFavoritesOnly), findsOneWidget);
    final fabs = find.byType(FloatingActionButton);
    expect(fabs, findsNWidgets(2));
    final scrollFab = tester.widget<FloatingActionButton>(scrollFinder);
    expect(scrollFab.elevation, 0);
    expect(scrollFab.shape, isA<CircleBorder>());
    expect((scrollFab.shape! as CircleBorder).side, BorderSide.none);
    final add = tester.widget<FloatingActionButton>(fabs.last);
    expect(add.elevation, 0);
    expect(add.shape, isA<CircleBorder>());
    expect((add.shape! as CircleBorder).side, BorderSide.none);
    final leftCenter = tester.getCenter(scrollFinder);
    final rightCenter = tester.getCenter(fabs.last);
    expect(leftCenter.dx, lessThan(rightCenter.dx));
    expect((leftCenter.dy - rightCenter.dy).abs(), lessThan(2));
    expect(leftCenter.dx, lessThan(80));
    expect(rightCenter.dx, greaterThan(310));
    // The splash arrow is top-left; the menu is top-right of search.
    final drawerIcon = find.descendant(
      of: find.byType(AppBar).first,
      matching: find.byIcon(Icons.menu),
    );
    expect(drawerIcon, findsOneWidget);
    expect(tester.getCenter(backFinder).dx, lessThan(60));
    expect(tester.getCenter(drawerIcon).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.search).first).dx));
    expect(tester.getCenter(drawerIcon).dy, lessThan(leftCenter.dy));

    await switchTab(tester, 2);
    expect(backFinder, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('every drawer destination returns to the same bookmarked tab', (
    tester,
  ) async {
    final l10n = await open(tester);
    await switchTab(tester, 2);
    for (final label in [
      l10n.homeTabShared,
      l10n.homeTabTrash,
      l10n.homeDrawerAutofillPreset,
      l10n.homeDrawerStorage,
      l10n.homeDrawerSettings,
      l10n.homeDrawerHelp,
      l10n.homeDrawerTips,
      l10n.homeDrawerPremium,
    ]) {
      tester
          .state<ScaffoldState>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(Scaffold),
                )
                .first,
          )
          .openEndDrawer();
      await tester.pumpAndSettle();
      final item = find.descendant(
        of: find.byType(Drawer),
        matching: find.text(label),
      );
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pump(const Duration(milliseconds: 500));
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      expect(tester.takeException(), isNull, reason: label);
      expect(appRouter.canPop(), isTrue, reason: label);
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('home_tab_2')))
            .properties
            .selected,
        isTrue,
      );
    }
    await tester.tap(
      find.widgetWithText(OutlinedButton, l10n.communityScreenTitle),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommunityScreen), findsOneWidget);
    expect(appRouter.canPop(), isTrue);
    appRouter.pop();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeBookmarkedEmptyTitle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'home tabs and bookmark entry follow the configured accent without correction',
    (tester) async {
      for (final theme in [
        AppThemePreset.defaultLight,
        AppThemePreset.defaultLight.copyWith(
          accentColor: Colors.white,
          selectionColor: Colors.black,
        ),
      ]) {
        final l10n = await open(tester, theme: theme);
        final scheme = Theme.of(
          tester.element(find.byType(HomeScreen)),
        ).colorScheme;
        for (final index in [0, 1, 2]) {
          await switchTab(tester, index);
          final labels = tester.widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey('home_tab_$index')),
              matching: find.byType(Text),
            ),
          );
          expect(
            labels.single.style!.color,
            scheme.primary,
            reason: 'selected tab $index on ${theme.id}',
          );
        }
        final action = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, l10n.communityScreenTitle),
        );
        final foreground =
            action.style?.foregroundColor?.resolve({}) ??
            Theme.of(
              tester.element(find.byType(HomeScreen)),
            ).colorScheme.primary;
        expect(foreground, scheme.primary, reason: 'bookmark gallery action');
        final icon = tester.widget<Icon>(find.byIcon(Icons.bookmark_border));
        expect(icon.color, scheme.primary, reason: 'bookmark empty-state icon');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('home main states fit all widths, modes, languages and mutations', (
    tester,
  ) async {
    await loadAppFonts(tester);
    const widths = [
      320,
      360,
      375,
      390,
      430,
      480,
      520,
      559,
      560,
      600,
      640,
      641,
      700,
      759,
      760,
      834,
      900,
      1024,
      1180,
      1280,
      1366,
      1440,
      1600,
      1920,
    ];
    const languages = ['ja', 'en', 'zh', 'zh_Hant', 'ko', 'fr', 'es'];
    for (final language in languages) {
      final profiles =
          <
            ({
              bool pc,
              Size size,
              double scale,
              AppThemePreset? theme,
              String suffix,
            })
          >[
            for (final pc in [false, true])
              for (final width in widths)
                (
                  pc: pc,
                  size: Size(width.toDouble(), pc ? 900 : 844),
                  scale: 1,
                  theme: null,
                  suffix: '',
                ),
            (
              pc: false,
              size: const Size(320, 844),
              scale: 2,
              theme: AppThemePreset.defaultDark,
              suffix: '-dark-scale2',
            ),
            (
              pc: false,
              size: const Size(390, 844),
              scale: 1.3,
              theme: AppThemePreset.defaultLight.copyWith(
                accentColor: Colors.white,
                selectionColor: Colors.black,
              ),
              suffix: '-custom-scale1.3',
            ),
            (
              pc: true,
              size: const Size(1440, 900),
              scale: 2,
              theme: AppThemePreset.defaultLight.copyWith(
                accentColor: Colors.white,
                selectionColor: Colors.black,
              ),
              suffix: '-custom-scale2',
            ),
            (
              pc: true,
              size: const Size(760, 900),
              scale: 1.3,
              theme: AppThemePreset.defaultDark,
              suffix: '-dark-scale1.3',
            ),
            (
              pc: false,
              size: const Size(559, 844),
              scale: 2,
              theme: null,
              suffix: '-light-scale2',
            ),
            (
              pc: true,
              size: const Size(641, 360),
              scale: 1,
              theme: null,
              suffix: '-short',
            ),
            (
              pc: false,
              size: const Size(640, 360),
              scale: 2,
              theme: null,
              suffix: '-short-scale2',
            ),
          ];
      for (final profile in profiles) {
        final suffix =
            '$language-${profile.pc ? 'pc' : 'sp'}-${profile.size.width.toInt()}${profile.suffix}';
        final l10n = await open(
          tester,
          first: true,
          language: language,
          pc: profile.pc,
          size: profile.size,
          scale: profile.scale,
          theme: profile.theme,
        );
        await capture(tester, 'first-guidance-$suffix');
        final label = tester.renderObject<RenderParagraph>(
          find.text(l10n.homeFirstLaunchStart),
        );
        expect(
          label.size.width + .01,
          greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity)),
          reason: suffix,
        );
        await tester.tap(find.text(l10n.homeFirstLaunchStart));
        await tester.pumpAndSettle();
        await capture(tester, 'projects-empty-$suffix');
        await switchTab(tester, 1);
        await capture(tester, 'works-empty-$suffix');
        await switchTab(tester, 2);
        await capture(tester, 'bookmarks-empty-$suffix');
        await switchTab(tester, 0);
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await capture(tester, 'search-empty-$suffix');
        tester
            .state<ScaffoldState>(
              find
                  .descendant(
                    of: find.byType(HomeScreen),
                    matching: find.byType(Scaffold),
                  )
                  .first,
            )
            .openEndDrawer();
        await tester.pumpAndSettle();
        await capture(tester, 'drawer-$suffix');
        Scaffold.of(tester.element(find.byType(Drawer))).closeEndDrawer();
        await tester.pumpAndSettle();
      }
    }
    if (captureRoot != null) {
      File(
        '$captureRoot/manifest.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 20)));
}
