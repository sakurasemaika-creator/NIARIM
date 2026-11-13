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
    final usual = super.getLayout(constraints) as SliverGridRegularTileLayout;
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

TextStyle collectionTileCaptionStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  color:
      Theme.of(context).popupMenuTheme.textStyle?.color ??
      Theme.of(context).colorScheme.onSurface,
  fontWeight: FontWeight.w600,
  fontFamily: 'Kuramubon',
  fontFamilyFallback: kHeadingFontFallback,
);

CollectionTileGridDelegate collectionTileGridDelegate(
  BuildContext context,
  double maxExtent,
) {
  final caption = TextPainter(
    text: TextSpan(
      text: 'Ag国한',
      style: DefaultTextStyle.of(context).style
          .merge(collectionTileCaptionStyle(context))
          .copyWith(
            fontWeight: MediaQuery.boldTextOf(context)
                ? FontWeight.bold
                : FontWeight.w600,
          ),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    locale: Localizations.localeOf(context),
  )..layout();
  final minimumHeight = 80 + caption.height + 8;
  caption.dispose();
  return CollectionTileGridDelegate(
    maxExtent: maxExtent,
    minHeight: minimumHeight,
  );
}

/// The cover takes all available height above the single-line name band.
/// Extended metadata stays available in the detail view or preview.
Widget collectionTileCaption(BuildContext context, String name) => ColoredBox(
  color:
      Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surfaceContainer,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Tooltip(
      message: name,
      triggerMode: TooltipTriggerMode.manual,
      excludeFromSemantics: true,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: collectionTileCaptionStyle(context),
      ),
    ),
  ),
);

/// Same gentle elevation as ProjectListWidget's unselected tile cards.
Widget collectionTileShadow(BuildContext context, Widget child) =>
    AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
