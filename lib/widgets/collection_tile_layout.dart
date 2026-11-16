import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/font_fallback.dart';
import '../utils/duplicate_name.dart';
import '../utils/line_break.dart';
import 'collection_action_controls.dart';

/// Projects, exported works, shared files and folders use the same grid
/// geometry even when accessibility text scaling increases.
class CollectionTileGridDelegate
    extends SliverGridDelegateWithMaxCrossAxisExtent {
  const CollectionTileGridDelegate({
    required double maxExtent,
    required this.minHeight,
    this.textScale = 1,
  }) : super(
         maxCrossAxisExtent: maxExtent,
         crossAxisSpacing: 8,
         mainAxisSpacing: 8,
         childAspectRatio: 16 / 12,
       );

  final double minHeight;

  /// 文字の倍率（[collectionTileColumnCount]）。
  final double textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usual =
        SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: collectionTileColumnCount(
                maxCrossAxisExtent,
                constraints.crossAxisExtent,
                textScale: textScale,
              ),
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
            ).getLayout(constraints)
            as SliverGridRegularTileLayout;
    // 幅の狭いカード（右上のメニューと左下の星が左右に並ばない幅）は、
    // 2つが上下にも重ならないよう、絵の欄を2つ分の高さにする。
    final needed = usual.childCrossAxisExtent < _cornerActionsSpan
        ? minHeight + _cornerActionsSpan - kCollectionTilePictureMinHeight
        : minHeight;
    if (usual.childMainAxisExtent >= needed) return usual;
    return SliverGridRegularTileLayout(
      crossAxisCount: usual.crossAxisCount,
      mainAxisStride: needed + mainAxisSpacing,
      crossAxisStride: usual.crossAxisStride,
      childMainAxisExtent: needed,
      childCrossAxisExtent: usual.childCrossAxisExtent,
      reverseCrossAxis: usual.reverseCrossAxis,
    );
  }

  @override
  bool shouldRelayout(covariant CollectionTileGridDelegate oldDelegate) =>
      minHeight != oldDelegate.minHeight ||
      textScale != oldDelegate.textScale ||
      super.shouldRelayout(oldDelegate);
}

/// 表示サイズ（小・中・大）のカードの基準の幅。
const double kCollectionTileSmallExtent = 130;
const double kCollectionTileMediumExtent = 170;
const double kCollectionTileLargeExtent = 240;

/// 小のカードを3列に並べてよい、カードの幅の下限。右上のメニューと左下の
/// 星（どちらも[CollectionActionFrame.extent]）が置け、名前の帯に字が入る幅。
const double kCollectionTileMinWidth = 76;

/// カードの絵の欄の高さの下限（[collectionTileGridDelegate]）。
const double kCollectionTilePictureMinHeight = 80;

/// カードの絵の欄の隅に置く操作（右上のメニュー・左下の星）2つ分の長さ
/// （端からの余白4pxを含む）。カードの幅がこれより狭いと2つが左右に並ばない。
const double _cornerActionsSpan = 2 * (CollectionActionFrame.extent + 4);

/// 基準の幅[maxExtent]のカードを幅[width]に並べるときの列数。
///
/// 基準の幅だけで決めると、スマホの幅では近い2つの表示サイズが同じ列数に
/// なり、選んでも何も変わらなかった（360pxで大と中、390〜430pxで中と小）。
/// 小を基準に、中は小より、大は中より少なくとも1列少なくする（スマホは
/// 大1列・中2列・小3列。広い画面ではもともと基準の幅どおりで差がある）。
/// 分割画面・ポップアップの窓のように狭い幅でも、小のカードが
/// [kCollectionTileMinWidth]以上の幅で3列に並ぶ間（幅244px以上、画面の
/// 余白を含めて260px以上）は小を3列にして、3つとも違う列数にする。それより
/// 狭いと、大と中が同じ1列になる。
///
/// 文字を大きくしている端末（[textScale]が1より大きい）では、幅を文字の
/// 倍率で割った幅で決める。カードの名前の字も大きくなるので、列数が同じ
/// ままだと名前の帯に入る字の数が減り、文字2倍の幅320pxでは1行に4〜5字しか
/// 入らず、名前が「Archi / ve」「書き出 / しフ…」のように語の途中で切れた。
int collectionTileColumnCount(
  double maxExtent,
  double width, {
  double textScale = 1,
}) {
  if (textScale > 1) width /= textScale;
  int fit(double extent) => math.max(1, (width / (extent + 8)).ceil());
  if (maxExtent < kCollectionTileSmallExtent) return fit(maxExtent);
  // 幅[kCollectionTileMinWidth]以上のカードが並ぶ列の数。
  final roomy = ((width + 8) / (kCollectionTileMinWidth + 8)).floor();
  final small = math.max(fit(kCollectionTileSmallExtent), math.min(3, roomy));
  if (maxExtent <= kCollectionTileSmallExtent) return small;
  final medium = math.max(
    1,
    math.min(fit(kCollectionTileMediumExtent), small - 1),
  );
  if (maxExtent <= kCollectionTileMediumExtent) return medium;
  return math.max(1, math.min(fit(maxExtent), medium - 1));
}

TextStyle collectionTileCaptionStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  color:
      Theme.of(context).popupMenuTheme.textStyle?.color ??
      Theme.of(context).colorScheme.onSurface,
  fontWeight: FontWeight.w600,
  fontFamily: 'Kuramubon',
  fontFamilyFallback: kHeadingFontFallback,
);

/// [locationRow]が真なら、名前の下の場所の行（検索の結果が入っている
/// フォルダ）の高さも足す。
CollectionTileGridDelegate collectionTileGridDelegate(
  BuildContext context,
  double maxExtent, {
  bool locationRow = false,
  int nameLines = kCollectionTileNameLines,
}) {
  final minimumHeight =
      kCollectionTilePictureMinHeight +
      collectionTileNameHeight(context, lines: nameLines) +
      (locationRow ? collectionTileLocationHeight(context) : 0) +
      8;
  return CollectionTileGridDelegate(
    maxExtent: maxExtent,
    minHeight: minimumHeight,
    textScale: MediaQuery.textScalerOf(context).scale(1),
  );
}

/// カードの名前の行数の上限。
const int kCollectionTileNameLines = 2;

/// 名前を何行にも折り返して出す行（詳細表示・ゴミ箱のカード）の、見出しの
/// 書体（くらむぼん）の行の高さ（文字の大きさに対する倍率）。
///
/// くらむぼんの行の高さは文字の大きさちょうど（上0.88・下0.12）なのに、
/// 欧文のアクセント（é・ó）は上0.92〜1.11、q・gの下は0.26まで出るので、
/// そのままでは折り返した行どうしが重なった（「séquence」のアクセントが
/// 上の行の「longue」に、「q」の下が次の行の字に触れた）。
const double kWrappedNameLineHeight = 1.25;

/// カードの名前に出す長さの上限を決める幅（文字の倍率1倍の論理px）。
///
/// スマホの既定の大きさ（幅360px・小表示）のカードの名前の帯の幅
/// （(360 − 左右の余白16 − カードの間16) ÷ 3列 − 帯の余白12 ≒ 97.3px）。
/// 名前はこの幅の[kCollectionTileNameLines]行に入る長さまで出し、それより
/// 長い名前はそこまでで「…」にする（同梱の見出しの書体で全角14文字。
/// 英数字は字ごとの幅で決まる）。どの大きさのカードでも同じ名前は同じ
/// ところで切れ、名前の帯がこの幅以上のカードでは切った名前が2行に
/// 入りきる。帯がこれより狭いカード（幅320pxの小、列が1つ増えたばかりの
/// 幅、文字の倍率が大きいとき）は2行目の終わりで「…」。全部の名前は
/// 詳細表示と読み上げで分かる。
const double kCollectionTileNameReferenceWidth = 97;

/// カードの名前の字の書式（[Text]が実際に使う書式。太字の設定も含む）。
TextStyle _nameTextStyle(BuildContext context) => DefaultTextStyle.of(context)
    .style
    .merge(collectionTileCaptionStyle(context))
    .copyWith(
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.bold
          : FontWeight.w600,
    );

/// 書体を読み込み直したら（後から読み込む書体・テストの書体）、測った値を
/// 捨てる。
void _forgetMeasurementsWhenFontsChange() {
  if (_watchingFonts) return;
  _watchingFonts = true;
  PaintingBinding.instance.systemFonts.addListener(() {
    _nameHeights.clear();
    _locationHeights.clear();
    _displayNames.clear();
    _koreanWords.clear();
    _copyCaptions.clear();
  });
}

var _watchingFonts = false;

/// 名前の帯（[kCollectionTileNameLines]行分）の高さ。名前が1行でも2行
/// でも同じ高さにして、同じ行のカードの絵の高さをそろえる。
double collectionTileNameHeight(
  BuildContext context, {
  int lines = kCollectionTileNameLines,
}) {
  _forgetMeasurementsWhenFontsChange();
  final style = _nameTextStyle(context);
  final key = (
    style,
    MediaQuery.textScalerOf(context),
    Directionality.of(context),
    Localizations.maybeLocaleOf(context),
    lines,
  );
  final cached = _nameHeights[key];
  if (cached != null) return cached;
  // 欧文・漢字・ハングルの代わりの書体の行の高さも含めて測る。
  final painter = TextPainter(
    text: TextSpan(text: List.filled(lines, 'Ag国한').join('\n'), style: style),
    textScaler: key.$2,
    textDirection: key.$3,
    locale: key.$4,
  )..layout();
  final height = painter.height;
  painter.dispose();
  if (_nameHeights.length > 16) _nameHeights.clear();
  return _nameHeights[key] = height;
}

final _nameHeights =
    <(TextStyle, TextScaler, TextDirection, Locale?, int), double>{};

/// 場所の行の字。名前と同じ面（カードの帯）の上にあるので、名前と同じ
/// 文字色から作る（ページの文字色だと、帯だけ暗いテーマで溶けた）。
TextStyle collectionTileLocationStyle(BuildContext context) {
  final name = collectionTileCaptionStyle(context).color!;
  return TextStyle(fontSize: 10, color: name.withValues(alpha: name.a * 0.75));
}

/// 場所の行の高さ（フォルダの印と1行の字の高い方）。
double collectionTileLocationHeight(BuildContext context) {
  final style = DefaultTextStyle.of(
    context,
  ).style.merge(collectionTileLocationStyle(context));
  final key = (
    style,
    MediaQuery.textScalerOf(context),
    Directionality.of(context),
    Localizations.maybeLocaleOf(context),
  );
  _forgetMeasurementsWhenFontsChange();
  final cached = _locationHeights[key];
  if (cached != null) return cached;
  final painter = TextPainter(
    text: TextSpan(text: 'Ag国한', style: style),
    textScaler: key.$2,
    textDirection: key.$3,
    locale: key.$4,
  )..layout();
  final height = math.max(painter.height, key.$2.scale(12));
  painter.dispose();
  if (_locationHeights.length > 16) _locationHeights.clear();
  return _locationHeights[key] = height;
}

final _locationHeights =
    <(TextStyle, TextScaler, TextDirection, Locale?), double>{};

/// [name]を、カードの名前に出す長さ（[kCollectionTileNameReferenceWidth]の
/// [kCollectionTileNameLines]行分、文字の倍率1倍）までにする。それより長い
/// 名前は、「…」を付けてその長さに入るところまでにする。単語を空白で
/// 区切る言語では、途中で切れる単語を出さない。
String collectionTileDisplayName(BuildContext context, String name) {
  _forgetMeasurementsWhenFontsChange();
  final style = _nameTextStyle(context);
  final key = (
    name,
    style,
    Directionality.of(context),
    Localizations.maybeLocaleOf(context),
  );
  final cached = _displayNames[key];
  if (cached != null) return cached;
  final painter = TextPainter(
    maxLines: kCollectionTileNameLines,
    textDirection: key.$3,
    locale: key.$4,
  );
  String korean(String text) => _keepKoreanWordsWithin(
    text,
    style: style,
    textScaler: TextScaler.noScaling,
    textDirection: key.$3,
    locale: key.$4,
    maxWidth: kCollectionTileNameReferenceWidth,
  );
  final copy = copyMarkSplit(name);
  // 印と拡張子（「(コピー 12).mp4」）が上限の幅の1行に入らないときは、
  // カード（[_captionText]）と同じく、入る最初の段階（拡張子の前→番号の前→
  // 印の語の中）で折り返して測る。かたまりのまま測ると、頭をどれだけ
  // 縮めても2行に入らず、後ろを切って番号と拡張子を落とした（384pxの
  // カードでも「Hotel (コピー…」）。
  final markLine = copy == null
      ? null
      : _markAtFirstFittingLevel(
          copy.tail,
          (part) => _fitsOneLine(
            part,
            style: style,
            textScaler: TextScaler.noScaling,
            textDirection: key.$3,
            locale: key.$4,
            maxWidth: kCollectionTileNameReferenceWidth,
            wholeWidth: false,
          ),
        );
  bool fits(String text) {
    painter
      ..text = TextSpan(
        // カードと同じく、ハングルの語・複製の印は途中で折り返さず、ファイル
        // 名は区切りの記号の前で折り返して測る（印と拡張子のかたまりの中は
        // 除く）。
        text: copy != null && text.endsWith(copy.tail)
            ? korean(
                    _nameHead(
                      text.substring(0, text.length - copy.tail.length),
                    ),
                  ) +
                  markLine!
            : korean(_nameHead(text)),
        style: style,
      )
      ..layout(maxWidth: kCollectionTileNameReferenceWidth);
    return !painter.didExceedMaxLines;
  }

  var shown = name;
  // 複製の名前は、印（「(コピー 2)」）を残したまま元の名前の頭を縮める
  // （後ろを切ると、どの複製か分からなくなる）。
  final keepingMark = fits(name) ? null : _shortenKeepingCopyMark(name, fits);
  if (keepingMark != null) {
    shown = keepingMark;
  } else if (copy != null && !fits(name)) {
    // 頭の1字と印でも上限に入らない複製の名前も、印・番号・拡張子は残し、
    // 頭だけを1字と「…」にする（実際の幅での折り返しは[_captionText]）。
    final head = copy.head.characters;
    shown = head.length < 2 ? name : '${head.first}…${copy.tail}';
  } else if (!fits(name)) {
    final characters = name.characters.toList();
    // 「…」を付けて入る、一番長い名前の頭（字の数で二分探索）。
    var low = 0;
    var high = characters.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (fits('${characters.take(middle).join().trimRight()}…')) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    var text = characters.take(low).join();
    // 語を空白で区切って書く字（英字・ハングル等）の語の途中で切れるとき
    // だけ、その語を出さない。漢字・かなはどの字の間で切ってもよいので、
    // 名前に空白があっても上限まで出す。
    if (low > 0 &&
        _inSpacedWord(characters[low - 1]) &&
        _inSpacedWord(characters[low])) {
      final space = text.lastIndexOf(RegExp(r'\s'));
      if (space >= text.length ~/ 2) text = text.substring(0, space);
    }
    shown = '${text.trimRight()}…';
  }
  painter.dispose();
  if (_displayNames.length > 512) _displayNames.clear();
  return _displayNames[key] = shown;
}

final _displayNames = <(String, TextStyle, TextDirection, Locale?), String>{};

/// [text]を1行に並べたときの幅が[maxWidth]以下か。
///
/// [wholeWidth]が偽なら、途中で切れない部分がどれも1行に入るか（行を変えて
/// よい所で折り返した最も広い部分の幅）。
bool _fitsOneLine(
  String text, {
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required Locale? locale,
  required double maxWidth,
  bool wholeWidth = true,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textScaler: textScaler,
    textDirection: textDirection,
    locale: locale,
  )..layout();
  final fits =
      (wholeWidth ? painter.width : painter.minIntrinsicWidth) <= maxWidth;
  painter.dispose();
  return fits;
}

/// 複製の名前の後ろの印と拡張子[tail]（「 (copy 12).mp4」）を、名前の
/// 欄に描く文にする。[fits]は、渡した文の途中で切れない部分（かたまり）が
/// どれも欄の1行に入るか。印・番号・拡張子が1行に入るなら1つのかたまり、
/// 入らなければ[_MarkBreaks]の順（閉じ括弧と拡張子の間→印の語と番号の間→
/// 印の語の中で両側に2字以上）に、入る最初の段階まで折り返せる所を足す。
/// かたまりのままだと、欄より広いかたまりは途中のどこかで切れた
/// （「(コピー 12).gi / f」「(copy / 12).mp4」）。印の語の中を先に折り返すと、
/// 文字2倍の360pxで「Hotel (c / op / y).mp4」と1字ずつに切れた。
String copyMarkLineText(String tail, bool Function(String text) fits) =>
    _markAtFirstFittingLevel(tail, fits);

/// 複製の印の中で行を変えてよい所の段階（少ない順）。印・番号・拡張子が
/// 1行に入らないときだけ、入る最初の段階まで進める。
enum _MarkBreaks {
  /// 印・番号・拡張子を1つのかたまりにする（名前と印の間では行を変えて
  /// よい）。
  none,

  /// 閉じ括弧と拡張子の間（「(copy 2) / .mp4」。拡張子の中では折り返さない）。
  beforeExtension,

  /// それと、印の語と番号の間（「(copy / 2).mp4」）。
  beforeNumber,

  /// それと、印の語の中。両側に2字以上残し（「(co / py 2)」。「(c / opy」
  /// 「(cop / y」にしない）、長音・小書きの仮名の前では行を変えない。
  insideWord,

  /// 語の中で両側に2字以上残して折っても、印の部分が1行に入らないほど狭い
  /// ときの最後の手段：印の語の字の間ならどこでも（長音・小書きの仮名の前を
  /// 除く。「(コ / ピー)」）。これが無いと、行に入らない部分を段落が字の途中で
  /// 切り、閉じ括弧だけが次の行へ落ちる（文字2倍・320pxの作品一覧の行で
  /// 「(コピー / )」「（副本 / ）」）。
  anywhereInWord,
}

/// 印と拡張子[tail]を、段階[level]まで折り返せるようにした描く文。
/// 折り返さない字の間には単語結合子、印の中の空白は改行しない空白、
/// 折り返してよい所は幅の無い空白（番号の前の空白はそのまま）にする。
/// 前の空白（名前と印の間）はそのまま残す。
String _markWithBreaks(String tail, _MarkBreaks level) {
  final lead = tail.length - tail.trimLeft().length;
  final chars = tail.substring(lead).characters.toList();
  final close = chars.lastIndexWhere((char) => char == ')' || char == '）');
  bool allows(_MarkBreaks needed) => level.index >= needed.index;
  final out = StringBuffer(tail.substring(0, lead));
  for (var i = 0; i < chars.length; i++) {
    final char = chars[i];
    if (char == ' ') {
      // 番号の前の空白でだけ行を変えてよい。
      final beforeNumber =
          i + 1 < chars.length && _digit.hasMatch(chars[i + 1]);
      out.write(
        beforeNumber && allows(_MarkBreaks.beforeNumber) ? ' ' : '\u00a0',
      );
      continue;
    }
    if (i > 0 && chars[i - 1] != ' ') {
      final previous = chars[i - 1];
      final bool breaks;
      if (close >= 0 && i == close + 1) {
        breaks = allows(_MarkBreaks.beforeExtension);
      } else if (close >= 0 && i > close) {
        breaks = false;
      } else if (_letter.hasMatch(previous) && _digit.hasMatch(char)) {
        breaks = allows(_MarkBreaks.beforeNumber);
      } else if (allows(_MarkBreaks.insideWord) &&
          _letter.hasMatch(previous) &&
          _letter.hasMatch(char) &&
          !isNoLineStartCharacter(char)) {
        var start = i - 1;
        while (start > 0 && _letter.hasMatch(chars[start - 1])) {
          start--;
        }
        var end = i + 1;
        while (end < chars.length && _letter.hasMatch(chars[end])) {
          end++;
        }
        breaks =
            level == _MarkBreaks.anywhereInWord ||
            (i - start >= 2 && end - i >= 2);
      } else {
        breaks = false;
      }
      // 幅の無い空白（ZERO WIDTH SPACE）：ここで行を変えてよい。
      out.write(breaks ? '\u200b' : '\u2060');
    }
    out.write(char);
  }
  return out.toString();
}

final _letter = RegExp(r'^\p{L}$', unicode: true);
final _digit = RegExp(r'^\d$');

/// [_MarkBreaks]の段階（[from]から）ごとの、印と拡張子[tail]の描く文
/// （前の段階と同じになる段階は除く。拡張子・番号の無い印、短い語の印）。
List<(_MarkBreaks, String)> _markLevels(
  String tail, {
  _MarkBreaks from = _MarkBreaks.none,
}) {
  final levels = <(_MarkBreaks, String)>[];
  for (final level in _MarkBreaks.values.skip(from.index)) {
    final text = _markWithBreaks(tail, level);
    if (levels.isEmpty || levels.last.$2 != text) levels.add((level, text));
  }
  return levels;
}

/// 印と拡張子[tail]を、[fits]（途中で切れない部分がどれも1行に入るか）が
/// 真になる最初の段階で折り返せるようにした描く文と、その段階。どの段階
/// でも入らないときは、いちばん折り返せる形。
(_MarkBreaks, String) _firstFittingMarkLevel(
  String tail,
  bool Function(String) fits,
) {
  final levels = _markLevels(tail);
  return levels.firstWhere(
    (level) => fits(level.$2),
    orElse: () => levels.last,
  );
}

/// [_firstFittingMarkLevel]の描く文。
String _markAtFirstFittingLevel(String tail, bool Function(String) fits) =>
    tail.trim().isEmpty ? tail : _firstFittingMarkLevel(tail, fits).$2;

/// 複製の名前[name]を、後ろの印と拡張子（「 (copy 2)」「（副本）.png」）を
/// 残したまま、元の名前の頭を「…」で縮めて[fits]に入るようにする
/// （「Bravo Char… (copy 2)」）。頭は少なくとも1字残す（「… (copy 2)」だけ
/// では、どの名前の複製か分からない）。語を空白で区切る字の語の途中で切れる
/// ときは、[collectionTileDisplayName]と同じくその語を出さない。複製の名前
/// でない・頭の1字と印でも入らないときはnull。
String? _shortenKeepingCopyMark(String name, bool Function(String) fits) {
  final split = copyMarkSplit(name);
  if (split == null) return null;
  var head = split.head;
  // 一度縮めた名前（「Bravo…」）をさらに縮めるときは、前の「…」を外す。
  if (head.endsWith('…')) head = head.substring(0, head.length - 1);
  final characters = head.characters.toList();
  String candidate(String start) => '${start.trimRight()}…${split.tail}';
  // 頭が1字なら縮められない（「H… (copy 2)」は何も省いていない）。
  if (characters.length < 2 || !fits(candidate(characters.first))) {
    return null;
  }
  var low = 1;
  var high = characters.length - 1;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (fits(candidate(characters.take(middle).join()))) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  var text = characters.take(low).join();
  if (low > 0 &&
      low < characters.length &&
      _inSpacedWord(characters[low - 1]) &&
      _inSpacedWord(characters[low])) {
    final space = text.lastIndexOf(RegExp(r'\s'));
    if (space >= text.length ~/ 2) text = text.substring(0, space);
  }
  return candidate(text);
}

/// カードの名前の帯に描く文。複製の名前は印を1つのかたまりにし、帯の幅
/// （[maxWidth]）の2行に入らなければ、印を残したまま頭を縮める（文の
/// 終わりで切ると、印が「(co…」と切れた）。ハングルの語は途中で折り返さない。
/// 長音・小書きの仮名は行の頭に来ない。
///
/// 印・番号・拡張子が帯の1行に入らない（狭いカード・大きな文字）ときは、
/// [_MarkBreaks]の順（閉じ括弧と拡張子の間→印の語と番号の間→印の語の中で
/// 両側に2字以上）に、印の部分がどれも1行に入る最初の段階で折り返し、
/// 頭を1字と「…」まで縮める（「H… (copy 2) / .mp4」）。その段階では頭を
/// 1字も残せないときだけ、次の段階へ進めて頭を残す（「Hotel (copy / 2).mp4」）。
/// 以前は先に印の語の中で折り返し、「Hotel (copi / e).mp4」「Hotel (cop /
/// y 2).mp4」と1字だけを残し、日本語は「(コピ / ー 2)」と長音が行の頭に
/// 来た。その前は頭を縮めるのを諦めて元の名前に戻り、行の数の上限で
/// 「Hotel / (cop…」と番号ごと切れた。
String _captionText(
  BuildContext context,
  String name,
  String shown,
  double maxWidth,
) {
  final style = _nameTextStyle(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);
  final locale = Localizations.maybeLocaleOf(context);
  // 印が帯の1行に入るか（[whole]が偽なら、途中で切れない部分がどれも入るか）。
  bool markFits(String part, {bool whole = true}) => _fitsOneLine(
    part,
    style: style,
    textScaler: textScaler,
    textDirection: textDirection,
    locale: locale,
    maxWidth: maxWidth,
    wholeWidth: whole,
  );

  String korean(String text) => _keepKoreanWordsWithin(
    text,
    style: style,
    textScaler: textScaler,
    textDirection: textDirection,
    locale: locale,
    maxWidth: maxWidth,
  );
  final split = copyMarkSplit(shown);
  // ファイル名は区切りの記号の前で折り返す（印と拡張子のかたまりの中は
  // 除く。かたまりの中で折り返せると「(コピー 12) / .mp4」と切れる）。
  String separated(String text) => split != null && text.endsWith(split.tail)
      ? _nameHead(text.substring(0, text.length - split.tail.length)) +
            split.tail
      : _nameHead(text);
  String prepared(String text) =>
      korean(keepCopyMarkTogether(separated(text), name: text, fits: markFits));
  if (split == null) return prepared(shown);
  final key = (name, shown, style, textScaler, textDirection, locale, maxWidth);
  final cached = _copyCaptions[key];
  if (cached != null) return cached;
  final painter = TextPainter(
    maxLines: kCollectionTileNameLines,
    textScaler: textScaler,
    textDirection: textDirection,
    locale: locale,
  );
  bool fitsAs(String Function(String) prepare, String text) {
    painter
      ..text = TextSpan(text: prepare(text), style: style)
      ..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  String result;
  final mark = split.tail.trimLeft();
  if (markFits(keepPartsTogether(mark, [mark]))) {
    bool fits(String text) => fitsAs(prepared, text);
    result = prepared(
      fits(shown) ? shown : _shortenKeepingCopyMark(name, fits) ?? shown,
    );
  } else {
    // 印の中で折り返す：頭は語のまま（ハングルの語は途中で折り返さない）、
    // 印は、印の部分がどれも帯の1行に入る最初の段階から折り返せるように
    // する。その段階で名前の頭を1字も残せない（「… (copy 2) / .mp4」）とき
    // だけ、次の段階へ進めて頭を残す（「Hotel (copy / 2).mp4」。「…」だけ
    // では、どの名前の複製か分からない）。
    final tail = split.tail;
    final (first, _) = _firstFittingMarkLevel(
      tail,
      (text) => markFits(text, whole: false),
    );
    // 語の中のどこでも折る段階は、印の部分が1行に入らないときだけ（頭を
    // 残すために1字だけを行に残さない）。
    List<(_MarkBreaks, String)> levelsOf(String text) => [
      for (final level in _markLevels(text, from: first))
        if (level.$1 != _MarkBreaks.anywhereInWord ||
            first == _MarkBreaks.anywhereInWord)
          level,
    ];
    final levels = levelsOf(tail);
    String? withHead;
    for (final (_, marked) in levels) {
      String breakable(String text) =>
          korean(_nameHead(text.substring(0, text.length - tail.length))) +
          marked;
      bool fits(String text) => fitsAs(breakable, text);
      if (fits(shown)) {
        withHead = breakable(shown);
      } else if (_shortenKeepingCopyMark(name, fits) case final shorter?) {
        withHead = breakable(shorter);
      } else if (_squeezedHead(name, marked) case final squeezed?
          when fitsAs((_) => squeezed, squeezed)) {
        // 印の前の空白を詰めれば頭の1字が入る（「H…(copy 2) / .mp4」）。
        withHead = squeezed;
      }
      if (withHead != null) break;
    }
    // 頭の1字も入らないほど狭いときは、頭を「…」にする。
    final ellipsis = [
      for (final (_, marked) in levels)
        if (fitsAs((_) => '…$marked', '…$marked')) '…$marked',
    ].firstOrNull;
    if (withHead ?? ellipsis case final fitting?) {
      result = fitting;
    } else {
      // それでも2行に入らないときは、印だけを出す（名前は読み上げと
      // 長押し・ホバーの吹き出しで分かる）。2行に入らなければ次の段階でも
      // 折り返すが、番号は失わない。
      final markOnly = tail.trimLeft();
      String? fitting(String text) {
        for (final (_, candidate) in levelsOf(text)) {
          if (fitsAs((_) => candidate, text)) return candidate;
        }
        return null;
      }

      // 拡張子まで2行に入らない（文字2倍の小さいカード）ときは、番号
      // （閉じ括弧）までを出して拡張子を「…」にする（行の数の上限で
      // 切ると「(コピ / ー 1」と番号の途中で切れた）。
      final close = markOnly.lastIndexOf(RegExp('[)）]')) + 1;
      result =
          fitting(markOnly) ??
          (close > 0 && close < markOnly.length
              ? fitting('${markOnly.substring(0, close)}…')
              : null) ??
          levelsOf(markOnly).last.$2;
    }
  }
  painter.dispose();
  if (_copyCaptions.length > 512) _copyCaptions.clear();
  return _copyCaptions[key] = result;
}

/// 複製の名前[name]の頭の1字と「…」に、前の空白を詰めた印（描く文
/// [marked]。[_markWithBreaks]の形）を続けた描く文。頭が1字だけの名前は
/// その字のまま。
String? _squeezedHead(String name, String marked) {
  final head = copyMarkSplit(name)?.head.characters;
  if (head == null || head.isEmpty) return null;
  return '${head.first}${head.length > 1 ? '…' : ''}${marked.trimLeft()}';
}

/// 名前の頭（複製の印の前）を描く文にする：ファイル名は区切りの記号
/// （「_」「.」「-」）の前で折り返し、長音・小書きの仮名は行の頭に来ない
/// ようにする。
String _nameHead(String text) =>
    keepJapaneseLineStartsAttached(breakableAtFileSeparators(text));

final _copyCaptions =
    <
      (String, String, TextStyle, TextScaler, TextDirection, Locale?, double),
      String
    >{};

/// [text]のハングルの語のうち、幅[maxWidth]の1行に入る語を途中で折り返さない
/// ようにする（[keepKoreanWordsTogetherWhere]。Flutterはハングルのどの字の
/// 間でも折り返すので、2行の名前が「애니메이션 만들 / 기 연습」のように語の
/// 途中で切れた）。1行に入らない長い語は、どこでも折り返せるまま。
String _keepKoreanWordsWithin(
  String text, {
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required Locale? locale,
  required double maxWidth,
}) {
  if (!containsHangul(text)) return text;
  final key = (text, style, textScaler, textDirection, locale, maxWidth);
  final cached = _koreanWords[key];
  if (cached != null) return cached;
  final painter = TextPainter(
    textScaler: textScaler,
    textDirection: textDirection,
    locale: locale,
  );
  final joined = keepKoreanWordsTogetherWhere(text, (word) {
    painter
      ..text = TextSpan(text: word, style: style)
      ..layout();
    return painter.width <= maxWidth;
  });
  painter.dispose();
  if (_koreanWords.length > 512) _koreanWords.clear();
  return _koreanWords[key] = joined;
}

final _koreanWords =
    <(String, TextStyle, TextScaler, TextDirection, Locale?, double), String>{};

/// [character]が、語を空白で区切って書く字（英字・数字・ハングル等）か。
/// 空白と、どの字の間でも行を変えてよい字（漢字・かな・全角の字）は偽。
bool _inSpacedWord(String character) {
  if (character.trim().isEmpty) return false;
  final rune = character.runes.first;
  return !((rune >= 0x2E80 && rune <= 0x303F) ||
      (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0x31F0 && rune <= 0x31FF) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xFF00 && rune <= 0xFFEF) ||
      (rune >= 0x20000 && rune <= 0x3FFFD));
}

/// The cover takes all available height above the name band. The name
/// shows on up to two lines (see [collectionTileDisplayName]); extended
/// metadata stays available in the detail view or preview.
///
/// [locationRow]が真なら、名前の下に場所の行（[location]、検索の結果が
/// 入っているフォルダ）を置く。場所の無いカードも同じ高さを空けて、同じ
/// 行のカードの絵の高さをそろえる。
Widget collectionTileCaption(
  BuildContext context,
  String name, {
  String? location,
  bool locationRow = false,
}) {
  final shown = collectionTileDisplayName(context, name);
  // 上限で切った字・語結合子を入れた字を描き、読み上げと文での検索
  // （find.text 等）には名前の全部を渡す。
  Widget nameText(String text) => Text.rich(
    TextSpan(text: text, semanticsLabel: name),
    semanticsLabel: name,
    maxLines: kCollectionTileNameLines,
    overflow: TextOverflow.ellipsis,
    style: collectionTileCaptionStyle(context),
  );
  final nameBand = SizedBox(
    height: collectionTileNameHeight(context),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: Tooltip(
        message: name,
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        // ハングルの語は、カードの幅の1行に入る語なら途中で折り返さない。
        // 複製の名前は、印（「(コピー 2)」）を途中で折り返さず、入らなければ
        // 印を残して頭を縮める。
        child: containsHangul(shown) || copyMarkSplit(shown) != null
            ? LayoutBuilder(
                builder: (context, constraints) => nameText(
                  _captionText(context, name, shown, constraints.maxWidth),
                ),
              )
            // ファイル名は区切りの記号の前で折り返す（字の途中で切らない）。
            // 長音・小書きの仮名は行の頭に来ない。
            : nameText(_nameHead(shown)),
      ),
    ),
  );
  final style = collectionTileLocationStyle(context);
  return ColoredBox(
    color:
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: !locationRow && location == null
          ? nameBand
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                nameBand,
                SizedBox(
                  height: collectionTileLocationHeight(context),
                  child: location == null
                      ? null
                      : Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: MediaQuery.textScalerOf(context).scale(12),
                              color: style.color,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    ),
  );
}

/// Same gentle elevation as ProjectListWidget's unselected tile cards.
Widget collectionTileShadow(BuildContext context, Widget child) =>
    AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
