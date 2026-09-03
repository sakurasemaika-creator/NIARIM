import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../config/font_fallback.dart';

/// サムネイル画像の代わりに使うプレースホルダー配色（実サムネイル取得は
/// バックエンド実装後に対応）。
const List<List<Color>> kCommunityThumbnailGradients = [
  [Color(0xFFFF8A65), Color(0xFFFF5252)],
  [Color(0xFF4FC3F7), Color(0xFF2979FF)],
  [Color(0xFFBA68C8), Color(0xFF7C4DFF)],
  [Color(0xFF81C784), Color(0xFF00BFA5)],
  [Color(0xFFFFD54F), Color(0xFFFF8F00)],
  [Color(0xFFF06292), Color(0xFFC2185B)],
];

/// 動画の長さ（秒）を「m:ss」表記へ変換する。
String formatDurationLabel(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 作品広場の一覧（新着・ランキング・作者別）で共通して使う作品カード。
class CommunityWorkCard extends StatelessWidget {
  final CommunityWork work;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;
  final VoidCallback? onAuthorTap;
  final int? rankNumber;
  // フォロー中の作者タブ（Task#145）で、この作品がフォロー中の作者の
  // リポストによって一覧に混ざっている場合のリポスト元の作者名。
  // nullなら通常の投稿として表示する。
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
    final gradient =
        kCommunityThumbnailGradients[work.thumbnailColorIndex %
            kCommunityThumbnailGradients.length];
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 一覧のグリッドセルは全カード共通の固定アスペクト比
            // （CommunityWorkGridのchildAspectRatio）で敷き詰めるため、
            // ショート動画のサムネイルだけ縦長(9:16)にするとカードの
            // 高さがセルからはみ出してしまう。一覧上は他カードと同じ
            // 16:9のまま「ショート」バッジで見分けられるようにし、
            // 実際の縦長表示はショートモード（全画面縦スクロール
            // ビューア）側で行う。
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
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.70),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  if (rankNumber != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      // 順位バッジの数字は、一覧を流し見しただけでも
                      // 何位かがすぐ伝わるよう、他のバッジ文字より一回り
                      // 大きく・見出し用フォント（くらむぼん）で表示する。
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#$rankNumber',
                          style: TextStyle(
                            color: ThemeService.activeColorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                      ),
                    ),
                  // NIARIM側で非公開にした作品であることを示すバッジ。
                  // 通常は一覧側の絞り込みで除外されるため、投稿者本人が
                  // 自分の投稿者別作品一覧を開いた場合にのみ表示される。
                  if (!work.isNiarimPublished)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: ThemeService.activeColorScheme.onSurface,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.communityVisibilityHiddenBadge,
                              style: TextStyle(
                                color: ThemeService.activeColorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        formatDurationLabel(work.durationSeconds),
                        style: TextStyle(
                          color: ThemeService.activeColorScheme.onSurface,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  if (work.isShort)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.communityShortsBadge,
                          style: TextStyle(
                            color: ThemeService.activeColorScheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onBookmarkToggle,
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: ThemeService.activeColorScheme.onSurface,
                          shadows: [
                            Shadow(color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (repostedByAuthorName != null) ...[
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 12, color: scheme.primary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.communityRepostedByBadge(repostedByAuthorName!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    work.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onAuthorTap,
                    child: Text(
                      work.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      // 日本語ロケールではカンマ区切りの通常表記（例：12,345）を
                      // 使うため、K/M簡略表記より横幅を取りやすい。カードの
                      // 横幅が狭い場合に数字が省略記号で切れても崩れないよう
                      // Flexibleで包む。
                      Flexible(
                        child: Text(
                          formatCompactCount(
                            work.viewCount,
                            Localizations.localeOf(context).languageCode,
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.bookmark,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          formatCompactCount(
                            work.bookmarkCount,
                            Localizations.localeOf(context).languageCode,
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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

/// 画面幅に応じて列数を切り替えるグリッド（電話は2列、幅の広いPC/DeX画面
/// ではカード幅を基準にもっと多くの列を表示する）。
class CommunityWorkGrid extends StatelessWidget {
  final List<CommunityWork> works;
  final Set<String> bookmarkedIds;
  final void Function(CommunityWork work) onTapWork;
  final void Function(CommunityWork work) onToggleBookmark;
  final void Function(CommunityWork work)? onTapAuthor;
  final Map<String, int>? rankNumbers;
  // workId→リポスト元の作者名（フォロー中の作者タブでのみ渡す。Task#145）。
  final Map<String, String>? repostedByNames;

  const CommunityWorkGrid({
    super.key,
    required this.works,
    required this.bookmarkedIds,
    required this.onTapWork,
    required this.onToggleBookmark,
    this.onTapAuthor,
    this.rankNumbers,
    this.repostedByNames,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: works.length,
          itemBuilder: (context, index) {
            final work = works[index];
            return CommunityWorkCard(
              work: work,
              isBookmarked: bookmarkedIds.contains(work.id),
              onTap: () => onTapWork(work),
              onBookmarkToggle: () => onToggleBookmark(work),
              onAuthorTap: onTapAuthor == null
                  ? null
                  : () => onTapAuthor!(work),
              rankNumber: rankNumbers?[work.id],
              repostedByAuthorName: repostedByNames?[work.id],
            );
          },
        );
      },
    );
  }
}
