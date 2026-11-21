// 自動塗りのプリセットのパーツの数を、言語の複数形の決まり（CLDR）で書く
// ことを見張る（DISC131）。
//
// 以前は「{count} parts」「{count} parties」のように数によらず同じ形で、
// 1つでも「1 parts」「1 parties」と出ていた。仏語は0と1が単数（CLDR）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/widgets/autofill_preset_selection_sheet.dart';

/// 言語ごとの期待（数 → 文）。
const _expected = <String, Map<int, String>>{
  'ja': {0: '0パーツ', 1: '1パーツ', 2: '2パーツ', 5: '5パーツ'},
  'en': {0: '0 parts', 1: '1 part', 2: '2 parts', 5: '5 parts'},
  'es': {0: '0 partes', 1: '1 parte', 2: '2 partes', 5: '5 partes'},
  'fr': {0: '0 partie', 1: '1 partie', 2: '2 parties', 5: '5 parties'},
  'ko': {0: '0개 부위', 1: '1개 부위', 2: '2개 부위', 5: '5개 부위'},
  'zh': {0: '0个部件', 1: '1个部件', 2: '2个部件', 5: '5个部件'},
  'zh_Hant': {0: '0個部件', 1: '1個部件', 2: '2個部件', 5: '5個部件'},
};

Locale _locale(String tag) => tag == 'zh_Hant'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
    : Locale(tag);

void main() {
  test('パーツの数は7言語とも、その言語の単数・複数で書く（仏語は0と1が単数）', () {
    final problems = <String>[];
    for (final MapEntry(key: tag, value: cases) in _expected.entries) {
      final l = lookupAppLocalizations(_locale(tag));
      for (final MapEntry(key: n, value: text) in cases.entries) {
        for (final (name, actual) in [
          ('autofillPresetPartsCount', l.autofillPresetPartsCount(n)),
          (
            'autofillPresetSelectionPartCount',
            l.autofillPresetSelectionPartCount(n),
          ),
        ]) {
          if (actual != text) problems.add('$tag $name($n): 「$actual」≠「$text」');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('自動塗りのプリセットを選ぶ画面で、パーツ1つのプリセットは単数で出る', (tester) async {
    for (final tag in const ['en', 'es', 'fr']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: _locale(tag),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAutofillPresetSelectionSheet(
                  context,
                  allPresets: [
                    AutofillPreset(
                      id: 'one',
                      name: 'One',
                      parts: [
                        const AutofillPart(
                          id: 'p',
                          name: 'P',
                          color: 0xFF000000,
                        ),
                      ],
                    ),
                  ],
                  initiallyEnabledIds: null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(_expected[tag]![1]!), findsOneWidget, reason: tag);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
