import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';

void main() {
  testWidgets('12-month full Premium shows 550000 coins and cannot redeem '
      'until the annual server offer is implemented', (tester) async {
    final premium = PremiumService();
    final settings = SettingsService();
    final auth = GoogleAuthService();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<PremiumService>.value(value: premium),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RewardUnlockScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('rewardDurationButton'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final monthly = find.byType(ExpansionTile).last;
    await tester.tap(find.descendant(
      of: monthly, matching: find.byType(ListTile)).first);
    await tester.pumpAndSettle();
    final twelve = find.byKey(const ValueKey('rewardDuration_month_12'));
    await tester.ensureVisible(twelve);
    await tester.pumpAndSettle();
    await tester.tap(twelve);
    await tester.pumpAndSettle();

    final full = find.byKey(const ValueKey('rewardFeature_fullPremium'));
    await tester.ensureVisible(full);
    await tester.pumpAndSettle();
    await tester.tap(full);
    await tester.pumpAndSettle();
    final price = find.descendant(
      of: full, matching: find.textContaining('550000 coins'));
    expect(price, findsOneWidget);
    expect(find.textContaining('660000 coins'), findsNothing);
    final total = find.byKey(const Key('rewardTotalCoins'));
    // The summary card is lazily built below the benefit list.
    await tester.scrollUntilVisible(
      total, 260, scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(total).data, contains('550000 coins'));
    expect(tester.widget<OutlinedButton>(
      find.byKey(const Key('rewardRedeemButton'))).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    premium.dispose();
    settings.dispose();
    auth.dispose();
  });

  testWidgets(
    'duration picker is above benefit checkboxes and recalculates each price',
    (tester) async {
      final premium = PremiumService();
      final settings = SettingsService();
      final auth = GoogleAuthService();

      const cost = CoinUnlockUnitPrices(
        perHour: 110,
        perDay: 470,
        perWeek: 3520,
        perMonth: 13000,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
            ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RewardUnlockScreen(
              priceCatalog: {CoinUnlockTarget.toneCurve: cost},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('rewardDurationButton')), findsOneWidget);
      expect(find.byKey(const Key('rewardFeature_toneCurve')), findsOneWidget);
      final before = tester.getTopLeft(
        find.byKey(const Key('rewardDurationButton')),
      );
      final after = tester.getTopLeft(
        find.byKey(const Key('rewardFeature_toneCurve')),
      );
      expect(before.dy, lessThan(after.dy));

      expect(find.text('110 coins'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rewardDurationButton')));
      await tester.pumpAndSettle();
      // Categories start collapsed so days remains reachable on small screens.
      await tester.tap(find.widgetWithText(ExpansionTile, 'days'));
      await tester.pumpAndSettle();
      final day2 = find.byKey(const ValueKey('rewardDuration_day_2'));
      await tester.ensureVisible(day2);
      await tester.pumpAndSettle();
      await tester.tap(day2);
      await tester.pumpAndSettle();
      expect(find.text('940 coins'), findsOneWidget);

      // No wallet/SSV/price quote is connected: neither action can spend coins.
      final goalButton = find.byKey(const Key('rewardSetGoalButton'));
      await tester.scrollUntilVisible(
        goalButton,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(goalButton).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      premium.dispose();
      settings.dispose();
      auth.dispose();
    },
  );
}
