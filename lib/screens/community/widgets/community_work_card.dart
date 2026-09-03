import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../config/font_fallback.dart';

/// 動画の長さ（秒）を「m:ss」表記へ変換する。
String formatDurationLabel(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Communityの実動画サムネイルが無い間に表示するアプリUI用パレット。
/// ユーザー作品色ではないため、常に現在のテーマから導出する。
List<List<Color>> communityThumbnailGradients(ColorScheme scheme) => <List<Color>>[
  [scheme.primaryContainer, scheme.primary],
  [scheme.secondaryContainer, scheme.secondary],
  [scheme.tertiaryContainer, scheme.tertiary],
  [scheme.primary.withValues(alpha: 0.55), scheme.secondary],
  [scheme.secondary.withValues(alpha: 0.55), scheme.tertiary],
  [scheme.tertiary.withValues(alpha: 0.55), scheme.primary],
];

/// 作品広場の一覧（新着・ランキング・作者別）で共通して使う作品カード。
class CommunityWorkCard extends StatelessWidget {
  final CommunityWork work;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;
  final VoidCallback? onAuthorTap;
  final int? rankNumber;
  final String? repostedByAuthorName;

  const CommunityWorkCard({
    super.key,
    required this.work,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    this.onAuthorTap,
    this.rankNumber,
    this.repostedByAuthorName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholderGradients = communityThumbnailGradients(scheme);
    final gradient = placeholderGradients[
      work.thumbnailColorIndex % placeholderGradients.length
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        formatDurationLabel(work.durationSeconds),
                        style: TextStyle(
                          color: ThemeService.activeColorScheme.surface,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (work.isShort)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.communityShortBadge,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rankNumber != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '#$rankNumber',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        Text(
                          work.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: onAuthorTap,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              work.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                        if (repostedByAuthorName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.repeat_rounded, size: 11, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    repostedByAuthorName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.communityBookmarkTooltip,
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    onPressed: onBookmarkToggle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
