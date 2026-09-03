import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import 'widgets/community_shorts_viewer.dart';
import 'widgets/community_work_card.dart';
import 'widgets/video_type_filter.dart';
import '../../config/font_fallback.dart';

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
  State<CommunityAuthorWorksScreen> createState() =>
      _CommunityAuthorWorksScreenState();
}

class _CommunityAuthorWorksScreenState extends State<CommunityAuthorWorksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  // 「総合」「縦画面のみ」「横画面のみ」の絞り込み（「作品」タブが対象。
  // ブックマーク一覧は本来の投稿順ではないため、ショートモード同様に
  // 対象外とする）。
  VideoTypeFilter _videoTypeFilter = VideoTypeFilter.all;

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
      adMockMaterialPageRoute(
        builder: (_) => CommunityShortsScreen(
          works: target,
          bookmarkedIds: bookmarkedIds,
          onToggleBookmark: (w) =>
              context.read<CommunityService>().toggleBookmark(w.id),
        ),
      ),
    );
  }

  /// フォロー中/フォロワー一覧を表示するダイアログ（Task#134継続：22.5節の
  /// 本人選択制公開）。呼び出し元で公開可否を確認してから呼ぶこと。
  /// [footerNote]は、フォロワー一覧で本人非公開設定のため除外した人数が
  /// あるときの補足表示に使う（22.7節）。
  void _showNameListDialog(
    String title,
    String emptyMessage,
    List<String> names, {
    String? footerNote,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: names.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          emptyMessage,
                          style: TextStyle(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: names.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.primaryContainer,
                            child: Text(names[i].substring(0, 1)),
                          ),
                          title: Text(names[i]),
                        ),
                      ),
              ),
              if (footerNote != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    footerNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(dialogContext)!.commonClose),
          ),
        ],
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
    final works = communityService.worksByAuthor(
      widget.authorId,
      includeHidden: isSelf,
    );
    // 「作品」タブの一覧・縦画面モードにのみ「総合/縦画面のみ/横画面のみ」
    // 絞り込みを適用する。投稿数の表示（works.length）は絞り込みの影響を
    // 受けない総数のままにする。
    final filteredWorks = _videoTypeFilter.apply(works);
    final followerCount = communityService.followerCountOf(widget.authorId);
    final followingCount = communityService.followingCountOf(widget.authorId);
    // 一覧（誰がフォロー中／フォロワーか）は本人選択制の公開設定に従う。
    // 数字自体は常に公開だが、一覧を開けるのは本人自身か、本人が公開設定に
    // した場合のみ（29_動画投稿・ランキング機能仕様.md 22.5節）。
    final followersPublic = communityService.isFollowersPublic(widget.authorId);
    final canViewFollowerList = isSelf || followersPublic;
    final bookmarkedIds = communityService.bookmarkedIds;
    final bookmarksPublic = communityService.isBookmarksPublic(widget.authorId);
    final bookmarkedWorks = (isSelf || bookmarksPublic)
        ? communityService.bookmarkedWorksOf(widget.authorId)
        : const <CommunityWork>[];

    void toggleBookmark(CommunityWork work) =>
        communityService.toggleBookmark(work.id);
    void openWork(CommunityWork work) =>
        context.read<CommunityPreviewService>().show(work);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.authorName),
        actions: [
          VideoTypeFilterButton(
            value: _videoTypeFilter,
            onChanged: (v) => setState(() => _videoTypeFilter = v),
          ),
          if (_videoTypeFilter == VideoTypeFilter.shortOnly)
            IconButton(
              icon: const Icon(Icons.view_carousel_outlined),
              tooltip: l10n.communityShortsModeTooltip,
              // ショートモードは「作品」タブの一覧を対象にする
              // （ブックマーク一覧は本来の投稿順ではないため対象外）。
              onPressed: () => _openShortsMode(filteredWorks, bookmarkedIds),
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
                    child: Text(
                      widget.authorName.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.authorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.communityAuthorWorksCount(works.length),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            // フォロー中／フォロワー一覧（誰が誰をフォローして
                            // いるか）は本人選択制の公開設定に従う。数字自体は
                            // 特定個人を識別できずUGCリスクが小さいため常に
                            // 表示するが、一覧を開けるのは本人か、本人が公開
                            // 設定にした場合のみ（29_動画投稿・ランキング機能
                            // 仕様.md 22.4節・22.5節）。
                            InkWell(
                              key: const Key(
                                'communityAuthorFollowingCountTap',
                              ),
                              onTap: canViewFollowerList
                                  ? () => _showNameListDialog(
                                      l10n.communityFollowingListTitle,
                                      l10n.communityFollowingListEmpty,
                                      communityService.followingNamesOf(
                                        widget.authorId,
                                      ),
                                    )
                                  : null,
                              child: Text(
                                l10n.communityAuthorFollowingCount(
                                  followingCount,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                  decoration: canViewFollowerList
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
                            ),
                            InkWell(
                              key: const Key('communityAuthorFollowerCountTap'),
                              onTap: canViewFollowerList
                                  ? () {
                                      // フォロワー自身がフォロー中/フォロワー
                                      // 一覧を非公開にしている場合は、この
                                      // authorId側が公開設定でもその人物
                                      // だけは表示しない（Task#134継続：
                                      // 22.7節）。
                                      final visibleNames = communityService
                                          .visibleFollowerNamesOf(
                                            widget.authorId,
                                          );
                                      final hiddenCount =
                                          followerCount - visibleNames.length;
                                      _showNameListDialog(
                                        l10n.communityFollowersListTitle,
                                        l10n.communityFollowersListEmpty,
                                        visibleNames,
                                        footerNote: hiddenCount > 0
                                            ? l10n.communityFollowersListHiddenNote(
                                                hiddenCount,
                                              )
                                            : null,
                                      );
                                    }
                                  : null,
                              child: Text(
                                l10n.communityAuthorFollowerCount(
                                  followerCount,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                  decoration: canViewFollowerList
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 自分自身の投稿者ページではフォローボタンを表示しない
                  // （Task#144：お気に入り作者機能）。
                  if (!isSelf)
                    OutlinedButton.icon(
                      onPressed: () => communityService.toggleFavoriteAuthor(
                        widget.authorId,
                      ),
                      icon: Icon(
                        isFavorite
                            ? Icons.person_remove_alt_1
                            : Icons.person_add_alt_1,
                        size: 18,
                      ),
                      label: Text(
                        isFavorite
                            ? l10n.communityFavoriteAuthorFollowing
                            : l10n.communityFavoriteAuthorFollow,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isFavorite
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            // 自分自身のフォロワー一覧を公開するかどうかの設定
            // （Task#134継続：本人選択制の公開。22.5節）。
            if (isSelf)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _PublicVisibilityToggle(
                  value: communityService.selfFollowersPublic,
                  onChanged: communityService.setSelfFollowersPublic,
                  title: l10n.communityFollowersPublicToggleTitle,
                  description: l10n.communityFollowersPublicToggleDesc,
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ─── 作品タブ ───────────────────────────────────
                  SingleChildScrollView(
                    child: filteredWorks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                l10n.communityNoWorksMessage,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : CommunityWorkGrid(
                            works: filteredWorks,
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
                            child: _PublicVisibilityToggle(
                              value: communityService.selfBookmarksPublic,
                              onChanged:
                                  communityService.setSelfBookmarksPublic,
                              title: l10n.communityBookmarksPublicToggleTitle,
                              description:
                                  l10n.communityBookmarksPublicToggleDesc,
                            ),
                          ),
                        if (!isSelf && !bookmarksPublic)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 40,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.communityBookmarksPrivateNotice,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (bookmarkedWorks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                l10n.communityBookmarksEmptyMessage,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
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
/// ブックマーク一覧・フォロワー一覧など、「自分の関係性データを他ユーザーに
/// 公開するか」の設定で共通して使う汎用トグル（Task#134継続：フォロワー
/// 一覧の本人選択制公開に合わせて、ブックマーク専用だったウィジェットを
/// 汎用化した）。
class _PublicVisibilityToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String description;

  const _PublicVisibilityToggle({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(
                value ? Icons.public : Icons.lock_outline,
                color: value ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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
