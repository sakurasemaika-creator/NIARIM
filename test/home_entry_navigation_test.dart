import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/config/accent_text_theme.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
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
    'guidance closes only from its buttons and acknowledged home revisits skip it',
    (tester) async {
      await open(tester, first: true);
      await tester.tapAt(const Offset(3, 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppTutorial), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isTrue,
      );
      // 最後のページまでめくって「はじめる」。
      while (find.byKey(const Key('tutorialStart')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('tutorialNext')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('tutorialStart')));
      await tester.pumpAndSettle();
      expect(find.byType(AppTutorial), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('first_launch'),
        isFalse,
      );
      appRouter.go('/');
      await tester.pumpAndSettle();
      appRouter.go('/home');
      await tester.pumpAndSettle();
      expect(find.byType(AppTutorial), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('home bottom FABs and drawer icon obey navigation layout', (
    tester,
  ) async {
    final l10n = await open(tester);
    final backFinder = find.byKey(const Key('homeBackToSplashFab'));
    expect(backFinder, findsOneWidget);
    expect(find.text(l10n.homeFavoritesOnly), findsOneWidget);
    final fabs = find.byType(FloatingActionButton);
    expect(fabs, findsNWidgets(2));
    final back = tester.widget<FloatingActionButton>(backFinder);
    expect(back.elevation, 0);
    expect(back.shape, isA<CircleBorder>());
    expect((back.shape! as CircleBorder).side, BorderSide.none);
    final add = tester.widget<FloatingActionButton>(fabs.last);
    expect(add.elevation, 0);
    expect(add.shape, isA<CircleBorder>());
    expect((add.shape! as CircleBorder).side, BorderSide.none);
    final leftCenter = tester.getCenter(backFinder);
    final rightCenter = tester.getCenter(fabs.last);
    expect(leftCenter.dx, lessThan(rightCenter.dx));
    expect((leftCenter.dy - rightCenter.dy).abs(), lessThan(2));
    expect(leftCenter.dx, lessThan(80));
    expect(rightCenter.dx, greaterThan(310));
    // The hamburger stays at the top left, the splash arrow is lower left.
    final drawerIcon = find.descendant(
      of: find.byType(AppBar).first,
      matching: find.byIcon(Icons.menu),
    );
    expect(drawerIcon, findsOneWidget);
    expect(tester.getCenter(drawerIcon).dy, lessThan(leftCenter.dy));

    await switchTab(tester, 2);
    expect(backFinder, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
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
          .openDrawer();
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

  testWidgets('home tabs and bookmark entry use the theme accent text colour', (
    tester,
  ) async {
    for (final theme in [
      AppThemePreset.defaultLight,
      AppThemePreset.defaultLight.copyWith(
        accentColor: Colors.white,
        selectionColor: Colors.black,
      ),
      // 明るい差し色でも、アクセントの文字・アイコン色を選べば読める。
      AppThemePreset.defaultLight.copyWith(
        accentColor: Colors.white,
        selectionColor: Colors.black,
        accentTextColor: const Color(0xFF8A1538),
      ),
    ]) {
      final l10n = await open(tester, theme: theme);
      final accent = AccentTextTheme.of(
        tester.element(find.byType(HomeScreen)),
      );
      expect(accent, theme.effectiveAccentTextColor, reason: theme.id);
      // 選ばれたタブの名前・作品広場へのボタンは、テーマの「アクセントの
      // 文字・アイコン色」（未指定なら差し色。ユーザー指定で、読みやすさの
      // ために黒や白へ自動で差し替えない。読めない組み合わせは起動画面の
      // リセットで戻せる）。
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
          accent,
          reason: 'selected tab $index on ${theme.id}',
        );
      }
      final action = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, l10n.communityScreenTitle),
      );
      final foreground = action.style?.foregroundColor?.resolve({}) ?? accent;
      expect(foreground, accent, reason: 'bookmark gallery action');
      // 空のときのアイコンは作品一覧の空の表示と同じ色・同じ下地の円
      // （ユーザー指定。読みやすさのために黒や白へ自動で差し替えない）。
      final icon = tester.widget<Icon>(find.byIcon(Icons.bookmark_border));
      final circle = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.bookmark_border),
              matching: find.byType(Container),
            )
            .first,
      );
      await switchTab(tester, 1);
      final worksIcon = tester.widget<Icon>(
        find.byIcon(Icons.video_library_outlined),
      );
      final worksCircle = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.video_library_outlined),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(icon.color, worksIcon.color, reason: 'bookmark icon colour');
      expect(icon.size, worksIcon.size, reason: 'bookmark icon size');
      expect(
        (circle.decoration! as BoxDecoration).color,
        (worksCircle.decoration! as BoxDecoration).color,
        reason: 'bookmark icon circle',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
        for (final text in [l10n.tutorialSkip, l10n.tutorialNext]) {
          final label = tester.renderObject<RenderParagraph>(find.text(text));
          expect(
            label.size.width + .01,
            greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity)),
            reason: '$suffix $text',
          );
        }
        await tester.tap(find.byKey(const Key('tutorialSkip')));
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
            .openDrawer();
        await tester.pumpAndSettle();
        await capture(tester, 'drawer-$suffix');
        Scaffold.of(tester.element(find.byType(Drawer))).closeDrawer();
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
