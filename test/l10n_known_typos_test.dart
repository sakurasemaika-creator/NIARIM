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
      titles[language] = tester.widget<Text>(find.byType(Text)).data!;
    }
    expect(titles['ko'], contains('볼'));
    expect(titles['zh'], contains('脸颊的红晕'));
    expect(titles['zh_Hant'], contains('臉頰的紅暈'));
  });
}
