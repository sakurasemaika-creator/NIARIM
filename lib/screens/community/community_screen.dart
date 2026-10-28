import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/api/community_api.dart' show RankingPeriod;
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/dispose_on_unmount.dart';
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
    // Pre-fill with the saved filters, not the empty ones before they load.
    await service.contentFiltersReady;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    // The dialog disposes these once it has really left the tree: its
    // closing transition still reads them after showDialog returns.
    final words = TextEditingController(text: service.mutedWords.join(', '));
    final tags = TextEditingController(text: service.mutedTags.join(', '));
    var hideAi = service.hideGenerativeAiImageVideo;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dialogBackground = opaqueOver(
      theme.dialogTheme.backgroundColor ?? scheme.surfaceContainerHigh,
      theme.scaffoldBackgroundColor,
    );
    final activeTrack = opaqueOver(
      scheme.primary.withValues(alpha: 0.2),
      dialogBackground,
    );
    final inactiveTrack = opaqueOver(
      theme.scaffoldBackgroundColor,
      dialogBackground,
    );
    final trackOutline = scheme.onSurface;
    final result = await showDialog<_ContentFilterInput>(
      context: context,
      builder: (context) => DisposeOnUnmount(
        controller: words,
        builder: (context) => DisposeOnUnmount(
          controller: tags,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: Text(l10n.communityContentFilterTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('communityMutedWordsField'),
                      controller: words,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.communityMutedWords,
                        helper: Text(
                          l10n.communityMutedWordsHint,
                          softWrap: true,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('communityMutedTagsField'),
                      controller: tags,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.communityMutedTags,
                        helper: Text(
                          l10n.communityMutedTagsHint,
                          softWrap: true,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchTheme(
                      data: SwitchTheme.of(context).copyWith(
                        trackOutlineWidth: const WidgetStatePropertyAll(2),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: activeTrack,
                        activeThumbColor: scheme.onPrimary,
                        thumbIcon: WidgetStatePropertyAll(
                          Icon(
                            Icons.circle_outlined,
                            color: scheme.onSurface,
                            size: 20,
                          ),
                        ),
                        inactiveTrackColor: inactiveTrack,
                        inactiveThumbColor: scheme.onSurfaceVariant,
                        trackOutlineColor: WidgetStatePropertyAll(trackOutline),
                        value: hideAi,
                        onChanged: (v) => setDialogState(() => hideAi = v),
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
                      hideAi: hideAi,
                      words: words.text,
                      tags: tags.text,
                    ),
                  ),
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await service.setHideGenerativeAiImageVideo(result.hideAi);
    await service.setMutedWords(
      CommunityService.parseFilterInput(result.words),
    );
    await service.setMutedTags(CommunityService.parseFilterInput(result.tags));
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

    final naturalTitle = measure(l10n.communityScreenTitle, titleStyle);
    final title = measure(
      l10n.communityScreenTitle,
      titleStyle,
      maxWidth: (width - 88).clamp(1.0, double.infinity),
    );
    final videoWidth =
        (measure(
                  _videoTypeFilter.label(l10n),
                  theme.textTheme.bodyMedium!.copyWith(fontSize: 12),
                ).width +
                48)
            .clamp(48.0, (width - 16).clamp(48.0, double.infinity));
    final videoHeight =
        (measure(
                  _videoTypeFilter.label(l10n),
                  theme.textTheme.bodyMedium!.copyWith(fontSize: 12),
                  maxWidth: (videoWidth - 48).clamp(1.0, double.infinity),
                ).height +
                8)
            .clamp(48.0, double.infinity);
    final actions = <Widget>[
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
            label: Text('${communityService.unreadFollowNotificationCount}'),
            isLabelVisible: communityService.unreadFollowNotificationCount > 0,
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
          // Distinct from the video-type filter's funnel next to it.
          key: const Key('communityContentFilterButton'),
          icon: const Icon(Icons.visibility_off_outlined),
          tooltip: l10n.communityContentFilterTitle,
          onPressed: () => _showContentFilters(communityService),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.commonSearch,
          onPressed: () => setState(() => _isSearching = true),
        ),
        const HelpButton(topic: '作品広場'),
      ],
    ];
    final toolbarActions = <Widget>[
      for (final action in actions)
        SizedBox(
          width: action is VideoTypeFilterButton ? videoWidth : 48,
          height: action is VideoTypeFilterButton ? videoHeight : 48,
          child: action,
        ),
    ];
    final actionsWidth = toolbarActions.fold<double>(
      0,
      (sum, item) => sum + (item as SizedBox).width!,
    );
    final separateActions = naturalTitle.width + actionsWidth + 88 > width;
    // Match Wrap's natural rows, keeping every action reachable without
    // sacrificing the screen name to a row of icons.
    var actionsHeight = 0.0;
    var rowWidth = 0.0;
    var rowHeight = 0.0;
    for (final action in toolbarActions.cast<SizedBox>()) {
      if (rowWidth > 0 && rowWidth + action.width! > width - 16) {
        actionsHeight += rowHeight;
        rowWidth = 0;
        rowHeight = 0;
      }
      rowWidth += action.width!;
      if (action.height! > rowHeight) rowHeight = action.height!;
    }
    actionsHeight += rowHeight;
    final labels = [
      l10n.communityTabNew,
      l10n.communityTabRanking,
      l10n.communityTabFavoriteAuthors,
    ];
    final tabWidths = labels.map(
      (label) => measure(label, labelStyle).width + 32,
    );
    final scrollTabs = tabWidths.fold<double>(0, (a, b) => a + b) > width;
    final tabHeight = labels
        .map((label) => measure(label, labelStyle).height + 16)
        .fold<double>(48, (a, b) => a > b ? a : b);
    final searchHeight = (scaler.scale(24) + 16).clamp(56.0, double.infinity);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: barBackground,
        foregroundColor: foreground,
        titleTextStyle: titleStyle,
        iconTheme: IconThemeData(color: foreground),
        actionsIconTheme: IconThemeData(color: foreground),
        toolbarHeight: _isSearching
            ? searchHeight
            : (title.height + 16).clamp(kToolbarHeight, double.infinity),
        title: _isSearching
            ? Row(
                children: [
                  IconButton(
                    key: const Key('communitySearchModeToggle'),
                    icon: Icon(
                      _tagSearchMode ? Icons.search : Icons.sell_outlined,
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
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              )
            : Text(
                l10n.communityScreenTitle,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
        actions: separateActions && !_isSearching ? null : toolbarActions,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            tabHeight +
                (separateActions && !_isSearching ? actionsHeight + 8 : 0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (separateActions && !_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: foreground),
                    child: IconTheme(
                      data: IconThemeData(color: foreground),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        children: toolbarActions,
                      ),
                    ),
                  ),
                ),
              TabBar(
                controller: _tabController,
                isScrollable: scrollTabs,
                // Long localized labels scroll from the leading edge;
                // centering an over-wide TabBar shifts the first tab and
                // makes the underline/text appear misaligned.
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('communityMyWorksButton'),
        onPressed: _openMyWorks,
        icon: const Icon(Icons.video_library_outlined),
        label: Text(l10n.communityMyWorksTitle),
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

/// What the viewer entered in the display-filter dialog, read before the
/// dialog's text controllers are disposed.
class _ContentFilterInput {
  const _ContentFilterInput({
    required this.hideAi,
    required this.words,
    required this.tags,
  });

  final bool hideAi;
  final String words;
  final String tags;
}
