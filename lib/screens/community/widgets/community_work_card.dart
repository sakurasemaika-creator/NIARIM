import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/community_plaza_labels.dart';
import '../../../services/community_service.dart';
import 'package:provider/provider.dart';
import '../../../models/community_work.dart';
import '../../../config/font_fallback.dart';

String formatDurationLabel(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

List<List<Color>> communityThumbnailGradients(ColorScheme scheme) =>
    <List<Color>>[
      [scheme.primaryContainer, scheme.primary],
      [scheme.secondaryContainer, scheme.secondary],
      [scheme.tertiaryContainer, scheme.tertiary],
      [scheme.primary.withValues(alpha: 0.55), scheme.secondary],
      [scheme.secondary.withValues(alpha: 0.55), scheme.tertiary],
      [scheme.tertiary.withValues(alpha: 0.55), scheme.primary],
    ];

List<Color> communityThumbnailGradient(ColorScheme scheme, int colorIndex) {
  final gradients = communityThumbnailGradients(scheme);
  return gradients[colorIndex % gradients.length];
}

/// Compatibility accessor for community views that share this palette.
/// The value is recalculated from the current active theme on every access.
List<List<Color>> get kCommunityThumbnailGradients =>
    communityThumbnailGradients(ThemeService.activeColorScheme);

class CommunityWorkCard extends StatelessWidget {
  final CommunityWork work;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;
  final VoidCallback? onAuthorTap;
  final int? rankNumber;
  final String? repostedByAuthorName;
  final bool isMuted;
  final bool isUnavailable;
  final VoidCallback? onMuteToggle;

  const CommunityWorkCard({
    super.key,
    required this.work,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    this.onAuthorTap,
    this.rankNumber,
    this.repostedByAuthorName,
    this.isMuted = false,
    this.isUnavailable = false,
    this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final cardColor = theme.cardTheme.color ?? scheme.surfaceContainerLow;
    final textColor = scheme.onSurface;
    final detailColor = scheme.onSurfaceVariant;
    final obscured = isUnavailable || isMuted;
    final author = work.authorName.trim().isEmpty
        ? l10n.communityCreatorLabel
        : work.authorName;
    final language = Localizations.localeOf(context).languageCode;
    final views = formatCompactCount(work.viewCount, language);
    final bookmarks = formatCompactCount(work.bookmarkCount, language);
    final overlay = cardColor;
    Widget badge(
      String label, {
      IconData? icon,
      bool iconOnly = false,
      double fontSize = 10,
    }) => Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: overlay,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: iconOnly ? 18 : 12, color: textColor),
            if (!iconOnly) ...[
              if (icon != null) const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    Widget count(String label, String value) => Flexible(
      child: Semantics(
        label: '$label: $value',
        child: ExcludeSemantics(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: detailColor),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 200;
        return Card(
          color: cardColor,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: obscured ? null : onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, thumbnail) {
                      final maxBadgeWidth = (thumbnail.maxWidth - 66).clamp(
                        1.0,
                        double.infinity,
                      );
                      return Stack(
                        children: [
                          if (obscured)
                            Positioned.fill(
                              child: ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Center(
                                  child: Icon(
                                    Icons.visibility_off_outlined,
                                    size: 32,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          if (!obscured)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: communityThumbnailGradient(
                                    scheme,
                                    work.thumbnailColorIndex,
                                  ),
                                ),
                              ),
                              // Draw real YouTube artwork whenever the backend
                              // supplies it. A theme-derived gradient remains
                              // visible while loading or if the URL fails.
                              child: work.thumbnailUrl.startsWith('https://')
                                  ? Image.network(
                                      work.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          const SizedBox.shrink(),
                                    )
                                  : null,
                            ),
                          ),
                          if (!work.isNiarimPublished && !obscured)
                            Positioned(
                              left: 6,
                              top: 6,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxBadgeWidth,
                                ),
                                child: badge(
                                  l10n.communityVisibilityHiddenBadge,
                                  icon: Icons.lock_outline,
                                  iconOnly: compact,
                                ),
                              ),
                            )
                          else if (rankNumber != null)
                            Positioned(
                              left: 6,
                              top: 6,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxBadgeWidth,
                                ),
                                child: badge('#$rankNumber', fontSize: 16),
                              ),
                            ),
                          // The upper menu is a 48dp touch target. On
                          // 120dp tiles a bottom-right duration chip would
                          // overlap it, so favor a clear thumbnail.
                          if (!obscured && thumbnail.maxWidth >= 148)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: (thumbnail.maxWidth - 18) * .48,
                              ),
                              child: badge(
                                formatDurationLabel(work.durationSeconds),
                              ),
                            ),
                          ),
                          if (work.isShort && !obscured)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: (thumbnail.maxWidth - 18) * .48,
                                ),
                                child: badge(l10n.communityShortsBadge),
                              ),
                            ),
                          if (onMuteToggle != null && !isUnavailable)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Material(
                                color: overlay,
                                shape: const CircleBorder(),
                                child: PopupMenuButton<String>(
                                  key: ValueKey('communityMuteMenu-${work.id}'),
                                  tooltip: isMuted
                                      ? CommunityPlazaLabels.of(context).unmuteWork
                                      : CommunityPlazaLabels.of(context).muteWork,
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (_) => onMuteToggle!(),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: isMuted ? 'unmute' : 'mute',
                                      child: Text(isMuted
                                          ? CommunityPlazaLabels.of(context).unmuteWork
                                          : CommunityPlazaLabels.of(context).muteWork),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (repostedByAuthorName != null && !obscured) ...[
                        Row(
                          children: [
                            Icon(Icons.repeat, size: 12, color: detailColor),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                l10n.communityRepostedByBadge(
                                  repostedByAuthorName!,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: detailColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        isUnavailable
                            ? CommunityPlazaLabels.of(context).unavailablePlaceholder
                            : isMuted
                            ? CommunityPlazaLabels.of(context).mutedPlaceholder
                            : work.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                          color: textColor,
                        ),
                      ),
                      if (!obscured) const SizedBox(height: 4),
                      if (!obscured)
                      Semantics(
                        button: onAuthorTap != null,
                        label: author,
                        child: GestureDetector(
                          key: ValueKey('community-author-${work.id}'),
                          onTap: onAuthorTap,
                          behavior: HitTestBehavior.opaque,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: onAuthorTap == null ? 0 : 48,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ExcludeSemantics(
                                child: Text(
                                  author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: detailColor,
                                    fontFamily: 'Kuramubon',
                                    fontFamilyFallback: kHeadingFontFallback,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!obscured) const SizedBox(height: 4),
                      if (!obscured)
                      LayoutBuilder(
                        builder: (context, metrics) {
                          // At 120dp tiles, preserve readable counts by
                          // suppressing redundant glyphs, never shrinking
                          // the bookmark's minimum 48dp hit target.
                          final dense = metrics.maxWidth < 150;
                          return Row(
                        children: [
                          if (!dense) ...[
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 13,
                              color: detailColor,
                            ),
                            const SizedBox(width: 2),
                          ],
                          count(l10n.communityRankingSortViews, views),
                          SizedBox(width: dense ? 6 : 5),
                          if (!dense) ...[
                            Icon(Icons.bookmarks_outlined, size: 13, color: detailColor),
                            const SizedBox(width: 2),
                          ],
                          count(l10n.communityRankingSortBookmarks, bookmarks),
                          const SizedBox(width: 2),
                          // Keep the bookmark action alongside the two counts;
                          // the 48dp target stays tappable even at narrow widths.
                          MergeSemantics(
                            child: Semantics(
                              button: true,
                              label: isBookmarked
                                  ? l10n.communityWorkDetailBookmarkRemove
                                  : l10n.communityWorkDetailBookmarkAdd,
                              toggled: isBookmarked,
                              child: IconButton(
                                key: ValueKey('community-bookmark-${work.id}'),
                                tooltip: isBookmarked
                                    ? l10n.communityWorkDetailBookmarkRemove
                                    : l10n.communityWorkDetailBookmarkAdd,
                                constraints: const BoxConstraints.tightFor(
                                  width: 48,
                                  height: 48,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: onBookmarkToggle,
                                icon: Icon(
                                  isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: detailColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CommunityWorkGrid extends StatelessWidget {
  final List<CommunityWork> works;
  final Set<String> bookmarkedIds;
  final void Function(CommunityWork work) onTapWork;
  final void Function(CommunityWork work) onToggleBookmark;
  final void Function(CommunityWork work)? onTapAuthor;
  final Map<String, int>? rankNumbers;
  final Map<String, String>? repostedByNames;

  /// 一覧の下端に足す余白。フローティングボタン（「投稿する」）がある
  /// 画面では、これが無いと**最終行のカードの下側がFABに永久に隠れる**
  /// （どれだけスクロールしても出てこない）。
  final double bottomPadding;
  final double minTileWidth;

  const CommunityWorkGrid({
    super.key,
    required this.works,
    required this.bookmarkedIds,
    required this.onTapWork,
    required this.onToggleBookmark,
    this.onTapAuthor,
    this.rankNumbers,
    this.repostedByNames,
    this.bottomPadding = 12,
    this.minTileWidth = 160,
  });

  Future<void> _toggleMute(BuildContext context, CommunityWork work) async {
    final service = context.read<CommunityService>();
    if (!service.isWorkMuted(work)) {
      await service.setWorkMuted(work.id);
      return;
    }
    final texts = CommunityPlazaLabels.of(context);
    final permanent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(texts.unmuteQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(texts.unmuteTemporary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(texts.unmuteAlways),
          ),
        ],
      ),
    );
    if (permanent != null) {
      await service.unmuteWork(work.id, permanently: permanent);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final service = context.watch<CommunityService>();
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final minimumWidth = minTileWidth * (scale < 1 ? 1 : scale);
      final columns = ((constraints.maxWidth - 24 + 10) / (minimumWidth + 10))
          .floor()
          .clamp(1, 6);
      final width = (constraints.maxWidth - 24 - 10 * (columns - 1)) / columns;
      return SizedBox(
        width: constraints.maxWidth,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final work in works)
                SizedBox(
                  width: width,
                  child: CommunityWorkCard(
                    work: work,
                    isBookmarked: bookmarkedIds.contains(work.id),
                    onTap: () => onTapWork(work),
                    onBookmarkToggle: () => onToggleBookmark(work),
                    onAuthorTap: onTapAuthor == null
                        ? null
                        : () => onTapAuthor!(work),
                    rankNumber: rankNumbers?[work.id],
                    repostedByAuthorName: repostedByNames?[work.id],
                    isMuted: !work.isUnavailable && service.isWorkMuted(work),
                    isUnavailable: work.isUnavailable || !work.isNiarimPublished,
                    onMuteToggle: work.isUnavailable || !work.isNiarimPublished
                        ? null
                        : () => _toggleMute(context, work),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
