import 'package:flutter/foundation.dart';

/// One operator present in the signed-in account's present box.
@immutable
class OpalPresent {
  const OpalPresent({
    required this.id,
    required this.coins,
    required this.title,
    required this.body,
    required this.translations,
    required this.claimUntil,
    required this.claimed,
  });

  final String id;
  final int coins;
  final String title;
  final String body;

  /// Per-language `(title, body)` written by the operator, keyed like
  /// `AppLocalizations.localeName` (`ja`, `en`, `zh_Hant`...).
  final Map<String, ({String title, String body})> translations;
  final DateTime claimUntil;
  final bool claimed;

  ({String title, String body}) messageFor(String localeName) =>
      translations[localeName] ?? (title: title, body: body);

  OpalPresent asClaimed() => OpalPresent(
    id: id,
    coins: coins,
    title: title,
    body: body,
    translations: translations,
    claimUntil: claimUntil,
    claimed: true,
  );

  static OpalPresent fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final coins = json['coins'];
    final title = json['title'];
    final body = json['body'];
    final until = json['claimUntilEpochMs'];
    final claimed = json['claimed'];
    if (id is! String ||
        id.isEmpty ||
        coins is! int ||
        coins < 1 ||
        title is! String ||
        body is! String ||
        until is! int ||
        until < 0 ||
        until > 8640000000000000 ||
        claimed is! bool) {
      throw const FormatException('Invalid present');
    }
    final translations = <String, ({String title, String body})>{};
    final raw = json['translations'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (entry.key is String &&
            value is Map &&
            value['title'] is String &&
            value['body'] is String) {
          translations[entry.key as String] = (
            title: value['title'] as String,
            body: value['body'] as String,
          );
        }
      }
    }
    return OpalPresent(
      id: id,
      coins: coins,
      title: title,
      body: body,
      translations: translations,
      claimUntil: DateTime.fromMillisecondsSinceEpoch(until),
      claimed: claimed,
    );
  }
}

/// The server's answer to `GET /me/gifts`.
@immutable
class OpalGiftInbox {
  const OpalGiftInbox({
    required this.niarimUserId,
    required this.accountAgeSeconds,
    required this.presents,
  });

  final String niarimUserId;

  /// Seconds since the server created the NIARIM account (null if unknown).
  final int? accountAgeSeconds;
  final List<OpalPresent> presents;

  int get unclaimedCount => presents.where((p) => !p.claimed).length;

  OpalGiftInbox withClaimed(String presentId) => OpalGiftInbox(
    niarimUserId: niarimUserId,
    accountAgeSeconds: accountAgeSeconds,
    presents: [
      for (final present in presents)
        present.id == presentId ? present.asClaimed() : present,
    ],
  );

  static OpalGiftInbox fromJson(Map<String, dynamic> json) {
    final userId = json['niarimUserId'];
    final age = json['accountAgeSeconds'];
    final presents = json['presents'];
    if (userId is! String ||
        userId.isEmpty ||
        !(age == null || (age is int && age >= 0)) ||
        presents is! List) {
      throw const FormatException('Invalid present box');
    }
    return OpalGiftInbox(
      niarimUserId: userId,
      accountAgeSeconds: age as int?,
      presents: [
        for (final row in presents)
          if (row is Map) OpalPresent.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}

/// Bumped whenever opals were credited outside the wallet screen (a coupon
/// or a present), so open wallet views reload their server balance.
final ValueNotifier<int> opalWalletRevision = ValueNotifier<int>(0);
