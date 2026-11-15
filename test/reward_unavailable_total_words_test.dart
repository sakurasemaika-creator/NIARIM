// 特典交換の合計の欄で、特典を選んでいないときの「正式な交換価格は準備中
// です」が語の途中で折れない（DISC170）。
//
// 合計の数（「55000コイン」）と同じ見出しの大きな字（headlineSmall・
// くらむぼん）で文を出していたので、仏語・360px・文字2倍では1つの語
// （「conversion」「disponibles」）が欄の幅より広く、「Les tarifs de conver /
// sion ne sont pas disponibl / es」と語の途中で折れた。この文は数ではなく
// 準備中であることの説明なので、本文の書体・大きさで出す（確定価格の注記と
// 同じ決まり）。7言語×320/360/412px×文字1.0/1.3/2.0で、どの語も途中で
// 折れないこと（欄より広い語が無いこと）、本文の書体であることを見張る。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

void main() {
  var fontsLoaded = false;
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('the unavailable total is a sentence that breaks only between '
        'words ($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      final themes = ThemeService();
      await themes.init();
      addTearDown(themes.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 20000);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(
              value: PremiumService(),
            ),
            ChangeNotifierProvider<SettingsService>.value(
              value: SettingsService(),
            ),
            ChangeNotifierProvider<GoogleAuthService>.value(
              value: GoogleAuthService(),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            theme: themes.themeDataFor(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RewardUnlockScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final theme = themes.themeDataFor(locale);
      final problems = <String>[];
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, 20000);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();
          final at = '${width.toInt()}px x$scale';
          final error = tester.takeException();
          if (error != null) problems.add('$at: $error');
          final total = find.byKey(const Key('rewardTotalCoins'));
          expect(
            tester.widget<Text>(total).data,
            l10n.rewardUnlockUnavailable,
            reason: 'nothing is selected',
          );
          final paragraph = textParagraphsIn(total).single;
          // 欄より広い語も含めて、語の途中で折れない（どの語も欄に入る）。
          for (final broken in wordsBrokenThatFit(
            paragraph,
            fitWidth: double.infinity,
          )) {
            problems.add('$at: $broken');
          }
          final lines = ParagraphLines(paragraph);
          if (lines.visible != l10n.rewardUnlockUnavailable) {
            problems.add('$at: the sentence is cut: ${lines.lines}');
          }
          // 説明の文なので本文の書体（白光明朝）。数の見出しの書体ではない。
          final family = paragraph.text.style?.fontFamily;
          if (family != theme.textTheme.bodyLarge?.fontFamily) {
            problems.add('$at: drawn in $family');
          }
        }
      }
      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
