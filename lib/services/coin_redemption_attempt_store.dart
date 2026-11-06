import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'api/community_api.dart';
import 'api/niarim_api_exception.dart';

/// Persist a debit UUID BEFORE making the request. On app kill or response
/// loss, the next tap retries the SAME UUID, never a second wallet debit.
/// This is a tiny account-scoped idempotency aid, not proof of coin balance.
class CoinRedemptionAttemptStore {
  const CoinRedemptionAttemptStore();

  static String _key(String accountId) =>
      'pending_coin_redemption_full_premium_v1_$accountId';

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int x) => bytes[x].toRadixString(16).padLeft(2, '0');
    return [
      [for (var i = 0; i < 4; i++) h(i)].join(),
      [for (var i = 4; i < 6; i++) h(i)].join(),
      [for (var i = 6; i < 8; i++) h(i)].join(),
      [for (var i = 8; i < 10; i++) h(i)].join(),
      [for (var i = 10; i < 16; i++) h(i)].join(),
    ].join('-');
  }

  Future<Map<String, dynamic>> redeem({
    required CommunityApi api,
    required String accountId,
    required String serverPriceVersion,
  }) async {
    if (accountId.isEmpty || serverPriceVersion.isEmpty) {
      throw ArgumentError('Missing identity or server price version');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _key(accountId);
    String? requestId;
    String version = serverPriceVersion;
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        final savedId = saved['requestId'];
        final savedVersion = saved['version'];
        if (savedId is String &&
            RegExp(
              r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
            ).hasMatch(savedId) &&
            savedVersion is String &&
            savedVersion.isNotEmpty) {
          requestId = savedId;
          version = savedVersion;
        }
      } on Object {
        // Corrupt local metadata grants no extra currency.
      }
    }
    requestId ??= _newUuid();
    // Require a durable local write before the server can charge coins.
    final stored = await prefs.setString(
      key,
      jsonEncode({'requestId': requestId, 'version': version}),
    );
    if (!stored) throw StateError('Cannot persist the redemption request');

    try {
      final response = await api.redeemFullPremiumCoins(
        requestId: requestId,
        priceVersion: version,
      );
      if (response['redeemed'] != true) {
        throw StateError('Server did not confirm the redemption');
      }
      await prefs.remove(key);
      return response;
    } on NiarimApiException catch (error) {
      // On a definitive price change, the old uncommitted request can safely
      // be abandoned. On HTTP/network uncertainty KEEP its UUID for retry.
      if (error.code == 'REDEMPTION_PRICE_CHANGED' ||
          error.code == 'REDEMPTION_REQUEST_ID_INVALID') {
        await prefs.remove(key);
      }
      rethrow;
    }
  }
}
