// ブラシ・トーン・スタンプの一覧の名前が、狭いドック・大きな文字でも1字で
// 切れず、2行まで折り返してから「…」で切ることを見張る。
//
// 以前は名前を1行で「…」にしていたので、PCのドック200px×文字2倍の中国語で
// スタンプの「三角形」が「三…」になった。ただし行に入らない語がある名前と、
// 1行に2字も入らない狭い行（折り返すと1字ずつ縦に並ぶ）は、1行で「…」にする
// （欧文の語は途中で折らない）。日本語・中国語の名前は字の間で折り返せるので、
// 長い名前（組み込みのブラシの名前はどの言語でも日本語）も2行まで折り返す
// （Flutterの最小の固有幅は、空白の無い日本語・中国語の文を1つの語と数える）。
// 2行に折り返すときは、日本語の行頭禁則を守る（「カリグラフィ / ー」のように
// 長音符・小さいかな・閉じ括弧で行を始めない）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/preset_stroke_row.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

/// 幅[width]・文字の倍率[scale]で名前[name]の行を出し、名前の段落を返す。
Future<RenderParagraph> _name(
  WidgetTester tester,
  Locale locale,
  String name,
  double width,
  double scale,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeService().themeDataFor(locale),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: PresetStrokeRow(
              name: name,
              color: Colors.black,
              selected: false,
              onTap: () {},
              stamp: Stamp(id: 's', name: name),
              // 一覧の行と同じ、お気に入り・メニュー・並べ替えのつまみの幅。
              trailing: const SizedBox(width: 104, height: 24),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(name), matching: find.byType(RichText)),
  );
}

int _lines(RenderParagraph p) {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    locale: p.locale,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.constraints.maxWidth);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

void main() {
  testWidgets('中国語の「三角形」はドック200px×文字2倍で切れず2行に折り返す', (tester) async {
    await loadAppFonts(tester);
    final p = await _name(tester, const Locale('zh'), '三角形', 200, 2.0);
    expect(p.didExceedMaxLines, isFalse, reason: '「…」で切れた');
    expect(_lines(p), 2);
  });

  testWidgets('行に入らない語がある名前は、語の途中で折らず1行で「…」にする', (tester) async {
    await loadAppFonts(tester);
    final p = await _name(
      tester,
      const Locale('fr'),
      'Aquarelle humide',
      200,
      2.0,
    );
    expect(
      textFitProblems(p, data: true),
      isEmpty,
      reason: '語の途中で折れた（${_lines(p)}行）',
    );
    expect(_lines(p), 1);
  });

  testWidgets('語がどれも入る名前は2行まで折り返す', (tester) async {
    await loadAppFonts(tester);
    final p = await _name(tester, const Locale('fr'), 'Trait fin', 200, 2.0);
    expect(p.didExceedMaxLines, isFalse);
    expect(textFitProblems(p, data: true), isEmpty);
  });

  testWidgets('1行に2字も入らない狭い行は、折り返して1字ずつ縦に並べず1行で「…」', (tester) async {
    await loadAppFonts(tester);
    // 名前の欄が12pxの字2つ分（24px）より狭い行。
    final p = await _name(tester, const Locale('ja'), 'ペン', 150, 1.0);
    expect(_lines(p), 1);
  });

  testWidgets('日本語・中国語の長い名前も、ドック200px×文字2倍で1行で切らず'
      '2行まで折り返す', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    for (final (locale, name) in const [
      (Locale('ja'), 'グレー単色の下塗り'),
      (Locale('ja'), 'エアブラシ（柔らかい）'),
      (Locale('zh'), '柔和喷枪笔刷大'),
      (Locale('zh', 'Hant'), '柔和噴槍筆刷大'),
    ]) {
      final p = await _name(tester, locale, name, 200, 2.0);
      if (_lines(p) != 2) {
        problems.add('${locale.toLanguageTag()} «$name»: ${_lines(p)}行');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('2行に折り返す名前は、長音符「ー」・小さいかな・閉じ括弧で行を始めない'
      '（日本語の行頭禁則。幅150〜360px×文字1.0/1.3/2.0）', (tester) async {
    await loadAppFonts(tester);
    // 行の始めに来てはいけない字。
    const noLineStart =
        'ーぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ'
        '、。，．・：；？！）」』】〕〉》］｝)]},.:;?!';
    // 組み込みのブラシ・トーン・スタンプの名前のうち、行頭禁則の字を含むもの。
    const names = [
      'カリグラフィー',
      'グリッターペン',
      'マーカーペン',
      'チェックマーク',
      'ボールチェーン',
      'ストッキング 10デニール',
      'ガッシュ（不透明水彩）',
      'ピクセルボーダー（横1px）',
      'ピクセルストライプ（縦1px）',
      'チェーン（太）',
      '葉っぱ（ベタ塗り）',
      'エアブラシ（柔らかい）',
      '木炭（粗目）',
    ];
    final problems = <String>[];
    var wrapped = 0;
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (var width = 150.0; width <= 360; width += 3) {
        for (final name in names) {
          final p = await _name(tester, const Locale('ja'), name, width, scale);
          final painter = TextPainter(
            text: p.text,
            textDirection: p.textDirection,
            textScaler: p.textScaler,
            locale: p.locale,
            maxLines: p.maxLines,
            ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
            strutStyle: p.strutStyle,
            textWidthBasis: p.textWidthBasis,
            textHeightBehavior: p.textHeightBehavior,
          )..layout(maxWidth: p.constraints.maxWidth);
          final text = p.text.toPlainText();
          final lines = painter.computeLineMetrics();
          if (lines.length > 1) wrapped++;
          for (final line in lines.skip(1)) {
            var at = painter
                .getPositionForOffset(
                  Offset(0, line.baseline - line.ascent + line.height / 2),
                )
                .offset;
            while (at < text.length && text[at] == '\u2060') {
              at++;
            }
            if (at < text.length && noLineStart.contains(text[at])) {
              problems.add(
                '${width.round()}px ×$scale «$name»: 「${text.substring(0, at).replaceAll('\u2060', '')} / '
                '${text.substring(at).replaceAll('\u2060', '')}」',
              );
            }
          }
          painter.dispose();
        }
      }
    }
    // 折り返した名前を見ていること。
    expect(wrapped, greaterThan(100));
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
