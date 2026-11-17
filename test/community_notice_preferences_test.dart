import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_follow_notifications_screen.dart';
import 'package:niarim/screens/settings/community_notification_settings_screen.dart';
import 'package:niarim/screens/settings/settings_screen.dart';
import 'package:niarim/services/community_notice.dart';
import 'package:niarim/services/community_notice_history.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Premium extends ChangeNotifier implements PremiumService {
  @override
  bool get isPremium => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first social notices win permanently, isolated by account', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    Map<String, String> event(String id, String key) => {
      'eventId': id,
      'firstKey': key * 64,
    };
    final original = event('first_follow', 'a');
    final later = event('later_follow', 'a');
    final bookmark = event('new_bookmark', 'b');
    final repost = event('new_repost', 'c');
    final samePage = await CommunityNoticeHistory.filter({
      'events': [later, original],
      'nextCursor': 'keep-this',
    }, 'account1');
    expect(samePage, {
      'events': [original],
      'nextCursor': 'keep-this',
    });
    final observedAgain = await CommunityNoticeHistory.filter({
      'events': [later, bookmark, repost, original],
    }, 'account1');
    expect(observedAgain['events'], [bookmark, repost, original]);
    expect(
      (await CommunityNoticeHistory.filter({
        'events': [later],
      }, 'account2'))['events'],
      [later],
    );
  });

  testWidgets(
    'gear and creation settings open one screen and return to their caller',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      final themes = ThemeService();
      final l10n = lookupAppLocalizations(const Locale('ja'));
      final router = GoRouter(
        initialLocation: communityNotificationsRoute,
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(
            path: communityNotificationsRoute,
            builder: (_, _) => const CommunityFollowNotificationsScreen(),
          ),
          GoRoute(
            path: communityNotificationSettingsRoute,
            builder: (_, _) => const CommunityNotificationSettingsScreen(),
          ),
          GoRoute(
            path: communityMyWorksRoute,
            builder: (_, _) => const Scaffold(body: Text('Account settings')),
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
            theme: themes.themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.communityFollowNotificationsSignInRequired),
        findsOneWidget,
      );
      expect(find.text(l10n.communityFollowNotificationsEmpty), findsNothing);
      await tester.tap(find.text(l10n.communitySignInPromptConnect));
      await tester.pumpAndSettle();
      expect(find.text('Account settings'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plazaNotificationSettings')));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityNotificationSettingsScreen), findsOneWidget);

      final toggles = {
        for (final category in CommunityPushCategory.values)
          category: find.byKey(ValueKey(category.preferenceKey)),
      };
      for (final entry in toggles.entries) {
        expect(tester.widget<SwitchListTile>(entry.value).value, isTrue);
      }
      final master = find.byKey(const Key('pushNotificationsOnDevice'));
      await tester.tap(master);
      await tester.pumpAndSettle();
      for (final toggle in toggles.values) {
        final tile = tester.widget<SwitchListTile>(toggle);
        expect(tile.value, isTrue);
        expect(tile.onChanged, isNull);
      }
      final toggle = toggles[CommunityPushCategory.bookmark]!;
      final toggleContext = tester.element(toggle);
      final theme = Theme.of(toggleContext);
      const selected = {WidgetState.selected};
      const disabled = {WidgetState.selected, WidgetState.disabled};
      expect(
        SwitchTheme.of(toggleContext).thumbColor?.resolve(selected),
        theme.colorScheme.onPrimary,
      );
      expect(
        SwitchTheme.of(toggleContext).trackColor?.resolve(selected),
        theme.colorScheme.primary,
      );
      expect(
        SwitchTheme.of(toggleContext).thumbColor?.resolve(disabled),
        isNull,
      );
      expect(
        SwitchTheme.of(toggleContext).trackColor?.resolve(disabled),
        isNull,
      );
      await tester.tap(master);
      await tester.pumpAndSettle();
      await tester.tap(toggles[CommunityPushCategory.bookmark]!);
      await tester.pumpAndSettle();
      expect(settings.pushEnabledFor(CommunityPushCategory.bookmark), isFalse);
      expect(settings.pushEnabledFor(CommunityPushCategory.follower), isTrue);
      expect(settings.pushEnabledFor(CommunityPushCategory.repost), isTrue);
      expect(
        settings.pushEnabledFor(CommunityPushCategory.publication),
        isTrue,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityFollowNotificationsScreen), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      final setting = find.text('この端末のプッシュ通知');
      await tester.scrollUntilVisible(setting, 180);
      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityNotificationSettingsScreen), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(toggles[CommunityPushCategory.bookmark]!)
            .value,
        isFalse,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      final reopened = SettingsService();
      await reopened.init();
      expect(reopened.pushEnabledFor(CommunityPushCategory.bookmark), isFalse);
      expect(reopened.pushEnabledFor(CommunityPushCategory.follower), isTrue);
      reopened.dispose();
    },
  );
}
