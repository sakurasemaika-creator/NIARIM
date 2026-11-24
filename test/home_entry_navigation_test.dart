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
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
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

  void disposeServices(List<ChangeNotifier> services) {
    for (final service in services.reversed) {
      service.dispose();
    }
    services.clear();
  }

  Future<AppLocalizations> open(
    WidgetTester tester, {
    bool first = false,
    String language = 'ja',
    bool pc = false,
    Size size = const Size(390, 844),
    double scale = 1,
    AppThemePreset? theme,
    List<ChangeNotifier>? services,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (services != null) disposeServices(services);
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
    final providers = await tester.runAsync(
      () => buildAppProviders(debugOnCreated: services?.add),
    );
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
      // 初回は図つきの使い方（1ページ目に案内の一文）。外側・Esc・戻る
      // 操作では閉じない。
      expect(find.text(l10n.homeFirstLaunchMessage), findsOneWidget);
      expect(find.byType(AppTutorial), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('tutorialSkip')));
      await tester.pumpAndSettle();
      expect(find.byType(AppTutorial), findsNothing);
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
        ];
        for (final glyph in expectedIcons) {
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
    // 起動画面へ戻る矢印は上のバーの左上で、どのタブでも同じ所に出る
    // （所有者の指定 2026-11-22。11-17の左下の浮かぶボタンを戻した）。
    // 左下は一覧の一番上へ戻る「↑」、右下は＋。
    final backFinder = find.byKey(const Key('homeBackToSplashButton'));
    final scrollFinder = find.byKey(const Key('homeScrollToTopFab'));
    expect(backFinder, findsOneWidget);
    expect(find.byKey(const Key('homeBackToSplashFab')), findsNothing);
    expect(
      find.ancestor(of: backFinder, matching: find.byType(AppBar)),
      findsOneWidget,
    );
    // 空の一覧では「一番上へ」を出さない（送る先が無い）。作品を作って
    // から、左下の「一番上へ」と右下の＋の並びを確かめる。
    expect(scrollFinder, findsNothing);
    final projects = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    // 「一番上へ」は一覧を上へ戻せるときだけ出す（一番上・スクロールできない
    // 一覧では出さない。DISC181）ので、送れるだけ作ってから送る。
    await tester.runAsync(() async {
      for (var i = 0; i < 16; i++) {
        await projects.createProject(
          name: 'Layout $i',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
      }
    });
    await tester.pumpAndSettle();
    expect(scrollFinder, findsNothing);
    expect(find.text(l10n.homeFavoritesOnly), findsOneWidget);
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ProjectListWidget),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(200);
    await tester.pumpAndSettle();
    expect(scrollFinder, findsOneWidget);
    final fabs = find.byType(FloatingActionButton);
    expect(fabs, findsNWidgets(2));
    final fabTheme = Theme.of(
      tester.element(scrollFinder),
    ).floatingActionButtonTheme;
    // 一番上へ・＋は同じ見た目（影なし・縁なしの丸）。
    for (final fab in [scrollFinder, fabs.last]) {
      final widget = tester.widget<FloatingActionButton>(fab);
      final shape = widget.shape ?? fabTheme.shape;
      expect(widget.elevation ?? fabTheme.elevation, 0);
      expect(shape, isA<CircleBorder>());
      expect((shape! as CircleBorder).side, BorderSide.none);
      expect(tester.getSize(fab), tester.getSize(fabs.last));
    }
    final backCenter = tester.getCenter(backFinder);
    final upCenter = tester.getCenter(scrollFinder);
    final addCenter = tester.getCenter(fabs.last);
    expect(backCenter.dx, lessThan(40));
    expect(upCenter.dx, lessThan(80));
    expect((upCenter.dy - addCenter.dy).abs(), lessThan(2));
    expect(addCenter.dx, greaterThan(310));
    // The menu is top-right of search, on the same bar as the back arrow.
    final drawerIcon = find.descendant(
      of: find.byType(AppBar).first,
      matching: find.byIcon(Icons.menu),
    );
    expect(drawerIcon, findsOneWidget);
    expect(
      tester.getCenter(drawerIcon).dx,
      greaterThan(tester.getCenter(find.byIcon(Icons.search).first).dx),
    );
    expect(
      (tester.getCenter(drawerIcon).dy - backCenter.dy).abs(),
      lessThan(2),
    );

    // 作品一覧・共有（受け取った／作った）・ゴミ箱のタブでも同じ所。
    for (final tab in [1, 2, 3]) {
      await switchTab(tester, tab);
      expect(backFinder, findsOneWidget, reason: 'tab $tab');
      expect(find.byKey(const Key('homeScrollToTopFab')), findsNothing);
      final center = tester.getCenter(backFinder);
      expect((center - backCenter).distance, lessThan(1), reason: 'tab $tab');
    }
    await switchTab(tester, 1);
    expect(
      find.byType(FloatingActionButton),
      findsNWidgets(1),
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
  for (final language in const [
    'ja',
    'en',
    'zh',
    'zh_Hant',
    'ko',
    'fr',
    'es',
  ]) {
    testWidgets(
      'home main states fit all widths, modes and mutations ($language)',
      (tester) async {
        await loadAppFonts(tester);
        final services = <ChangeNotifier>[];
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
            services: services,
          );
          await capture(tester, 'first-guidance-$suffix');
          // 初回の案内（図つきの使い方）の1ページ目：案内の一文と、
          // 「スキップ」「次へ」のボタンの名前が切れずに画面の中にある。
          for (final (name, finder) in [
            // 案内の一文は最後の語を折らない文（KeepTogetherText）なので、
            // 中で描く段落（RichText）を見る。
            (
              'lead',
              find.descendant(
                of: find.text(l10n.homeFirstLaunchMessage),
                matching: find.byType(RichText),
              ),
            ),
            (
              'skip',
              find.descendant(
                of: find.byKey(const Key('tutorialSkip')),
                matching: find.byType(RichText),
              ),
            ),
            (
              'next',
              find.descendant(
                of: find.byKey(const Key('tutorialNext')),
                matching: find.byType(RichText),
              ),
            ),
          ]) {
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            final label = tester.renderObject<RenderParagraph>(finder);
            expect(label.didExceedMaxLines, isFalse, reason: '$suffix $name');
            expect(finder.hitTestable(), findsOneWidget, reason: suffix);
            final bounds = tester.getRect(finder);
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
          await tester.tap(find.byKey(const Key('tutorialSkip')));
          await tester.pumpAndSettle();
          await capture(tester, 'projects-empty-$suffix');
          await switchTab(tester, 1);
          await capture(tester, 'works-empty-$suffix');
          await switchTab(tester, 0);
          await tester.tap(find.byIcon(Icons.search));
          await settleWithAsyncExport(tester);
          expect(find.byKey(const Key('homeSearchInput')), findsOneWidget);
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
          await settleWithAsyncExport(tester);
          await capture(tester, 'drawer-$suffix');
          Scaffold.of(tester.element(find.byType(Drawer))).closeEndDrawer();
          await settleWithAsyncExport(tester);
        }
        if (captureRoot != null) {
          File('$captureRoot/manifest.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(manifest),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        disposeServices(services);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}
