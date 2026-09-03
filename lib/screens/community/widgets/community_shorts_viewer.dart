import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../router.dart';
import 'community_work_card.dart' show communityThumbnailGradient;

/// 「ショートモード」：新着・ランキング・投稿者別作品一覧の各画面から
/// ボタン1つで切り替えられる、YouTubeショート／TikTok／Instagramリール
/// 風の全画面縦スクロール連続再生ビューア（Task#159）。
///
/// 【横動画/ショートの区別について】YouTube Data APIには「これはShorts
/// である」という直接のフラグが無いが、NIARIM側は投稿元プロジェクトの
/// キャンバスサイズ（縦長かどうか）を投稿時点で把握できるため、確実に
/// 判定できる（詳細はCommunityWork.isShortのドキュメントコメント参照）。
/// このビューアには呼び出し元で事前にisShortのみへ絞り込んだ一覧を渡す。
///
/// 実際の動画本体（YouTube埋め込み）はバックエンド未実装のため、既存の
/// 一覧・フローティングプレビューと同じプレースホルダー（グラデーション＋
/// 再生アイコン）を全画面表示する。上下スワイプでPageView.builderが
/// 次/前の作品へ切り替わる。
class CommunityShortsScreen extends StatefulWidget {
  final List<CommunityWork> works;
  final int initialIndex;
  final Set<String> bookmarkedIds;
  final void Function(CommunityWork work) onToggleBookmark;

  const CommunityShortsScreen({
    super.key,
    required this.works,
    this.initialIndex = 0,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
  });

  @override
  State<CommunityShortsScreen> createState() => _CommunityShortsScreenState();
}

class _CommunityShortsScreenState extends State<CommunityShortsScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: ThemeService.activeColorScheme.onSurface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: widget.works.length,
            itemBuilder: (context, index) {
              final work = widget.works[index];
              return _ShortsPage(
                work: work,
                isBookmarked: widget.bookmarkedIds.contains(work.id),
                onToggleBookmark: () => widget.onToggleBookmark(work),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              tooltip: l10n.communityShortsModeExitTooltip,
              icon: Icon(
                Icons.close,
                color: ThemeService.activeColorScheme.onSurface,
                size: 28,
                shadows: [Shadow(color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54), blurRadius: 6)],
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortsPage extends StatelessWidget {
  final CommunityWork work;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  const _ShortsPage({
    required this.work,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gradient =
        communityThumbnailGradient(Theme.of(context).colorScheme, work.thumbnailColorIndex);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
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
              size: 72,
            ),
          ),
        ),
        // 下部のグラデーションで文字を読みやすくする（動画プレイヤーアプリの
        // 定番デザイン）。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 88,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                work.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThemeService.activeColorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                work.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThemeService.activeColorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ThemeService.activeColorScheme.onSurface,
                  backgroundColor: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => appRouter.push('/community/work/${work.id}'),
                child: Text(
                  l10n.communityFloatingPreviewDetailButton,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // 右側の縦アクションバー（ブックマーク・再生数）。
        Positioned(
          right: 12,
          bottom: 24,
          child: Column(
            children: [
              IconButton(
                onPressed: onToggleBookmark,
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: ThemeService.activeColorScheme.onSurface,
                  size: 32,
                  shadows: [Shadow(color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54), blurRadius: 6)],
                ),
              ),
              Text(
                formatCompactCount(
                  work.bookmarkCount,
                  Localizations.localeOf(context).languageCode,
                ),
                style: TextStyle(
                  color: ThemeService.activeColorScheme.onSurface,
                  fontSize: 11,
                  shadows: [Shadow(color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54), blurRadius: 4)],
                ),
              ),
              SizedBox(height: 12),
              Icon(
                Icons.play_arrow_rounded,
                color: ThemeService.activeColorScheme.onSurface,
                size: 26,
                shadows: [Shadow(color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54), blurRadius: 6)],
              ),
              Text(
                formatCompactCount(
                  work.viewCount,
                  Localizations.localeOf(context).languageCode,
                ),
                style: TextStyle(
                  color: ThemeService.activeColorScheme.onSurface,
                  fontSize: 11,
                  shadows: [Shadow(color: ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54), blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
