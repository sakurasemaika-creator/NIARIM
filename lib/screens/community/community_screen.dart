import 'dart:math' as math;

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
import '../../config/accent_text_theme.dart';

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
  final _searchFocus = FocusNode();
  final _bodyKey = GlobalKey();
  bool _tagSearchMode = false;
  VideoTypeFilter _videoTypeFilter = VideoTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    // 検索窓を押したら検索の種類（作品名・投稿者名／タグ）を選べるようにする。
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_isSearching) {
        setState(() => _isSearching = true);
      }
    });
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
    _searchFocus.dispose();
    super.dispose();
  }

  static const double _toolbarIconWidth = 48;
  static const double _minSearchFieldWidth = 140;

  void _closeSearch() {
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _tagSearchMode = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  /// 戻るボタンと[title]と、残り[width]の中で画面名が切れずに収まるか。
  static bool _titleFitsBeside(
    BuildContext context,
    String title,
    double width,
  ) {
    final theme = Theme.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width + kToolbarHeight + 32 + 4 <= width;
    painter.dispose();
    return fits;
  }

  /// [labels]のタブを[width]に等分して並べたとき、どのタブ名も切れないか。
  static bool _tabsFitEqually(
    BuildContext context,
    List<String> labels,
    double width,
  ) {
    final theme = Theme.of(context);
    final style = theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall;
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    // タブの左右の余白（16ずつ）を含めて、等分の幅に入るか。
    return widest + 32 <= width / labels.length;
  }

  /// 動画の種類のボタン（漏斗・種類の名前・▼）の幅。
  static double _videoFilterWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + 48 + 8;
    painter.dispose();
    return width;
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
    // 上部のバー（2段）とタブを覆わないよう、一覧の上端に出す。
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    context.read<CommunityPreviewService>().show(
      work,
      top: body?.localToGlobal(Offset.zero).dy,
    );
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
    final activeTrack = opaqueOver(scheme.primary, dialogBackground);
    final inactiveTrack = opaqueOver(
      scheme.surfaceContainerHighest,
      dialogBackground,
    );
    // Use the user's theme foreground roles directly. A content-filter
    // switch must not silently substitute a different color for readability.
    final trackOutline = scheme.outline;
    final result = await showDialog<_ContentFilterInput>(
      context: context,
      builder: (context) => DisposeOnUnmount(
        controller: words,
        builder: (context) => DisposeOnUnmount(
          controller: tags,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(l10n.communityContentFilterTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchTheme(
                      data: SwitchTheme.of(context).copyWith(
                        trackOutlineWidth: const WidgetStatePropertyAll(2),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: activeTrack,
                        activeThumbColor: scheme.onPrimary,
                        inactiveTrackColor: inactiveTrack,
                        inactiveThumbColor: scheme.onSurfaceVariant,
                        trackOutlineColor: WidgetStatePropertyAll(trackOutline),
                        value: hideAi,
                        onChanged: (v) => setDialogState(() => hideAi = v),
                        title: Text(l10n.communityHideGenerativeAiImageVideo),
                      ),
                    ),
                    TextField(
                      key: const Key('communityMutedWordsField'),
                      controller: words,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.communityMutedWords,
                        helperText: l10n.communityMutedWordsHint,
                        helperMaxLines: 5,
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
                        helperText: l10n.communityMutedTagsHint,
                        helperMaxLines: 5,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // 文字ボタンの色はテーマの「アクセントの文字・アイコン色」
                // （差し色を黒や白へ自動で差し替えない）。
                TextButton(
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
    final unread = communityService.unreadFollowNotificationCount;
    final notificationsButton = IconButton(
      key: const Key('communityNotificationsButton'),
      icon: Badge(
        label: Text('$unread'),
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: l10n.communityFollowNotificationsTooltip,
      onPressed: () => Navigator.of(context).push(
        adMockMaterialPageRoute<void>(
          builder: (_) => const CommunityFollowNotificationsScreen(),
        ),
      ),
    );
    const helpButton = HelpButton(topic: '作品広場');
    final filterButtons = <Widget>[
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
        // 目のアイコンは「何のボタンか分かりにくい」（ユーザー指摘）うえ、
        // 自分の投稿では「非公開」の印でもあるので、表示の調整を表すつまみ。
        icon: const Icon(Icons.tune),
        tooltip: l10n.communityContentFilterTitle,
        onPressed: () => _showContentFilters(communityService),
      ),
    ];
    // 上部のバー（ユーザー指定）：1段目は戻る・画面名と、右側に通知とヘルプ。
    // 2段目は左に虫眼鏡の付いた検索窓（残りの幅いっぱい）、右にフィルター2つ。
    // 画面名が長い言語・狭い画面・大きな文字で通知とヘルプを並べると画面名が
    // 切れるときは、2段目の右端へ回す（画面名を途中で切らない、ユーザー指定）。
    // 2段目に検索窓を置く幅が無いときは虫眼鏡のボタンにして、押すと2段目が
    // 検索窓になる。
    final textScaler = MediaQuery.textScalerOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconsBesideTitle = _titleFitsBeside(
      context,
      l10n.communityScreenTitle,
      screenWidth - _toolbarIconWidth * 2,
    );
    final rowHeight = math.max(48.0, textScaler.scale(16) + 32);
    final searchModeHeight =
        12.0 + math.max(44.0, textScaler.scale(14) * 1.4 + 24);
    final fixedWidth =
        _toolbarIconWidth *
            (filterButtons.length - 1 + (iconsBesideTitle ? 0 : 2)) +
        _videoFilterWidth(context, _videoTypeFilter.label(l10n)) +
        16;
    final inlineSearch = screenWidth - fixedWidth >= _minSearchFieldWidth;
    final tabLabels = [
      l10n.communityTabNew,
      l10n.communityTabRanking,
      l10n.communityTabFavoriteAuthors,
    ];
    final tabsFit = _tabsFitEqually(context, tabLabels, screenWidth);

    Widget searchField({required bool autofocus}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: TextField(
        key: const Key('communitySearchField'),
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          hintText: _tagSearchMode
              ? l10n.communityTagSearchHint
              : l10n.communitySearchHint,
          hintMaxLines: 1,
          prefixIcon: Icon(
            _tagSearchMode ? Icons.sell_outlined : Icons.search,
            size: 20,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  key: const Key('communitySearchClose'),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: l10n.commonClose,
                  onPressed: _closeSearch,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _isSearching = true;
        }),
      ),
    );

    final Widget toolbarRow;
    if (inlineSearch) {
      toolbarRow = Row(
        children: [
          const SizedBox(width: 4),
          Expanded(child: searchField(autofocus: false)),
          ...filterButtons,
          if (!iconsBesideTitle) ...[notificationsButton, helpButton],
          const SizedBox(width: 4),
        ],
      );
    } else if (_isSearching) {
      toolbarRow = Row(
        children: [
          const SizedBox(width: 4),
          Expanded(child: searchField(autofocus: true)),
          const SizedBox(width: 4),
        ],
      );
    } else {
      toolbarRow = Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            key: const Key('communitySearchButton'),
            icon: const Icon(Icons.search),
            tooltip: l10n.commonSearch,
            onPressed: () => setState(() => _isSearching = true),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              // 狭い画面・大きな文字では横にスクロールして全部に届く。
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...filterButtons,
                    if (!iconsBesideTitle) ...[notificationsButton, helpButton],
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.communityScreenTitle),
        actions: [
          if (iconsBesideTitle) ...[notificationsButton, helpButton],
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            rowHeight + (_isSearching ? searchModeHeight : 0) + 48,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const Key('communityToolbarActions'),
                height: rowHeight,
                child: toolbarRow,
              ),
              if (_isSearching)
                Container(
                  height: searchModeHeight,
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
                        // 切り替えた後も続けて打てるよう、検索窓へ戻す。
                        _searchFocus.requestFocus();
                      },
                    ),
                  ),
                ),
              // タブ名が等分の幅に入りきらないとき（フランス語の320px等）は、
              // 名前の幅のまま横にスクロールする（以前は「Classeme」の
              // ように途中で切れていた）。
              TabBar(
                key: const Key('communityTabBar'),
                controller: _tabController,
                isScrollable: !tabsFit,
                tabAlignment: tabsFit ? null : TabAlignment.start,
                tabs: [for (final label in tabLabels) Tab(text: label)],
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
          key: _bodyKey,
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
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: const Icon(Icons.bookmark, size: 16),
                            label: Text(l10n.communityRankingSortBookmarks),
                            selected: _sort == _RankingSort.bookmarks,
                            onSelected: (_) {
                              setState(() => _sort = _RankingSort.bookmarks);
                              _fetchRanking();
                            },
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
              color: AccentTextTheme.of(context).withValues(alpha: 0.6),
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
