import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../utils/name_collation.dart';
import '../../../widgets/checked_menu_item.dart';
import '../../../widgets/collection_tile_layout.dart';

enum CommunityWorkView { detail, large, medium, small }

extension CommunityWorkViewSize on CommunityWorkView {
  CollectionViewSize? get tileSize => switch (this) {
    CommunityWorkView.detail => null,
    CommunityWorkView.large => CollectionViewSize.large,
    CommunityWorkView.medium => CollectionViewSize.medium,
    CommunityWorkView.small => CollectionViewSize.small,
  };
}

class CommunityWorkViewButton extends StatelessWidget {
  const CommunityWorkViewButton({
    super.key,
    required this.detail,
    required this.size,
    required this.onChanged,
    this.allowDetail = true,
    this.tooltip,
  });

  final bool detail;
  final CollectionViewSize size;
  final ValueChanged<CommunityWorkView> onChanged;
  final bool allowDetail;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<CommunityWorkView>(
      tooltip: tooltip ?? l10n.homeViewModeTooltip,
      position: PopupMenuPosition.under,
      icon: Icon(detail ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
      onSelected: onChanged,
      itemBuilder: (_) => [
        if (allowDetail)
          checkedMenuItem(
            context,
            value: CommunityWorkView.detail,
            checked: detail,
            label: l10n.homeViewModeDetail,
          ),
        MenuSectionHeading<CommunityWorkView>(l10n.homeViewSizeHeading),
        for (final view in CommunityWorkView.values.skip(1))
          checkedMenuItem(
            context,
            value: view,
            checked: !detail && view.tileSize == size,
            label: switch (view.tileSize!) {
              CollectionViewSize.large => l10n.homeViewModeLarge,
              CollectionViewSize.medium => l10n.homeViewModeMedium,
              CollectionViewSize.small => l10n.homeViewModeSmall,
            },
          ),
      ],
    );
  }
}

List<CommunityWork> sortCommunityWorks(
  Iterable<CommunityWork> works, {
  required bool byName,
  required bool ascending,
}) {
  final compareName = nameComparator<CommunityWork>((work) => work.title);
  return works.toList()..sort((a, b) {
    final order = byName ? compareName(a, b) : a.postedAt.compareTo(b.postedAt);
    if (order == 0) return a.id.compareTo(b.id);
    return ascending ? order : -order;
  });
}
