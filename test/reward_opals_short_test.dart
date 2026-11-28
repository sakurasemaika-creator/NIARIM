import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// With too few Opals for the chosen benefits, the exchange tab only greyed
/// out "Redeem Opals" (found by walking the app against a local copy of the
/// backend, 2026-11-28). It now says how many more are needed and offers the
/// tabs where Opals are earned.
class _Account implements GoogleSignInAccount {
  @override
  String get id => 'opal-account';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _Account();
}

class _Api extends CommunityApi {
  _Api(super.client, this.balance);

  final int balance;

  @override
  Future<Map<String, dynamic>> myRewardState() async => {
    'balanceCoins': balance,
    'redemptionEnabled': true,
    'individualRedemptionEnabled': true,
    'entitlements': <Map<String, Object>>[],
  };

  @override
  Future<Map<String, dynamic>> fullPremiumCoinQuote({int months = 1}) async {
    final amount = months == 12 ? 550000 : 55000;
    return {
      'enabled': true,
      'priceCoins': amount,
      'catalogPriceCoins': amount,
      'priceVersion': CoinBenefitPriceCatalog.version,
    };
  }

  @override
  Future<Map<String, dynamic>> selectedBenefitCoinQuote({
    required List<String> targets,
    required String duration,
    required int quantity,
  }) async => {
    'enabled': true,
    'priceCoins': 2160,
    'catalogPriceCoins': 2160,
    'priceVersion': CoinBenefitPriceCatalog.version,
  };
}

const _toneCurveHour = 2160;

Future<PremiumService> _open(
  WidgetTester tester, {
  required int balance,
  Locale locale = const Locale('ja'),
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final client = NiarimApiClient(baseUrl: 'https://example.invalid');
  final auth = _Auth();
  final premium = PremiumService()..bindGoogleAuth(auth);
  final community = CommunityService(api: _Api(client, balance));
  final settings = SettingsService();
  final theme = ThemeService();
  addTearDown(client.close);
  addTearDown(community.dispose);
  addTearDown(settings.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _screen,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ChangeNotifierProvider<CommunityService>.value(value: community),
          ChangeNotifierProvider<ThemeService>.value(value: theme),
        ],
        child: MaterialApp(
          theme: theme.themeDataFor(locale),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The Opals screen's three tabs, with stand-ins for the first two.
          home: const DefaultTabController(
            length: 3,
            initialIndex: 2,
            child: Scaffold(
              body: TabBarView(
                children: [
                  Center(child: Text('missions tab')),
                  Center(child: Text('ads tab')),
                  RewardUnlockScreen(embedded: true),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final toneCurve = find.byKey(const ValueKey('rewardFeature_toneCurve'));
  await tester.scrollUntilVisible(
    toneCurve,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  await tester.tap(toneCurve);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('rewardRedeemButton')),
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  return premium;
}

/// Takes the screen away and stops the Premium service's timer.
Future<void> _close(WidgetTester tester, PremiumService premium) async {
  await tester.pumpWidget(const SizedBox.shrink());
  premium.dispose();
}

final _short = find.byKey(const Key('rewardOpalsShort'));
final _screen = GlobalKey();

/// Writes what the screen looks like to build/reward-opals-short/.
Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final out = Directory('build/reward-opals-short')
      ..createSync(recursive: true);
    File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  for (final (button, tab) in [
    ('rewardOpalsShortEarn', 'ads tab'),
    ('rewardOpalsShortMissions', 'missions tab'),
  ]) {
    testWidgets('too few Opals: how many more, and $button opens the $tab', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final premium = await _open(tester, balance: 500);
      final l10n = lookupAppLocalizations(const Locale('ja'));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('rewardRedeemButton')))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('rewardOpalsShortMissions')),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(_short).data,
        l10n.rewardUnlockOpalsShort(_toneCurveHour - 500),
      );
      expect(l10n.rewardUnlockOpalsShort(1660), 'あと1,660オパールで交換できます');
      await _capture(tester, 'ja_412');

      await tester.tap(find.byKey(Key(button)));
      await tester.pumpAndSettle();
      expect(find.text(tab), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester, premium);
    });
  }

  testWidgets('enough Opals: nothing more to say', (tester) async {
    final premium = await _open(tester, balance: _toneCurveHour);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('rewardRedeemButton')))
          .onPressed,
      isNotNull,
    );
    expect(_short, findsNothing);
    expect(find.byKey(const Key('rewardOpalsShortEarn')), findsNothing);
    await _close(tester, premium);
  });

  testWidgets('French, 320 px, text ×2: the line and both buttons fit', (
    tester,
  ) async {
    await loadAppFonts(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final premium = await _open(
      tester,
      balance: 500,
      locale: const Locale('fr'),
      size: const Size(320, 700),
    );
    final missions = find.byKey(const Key('rewardOpalsShortMissions'));
    await tester.scrollUntilVisible(
      missions,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'fr_320_x2');
    final earn = find.byKey(const Key('rewardOpalsShortEarn'));
    // Too wide for one row: one button per row, each as wide as the card.
    expect(
      tester.getTopLeft(missions).dy,
      greaterThan(tester.getTopLeft(earn).dy),
    );
    expect(tester.takeException(), isNull);
    await _close(tester, premium);
  });

  test('the count is a plural with the language’s digit grouping', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final grouped = NumberFormat.decimalPattern(
        locale.toString(),
      ).format(1660);
      expect(l10n.rewardUnlockOpalsShort(1660), contains(grouped));
      expect(l10n.rewardUnlockOpalsShort(1), isNot(contains('{')));
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.rewardUnlockOpalsShort(1), 'Collect 1 more Opal to redeem');
    expect(en.rewardUnlockOpalsShort(2), 'Collect 2 more Opals to redeem');
  });
}
