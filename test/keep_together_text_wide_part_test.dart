// [KeepTogetherText]のかたまりが欄の1行より広いときは、つながずに普通の
// [Text]と同じに折ること（DISC130の実操作）。
//
// 容量削減の画面（日本語・360px・文字2倍）で「未使用素材を一括削除
// （全プロジェクト）」の「（全プロジェクト）」をかたまりにすると、かたまりが
// 行より広いのに次の行へ送られ、そのうえ字の途中で折れて「未使用素材を一 /
// 括削除 / （全プロジェク / ト）」と4行になり、「ト）」だけの行ができた（普通の
// Textは「未使用素材を一 / 括削除（全プロ / ジェクト）」の3行）。
//
// 本物のフォント（見出しのくらむぼん・本文の白光明朝）と文字2倍で、幅を1px
// ずつ変えて調べる：1行に入らないかたまりがあるときは普通のTextと同じ行、
// 入るかたまりは途中で折らない、行の頭・終わりの禁則、欄の外へはみ出さない、
// 文の終わりのかたまりは普通のTextより行を増やさない。あわせて、内側の大きさを
// 尋ねる親（ダイアログのボタンの段・IntrinsicWidth）の中でも、尋ねた大きさと
// 実際に並べた大きさが食い違わないこと（debugCheckIntrinsicSizes）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/keep_together_text.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 数と、そのすぐ後に空白なしで続く単位の字（[KeepTogetherText]が自分で
/// かたまりにするもの）。
final _numberWithUnit = RegExp(
  r'(?<!\d)\d+(?:[.,]\d+)*'
  r'(?:\p{Script=Han}{1,3}|\p{Script=Hiragana}{1,3}'
  r'|[\p{Script=Katakana}ー]{1,3}|\p{Script=Hangul}{1,3})',
  unicode: true,
);

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

void main() {
  var fontsLoaded = false;
  Future<void> fonts(WidgetTester tester) async {
    if (fontsLoaded) return;
    await loadAppFonts(tester);
    fontsLoaded = true;
  }

  // (説明, 言語, 文, かたまり, かたまりが文の終わりにあるか)
  final cases = <(String, Locale, String, List<String>, bool)>[
    for (final locale in const [
      Locale('ja'),
      Locale('en'),
      Locale('es'),
      Locale('fr'),
      Locale('ko'),
      Locale('zh'),
      _zhHant,
    ])
      for (final text in [
        lookupAppLocalizations(locale).storageRemoveUnusedMaterialsButton,
        lookupAppLocalizations(locale).storageEraseAllButton,
      ])
        (
          '容量削減の行',
          locale,
          text,
          [
            for (final m in RegExp(r'[（(][^（）()\s]+[）)]').allMatches(text))
              m.group(0)!,
          ],
          true,
        ),
    ('確定価格', const Locale('ja'), '確定価格（交換準備中） · 55000コイン', ['55000コイン'], true),
    ('読点', const Locale('ja'), '累計30日、達成しました。', const <String>[], false),
  ];

  const families = <String, (String, List<String>)>{
    '見出し（くらむぼん）': ('Kuramubon', kHeadingFontFallback),
    '本文（白光明朝）': ('HakkouMincho', kBodyFontFallback),
  };

  for (final (what, locale, text, keep, atEnd) in cases) {
    for (final MapEntry(key: fontName, value: (family, fallback))
        in families.entries) {
      testWidgets('1行に入らないかたまりはつながない（$what「$text」, '
          '${locale.toLanguageTag()}, $fontName, 文字2倍）', (tester) async {
        await fonts(tester);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1300, 60000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final style = TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallback,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        );
        const scaler = TextScaler.linear(2);
        final widths = [for (var w = 40; w <= 420; w += 2) w];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: scaler),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final w in widths) ...[
                        SizedBox(
                          key: ValueKey('keep$w'),
                          width: w.toDouble(),
                          child: KeepTogetherText(
                            text,
                            keep: keep,
                            style: style,
                          ),
                        ),
                        SizedBox(
                          key: ValueKey('plain$w'),
                          width: w.toDouble(),
                          child: Text(text, style: style),
                        ),
                      ],
                      SizedBox(
                        key: const ValueKey('keepWide'),
                        width: 1300,
                        child: KeepTogetherText(text, keep: keep, style: style),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        RenderParagraph paragraphIn(String key) =>
            tester.renderObject<RenderParagraph>(
              find
                  .descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(RichText),
                  )
                  .first,
            );

        // かたまり（[keep]と、数と単位）を、前後の離せない字（前の開き括弧・
        // 数の前の通貨の記号や符号、後ろの閉じ括弧・読点）と合わせて1行に
        // 並べたときの幅（かたまりとして描いた幅。字と字の間の詰め〔カーニング〕
        // が切れる分だけ、普通の文より少し広いことがある）。
        final parts = <String>{
          ...keep,
          for (final m in _numberWithUnit.allMatches(text)) m.group(0)!,
        };
        final wideLines = ParagraphLines(paragraphIn('keepWide'));
        expect(wideLines.lines, hasLength(1));
        final wideText = wideLines.visible.replaceAll(' ', ' ');
        final prefix = RegExp(
          '[\$+\\\\\u00a3\u00a4\u00a5\u00b1\u2116\u2212\u2213'
          '\u20a0-\u20cf\ufe69\uff04\uffe1\uffe5\uffe6]',
        );
        final partWidth = <String, double>{};
        for (final part in parts) {
          var start = wideText.indexOf(part);
          var end = start + part.length;
          while (start > 0 &&
              (lineEndForbidden.contains(wideText[start - 1]) ||
                  prefix.hasMatch(wideText[start - 1]))) {
            start--;
          }
          while (end < wideText.length &&
              lineStartForbidden.contains(wideText[end])) {
            end++;
          }
          final boxes = wideLines.paragraph.getBoxesForSelection(
            wideLines.sourceSelection(start, end),
          );
          partWidth[part] = boxes.last.right - boxes.first.left;
        }

        String normalized(ParagraphLines lines) => lines.lines
            .map((l) => l.replaceAll(' ', ' ').replaceAll('​', ''))
            .join('\n');

        final problems = <String>[];
        var tooWide = 0;
        for (final w in widths) {
          final kept = ParagraphLines(paragraphIn('keep$w'));
          final plain = ParagraphLines(paragraphIn('plain$w'));
          String show(ParagraphLines lines) => lines.lines.join(' / ');
          for (final problem in kept.charsOutsideWidth()) {
            problems.add('幅$w: 欄の外 $problem');
          }
          // 閉じ括弧・読点で始まる行、開き括弧で終わる行を作らない（普通の
          // Textでも、入りきらない語の途中で折れると「proyectos / )」となる。
          // 前の1字と送れば避けられる。2字が入らない幅だけは避けられない）。
          final plainEdges = plain.lineEdgeViolations();
          for (final problem in kept.lineEdgeViolations()) {
            if (w >= 80 || plainEdges.isEmpty) {
              problems.add('幅$w: $problem（普通のText ${show(plain)}）');
            }
          }
          final flat = kept.visible.replaceAll(' ', ' ').replaceAll('​', '');
          final wide = [
            for (final part in parts)
              if (partWidth[part]! > w) part,
          ];
          if (wide.isNotEmpty) {
            tooWide++;
            // 1行に入らないかたまりは、つながずに普通のTextと同じに折る。
            if (plainEdges.isEmpty && normalized(kept) != normalized(plain)) {
              problems.add(
                '幅$w: 「${wide.join('・')}」が1行に入らないのに普通のTextと'
                '違う: ${show(kept)}（普通のText ${show(plain)}）',
              );
            }
            continue;
          }
          for (final part in parts) {
            final at = flat.indexOf(part);
            if (at >= 0 && kept.breaksWithin(at, at + part.length).isNotEmpty) {
              problems.add('幅$w: 「$part」の途中で行が変わる: ${show(kept)}');
            }
          }
          if (atEnd && kept.lines.length > plain.lines.length) {
            problems.add(
              '幅$w: 普通のTextより行が多い: ${show(kept)}（普通のText '
              '${show(plain)}）',
            );
          }
        }
        if (parts.isNotEmpty) {
          expect(tooWide, greaterThan(0), reason: 'かたまりより狭い欄も調べる');
        }
        expect(problems, isEmpty, reason: problems.take(12).join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('内側の大きさを尋ねる親の中でも、尋ねた大きさと並べた大きさが'
      '同じ（ダイアログのボタン・IntrinsicWidth, 文字1〜2倍）', (tester) async {
    await fonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugCheckIntrinsicSizes = true;
    try {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final width in [320.0, 360.0, 412.0]) {
          tester.view.physicalSize = Size(width, 800);
          const label = '未使用素材を一括削除（全プロジェクト）';
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Column(
                    children: [
                      IntrinsicWidth(
                        child: KeepTogetherText(
                          label,
                          keep: const ['（全プロジェクト）'],
                          style: const TextStyle(
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                      ),
                      Table(
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.intrinsicHeight,
                        children: const [
                          TableRow(
                            children: [
                              KeepTogetherText(label, keep: ['（全プロジェクト）']),
                              Text('x'),
                            ],
                          ),
                        ],
                      ),
                      AlertDialog(
                        content: const Text('?'),
                        actions: [
                          FilledButton(
                            onPressed: () {},
                            child: const KeepTogetherText(
                              label,
                              keep: ['（全プロジェクト）'],
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${width.toInt()}px 文字$scale倍',
          );
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.descendant(
              of: find.byType(KeepTogetherText),
              matching: find.byType(RichText),
            ),
          )) {
            final lines = ParagraphLines(paragraph);
            expect(lines.charsOutsideWidth(), isEmpty);
            expect(lines.lineEdgeViolations(), isEmpty);
          }
        }
      }
    } finally {
      debugCheckIntrinsicSizes = false;
    }
  });
}
