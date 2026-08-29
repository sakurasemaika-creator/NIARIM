import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../widgets/responsive.dart';
import 'widgets/community_shorts_viewer.dart';
import 'widgets/community_work_card.dart';

/// 特定の作者の投稿作品一覧（29_動画投稿・ランキング機能仕様.md 8.4節）＋
/// その作者のブックマーク一覧（Task#145：ユーザー別ブックマーク一覧の
/// 実現可否調査を受けた実装）。作品カードの作者名タップから遷移する。
///
/// 【不具合修正】以前はauthorId/authorName以外に`works`・`bookmarkedIds`・
/// `onToggleBookmark`・`onOpenWork`を呼び出し元からその都度の
/// スナップショットとして受け取っていたが、`MaterialPageRoute`のbuilder
/// 内で一度だけ評価される値のため、このAPI設計自体が「この画面を開いた
/// 後にブックマーク状態が変わっても、この画面上のブックマークアイコンが
/// 更新されない」という不具合を内包していた（この画面自身でブックマークを
/// トグルした場合も、setStateではwidget.bookmarkedIdsという不変の
/// フィールド自体は更新されないため、直後の再描画でも古い状態のまま
/// 表示されていた）。`CommunityService`は既にアプリ全体で共有される
/// Providerであるため、authorId/authorNameだけを受け取り、残りは全て
/// `context.watch<CommunityService>()`から都度取得するよう変更し、
/// この種のスナップショット起因の不具合が起きない設計にした。
class CommunityAuthorWorksScreen extends StatefulWidget {
  final String authorId;
  final String authorName;

  const CommunityAuthorWorksScreen({
    super.key,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<CommunityAuthorWorksScreen> createState() => _CommunityAuthorWorksScreenState();
}

class _CommunityAuthorWorksScreenState extends State<CommunityAuthorWorksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openShortsMode(List<CommunityWork> works, Set<String> bookmarkedIds) {
    if (works.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communityShortsModeEmptySnackbar)),
      );
      return;
    }
    final shorts = works.where((w) => w.isShort).toList();
    final target = shorts.isNotEmpty ? shorts : works;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityShortsScreen(
          works: target,
          bookmarkedIds: bookmarkedIds,
          onToggleBookmark: (w) => context.read<CommunityService>().toggleBookmark(w.id),
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
    final works = communityService.worksByAuthor(widget.authorId, includeHidden: isSelf);
    final followerCount = communityService.followerCountOf(widget.authorId);
    final bookmarkedIds = communityService.bookmarkedIds;
    final bookmarksPublic = communityService.isBookmarksPublic(widget.authorId);
    final bookmarkedWorks = (isSelf || bookmarksPublic)
        ? communityService.bookmarkedWorksOf(widget.authorId)
        : const <CommunityWork>[];

    void toggleBookmark(CommunityWork work) => communityService.toggleBookmark(work.id);
    void openWork(CommunityWork work) => context.read<CommunityPreviewService>().show(work);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.authorName),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_carousel_outlined),
            tooltip: l10n.communityShortsModeTooltip,
            // ショートモードは「作品」タブの一覧を対象にする
            // （ブックマーク一覧は本来の投稿順ではないため対象外）。
            onPressed: () => _openShortsMode(works, bookmarkedIds),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.communityAuthorTabWorks),
            Tab(text: l10n.communityAuthorTabBookmarks),
          ],
        ),
      ),
      body: desktopCentered(
        context,
        Column(
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
                        Text(
                          // フォロワー一覧（誰がフォローしているか）は非公開の
                          // ままだが、数字のみの表示は特定個人を識別できず
                          // UGCリスクが小さいため、作品数と並べて表示する
                          // （29_動画投稿・ランキング機能仕様.md 22.4節）。
                          '${l10n.communityAuthorWorksCount(works.length)}　'
                          '${l10n.communityAuthorFollowerCount(followerCount)}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ─── 作品タブ ───────────────────────────────────
                  SingleChildScrollView(
                    child: works.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(l10n.communityNoWorksMessage,
                                  style: TextStyle(color: scheme.onSurfaceVariant)),
                            ),
                          )
                        : CommunityWorkGrid(
                            works: works,
                            bookmarkedIds: bookmarkedIds,
                            onTapWork: openWork,
                            onToggleBookmark: toggleBookmark,
                          ),
                  ),
                  // ─── ブックマークタブ（Task#145） ───────────────────
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSelf)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _BookmarksPublicToggle(
                              value: communityService.selfBookmarksPublic,
                              onChanged: communityService.setSelfBookmarksPublic,
                            ),
                          ),
                        if (!isSelf && !bookmarksPublic)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, size: 40, color: scheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(l10n.communityBookmarksPrivateNotice,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          )
                        else if (bookmarkedWorks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(l10n.communityBookmarksEmptyMessage,
                                  style: TextStyle(color: scheme.onSurfaceVariant)),
                            ),
                          )
                        else
                          CommunityWorkGrid(
                            works: bookmarkedWorks,
                            bookmarkedIds: bookmarkedIds,
                            onTapWork: openWork,
                            onToggleBookmark: toggleBookmark,
                          ),
                      ],
                    ),
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

/// 自分のブックマーク一覧タブに表示する公開設定スイッチ（ユーザー設定）。
/// Task#145の調査で推奨した「既定非公開」を、オンにすることで他ユーザーが
/// この画面から閲覧できるようになる。
class _BookmarksPublicToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BookmarksPublicToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(value ? Icons.public : Icons.lock_outline,
                  color: value ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.communityBookmarksPublicToggleTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
                    const SizedBox(height: 2),
                    Text(l10n.communityBookmarksPublicToggleDesc,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
