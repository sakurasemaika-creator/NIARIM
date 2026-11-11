import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/font_fallback.dart';

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
    Widget title() =>
        Text(displayName, semanticsLabel: name, style: titleStyle);
    Widget details() => Text(metadata, style: detailStyle);
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
    Widget actions() => Row(
      mainAxisSize: MainAxisSize.min,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Inline only when the full name fits beside the icon/actions.
                // Otherwise give the name its own full-width, wrapping row.
                final nameWidth = constraints.maxWidth - 40 - 12 -
                    (onCopy == null ? 144 : 192) - 12;
                final measure = TextPainter(
                  text: TextSpan(
                    text: displayName,
                    style: MediaQuery.boldTextOf(context)
                        ? titleStyle.copyWith(fontWeight: FontWeight.bold)
                        : titleStyle,
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.maybeLocaleOf(context),
                  maxLines: 1,
                )..layout(maxWidth: nameWidth > 0 ? nameWidth : 0);
                final inline = nameWidth > 0 && !measure.didExceedMaxLines;
                measure.dispose();
                final badge = SizedBox(
                  width: 40,
                  height: 40,
                  child: thumbnailHidden
                      ? Icon(icon, color: foreground)
                      : thumbnailPath != null
                          ? Image.file(
                              File(thumbnailPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Icon(icon, color: foreground),
                            )
                          : Icon(icon, color: foreground),
                );
                if (inline) {
                  return Row(
                    children: [
                      badge,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title(),
                            details(),
                            if (shareError != null) ...[
                              const SizedBox(height: 8),
                              shareFeedback(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      actions(),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title(),
                    const SizedBox(height: 4),
                    details(),
                    if (shareError != null) ...[
                      const SizedBox(height: 8),
                      shareFeedback(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [badge, actions()],
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
