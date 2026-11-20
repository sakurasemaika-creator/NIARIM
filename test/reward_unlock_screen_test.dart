import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';

class _RewardAccount implements GoogleSignInAccount {
  @override
  String get id => 'reward-test-account';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RewardAuth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _RewardAccount();
}

class _RewardApi extends CommunityApi {
  _RewardApi(super.client);

  int starts = 0;
  bool credited = false;

  @override
  Future<Map<String, dynamic>> myRewardState() async => {
    'balanceCoins': credited ? 20 : 0,
    'rewardEarningEnabled': true,
    'rewardedCoinsPerCompletion': 10,
    'rewardedOfferVersion': 'launch-v1-10-coins',
  };

  @override
  Future<Map<String, dynamic>> beginRewardedAdSession({
    required int rewardCoins,
    required String offerVersion,
  }) async => {
    'rewardCoins': rewardCoins,
    'offerVersion': offerVersion,
    'adUnitId': 'fixture-ad-unit',
    'customData': 'v1.fixture.${++starts}',
  };

  @override
  Future<Map<String, dynamic>> rewardedAdStatus(String nonce) async => {
    'credited': credited,
    'status': credited ? 'credited' : 'pending',
  };
}

class _RewardAds extends AdvertisingService {
  _RewardAds({required super.premiumService});

  bool available = false;

  @override
  bool get canOfferRewardedAds => true;

  @override
  Future<bool> showRewardedCoinAd({
    required String adUnitId,
    required String customData,
  }) async => available;
}

class _ExchangeApi extends CommunityApi {
  _ExchangeApi(super.client);

  bool annualEnabled = false;
  int balance = 600000;
  final redemptions = <String>[];
  final entitlements = <Map<String, Object>>[];

  @override
  Future<Map<String, dynamic>> myRewardState() async => {
    'balanceCoins': balance,
    'redemptionEnabled': true,
    'individualRedemptionEnabled': true,
    'entitlements': entitlements,
  };

  @override
  Future<Map<String, dynamic>> fullPremiumCoinQuote({int months = 1}) async {
    final enabled = months == 1 || annualEnabled;
    final amount = months == 12 ? 550000 : 55000;
    return {
      'enabled': enabled,
      'priceCoins': enabled ? amount : null,
      'catalogPriceCoins': amount,
      'priceVersion': enabled ? CoinBenefitPriceCatalog.version : null,
    };
  }

  @override
  Future<Map<String, dynamic>> selectedBenefitCoinQuote({
    required List<String> targets,
    required String duration,
    required int quantity,
  }) async {
    expect(targets, ['toneCurve']);
    expect(duration, 'hour');
    expect(quantity, 1);
    return {
      'enabled': true,
      'priceCoins': 2160,
      'catalogPriceCoins': 2160,
      'priceVersion': CoinBenefitPriceCatalog.version,
    };
  }

  @override
  Future<Map<String, dynamic>> redeemSelectedBenefitCoins({
    required List<String> targets,
    required String duration,
    required int quantity,
    required String requestId,
    required String priceVersion,
  }) async {
    expect(targets, ['toneCurve']);
    expect(duration, 'hour');
    expect(quantity, 1);
    expect(priceVersion, CoinBenefitPriceCatalog.version);
    _redeem('toneCurve', 2160, const Duration(hours: 1));
    return {'redeemed': true};
  }

  @override
  Future<Map<String, dynamic>> redeemFullPremiumCoins({
    required String requestId,
    required String priceVersion,
    int months = 1,
  }) async {
    expect(annualEnabled, isTrue);
    expect(months, 12);
    expect(priceVersion, CoinBenefitPriceCatalog.version);
    _redeem('fullPremium', 550000, const Duration(days: 365));
    return {'redeemed': true};
  }

  void _redeem(String feature, int price, Duration duration) {
    redemptions.add(feature);
    balance -= price;
    entitlements.add({
      'feature': feature,
      'status': 'active',
      'expiresAtEpochMs': DateTime.now().add(duration).millisecondsSinceEpoch,
    });
  }
}

Future<void> _selectTwelveMonths(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rewardDurationButton')));
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
}

void main() {
  testWidgets('shows unavailable ads and allows retries and consecutive ads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = NiarimApiClient(baseUrl: 'https://example.invalid');
    final api = _RewardApi(client);
    final community = CommunityService(api: api);
    final premium = PremiumService();
    final settings = SettingsService();
    final ads = _RewardAds(premiumService: premium);
    final auth = _RewardAuth();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ChangeNotifierProvider<CommunityService>.value(value: community),
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<AdvertisingService>.value(value: ads),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RewardUnlockScreen(mode: RewardPageMode.earnCoins),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labels = lookupAppLocalizations(const Locale('ja'));
    final watch = find.byKey(const Key('rewardWatchAdButton'));
    await tester.tap(watch);
    await tester.pump();
    expect(api.starts, 1);
    expect(find.text(labels.rewardUnlockRewardUnavailable), findsOneWidget);
    expect(find.text(labels.coinAmount(0)), findsOneWidget);
    expect(tester.widget<FilledButton>(watch).onPressed, isNotNull);

    ads.available = true;
    await tester.tap(watch);
    await tester.pump();
    expect(api.starts, 2);
    expect(tester.widget<FilledButton>(watch).onPressed, isNotNull);
    await tester.tap(watch);
    await tester.pump();
    expect(api.starts, 3);
    expect(find.text(labels.rewardUnlockRewardRefresh), findsOneWidget);

    for (final seconds in [1, 2, 4, 6]) {
      await tester.pump(Duration(seconds: seconds));
    }
    api.credited = true;
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text(labels.coinAmount(20)), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    auth.dispose();
    community.dispose();
    premium.dispose();
    settings.dispose();
    client.close();
  });

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

    await _selectTwelveMonths(tester);

    final full = find.byKey(const ValueKey('rewardFeature_fullPremium'));
    await tester.ensureVisible(full);
    await tester.pumpAndSettle();
    await tester.tap(full);
    await tester.pumpAndSettle();
    final price = find.descendant(
      of: full,
      matching: find.textContaining('550,000 opals'),
    );
    expect(price, findsOneWidget);
    expect(find.textContaining('528,000 opals'), findsNothing);
    final total = find.byKey(const Key('rewardTotalCoins'));
    // The summary card is lazily built below the benefit list.
    await tester.scrollUntilVisible(
      total,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(total).data, contains('550,000 opals'));
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

  testWidgets('redeems a single feature and an annual pack only from '
      'enabled offers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = NiarimApiClient(baseUrl: 'https://example.invalid');
    final api = _ExchangeApi(client);
    final auth = _RewardAuth();
    final premium = PremiumService()..bindGoogleAuth(auth);
    final community = CommunityService(api: api);
    final settings = SettingsService();
    addTearDown(client.close);
    addTearDown(community.dispose);
    addTearDown(settings.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ChangeNotifierProvider<CommunityService>.value(value: community),
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

    final duration = find.byKey(const Key('rewardDurationButton'));
    final toneCurve = find.byKey(const ValueKey('rewardFeature_toneCurve'));
    final fullPremium = find.byKey(const ValueKey('rewardFeature_fullPremium'));
    final redeem = find.byKey(const Key('rewardRedeemButton'));
    final list = find.byType(Scrollable).first;
    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(finder, 250, scrollable: list);
      await tester.pumpAndSettle();
    }

    Future<void> confirm() async {
        final previousCount = api.redemptions.length;
      await tester.tap(redeem);
      await tester.pumpAndSettle();
        expect(api.redemptions.length, previousCount);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    await reveal(toneCurve);
    await tester.tap(toneCurve);
    await tester.pumpAndSettle();
    await reveal(redeem);
    await confirm();
    expect(api.redemptions, ['toneCurve']);
    expect(api.balance, 597840);
    expect(premium.isFeatureAvailable(PremiumFeature.toneCurve), isTrue);
    expect(premium.isFeatureAvailable(PremiumFeature.levelAdjustment), isFalse);

    await tester.drag(list, const Offset(0, 850));
    await tester.pumpAndSettle();
    await reveal(toneCurve);
    await tester.tap(toneCurve);
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 550));
    await tester.pumpAndSettle();
    await tester.ensureVisible(duration);
    await _selectTwelveMonths(tester);
    await reveal(fullPremium);
    await tester.tap(fullPremium);
    await tester.pumpAndSettle();
    await reveal(redeem);
    expect(tester.widget<OutlinedButton>(redeem).onPressed, isNull);

    api.annualEnabled = true;
    await tester.drag(list, const Offset(0, 1600));
    await tester.pumpAndSettle();
    final refresh = find.widgetWithIcon(TextButton, Icons.refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    await reveal(redeem);
    expect(tester.widget<OutlinedButton>(redeem).onPressed, isNotNull);
    await confirm();
    expect(api.redemptions, ['toneCurve', 'fullPremium']);
    expect(api.balance, 47840);
    expect(premium.hasCoinPremium, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
      premium.dispose();
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
