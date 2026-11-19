import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/community_ranking_layout_labels.dart';
import '../../../models/community_work.dart';
import '../../../services/community_service.dart';

/// Public totals for the work, with an optional separate ranking-period score.
class CommunityWorkCounts extends StatelessWidget {
  const CommunityWorkCounts({
    super.key,
    required this.work,
    this.periodBookmarks,
    this.compact = false,
    this.fontSize = 12,
    this.postedLabel,
  });

  final CommunityWork work;
  final int? periodBookmarks;
  final bool compact;
  final double fontSize;
  final String? postedLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final language = Localizations.localeOf(context).languageCode;
    final service = context.watch<CommunityService?>();
    final reposts =
        service?.repostCountOf(work.id, fallback: work.repostCount) ??
        work.repostCount;

    Widget metric(String key, IconData icon, String label, int value) {
      final full = formatCompactCount(value, language);
      final short = compact && value >= 1000 && value < 10000
          ? '${(value ~/ 100) / 10}K'
          : full;
      return Semantics(
        key: ValueKey('community-$key-count-${work.id}'),
        label: '$label: $full',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: fontSize + 2, color: color),
              const SizedBox(width: 3),
              Text(
                short,
                style: TextStyle(fontSize: fontSize, color: color),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 2,
      children: [
        if (postedLabel case final label?)
          Text(
            label,
            key: const Key('communityDetailPostedAt'),
            style: TextStyle(fontSize: fontSize, color: color),
          ),
        metric(
          'bookmark',
          Icons.bookmarks_outlined,
          l10n.communityRankingSortBookmarks,
          work.bookmarkCount,
        ),
        metric('repost', Icons.repeat, l10n.communityRepostCount, reposts),
        if (periodBookmarks case final score?)
          metric(
            'period-bookmark',
            Icons.date_range_outlined,
            CommunityRankingLayoutLabels.of(context).periodBookmarks,
            score,
          ),
      ],
    );
  }
}
