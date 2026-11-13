import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';
import 'package:niarim/services/coin_redemption_attempt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRedemptionApi extends CommunityApi {
  _FakeRedemptionApi()
    : super(NiarimApiClient(baseUrl: 'https://example.invalid'));

  final List<String> attemptedIds = [];
  final List<String> attemptedVersions = [];
  final List<int> attemptedMonths = [];
  bool failNext = false;

  @override
  Future<Map<String, dynamic>> redeemFullPremiumCoins({
    required String requestId,
    required String priceVersion,
    int months = 1,
  }) async {
    attemptedMonths.add(months);
    attemptedIds.add(requestId);
    attemptedVersions.add(priceVersion);
    if (failNext) {
      failNext = false;
      throw const NiarimApiException.network('connection lost');
    }
    return {
      'redeemed': true,
      'expiresAtEpochMs': 1800000000000,
      'costCoins': 55000,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'network timeout preserves UUID until the original debit is confirmed',
    () async {
      final api = _FakeRedemptionApi()..failNext = true;
      const store = CoinRedemptionAttemptStore();
      await expectLater(
        store.redeem(
          api: api,
          accountId: 'GoogleAccountA',
          serverPriceVersion: 'v1-premium-month',
        ),
        throwsA(isA<NiarimApiException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString(
        'pending_coin_redemption_full_premium_v1_GoogleAccountA',
      );
      expect(pending, isNotNull);
      final first = api.attemptedIds.single;
      final success = await store.redeem(
        api: api,
        accountId: 'GoogleAccountA',
        serverPriceVersion: 'v1-premium-month',
      );
      expect(success['redeemed'], true);
      expect(api.attemptedIds[1], first);
      expect(
        prefs.getString(
          'pending_coin_redemption_full_premium_v1_GoogleAccountA',
        ),
        isNull,
      );
      await store.redeem(
        api: api,
        accountId: 'GoogleAccountA',
        serverPriceVersion: 'v1-premium-month',
      );
      expect(api.attemptedIds[2], isNot(first));
    },
  );

  test(
    'a pending debit is never resumed against a different account',
    () async {
      final api = _FakeRedemptionApi()..failNext = true;
      const store = CoinRedemptionAttemptStore();
      await expectLater(
        store.redeem(
          api: api,
          accountId: 'GoogleAccountA',
          serverPriceVersion: 'v1-premium-month',
        ),
        throwsA(isA<NiarimApiException>()),
      );
      final first = api.attemptedIds.single;
      await store.redeem(
        api: api,
        accountId: 'GoogleAccountB',
        serverPriceVersion: 'v1-premium-month',
      );
      expect(api.attemptedIds[1], isNot(first));
      await store.redeem(
        api: api,
        accountId: 'GoogleAccountA',
        serverPriceVersion: 'v1-premium-month',
      );
      expect(api.attemptedIds[2], first);
    },
  );

  test(
    'monthly and annual retries keep separate durable request IDs',
    () async {
      final api = _FakeRedemptionApi()..failNext = true;
      const store = CoinRedemptionAttemptStore();
      await expectLater(
        store.redeem(
          api: api,
          accountId: 'account',
          serverPriceVersion: 'v3-final-annual550000',
          months: 12,
        ),
        throwsA(isA<NiarimApiException>()),
      );
      final pendingAnnual = api.attemptedIds.single;
      final monthly = await store.redeem(
        api: api,
        accountId: 'account',
        serverPriceVersion: 'v3-final-annual550000',
        months: 1,
      );
      expect(monthly['redeemed'], true);
      expect(api.attemptedIds[1], isNot(pendingAnnual));
      final annual = await store.redeem(
        api: api,
        accountId: 'account',
        serverPriceVersion: 'v3-final-annual550000',
        months: 12,
      );
      expect(annual['redeemed'], true);
      expect(api.attemptedIds[2], pendingAnnual);
      expect(api.attemptedMonths, [12, 1, 12]);
    },
  );

  test('unsupported Premium periods never send redemption requests', () async {
    final api = _FakeRedemptionApi();
    const store = CoinRedemptionAttemptStore();
    await expectLater(
      store.redeem(
        api: api,
        accountId: 'account',
        serverPriceVersion: 'v3-final-annual550000',
        duration: 'year',
        quantity: 1,
      ),
      throwsArgumentError,
    );
    expect(api.attemptedIds, isEmpty);
  });
}
