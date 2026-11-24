// 訳の中の誤字・文字化け・訳し忘れの見張り（実際に見つかったもの）。
//
// 頬の赤みの活用Tipsが韓国語・簡体字・繁体字で文字化けしていた（「봼기」
// 「脸颇的红晖」「臉頸的紅晖」「皮膩」）。韓国語の画像の読み込みの失敗の文に
// 誤字（「없업니다」「샜도해」）、簡体字に繁体字（「慣用手」）、繁体字に英語
// （「furigana」）、韓国語・中国語に英語の内部の言葉（「EndCard」「Pixel Art」
// 「Vector」）、韓国語・中国語に日本語の波ダッシュ（〜）が残っていた。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_locale.dart';

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

/// 言語 → その言語の文に出てはいけない文字列。
const _forbidden = <String, List<String>>{
  'ko': ['봼', '봉색', '없업', '샜도', 'EndCard', 'Pixel Art', 'Vector', '〜'],
  'zh': ['脸颇', '红晖', '慣', 'EndCard', 'Pixel Art', 'Vector', '〜'],
  'zh_Hant': [
    '臉頸',
    '紅晖',
    '皮膩',
    'furigana',
    'EndCard',
    'Pixel Art',
    'Vector',
    '〜',
  ],
  'ja': ['Pixel Art', 'Vector'],
  'es': ['EndCard'],
  'fr': ['EndCard'],
};

const _endMarkTerms = {
  'en': ('end mark', ['end card', 'end logo']),
  'es': ('marca final', ['tarjeta final', 'logo final', 'logotipo de cierre']),
  'fr': ('marque de fin', ['carte de fin', 'logo final', 'logo de fin']),
  'ja': ('エンドマーク', ['エンドカード', 'エンドロゴ']),
  'ko': ('엔드마크', ['엔드카드', '엔드 카드', '엔드 마크', '엔드 로고']),
  'zh': ('片尾标记', ['片尾卡', '片尾标志']),
  'zh_Hant': ('片尾標記', ['片尾卡', '片尾標誌']),
};

const _endMarkLabels = [
  'premiumHeroHighlightWatermark',
  'premiumFeatureEndLogo',
  'premiumBannerEndCardBody',
  'helpEndCardTitle',
  'helpEndCardDesc',
  'tipsEndCardWatermarkTitle',
  'tipsEndCardWatermarkDesc',
  'timelineEndCardTrackLabel',
  'timelineHideEndCard',
  'timelineShowEndCard',
  'exportOutputWithEndCard',
  'exportOutputWithoutEndCard',
  'workspaceEndCardSection',
  'workspaceEndCardHint',
  'workspaceEndCardDefaultHiddenTitle',
  'rewardUnlockEndCardEdit',
  'licenseTermsArt4Body',
];

void main() {
  test('訳に、見つかった誤字・文字化け・訳し忘れが残っていない', () {
    final offenders = [
      for (final MapEntry(key: locale, value: words) in _forbidden.entries)
        for (final MapEntry(:key, :value) in _values(locale).entries)
          for (final word in words)
            if (value.contains(word)) '$locale $key: 「$word」',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  for (final MapEntry(key: locale, value: (term, oldTerms))
      in _endMarkTerms.entries) {
    test('DISC402・DISC523: $locale のエンドマークの呼び名がそろっている', () {
      final values = _values(locale);
      for (final key in _endMarkLabels) {
        final value = values[key]?.toLowerCase();
        expect(value, contains(term), reason: '$locale $key');
        for (final oldTerm in oldTerms) {
          expect(value, isNot(contains(oldTerm)), reason: '$locale $key');
        }
      }
    });
  }

  testWidgets('頬の赤みの活用Tipsの見出しが各言語で読める', (tester) async {
    final titles = <String, String>{};
    for (final language in const ['ko', 'zh', 'zh_Hant']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: localeFromLanguageCode(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) =>
                Text(AppLocalizations.of(context)!.tipsBlushAutofillTitle),
          ),
        ),
      );
      titles[language] = tester.widget<Text>(find.bySubtype<Text>()).data!;
    }
    expect(titles['ko'], contains('볼'));
    expect(titles['zh'], contains('脸颊的红晕'));
    expect(titles['zh_Hant'], contains('臉頰的紅暈'));
  });
}
