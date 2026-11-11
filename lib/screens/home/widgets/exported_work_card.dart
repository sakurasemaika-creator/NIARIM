import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/font_fallback.dart';
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

  static final _filenameSeparators = RegExp(r'([_.-])');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    Widget actions() => Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        if (onCopy != null)
          IconButton(
            key: const Key('exportedWorkCopyButton'),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            color: foreground,
            icon: const Icon(Icons.content_copy_outlined, size: 20),
            tooltip: '${MaterialLocalizations.of(context).copyButtonLabel}: $name',
            onPressed: onCopy,
          ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          color: foreground,
          icon: const Icon(Icons.drive_file_move_outline, size: 20),
          tooltip: '$moveLabel: $name',
          onPressed: onMove,
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          color: foreground,
          icon: shareBusy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : const Icon(Icons.ios_share, size: 20),
          tooltip: '$shareLabel: $name',
          onPressed: onShare,
        ),
        if (onChangeThumbnail != null)
          PopupMenuButton<String>(
            key: const Key('exportedWorkMoreMenu'),
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onSelected: (value) {
              if (value == 'thumbnail') onChangeThumbnail?.call();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'thumbnail',
                child: Text(Localizations.localeOf(context).languageCode == 'ja'
                    ? 'サムネイル変更' : 'Change thumbnail'),
              ),
            ],
          ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          color: foreground,
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: '$deleteLabel: $name',
          onPressed: onDelete,
        ),
      ],
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: background,
      clipBehavior: Clip.antiAlias,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): onMove,
          const SingleActivator(LogicalKeyboardKey.contextMenu): onMove,
        },
        child: InkWell(
          onTap: onOpen,
          onLongPress: onMove,
          onSecondaryTap: onMove,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use a proportionate cover on phones without letting it grow
              // unreasonably large on desktop. The Table fills this cover to
              // the *actual* content height, including wrapped action rows.
              final coverWidth = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth * 0.24).clamp(72.0, 96.0)
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
                              title(),
                              const SizedBox(height: 4),
                              details(),
                              if (shareError != null) ...[
                                const SizedBox(height: 8),
                                shareFeedback(),
                              ],
                              const SizedBox(height: 4),
                              // Large controls are kept; on narrow cards they
                              // wrap rather than overflowing/clipping.
                              actions(),
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
    );
  }
}
