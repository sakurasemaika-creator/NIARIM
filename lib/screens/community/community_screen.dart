import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/api/community_api.dart' show RankingPeriod;
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import 'community_edit_feedback.dart';
import 'community_author_works_screen.dart';
import 'community_follow_notifications_screen.dart';
import 'community_my_works_screen.dart';
import 'widgets/community_shorts_viewer.dart';
import 'widgets/community_work_card.dart';
import 'widgets/video_type_filter.dart';
import '../../config/font_fallback.dart';
import '../../utils/color_contrast.dart';

enum _RankingPeriod { allTime, yearly, monthly, weekly, daily }

enum _RankingSort { views, bookmarks }

/// 作品広場画面。
///
/// 設定済みのCommunity backendから一覧を取得し、未設定時はdemo dataを使う。
/// 作品カードをタップするとフローティング動画
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
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    final initialTag = widget.initialTagFilter;
    if (initialTag != null && initialTag.isNotEmpty) {
      _isSearching = true;
      _tagSearchMode = true;
      _searchQuery = initialTag;
      _searchController.text = initialTag;
    }
    // With a backend, the plaza shows the server's latest works and the
    // selected ranking; without one, the bundled dummy works.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<CommunityService>();
      if (!service.isBackendConnected) return;
      service.refreshFromBackend();
      _fetchRanking();
    });
  }

  /// The following tab shows the followed authors' works and reposts as
  /// the server has them now.
  void _onTabChanged() {
    if (_tabController.indexIsChanging || _tabController.index != 2) return;
    final service = context.read<CommunityService>();
    if (service.isBackendConnected) service.refreshFollowingFeed();
  }

  /// Brings the selected ranking into the service's store; the ranking tab
  /// then ranks and filters it like every other work.
  Future<void> _fetchRanking() async {
    final service = context.read<CommunityService>();
    if (!service.isBackendConnected) return;
    await service.fetchRanking(
      _sort == _RankingSort.bookmarks && _period == _RankingPeriod.allTime
          ? RankingPeriod.bookmarks
          : switch (_period) {
              _RankingPeriod.allTime => RankingPeriod.all,
              _RankingPeriod.yearly => RankingPeriod.year,
              _RankingPeriod.monthly => RankingPeriod.month,
              _RankingPeriod.weekly => RankingPeriod.week,
              _RankingPeriod.daily => RankingPeriod.day,
            },
    );
  }

  /// Pulling down on any tab takes the latest works, the selected ranking
  /// and the following feed from the server again, so an edit made since
  /// (a poster's AI image/video declaration, tags, a work hidden) shows.
  Future<void> _refreshAll() async {
    final service = context.read<CommunityService>();
    if (!service.isBackendConnected) return;
    await Future.wait([
      service.refreshFromBackend(),
      _fetchRanking(),
      service.refreshFollowingFeed(),
    ]);
  }

  /// [child] scrolls even when it fits, so it can always be pulled down to
  /// refresh; without a backend there is nothing to fetch.
  Widget _pullToRefresh(CommunityService service, Widget child) {
    if (!service.isBackendConnected) return child;
    return RefreshIndicator(
      key: const Key('communityPullToRefresh'),
      onRefresh: _refreshAll,
      child: child,
    );
  }

  /// Content that fills the refresh viewport even when the list is short.
  Widget _scrollableContent(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth,
          minHeight: constraints.maxHeight,
        ),
        child: child,
      ),
    ),
  );

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
    final service = context.read<CommunityService>();
    if (service.isBackendConnected) {
      // The server's ranking for the period, in its order, as the viewer's
      // filters allow. It ranks by views; the bookmark order is its own
      // all-time ranking, or the period's works re-sorted by bookmarks.
      final ranked = [..._applySearch(service.rankedWorks)];
      if (_sort == _RankingSort.bookmarks &&
          _period != _RankingPeriod.allTime) {
        ranked.sort((a, b) => b.bookmarkCount.compareTo(a.bookmarkCount));
      }
      return _sortAscending ? ranked.reversed.toList() : ranked;
    }
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

  Future<void> _showContentFilters(CommunityService service) async {
    await service.contentFiltersReady;
    if (!mounted) return;
    final result = await showDialog<_ContentFilterInput>(
      context: context,
      builder: (_) => _ContentFilterDialog(
        initialWords: service.mutedWords.toList(),
        initialTags: service.mutedTags.toList(),
        initialHideAi: service.hideGenerativeAiImageVideo,
      ),
    );
    if (result == null) return;
    await service.setHideGenerativeAiImageVideo(result.hideAi);
    await service.setMutedWords(result.words);
    await service.setMutedTags(result.tags);
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
          onToggleBookmark: (w) => reportFailedCommunityEdit(
            context,
            communityService,
            communityService.toggleBookmark(w.id),
          ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final barBackground = opaqueOver(
      theme.appBarTheme.backgroundColor ?? scheme.surface,
      opaqueOver(theme.scaffoldBackgroundColor, Colors.black),
    );
    final foreground = theme.appBarTheme.foregroundColor ?? scheme.onSurface;
    final selected = theme.tabBarTheme.labelColor ?? scheme.primary;
    final unselected =
        theme.tabBarTheme.unselectedLabelColor ?? scheme.onSurfaceVariant;
    final titleStyle =
        (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!)
            .copyWith(color: foreground);
    final labelStyle =
        theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall!;
    Size measure(
      String text,
      TextStyle style, {
      double maxWidth = double.infinity,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        locale: Localizations.localeOf(context),
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final titleSize = measure(
      l10n.communityScreenTitle,
      titleStyle,
      maxWidth: (width - 168).clamp(1.0, double.infinity),
    );
    final videoWidth = (measure(
              _videoTypeFilter.label(l10n),
              theme.textTheme.bodyMedium!.copyWith(fontSize: 12),
            ).width +
            48)
        .clamp(48.0, 160.0);
    final labels = [
      l10n.communityTabNew,
      l10n.communityTabRanking,
      l10n.communityTabFavoriteAuthors,
    ];
    final tabWidths =
        labels.map((label) => measure(label, labelStyle).width + 32);
    final scrollTabs = tabWidths.fold<double>(0, (a, b) => a + b) > width;
    final tabHeight = labels
        .map((label) => measure(label, labelStyle).height + 16)
        .fold<double>(48, (a, b) => a > b ? a : b);
    final searchFill =
        theme.inputDecorationTheme.fillColor ?? scheme.surfaceContainerLow;

    // Stable three-row mobile header: title/actions, search/filters, tabs.
    // The search row never wraps its controls beneath the title.
    final searchRow = Padding(
      key: const Key('communitySearchRow'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 48,
        child: _isSearching
            ? Material(
                color: searchFill,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('communitySearchModeToggle'),
                      icon: Icon(
                        _tagSearchMode
                            ? Icons.search
                            : Icons.sell_outlined,
                      ),
                      tooltip: _tagSearchMode
                          ? l10n.communitySearchHint
                          : l10n.communityTagSearchHint,
                      onPressed: () => setState(() {
                        _tagSearchMode = !_tagSearchMode;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: _tagSearchMode
                              ? l10n.communityTagSearchHint
                              : l10n.communitySearchHint,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
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
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final shortMode =
                      _videoTypeFilter == VideoTypeFilter.shortOnly;
                  final maxVideoWidth = (constraints.maxWidth -
                          148 -
                          (shortMode ? 48 : 0))
                      .clamp(48.0, 160.0).toDouble();
                  final filterWidth =
                      videoWidth.clamp(48.0, maxVideoWidth).toDouble();
                  return Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: searchFill,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            key: const Key('communitySearchTrigger'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                setState(() => _isSearching = true),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.search),
                                  tooltip: l10n.commonSearch,
                                  onPressed: () =>
                                      setState(() => _isSearching = true),
                                ),
                                Expanded(
                                  child: Text(
                                    l10n.communitySearchHint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: filterWidth,
                        height: 48,
                        child: VideoTypeFilterButton(
                          value: _videoTypeFilter,
                          onChanged: (v) =>
                              setState(() => _videoTypeFilter = v),
                        ),
                      ),
                      IconButton(
                        key: const Key('communityContentFilterButton'),
                        icon: const Icon(Icons.tune),
                        tooltip: l10n.communityContentFilterTitle,
                        onPressed: () =>
                            _showContentFilters(communityService),
                      ),
                      if (shortMode)
                        IconButton(
                          icon: const Icon(Icons.view_carousel_outlined),
                          tooltip: l10n.communityShortsModeTooltip,
                          onPressed: () => _openShortsMode(allWorks),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('communityBackToSplashButton'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.homeBackToSplashTooltip,
          onPressed: () => context.go('/'),
        ),
        backgroundColor: barBackground,
        foregroundColor: foreground,
        titleTextStyle: titleStyle,
        iconTheme: IconThemeData(color: foreground),
        actionsIconTheme: IconThemeData(color: foreground),
        toolbarHeight:
            (titleSize.height + 16).clamp(kToolbarHeight, double.infinity).toDouble(),
        title: Text(
          l10n.communityScreenTitle,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${communityService.unreadFollowNotificationCount}'),
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
          const HelpButton(topic: '作品広場'),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56 + tabHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              searchRow,
              TabBar(
                controller: _tabController,
                isScrollable: scrollTabs,
                tabAlignment: scrollTabs
                    ? TabAlignment.start
                    : TabAlignment.fill,
                labelStyle: labelStyle,
                unselectedLabelStyle: labelStyle,
                labelColor: selected,
                unselectedLabelColor: unselected,
                indicatorColor: selected,
                tabs: [
                  for (final label in labels)
                    Tab(text: label, height: tabHeight),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('communityMyWorksButton'),
        heroTag: 'community-my-works',
        mini: MediaQuery.sizeOf(context).height < 400,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        tooltip: l10n.communityMyWorksTitle,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(side: BorderSide.none),
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        onPressed: _openMyWorks,
        child: const Icon(Icons.video_library_outlined),
      ),
      body: desktopCentered(
        context,
        TabBarView(
          controller: _tabController,
          children: [
            Builder(
              builder: (context) {
                final works = _newArrivals(allWorks);
                if (works.isEmpty) {
                  return _pullToRefresh(
                    communityService,
                    _scrollableContent(_buildSearchEmptyState(l10n)),
                  );
                }
                return _pullToRefresh(
                  communityService,
                  _scrollableContent(
                    CommunityWorkGrid(
                      works: works,
                      bookmarkedIds: bookmarkedIds,
                      onTapWork: _openFloatingPreview,
                      onToggleBookmark: (w) => reportFailedCommunityEdit(
                        context,
                        communityService,
                        communityService.toggleBookmark(w.id),
                      ),
                      onTapAuthor: _openAuthorWorks,
                      bottomPadding: 88,
                    ),
                  ),
                );
              },
            ),
            _pullToRefresh(
              communityService,
              _scrollableContent(
                Column(
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
                              onSelected: (_) {
                                setState(() => _period = period);
                                _fetchRanking();
                              },
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ChoiceChip(
                                  avatar: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 16,
                                  ),
                                  label: Text(l10n.communityRankingSortViews),
                                  selected: _sort == _RankingSort.views,
                                  onSelected: (_) {
                                    setState(() => _sort = _RankingSort.views);
                                    _fetchRanking();
                                  },
                                ),
                                ChoiceChip(
                                  avatar: const Icon(Icons.bookmark, size: 16),
                                  label: Text(
                                    l10n.communityRankingSortBookmarks,
                                  ),
                                  selected: _sort == _RankingSort.bookmarks,
                                  onSelected: (_) {
                                    setState(
                                      () => _sort = _RankingSort.bookmarks,
                                    );
                                    _fetchRanking();
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                            ),
                            tooltip: _sortAscending
                                ? l10n.communityRankingSortAscendingTooltip
                                : l10n.communityRankingSortDescendingTooltip,
                            onPressed: () => setState(
                              () => _sortAscending = !_sortAscending,
                            ),
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
                          onToggleBookmark: (w) => reportFailedCommunityEdit(
                            context,
                            communityService,
                            communityService.toggleBookmark(w.id),
                          ),
                          onTapAuthor: _openAuthorWorks,
                          rankNumbers: rankNumbers,
                          bottomPadding: 88,
                        );
                      },
                    ),
                  ],
                ),
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
                  return _pullToRefresh(
                    communityService,
                    _scrollableContent(_buildNoFavoriteAuthorsState(l10n)),
                  );
                }
                if (works.isEmpty) {
                  return _pullToRefresh(
                    communityService,
                    _scrollableContent(_buildSearchEmptyState(l10n)),
                  );
                }
                return _pullToRefresh(
                  communityService,
                  _scrollableContent(
                    CommunityWorkGrid(
                      works: works,
                      bookmarkedIds: bookmarkedIds,
                      onTapWork: _openFloatingPreview,
                      onToggleBookmark: (w) => reportFailedCommunityEdit(
                        context,
                        communityService,
                        communityService.toggleBookmark(w.id),
                      ),
                      onTapAuthor: _openAuthorWorks,
                      repostedByNames: repostedByNames,
                      bottomPadding: 88,
                    ),
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


class _MuteEntry {
  _MuteEntry(this.value, {this.editing = false});
  String value;
  bool editing;
  final FocusNode focusNode = FocusNode();

  void dispose() => focusNode.dispose();
}

/// Edit the draft only. Save commits all fields; Cancel discards everything.
class _ContentFilterDialog extends StatefulWidget {
  const _ContentFilterDialog({
    required this.initialWords,
    required this.initialTags,
    required this.initialHideAi,
  });

  final List<String> initialWords;
  final List<String> initialTags;
  final bool initialHideAi;

  @override
  State<_ContentFilterDialog> createState() => _ContentFilterDialogState();
}

class _ContentFilterDialogState extends State<_ContentFilterDialog> {
  late final List<_MuteEntry> _words;
  late final List<_MuteEntry> _tags;
  late bool _hideAi;

  @override
  void initState() {
    super.initState();
    _words = widget.initialWords.map(_makeEntry).toList();
    _tags = widget.initialTags.map(_makeEntry).toList();
    _hideAi = widget.initialHideAi;
  }

  _MuteEntry _makeEntry(String value, {bool editing = false}) {
    final entry = _MuteEntry(value, editing: editing);
    entry.focusNode.addListener(() {
      if (!entry.focusNode.hasFocus && entry.editing && mounted &&
          (_words.contains(entry) || _tags.contains(entry))) {
        setState(() => entry.editing = false);
      }
    });
    return entry;
  }

  @override
  void dispose() {
    for (final entry in [..._words, ..._tags]) {
      entry.dispose();
    }
    super.dispose();
  }

  void _focusAfterBuild(_MuteEntry entry, List<_MuteEntry> entries) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && entries.contains(entry)) entry.focusNode.requestFocus();
    });
  }

  void _add(List<_MuteEntry> entries) {
    final entry = _makeEntry('', editing: true);
    setState(() => entries.add(entry));
    _focusAfterBuild(entry, entries);
  }

  void _edit(_MuteEntry entry, List<_MuteEntry> entries) {
    setState(() => entry.editing = true);
    _focusAfterBuild(entry, entries);
  }

  void _finishEditing(_MuteEntry entry) {
    entry.focusNode.unfocus();
    if (entry.editing && mounted) {
      setState(() => entry.editing = false);
    }
  }

  void _remove(List<_MuteEntry> entries, _MuteEntry entry) {
    setState(() => entries.remove(entry));
    // Let the removed TextFormField unmount before releasing its focus node.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  Widget _section({
    required String title,
    required String hint,
    required String keyPrefix,
    required List<_MuteEntry> entries,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          softWrap: true,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton.icon(
          key: Key(keyPrefix + 'AddButton'),
          onPressed: () => _add(entries),
          icon: const Icon(Icons.add),
          label: Text(l10n.communityMuteAddNew),
        ),
        for (final entry in entries)
          Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  key: Key(keyPrefix + 'Edit_' + entries.indexOf(entry).toString()),
                  tooltip: l10n.commonEdit,
                  onPressed: () => _edit(entry, entries),
                  icon: const Icon(Icons.edit_outlined),
                ),
                Expanded(
                  child: entry.editing
                      ? TextFormField(
                          key: Key(keyPrefix + 'Entry_' + entries.indexOf(entry).toString()),
                          initialValue: entry.value,
                          focusNode: entry.focusNode,
                          onChanged: (text) => entry.value = text,
                          onFieldSubmitted: (_) => _finishEditing(entry),
                          onTapOutside: (_) => _finishEditing(entry),
                          maxLines: 1,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: title,
                            border: const OutlineInputBorder(),
                          ),
                        )
                      : Padding(
                          key: Key(keyPrefix + 'Display_' + entries.indexOf(entry).toString()),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12,
                          ),
                          child: Text(
                            entry.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                IconButton(
                  key: Key(keyPrefix + 'Delete_' + entries.indexOf(entry).toString()),
                  tooltip: l10n.commonDelete,
                  onPressed: () => _remove(entries, entry),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = opaqueOver(
      theme.dialogTheme.backgroundColor ?? scheme.surfaceContainerHigh,
      theme.scaffoldBackgroundColor,
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(l10n.communityContentFilterTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              title: l10n.communityMutedWords,
              hint: l10n.communityMutedWordsHint,
              keyPrefix: 'communityMutedWords',
              entries: _words,
            ),
            const SizedBox(height: 12),
            _section(
              title: l10n.communityMutedTags,
              hint: l10n.communityMutedTagsHint,
              keyPrefix: 'communityMutedTags',
              entries: _tags,
            ),
            const SizedBox(height: 16),
            SwitchTheme(
              data: SwitchTheme.of(context).copyWith(
                trackOutlineWidth: const WidgetStatePropertyAll(2),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: opaqueOver(
                  scheme.primary.withValues(alpha: 0.2),
                  background,
                ),
                activeThumbColor: scheme.onPrimary,
                thumbIcon: WidgetStatePropertyAll(
                  Icon(Icons.circle_outlined, color: scheme.onSurface, size: 20),
                ),
                inactiveTrackColor: opaqueOver(
                  theme.scaffoldBackgroundColor,
                  background,
                ),
                inactiveThumbColor: scheme.onSurfaceVariant,
                trackOutlineColor: WidgetStatePropertyAll(scheme.onSurface),
                value: _hideAi,
                onChanged: (value) => setState(() => _hideAi = value),
                title: Text(l10n.communityHideGenerativeAiImageVideo),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('communityContentFilterSaveButton'),
          onPressed: () => Navigator.pop(
            context,
            _ContentFilterInput(
              hideAi: _hideAi,
              words: _words.map((entry) => entry.value).toList(),
              tags: _tags.map((entry) => entry.value).toList(),
            ),
          ),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _ContentFilterInput {
  const _ContentFilterInput({
    required this.hideAi,
    required this.words,
    required this.tags,
  });

  final bool hideAi;
  final List<String> words;
  final List<String> tags;
}
