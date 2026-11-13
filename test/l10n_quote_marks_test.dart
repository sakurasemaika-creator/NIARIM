// 文の中で名前・項目名を囲む記号を、言語ごとの書き方にそろえる見張り。
//
// 簡体字（zh）は“ ”（入れ子は‘ ’）で囲む（所有者の指定）。「」『』は日本語と
// 繁体字の書き方で、簡体字の画面に出すと日本語の文が混ざったように見える。
// 繁体字（zh_Hant）は「」のまま。英語・スペイン語・フランス語に「」が
// 残っていると、その言語の利用者には意味の分からない記号になる。
// あわせて、中国語の文の途中に半角の , ; ( ) が混ざっていないことも見る
// （全角の，；（）で書く）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

List<String> _offenders(String locale, RegExp pattern) => [
  for (final MapEntry(:key, :value) in _values(locale).entries)
    if (pattern.hasMatch(value)) '$key: $value',
];

void main() {
  final cornerBrackets = RegExp('[「」『』]');

  test('簡体字の文に「」『』が残っていない（“ ”と‘ ’で囲む）', () {
    final offenders = _offenders('zh', cornerBrackets);
    expect(
      offenders,
      isEmpty,
      reason: '簡体字は「」を“ ”へ、『』を‘ ’へ:\n${offenders.join('\n')}',
    );
  });

  test('繁体字は「」のまま（簡体字の“ ”へそろえない）', () {
    expect(_values('zh_Hant').values.where((v) => v.contains('「')), isNotEmpty);
    expect(_offenders('zh_Hant', RegExp('[“”]')), isEmpty);
  });

  test('英語・スペイン語・フランス語に「」『』が残っていない', () {
    final offenders = [
      for (final locale in const ['en', 'es', 'fr'])
        for (final line in _offenders(locale, cornerBrackets)) '$locale $line',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('中国語の文の途中に半角の , ; ( ) が混ざっていない', () {
    // 漢字・全角記号のすぐ前後の半角の , ; と、漢字を囲む半角の ( )。
    // 「宽度(px)」のように英字を囲む括弧は対象外。
    final halfWidth = RegExp(
      r'[\u3000-\u9fff\uff00-\uffef“”‘’][,;]|[,;][\u3400-\u9fff“‘]'
      r'|\([\u3400-\u9fff“‘]|[\u3400-\u9fff”’]\)',
    );
    final offenders = [
      for (final locale in const ['zh', 'zh_Hant'])
        for (final line in _offenders(locale, halfWidth)) '$locale $line',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('簡体字の画面では名前を“ ”で、繁体字では「」で囲んで出す', (tester) async {
    final shown = <String, String>{};
    for (final locale in const [
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Text(
                l10n.confirmDeleteNamedBody('草稿'),
                key: const Key('a'),
              );
            },
          ),
        ),
      );
      await tester.pump();
      shown[locale.toLanguageTag()] = tester
          .widget<Text>(find.byKey(const Key('a')))
          .data!;
    }
    expect(shown['zh'], '要删除“草稿”吗？此操作无法撤销。');
    expect(shown['zh-Hant'], contains('「草稿」'));
  });
}
