import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Keep the same actions reachable when translated or enlarged labels no
/// longer fit. Width decisions use the actual button and count text styles.
class HomeSelectionToolbar extends StatelessWidget {
  const HomeSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDeselectAll,
    this.onCut,
    this.onCopy,
    this.onTrash,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onTrash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final buttonText =
        (theme.textButtonTheme.style?.textStyle?.resolve({}) ??
                theme.textTheme.labelLarge!)
            .copyWith(color: foreground);
    final countText = theme.textTheme.bodyMedium!.copyWith(color: foreground);
    final countLabel = l10n.homeSelectionCount(selectedCount);
    double widthOf(String label, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    Widget iconButton(
      String label,
      IconData icon,
      VoidCallback? action, {
      Color? color,
    }) => SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: label,
        icon: Icon(icon),
        onPressed: action,
        style: IconButton.styleFrom(
          foregroundColor: color ?? foreground,
          disabledForegroundColor: (color ?? foreground).withValues(
            alpha: 0.38,
          ),
          minimumSize: const Size(48, 48),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );

    Widget textButton(String label, VoidCallback action) => Tooltip(
      message: label,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 48),
          foregroundColor: foreground,
          textStyle: buttonText,
          visualDensity: VisualDensity.standard,
        ),
        onPressed: action,
        child: Text(label, maxLines: 1),
      ),
    );

    final widest = [
      widthOf(l10n.homeSelectionAllSelect, buttonText) + 8,
      widthOf(l10n.homeSelectionAllDeselect, buttonText) + 8,
      widthOf(countLabel, countText),
    ].fold<double>(48, (largest, width) => width > largest ? width : largest);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < widest * 3 + 48 * 3 + 2;
          final actions = [
            iconButton(l10n.commonCut, Icons.content_cut, onCut),
            iconButton(l10n.commonCopy, Icons.content_copy, onCopy),
            iconButton(
              l10n.homeMoveToTrash,
              Icons.delete,
              onTrash,
              color: theme.colorScheme.primary,
            ),
          ];
          if (compact) {
            final scopeControls = <Widget>[
              iconButton(
                l10n.homeSelectionAllSelect,
                Icons.select_all,
                onSelectAll,
              ),
              iconButton(
                l10n.homeSelectionAllDeselect,
                Icons.deselect,
                onDeselectAll,
              ),
              Expanded(
                child: Tooltip(
                  message: countLabel,
                  child: Semantics(
                    label: countLabel,
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 48,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$selectedCount',
                            key: const Key('home-selection-count'),
                            style: countText,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ];
            if (constraints.maxWidth < 48 * 6) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: scopeControls),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: actions,
                  ),
                ],
              );
            }
            return Row(children: [...scopeControls, ...actions]);
          }
          return Row(
            children: [
              Expanded(
                child: textButton(l10n.homeSelectionAllSelect, onSelectAll),
              ),
              Expanded(
                child: textButton(l10n.homeSelectionAllDeselect, onDeselectAll),
              ),
              Expanded(
                child: Text(
                  countLabel,
                  key: const Key('home-selection-count'),
                  style: countText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}
