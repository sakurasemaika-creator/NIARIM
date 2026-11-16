import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';

void main() {
  testWidgets('12-month full Premium shows 550000 opals and cannot redeem '
      'without a server wallet and quote', (tester) async {
    final premium = PremiumService();
    final settings = SettingsService();
    final auth = GoogleAuthService();
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
          home: RewardUnlockScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picker = find.byKey(const Key('rewardDurationButton'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final monthly = find.byType(ExpansionTile).last;
    await tester.tap(
      find.descendant(of: monthly, matching: find.byType(ListTile)).first,
    );
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
      of: full,
      matching: find.textContaining('550000 opals'),
    );
    expect(price, findsOneWidget);
    expect(find.textContaining('528000 opals'), findsNothing);
    final total = find.byKey(const Key('rewardTotalCoins'));
    // The summary card is lazily built below the benefit list.
    await tester.scrollUntilVisible(
      total,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(total).data, contains('550000 opals'));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('rewardRedeemButton')))
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    premium.dispose();
    settings.dispose();
    auth.dispose();
  });

  testWidgets(
    'duration picker remains above benefits and rejects stale quoted prices',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final premium = PremiumService();
      final settings = SettingsService();
      final auth = GoogleAuthService();

      const cost = CoinUnlockUnitPrices(
        perHour: 110,
        perDay: 470,
        perWeek: 3520,
        perMonth: 11080,
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

      // Display the catalog tariff even if the injected quote is stale.
      final toneCurve = find.byKey(const Key('rewardFeature_toneCurve'));
      String amount(CoinUnlockDuration duration) {
        final price = CoinBenefitPriceCatalog.cost(
          CoinUnlockTarget.toneCurve,
          duration,
        );
        return lookupAppLocalizations(const Locale('en')).coinAmount(price);
      }

      expect(
        find.descendant(
          of: toneCurve,
          matching: find.textContaining(
            amount(const CoinUnlockDuration(1, CoinDurationUnit.hour)),
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('110 opals'), findsNothing);
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
      expect(
        find.descendant(
          of: toneCurve,
          matching: find.textContaining(
            amount(const CoinUnlockDuration(2, CoinDurationUnit.day)),
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('940 opals'), findsNothing);

      // No wallet/SSV/price quote is connected: neither action can spend opals.
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
