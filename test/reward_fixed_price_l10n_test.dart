// 特典交換の確定価格（CoinBenefitPriceCatalog）を出す所で、日本語以外の
// 言語でもその言語の文が出て、数とオパールの単位がその言語の形（単数・複数と
// 空白）で出ることを、本物の画面で確かめる。
//
// 価格を確定価格にしたとき、価格の行の「確定価格（交換準備中）」は日本語と
// 英語しか持たず（スペイン語・フランス語・韓国語でも英語が出る）、合計の
// 注記「（確定価格・交換準備中）」と「重複・有効期限を確認」の
// 「確定単価による合計：… コイン。…」はどの言語でも日本語のまま、数と
// 「 コイン」をコードでつないでいた。
//
// 中国語（簡体字・繁体字）の「确定价格」「確定價格」は、このアプリでは
// 「确定」「確定」がOKのボタンの語なので「价格を確定する」という操作に
// 読めた。名詞として読める「最终价格」「最終價格」にする。
//
// 期待する文は言語ごとにここへ書いてある（ARBの訳をそのまま写したもの）。
// 交換の確認（全機能1か月）は確定価格と同じ見積もりのときだけ出る。
import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-fixed-price';
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

/// 残高[balance]コインで、全機能1か月を確定価格どおりの見積もりで交換できる
/// サーバー。[activeUntil]まではコインの全機能を使っている。
CommunityService _server({required int balance, DateTime? activeUntil}) =>
    CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          maxGetRetries: 0,
          tokenProvider: () async => 'test-token',
          httpClient: MockClient((request) async {
            if (request.method != 'GET') return _json({'redeemed': false});
            return _json(switch (request.url.path) {
              '/me/rewards' => {
                'balanceCoins': balance,
                'redemptionEnabled': true,
                'entitlements': [
                  if (activeUntil != null)
                    {
                      'feature': 'fullPremium',
                      'status': 'active',
                      'expiresAtEpochMs': activeUntil.millisecondsSinceEpoch,
                    },
                ],
              },
              '/me/rewards/quote' => {
                'enabled': true,
                'priceCoins': CoinBenefitPriceCatalog.unitCoins(
                  CoinUnlockTarget.fullPremium,
                  CoinDurationUnit.month,
                ),
                'priceVersion': CoinBenefitPriceCatalog.version,
              },
              _ => <String, Object>{},
            });
          }),
        ),
      ),
    );

/// 価格の行の、交換の準備ができていない確定価格の前に付く言葉。
const _fixedPrice = {
  'en': 'Fixed price (redemption not yet available)',
  'es': 'Precio definitivo (canje aún no disponible)',
  'fr': 'Prix définitif (échange pas encore disponible)',
  'ko': '확정 가격(교환 준비 중)',
  'zh': '最终价格（兑换准备中）',
  'zh_Hant': '最終價格（兌換準備中）',
};

/// 「重複・有効期限を確認」の最後の文の、合計のコインの前まで。
const _fixedTotalLead = {
  'en': 'Total at fixed unit prices: ',
  'es': 'Total según los precios unitarios definitivos: ',
  'fr': 'Total selon les prix unitaires définitifs\u00a0: ',
  'ko': '확정 단가 기준 합계: ',
  'zh': '按最终单价计算的合计：',
  'zh_Hant': '按最終單價計算的合計：',
};

/// その言語の画面に出てはいけない文字。英語・スペイン語・フランス語は
/// 仮名・漢字・ハングル、韓国語は仮名・漢字（日本語の文と日付も見つかる）、
/// 中国語は仮名・ハングル。
RegExp _foreign(String locale) => switch (locale) {
  'ko' => RegExp('[぀-ヿ一-鿿]'),
  'zh' || 'zh_Hant' => RegExp('[぀-ヿ가-힯]'),
  _ => RegExp('[぀-ヿ一-鿿가-힯]'),
};

Locale _localeOf(String code) => code == 'zh_Hant'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
    : Locale(code);

/// 数とコインの単位の語。どの言語の語でも、つながっていれば数と一緒に拾う。
final _coinPhrase = RegExp(
  r'(\d+)\s*(opals?|ópalos?|opales?|오팔|オパール|欧泊|歐泊)(?![\p{L}])',
  unicode: true,
);

/// [within]の中の[Text]とその派生（数と単位を途中で切らない
/// KeepTogetherText等）の文字列。
List<String> _texts(WidgetTester tester, Finder within) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(
      of: within,
      matching: find.byWidgetPredicate((widget) => widget is Text),
    ),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

/// [texts]がその言語の文だけで、数とコインの単位がどこでも[l10n]の
/// coinAmountと同じ形で出ていること。
void _expectLocalised(
  String locale,
  AppLocalizations l10n,
  List<String> texts,
) {
  final foreign = _foreign(locale);
  for (final text in texts) {
    expect(foreign.hasMatch(text), isFalse, reason: '$locale: $text');
    for (final match in _coinPhrase.allMatches(text)) {
      expect(
        match.group(0),
        l10n.coinAmount(int.parse(match.group(1)!)),
        reason: '$locale: 数と単位がその言語の形でない: $text',
      );
    }
  }
}

Future<PremiumService> _pump(
  WidgetTester tester,
  String locale,
  CommunityService community, {
  Map<CoinUnlockTarget, CoinUnlockUnitPrices> priceCatalog = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 6000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final premium = PremiumService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PremiumService>.value(value: premium),
        ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
        ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
        ChangeNotifierProvider<CommunityService>.value(value: community),
      ],
      child: MaterialApp(
        locale: _localeOf(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RewardUnlockScreen(priceCatalog: priceCatalog),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  return premium;
}

/// 期間のシートで[duration]を選ぶ。
Future<void> _pickDuration(
  WidgetTester tester,
  CoinUnlockDuration duration,
) async {
  await tester.tap(find.byKey(const Key('rewardDurationButton')));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(ExpansionTile).at(duration.unit.index),
          matching: find.byType(ListTile),
        )
        .first,
  );
  await tester.pumpAndSettle();
  final option = find.byKey(
    ValueKey('rewardDuration_${duration.unit.name}_${duration.amount}'),
  );
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  test('中国語の確定価格の言葉は、OKのボタンの語（确定・確定）で始まらない', () {
    for (final code in ['zh', 'zh_Hant']) {
      final l10n = lookupAppLocalizations(_localeOf(code));
      expect(l10n.rewardUnlockFixedPrice, _fixedPrice[code], reason: code);
      expect(
        l10n.rewardUnlockFixedPrice.startsWith(l10n.commonOk),
        isFalse,
        reason: '$code: 「${l10n.commonOk}」（OK）で始まると操作に読める',
      );
      expect(
        l10n.rewardUnlockReviewFixedTotal('X'),
        startsWith('${_fixedTotalLead[code]}X'),
        reason: code,
      );
    }
  });

  for (final locale in ['en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    for (final n in [1, 2]) {
      testWidgets('価格の行・合計・重複の確認がその言語の文と数の形（$locale, $n時間・残高$n）', (
        tester,
      ) async {
        final duration = CoinUnlockDuration(n, CoinDurationUnit.hour);
        int cost(CoinUnlockTarget target) =>
            CoinBenefitPriceCatalog.cost(target, duration);
        // トーンカーブだけ、サーバーの価格が確定価格と同じ。
        final premium = await _pump(
          tester,
          locale,
          _server(balance: n),
          priceCatalog: {
            CoinUnlockTarget.toneCurve: CoinUnlockUnitPrices(
              perHour: CoinBenefitPriceCatalog.unitCoins(
                CoinUnlockTarget.toneCurve,
                CoinDurationUnit.hour,
              ),
              perDay: CoinBenefitPriceCatalog.unitCoins(
                CoinUnlockTarget.toneCurve,
                CoinDurationUnit.day,
              ),
              perWeek: CoinBenefitPriceCatalog.unitCoins(
                CoinUnlockTarget.toneCurve,
                CoinDurationUnit.week,
              ),
              perMonth: CoinBenefitPriceCatalog.unitCoins(
                CoinUnlockTarget.toneCurve,
                CoinDurationUnit.month,
              ),
            ),
          },
        );
        if (n != 1) await _pickDuration(tester, duration);
        final l10n = lookupAppLocalizations(_localeOf(locale));

        // 残高はその言語の数と単位（1は単数）。
        expect(find.text(l10n.coinAmount(n)), findsOneWidget);

        // サーバーの価格が確定価格と同じ行は数だけ、サーバーの価格が無い行は
        // 確定価格の言葉と数。
        final toneCurve = find.byKey(const ValueKey('rewardFeature_toneCurve'));
        expect(
          _texts(tester, toneCurve),
          contains(l10n.coinAmount(cost(CoinUnlockTarget.toneCurve))),
        );
        final watermark = find.byKey(const ValueKey('rewardFeature_watermark'));
        expect(
          _texts(tester, watermark),
          contains(
            '${_fixedPrice[locale]} · '
            '${l10n.coinAmount(cost(CoinUnlockTarget.watermark))}',
          ),
        );
        _expectLocalised(locale, l10n, _texts(tester, find.byType(Scaffold)));

        // 2つ選ぶと、合計の見出しは確定価格の合計の数だけ、その下に注記。
        await tester.tap(toneCurve);
        await tester.tap(watermark);
        await tester.pumpAndSettle();
        final sum =
            cost(CoinUnlockTarget.toneCurve) + cost(CoinUnlockTarget.watermark);
        expect(
          tester.widget<Text>(find.byKey(const Key('rewardTotalCoins'))).data,
          l10n.coinAmount(sum),
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('rewardTotalReferenceNote')))
              .data,
          _fixedPrice[locale],
        );
        _expectLocalised(locale, l10n, _texts(tester, find.byType(Scaffold)));

        // 重複・有効期限の確認の最後の文は、確定価格の合計をその言語で。
        await tester.tap(find.byKey(const Key('rewardOverlapPreviewButton')));
        await tester.pumpAndSettle();
        final dialog = _texts(tester, find.byType(AlertDialog));
        expect(
          dialog.join('\n'),
          contains('${_fixedTotalLead[locale]}${l10n.coinAmount(sum)}'),
        );
        _expectLocalised(locale, l10n, dialog);
        await tester.tap(find.byKey(const Key('rewardOverlapReviewClose')));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });

      testWidgets('交換の確認がその言語の文と数の形（$locale, ${n == 1 ? '利用前' : '利用中'}）', (
        tester,
      ) async {
        final premium = await _pump(
          tester,
          locale,
          _server(
            balance: 60000,
            activeUntil: n == 1
                ? null
                : DateTime.now().add(const Duration(days: 9)),
          ),
        );
        final l10n = lookupAppLocalizations(_localeOf(locale));
        await tester.tap(
          find.byKey(const ValueKey('rewardFeature_fullPremium')),
        );
        await tester.pumpAndSettle();
        await _pickDuration(
          tester,
          const CoinUnlockDuration(1, CoinDurationUnit.month),
        );
        final price = CoinBenefitPriceCatalog.unitCoins(
          CoinUnlockTarget.fullPremium,
          CoinDurationUnit.month,
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('rewardTotalCoins'))).data,
          l10n.coinAmount(price),
        );
        await tester.tap(find.byKey(const Key('rewardRedeemButton')));
        await tester.pumpAndSettle();
        final dialog = _texts(tester, find.byType(AlertDialog));
        expect(dialog.join('\n'), contains(l10n.coinAmount(price)));
        _expectLocalised(locale, l10n, dialog);
        // 確認だけして交換はしない。
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });
    }
  }
}
