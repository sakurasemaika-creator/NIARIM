// 契約状態の画面（利用中の特典・会員の種類）の有効期限が、その言語の日付の
// 書き方で出ることを、本物の画面で確かめる。
//
// 以前は日付を「2026年11月13日 16時06分」とコードで組み立て、「利用期限」の
// 語と「: 」でつないでいたため、英語でも「Expires: 2026年11月13日 16時06分」、
// フランス語は「Expire: …」（コロンの前の空白も無い）と出ていた。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/membership_benefits_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'membership-expiry-account';
  @override
  String get email => 'example.invalid';
  @override
  String get displayName => 'Example';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends GoogleAuthService {
  final _user = _Account();
  @override
  GoogleSignInAccount? get account => _user;
  @override
  bool get isConfigured => true;
}

/// Google Playで確認済みの年額会員で、コインで交換した全機能も利用中の状態。
/// 画面は状態を読むだけなので、読む値だけを差し替える。
class _Member extends PremiumService {
  _Member(this.playUntil, this.coinUntil);
  final DateTime playUntil;
  final DateTime coinUntil;
  @override
  bool get hasVerifiedPlayPremium => true;
  @override
  String? get verifiedSubscriptionProductId => PremiumService.yearlyProductId;
  @override
  DateTime? get verifiedExpiryDate => playUntil;
  @override
  DateTime? get activeCoinPremiumExpiry => coinUntil;
  @override
  void applyServerCoinPremiumExpiry(DateTime? expiresAt, {String? accountId}) {}
}

http.Response _json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

CommunityService _server(DateTime benefitUntil) => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/me/rewards') {
          return _json({
            'entitlements': [
              {
                'feature': 'endCardEdit',
                'status': 'active',
                'expiresAtEpochMs': benefitUntil.millisecondsSinceEpoch,
              },
            ],
          });
        }
        return _json(<String, Object>{});
      }),
    ),
  ),
);

/// 漢字・仮名・ハングル（英語・スペイン語・フランス語の画面に出てはいけない）。
final _cjk = RegExp('[぀-ヿ一-鿿가-힯]');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'ja': Locale('ja'),
    'en': Locale('en'),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    testWidgets('契約状態の有効期限がその言語の日付で出る（$name）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // 3つとも違う日時にして、どの行がどの日付かを取り違えないようにする。
      final now = DateTime.now();
      final playUntil = DateTime(now.year + 1, 2, 3, 16, 6);
      final coinUntil = DateTime(now.year + 1, 4, 5, 9, 7);
      final benefitUntil = DateTime(now.year + 1, 6, 7, 21, 8);
      final premium = _Member(playUntil, coinUntil);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<SettingsService>.value(
              value: SettingsService(),
            ),
            ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
            ChangeNotifierProvider<CommunityService>.value(
              value: _server(benefitUntil),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MembershipBenefitsScreen(),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      // 特典の一覧が出ていること（出ていなければ何も確かめていない）。
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

      final l10n = lookupAppLocalizations(locale);
      final texts = [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          text.data ?? text.textSpan?.toPlainText() ?? '',
      ];
      // 日付はその言語の書き方（年月日の並び・月の名前・12/24時間）。
      String date(DateTime d) =>
          DateFormat.yMMMd(l10n.localeName).add_jm().format(d);
      for (final (what, expiry) in [
        ('Google Playの会員', playUntil),
        ('コインの全機能', coinUntil),
        ('交換した特典', benefitUntil),
      ]) {
        expect(
          texts.where((t) => t.contains(date(expiry))),
          hasLength(1),
          reason: '$name $what: ${date(expiry)} が1行に出ていない\n$texts',
        );
      }
      // どの言語にも「時」「分」の付いた時刻は無い。
      for (final text in texts) {
        expect(text, isNot(matches(RegExp('[0-9]時'))), reason: '$name: $text');
        expect(text, isNot(matches(RegExp('[0-9]分'))), reason: '$name: $text');
      }
      if (name == 'en' || name == 'es' || name == 'fr') {
        for (final text in texts) {
          expect(_cjk.hasMatch(text), isFalse, reason: '$name: $text');
        }
      }
      if (name == 'fr') {
        // フランス語の句読点の前の空白（「Expire: 」ではない）。
        for (final text in texts) {
          expect(
            text,
            isNot(matches(RegExp(r'\p{L}:', unicode: true))),
            reason: text,
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      premium.dispose();
    });
  }
}
