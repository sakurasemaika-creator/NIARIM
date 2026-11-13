import 'package:flutter/material.dart';

import '../screens/canvas/widgets/canvas_icon_button.dart';

/// Identical tap areas and toolbar-style outline across project, folder,
/// received-share and local-file collection actions.
class CollectionActionFrame extends StatelessWidget {
  const CollectionActionFrame({super.key, required this.child});

  static const double extent = 40;
  static const double glyphSize = 16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: CanvasIconButton.outlineColor(
              scheme.onSurfaceVariant,
              scheme,
            ),
            width: 1.25,
          ),
        ),
        child: ClipOval(child: child),
      ),
    );
  }
}

/// The empty state is a visible, neutral star (the same tone as the save/load
/// action icons), never a blank button. The whole circle is tappable.
class CollectionFavoriteButton extends StatelessWidget {
  const CollectionFavoriteButton({
    super.key,
    required this.favorite,
    required this.tooltip,
    required this.onPressed,
    this.itemId,
  });

  final bool favorite;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CollectionActionFrame(
      key: itemId == null ? null : Key('collectionFavorite_$itemId'),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: CollectionActionFrame.glyphSize,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: CollectionActionFrame.extent,
          height: CollectionActionFrame.extent,
        ),
        icon: Icon(
          Icons.star,
          color: favorite ? scheme.primary : scheme.onSurfaceVariant,
          size: CollectionActionFrame.glyphSize,
        ),
      ),
    );
  }
}
