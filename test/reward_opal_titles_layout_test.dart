// オパール（報酬の通貨）の画面の見出し・ボタンが、狭いスマホ（320dp）と
// 大きな文字（2倍）でも切れず、単語の途中で折り返さないことを、本物の
// フォント・テーマ・画面で確かめる。
//
// - 「オパール・特典」の画面名（戻るボタンのある画面バー）が、スペイン語
//   「Ópalos y recompensas」・フランス語「Opales et avantages」で入らず
//   「Ópalos y recom…」と省略され、はみ出した分を切る処理で大文字の Ó の
//   アクセントまで切れて「Opalos」に見えていた。
// - 契約状態のカードの見出し（オパールで解放中）が、スペイン語の
//   「Desbloqueado」で「Desbloqu / eado」と単語の途中で折り返していた。
// - 特典交換の「このオパール数を目標にする」が、韓国語「이 오팔 수를 목표로
//   설정」で「목표 / 로」と語の途中で折り返していた。
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
import 'package:niarim/screens/rewards/coin_benefits_screen.dart';
import 'package:niarim/screens/rewards/membership_benefits_screen.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-opal-titles';
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

/// オパールで全機能を交換して利用中（Google Playの会員ではない）。
class _OpalMember extends PremiumService {
  _OpalMember(this.until);
  final DateTime until;
  @override
  bool get hasVerifiedPlayPremium => false;
  @override
  bool get hasCoinPremium => true;
  @override
  DateTime? get activeCoinPremiumExpiry => until;
  @override
  void applyServerCoinPremiumExpiry(DateTime? expiresAt, {String? accountId}) {}
}

http.Response _json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 残高60000オパールで交換ができるサーバー。
CommunityService _server() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.method != 'GET') return _json({'redeemed': false});
        return _json(switch (request.url.path) {
          '/me/rewards' => {
            'balanceCoins': 60000,
            'redemptionEnabled': true,
            'entitlements': <Object>[],
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

const _locales = <String, Locale>{
  'ja': Locale('ja'),
  'en': Locale('en'),
  'es': Locale('es'),
  'fr': Locale('fr'),
  'ko': Locale('ko'),
  'zh': Locale('zh'),
  'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
};

/// 空白で区切られた語の中の字（ラテン文字・ハングル）。日本語・中国語は
/// 字と字の間のどこで行を変えてもよいので数えない。
final _wordChar = RegExp(r'[\p{Script=Latin}\p{Script=Hangul}]', unicode: true);

/// [lines]の中で、語の途中で行が変わる所。
List<String> _breaksInsideWords(ParagraphLines lines) {
  final text = lines.visible;
  return [
    for (final i in lines.breaksWithin(0, text.length))
      if (i > 0 &&
          _wordChar.hasMatch(text[i - 1]) &&
          _wordChar.hasMatch(text[i]))
        '${text.substring(0, i)}|${text.substring(i)}  '
            '«${lines.lines.join(' / ')}»',
  ];
}

RenderParagraph _paragraphOf(WidgetTester tester, Finder within, String text) {
  final matches = [
    for (final element
        in find
            .descendant(of: within, matching: find.byType(RichText))
            .evaluate())
      if (element.renderObject case final RenderParagraph paragraph
          when paragraph.text.toPlainText(includeSemanticsLabels: false) ==
              text)
        paragraph,
  ];
  expect(matches, hasLength(1), reason: '「$text」が1つだけ出ていない');
  return matches.single;
}

void main() {
  var fontsLoaded = false;
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  Future<ThemeService> prepare(WidgetTester tester, Size size) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    return themes;
  }

  Widget app(
    ThemeService themes,
    Locale locale,
    Widget home, {
    PremiumService? premium,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<PremiumService>.value(
        value: premium ?? PremiumService(),
      ),
      ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
      ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
      ChangeNotifierProvider<CommunityService>.value(value: _server()),
      ChangeNotifierProvider<ProjectService>.value(value: ProjectService()),
    ],
    child: MaterialApp(
      locale: locale,
      theme: themes.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: locale) in _locales.entries) {
    final l10n = lookupAppLocalizations(locale);

    for (final width in const [320.0, 360.0]) {
      testWidgets('「オパール・特典」の画面名が戻るボタンの横に省略されずに入る'
          '（$name, ${width.toInt()}dp, 文字2倍）', (tester) async {
        final themes = await prepare(tester, Size(width, 1600));
        await tester.pumpWidget(
          app(themes, locale, const Scaffold(body: SizedBox.expand())),
        );
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const CoinBenefitsScreen(),
              ),
            );
        await settle(tester);
        final title = _paragraphOf(
          tester,
          find.byType(AppBar).last,
          l10n.rewardNavigationHub,
        );
        // 入らない文は省略され、はみ出した分を切る処理でアクセント
        // （Ó の上の印）まで切れる。
        expect(
          title.didExceedMaxLines,
          isFalse,
          reason: '$name: 「${l10n.rewardNavigationHub}」が省略された',
        );
        final full = title.getMaxIntrinsicWidth(double.infinity);
        expect(
          full,
          lessThanOrEqualTo(title.size.width + 0.5),
          reason:
              '$name: 「${l10n.rewardNavigationHub}」'
              '${full.toStringAsFixed(1)}px が欄 '
              '${title.size.width.toStringAsFixed(1)}px に入らない',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('契約状態のカードの見出し（オパールで解放中）が語の途中で折り返さない'
        '（$name, 320dp, 文字2倍）', (tester) async {
      final themes = await prepare(tester, const Size(320, 2000));
      final premium = _OpalMember(DateTime(DateTime.now().year + 1, 4, 5, 9));
      addTearDown(premium.dispose);
      await tester.pumpWidget(
        app(themes, locale, const MembershipBenefitsScreen(), premium: premium),
      );
      await settle(tester);
      final heading = _paragraphOf(
        tester,
        find.byType(Card).first,
        l10n.rewardNavigationMembershipCoin,
      );
      expect(_breaksInsideWords(ParagraphLines(heading)), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('特典交換の「目標にする」「交換する」が語の途中で折り返さない'
        '（$name, 320dp, 文字2倍）', (tester) async {
      final themes = await prepare(tester, const Size(320, 6000));
      await tester.pumpWidget(app(themes, locale, const RewardUnlockScreen()));
      await settle(tester);
      // 特典を選ぶと合計・目標・交換のボタンが出る。
      for (final target in ['allAds', 'canvasAds']) {
        await tester.tap(find.byKey(ValueKey('rewardFeature_$target')));
      }
      await tester.pumpAndSettle();
      final problems = <String>[];
      for (final text in [l10n.rewardUnlockGoal, l10n.rewardUnlockRedeem]) {
        final paragraph = _paragraphOf(tester, find.byType(Scaffold), text);
        problems.addAll(_breaksInsideWords(ParagraphLines(paragraph)));
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
