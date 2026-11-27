/// アプリで使うフォントの「未収録文字を補う代替フォント」の定義。
///
/// ## なぜ必要か
///
/// アプリは7言語（ja/en/es/fr/ko/zh/zh_Hant）に対応しているが、同梱して
/// いる日本語系フォントはハングルと簡体字を持たない。補わないとこれらは
/// 端末のシステムフォント任せになり、端末ごとに見た目が変わって明朝で
/// 統一した意匠が崩れる（ハングルを持たない端末では豆腐になる）。
/// また、同梱フォントはいずれも既存フォントの改変版で、改変の過程で
/// 収録文字が減っているものもある。
///
/// ## 本文用と見出し用で列を分けている理由
///
/// **代替フォントは本文用と見出し用で別の列を持つ必要がある。**
/// 見出し（くらむぼん＝Dela Gothic派生の超極太ゴシック）の補完に明朝を
/// 使うと、たとえば価格表示「550엔」のように極太の数字と細い明朝の
/// ハングルが同じ単語の中に並び、明確に浮いてしまう（公式サイト側で
/// 実際にこの症状が出た）。太さの近いゴシックBlack(900)で補うと解消する。
///
/// | 用途 | 主フォント | 補完に使うもの |
/// |---|---|---|
/// | 本文 | 白光明朝（Noto Serif JP派生） | Noto Serif KR / SC（同じSource Han Serif系で骨格・字幅が揃う） |
/// | 見出し | くらむぼん（Dela Gothic派生） | Noto Sans KR / SC の Black(900)（太さを合わせる） |
///
/// ## カバー判定は本文用・見出し用それぞれで見ること
///
/// 本文用スタックと見出し用スタックは別物なので、**片方が持っていても
/// もう片方の字抜けは埋まらない**。カバー率を確かめるときは2つの列の
/// 和集合ではなく、それぞれの列ごとに判定する必要がある。
/// `test/font_coverage_test.dart`はその方針で検証している。
///
/// ## 補完用フォントはサブセット化して同梱している
///
/// Noto Serif/Sans KR・SCは原本が10〜24MBあり、4つ合わせて75MBになる。
/// そのままではAPKが肥大化するため、**アプリのUIに実際に出る文字だけ**を
/// 抜き出したものを同梱している（計約3.6MB）。生成手順は
/// `tool/build_fallback_fonts.py`にある。`lib/l10n/*.arb`へ文言を追加した
/// あとは再生成が必要で、忘れると増やした文字だけシステムフォントで
/// 表示されて見た目が揃わなくなる。`test/font_coverage_test.dart`が
/// その取りこぼしを検出する。
///
/// なおユーザーが入力した文字（作品名など）は対象外で、従来どおり
/// システムフォントが受け持つ（現状と同じ挙動のため後退は無い）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 本文用フォント（白光明朝）の代替フォント列。
///
/// - `DelaGothicOne`：白光明朝に無い拡張ラテン254文字（Ą ć Č İ 等）を補う。
///   白光明朝が取りこぼす文字はちょうどこの254文字だけなので、先頭に
///   置いても「セリフ体で出せる文字がゴシック体になる」ことは起こらない。
/// - `NotoSerifJP`：白光明朝の改変元。実測では収録文字が完全に一致して
///   おり、白光明朝が主フォントの文では補える文字は無い（その文の列
///   [bodyFontFallbackFor]からは外してある）。主フォントを別の書体にした
///   文（[fallbackUnderOtherFamily]）と、Noto Serif JPを主にした文の補完に使う。
/// - `NotoSerifKRSubset` / `NotoSerifSCSubset`：ハングル・簡体字。
///   本文と同じSource Han Serif系なので混植しても継ぎ目が出ない。
const List<String> kBodyFontFallback = <String>[
  'DelaGothicOne',
  'NotoSerifJP',
  'NotoSerifKRSubset',
  'NotoSerifSCSubset',
];

/// 見出し用フォント（くらむぼん）の代替フォント列。
///
/// 明朝を一切含めないのが要点。上記のとおり、極太ゴシックの中に細い明朝が
/// 混ざると同じ単語の中で浮くため。ここに無い文字は端末のシステムフォント
/// （Androidの日本語・中国語はNoto Sans CJK＝ゴシック）が受け持つので、
/// 明朝で補うより見た目が近い。
///
/// - `DelaGothicOne`：くらむぼんの改変元。くらむぼんに無い1,456文字を補う。
/// - `NotoSansKRBlackSubset` / `NotoSansSCBlackSubset`：ハングル・簡体字を
///   Black(900)で補い、くらむぼんの太さに合わせる。
const List<String> kHeadingFontFallback = <String>[
  'DelaGothicOne',
  'NotoSansKRBlackSubset',
  'NotoSansSCBlackSubset',
];

/// 中国語（簡体字・繁体字）の画面の本文の代替フォント列。主フォントは
/// [bodyFontFamilyFor]が返すNoto Serif SC（サブセット）。
const List<String> kChineseBodyFontFallback = <String>[
  'HakkouMincho',
  'DelaGothicOne',
  'NotoSerifJP',
  'NotoSerifKRSubset',
];

/// 韓国語の画面の本文の代替フォント列。主フォントは[bodyFontFamilyFor]が
/// 返すNoto Serif KR（サブセット）。
///
/// 部分フォントに無い字（利用者が打つ作品名・フォルダ名・タグの全角英数字・
/// かな・漢字）は明朝の白光明朝で補う。[kBodyFontFallback]を使うと先頭の
/// 極太のDela Gothic Oneがそれらを描き、「ＡＢＣ全角」の「ＡＢＣ」だけが
/// 極太になった。白光明朝に無い拡張ラテンだけをDela Gothic Oneが受け持つ。
const List<String> kKoreanBodyFontFallback = <String>[
  'HakkouMincho',
  'DelaGothicOne',
  'NotoSerifJP',
  'NotoSerifSCSubset',
];

/// 表示言語[locale]の本文の主フォント。
///
/// 白光明朝の漢字はどれも字幅0.65em（縦長の明朝）の日本の字形なので、
/// 中国語の文では白光明朝にある字（示・收・藏…）だけが細い日本の字形で、
/// 無い字（仅・显…）は全角の Noto Serif SC になり、1語の中で字幅と字形が
/// 混ざって詰まって見えた（「仅显示收藏」）。中国語は Noto Serif SC
/// （白光明朝と同じ Source Han Serif 系の明朝）を主にし、字幅をそろえる。
/// 繁体字も同じ Noto Serif SC（簡体字の地域の字形）で描く（繁体字用の
/// 書体は同梱していない）。サブセットには、ARBの字に加えて lib 配下の
/// 手書きの文字列（組み込みのブラシ・トーン等の名前）の漢字・かな・全角の
/// 字と空白も入れてある（tool/build_fallback_fonts.py）。
String bodyFontFamilyFor(Locale? locale) => switch (locale?.languageCode) {
  'zh' => 'NotoSerifSCSubset',
  'ko' => 'NotoSerifKRSubset',
  _ => 'HakkouMincho',
};

/// 表示言語[locale]の本文の代替フォント列（[bodyFontFamilyFor]と組で使う）。
///
/// 主フォントの白光明朝（中国語・韓国語では列の先頭）はNoto Serif JPと
/// 収録文字が完全に一致するので、Noto Serif JPが描く字は無い。それでも列に
/// 名前があると、その列で最初に文を並べたときに書体のデータ（約13.6MB）が
/// 読み込まれ、アプリを閉じるまでメモリに残る。描く字が変わらないよう、
/// この列からだけ外してある（`test/font_fallback_memory_test.dart`）。
List<String> bodyFontFallbackFor(Locale? locale) =>
    switch (locale?.languageCode) {
      'zh' => _chineseBodyFallbackUnderBodyFont,
      'ko' => _koreanBodyFallbackUnderBodyFont,
      _ => _bodyFallbackUnderBodyFont,
    };

const List<String> _bodyFallbackUnderBodyFont = <String>[
  'DelaGothicOne',
  'NotoSerifKRSubset',
  'NotoSerifSCSubset',
];

const List<String> _chineseBodyFallbackUnderBodyFont = <String>[
  'HakkouMincho',
  'DelaGothicOne',
  'NotoSerifKRSubset',
];

const List<String> _koreanBodyFallbackUnderBodyFont = <String>[
  'HakkouMincho',
  'DelaGothicOne',
  'NotoSerifSCSubset',
];

/// 本文の書式を受け継いで、主フォントだけを別の書体（monospace等）にした
/// 文の代替フォント列。[inherited]が[bodyFontFallbackFor]の列なら、外した
/// Noto Serif JPを戻した元の列（[kBodyFontFallback]等）を返す。別の書体には
/// 無い字をNoto Serif JPが描くことがあるため。それ以外の列はそのまま返す。
List<String>? fallbackUnderOtherFamily(List<String>? inherited) {
  if (inherited == null) return null;
  for (final (underBody, full) in const [
    (_bodyFallbackUnderBodyFont, kBodyFontFallback),
    (_chineseBodyFallbackUnderBodyFont, kChineseBodyFontFallback),
    (_koreanBodyFallbackUnderBodyFont, kKoreanBodyFontFallback),
  ]) {
    if (listEquals(inherited, underBody)) return full;
  }
  return inherited;
}

bool _usesUnifiedHeadingFont(Locale? locale) =>
    locale?.languageCode == 'zh' || locale?.languageCode == 'ko';

String headingFontFamilyFor(Locale? locale) =>
    _usesUnifiedHeadingFont(locale) ? bodyFontFamilyFor(locale) : 'Kuramubon';

List<String> headingFontFallbackFor(Locale? locale) =>
    _usesUnifiedHeadingFont(locale)
    ? bodyFontFallbackFor(locale)
    : kHeadingFontFallback;

/// Keeps the visual settings of a heading and applies the supplied locale.
TextStyle headingStyleFor(Locale? locale, TextStyle style) => style.copyWith(
  fontFamily: headingFontFamilyFor(locale),
  fontFamilyFallback: headingFontFallbackFor(locale),
);

TextStyle localizedHeadingStyle(BuildContext context, TextStyle style) =>
    headingStyleFor(Localizations.maybeLocaleOf(context), style);

/// ひらがな・カタカナ（小さいかなの拡張・半角カナも）を含むか。
bool _hasKana(String text) {
  for (final unit in text.codeUnits) {
    if ((unit >= 0x3040 && unit <= 0x30FF) ||
        (unit >= 0x31F0 && unit <= 0x31FF) ||
        (unit >= 0xFF66 && unit <= 0xFF9F)) {
      return true;
    }
  }
  return false;
}

/// 利用者が付けた名前（作品名・作者名）[text]を描く書式。
///
/// 中国語・韓国語の画面の主フォントは、UIの字だけを抜いた部分フォント。
/// ほかの人が日本語で付けた作品名は、部分フォントにある字（冒・雨…）と
/// 無い字（険・街…）で書体と太さが変わり、1つの題の中で字が混ざった
/// （「夜明けの冒険」の「険」だけが細かった）。かなを含む名前は日本語と
/// 見なし、全部の字がある白光明朝で描く。ほかの言語の画面と、かなの無い
/// 名前はそのまま。
TextStyle userNameStyleFor(Locale? locale, String text, TextStyle style) {
  if (!_usesUnifiedHeadingFont(locale) || !_hasKana(text)) {
    return style;
  }
  return style.copyWith(
    fontFamily: 'HakkouMincho',
    fontFamilyFallback: _bodyFallbackUnderBodyFont,
  );
}

TextStyle localizedUserNameStyle(
  BuildContext context,
  String text,
  TextStyle style,
) => userNameStyleFor(Localizations.maybeLocaleOf(context), text, style);
