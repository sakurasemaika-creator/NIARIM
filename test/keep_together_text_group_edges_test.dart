// [KeepTogetherText]が欄の幅でかたまりのつなぎ方を決めるようになってから
// （DISC130）、レビューで見つかった3つの崩れと、書体が変わったときの決め直し。
//
// 1. かたまり（数と単位）が字（書記素）の途中で終わる文（分けて書いた濁点
//    「か＋゛」・異体字セレクター・分けて書いたハングル・半角カナの濁点）で、
//    字の位置の表に無い位置を引いて例外になり、文の代わりに赤いエラーの部品が
//    出た（作品名など、利用者の書いた文がそのまま入る所がある）。
// 2. 内側の最小の幅を、どのかたまりもつながない文で答えたため、
//    [ActionBesideOrBelow]が「単語の途中で折れない」と見て操作を横に置き、
//    入らないかたまりを分けた（韓国語・文字2倍「55000 / 오팔」等）。
// 3. かたまりの前の記号（全角の～＋＝）を「離せない字」として一緒に数えた
//    ため、記号の後で行が変わるだけで「行をまたいだ」と見て、入るかたまりを
//    分けた（「期間は1日～30 / 日です」）。
// 4. 書体が読み込まれる・変わる（端末の書体の変更）と字の幅が変わるのに、
//    前の書体で決めたつなぎ方のまま描いた。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/action_beside_or_below.dart';
import 'package:niarim/widgets/keep_together_text.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

const _zeroWidthSpace = '\u200b';

const _body = TextStyle(
  fontFamily: 'HakkouMincho',
  fontFamilyFallback: kBodyFontFallback,
  fontSize: 14,
);

const _heading = TextStyle(
  fontFamily: 'Kuramubon',
  fontFamilyFallback: kHeadingFontFallback,
  fontSize: 14,
);

Widget _app(
  Widget child, {
  Locale locale = const Locale('ja'),
  double scale = 1,
  TextStyle style = _body,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(1000, 2000),
      textScaler: TextScaler.linear(scale),
    ),
    child: Material(
      child: DefaultTextStyle(
        style: style,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

RenderParagraph _paragraphOf(WidgetTester tester, Finder of) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: of, matching: find.byType(RichText)).first,
    );

/// 描いた行で、[part]（改行しない空白は普通の空白として探す）のどこかが
/// 途中で行を変えているか。
bool _splits(ParagraphLines lines, String part) {
  final index = <int>[];
  final flat = StringBuffer();
  for (var i = 0; i < lines.visible.length; i++) {
    final char = lines.visible[i];
    if (char == _zeroWidthSpace) continue;
    index.add(i);
    flat.write(char == '\u00a0' ? ' ' : char);
  }
  final text = flat.toString();
  for (var at = text.indexOf(part); at >= 0; at = text.indexOf(part, at + 1)) {
    final end = index[at + part.length - 1] + 1;
    if (lines.breaksWithin(index[at], end).isNotEmpty) return true;
  }
  return false;
}

/// [text]を[style]・[scale]で1行に並べた幅。
double _width(String text, TextStyle style, double scale) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(scale),
  )..layout();
  try {
    return painter.width;
  } finally {
    painter.dispose();
  }
}

void main() {
  var fontsLoaded = false;
  Future<void> fonts(WidgetTester tester) async {
    if (fontsLoaded) return;
    await loadAppFonts(tester);
    fontsLoaded = true;
  }

  testWidgets('かたまりが字の途中で終わる文も、字を分けずに描く', (tester) async {
    await fonts(tester);
    for (final text in [
      // 「が」を「か」と結合する濁点（U+3099）で書いたもの。
      '作品2\u304b\u3099を見る',
      // 異体字セレクター（U+E0100）付きの漢字。
      '第2葛\u{E0100}飾',
      // 「개월」を字母（初声・中声・終声）に分けて書いたもの。
      '10\u1100\u1162\u110b\u116f\u11af 후',
      // 半角カナと半角の濁点（U+FF9E）。
      '2\uff76\uff9e\uff99',
    ]) {
      for (final width in [400.0, 60.0, 30.0]) {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: width,
              child: KeepTogetherText(text, keep: const []),
            ),
          ),
        );
        final what = '「$text」${width.toInt()}px';
        expect(tester.takeException(), isNull, reason: what);
        expect(find.byType(ErrorWidget), findsNothing, reason: what);
        final drawn = _paragraphOf(
          tester,
          find.byType(KeepTogetherText),
        ).text.toPlainText(includeSemanticsLabels: false);
        // 行を変えないための字（WORD JOINER）・行を変えてよい所の印
        // （ZERO WIDTH SPACE）を除くと、字（書記素）の並びは元の文のまま
        // （字の途中にこれらを挟むと、濁点・字母が前の字から離れる）。
        expect(
          [
            for (final char in drawn.characters)
              if (char != wordJoiner && char != _zeroWidthSpace) char,
          ],
          text.characters.toList(),
          reason: what,
        );
      }
    }
  });

  // 実際の呼び出し元（ログインボーナス・ミッションの行）と同じ、文の横か
  // 下に「受け取る」のボタンを置く並べ方。
  for (final (what, locale, style, scale, width, text, keep) in [
    (
      'コイン（韓国語）',
      const Locale('ko'),
      _heading,
      2.0,
      222.0,
      lookupAppLocalizations(const Locale('ko')).coinAmount(55000),
      [lookupAppLocalizations(const Locale('ko')).coinAmount(55000)],
    ),
    (
      '作品の目標（簡体字）',
      const Locale('zh'),
      _heading,
      2.0,
      234.0,
      lookupAppLocalizations(
        const Locale('zh'),
      ).creatorMissionNamedBookmark('My work 2', 100),
      const <String>[],
    ),
    (
      '確定価格（日本語）',
      const Locale('ja'),
      _heading,
      2.0,
      330.0,
      '${lookupAppLocalizations(const Locale('ja')).rewardUnlockFixedPrice}'
          ' · ${lookupAppLocalizations(const Locale('ja')).coinAmount(55000)}',
      [lookupAppLocalizations(const Locale('ja')).coinAmount(55000)],
    ),
    (
      '容量削減の行（日本語）',
      const Locale('ja'),
      _heading,
      1.3,
      282.0,
      lookupAppLocalizations(
        const Locale('ja'),
      ).storageRemoveUnusedMaterialsButton,
      const ['（全プロジェクト）'],
    ),
  ]) {
    testWidgets('文の横にボタンを置くかは、かたまりをつないだ文の幅で決める'
        '（$what, 文字$scale倍, ${width.toInt()}px）', (tester) async {
      await fonts(tester);
      final l = lookupAppLocalizations(locale);
      Widget row(Key key, Widget text) => SizedBox(
        key: key,
        width: width,
        child: ActionBesideOrBelow(
          text: text,
          action: OutlinedButton(onPressed: () {}, child: Text(l.missionClaim)),
        ),
      );
      // かたまりをすべてつないだ文（幅の制限が無いときに描く文。DISC130より
      // 前の部品は、どの幅でもこの文を描いた）。
      await tester.pumpWidget(
        _app(
          OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: double.infinity,
            child: KeepTogetherText(text, keep: keep),
          ),
          locale: locale,
          scale: scale,
          style: style,
        ),
      );
      final joined = tester
          .widget<RichText>(
            find.descendant(
              of: find.byType(KeepTogetherText),
              matching: find.byType(RichText),
            ),
          )
          .text;
      final groups = [
        for (final m in RegExp(
          '(?:[^$wordJoiner]$wordJoiner)+[^$wordJoiner]',
        ).allMatches(joined.toPlainText()))
          m.group(0)!.replaceAll(wordJoiner, '').replaceAll('\u00a0', ' '),
      ];
      expect(groups, isNotEmpty);

      await tester.pumpWidget(
        _app(
          Column(
            children: [
              row(const ValueKey('keep'), KeepTogetherText(text, keep: keep)),
              row(
                const ValueKey('joined'),
                RichText(text: joined, textScaler: TextScaler.linear(scale)),
              ),
            ],
          ),
          locale: locale,
          scale: scale,
          style: style,
        ),
      );
      expect(tester.takeException(), isNull);
      String placement(String key) {
        final box = find.byKey(ValueKey(key));
        final textBottom = tester
            .getBottomLeft(
              find.descendant(of: box, matching: find.byType(RichText)).first,
            )
            .dy;
        final buttonTop = tester
            .getTopLeft(
              find.descendant(of: box, matching: find.byType(OutlinedButton)),
            )
            .dy;
        return buttonTop >= textBottom - 0.5 ? 'below' : 'beside';
      }

      final lines = ParagraphLines(
        _paragraphOf(tester, find.byKey(const ValueKey('keep'))),
      );
      expect(
        placement('keep'),
        placement('joined'),
        reason: lines.lines.join(' / '),
      );
      for (final group in groups) {
        expect(
          _splits(lines, group),
          isFalse,
          reason: '「$group」: ${lines.lines.join(' / ')}',
        );
      }
    });
  }

  testWidgets('前の記号の後で行を変えてよいとき、1行に入るかたまりを分けない', (tester) async {
    await fonts(tester);
    final problems = <String>[];
    var checked = 0;
    for (final (text, groups) in [
      ('期間は1日～30日です', ['1日', '30日']),
      ('価格は＋10コイン、合計は＝55000コインです', ['10コイン、', '55000コイン']),
    ]) {
      for (var w = 40.0; w <= 160; w += 2) {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: w,
              child: KeepTogetherText(text, keep: const []),
            ),
          ),
        );
        final lines = ParagraphLines(
          _paragraphOf(tester, find.byType(KeepTogetherText)),
        );
        for (final group in groups) {
          if (_width(group, _body, 1) + 1 > w) continue;
          checked++;
          if (_splits(lines, group)) {
            problems.add(
              '「$text」${w.toInt()}px「$group」: ${lines.lines.join(' / ')}',
            );
          }
        }
        problems.addAll(lines.lineEdgeViolations());
      }
    }
    expect(checked, greaterThan(50));
    expect(problems, isEmpty, reason: problems.take(10).join('\n'));
  });

  testWidgets('書体が変わったら、つなぎ方を決め直す', (tester) async {
    // まだ読み込んでいない書体名で描く（テストの既定の書体で並ぶ）。
    const family = 'KeepTogetherLateFont';
    const text = '累計55000コイン';
    const style = TextStyle(fontFamily: family, fontSize: 14);
    final before = _width('55000コイン', style, 1);
    // 読み込む前は入らず、読み込んだ後は入る幅（くらむぼんの数字は、
    // テストの既定の書体の数字〔1em〕より狭い）。
    await tester.runAsync(() async {
      final loader = FontLoader('KeepTogetherWidthProbe')
        ..addFont(rootBundle.load('assets/fonts/Kuramubon.otf'));
      await loader.load();
    });
    final after = _width(
      '55000コイン',
      style.copyWith(fontFamily: 'KeepTogetherWidthProbe'),
      1,
    );
    expect(after + 8, lessThan(before));
    final width = ((before + after) / 2).roundToDouble();

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: width,
          child: const KeepTogetherText(text, keep: [], style: style),
        ),
      ),
    );
    await tester.runAsync(() async {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/Kuramubon.otf'));
      await loader.load();
    });
    // 書体の変更は次のフレームで知らされる。
    await tester.pump();
    await tester.pump();
    expect(_width('55000コイン', style, 1), moreOrLessEquals(after));
    final lines = ParagraphLines(
      _paragraphOf(tester, find.byType(KeepTogetherText)),
    );
    expect(
      _splits(lines, '55000コイン'),
      isFalse,
      reason: '${width.toInt()}px: ${lines.lines.join(' / ')}',
    );

    // 新しく作った部品と同じに描く。
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: width,
          child: const KeepTogetherText(
            text,
            key: ValueKey('fresh'),
            keep: [],
            style: style,
          ),
        ),
      ),
    );
    expect(
      ParagraphLines(_paragraphOf(tester, find.byType(KeepTogetherText))).lines,
      lines.lines,
    );
    expect(tester.takeException(), isNull);
  });
}
