// 全機能を1か月・12か月以外の期間（2か月など）で交換するときの確認の文が、
// 交換する内容と有効期限の知らせの間で改行され、「\n」の字がそのまま
// 出ないことを、本物の画面で確かめる。
//
// 文字列の中で改行を「\\n」と書いていたため、確認のダイアログに
// 「…2 meses · 110000 ópalos\n\nVigencia tras el canje…」と出ていた
// （1か月・12か月はサーバーの見積もりの別の確認で、正しく改行していた）。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/coin_duration_label.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-flexible-confirm';
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

http.Response _json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// どの期間にも価格表どおりの見積もりを返し、残高が足りるサーバー。
CommunityService _server() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.method != 'GET') return _json({'redeemed': false});
        final query = request.url.queryParameters;
        if (request.url.path == '/me/rewards/quote' &&
            query.containsKey('quantity')) {
          final price = CoinBenefitPriceCatalog.cost(
            CoinUnlockTarget.fullPremium,
            CoinUnlockDuration(
              int.parse(query['quantity']!),
              CoinDurationUnit.values.byName(query['duration']!),
            ),
          );
          return _json({
            'enabled': true,
            'priceCoins': price,
            'catalogPriceCoins': price,
            'priceVersion': CoinBenefitPriceCatalog.version,
          });
        }
        return _json(switch (request.url.path) {
          '/me/rewards' => {
            'balanceCoins': 9999999,
            'redemptionEnabled': true,
            'entitlements': <Object>[],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  for (final (name, locale) in const [
    ('ja', Locale('ja')),
    ('es', Locale('es')),
  ]) {
    testWidgets('2か月の全機能の交換の確認で、内容と期限の知らせの間が改行になる（$name）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 6000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final premium = PremiumService();
      addTearDown(premium.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<SettingsService>.value(
              value: SettingsService(),
            ),
            ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
            ChangeNotifierProvider<CommunityService>.value(value: _server()),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RewardUnlockScreen(),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();
      }

      await settle();
      await tester.tap(find.byKey(const ValueKey('rewardFeature_fullPremium')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rewardDurationButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(ExpansionTile).at(CoinDurationUnit.month.index),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final twoMonths = find.byKey(const ValueKey('rewardDuration_month_2'));
      await tester.ensureVisible(twoMonths);
      await tester.pumpAndSettle();
      await tester.tap(twoMonths);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rewardRedeemButton')));
      await settle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final l10n = lookupAppLocalizations(locale);
      final period = coinUnlockDurationLabel(
        l10n,
        const CoinUnlockDuration(2, CoinDurationUnit.month),
      );
      // 数と単位を行の途中で切らないための字（幅の無い字・改行しない空白）を
      // 普通の文へ戻して比べる。
      String plain(String text) =>
          text.replaceAll('\u2060', '').replaceAll('\u00a0', ' ');
      final cost = plain(
        l10n.coinAmount(
          CoinBenefitPriceCatalog.cost(
            CoinUnlockTarget.fullPremium,
            const CoinUnlockDuration(2, CoinDurationUnit.month),
          ),
        ),
      );
      final body = [
        for (final element
            in find
                .descendant(of: dialog, matching: find.byType(RichText))
                .evaluate())
          plain(
            (element.renderObject! as RenderParagraph).text.toPlainText(
              includeSemanticsLabels: false,
            ),
          ),
      ].where((text) => text.contains(cost)).toList();
      expect(body, hasLength(1), reason: '$name: 交換する内容の文');
      expect(body.single, isNot(contains(r'\n')), reason: body.single);
      final paragraphs = body.single.split('\n\n');
      expect(paragraphs, hasLength(2), reason: body.single);
      expect(paragraphs.first, contains(plain(period)));
      expect(paragraphs.first, endsWith(cost));
      expect(paragraphs.last, isNot(contains(cost)));
      await tester.tap(
        find.descendant(of: dialog, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
