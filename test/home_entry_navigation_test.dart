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
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/screens/home/home_screen.dart';
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

  testWidgets(
    'home tabs and bookmark entry remain readable with light accents',
    (tester) async {
      for (final theme in [
        AppThemePreset.defaultLight,
        AppThemePreset.defaultLight.copyWith(
          accentColor: Colors.white,
          selectionColor: Colors.black,
        ),
      ]) {
        final l10n = await open(tester, theme: theme);
        final background = opaqueOver(
          Theme.of(
            tester.element(find.byType(HomeScreen)),
          ).scaffoldBackgroundColor,
          Colors.black,
        );
        for (final index in [0, 1, 2]) {
          await switchTab(tester, index);
          final labels = tester.widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey('home_tab_$index')),
              matching: find.byType(Text),
            ),
          );
          expect(
            contrastRatio(background, labels.single.style!.color!),
            greaterThanOrEqualTo(4.5),
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
        expect(
          contrastRatio(background, foreground),
          greaterThanOrEqualTo(4.5),
          reason: 'bookmark gallery action',
        );
        final icon = tester.widget<Icon>(find.byIcon(Icons.bookmark_border));
        expect(
          contrastRatio(background, opaqueOver(icon.color!, background)),
          greaterThanOrEqualTo(3),
          reason: 'bookmark empty-state icon',
        );
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
