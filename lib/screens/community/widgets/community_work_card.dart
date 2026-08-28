import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';

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

/// みんなの作品一覧（新着・ランキング・作者別）で共通して使う作品カード。
class CommunityWorkCard extends StatelessWidget {
  final CommunityWork work;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;
  final VoidCallback? onAuthorTap;
  final int? rankNumber;

  const CommunityWorkCard({
    super.key,
    required this.work,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    this.onAuthorTap,
    this.rankNumber,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradient = kCommunityThumbnailGradients[work.thumbnailColorIndex % kCommunityThumbnailGradients.length];
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
                      child: const Center(
                        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 40),
                      ),
                    ),
                  ),
                  if (rankNumber != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('#$rankNumber',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, color: Colors.white, size: 11),
                            const SizedBox(width: 3),
                            Text(AppLocalizations.of(context)!.communityVisibilityHiddenBadge,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(formatDurationLabel(work.durationSeconds),
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
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
                          color: Colors.white,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
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
                  Text(
                    work.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Kuramubon'),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onAuthorTap,
                    child: Text(
                      work.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(formatCompactCount(work.viewCount),
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      const SizedBox(width: 10),
                      Icon(Icons.bookmark, size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(formatCompactCount(work.bookmarkCount),
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
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

  const CommunityWorkGrid({
    super.key,
    required this.works,
    required this.bookmarkedIds,
    required this.onTapWork,
    required this.onToggleBookmark,
    this.onTapAuthor,
    this.rankNumbers,
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
              onAuthorTap: onTapAuthor == null ? null : () => onTapAuthor!(work),
              rankNumber: rankNumbers?[work.id],
            );
          },
        );
      },
    );
  }
}
