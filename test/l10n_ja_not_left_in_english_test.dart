// 日本語のARB（テンプレート）に、英語のまま残った文が無いことの見張り。
//
// 取り消し・やり直しのボタンの説明（commonUndo・commonRedo）が日本語でも
// 「Undo」「Redo」と出ていた（DISC089）。アプリの他の所は「取り消し」
// 「やり直し」と書いている。英語と同じでよいのは、固有名詞・単位・形式名・
// 言語の自称だけ（下の許可リスト、理由つき）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

/// 日本語でも英語と同じ綴りでよいもの（キー → 理由）。
const _sameAsEnglish = {
  'settingsLanguageEnglish': '言語の自称',
  'settingsLanguageFrench': '言語の自称',
  'settingsLanguageSpanish': '言語の自称',
  'commonOk': '日本語のUIでも「OK」と書く',
  'exportFpsLabel': '単位（fps）',
  'pcStatusFps': '単位（fps）',
  'exportFormatMp4': 'ファイル形式の名前',
  'exportFormatGif': 'ファイル形式の名前',
  'exportFormatAvi': 'ファイル形式の名前',
  'penSubToolBrushSizeOpacity': '単位（px・%）だけ',
  'brushSettingsFadeOff': '日本語のUIでも「OFF」と書く',
  'commonOff': '日本語のUIでも「OFF」と書く',
  'storageCategoryNiarimTotal': 'アプリ名',
};

Map<String, String> _values(String locale) {
  final data =
      json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in data.entries)
      if (!key.startsWith('@') && value is String) key: value,
  };
}

void main() {
  test('日本語のARBに英語のまま残った文が無い', () {
    final ja = _values('ja');
    final en = _values('en');
    final latinWord = RegExp('[A-Za-z]{2,}');
    final offenders = [
      for (final MapEntry(:key, :value) in ja.entries)
        if (value == en[key] &&
            latinWord.hasMatch(value.replaceAll(RegExp(r'\{[^}]*\}'), '')) &&
            !_sameAsEnglish.containsKey(key))
          '$key: $value',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('許可リストのキーは今も英語と同じ（違えば外す）', () {
    final ja = _values('ja');
    final en = _values('en');
    for (final key in _sameAsEnglish.keys) {
      expect(ja[key], en[key], reason: '$key は英語と違うので許可リストから外す');
    }
  });

  testWidgets('日本語の画面では取り消し・やり直しのボタンを日本語で説明する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: l10n.commonUndo,
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: l10n.commonRedo,
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
    expect(find.byTooltip('取り消し'), findsOneWidget);
    expect(find.byTooltip('やり直し'), findsOneWidget);
  });
}
