import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'community_follow_notifications_screen.dart';
import 'community_my_works_screen.dart';
import 'widgets/community_shorts_viewer.dart';
import 'widgets/community_work_card.dart';
import 'widgets/video_type_filter.dart';
import '../../config/font_fallback.dart';

enum _RankingPeriod { allTime, yearly, monthly, weekly, daily }

enum _RankingSort { views, bookmarks }

/// 作品広場画面。
///
/// `29_動画投稿・ランキング機能仕様.md`のバックエンド（YouTube投稿・
/// DynamoDB・ランキング集計）は未実装のため、この画面は表示確認用の
/// ダミーデータ（`CommunityService`）のみで動作するUI・デザインの
/// 作り込みに限定している。作品カードをタップするとフローティング動画
/// プレビューウィンドウ（`CommunityFloatingPreview`）が開き、そこから
/// 「詳細へ」ボタンで作品詳細画面（別ルート、`CommunityWorkDetailScreen`）
/// へ遷移する。
class CommunityScreen extends StatefulWidget {
  final String? initialTagFilter;

  const CommunityScreen({super.key, this.initialTagFilter});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _RankingPeriod _period = _RankingPeriod.allTime;
  _RankingSort _sort = _RankingSort.views;
  bool _sortAscending = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _tagSearchMode = false;
  VideoTypeFilter _videoTypeFilter = VideoTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final initialTag = widget.initialTagFilter;
    if (initialTag != null && initialTag.isNotEmpty) {
      _isSearching = true;
      _tagSearchMode = true;
      _searchQuery = initialTag;
      _searchController.text = initialTag;
    }
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTag = widget.initialTagFilter;
    if (newTag != null &&
        newTag.isNotEmpty &&
        newTag != oldWidget.initialTagFilter) {
      setState(() {
        _isSearching = true;
        _tagSearchMode = true;
        _searchQuery = newTag;
        _searchController.text = newTag;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<CommunityWork> _applySearch(List<CommunityWork> works) {
    final typeFiltered = _videoTypeFilter.apply(works);
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return typeFiltered;
    if (_tagSearchMode) {
      return typeFiltered
          .where((w) => w.tags.any((t) => t.toLowerCase().contains(query)))
          .toList();
    }
    return typeFiltered
        .where(
          (w) =>
              w.title.toLowerCase().contains(query) ||
              w.authorName.toLowerCase().contains(query),
        )
        .toList();
  }

  List<CommunityWork> _newArrivals(List<CommunityWork> allWorks) =>
      _applySearch(
        [...allWorks]..sort((a, b) => b.postedAt.compareTo(a.postedAt)),
      );

  Duration? _periodWindow(_RankingPeriod period) => switch (period) {
    _RankingPeriod.allTime => null,
    _RankingPeriod.yearly => const Duration(days: 365),
    _RankingPeriod.monthly => const Duration(days: 30),
    _RankingPeriod.weekly => const Duration(days: 7),
    _RankingPeriod.daily => const Duration(days: 1),
  };

  List<CommunityWork> _rankingWorks(List<CommunityWork> allWorks) {
    final filtered = _applySearch(allWorks.toList());
    final window = _periodWindow(_period);
    final now = DateTime.now();
    double scoreOf(CommunityWork w) {
      final metric = _sort == _RankingSort.views
          ? w.viewCount
          : w.bookmarkCount;
      if (window == null) return metric.toDouble();
      final age = now.difference(w.postedAt);
      final windowSeconds = window.inSeconds.toDouble();
      final ageSeconds = age.inSeconds.toDouble().clamp(
        windowSeconds,
        double.infinity,
      );
      final weight = windowSeconds / ageSeconds;
      return metric * weight;
    }

    final direction = _sortAscending ? 1 : -1;
    filtered.sort((a, b) => direction * scoreOf(a).compareTo(scoreOf(b)));
    return filtered.take(50).toList();
  }

  void _openFloatingPreview(CommunityWork work) {
    context.read<CommunityPreviewService>().show(work);
  }

  void _openAuthorWorks(CommunityWork work) {
    Navigator.of(context).push(
      adMockMaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
        ),
      ),
    );
  }

  void _openMyWorks() {
    Navigator.of(context).push(
      adMockMaterialPageRoute<void>(
        builder: (_) => const CommunityMyWorksScreen(),
      ),
    );
  }

  void _openShortsMode(List<CommunityWork> allWorks) {
    final base = switch (_tabController.index) {
      0 => _newArrivals(allWorks),
      1 => _rankingWorks(allWorks),
      _ => _applySearch(context.read<CommunityService>().favoriteAuthorWorks),
    };
    if (base.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communityShortsModeEmptySnackbar)),
      );
      return;
    }
    final shorts = base.where((w) => w.isShort).toList();
    final target = shorts.isNotEmpty ? shorts : base;
    final communityService = context.read<CommunityService>();
    Navigator.of(context).push(
      adMockMaterialPageRoute(
        builder: (_) => CommunityShortsScreen(
          works: target,
          bookmarkedIds: communityService.bookmarkedIds,
          onToggleBookmark: (w) => communityService.toggleBookmark(w.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final communityService = context.watch<CommunityService>();
    final allWorks = communityService.discoverableWorks;
    final bookmarkedIds = communityService.bookmarkedIds;
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _tagSearchMode
                      ? l10n.communityTagSearchHint
                      : l10n.communitySearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(l10n.communityScreenTitle),
        actions: [
          if (_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClose,
              onPressed: () => setState(() {
                _isSearching = false;
                _tagSearchMode = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: Badge(
                label: Text(
                  '${communityService.unreadFollowNotificationCount}',
                ),
                isLabelVisible:
                    communityService.unreadFollowNotificationCount > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: l10n.communityFollowNotificationsTooltip,
              onPressed: () => Navigator.of(context).push(
                adMockMaterialPageRoute<void>(
                  builder: (_) => const CommunityFollowNotificationsScreen(),
                ),
              ),
            ),
            VideoTypeFilterButton(
              value: _videoTypeFilter,
              onChanged: (v) => setState(() => _videoTypeFilter = v),
            ),
            if (_videoTypeFilter == VideoTypeFilter.shortOnly)
              IconButton(
                icon: const Icon(Icons.view_carousel_outlined),
                tooltip: l10n.communityShortsModeTooltip,
                onPressed: () => _openShortsMode(allWorks),
              ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.commonSearch,
              onPressed: () => setState(() => _isSearching = true),
            ),
            const HelpButton(topic: '作品広場'),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearching ? 104 : 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<bool>(
                          value: false,
                          icon: const Icon(Icons.search, size: 18),
                          label: Text(
                            l10n.communitySearchHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: const Icon(Icons.sell_outlined, size: 18),
                          label: Text(
                            l10n.communityTagSearchHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selected: {_tagSearchMode},
                      onSelectionChanged: (selection) {
                        final tagMode = selection.first;
                        if (tagMode == _tagSearchMode) return;
                        setState(() {
                          _tagSearchMode = tagMode;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    ),
                  ),
                ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.communityTabNew),
                  Tab(text: l10n.communityTabRanking),
                  Tab(text: l10n.communityTabFavoriteAuthors),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('communityMyWorksButton'),
        onPressed: _openMyWorks,
        icon: const Icon(Icons.video_library_outlined),
        label: const Text('自分の投稿'),
        shape: const StadiumBorder(),
      ),
      body: desktopCentered(
        context,
        TabBarView(
          controller: _tabController,
          children: [
            Builder(
              builder: (context) {
                final works = _newArrivals(allWorks);
                if (works.isEmpty) return _buildSearchEmptyState(l10n);
                return SingleChildScrollView(
                  child: CommunityWorkGrid(
                    works: works,
                    bookmarkedIds: bookmarkedIds,
                    onTapWork: _openFloatingPreview,
                    onToggleBookmark: (w) =>
                        communityService.toggleBookmark(w.id),
                    onTapAuthor: _openAuthorWorks,
                    bottomPadding: 88,
                  ),
                );
              },
            ),
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final period in _RankingPeriod.values)
                          ChoiceChip(
                            label: Text(_periodLabel(l10n, period)),
                            selected: _period == period,
                            onSelected: (_) => setState(() => _period = period),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        ChoiceChip(
                          avatar: const Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                          ),
                          label: Text(l10n.communityRankingSortViews),
                          selected: _sort == _RankingSort.views,
                          onSelected: (_) =>
                              setState(() => _sort = _RankingSort.views),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.bookmark, size: 16),
                          label: Text(l10n.communityRankingSortBookmarks),
                          selected: _sort == _RankingSort.bookmarks,
                          onSelected: (_) =>
                              setState(() => _sort = _RankingSort.bookmarks),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                          ),
                          tooltip: _sortAscending
                              ? l10n.communityRankingSortAscendingTooltip
                              : l10n.communityRankingSortDescendingTooltip,
                          onPressed: () =>
                              setState(() => _sortAscending = !_sortAscending),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final ranked = _rankingWorks(allWorks);
                      if (ranked.isEmpty) return _buildSearchEmptyState(l10n);
                      final rankNumbers = {
                        for (int i = 0; i < ranked.length; i++)
                          ranked[i].id: i + 1,
                      };
                      return CommunityWorkGrid(
                        works: ranked,
                        bookmarkedIds: bookmarkedIds,
                        onTapWork: _openFloatingPreview,
                        onToggleBookmark: (w) =>
                            communityService.toggleBookmark(w.id),
                        onTapAuthor: _openAuthorWorks,
                        rankNumbers: rankNumbers,
                        bottomPadding: 88,
                      );
                    },
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final feed = communityService.favoriteAuthorFeed;
                final works = _applySearch(feed.map((e) => e.work).toList());
                final repostedByNames = {
                  for (final e in feed)
                    if (e.repostedByAuthorName != null)
                      e.work.id: e.repostedByAuthorName!,
                };
                if (communityService.favoriteAuthorIds.isEmpty) {
                  return _buildNoFavoriteAuthorsState(l10n);
                }
                if (works.isEmpty) return _buildSearchEmptyState(l10n);
                return SingleChildScrollView(
                  child: CommunityWorkGrid(
                    works: works,
                    bookmarkedIds: bookmarkedIds,
                    onTapWork: _openFloatingPreview,
                    onToggleBookmark: (w) =>
                        communityService.toggleBookmark(w.id),
                    onTapAuthor: _openAuthorWorks,
                    repostedByNames: repostedByNames,
                    bottomPadding: 88,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFavoriteAuthorsState(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_alt_1,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.communityFavoriteAuthorsEmptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.communityFavoriteAuthorsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(AppLocalizations l10n) {
    final query = _searchQuery.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? l10n.communityEmptyState
                  : l10n.communitySearchNoResults(query),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(AppLocalizations l10n, _RankingPeriod period) {
    return switch (period) {
      _RankingPeriod.allTime => l10n.communityRankingPeriodAllTime,
      _RankingPeriod.yearly => l10n.communityRankingPeriodYearly,
      _RankingPeriod.monthly => l10n.communityRankingPeriodMonthly,
      _RankingPeriod.weekly => l10n.communityRankingPeriodWeekly,
      _RankingPeriod.daily => l10n.communityRankingPeriodDaily,
    };
  }
}
