import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/collection_action_controls.dart';
import '../../../widgets/collection_tile_layout.dart';
import '../../../widgets/home_collection_selection_scope.dart';
import 'folder_thumbnail.dart';

/// A saved export keeps its complete identity visible, including large text.
class ExportedWorkCard extends StatelessWidget {
  const ExportedWorkCard({
    super.key,
    required this.name,
    required this.metadata,
    required this.icon,
    required this.moveLabel,
    required this.shareLabel,
    required this.deleteLabel,
    required this.onOpen,
    required this.onMove,
    this.onCopy,
    required this.onShare,
    required this.onDelete,
    this.onChangeThumbnail,
    this.thumbnailPath,
    this.originalMediaPath,
    this.thumbnailHidden = false,
    this.shareBusy = false,
    this.shareError,
    this.gridTile = false,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.selectionId,
  });

  final String name;
  final String metadata;
  final IconData icon;
  final String moveLabel;
  final String shareLabel;
  final String deleteLabel;
  final VoidCallback? onOpen;
  final VoidCallback onMove;
  final VoidCallback? onCopy;
  final VoidCallback? onChangeThumbnail;
  final String? thumbnailPath;
  final String? originalMediaPath;
  final bool thumbnailHidden;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool shareBusy;
  final String? shareError;

  /// Match the project collection's small/medium/large card presentation.
  final bool gridTile;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final String? selectionId;

  static final _filenameSeparators = RegExp(r'([_.-])');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = HomeCollectionSelectionScope.maybeOf(context);
    final selectionActive =
        selection != null && selection.active && selectionId != null;
    final selectTap = selectionActive
        ? () => selection.onToggle(selectionId!)
        : onOpen;
    final selectLongPress = selection != null && selectionId != null
        ? () => selection.onLongPress(selectionId!)
        : onMove;
    final foreground =
        theme.popupMenuTheme.textStyle?.color ?? theme.colorScheme.onSurface;
    final background = theme.cardTheme.color ?? theme.colorScheme.surface;
    final titleStyle = theme.textTheme.bodyLarge!.copyWith(
      color: foreground,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );
    final detailStyle = theme.textTheme.bodySmall!.copyWith(
      fontSize: 11,
      color: foreground,
    );
    // Allow natural filename breaks without changing the saved/accessibility name.
    final displayName = name.replaceAllMapped(
      _filenameSeparators,
      (match) => '\u200B${match[0]}',
    );
    Widget title() => Text(
      displayName,
      key: const Key('exportedWorkTitle'),
      semanticsLabel: name,
      // A very long filename at 2x text size must not grow beyond the
      // screen-height card; the original full name remains in semantics and
      // in the file detail view.
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    Widget details() => Text(
      metadata,
      key: const Key('exportedWorkMetadata'),
      style: detailStyle,
    );
    // 共有できなかったときの知らせ。文字の色はテーマ・外観のメニュー文字色
    // （このカードの文字と同じ役目）で、色ではなく先頭の印と文で知らせる。
    Widget shareFeedback() => Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              shareError!,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
    Widget favorite() => CollectionFavoriteButton(
      favorite: isFavorite,
      tooltip: isFavorite
          ? AppLocalizations.of(context)!.colorPickerFavoriteRemove
          : AppLocalizations.of(context)!.colorPickerFavoriteAdd,
      onPressed: onToggleFavorite,
    );
    Widget menu() => CollectionActionFrame(
      child: PopupMenuButton<String>(
        key: const Key('exportedWorkMoreMenu'),
        padding: EdgeInsets.zero,
        icon: shareBusy
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : const Icon(
                Icons.more_vert,
                size: CollectionActionFrame.glyphSize,
              ),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        onSelected: (action) {
          switch (action) {
            case 'open':
              onOpen?.call();
            case 'copy':
              onCopy?.call();
            case 'move':
              onMove();
            case 'share':
              onShare?.call();
            case 'thumbnail':
              onChangeThumbnail?.call();
            case 'delete':
              onDelete?.call();
          }
        },
        itemBuilder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return [
            PopupMenuItem(
              value: 'open',
              enabled: onOpen != null,
              child: Text(l10n.projectListOpenAction),
            ),
            PopupMenuItem(
              value: 'share',
              enabled: onShare != null && !shareBusy,
              child: Text(shareLabel),
            ),
            if (onChangeThumbnail != null)
              PopupMenuItem(
                value: 'thumbnail',
                child: Text(l10n.thumbnailChangeAction),
              ),
            PopupMenuItem(
              value: 'delete',
              enabled: onDelete != null,
              child: Text(
                deleteLabel,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ];
        },
      ),
    );

    // The whole left edge of the card is its cover. Keeping the title and
    // metadata in a separate column avoids moving them above the thumbnail
    // when filenames wrap or accessibility text size increases.
    Widget thumbnail() {
      final path = thumbnailPath ?? originalMediaPath;
      return ColoredBox(
        key: const Key('exportedWorkThumbnailArea'),
        color: theme.colorScheme.surfaceContainerHighest,
        child: thumbnailHidden || path == null
            ? Center(child: Icon(icon, color: foreground))
            : FolderCoverMedia(path: path, cacheWidth: 256),
      );
    }

    if (gridTile) {
      return HomeCollectionSelectionSurface(
        selectionId: selectionId ?? name,
        child: collectionTileShadow(
          context,
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.transparent, width: 2),
            ),
            child: InkWell(
              onTap: selectTap,
              onLongPress: selectLongPress,
              onSecondaryTap: selectLongPress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbnail(),
                        // Keep grid actions in the same corners as Projects:
                        // menu at top-right, favorite at bottom-left.
                        if (!selectionActive)
                          Positioned(top: 4, right: 4, child: menu()),
                        if (!selectionActive && onToggleFavorite != null)
                          Positioned(
                            key: const Key(
                              'exportedWorkGridFavoriteBottomLeft',
                            ),
                            bottom: 4,
                            left: 4,
                            child: favorite(),
                          ),
                      ],
                    ),
                  ),
                  collectionTileCaption(context, name),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return HomeCollectionSelectionSurface(
      selectionId: selectionId ?? name,
      grid: false,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: background,
        clipBehavior: Clip.antiAlias,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): onMove,
            const SingleActivator(LogicalKeyboardKey.contextMenu): onMove,
          },
          child: InkWell(
            onTap: selectTap,
            onLongPress: selectLongPress,
            onSecondaryTap: selectLongPress,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use a proportionate cover on phones without letting it grow
                // unreasonably large on desktop. The Table fills this cover to
                // the *actual* content height, including wrapped action rows.
                final coverWidth = constraints.maxWidth.isFinite
                    ? (constraints.maxWidth * 0.24).clamp(72.0, 96.0).toDouble()
                    : 88.0;
                return Table(
                  columnWidths: {
                    0: FixedColumnWidth(coverWidth),
                    1: const FixedColumnWidth(12),
                    2: const FlexColumnWidth(),
                  },
                  children: [
                    TableRow(
                      children: [
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.fill,
                          child: thumbnail(),
                        ),
                        const SizedBox.shrink(),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.top,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: title()),
                                    const SizedBox(width: 4),
                                    if (!selectionActive &&
                                        onToggleFavorite != null) ...[
                                      favorite(),
                                      const SizedBox(width: 4),
                                    ],
                                    if (!selectionActive) menu(),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                details(),
                                if (shareError != null) ...[
                                  const SizedBox(height: 8),
                                  shareFeedback(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
