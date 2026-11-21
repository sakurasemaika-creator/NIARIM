// 数と単位を途中で切らない[KeepTogetherText]が、普通の[Text]なら行を
// 変えない所（閉じ括弧・読点・句点の前、開き括弧の後）で行を変えないこと、
// かたまりより狭い欄でも字が欄の外へはみ出さないこと、1行に並べた字の
// 位置・行の高さ・文の幅が普通の[Text]と同じで、読み上げは元の文のままで
// あることを、本物のフォント（本文の白光明朝・見出しのくらむぼん）と
// 幅40〜260pxで確かめる（字の間隔はテーマの本文の0.25px）。
//
// 数と単位のかたまりを埋め込んだ部品（WidgetSpan）で並べていた頃は、
// 段落が部品の前後のどこでも行を変えてよいと見なし、文字2倍の特典交換の
// 題が「作品広場の投 / 稿枠（1日 / 1作品→3作品 / ）」と閉じ括弧だけの行に
// なり、幅によっては「投稿枠（」で行が終わり、「30日 / 、達成しました」と
// 読点で行が始まった（普通のTextでは0回）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/keep_together_text.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 数と、そのすぐ後に空白なしで続く単位の字（[KeepTogetherText]が1つの
/// かたまりにするもの）。
final _numberWithUnit = RegExp(
  r'(?<!\d)\d+(?:[.,]\d+)*'
  r'(?:\p{Script=Han}{1,3}|\p{Script=Hiragana}{1,3}'
  r'|[\p{Script=Katakana}ー]{1,3}|\p{Script=Hangul}{1,3})',
  unicode: true,
);

/// 字と字の間のどこでも行を変えてよい字（漢字・仮名・ハングル）。
final _cjk = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
  unicode: true,
);

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

void main() {
  var fontsLoaded = false;

  final cases = <(String, Locale, String, List<String>)>[
    for (final locale in const [Locale('ja'), Locale('zh'), _zhHant])
      (
        '特典の名前',
        locale,
        lookupAppLocalizations(locale).rewardUnlockCommunityPostQuota,
        const <String>[],
      ),
    (
      '特典の名前',
      const Locale('ko'),
      lookupAppLocalizations(const Locale('ko')).rewardUnlockCommunityPostQuota,
      const <String>[],
    ),
    ('読点', const Locale('ja'), '累計30日、達成しました。', const <String>[]),
    ('かぎ括弧', const Locale('ja'), '「10件」の作品（30日）を投稿しました。', const <String>[]),
    ('逗号', const Locale('zh'), '累计登录30天，已获得5金币。', const <String>[]),
    ('逗號', _zhHant, '累計登入30天，已獲得5金幣。', const <String>[]),
    ('確定価格', const Locale('ja'), '確定価格（交換準備中） · 55000コイン', const ['55000コイン']),
    // 空白を挟む数と単位（普通の空白の後では、段落はいつでも行を変える）。
    (
      '空白',
      const Locale('es'),
      'Misión diaria: Mantén abierta la Plaza de Obras 5 minutos en total.',
      const ['5 minutos'],
    ),
    (
      '空白',
      const Locale('fr'),
      'Mission mensuelle\u00a0: Garder la Place des œuvres ouverte '
          '2 heures au total (1 heure par jour).',
      const ['2 heures', '1 heure'],
    ),
  ];

  const families = <String, (String, List<String>)>{
    '本文（白光明朝）': ('HakkouMincho', kBodyFontFallback),
    '見出し（くらむぼん）': ('Kuramubon', kHeadingFontFallback),
  };

  for (final (what, locale, text, keep) in cases) {
    for (final MapEntry(key: fontName, value: (family, fallback))
        in families.entries) {
      testWidgets('行の頭・終わりの禁則を守り、幅と読み上げは普通のTextと同じ'
          '（$what, ${locale.toLanguageTag()}, $fontName）', (tester) async {
        if (!fontsLoaded) {
          await loadAppFonts(tester);
          fontsLoaded = true;
        }
        final semantics = tester.ensureSemantics();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1300, 80000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final style = TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallback,
          fontSize: 14,
        );
        final widths = [for (var w = 40; w <= 260; w++) w];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in widths) ...[
                      SizedBox(
                        key: ValueKey('keep$w'),
                        width: w.toDouble(),
                        child: KeepTogetherText(text, keep: keep, style: style),
                      ),
                      SizedBox(
                        key: ValueKey('plain$w'),
                        width: w.toDouble(),
                        child: Text(text, style: style),
                      ),
                    ],
                    // 1行に収まる幅。
                    SizedBox(
                      key: const ValueKey('keepWide'),
                      width: 1200,
                      child: KeepTogetherText(text, keep: keep, style: style),
                    ),
                    SizedBox(
                      key: const ValueKey('plainWide'),
                      width: 1200,
                      child: Text(text, style: style),
                    ),
                  ],
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

        // 数と単位のかたまりと、その前後の行を変えられない字（前の開き括弧・
        // 記号〔「→3」〕、後の閉じ括弧・句読点）を合わせた幅。これより狭い
        // 欄では、どう並べてもどこかで切れるので数えない（段落の最小の幅は
        // 使えない。くらむぼんの繁体字の文では、普通のTextでも1行の幅と
        // 同じ値になった）。
        final plainWide = ParagraphLines(paragraphIn('plainWide'));
        final symbol = RegExp(r'\p{S}', unicode: true);
        var narrowest = 0.0;
        final visible = plainWide.visible;
        for (final (start0, end0) in [
          for (final match in _numberWithUnit.allMatches(visible))
            (match.start, match.end),
          for (final part in keep)
            if (visible.indexOf(part) case final at when at >= 0)
              (at, at + part.length),
          // 空白で区切るラテン文字の語（語の中では、行の頭に来ない字の前でも
          // 入りきらなければ切れる）。
          for (final word in RegExp(r'[^ ]+').allMatches(visible))
            if (!_cjk.hasMatch(word.group(0)!)) (word.start, word.end),
        ]) {
          var start = start0;
          var end = end0;
          while (start > 0 &&
              (lineEndForbidden.contains(visible[start - 1]) ||
                  symbol.hasMatch(visible[start - 1]))) {
            start--;
          }
          while (end < visible.length &&
              lineStartForbidden.contains(visible[end])) {
            end++;
          }
          final boxes = plainWide.paragraph.getBoxesForSelection(
            plainWide.sourceSelection(start, end),
          );
          final width = boxes.last.right - boxes.first.left;
          if (width > narrowest) narrowest = width;
        }

        final problems = <String>[];
        var checked = 0;
        for (final w in widths) {
          final kept = paragraphIn('keep$w');
          final plain = paragraphIn('plain$w');
          final keptLines = ParagraphLines(kept);
          // かたまりより狭い欄でも、字が欄の外へはみ出さない（はみ出した分は
          // 切れて見えなくなる。入りきらないかたまりは字の間で折る）。
          for (final problem in keptLines.charsOutsideWidth()) {
            problems.add('幅$w: 欄の外 $problem');
          }
          if (w < narrowest + 0.5) continue;
          checked++;
          for (final problem in keptLines.lineEdgeViolations()) {
            problems.add('幅$w: $problem');
          }
          // 普通のTextは禁則を守る（調べ方が正しいことの確かめ）。
          for (final problem in ParagraphLines(plain).lineEdgeViolations()) {
            problems.add('幅$w（普通のText）: $problem');
          }
          for (final match in _numberWithUnit.allMatches(keptLines.visible)) {
            if (keptLines.breaksWithin(match.start, match.end).isNotEmpty) {
              problems.add(
                '幅$w: 「${match.group(0)}」の途中で行が変わる: '
                '${keptLines.lines.join(' / ')}',
              );
            }
          }
          // かたまりの中の空白は改行しない空白（U+00A0）で描かれる。
          final flat = keptLines.visible.replaceAll('\u00a0', ' ');
          for (final part in keep) {
            final at = flat.indexOf(part);
            if (at >= 0 &&
                keptLines.breaksWithin(at, at + part.length).isNotEmpty) {
              problems.add(
                '幅$w: 「$part」の途中で行が変わる: '
                '${keptLines.lines.join(' / ')}',
              );
            }
          }
        }
        expect(checked, greaterThan(150), reason: '調べた幅の数');
        expect(problems, isEmpty, reason: problems.take(20).join('\n'));

        // 1行に並べたとき、字の位置と文の幅が普通のTextと同じ（かたまりに
        // しても字の間が広がらない。テーマの本文の字の間隔〔0.25px〕は字ごとに
        // 足されるので、行を変えないための字に足すと、かたまりの中だけ
        // 広がった）。
        final keptWide = ParagraphLines(paragraphIn('keepWide'));
        expect(
          keptWide.visible.replaceAll('\u00a0', ' '),
          plainWide.visible.replaceAll('\u00a0', ' '),
        );
        expect(keptWide.lines, hasLength(1));
        final shifted = <String>[];
        for (var i = 0; i < plainWide.visible.length; i++) {
          final keptBoxes = keptWide.paragraph.getBoxesForSelection(
            keptWide.sourceSelection(i, i + 1),
          );
          final plainBoxes = plainWide.paragraph.getBoxesForSelection(
            plainWide.sourceSelection(i, i + 1),
          );
          if (keptBoxes.isEmpty || plainBoxes.isEmpty) continue;
          final keptBox = keptBoxes.first.toRect();
          final plainBox = plainBoxes.first.toRect();
          if ((keptBox.left - plainBox.left).abs() > 0.01 ||
              (keptBox.right - plainBox.right).abs() > 0.01 ||
              (keptBox.top - plainBox.top).abs() > 0.01 ||
              (keptBox.bottom - plainBox.bottom).abs() > 0.01) {
            shifted.add(
              '「${plainWide.visible[i]}」 $keptBox（普通のText $plainBox）',
            );
          }
        }
        expect(shifted, isEmpty, reason: shifted.join('\n'));
        // 行の高さも同じ（行を変えないための字が別のフォントで描かれて、
        // 行が高くならない）。
        expect(
          keptWide.paragraph.size.height,
          moreOrLessEquals(plainWide.paragraph.size.height, epsilon: 0.01),
        );
        expect(
          keptWide.paragraph.getMaxIntrinsicWidth(double.infinity),
          moreOrLessEquals(
            plainWide.paragraph.getMaxIntrinsicWidth(double.infinity),
            epsilon: 0.01,
          ),
        );
        expect(tester.takeException(), isNull);

        // 読み上げは元の文のまま（行を変えないための字を含まない）。
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  child: KeepTogetherText(text, keep: keep, style: style),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSemantics(find.byType(KeepTogetherText)),
          isSemantics(label: text),
        );
        expect(tester.widget<Text>(find.byType(KeepTogetherText)).data, text);
        semantics.dispose();
      });
    }
  }
}
