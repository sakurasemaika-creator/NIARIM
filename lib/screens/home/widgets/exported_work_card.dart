import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';

/// A saved export keeps its complete identity visible, including large text.
class ExportedWorkCard extends StatelessWidget {
  const ExportedWorkCard({
    super.key,
    required this.name,
    required this.metadata,
    required this.icon,
    required this.shareLabel,
    required this.deleteLabel,
    required this.onOpen,
    required this.onMove,
    required this.onShare,
    required this.onDelete,
  });

  final String name;
  final String metadata;
  final IconData icon;
  final String shareLabel;
  final String deleteLabel;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onShare;
  final VoidCallback onDelete;

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
    Widget title() => Text(name, style: titleStyle);
    Widget details() => Text(metadata, style: detailStyle);
    Widget actions() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          color: foreground,
          icon: const Icon(Icons.ios_share, size: 20),
          tooltip: '$shareLabel: $name',
          onPressed: onShare,
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
      child: InkWell(
        onTap: onOpen,
        onLongPress: onMove,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Inline only when the full name fits beside the icon/actions.
              // Otherwise give the name its own full-width, wrapping row.
              final nameWidth = constraints.maxWidth - 40 - 12 - 96 - 12;
              final measure = TextPainter(
                text: TextSpan(
                  text: name,
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
                child: Icon(icon, color: foreground),
              );
              if (inline) {
                return Row(
                  children: [
                    badge,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title(), details()],
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
    );
  }
}
