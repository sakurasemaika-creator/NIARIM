import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';

void main() {
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
        theme: themeService.themeData,
        home: const ThemePreviewGalleryScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('themePreviewPager')), findsOneWidget);
    expect(find.text('起動画面'), findsOneWidget);
    expect(find.text('NIARIM'), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewNext')));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクト一覧'), findsOneWidget);
    expect(find.text('NIARIM'), findsNothing);
    await tester.drag(find.byKey(const Key('themePreviewPager')), const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(find.text('新規プロジェクト'), findsOneWidget);
    await tester.tap(find.byKey(const Key('themePreviewClose')));
    await tester.pumpAndSettle();
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
