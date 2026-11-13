import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/font_fallback.dart';
import '../utils/line_break.dart';
import 'collection_action_controls.dart';

/// Projects, exported works, shared files and folders use the same grid
/// geometry even when accessibility text scaling increases.
class CollectionTileGridDelegate
    extends SliverGridDelegateWithMaxCrossAxisExtent {
  const CollectionTileGridDelegate({
    required double maxExtent,
    required this.minHeight,
  }) : super(
         maxCrossAxisExtent: maxExtent,
         crossAxisSpacing: 8,
         mainAxisSpacing: 8,
         childAspectRatio: 16 / 12,
       );

  final double minHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usual =
        SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: collectionTileColumnCount(
                maxCrossAxisExtent,
                constraints.crossAxisExtent,
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
      minHeight != oldDelegate.minHeight || super.shouldRelayout(oldDelegate);
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
int collectionTileColumnCount(double maxExtent, double width) {
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
}) {
  final minimumHeight =
      kCollectionTilePictureMinHeight +
      collectionTileNameHeight(context) +
      (locationRow ? collectionTileLocationHeight(context) : 0) +
      8;
  return CollectionTileGridDelegate(
    maxExtent: maxExtent,
    minHeight: minimumHeight,
  );
}

/// カードの名前の行数の上限。
const int kCollectionTileNameLines = 2;

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
  });
}

var _watchingFonts = false;

/// 名前の帯（[kCollectionTileNameLines]行分）の高さ。名前が1行でも2行
/// でも同じ高さにして、同じ行のカードの絵の高さをそろえる。
double collectionTileNameHeight(BuildContext context) {
  _forgetMeasurementsWhenFontsChange();
  final style = _nameTextStyle(context);
  final key = (
    style,
    MediaQuery.textScalerOf(context),
    Directionality.of(context),
    Localizations.maybeLocaleOf(context),
  );
  final cached = _nameHeights[key];
  if (cached != null) return cached;
  // 欧文・漢字・ハングルの代わりの書体の行の高さも含めて測る。
  final painter = TextPainter(
    text: TextSpan(
      text: List.filled(kCollectionTileNameLines, 'Ag国한').join('\n'),
      style: style,
    ),
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
    <(TextStyle, TextScaler, TextDirection, Locale?), double>{};

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
  bool fits(String text) {
    painter
      ..text = TextSpan(
        // カードと同じく、ハングルの語は途中で折り返さずに測る。
        text: _keepKoreanWordsWithin(
          text,
          style: style,
          textScaler: TextScaler.noScaling,
          textDirection: key.$3,
          locale: key.$4,
          maxWidth: kCollectionTileNameReferenceWidth,
        ),
        style: style,
      )
      ..layout(maxWidth: kCollectionTileNameReferenceWidth);
    return !painter.didExceedMaxLines;
  }

  var shown = name;
  if (!fits(name)) {
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
        child: containsHangul(shown)
            ? LayoutBuilder(
                builder: (context, constraints) => nameText(
                  _keepKoreanWordsWithin(
                    shown,
                    style: _nameTextStyle(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    textDirection: Directionality.of(context),
                    locale: Localizations.maybeLocaleOf(context),
                    maxWidth: constraints.maxWidth,
                  ),
                ),
              )
            : nameText(shown),
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
