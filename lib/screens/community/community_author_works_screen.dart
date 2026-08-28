import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_service.dart';
import '../../widgets/responsive.dart';
import 'widgets/community_shorts_viewer.dart';
import 'widgets/community_work_card.dart';

/// 特定の作者の投稿作品一覧（29_動画投稿・ランキング機能仕様.md 8.4節）。
/// 作品カードの作者名タップから遷移する。ブックマークの状態は呼び出し元
/// （CommunityScreen）と共有し、この画面内での操作も一覧側へ反映される。
class CommunityAuthorWorksScreen extends StatefulWidget {
  final String authorId;
  final String authorName;
  final List<CommunityWork> works;
  final Set<String> bookmarkedIds;
  final void Function(CommunityWork work) onToggleBookmark;
  final void Function(CommunityWork work) onOpenWork;

  const CommunityAuthorWorksScreen({
    super.key,
    required this.authorId,
    required this.authorName,
    required this.works,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    required this.onOpenWork,
  });

  @override
  State<CommunityAuthorWorksScreen> createState() => _CommunityAuthorWorksScreenState();
}

class _CommunityAuthorWorksScreenState extends State<CommunityAuthorWorksScreen> {
  void _toggleBookmark(CommunityWork work) {
    setState(() => widget.onToggleBookmark(work));
  }

  void _openShortsMode() {
    if (widget.works.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communityShortsModeEmptySnackbar)),
      );
      return;
    }
    final shorts = widget.works.where((w) => w.isShort).toList();
    final target = shorts.isNotEmpty ? shorts : widget.works;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityShortsScreen(
          works: target,
          bookmarkedIds: widget.bookmarkedIds,
          onToggleBookmark: _toggleBookmark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final communityService = context.watch<CommunityService>();
    final isSelf = widget.authorId == kDummySelfAuthorId;
    final isFavorite = communityService.isFavoriteAuthor(widget.authorId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.authorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_carousel_outlined),
            tooltip: l10n.communityShortsModeTooltip,
            onPressed: _openShortsMode,
          ),
        ],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(widget.authorName.substring(0, 1),
                          style: TextStyle(fontSize: 18, color: scheme.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.authorName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
                          const SizedBox(height: 4),
                          Text(l10n.communityAuthorWorksCount(widget.works.length),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    // 自分自身の投稿者ページではフォローボタンを表示しない
                    // （Task#144：お気に入り作者機能）。
                    if (!isSelf)
                      OutlinedButton.icon(
                        onPressed: () => communityService.toggleFavoriteAuthor(widget.authorId),
                        icon: Icon(isFavorite ? Icons.person_remove_alt_1 : Icons.person_add_alt_1, size: 18),
                        label: Text(isFavorite
                            ? l10n.communityFavoriteAuthorFollowing
                            : l10n.communityFavoriteAuthorFollow),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isFavorite ? scheme.onSurfaceVariant : scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.works.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(l10n.communityNoWorksMessage, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                )
              else
                CommunityWorkGrid(
                  works: widget.works,
                  bookmarkedIds: widget.bookmarkedIds,
                  onTapWork: widget.onOpenWork,
                  onToggleBookmark: _toggleBookmark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
