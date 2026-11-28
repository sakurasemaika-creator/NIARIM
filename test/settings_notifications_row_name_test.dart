import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/community_notification_settings_screen.dart';
import 'package:niarim/screens/settings/settings_screen.dart';
import 'package:niarim/services/community_notice.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/fit_or_hide_title.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Premium extends ChangeNotifier implements PremiumService {
  @override
  bool get isPremium => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The settings row still said "Push notifications on this device" after
/// the screen it opens was renamed "Notification settings" (found by walking
/// the app against a local copy of the backend, 2026-11-28). The row now
/// carries the screen's name; its subtitle still says the screen sets this
/// device's push notifications.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the row is named after the screen it opens ($locale)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      final themes = ThemeService();
      final l10n = lookupAppLocalizations(locale);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(
            path: communityNotificationSettingsRoute,
            builder: (_, _) => const CommunityNotificationSettingsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(settings.dispose);
      addTearDown(themes.dispose);
      tester.view.physicalSize = const Size(480, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsService>.value(value: settings),
            ChangeNotifierProvider<PremiumService>(create: (_) => _Premium()),
            ChangeNotifierProvider(create: (_) => CommunityService()),
            ChangeNotifierProvider(create: (_) => GoogleAuthService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: themes.themeDataFor(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.text(l10n.communityNotificationSettingsTitle);
      await tester.scrollUntilVisible(row, 180);
      expect(row, findsOneWidget);
      expect(find.text(devicePushLabel(l10n)), findsNothing);
      expect(find.text(l10n.settingsNotificationsSubtitle), findsOneWidget);
      expect(
        l10n.settingsNotificationsSubtitle,
        contains(devicePushLabel(l10n)),
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityNotificationSettingsScreen), findsOneWidget);
      expect(
        tester.widget<FitOrHideTitle>(find.byType(FitOrHideTitle)).text,
        l10n.communityNotificationSettingsTitle,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
