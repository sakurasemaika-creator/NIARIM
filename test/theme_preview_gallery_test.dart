import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';

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

  testWidgets('theme settings shows live scaled preview and opens gallery', (tester) async {
    // Capture the actual Flutter rendering at a representative phone size.
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
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
