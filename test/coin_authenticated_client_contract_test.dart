import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';

void main() {
  const apiRoot =
      'https://example.execute-api.ap-northeast-1.amazonaws.com/';
  const version = 'v4-min10-repriced-20261113';
  const uuid = '123e4567-e89b-12d3-a456-426614174000';

  test('signed-in reward read uses the bearer token and never a user ID', () async {
    final calls = <http.Request>[];
    final httpClient = MockClient((request) async {
      calls.add(request);
      return http.Response(
        jsonEncode({
          'niarimUserId': 'Nauthenticated',
          'balanceCoins': 55000,
          'entitlements': <dynamic>[],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = NiarimApiClient(
      baseUrl: apiRoot,
      httpClient: httpClient,
      tokenProvider: () async => 'synthetic-id-token',
    );
    addTearDown(client.close);
    final response = await CommunityApi(client).myRewardState();
    expect(response['balanceCoins'], 55000);
    expect(calls, hasLength(1));
    expect(calls.single.url.path, '/me/rewards');
    expect(calls.single.url.queryParameters, isEmpty);
    expect(calls.single.headers['authorization'], 'Bearer synthetic-id-token');
  });

  test('an authenticated GET refreshes a rejected ID token once', () async {
    var count = 0;
    var requests = 0;
    final tokens = <String>[];
    final client = NiarimApiClient(
      baseUrl: apiRoot,
      // Do not forward a finalized Request into a second MockClient.
      // The single transport records both token refresh and response order.
      httpClient: MockClient((request) async {
        tokens.add(request.headers['authorization'] ?? '');
        requests++;
        return requests == 1
            ? http.Response('{"code":"UNAUTHORIZED","error":"expired"}', 401)
            : http.Response('{"balanceCoins":120}', 200);
      }),
      tokenProvider: () async => (++count == 1 ? 'expired' : 'fresh'),
      maxGetRetries: 0,
      retryBackoff: Duration.zero,
    );
    addTearDown(client.close);
    final wallet = await CommunityApi(client).myRewardState();
    expect(wallet['balanceCoins'], 120);
    expect(tokens, ['Bearer expired', 'Bearer fresh']);
    expect(requests, 2);
  });

  test('monthly and annual quotes use the server, not a local debit', () async {
    final calls = <http.Request>[];
    final client = NiarimApiClient(
      baseUrl: apiRoot,
      tokenProvider: () async => 'synthetic-id-token',
      httpClient: MockClient((request) async {
        calls.add(request);
        return http.Response(
          jsonEncode({
            'enabled': request.url.queryParameters['months'] == '1',
            'catalogPriceCoins': request.url.queryParameters['months'] == '1'
                ? 55000
                : 550000,
            'priceVersion': version,
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final api = CommunityApi(client);
    final month = await api.fullPremiumCoinQuote(months: 1);
    final year = await api.fullPremiumCoinQuote(months: 12);
    expect(month['catalogPriceCoins'], 55000);
    expect(year['catalogPriceCoins'], 550000);
    expect(year['enabled'], false);
    expect(calls.map((r) => r.url.path), everyElement('/me/rewards/quote'));
    expect(calls.map((r) => r.headers['authorization']),
        everyElement('Bearer synthetic-id-token'));
  });

  test('individual multi-benefit request contains no client pricing or owner ID', () async {
    final calls = <http.Request>[];
    final client = NiarimApiClient(
      baseUrl: apiRoot,
      tokenProvider: () async => 'synthetic-id-token',
      httpClient: MockClient((request) async {
        calls.add(request);
        return http.Response('{"redeemed":true,"duplicate":false}', 200);
      }),
    );
    addTearDown(client.close);
    final result = await CommunityApi(client).redeemSelectedBenefitCoins(
      targets: ['toneCurve', 'levelAdjustment'],
      duration: 'week',
      quantity: 1,
      requestId: uuid,
      priceVersion: version,
    );
    expect(result['redeemed'], true);
    final request = calls.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/me/rewards/redeem');
    expect(request.headers['authorization'], 'Bearer synthetic-id-token');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['targets'], ['toneCurve', 'levelAdjustment']);
    expect(body['priceVersion'], version);
    expect(body['requestId'], uuid);
    expect(body.containsKey('costCoins'), false);
    expect(body.containsKey('accountId'), false);
    expect(body.containsKey('niarimUserId'), false);
  });

  test('401 rejection never retries a coin debit POST with another token', () async {
    var requests = 0;
    final client = NiarimApiClient(
      baseUrl: apiRoot,
      tokenProvider: () async => 'expired-test-token',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response(
          '{"error":"Unauthorized","code":"UNAUTHORIZED"}', 401,
        );
      }),
    );
    addTearDown(client.close);
    await expectLater(
      CommunityApi(client).redeemFullPremiumCoins(
        requestId: uuid,
        priceVersion: version,
      ),
      throwsA(isA<NiarimApiException>()),
    );
    expect(requests, 1);
  });
}
