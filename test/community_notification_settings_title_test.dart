import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/community_notification_settings_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/fit_or_hide_title.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// 通知の設定の画面名は、戻るボタンのある上部バーに412pxの幅で入る
/// （利用者の動きで見つかったこと：画面名を1つ目のスイッチの名前「Push
/// notifications on this device」にしていて、英語の412pxで2px入らず、
/// 西・仏語ではもっと狭い画面から隠れていた）。
void main() {
  testWidgets('the screen name fits beside the back button at 412px', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    final settings = SettingsService();
    await settings.init();
    final themes = ThemeService();
    await themes.init();
    addTearDown(settings.dispose);
    addTearDown(themes.dispose);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final locale in AppLocalizations.supportedLocales) {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: themes.themeDataFor(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const CommunityNotificationSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      final title = find.byType(FitOrHideTitle);
      final name = tester.widget<FitOrHideTitle>(title).text;
      final l10n = AppLocalizations.of(tester.element(title))!;
      expect(name, l10n.communityNotificationSettingsTitle);
      expect(
        find.descendant(of: title, matching: find.text(name)),
        findsOneWidget,
        reason: '$locale: «$name» is hidden at 412px',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
