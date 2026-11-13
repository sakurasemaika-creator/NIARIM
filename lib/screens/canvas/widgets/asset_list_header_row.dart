import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/theme_service.dart';
import '../../../widgets/first_that_fits.dart';

/// The heading row of the brush, screentone and stamp lists: the list's name
/// (when the panel shows one), the "favorites only" filter and the search
/// toggle.
///
/// Text is never shrunk. When the filter's name does not fit beside the
/// others, the filter shows only its star and its name moves to the tooltip
/// (long press on touch, hover with a mouse) and the screen-reader label.
/// When even then the list's name does not fit, the list's name is left out
/// rather than cut. The choice follows the measured width, so it is the same
/// on a phone, a tablet or a PC window of the same width.
class AssetListHeaderRow extends StatelessWidget {
  const AssetListHeaderRow({
    super.key,
    this.title,
    required this.favoritesOnly,
    required this.onFavoritesOnlyChanged,
    required this.searching,
    required this.onSearchPressed,
  });

  /// The list's name, or null where the window around it already shows it.
  final String? title;
  final bool favoritesOnly;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final bool searching;
  final VoidCallback onSearchPressed;

  /// The key of the favorites filter (the same in both forms).
  static const Key favoritesKey = ValueKey('asset-favorites-only');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = l10n.customAutomationFavoritesOnly;
    Widget star() => Icon(
      favoritesOnly ? Icons.star : Icons.star_outline,
      size: 16,
      color: favoritesOnly
          ? ThemeService.activeColorScheme.tertiary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final labelled = FilterChip(
      key: favoritesKey,
      avatar: star(),
      label: Text(name, style: const TextStyle(fontSize: 11)),
      selected: favoritesOnly,
      tooltip: l10n.creativePanelFavoritesOnlyTooltip,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: onFavoritesOnlyChanged,
    );
    final iconOnly = FilterChip(
      key: favoritesKey,
      label: Icon(
        favoritesOnly ? Icons.star : Icons.star_outline,
        size: 16,
        semanticLabel: name,
        color: favoritesOnly
            ? ThemeService.activeColorScheme.tertiary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      showCheckmark: false,
      selected: favoritesOnly,
      tooltip: name,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: onFavoritesOnlyChanged,
    );
    final search = IconButton(
      icon: Icon(searching ? Icons.search_off : Icons.search, size: 16),
      onPressed: onSearchPressed,
      tooltip: l10n.creativePanelSearchTooltip,
    );
    // The name at the start and the controls at the end. No Spacer: each
    // form is measured at its natural width (see FirstThatFits).
    Widget row(Widget filter, {required bool withTitle}) {
      final showTitle = withTitle && title != null;
      return Row(
        mainAxisAlignment: showTitle
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.end,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                title!,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
            ),
          Row(mainAxisSize: MainAxisSize.min, children: [filter, search]),
        ],
      );
    }

    return FirstThatFits(
      children: [
        row(labelled, withTitle: true),
        row(iconOnly, withTitle: true),
        if (title != null) row(iconOnly, withTitle: false),
      ],
    );
  }
}
