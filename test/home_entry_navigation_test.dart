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
import 'package:niarim/widgets/app_tutorial.dart';
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
    // Exported-file scanning is genuinely asynchronous and can keep a
    // progress indicator alive; bounded pumps avoid waiting for infinity.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
  }

  Future<void> settleWithAsyncExport(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 350));
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
    'first-use guidance waits for acknowledgement and home revisits skip it',
    (tester) async {
      final l10n = await open(tester, first: true);
      await tester.tapAt(const Offset(3, 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFirstLaunchMessage), findsOneWidget);
      expect(find.byType(AppTutorial), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isTrue,
      );
      await tester.tap(find.text(l10n.homeFirstLaunchStart));
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFirstLaunchMessage), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isFalse,
      );
      appRouter.go('/');
      await tester.pumpAndSettle();
      appRouter.go('/home');
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFirstLaunchMessage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Help tutorial can finish, skip and reopen without resetting first use',
    (tester) async {
      final l10n = await open(tester);
      appRouter.push('/help');
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('helpTutorialButton'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final titles = [
        l10n.tutorialPage1Title,
        l10n.tutorialPage2Title,
        l10n.tutorialPage3Title,
        l10n.tutorialPage4Title,
        l10n.tutorialPage5Title,
        l10n.tutorialPage6Title,
      ];
      for (var page = 0; page < titles.length; page++) {
        expect(find.text(titles[page]).hitTestable(), findsOneWidget);
        await tester.tap(
          find.byKey(
            Key(page == titles.length - 1 ? 'tutorialStart' : 'tutorialNext'),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(AppTutorial), findsNothing);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text(titles.first).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorialSkip')));
      await tester.pumpAndSettle();
      expect(find.byType(AppTutorial), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isFalse,
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFirstLaunchMessage), findsNothing);
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

  testWidgets(
    'drawer icons and selected tab follow live red/blue/purple accents',
    (tester) async {
      final l10n = await open(
        tester,
        language: 'ja',
        size: const Size(390, 844),
      );
      final service = tester
          .element(find.byType(HomeScreen))
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

        // At phone width navigation intentionally shows icons, not labels.
        // Verify the actual TabBar accent and selected tab semantics.
        final tab = find.byKey(const ValueKey('home_tab_0'));
        expect(tab, findsOneWidget);
        expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
        expect(
          find.descendant(
            of: tab,
            matching: find.byIcon(Icons.movie_creation_outlined),
          ),
          findsOneWidget,
        );
        final bar = tester.widget<TabBar>(find.byType(TabBar).first);
        expect(bar.indicatorColor, accent);
        expect(bar.labelColor, accent);

        final opener = find.byIcon(Icons.menu);
        await tester.tap(opener);
        await tester.pumpAndSettle();
        final drawer = find.byType(Drawer);
        expect(drawer, findsOneWidget);
        final expectedIcons = [
          Icons.toll_outlined,
          Icons.workspace_premium_outlined,
          Icons.menu_book_outlined,
          Icons.settings_outlined,
          Icons.cleaning_services_outlined,
        ];        for (final glyph in expectedIcons) {
          final found = find.descendant(
            of: drawer,
            matching: find.byIcon(glyph),
          );
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
    },
  );

  testWidgets(
    'selected favorite filter uses the configured accent foreground',
    (tester) async {
      const foreground = Color(0xFF164A30);
      final l10n = await open(
        tester,
        theme: AppThemePreset.defaultLight.copyWith(
          accentColor: const Color(0xFFF1D780),
          buttonTextColor: foreground,
        ),
      );
      final finder = find.widgetWithText(FilterChip, l10n.homeFavoritesOnly);
      expect(finder, findsOneWidget);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      final chip = tester.widget<FilterChip>(finder);
      final scheme = Theme.of(tester.element(finder)).colorScheme;
      expect(chip.selected, isTrue);
      expect(chip.selectedColor, scheme.primary);
      expect(scheme.onPrimary, foreground);
      expect((chip.label as Text).style?.color, scheme.onPrimary);
      expect(chip.checkmarkColor, scheme.onPrimary);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(
        (tester.widget<FilterChip>(finder).label as Text).style?.color,
        isNull,
        reason: 'Unselected chip follows ordinary theme text',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      of: find.byKey(const ValueKey('home_tab_0')),
      matching: find.text(l10n.homeTabProjects),
    );
    expect(label, findsOneWidget);
    // Navigation now uses Flutter's TabBar indicator, not a text-shadow
    // outline. Its selected label and underline follow the current accent.
    final tabBar = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(tabBar.labelColor, menu);
    expect(tabBar.indicatorColor, menu);
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('home_tab_0')))
          .properties
          .selected,
      isTrue,
    );
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
    final fabTheme = Theme.of(
      tester.element(scrollFinder),
    ).floatingActionButtonTheme;
    final scrollShape = scrollFab.shape ?? fabTheme.shape;
    expect(scrollFab.elevation ?? fabTheme.elevation, 0);
    expect(scrollShape, isA<CircleBorder>());
    expect((scrollShape! as CircleBorder).side, BorderSide.none);
    final add = tester.widget<FloatingActionButton>(fabs.last);
    final addShape = add.shape ?? fabTheme.shape;
    expect(add.elevation ?? fabTheme.elevation, 0);
    expect(addShape, isA<CircleBorder>());
    expect((addShape! as CircleBorder).side, BorderSide.none);
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
    expect(
      tester.getCenter(drawerIcon).dx,
      greaterThan(tester.getCenter(find.byIcon(Icons.search).first).dx),
    );
    expect(tester.getCenter(drawerIcon).dy, lessThan(leftCenter.dy));

    await switchTab(tester, 1);
    expect(backFinder, findsOneWidget);
    expect(find.byKey(const Key('homeScrollToTopFab')), findsNothing);
    expect(
      find.byType(FloatingActionButton),
      findsOneWidget,
      reason: 'The exported works tab still has its new-folder button',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'every drawer destination returns to the same exported works tab',
    (tester) async {
      final l10n = await open(tester);
      await switchTab(tester, 1);
      for (final (target, path) in [
        (find.text(l10n.homeDrawerStorage), '/storage'),
        (find.text(l10n.homeDrawerSettings), '/settings'),
        (find.byKey(const Key('homeGuideMenuItem')), '/help'),
        (find.byKey(const Key('homeCoinBenefitsMenuItem')), '/rewards'),
        (
          find.byKey(const Key('homeMembershipBenefitsMenuItem')),
          '/membership',
        ),
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
        await settleWithAsyncExport(tester);
        final item = find.descendant(of: find.byType(Drawer), matching: target);
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
        expect(tester.takeException(), isNull, reason: path);
        expect(
          appRouter.routerDelegate.currentConfiguration.last.matchedLocation,
          path,
        );
        expect(appRouter.canPop(), isTrue, reason: path);
        appRouter.pop();
        await settleWithAsyncExport(tester);
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('home_tab_1')))
              .properties
              .selected,
          isTrue,
        );
      }
      // Community remains a separate route; the home library stays on Works.
      appRouter.push('/community');
      await settleWithAsyncExport(tester);
      expect(find.byType(CommunityScreen), findsOneWidget);
      expect(appRouter.canPop(), isTrue);
      appRouter.pop();
      await settleWithAsyncExport(tester);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('home_tab_1')))
            .properties
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'the four home tabs follow the configured accent without correction',
    (tester) async {
      for (final theme in [
        AppThemePreset.defaultLight,
        AppThemePreset.defaultLight.copyWith(
          accentColor: Colors.white,
          selectionColor: Colors.black,
        ),
      ]) {
        await open(tester, theme: theme);
        final scheme = Theme.of(
          tester.element(find.byType(HomeScreen)),
        ).colorScheme;
        for (final index in [0, 1, 2, 3]) {
          await switchTab(tester, index);
          final tab = find.byKey(ValueKey('home_tab_$index'));
          expect(tab, findsOneWidget);
          expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
          final bar = tester.widget<TabBar>(find.byType(TabBar).first);
          expect(
            bar.indicatorColor,
            scheme.primary,
            reason: 'selected tab $index on ${theme.id}',
          );
          expect(bar.labelColor, scheme.primary);
        }
        expect(find.byKey(const ValueKey('home_tab_2')), findsOneWidget);
        expect(find.byKey(const ValueKey('home_tab_3')), findsOneWidget);
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
        for (final text in [
          l10n.homeFirstLaunchMessage,
          l10n.homeFirstLaunchStart,
        ]) {
          final label = tester.renderObject<RenderParagraph>(find.text(text));
          expect(label.didExceedMaxLines, isFalse, reason: '$suffix $text');
          expect(find.text(text).hitTestable(), findsOneWidget, reason: suffix);
          final bounds = tester.getRect(find.text(text));
          expect(bounds.left, greaterThanOrEqualTo(0), reason: suffix);
          expect(
            bounds.right,
            lessThanOrEqualTo(profile.size.width),
            reason: suffix,
          );
          expect(bounds.top, greaterThanOrEqualTo(0), reason: suffix);
          expect(
            bounds.bottom,
            lessThanOrEqualTo(profile.size.height),
            reason: suffix,
          );
        }
        await tester.tap(find.text(l10n.homeFirstLaunchStart));
        await tester.pumpAndSettle();
        await capture(tester, 'projects-empty-$suffix');
        await switchTab(tester, 1);
        await capture(tester, 'works-empty-$suffix');
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
