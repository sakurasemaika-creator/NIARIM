import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/community_plaza_labels.dart';
import '../../../services/community_service.dart';
import '../../../widgets/collection_action_controls.dart';
import '../../../widgets/collection_tile_layout.dart';

import 'package:provider/provider.dart';

import '../../../models/community_work.dart';
import 'community_work_counts.dart';
import 'community_ranking_work_list.dart'
    show CommunityRankBadge, CommunityRankingLayout, CommunityRankingWorkCard;

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
  final int? periodBookmarks;
  final String? repostedByAuthorName;
  final bool isMuted;
  final bool isUnavailable;
  final bool compactActions;
  final VoidCallback? onMuteToggle;

  const CommunityWorkCard({
    super.key,
    required this.work,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    this.onAuthorTap,
    this.rankNumber,
    this.periodBookmarks,
    this.repostedByAuthorName,
    this.isMuted = false,
    this.isUnavailable = false,
    this.compactActions = false,
    this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isSample = context.select<CommunityService?, bool>(
      (service) => service?.isBackendConnected == false,
    );
    final cardColor = theme.cardTheme.color ?? scheme.surfaceContainerLow;
    final textColor = scheme.onSurface;
    final detailColor = scheme.onSurfaceVariant;
    final obscured = isUnavailable || isMuted;
    final author = work.authorName.trim().isEmpty
        ? l10n.communityCreatorLabel
        : work.authorName;
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
    const contentPadding = EdgeInsets.symmetric(horizontal: 6);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 200;
        final thumbnail = LayoutBuilder(
          key: ValueKey('community-thumbnail-${work.id}'),
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
                if (rankNumber case final rank?)
                  PositionedDirectional(
                    start: 4,
                    top: 4,
                    child: CommunityRankBadge(rank: rank, small: true),
                  ),
                if (!obscured && (repostedByAuthorName != null || isSample))
                  PositionedDirectional(
                    end: 4,
                    top: 4,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxBadgeWidth),
                      child: badge(
                        repostedByAuthorName != null
                            ? l10n.communityRepostedByBadge(
                                repostedByAuthorName!,
                              )
                            : l10n.communitySampleBadge,
                        icon: repostedByAuthorName == null
                            ? null
                            : Icons.repeat,
                        iconOnly: compact && repostedByAuthorName != null,
                      ),
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
                      child: badge(formatDurationLabel(work.durationSeconds)),
                    ),
                  ),
              ],
            );
          },
        );
        return Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: obscured ? null : onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.hasTightHeight)
                  Expanded(child: thumbnail)
                else
                  AspectRatio(aspectRatio: 16 / 9, child: thumbnail),
                Padding(
                  padding: contentPadding,
                  child: Text(
                    isUnavailable
                        ? CommunityPlazaLabels.of(
                            context,
                          ).unavailablePlaceholder
                        : isMuted
                        ? CommunityPlazaLabels.of(context).mutedPlaceholder
                        : work.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: collectionTileCaptionStyle(context),
                  ),
                ),
                if (!obscured)
                  Padding(
                    padding: contentPadding,
                    child: Semantics(
                      button: onAuthorTap != null,
                      label: author,
                      child: GestureDetector(
                        key: ValueKey('community-author-${work.id}'),
                        onTap: onAuthorTap,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height:
                              MediaQuery.textScalerOf(
                                context,
                              ).scale(11).clamp(11.0, 22.0) +
                              29,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: ExcludeSemantics(
                                  child: Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: detailColor,
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: CommunityWorkCounts(
                                    work: work,
                                    periodBookmarks: periodBookmarks,
                                    compact: constraints.maxWidth < 160,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!isUnavailable)
                  CollectionTileActions(
                    key: ValueKey('community-card-actions-${work.id}'),
                    compact: compactActions,
                    leading: obscured
                        ? null
                        : CommunityWorkOrientation(work: work),
                    children: [
                      // 読み上げの名前は丸の中に置く（丸の外に箱を
                      // 置くと、その箱が丸の外の帯を押しても断る）。
                      if (!obscured)
                        CollectionActionFrame(
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
                                width: CollectionActionFrame.extent,
                                height: CollectionActionFrame.extent,
                              ),
                              iconSize: CollectionActionFrame.glyphSize,
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
                      if (onMuteToggle != null)
                        CollectionActionFrame(
                          child: PopupMenuButton<String>(
                            key: ValueKey('communityMuteMenu-${work.id}'),
                            padding: EdgeInsets.zero,
                            iconSize: CollectionActionFrame.glyphSize,
                            tooltip: isMuted
                                ? CommunityPlazaLabels.of(context).unmuteWork
                                : CommunityPlazaLabels.of(context).muteWork,
                            icon: Icon(Icons.more_vert, color: textColor),
                            onSelected: (_) => onMuteToggle!(),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: isMuted ? 'unmute' : 'mute',
                                child: Text(
                                  isMuted
                                      ? CommunityPlazaLabels.of(
                                          context,
                                        ).unmuteWork
                                      : CommunityPlazaLabels.of(
                                          context,
                                        ).muteWork,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                if (isUnavailable) CollectionTileActions.selectionSpace,
              ],
            ),
          ),
        );
      },
    );
  }
}

class CommunityWorkOrientation extends StatelessWidget {
  const CommunityWorkOrientation({super.key, required this.work});

  final CommunityWork work;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = work.isShort
        ? l10n.communityShortsBadge
        : l10n.communityLandscapeBadge;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Text(
            label,
            key: ValueKey('community-orientation-${work.id}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

/// The same hide/unhide action is used by grid cards and both ranking
/// layouts. Persisted filters remain unchanged when changing the layout.
Future<void> toggleCommunityWorkVisibility(
  BuildContext context,
  CommunityWork work,
) async {
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
  final CollectionViewSize viewSize;
  final Map<String, int> periodScores;
  final bool detail;

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
    this.viewSize = CollectionViewSize.medium,
    this.periodScores = const {},
    this.detail = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityService>();
    final padding = EdgeInsets.fromLTRB(8, 0, 8, bottomPadding);
    if (detail) {
      return ListView.separated(
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: works.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final work = works[index];
          final unavailable = work.isUnavailable || !work.isNiarimPublished;
          return CommunityRankingWorkCard(
            key: ValueKey('community-detail-${work.id}'),
            work: work,
            rank: rankNumbers?[work.id],
            layout: CommunityRankingLayout.horizontal,
            periodBookmarkCount: periodScores[work.id],
            isBookmarked: bookmarkedIds.contains(work.id),
            isMuted: !unavailable && service.isWorkMuted(work),
            isUnavailable: unavailable,
            repostedByAuthorName: repostedByNames?[work.id],
            onTap: () => onTapWork(work),
            onBookmarkToggle: () => onToggleBookmark(work),
            onAuthorTap: onTapAuthor == null ? null : () => onTapAuthor!(work),
            onVisibilityToggle: unavailable
                ? null
                : () => toggleCommunityWorkVisibility(context, work),
          );
        },
      );
    }
    return GridView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: collectionTileGridDelegate(
        context,
        viewSize.tileExtent,
        actionBandHeight: CollectionActionFrame.targetExtent,
      ),
      itemCount: works.length,
      itemBuilder: (context, index) {
        final work = works[index];
        return CommunityWorkCard(
          work: work,
          isBookmarked: bookmarkedIds.contains(work.id),
          onTap: () => onTapWork(work),
          onBookmarkToggle: () => onToggleBookmark(work),
          onAuthorTap: onTapAuthor == null ? null : () => onTapAuthor!(work),
          compactActions: viewSize == CollectionViewSize.small,
          rankNumber: rankNumbers?[work.id],
          periodBookmarks: periodScores[work.id],
          repostedByAuthorName: repostedByNames?[work.id],
          isMuted: !work.isUnavailable && service.isWorkMuted(work),
          isUnavailable: work.isUnavailable || !work.isNiarimPublished,
          onMuteToggle: work.isUnavailable || !work.isNiarimPublished
              ? null
              : () => toggleCommunityWorkVisibility(context, work),
        );
      },
    );
  }
}
