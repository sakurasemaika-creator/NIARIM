// 同じ種類の値を、同じ言語の中で同じ書き方で出す（P2-16）。
//
// - 描画領域の倍率：仏語・西語で、設定の「既定の描画領域」は「×3.0」、
//   新規プロジェクト・作品の詳細は「3.0×」と、同じ倍率が2通りに書かれていた。
//   作品の側の書き方（数の後に「×」。英語も同じ）にそろえた。どの言語でも
//   設定と新規プロジェクトで同じ書き方であることを見張る。
// - コマ毎秒の呼び名：テーマ・外観の見本一覧の新規プロジェクトの模型の見出しが
//   「FPS」と手書きで、本物の画面（仏語は「i/s」）と違っていた。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_preview_gallery_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the drawing area scale is written one way in each language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final words = lookupAppLocalizations(locale);
      expect(
        words.settingsScaleValue('3.0'),
        words.newProjectScaleValue('3.0'),
        reason: '$locale: settings and the new project differ',
      );
    }
    expect(
      lookupAppLocalizations(const Locale('fr')).settingsScaleValue('3.0'),
      '3.0×',
    );
  });

  testWidgets('the new project sample names the frame rate as the real '
      'screen does (fr)', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final themeService = ThemeService();
    await themeService.init();
    const locale = Locale('fr');
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeService>.value(
        value: themeService,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: themeService.themeData,
          home: const ThemePreviewGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final form = themePreviewEntries.indexWhere((e) => e.id == 'new');
    for (var i = 0; i < form; i++) {
      await tester.tap(find.byKey(const Key('themePreviewNext')));
      await tester.pumpAndSettle();
    }
    final list = find.byKey(const Key('themePreviewContentList'));
    expect(list, findsOneWidget);
    final words = lookupAppLocalizations(locale);
    expect(
      find.descendant(of: list, matching: find.text(words.exportFpsLabel)),
      findsOneWidget,
    );
    expect(find.descendant(of: list, matching: find.text('FPS')), findsNothing);
  });
}
