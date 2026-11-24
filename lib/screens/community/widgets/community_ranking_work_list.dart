import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/community_plaza_labels.dart';
import '../../../l10n/community_ranking_layout_labels.dart';
import 'community_work_counts.dart';
import '../../../models/community_work.dart';
import '../../../services/community_service.dart';
import '../../../widgets/collection_action_controls.dart';
import '../../../widgets/keep_together_text.dart';
import '../../canvas/widgets/canvas_icon_button.dart';
import 'community_thumbnail_placeholder.dart';
import 'community_work_card.dart'
    show
        CommunityWorkOrientation,
        formatDurationLabel,
        toggleCommunityWorkVisibility;

/// Only the ranking tab uses these two presentation modes.
enum CommunityRankingLayout { horizontal, largeThumbnail }

class CommunityRankingWorkList extends StatelessWidget {
  const CommunityRankingWorkList({
    super.key,
    required this.works,
    required this.layout,
    this.periodScores = const {},
    this.showRanks = true,
    this.rankNumbers,
    required this.bookmarkedIds,
    required this.onTapWork,
    required this.onToggleBookmark,
    required this.onTapAuthor,
    this.bottomPadding = 88,
  });

  final List<CommunityWork> works;

  /// Selected JST period scores; cumulative bookmarkCount stays unchanged.
  final Map<String, int> periodScores;
  final CommunityRankingLayout layout;
  final bool showRanks;
  final Map<String, int>? rankNumbers;
  final Set<String> bookmarkedIds;
  final void Function(CommunityWork) onTapWork;
  final void Function(CommunityWork) onToggleBookmark;
  final void Function(CommunityWork) onTapAuthor;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CommunityService>();
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding),
      child: Column(
        key: const Key('communityRankingWorkList'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < works.length; i++) ...[
            CommunityRankingWorkCard(
              key: ValueKey('community-ranking-work-${works[i].id}'),
              work: works[i],
              rank: showRanks
                  ? rankNumbers == null
                        ? i + 1
                        : rankNumbers![works[i].id]
                  : null,
              periodBookmarkCount: periodScores[works[i].id],
              layout: layout,
              isSample: !service.isBackendConnected,
              isBookmarked: bookmarkedIds.contains(works[i].id),
              isMuted: !works[i].isUnavailable && service.isWorkMuted(works[i]),
              isUnavailable:
                  works[i].isUnavailable || !works[i].isNiarimPublished,
              onTap: () => onTapWork(works[i]),
              onBookmarkToggle: () => onToggleBookmark(works[i]),
              onAuthorTap: () => onTapAuthor(works[i]),
              onVisibilityToggle:
                  works[i].isUnavailable || !works[i].isNiarimPublished
                  ? null
                  : () => toggleCommunityWorkVisibility(context, works[i]),
            ),
            if (i + 1 != works.length) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// First, second and third place use three independent theme container roles.
/// Unlike fixed gold/silver/bronze paint, these stay legible in custom themes.
class CommunityRankBadge extends StatelessWidget {
  const CommunityRankBadge({super.key, required this.rank, this.small = false});

  final int rank;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = CommunityRankingLayoutLabels.of(context);
    final top = rank <= 3;
    final (fill, ink) = switch (rank) {
      // The first place has the distinct tertiary role; second and third
      // deliberately share the same secondary role in every app theme.
      1 => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      2 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      3 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.surface, scheme.onSurface),
    };
    final size = small ? 32.0 : 38.0;
    return Semantics(
      label: words.rankedPlace(rank),
      // 中の数字は絵の一部。「3位」のあとに「3」を続けて読まない。
      excludeSemantics: true,
      child: top
          ? Container(
              key: ValueKey('communityRankMedal-$rank'),
              height: size,
              width: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outline, width: 1.6),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: ink,
                  fontSize: small ? 16 : 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : SizedBox(
              key: ValueKey('communityRankNumber-$rank'),
              width: size,
              height: size,
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: ink,
                    shadows: CanvasIconButton.outlineShadows(fill),
                    fontSize: small ? 16 : 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
    );
  }
}

class CommunityRankingWorkCard extends StatelessWidget {
  const CommunityRankingWorkCard({
    super.key,
    required this.work,
    required this.rank,
    required this.layout,
    this.periodBookmarkCount,
    this.repostedByAuthorName,
    this.isSample = false,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    required this.onAuthorTap,
    this.isMuted = false,
    this.isUnavailable = false,
    this.onVisibilityToggle,
  });

  final CommunityWork work;
  final int? rank;
  final CommunityRankingLayout layout;
  final int? periodBookmarkCount;
  final String? repostedByAuthorName;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onVisibilityToggle;
  final bool isMuted;
  final bool isUnavailable;
  final bool isSample;

  bool get _obscured => isMuted || isUnavailable;

  Widget _thumbnail(BuildContext context, {bool withMenu = false}) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_obscured)
          ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.visibility_off_outlined,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          CommunityThumbnailPlaceholder(
            child: work.thumbnailUrl.startsWith('https://')
                ? Image.network(
                    work.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                : null,
          ),
        if (!_obscured)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              key: ValueKey('ranking-duration-${work.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                formatDurationLabel(work.durationSeconds),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // 絵の角から4px：︙の押せる所（丸の外へ4px）が絵の中に収まる。
        if (withMenu && onVisibilityToggle != null && !isUnavailable)
          Positioned(right: 4, top: 4, child: _menu(context)),
      ],
    );
  }

  Widget _menu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = CommunityPlazaLabels.of(context);
    final message = isMuted ? t.unmuteWork : t.muteWork;
    return CollectionActionFrame(
      child: PopupMenuButton<String>(
        key: ValueKey('communityRankingMenu-${work.id}'),
        tooltip: message,
        icon: Icon(Icons.more_vert, color: scheme.onSurface),
        iconSize: CollectionActionFrame.glyphSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 180),
        onSelected: (_) => onVisibilityToggle?.call(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'visibility', child: Text(message)),
        ],
      ),
    );
  }

  Widget _bookmark(BuildContext context, {bool large = false}) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return CollectionActionFrame(
      child: IconButton(
        key: ValueKey('community-bookmark-${work.id}'),
        tooltip: isBookmarked
            ? l10n.communityWorkDetailBookmarkRemove
            : l10n.communityWorkDetailBookmarkAdd,
        icon: Icon(
          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: scheme.onSurfaceVariant,
        ),
        iconSize: CollectionActionFrame.glyphSize,
        constraints: const BoxConstraints.tightFor(
          width: CollectionActionFrame.extent,
          height: CollectionActionFrame.extent,
        ),
        padding: EdgeInsets.zero,
        onPressed: onBookmarkToggle,
      ),
    );
  }

  Widget _title(BuildContext context, {bool large = false}) {
    final t = CommunityPlazaLabels.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Text(
      isUnavailable
          ? t.unavailablePlaceholder
          : isMuted
          ? t.mutedPlaceholder
          : work.title,
      maxLines: large ? 2 : 2,
      overflow: TextOverflow.ellipsis,
      style: localizedHeadingStyle(
        context,
        TextStyle(
          color: scheme.onSurface,
          fontSize: large ? 19 : 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _author(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: !_obscured && onAuthorTap != null,
      child: InkWell(
        key: ValueKey('community-author-${work.id}'),
        onTap: _obscured ? null : onAuthorTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _obscured
                  ? ''
                  : (work.authorName.isEmpty
                        ? l10n.communityCreatorLabel
                        : work.authorName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: localizedHeadingStyle(
                context,
                TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _counts(BuildContext context) => _obscured
      ? const SizedBox.shrink()
      : CommunityWorkCounts(work: work, periodBookmarks: periodBookmarkCount);

  Widget _horizontal(BuildContext context, double width) {
    final thumbnailWidth = (width * .35).clamp(106.0, 230.0).toDouble();
    // Let the information determine the tile height, and stretch the
    // thumbnail to exactly that height (including tall localized titles).
    return IntrinsicHeight(
      child: Row(
        key: const Key('communityRankingHorizontalCard'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('communityRankingHorizontalThumbnail'),
            width: thumbnailWidth,
            child: _thumbnail(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rank case final place?) ...[
                        CommunityRankBadge(rank: place, small: width < 400),
                        const SizedBox(width: 4),
                      ],
                      Expanded(child: _title(context)),
                    ],
                  ),
                  if (!_obscured) ...[
                    if (isSample)
                      messageText(
                        AppLocalizations.of(context)!.communitySampleBadge,
                        key: ValueKey('ranking-sample-${work.id}'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    _author(context),
                    _counts(context),
                    if (repostedByAuthorName case final author?)
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.communityRepostedByBadge(author),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                  if (!isUnavailable)
                    CollectionTileActions(
                      leading: _obscured
                          ? null
                          : CommunityWorkOrientation(work: work),
                      children: [
                        if (!_obscured) _bookmark(context),
                        if (onVisibilityToggle != null) _menu(context),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _largeThumbnail(BuildContext context) {
    return Column(
      key: const Key('communityRankingLargeThumbnailCard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _thumbnail(context, withMenu: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rank case final place?) ...[
                    CommunityRankBadge(rank: place),
                    const SizedBox(width: 9),
                  ],
                  Expanded(child: _title(context, large: true)),
                ],
              ),
              if (!_obscured) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(flex: 2, child: _author(context)),
                    Flexible(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _counts(context),
                      ),
                    ),
                    CollectionActionRow(
                      children: [_bookmark(context, large: true)],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) => Card(
        key: ValueKey('community-ranking-card-${work.id}'),
        margin: EdgeInsets.zero,
        elevation: 1,
        color: Theme.of(context).cardTheme.color ?? scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // 丸い操作の押せる所は、丸の外の帯（並びの箱の外）も押せる。
        child: InkWell(
          onTap: _obscured ? null : onTap,
          child: layout == CommunityRankingLayout.horizontal
              ? _horizontal(context, box.maxWidth)
              : _largeThumbnail(context),
        ).withCollectionActionReach(),
      ),
    );
  }
}
