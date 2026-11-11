// 特典交換の画面（価格の行・合計・重複と有効期限の確認・交換の確認）で、
// 数と単位（「55000コイン」「550000코인」「1か月」）が行の途中で切れず、
// 特典の名前が単語の途中で折り返さないことを、本物のフォント・テーマ・
// スマホの幅（360dp）・文字の大きさ1倍〜2倍で確かめる。
//
// 日本語・中国語・韓国語は字と字の間のどこでも行を変えてよいので、数と単位を
// 空白なしでつなぐ書き方（「70コイン」「50金幣」「550000코인」）にしてから、
// 文字2倍で「…・70コ」「イン」、合計の見出しが「55000コイ」「ン」、
// 韓国語の交換の確認（文字1倍）が「55000코」「인」と単位の途中で切れていた。
//
// 特典の名前は先頭のチェックボックスの右の232pxに押し込まれていて、
// フランス語の文字2倍で「Actions automatiques personnalisée|s」と
// 単語の途中で切れていた（交換の準備中の行は右端の鍵のアイコンの分さらに
// 狭く、「Publication|s : 1 à 3 par jour」）。
//
// 特典の名前の中の数と単位・数の範囲（「1作品」「1개」「1篇」「2 heures」
// 「1 à 3」）も、文字2倍で「作品広場の投稿枠（1日1作|品→3作品）」
// 「작품 광장 하루 1|개→3개 게시」「Jusqu'à 2|heures」
// 「Publications : 1|à 3 par jour」と途中で切れていた。
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
import 'package:niarim/utils/coin_duration_label.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-exchange-line-break';
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

/// 残高60000コインで、全機能1か月を確定価格どおりの見積もりで交換できる
/// サーバー。
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

/// 360dpの画面で、特典の行の文が使える幅（一覧の余白32と、行の始めと
/// 終わりの余白16・24を除いた幅）から、交換の準備中の行の右端の鍵の
/// アイコンと間（40）を除いた幅。これより広い語は、どう並べてもどこかで
/// 切れるので数えない。
const _widestPlaceableWord = 360.0 - 32 - 16 - 24 - 40;

bool _isLatinWordChar(int rune) => RegExp(
  r'[\p{Script=Latin}\p{Nd}]',
  unicode: true,
).hasMatch(String.fromCharCode(rune));

/// 文の中の、空白や句読点で区切られたかたまり（U+FFFCは埋め込んだ部品）。
final _token = RegExp(r'[^\s·・：:（）()、。，,.!?！？/\-+\uFFFC]+');

/// 特典の名前の中の数と単位・数の範囲（言語ごと）。空白は改行しない空白
/// （U+00A0）でもよい。
const _titleCountPhrases = <String, List<String>>{
  'ja': ['1作品', '3作品', '2時間'],
  'ko': ['1개', '3개', '2시간'],
  'zh': ['1篇', '3篇', '2小时'],
  'zh_Hant': ['1篇', '3篇', '2小時'],
  'fr': ['1 à 3', '2 heures'],
  'es': ['1 a 3', '2 horas'],
  'en': ['1 to 3', '2-hour'],
};

/// [phrase]を、空白が普通の空白でも改行しない空白でも見つける形にする。
RegExp _phrasePattern(String phrase) =>
    RegExp(phrase.split(' ').map(RegExp.escape).join(r'[ \u00a0]'));

/// 数のあとに[units]のどれかが続くかたまり（「55000コイン」「550000코인」）と、
/// [phrases]（期間の「1か月」等）が、途中で行を変えている所。
///
/// 日付（「2026년 11월 10일」）は見ない（確かめたいのはコインの数と単位と
/// 期間。日付は実行した日で変わる）。
List<String> _numberUnitBreaks(
  RenderParagraph paragraph,
  Set<String> units,
  Iterable<String> phrases,
) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final broken = <String>[];
  final spans = <(int, int)>[
    for (final match in _token.allMatches(text))
      if (RegExp(r'^\d[\d,]*(.+)$').firstMatch(match.group(0)!) case final unit?
          when units.contains(unit.group(1)))
        (match.start, match.end),
    for (final phrase in phrases)
      for (final match in _phrasePattern(phrase).allMatches(text))
        (match.start, match.end),
  ];
  for (final (start, end) in spans) {
    double? previousTop;
    for (var i = start; i < end; i++) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      final top = boxes.first.top;
      if (previousTop != null && top > previousTop + 1) {
        broken.add(
          '${text.substring(start, i)}|${text.substring(i, end)}'
          '  «${text.replaceAll('\n', ' / ')}»',
        );
      }
      previousTop = top;
    }
  }
  return broken;
}

/// [paragraph]の中で、ラテン文字・数字どうしの間で行が変わる所（語が
/// [_widestPlaceableWord]より広いときは数えない）。
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
        _isLatinWordChar(text.codeUnitAt(i - 1)) &&
        _isLatinWordChar(text.codeUnitAt(i))) {
      var start = i - 1;
      while (start > 0 && _isLatinWordChar(text.codeUnitAt(start - 1))) {
        start--;
      }
      var end = i + 1;
      while (end < text.length && _isLatinWordChar(text.codeUnitAt(end))) {
        end++;
      }
      final wordWidth = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          )
          .fold<double>(0, (sum, box) => sum + box.right - box.left);
      if (wordWidth <= _widestPlaceableWord) {
        broken.add(
          '${text.substring(start, i)}|${text.substring(i, end)} '
          '(${wordWidth.toStringAsFixed(0)}px, '
          '欄${paragraph.size.width.toStringAsFixed(0)}px)  «$text»',
        );
      }
    }
    previousTop = top;
  }
  return broken;
}

Iterable<RenderParagraph> _paragraphs(Finder within) sync* {
  for (final element
      in find
          .descendant(of: within, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is RenderParagraph && paragraph.attached) yield paragraph;
  }
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
  // 同梱フォントはファイルで1回だけ読む（テストごとに読むと、テストの数だけ
  // フォントが積み上がってメモリが足りなくなり、テストの途中で落ちた）。
  var fontsLoaded = false;
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'ja': Locale('ja'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    'fr': Locale('fr'),
    'es': Locale('es'),
    'en': Locale('en'),
  };

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    for (final scale in [1.0, 1.75, 2.0]) {
      testWidgets('数と単位が途中で切れず、特典の名前が単語の途中で折り返さない'
          '（$name, 文字$scale倍, 360dp）', (tester) async {
        if (!fontsLoaded) {
          await loadAppFonts(tester);
          fontsLoaded = true;
        }
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
        final l10n = lookupAppLocalizations(locale);
        final problems = <String>[];
        var amountsSeen = 0;
        // その言語のコインの単位（「コイン」「코인」「金币」「coins」）と、
        // 選ぶ期間（全機能1か月・12か月）。
        final coinUnits = {
          for (final n in [1, 2])
            l10n.coinAmount(n).replaceAll(RegExp(r'[\d\s]'), ''),
        };
        final titlePhrases = _titleCountPhrases[name]!;
        final titlePhrasesSeen = {for (final phrase in titlePhrases) phrase: 0};
        final periods = [
          for (final amount in [1, 12])
            coinUnlockDurationLabel(
              l10n,
              CoinUnlockDuration(amount, CoinDurationUnit.month),
            ),
          ...titlePhrases,
        ];

        void scan(String where, Finder within, {bool rows = false}) {
          for (final paragraph in _paragraphs(within)) {
            final text = paragraph.text.toPlainText(
              includeSemanticsLabels: false,
            );
            if (RegExp(r'\d').hasMatch(text)) amountsSeen++;
            for (final phrase in titlePhrases) {
              titlePhrasesSeen[phrase] =
                  titlePhrasesSeen[phrase]! +
                  _phrasePattern(phrase).allMatches(text).length;
            }
            for (final broken in _numberUnitBreaks(
              paragraph,
              coinUnits,
              periods,
            )) {
              problems.add('$where: 数と単位の途中 $broken');
            }
          }
          if (!rows) return;
          for (final element
              in find
                  .byWidgetPredicate(
                    (widget) =>
                        widget.key is ValueKey<String> &&
                        (widget.key! as ValueKey<String>).value.startsWith(
                          'rewardFeature_',
                        ),
                  )
                  .evaluate()) {
            final row = find.byElementPredicate((e) => e == element);
            for (final paragraph in _paragraphs(row)) {
              for (final broken in _breaksInsideWords(paragraph)) {
                problems.add('$where: 単語の途中 $broken');
              }
            }
          }
        }

        Future<void> scanReview(String where) async {
          await tester.tap(find.byKey(const Key('rewardOverlapPreviewButton')));
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget, reason: '$where: 確認');
          scan('$where・重複と有効期限の確認', dialog);
          await tester.tap(find.byKey(const Key('rewardOverlapReviewClose')));
          await tester.pumpAndSettle();
        }

        // 1時間：交換の準備ができていない特典は確定価格の行。2つ選ぶと
        // 合計は確定価格の合計。
        scan('1時間の一覧', find.byType(Scaffold), rows: true);
        for (final target in ['toneCurve', 'customAutomation']) {
          await tester.tap(find.byKey(ValueKey('rewardFeature_$target')));
        }
        await tester.pumpAndSettle();
        scan('1時間の合計', find.byType(Scaffold));
        await scanReview('1時間');
        for (final target in ['toneCurve', 'customAutomation']) {
          await tester.tap(find.byKey(ValueKey('rewardFeature_$target')));
        }
        await tester.pumpAndSettle();

        // 全機能1か月：サーバーの見積もりどおりの合計と、交換の確認。
        await tester.tap(
          find.byKey(const ValueKey('rewardFeature_fullPremium')),
        );
        await tester.pumpAndSettle();
        await _pickDuration(
          tester,
          const CoinUnlockDuration(1, CoinDurationUnit.month),
        );
        final month = CoinBenefitPriceCatalog.unitCoins(
          CoinUnlockTarget.fullPremium,
          CoinDurationUnit.month,
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('rewardTotalCoins'))).data,
          l10n.coinAmount(month),
        );
        scan('1か月の一覧と合計', find.byType(Scaffold), rows: true);
        await tester.tap(find.byKey(const Key('rewardRedeemButton')));
        await tester.pumpAndSettle();
        final confirm = find.byType(AlertDialog);
        expect(confirm, findsOneWidget, reason: '$name: 交換の確認');
        scan('交換の確認', confirm);
        await tester.tap(
          find.descendant(of: confirm, matching: find.byType(TextButton)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // 全機能12か月：年額の確定価格の合計。
        await _pickDuration(
          tester,
          const CoinUnlockDuration(12, CoinDurationUnit.month),
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('rewardTotalCoins'))).data,
          l10n.coinAmount(
            CoinBenefitPriceCatalog.cost(
              CoinUnlockTarget.fullPremium,
              const CoinUnlockDuration(12, CoinDurationUnit.month),
            ),
          ),
        );
        scan('12か月の一覧と合計', find.byType(Scaffold), rows: true);
        await scanReview('12か月');

        // 何も見ていなければ確かめたことにならない。
        expect(amountsSeen, greaterThan(20), reason: '$name: 数と単位の文');
        for (final phrase in titlePhrases) {
          expect(
            titlePhrasesSeen[phrase],
            greaterThan(0),
            reason: '$name: 特典の名前の「$phrase」が出ていない',
          );
        }
        expect(
          problems,
          isEmpty,
          reason: '$name ×$scale:\n${problems.join('\n')}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });
    }
  }
}
