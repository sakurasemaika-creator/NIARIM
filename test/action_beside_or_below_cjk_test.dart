// 文と操作を並べる部品（ActionBesideOrBelow）が、中国語・日本語の文を
// 「語の途中で折れる」と取り違えて操作を下へ回さないことを見張る。
//
// 中国語・日本語は字の間で折り返してよい。ところがFlutter（SkParagraph）は、
// 文が1つの書体で描けて途中に空白が無いと、字の間の折り返しを最小の固有幅に
// 入れず、文全体の幅を返す（中国語の本文の書体〔Noto Serif SC〕の文で起きる）。
// 部品はその幅を「いちばん広い語」と読み、折り返すだけで語は折れない中国語の
// 文でも操作を文の下へ回していた（品質の設定の4つの選択肢で、中国語だけ丸が
// 名前の上に出た）。語が本当に入らない欧文は、今までどおり下へ回す。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/action_beside_or_below.dart';

import 'helpers/load_app_fonts.dart';

/// 幅[width]で[text]と48pxの操作を並べたとき、操作を文の横に置いたか。
Future<bool> _beside(
  WidgetTester tester,
  Locale locale,
  Widget text, {
  double width = 304,
  double minTextFraction = 0,
  bool actionFirst = true,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeService().themeDataFor(locale),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ActionBesideOrBelow(
              key: key,
              actionFirst: actionFirst,
              minTextFraction: minTextFraction,
              gap: 8,
              spacing: 0,
              text: text,
              action: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    ),
  );
  final box = tester.renderObject<RenderBox>(find.byKey(key));
  // 横に並べたら高さは文と操作の高い方、下に回したら文と操作の和。
  final text0 = tester.getSize(
    find.descendant(of: find.byKey(key), matching: find.byWidget(text)),
  );
  return box.size.height < text0.height + 48 - 0.5;
}

void main() {
  testWidgets('中国語・日本語の文は、折り返すだけなら操作を横に置く', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    for (final locale in const [
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('ja'),
    ]) {
      final l = lookupAppLocalizations(locale);
      // 品質の設定の選択肢（名前と説明）と同じ組み立て。
      for (final (name, desc) in [
        (l.perfSettingsQualityLow, l.perfSettingsQualityDescLow),
        (l.perfSettingsQualityHigh, l.perfSettingsQualityDescHigh),
      ]) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name),
            Text(desc, style: const TextStyle(fontSize: 12)),
          ],
        );
        if (!await _beside(tester, locale, text)) {
          problems.add('${locale.toLanguageTag()}: «$desc» の行で操作が下へ回った');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('中国語の文でも、割合の下限（既定0.55）より狭くなるなら下へ回す', (tester) async {
    await loadAppFonts(tester);
    final l = lookupAppLocalizations(const Locale('zh'));
    // 幅120では文に残る幅（64px）が全体の0.55より狭い。
    expect(
      await _beside(
        tester,
        const Locale('zh'),
        Text(l.perfSettingsQualityDescLow),
        width: 120,
        minTextFraction: 0.55,
      ),
      isFalse,
    );
  });

  testWidgets('入らない語がある欧文は、今までどおり操作を下へ回す', (tester) async {
    await loadAppFonts(tester);
    // 幅180で文に残る124pxより広い1語。
    expect(
      await _beside(
        tester,
        const Locale('fr'),
        const Text(
          'Anticonstitutionnellement réglés',
          style: TextStyle(fontSize: 16),
        ),
        width: 180,
      ),
      isFalse,
    );
    // 語がどれも入るなら横に置く。
    expect(
      await _beside(
        tester,
        const Locale('fr'),
        const Text(
          'Pour un appareil courant de chaque côté',
          style: TextStyle(fontSize: 12),
        ),
        width: 180,
      ),
      isTrue,
    );
  });
}
