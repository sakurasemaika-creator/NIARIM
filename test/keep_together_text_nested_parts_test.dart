// [KeepTogetherText]で、大きなかたまり（最後の語）の中に小さなかたまり
// （長音符・小さいかなをその前の字とつなぐ部分）があるとき、大きなかたまりが
// 欄の1行に入らずつながないときも、小さなかたまりはつないだままにすること。
//
// 一覧の行の名前は行の頭の禁則（keepLineStarts）と最後の語（keepLastPhrase）を
// 両方つなぐ。以前は始まりの早い大きなかたまりだけを残し、その中の小さな
// かたまりを捨てていたので、最後の語が入らない狭い欄で「…レイヤ／ー」と
// 長音符から行が始まった（活用Tipsの題）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/utils/line_break.dart';
import 'package:niarim/widgets/keep_together_text.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

void main() {
  // 活用Tipsの題（長音符・小さいかなを含むもの）と、最後の語が長い題。
  const texts = [
    '仮色で塗り分けて色更新するなら、線画は通常レイヤー1枚でOK',
    '共通レイヤー×フォルダで話数をまたいで使い回す',
    'パース定規×オニオンスキンで背景を使い回す',
    'グラデーション×指定色縁取りで前髪に透明感を出す',
    'ストッキング・タイツはデニール数でトーンの目の細かさが変わる',
    'ワイド画面ではPCモード（DeX）の本格レイアウトに',
    '早替えツール×ペンサブツールで手を止めない作業導線',
    'セーブスロット×自動保存を使い分ける',
    'スタンプ×ブレンドモードで光のエフェクト',
    '効果音はクリップ複製×フェードでリズムよく鳴らす',
  ];
  const smallKana = 'ーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ';

  testWidgets('a long last phrase that does not fit still keeps ー with the '
      'letter before it', (tester) async {
    await loadAppFonts(tester);
    for (final text in texts) {
      final keep = [
        ...lineStartKeepParts(text),
        ...japaneseLastPhraseParts(text),
      ];
      for (var width = 60.0; width <= 300; width += 1) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                child: KeepTogetherText(
                  text,
                  keep: keep,
                  style: const TextStyle(
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        final lines = ParagraphLines(paragraph).lines;
        for (final line in lines.skip(1)) {
          expect(
            smallKana.contains(line.characters.first),
            isFalse,
            reason: '$text at ${width}px: ${lines.join(' / ')}',
          );
        }
        // 欄の外へはみ出さない。
        expect(paragraph.size.width, lessThanOrEqualTo(width + 0.01));
      }
    }
  });
}
