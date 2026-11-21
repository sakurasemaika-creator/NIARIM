// 特典交換の「合計」で、確定価格（交換準備中）の注記が見出しの大きな字に
// 混ざらず、注釈の書体（白光明朝）の別の行に出ることを、本物のフォント・
// テーマ・スマホの幅で確かめる。
//
// 以前は合計の見出し（headlineSmall・くらむぼん）へ「110 pièces · Prix
// indicatif (échange pas encore disponible)」と注記までつないでいたため、
// 注記が見出しの書体で描かれ（注釈は白光明朝の決まり）、フランス語の文字
// 2倍では「dis|ponible)」と単語の途中で切れていた。
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
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-reference-note';
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
            'balanceCoins': 120,
            'redemptionEnabled': true,
            'entitlements': <Object>[],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

bool _isWordChar(int rune) => RegExp(
  r'[\p{Script=Latin}\p{Nd}()]',
  unicode: true,
).hasMatch(String.fromCharCode(rune));

/// [paragraph]の中で、文字どうしの間で行が変わる所。語が段落の幅より広い
/// ときは、どう並べても切れるので数えない。
List<String> _breaksInsideWords(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final broken = <String>[];
  double? previousTop;
  for (var i = 0; i < text.length; i++) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final top = boxes.first.top;
    if (previousTop != null &&
        top > previousTop + 1 &&
        _isWordChar(text.codeUnitAt(i - 1)) &&
        _isWordChar(text.codeUnitAt(i))) {
      var start = i - 1;
      while (start > 0 && _isWordChar(text.codeUnitAt(start - 1))) {
        start--;
      }
      var end = i + 1;
      while (end < text.length && _isWordChar(text.codeUnitAt(end))) {
        end++;
      }
      final wordWidth = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          )
          .fold<double>(0, (sum, box) => sum + box.right - box.left);
      if (wordWidth <= paragraph.constraints.maxWidth) {
        broken.add('${text.substring(start, i)}|${text.substring(i, end)}');
      }
    }
    previousTop = top;
  }
  return broken;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'fr': Locale('fr'),
    'es': Locale('es'),
    'en': Locale('en'),
    'ja': Locale('ja'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    for (final scale in [1.0, 1.75, 2.0]) {
      testWidgets('合計の確定価格の注記は見出しと別の行・注釈の書体（$name, 文字$scale倍, 360dp）', (
        tester,
      ) async {
        await loadAppFonts(tester);
        final themes = ThemeService();
        await themes.init();
        addTearDown(themes.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 30000);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final premium = PremiumService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PremiumService>.value(value: premium),
              ChangeNotifierProvider<SettingsService>.value(
                value: SettingsService(),
              ),
              ChangeNotifierProvider<GoogleAuthService>.value(
                value: _SignedIn(),
              ),
              ChangeNotifierProvider<CommunityService>.value(value: _server()),
            ],
            child: MaterialApp(
              locale: locale,
              theme: themes.themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RewardUnlockScreen(),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }

        // サーバーの価格が無い特典（トーンカーブ）を選ぶと、合計は確定価格。
        await tester.tap(find.byKey(const ValueKey('rewardFeature_toneCurve')));
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);
        const hour = CoinUnlockDuration(1, CoinDurationUnit.hour);
        final referenceTotal = CoinBenefitPriceCatalog.cost(
          CoinUnlockTarget.toneCurve,
          hour,
        );
        final total = find.byKey(const Key('rewardTotalCoins'));
        // 見出しの字は合計のコインだけ。
        expect(
          tester.widget<Text>(total).data,
          l10n.coinAmount(referenceTotal),
        );

        // 注記は合計のカードの中の、見出しの下の別の行に、注釈の書体で出る。
        final card = find.ancestor(of: total, matching: find.byType(Card));
        final note = find.descendant(
          of: card,
          matching: find.text(l10n.rewardUnlockFixedPrice),
        );
        expect(note, findsOneWidget, reason: '$name: 合計の下の注記');
        expect(
          tester.getTopLeft(note).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(total).dy - 0.001),
        );
        final noteStyle =
            (tester.renderObject(
                      find.descendant(
                        of: note,
                        matching: find.byType(RichText),
                      ),
                    )
                    as RenderParagraph)
                .text
                .style!;
        expect(noteStyle.fontFamily, 'HakkouMincho', reason: '$name: 注記の書体');
        final headlineStyle =
            (tester.renderObject(
                      find.descendant(
                        of: total,
                        matching: find.byType(RichText),
                      ),
                    )
                    as RenderParagraph)
                .text
                .style!;
        expect(headlineStyle.fontFamily, 'Kuramubon', reason: '$name: 合計の書体');

        // 合計のカードの文はどれも単語の途中で切れない。
        final broken = <String>[];
        for (final element
            in find
                .descendant(of: card, matching: find.byType(RichText))
                .evaluate()) {
          broken.addAll(
            _breaksInsideWords(element.renderObject! as RenderParagraph),
          );
        }
        expect(broken, isEmpty, reason: '$name ×$scale: $broken');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });
    }
  }
}
