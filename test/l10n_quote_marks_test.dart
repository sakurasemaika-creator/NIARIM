// 文の中で名前・項目名を囲む記号を、言語ごとの書き方にそろえる見張り。
//
// 簡体字（zh）は“ ”（入れ子は‘ ’）で囲む（所有者の指定）。「」『』は日本語と
// 繁体字の書き方で、簡体字の画面に出すと日本語の文が混ざったように見える。
// 繁体字（zh_Hant）は「」のまま。英語・スペイン語・フランス語に「」が
// 残っていると、その言語の利用者には意味の分からない記号になる。
// あわせて、中国語の文の途中に半角の , ; ( ) が混ざっていないことも見る
// （全角の，；（）で書く）。1つの言語の中で囲みの記号を混ぜないこと
// （英語は“ ”、スペイン語・フランス語は« »、韓国語・日本語・繁体字は「」）と、
// ARBの文に逆斜線が文字のまま残っていないこと（英語・韓国語のパレットの
// 説明に \"追加\"、全言語の基本操作のヘルプに \n がそのまま出ていた）も見る。
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

  test('1つの言語の中では、名前・項目名をいつも同じ記号で囲む', () {
    // 言語 → その言語で使わない囲みの記号（使うのは右の説明の記号だけ）。
    // 韓国語はARBの大半（90件）にそろえて「」（‘ ’・" "・“ ”が混ざって
    // いた）。英語は“ ”（" "が混ざっていた）、スペイン語・フランス語は« »。
    const notUsed = <String, String>{
      'ja': '"“”‘«»', // 「」『』
      'en': '"«»「」『』', // “ ” ‘ ’
      'es': '"“”‘「」『』', // « »
      'fr': '"“”‘「」『』', // « »
      'ko': '"“”‘«»', // 「」『』
      'zh': '"«»「」『』', // “ ” ‘ ’
      'zh_Hant': '"“”‘«»', // 「」『』
    };
    final offenders = <String>[];
    for (final MapEntry(key: locale, value: marks) in notUsed.entries) {
      for (final MapEntry(:key, :value) in _values(locale).entries) {
        final found = {
          for (final c in marks.split(''))
            if (value.contains(c)) c,
        };
        if (found.isNotEmpty) {
          offenders.add('$locale $key ${found.join()}: $value');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('ARBの文に逆斜線が文字として残っていない（\\" や \\n がそのまま出る）', () {
    final offenders = [
      for (final locale in const [
        'ja',
        'en',
        'es',
        'fr',
        'ko',
        'zh',
        'zh_Hant',
      ])
        for (final MapEntry(:key, :value) in _values(locale).entries)
          if (value.contains(r'\')) '$locale $key',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('パレットの空の説明と基本操作のヘルプに逆斜線が出ない', (tester) async {
    final shown = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Text(l10n.pixelArtPalettePickerEmpty, key: const Key('p')),
                    Text(l10n.helpBasicGestureDesc, key: const Key('h')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      for (final key in const ['p', 'h']) {
        final text = tester.widget<Text>(find.byKey(Key(key))).data!;
        if (text.contains(r'\')) {
          shown.add('${locale.toLanguageTag()} $key: $text');
        }
      }
    }
    expect(shown, isEmpty, reason: shown.join('\n'));
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
