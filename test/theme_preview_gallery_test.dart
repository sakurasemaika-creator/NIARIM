import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void mockPathProvider() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final dir = Directory.systemTemp.createTempSync('niarim_preview_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }

  test('gallery contains each independent screen once, no folder/tab variants', () {
    final ids = themePreviewEntries.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll([
      'splash', 'projects', 'shared', 'trash', 'canvas', 'timeline', 'export',
      'complete', 'community', 'settings', 'theme', 'widget_frame',
    ]));
    expect(ids, isNot(contains('folder')));
    expect(ids, isNot(contains('works_tab')));
    expect(ids, isNot(contains('bookmarks_tab')));
    expect(ids, isNot(contains('popup')));
  });

  testWidgets('swipe gallery renders adjacent pages, then closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeService = ThemeService();
    await themeService.init();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeService.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, '起動画面');
    expect(find.text('作品広場'), findsOneWidget);
    expect(find.byIcon(Icons.movie_filter_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewNext')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, 'プロジェクト一覧');
    expect(find.text('作品広場'), findsNothing);
    await tester.drag(find.byKey(const Key('themePreviewPager')), const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, themePreviewEntries[2].ja);
    await tester.tap(find.byKey(const Key('themePreviewHideControls')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewNext')), findsNothing);
    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewShowControls')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewNext')), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
  });

  testWidgets('gallery reflects actual button, text and custom surface colors',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    final preset = AppThemePreset.defaultLight.copyWith(
      textColor: const Color(0xFF112233),
      buttonTextColor: const Color(0xFF00CC11),
      menuTextColor: const Color(0xFFCC11BB),
      selectionTextColor: const Color(0xFF2255CC),
      panelBgColor: const Color(0xFFEEBBCC),
      menuBgColor: const Color(0xFFBBFFDD),
      updateMarkColor: const Color(0xFF667788),
    );
    service.previewCurrent(preset);
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: service,
      child: Builder(builder: (context) => MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: context.watch<ThemeService>().themeData,
        home: const ThemePreviewGalleryScreen(),
      )),
    ));
    await tester.pumpAndSettle();

    // Splash tiles and the app-logo foreground follow the explicit
    // button text color, not the unrelated menu-background swatch.
    final logo = tester.widget<SvgPicture>(
      find.byKey(const Key('themePreviewSplashAppLogo')),
    );
    expect(logo.colorFilter,
      const ColorFilter.mode(Color(0xFF00CC11), BlendMode.srcIn));

    // The theme sample must show raw user-set colors, not seed-scheme
    // approximations (especially for the panel, menu and update mark).
    final pager = tester.widget<PageView>(
      find.byKey(const Key('themePreviewPager')));
    final themeIndex = themePreviewEntries.indexWhere((e) => e.id == 'theme');
    expect(themeIndex, greaterThan(0));
    pager.controller!.jumpToPage(themeIndex);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(
      find.byKey(const Key('themePreviewTitle'))).data, 'テーマ・外観');

    Future<void> checkSwatch(String label, Color expected) async {
      // End users cannot scroll the preview content. For this color-token
      // assertion only, jump the internal scroll position programmatically;
      // the rendered screen remains top-aligned and noninteractive.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).last);
      for (var attempt = 0;
           attempt < 30 && find.text(label).evaluate().isEmpty;
           attempt++) {
        final position = scrollable.position;
        final next = (position.pixels + 100)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if (next == position.pixels) break;
        position.jumpTo(next);
        await tester.pumpAndSettle();
      }
      expect(find.text(label), findsOneWidget);
      final containingCard = find.ancestor(
        of: find.text(label), matching: find.byType(Card)).first;
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(of: containingCard,
          matching: find.byType(CircleAvatar)));
      expect(avatar.backgroundColor, expected, reason: label);
    }
    await checkSwatch('本文文字色', const Color(0xFF112233));
    await checkSwatch('ボタン内の文字色', const Color(0xFF00CC11));
    await checkSwatch('メニューの文字色', const Color(0xFFCC11BB));
    await checkSwatch('選択中の文字色', const Color(0xFF2255CC));
    await checkSwatch('パネル背景', const Color(0xFFEEBBCC));
    await checkSwatch('メニュー背景', const Color(0xFFBBFFDD));
    await checkSwatch('更新マーク', const Color(0xFF667788));
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme settings shows live scaled preview and opens gallery', (tester) async {
    // Capture the actual Flutter rendering at a representative phone size.
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    await loadAppFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    final screenshot = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: screenshot,
      child: MultiProvider(
        providers: providers!,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: const Locale('ja'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: context.watch<ThemeService>().themeData,
            debugShowCheckedModeBanner: false,
            home: const ThemeSettingsScreen(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewOpen')), findsOneWidget);
    expect(find.byKey(const Key('themeInlinePreview')), findsOneWidget);
    // The miniature is real Flutter content, not a fixed picture.
    expect(find.text('練習作品'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Future<void> saveCapture(String name) async {
      final boundary = screenshot.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final output = Directory('build/theme-inline-preview')
        ..createSync(recursive: true);
      await tester.runAsync(() => File(
        '${output.path}/$name',
      ).writeAsBytes(bytes!));
    }

    await saveCapture('theme_settings_default.png');

    final themeService = Provider.of<ThemeService>(
      tester.element(find.byKey(const Key('themeInlinePreview'))),
      listen: false,
    );
    final before = Theme.of(tester.element(
      find.byKey(const Key('themeInlinePreview')))).colorScheme.primary;
    themeService.previewCurrent(themeService.current.copyWith(
      accentColor: const Color(0xFF008B79),
    ));
    await tester.pumpAndSettle();
    final after = Theme.of(tester.element(
      find.byKey(const Key('themeInlinePreview')))).colorScheme.primary;
    expect(after, isNot(before));
    expect(find.byKey(const Key('themeInlinePreview')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await saveCapture('theme_settings_accent_changed.png');

    await tester.tap(find.byKey(const Key('themePreviewOpen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);

    // Capture each full-screen live Flutter gallery page for a human-readable
    // visual PDF. These are real rendered frames reached through the preview
    // button, not illustrations or the embedded miniature preview.
    for (var i = 0; i < themePreviewEntries.length; i++) {
      if (i > 0) {
        await tester.tap(find.byKey(const Key('themePreviewNext')));
        await tester.pumpAndSettle();
      }
      expect(tester.widget<Text>(
        find.byKey(const Key('themePreviewTitle'))).data,
        themePreviewEntries[i].ja);
      await saveCapture(
        'theme_gallery_${(i + 1).toString().padLeft(2, '0')}_${themePreviewEntries[i].id}.png',
      );
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themeInlinePreview')), findsOneWidget);
  });

  testWidgets('gallery works at narrow 320px portrait width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final themeService = ThemeService();
    await themeService.init();
    await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeService.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    // Cover every registered independent screen, not only the first dozen.
    for (var i = 1; i < themePreviewEntries.length; i++) {
      await tester.tap(find.byKey(const Key('themePreviewNext')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(
        find.byKey(const Key('themePreviewTitle'))).data,
        themePreviewEntries[i].ja);
      expect(tester.takeException(), isNull);
    }
  });
}
