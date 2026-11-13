import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/font_fallback.dart';

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
    if (usual.childMainAxisExtent >= minHeight) return usual;
    return SliverGridRegularTileLayout(
      crossAxisCount: usual.crossAxisCount,
      mainAxisStride: minHeight + mainAxisSpacing,
      crossAxisStride: usual.crossAxisStride,
      childMainAxisExtent: minHeight,
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

/// 基準の幅[maxExtent]のカードを幅[width]に並べるときの列数。
///
/// 基準の幅だけで決めると、スマホの幅では近い2つの表示サイズが同じ列数に
/// なり、選んでも何も変わらなかった（360pxで大と中、390〜430pxで中と小）。
/// 小を基準に、中は小より、大は中より少なくとも1列少なくする（スマホは
/// 大1列・中2列・小3列。広い画面ではもともと基準の幅どおりで差がある）。
int collectionTileColumnCount(double maxExtent, double width) {
  int fit(double extent) => math.max(1, (width / (extent + 8)).ceil());
  if (maxExtent <= kCollectionTileSmallExtent) return fit(maxExtent);
  final small = fit(kCollectionTileSmallExtent);
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
      80 +
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

/// カードの名前に出す長さの上限（全角16文字・半角32文字分）。
///
/// スマホの既定の大きさ（360px・小表示・文字の倍率1倍）のカードに、全角
/// 16文字が2行でちょうど入る。これより長い名前はこの長さまでで「…」にする
/// （どの大きさのカードでも同じ名前は同じところで切れる）。全部の名前は
/// 詳細表示と読み上げで分かる。
const int kCollectionTileNameMaxUnits = 32;

/// 名前の帯（[kCollectionTileNameLines]行分）の高さ。名前が1行でも2行
/// でも同じ高さにして、同じ行のカードの絵の高さをそろえる。
double collectionTileNameHeight(BuildContext context) {
  final style = DefaultTextStyle.of(context).style
      .merge(collectionTileCaptionStyle(context))
      .copyWith(
        fontWeight: MediaQuery.boldTextOf(context)
            ? FontWeight.bold
            : FontWeight.w600,
      );
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

/// [name]を、カードの名前に出す長さ（[kCollectionTileNameMaxUnits]、全角は
/// 2・半角は1と数える）までにする。超える名前はそこまでで「…」を付ける。
/// 単語を空白で区切る言語では、途中で切れる単語を出さない。
String collectionTileDisplayName(String name) {
  var units = 0;
  final kept = StringBuffer();
  for (final character in name.characters) {
    final width = _isWide(character.runes.first) ? 2 : 1;
    if (units + width > kCollectionTileNameMaxUnits) {
      var text = kept.toString();
      if (character.trim().isNotEmpty) {
        final space = text.lastIndexOf(RegExp(r'\s'));
        if (space >= text.length ~/ 2) text = text.substring(0, space);
      }
      return '${text.trimRight()}…';
    }
    units += width;
    kept.write(character);
  }
  return name;
}

// 全角（East Asian Widthの広い字）か。
bool _isWide(int rune) =>
    (rune >= 0x1100 && rune <= 0x115F) ||
    (rune >= 0x2E80 && rune <= 0x303E) ||
    (rune >= 0x3041 && rune <= 0x33FF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xA000 && rune <= 0xA4CF) ||
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFE30 && rune <= 0xFE4F) ||
    (rune >= 0xFF00 && rune <= 0xFF60) ||
    (rune >= 0xFFE0 && rune <= 0xFFE6) ||
    (rune >= 0x1F300 && rune <= 0x1F64F) ||
    (rune >= 0x1F900 && rune <= 0x1F9FF) ||
    (rune >= 0x20000 && rune <= 0x3FFFD);

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
  final nameBand = SizedBox(
    height: collectionTileNameHeight(context),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: Tooltip(
        message: name,
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        child: Text(
          collectionTileDisplayName(name),
          semanticsLabel: name,
          maxLines: kCollectionTileNameLines,
          overflow: TextOverflow.ellipsis,
          style: collectionTileCaptionStyle(context),
        ),
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
