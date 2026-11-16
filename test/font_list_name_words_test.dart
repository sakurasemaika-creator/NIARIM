// フォント管理の「ダウンロード済み」の一覧で、フォントの名前が語の途中で
// 折れない（DISC183）。
//
// 行の右に操作（ピクセル・お気に入り・名前の変更・削除）の4つのボタンを
// 並べていたので、スマホの幅では名前の欄が0〜30pxしか残らず、名前が
// 「Big / Fo / nt」「Sampl / e / Font」と語の途中・1字ずつで折れていた
// （日本語・仏語、360×740、文字1倍から）。名前が語の途中で折れる幅では、
// 操作を名前の下へ回す。7言語×320/360/412px×文字1.0/1.3/2.0で、名前と
// 大きさの行の語が途中で折れないこと、4つの操作がどの行にも残って押せる
// こと（名前は吹き出しと読み上げ）、はみ出さないことを見張る。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/font_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/word_breaks.dart';

const _names = ['Sample Font', 'Big Font', 'Kosugi Maru Regular'];

Map<String, Object> _font(int i, String name, int size) => {
  'id': 'font_$i',
  'displayName': name,
  'fileName': 'font_$i.${i.isEven ? 'otf' : 'ttf'}',
  'sizeBytes': size,
  'addedAt': DateTime(2026, 11, 15).toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('font names break only between words and keep their four '
        'actions ($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'user_fonts': jsonEncode([
          for (final (i, name) in _names.indexed)
            _font(i + 1, name, [1434, 5452595, 734003][i]),
        ]),
      });
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: context.watch<ThemeService>().themeDataFor(locale),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const FontSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final actions = [
        l10n.fontPixelModeTooltip,
        l10n.commonFavoriteToggle,
        l10n.commonRename,
        l10n.commonDelete,
      ];
      final problems = <String>[];
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, 1600);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();
          final at = '${width.toInt()}px x$scale';
          final error = tester.takeException();
          if (error != null) problems.add('$at: $error');
          for (final name in _names) {
            final row = find.ancestor(
              of: find.text(name),
              matching: find.byType(Card),
            );
            if (row.evaluate().length != 1) {
              problems.add('$at: no row for $name');
              continue;
            }
            // 名前の欄が取れる幅（行の幅から、先頭の印と行の左右の余白を
            // 除いた幅）。これに入る語は途中で折らない。
            final tile = tester.getRect(
              find.descendant(of: row, matching: find.byType(ListTile)),
            );
            final room = tile.width - 16 - 40 - 16 - 24;
            for (final paragraph in textParagraphsIn(row)) {
              if (paragraph.text.style?.fontSize == 11 &&
                  paragraph.text.toPlainText().length == 1) {
                continue; // 先頭の印（拡張子の1字）。
              }
              for (final broken in wordsBrokenThatFit(
                paragraph,
                fitWidth: room,
              )) {
                problems.add('$at $name: $broken');
              }
            }
            // 4つの操作が、この行に1つずつあり、押せる（行の中に見えている）。
            for (final action in actions) {
              final button = find.descendant(
                of: row,
                matching: find.byTooltip(action),
              );
              if (button.evaluate().length != 1) {
                problems.add('$at $name: 「$action」 is missing');
                continue;
              }
              final box = tester.getRect(button);
              final nameBox = tester.getRect(find.text(name));
              if (box.top < nameBox.bottom - 0.5) {
                problems.add('$at $name: 「$action」 overlaps the name row');
              }
              final card = tester.getRect(row);
              if (box.left < card.left - 0.5 ||
                  box.right > card.right + 0.5 ||
                  box.top < card.top - 0.5 ||
                  box.bottom > card.bottom + 0.5 ||
                  box.width < 40 ||
                  box.height < 40) {
                problems.add('$at $name: 「$action」 is outside the row ($box)');
              }
              if (button.hitTestable().evaluate().isEmpty) {
                problems.add('$at $name: 「$action」 cannot be pressed');
              }
            }
          }
        }
      }
      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }

  // 操作を押すと、今までどおりに働く（お気に入り・ピクセル）。
  testWidgets('the actions below a name still work', (tester) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'user_fonts': jsonEncode([_font(1, 'Sample Font', 1434)]),
    });
    const locale = Locale('fr');
    final l10n = lookupAppLocalizations(locale);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeService>().themeDataFor(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FontSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonFavoriteToggle));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsWidgets);
    await tester.tap(find.byTooltip(l10n.fontPixelModeTooltip));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.grid_on), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.commonRename));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
