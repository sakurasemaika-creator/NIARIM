import 'dart:io';
import 'package:flutter/material.dart';
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
      'splash', 'projects', 'canvas', 'timeline', 'export',
      'complete', 'community', 'settings', 'theme',
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
    expect(find.text('NIARIM'), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewNext')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, 'プロジェクト一覧');
    expect(find.text('NIARIM'), findsNothing);
    await tester.drag(find.byKey(const Key('themePreviewPager')), const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('themePreviewTitle'))).data, '新規プロジェクト');
    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
  });

  testWidgets('theme settings opens the full-screen gallery and returns', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockPathProvider();
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(MultiProvider(
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
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewOpen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewOpen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('themePreviewOpen')), findsOneWidget);
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
    for (var i = 0; i < 13; i++) {
      await tester.tap(find.byKey(const Key('themePreviewNext')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
