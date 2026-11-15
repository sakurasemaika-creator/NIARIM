import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/font_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/file_size_label.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// フォント管理の「ダウンロード済み」の一覧で、フォントのファイルの大きさを
/// 表示言語の書き方（`fileSizeLabel`）で出す（以前は全言語「1.4KB」）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('フォントの大きさを7言語の書き方で出す', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'user_fonts': jsonEncode([
        {
          'id': 'font_1',
          'displayName': 'Sample',
          'fileName': 'sample.ttf',
          'sizeBytes': 1434,
          'addedAt': DateTime(2026, 11, 15).toIso8601String(),
        },
      ]),
    });
    final providers = (await tester.runAsync(buildAppProviders))!;
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
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
      final expected = fileSizeLabel(l10n, 1434);
      final subtitle = find.textContaining(expected);
      if (subtitle.evaluate().isEmpty) {
        final shown = tester
            .widgetList<Text>(find.textContaining(' ・ '))
            .map((t) => t.data)
            .join(' / ');
        problems.add('${locale.toLanguageTag()}: 「$expected」が無い（$shown）');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
