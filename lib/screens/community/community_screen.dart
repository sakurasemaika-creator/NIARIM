import '../../utils/tolerant_preferences.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/community_plaza_labels.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/api/community_api.dart' show RankingPeriod;
import '../../l10n/community_ranking_layout_labels.dart';
import 'widgets/community_ranking_work_list.dart';
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

enum _PlazaSort { newest, views, bookmarks }

enum _PostDateFilter { all, today, thisWeek, thisMonth, thisYear, custom }

enum _DurationFilterMode { all, upTo, range }

const _communityThresholdChoices = <int>[
  0,
  50,
  100,
  1000,
  5000,
  10000,
  50000,
  100000,
  500000,
  1000000,
];

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
  static const _savedSearchesKey = 'community.savedSearches.v1';
  static const _historyKey = 'community.searchHistory.v1';
  static const _tileWidthKey = 'community.tileMinWidth.v1';
  static const _rankingLayoutKey = 'community.rankingLayout.v1';
  final List<Map<String, dynamic>> _savedSearches = [];
  final List<Map<String, dynamic>> _searchHistory = [];
  String _searchAccount = 'guest';
  _PlazaSort _plazaSort = _PlazaSort.newest;
  late final TabController _tabController;
  _RankingPeriod _period = _RankingPeriod.allTime;
  _RankingSort _sort = _RankingSort.views;
  bool _sortAscending = false;
  String _searchQuery = '';
  String _draftQuery = '';
  final _searchController = TextEditingController();
  bool _tagSearchMode = false;
  VideoTypeFilter _videoTypeFilter = VideoTypeFilter.all;
  _PostDateFilter _postDateFilter = _PostDateFilter.all;
  DateTimeRange? _customPostDateRange;
  bool _tagExactMatch = false;
  double _minimumTileWidth = 160;
  CommunityRankingLayout _rankingLayout = CommunityRankingLayout.horizontal;
  _DurationFilterMode _durationMode = _DurationFilterMode.all;
  double _upToMinutes = 5;
  int _minimumMinutes = 0;
  int _maximumMinutes = 10;
  int _minimumViews = 0;
  int _minimumBookmarks = 0;
  final _tabScrollControllers = List.generate(4, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    _loadSavedSearches();
    _loadTileWidth();
    _loadRankingLayout();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
    final initialTag = widget.initialTagFilter;
    if (initialTag != null && initialTag.isNotEmpty) {
      _tagSearchMode = true;
      _tagExactMatch = true;
      _searchQuery = initialTag;
      _draftQuery = initialTag;
      _searchController.text = initialTag;
      _tabController.index = 3;
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

  Future<void> _loadTileWidth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.readDouble(_tileWidthKey);
      if (saved != null && mounted) {
        setState(
          () => _minimumTileWidth = saved.clamp(120.0, 240.0).toDouble(),
        );
      }
    } catch (error) {
      debugPrint('Community tile width could not be restored: $error');
    }
  }

  Future<void> _loadRankingLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_rankingLayoutKey);
      if (!mounted || saved == null) return;
      final layouts = CommunityRankingLayout.values.where(
        (item) => item.name == saved,
      );
      if (layouts.isNotEmpty) {
        setState(() => _rankingLayout = layouts.first);
      }
    } catch (error) {
      debugPrint('Ranking layout could not be restored: $error');
    }
  }

  Future<void> _setRankingLayout(CommunityRankingLayout value) async {
    setState(() => _rankingLayout = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rankingLayoutKey, value.name);
    } catch (error) {
      debugPrint('Ranking layout could not be saved: $error');
    }
  }

  // History and saved criteria are device-local, scoped to an account.
  void _useSearchAccount(String account) {
    if (_searchAccount == account) return;
    setState(() {
      _searchAccount = account;
      _savedSearches.clear();
      _searchHistory.clear();
    });
    _loadSavedSearches();
  }

  Future<void> _loadSavedSearches() async {
    final account = _searchAccount;
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> read(String key) {
        final raw =
            prefs.readString('$key.$account') ??
            (account == 'guest' && key == _savedSearchesKey
                ? prefs.readString(key)
                : null);
        if (raw == null) return [];
        final decoded = jsonDecode(raw);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .take(10)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      final saved = read(_savedSearchesKey);
      final history = read(_historyKey);
      if (!mounted || account != _searchAccount) return;
      setState(() {
        _savedSearches
          ..clear()
          ..addAll(saved);
        _searchHistory
          ..clear()
          ..addAll(history);
      });
    } catch (error) {
      debugPrint('Community search data could not be loaded: $error');
    }
  }

  Future<void> _persistSavedSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_savedSearchesKey.$_searchAccount',
      jsonEncode(_savedSearches),
    );
  }

  Future<void> _persistSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_historyKey.$_searchAccount',
      jsonEncode(_searchHistory),
    );
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _draftQuery = query;
    });
    if (query.isEmpty) return;
    final snapshot = _currentSearchSnapshot(query);
    setState(() {
      // A repeated identical query is moved to the top.
      _searchHistory.removeWhere(
        (x) =>
            x['query'] == snapshot['query'] &&
            x['tagMode'] == snapshot['tagMode'] &&
            x['exactTag'] == snapshot['exactTag'],
      );
      _searchHistory.insert(0, snapshot);
      if (_searchHistory.length > 10) {
        _searchHistory.removeRange(10, _searchHistory.length);
      }
    });
    await _persistSearchHistory();
  }

  Future<void> _saveSearchFromHistory(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context)!;
    if (_savedSearches.length >= 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.communitySavedSearchLimit)));
      return;
    }
    final snapshot = Map<String, dynamic>.from(item);
    snapshot['name'] = snapshot['query'] as String? ?? '';
    setState(() => _savedSearches.add(snapshot));
    await _persistSavedSearches();
  }

  Future<void> _confirmDeleteSavedSearch(int index) async {
    if (index < 0 || index >= _savedSearches.length) return;
    final l10n = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communityDeleteSavedSearchConfirm),
        content: Text(_savedSearches[index]['name'] as String? ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _deleteSavedSearch(index);
  }

  Map<String, dynamic> _currentSearchSnapshot(String name) => {
    'name': name,
    'query': _searchController.text.trim(),
    'tagMode': _tagSearchMode,
    'exactTag': _tagExactMatch,
    'videoType': _videoTypeFilter.index,
    'dateFilter': _postDateFilter.index,
    'dateStart': _customPostDateRange?.start.toIso8601String(),
    'dateEnd': _customPostDateRange?.end.toIso8601String(),
    'durationMode': _durationMode.index,
    'upToMinutes': _upToMinutes,
    'minimumMinutes': _minimumMinutes,
    'maximumMinutes': _maximumMinutes,
    'minimumViews': _minimumViews,
    'minimumBookmarks': _minimumBookmarks,
  };

  void _restoreSavedSearch(Map<String, dynamic> saved) {
    int choice(String key, int max) =>
        ((saved[key] as num?)?.toInt() ?? 0).clamp(0, max).toInt();
    final start = DateTime.tryParse(saved['dateStart'] as String? ?? '');
    final end = DateTime.tryParse(saved['dateEnd'] as String? ?? '');
    setState(() {
      _draftQuery = saved['query'] as String? ?? '';
      _searchController.text = _draftQuery;
      _tagSearchMode = saved['tagMode'] == true;
      _tagExactMatch = saved['exactTag'] == true;
      _videoTypeFilter = VideoTypeFilter
          .values[choice('videoType', VideoTypeFilter.values.length - 1)];
      _postDateFilter = _PostDateFilter
          .values[choice('dateFilter', _PostDateFilter.values.length - 1)];
      _customPostDateRange = start == null || end == null || end.isBefore(start)
          ? null
          : DateTimeRange(start: start, end: end);
      _durationMode =
          _DurationFilterMode.values[choice(
            'durationMode',
            _DurationFilterMode.values.length - 1,
          )];
      _upToMinutes = ((saved['upToMinutes'] as num?)?.toDouble() ?? 5)
          .clamp(1, 60)
          .toDouble();
      _minimumMinutes = choice('minimumMinutes', 9999);
      _maximumMinutes = choice('maximumMinutes', 9999);
      _minimumViews = choice('minimumViews', 999999999);
      _minimumBookmarks = choice('minimumBookmarks', 999999999);
      if (!_communityThresholdChoices.contains(_minimumViews)) {
        _minimumViews = 0;
      }
      if (!_communityThresholdChoices.contains(_minimumBookmarks)) {
        _minimumBookmarks = 0;
      }
    });
    _tabController.animateTo(3);
    _scrollCurrentTabToTop();
  }

  Future<void> _saveCurrentSearch() async {
    final l10n = AppLocalizations.of(context)!;
    if (_savedSearches.length >= 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.communitySavedSearchLimit)));
      return;
    }
    final controller = TextEditingController(text: _searchController.text);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communitySaveSearch),
        content: TextField(
          key: const Key('communitySavedSearchName'),
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: l10n.communitySavedSearchName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || name == null || name.isEmpty) return;
    setState(() => _savedSearches.add(_currentSearchSnapshot(name)));
    await _persistSavedSearches();
  }

  Future<void> _deleteSavedSearch(int index) async {
    if (index < 0 || index >= _savedSearches.length) return;
    setState(() => _savedSearches.removeAt(index));
    await _persistSavedSearches();
  }

  Future<void> _confirmDeleteHistory(int index) async {
    if (index < 0 || index >= _searchHistory.length) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(CommunityPlazaLabels.of(dialogContext).deleteHistory),
        content: Text(_searchHistory[index]['query'] as String? ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext)!.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(dialogContext)!.commonDelete),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || index >= _searchHistory.length) return;
    setState(() => _searchHistory.removeAt(index));
    await _persistSearchHistory();
  }

  /// The following tab shows the followed authors' works and reposts as
  /// the server has them now.
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final service = context.read<CommunityService>();
    service.clearTemporaryUnmutes();
    if (_tabController.index != 2) return;
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
    service.clearTemporaryUnmutes();
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
  Widget _scrollableContent(Widget child, {required int tab}) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      controller: _tabScrollControllers[tab],
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
        _tagSearchMode = true;
        _tagExactMatch = true;
        _searchQuery = newTag;
        _draftQuery = newTag;
        _searchController.text = newTag;
        _tabController.index = 3;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _matchesPostDate(DateTime postedAt) {
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final start = switch (_postDateFilter) {
      _PostDateFilter.all => null,
      _PostDateFilter.today => startToday,
      _PostDateFilter.thisWeek => startToday.subtract(
        Duration(days: startToday.weekday - DateTime.monday),
      ),
      _PostDateFilter.thisMonth => DateTime(today.year, today.month),
      _PostDateFilter.thisYear => DateTime(today.year),
      _PostDateFilter.custom => _customPostDateRange?.start,
    };
    if (start == null) return true;
    final end = _postDateFilter == _PostDateFilter.custom
        ? _customPostDateRange?.end.add(const Duration(days: 1))
        : null;
    return !postedAt.isBefore(start) && (end == null || postedAt.isBefore(end));
  }

  List<CommunityWork> _applySearch(
    List<CommunityWork> works, {
    bool includeQuery = false,
  }) {
    final typeFiltered = _videoTypeFilter
        .apply(works)
        .where((work) => _matchesPostDate(work.postedAt))
        .where(
          (work) =>
              work.viewCount >= _minimumViews &&
              work.bookmarkCount >= _minimumBookmarks,
        )
        .where(
          (work) => switch (_durationMode) {
            _DurationFilterMode.all => true,
            _DurationFilterMode.upTo =>
              work.durationSeconds <= (_upToMinutes * 60).round(),
            _DurationFilterMode.range =>
              work.durationSeconds >= _minimumMinutes * 60 &&
                  work.durationSeconds <= _maximumMinutes * 60,
          },
        )
        .toList();
    final query = _searchQuery.trim().toLowerCase();
    if (!includeQuery || query.isEmpty) return typeFiltered;
    // Positive terms must all match; -term excludes; quoted phrases supported.
    final terms = RegExp(r'-?"[^"]+"|-?\S+')
        .allMatches(query)
        .map((m) => m.group(0)!)
        .toList();
    bool matches(CommunityWork work, String raw) {
      final term = raw.replaceAll('"', '').replaceFirst(RegExp(r'^#'), '');
      if (term.isEmpty) return false;
      final matchesTag = work.tags.any((tag) {
        final tagName = tag.toLowerCase().replaceFirst(RegExp(r'^[#＃]'), '');
        return _tagExactMatch ? tagName == term : tagName.contains(term);
      });
      if (_tagSearchMode) return matchesTag;
      final title = work.title.toLowerCase();
      return matchesTag ||
          (_tagExactMatch ? title == term : title.contains(term));
    }
    return typeFiltered.where((work) {
      return terms.every((token) {
        final negative = token.startsWith('-') && token.length > 1;
        final word = negative ? token.substring(1) : token;
        final found = matches(work, word);
        return negative ? !found : found;
      });
    }).toList();
  }

  List<CommunityWork> _newArrivals(List<CommunityWork> allWorks) {
    final sorted = [...allWorks];
    sorted.sort(switch (_plazaSort) {
      _PlazaSort.newest => (a, b) => b.postedAt.compareTo(a.postedAt),
      _PlazaSort.views => (a, b) => b.viewCount.compareTo(a.viewCount),
      _PlazaSort.bookmarks => (a, b) => b.bookmarkCount.compareTo(
        a.bookmarkCount,
      ),
    });
    return _applySearch(sorted);
  }

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
      final ranked = [...service.rankedWorks];
      if (_sort == _RankingSort.bookmarks &&
          _period != _RankingPeriod.allTime) {
        ranked.sort((a, b) => b.bookmarkCount.compareTo(a.bookmarkCount));
      }
      return _sortAscending ? ranked.reversed.toList() : ranked;
    }
    // Ranking is not subject to the search tab or local filter criteria.
    final filtered = allWorks.toList();
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
    context.read<CommunityService>().clearTemporaryUnmutes();
    Navigator.of(context).push(
      adMockMaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
        ),
      ),
    );
  }

  Future<void> _showContentFilters(CommunityService service, {bool muteOnly = false}) async {
    await service.contentFiltersReady;
    if (!mounted) return;
    final result = await showDialog<_ContentFilterInput>(
      context: context,
      builder: (_) => _ContentFilterDialog(
        muteOnly: muteOnly,
        initialWords: service.mutedWords.toList(),
        initialTags: service.mutedTags.toList(),
        initialHideAi: service.hideGenerativeAiImageVideo,
        initialDateFilter: _postDateFilter,
        initialDateRange: _customPostDateRange,
        initialExactTag: _tagExactMatch,
        initialDurationMode: _durationMode,
        initialUpToMinutes: _upToMinutes,
        initialMinimumMinutes: _minimumMinutes,
        initialMaximumMinutes: _maximumMinutes,
        initialMinimumViews: _minimumViews,
        initialMinimumBookmarks: _minimumBookmarks,
        initialTileWidth: _minimumTileWidth,
      ),
    );
    if (result == null) return;
    if (muteOnly) {
      await service.setMutedWords(result.words);
      await service.setMutedTags(result.tags);
      return;
    }
    await service.setHideGenerativeAiImageVideo(result.hideAi);
    if (mounted) {
      setState(() {
        _postDateFilter = result.dateFilter;
        _customPostDateRange = result.dateRange;
        _durationMode = result.durationMode;
        _upToMinutes = result.upToMinutes;
        _minimumMinutes = result.minimumMinutes;
        _maximumMinutes = result.maximumMinutes;
        _minimumViews = result.minimumViews;
        _minimumBookmarks = result.minimumBookmarks;
        _minimumTileWidth = result.tileWidth;
      });
    }
  }

  void _scrollCurrentTabToTop() {
    final controller = _tabScrollControllers[_tabController.index];
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _openMyWorks() {
    context.read<CommunityService>().clearTemporaryUnmutes();
    Navigator.of(context).push(
      adMockMaterialPageRoute<void>(
        builder: (_) => const CommunityMyWorksScreen(),
      ),
    );
  }

  void _openShortsMode(List<CommunityWork> allWorks) {
    context.read<CommunityService>().clearTemporaryUnmutes();
    final base = switch (_tabController.index) {
      0 => _newArrivals(allWorks),
      1 => _rankingWorks(allWorks),
      2 => _applySearch(context.read<CommunityService>().favoriteAuthorWorks),
      _ => _applySearch(allWorks, includeQuery: true),
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
    final currentAccount = communityService.currentUserId ?? 'guest';
    if (_searchAccount != currentAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _useSearchAccount(currentAccount);
      });
    }
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
      maxWidth: (width - 216).clamp(1.0, double.infinity),
    );
    final labels = [
      l10n.communityTabNew,
      l10n.communityTabRanking,
      l10n.communityTabFavoriteAuthors,
      CommunityPlazaLabels.of(context).searchTab,
    ];
    final tabWidths = labels.map(
      (label) => measure(label, labelStyle).width + 32,
    );
    final scrollTabs = tabWidths.fold<double>(0, (a, b) => a + b) > width;
    final tabHeight = labels
        .map((label) => measure(label, labelStyle).height + 16)
        .fold<double>(48, (a, b) => a > b ? a : b);
    final searchFill =
        theme.inputDecorationTheme.fillColor ?? scheme.surfaceContainerLow;
    Widget searchRowFor(int tab) {
      final headingStyle = theme.textTheme.titleSmall?.copyWith(
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
      );

      Widget accordion({
        required String title,
        required Key key,
        required bool saved,
      }) {
        final entries = saved ? _savedSearches : _searchHistory;
        return ExpansionTile(
          key: key,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(title, style: headingStyle)),
              const SizedBox(width: 6),
              Text('(${entries.length}/10)', style: theme.textTheme.bodySmall),
            ],
          ),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  saved
                      ? l10n.communitySavedSearchEmpty
                      : l10n.communitySearchHistoryEmpty,
                ),
              ),
            for (var index = 0; index < entries.length; index++)
              ListTile(
                key: ValueKey(
                  (saved
                          ? 'communitySavedSearch-'
                          : 'communitySearchHistory-') +
                      index.toString(),
                ),
                dense: true,
                title: Text(
                  entries[index]['name'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _restoreSavedSearch(entries[index]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!saved)
                      IconButton(
                        key: ValueKey('communitySaveHistory-$index'),
                        icon: const Icon(Icons.save_outlined),
                        tooltip: l10n.communitySaveSearch,
                        onPressed: () => _saveSearchFromHistory(entries[index]),
                      ),
                    IconButton(
                      key: ValueKey(saved
                          ? 'communityDeleteSavedSearch-$index'
                          : 'communityDeleteHistory-$index'),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.commonDelete,
                      onPressed: () => saved
                          ? _confirmDeleteSavedSearch(index)
                          : _confirmDeleteHistory(index),
                    ),
                  ],
                ),
              ),
            if (saved)
              TextButton.icon(
                key: const Key('communitySaveCurrentSearchButton'),
                onPressed: _saveCurrentSearch,
                icon: const Icon(Icons.add),
                label: Text(l10n.communitySaveSearch),
              ),
          ],
        );
      }

      return Padding(
        key: const Key('communitySearchRow'),
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tab == 3) ...[
            Material(
              key: const Key('communitySearchTrigger'),
              color: searchFill,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 48,
                child: Row(
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
                        _draftQuery = '';
                        _searchController.clear();
                      }),
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('communitySearchInput'),
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _tagSearchMode
                              ? l10n.communityTagSearchHint
                              : l10n.communitySearchHint,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) => _draftQuery = value,
                        onSubmitted: (_) => _runSearch(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: l10n.commonClose,
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _draftQuery = '';
                        _searchQuery = '';
                      }),
                    ),
                  ],
                ),
              ),
            ),
            CheckboxListTile(
              key: const Key('communitySearchExactMatch'),
              value: _tagExactMatch,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(CommunityPlazaLabels.of(context).exactTitle),
              onChanged: (enabled) =>
                  setState(() => _tagExactMatch = enabled ?? false),
            ),
            accordion(
              title: l10n.communitySavedSearches,
              key: const Key('communitySavedSearchAccordion'),
              saved: true,
            ),
            accordion(
              title: l10n.communitySearchHistory,
              key: const Key('communitySearchHistoryAccordion'),
              saved: false,
            ),
            ],
            Row(
              children: [
                IconButton(
                  key: const Key('communityContentFilterButton'),
                  icon: const Icon(Icons.tune),
                  tooltip: l10n.communityContentFilterTitle,
                  onPressed: () => _showContentFilters(communityService),
                ),
                PopupMenuButton<String>(
                  key: const Key('communitySortButton'),
                  tooltip: l10n.communitySortLabel,
                  icon: const Icon(Icons.sort),
                  onSelected: (value) {
                    if (value == 'shorts') {
                      _openShortsMode(allWorks);
                      return;
                    }
                    setState(() {
                      if (value.startsWith('type:')) {
                        final index = int.tryParse(value.substring(5)) ?? 0;
                        _videoTypeFilter =
                            VideoTypeFilter.values[index.clamp(
                              0,
                              VideoTypeFilter.values.length - 1,
                            )];
                      } else {
                        _plazaSort = switch (value) {
                          'views' => _PlazaSort.views,
                          'bookmarks' => _PlazaSort.bookmarks,
                          _ => _PlazaSort.newest,
                        };
                      }
                    });
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'newest',
                      child: Text(l10n.communityTabNew),
                    ),
                    PopupMenuItem(
                      value: 'views',
                      child: Text(l10n.communityRankingSortViews),
                    ),
                    PopupMenuItem(
                      value: 'bookmarks',
                      child: Text(l10n.communityRankingSortBookmarks),
                    ),
                    const PopupMenuDivider(),
                    for (final type in VideoTypeFilter.values)
                      CheckedPopupMenuItem(
                        value: 'type:${type.index}',
                        checked: type == _videoTypeFilter,
                        child: Text(type.label(l10n)),
                      ),
                    if (_videoTypeFilter == VideoTypeFilter.shortOnly)
                      PopupMenuItem(
                        value: 'shorts',
                        child: Text(l10n.communityShortsModeTooltip),
                      ),
                  ],
                ),
                  IconButton(
                  key: const Key('communityTileSizeButton'),
                  tooltip: l10n.communityTileSize,
                  icon: const Icon(Icons.grid_view_rounded),
                  onPressed: () async {
                    var size = _minimumTileWidth;
                    final chosen = await showDialog<double>(
                      context: context,
                      builder: (dialogContext) => StatefulBuilder(
                        builder: (dialogContext, update) => AlertDialog(
                          title: Text(l10n.communityTileSize),
                          content: Slider(
                            key: const Key('communityTileSizeQuickSlider'),
                            min: 120,
                            max: 240,
                            divisions: 6,
                            value: size,
                            onChanged: (next) => update(() => size = next),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(l10n.commonCancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, size),
                              child: Text(l10n.commonSave),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (chosen != null && mounted) {
                      setState(() => _minimumTileWidth = chosen);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble(_tileWidthKey, chosen);
                    }
                  },
                ),
                const Spacer(),
                if (tab == 3)
                FilledButton(
                  key: const Key('communitySearchButton'),
                  onPressed: _runSearch,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 48),
                    maximumSize: const Size(132, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l10n.commonSearch, maxLines: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('communityBackToSplashButton'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.homeBackToSplashTooltip,
          onPressed: () {
            communityService.clearTemporaryUnmutes();
            context.go('/');
          },
        ),
        backgroundColor: barBackground,
        foregroundColor: foreground,
        titleTextStyle: titleStyle,
        iconTheme: IconThemeData(color: foreground),
        actionsIconTheme: IconThemeData(color: foreground),
        toolbarHeight: (titleSize.height + 16)
            .clamp(kToolbarHeight, double.infinity)
            .toDouble(),
        title: Text(
          l10n.communityScreenTitle,
          softWrap: true,
          maxLines: 3,
          overflow: TextOverflow.visible,
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${communityService.unreadMilestoneCount}'),
              isLabelVisible: communityService.unreadMilestoneCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: l10n.communityFollowNotificationsTooltip,
            onPressed: () => Navigator.of(context).push(
              adMockMaterialPageRoute<void>(
                builder: (_) => const CommunityFollowNotificationsScreen(),
              ),
            ),
          ),
          IconButton(
            key: const Key('communityMuteSettingsButton'),
            icon: const Icon(Icons.visibility_off_outlined),
            tooltip: CommunityPlazaLabels.of(context).muteSettings,
            onPressed: () =>
                _showContentFilters(communityService, muteOnly: true),
          ),
          const HelpButton(topic: '作品広場'),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabHeight),
          child: TabBar(
            controller: _tabController,
            isScrollable: scrollTabs,
            tabAlignment: scrollTabs ? TabAlignment.start : TabAlignment.fill,
            labelStyle: labelStyle,
            unselectedLabelStyle: labelStyle,
            labelColor: selected,
            unselectedLabelColor: unselected,
            indicatorColor: selected,
            tabs: [
              for (final label in labels) Tab(text: label, height: tabHeight),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              key: const Key('communityScrollToTopButton'),
              heroTag: 'community-scroll-to-top',
              tooltip: l10n.communityScrollToTop,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: const CircleBorder(side: BorderSide.none),
              elevation: 0,
              onPressed: _scrollCurrentTabToTop,
              child: const Icon(Icons.arrow_upward),
            ),
            FloatingActionButton(
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
          ],
        ),
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
                    _scrollableContent(
                      Column(
                        children: [
                          searchRowFor(0),
                          _buildSearchEmptyState(l10n),
                        ],
                      ),
                      tab: 0,
                    ),
                  );
                }
                return _pullToRefresh(
                  communityService,
                  _scrollableContent(
                    Column(
                      children: [
                        searchRowFor(0),
                        CommunityWorkGrid(
                          minTileWidth: _minimumTileWidth,
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
                      ],
                    ),
                    tab: 0,
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
                PopupMenuButton<CommunityRankingLayout>(
                    key: const Key('communityRankingLayoutButton'),
                    tooltip: CommunityRankingLayoutLabels.of(context).title,
                    icon: Icon(
                      _rankingLayout == CommunityRankingLayout.horizontal
                          ? Icons.view_agenda_outlined
                          : Icons.view_stream_outlined,
                    ),
                    onSelected: _setRankingLayout,
                    itemBuilder: (context) {
                      final words = CommunityRankingLayoutLabels.of(context);
                      return [
                        CheckedPopupMenuItem(
                          value: CommunityRankingLayout.horizontal,
                          checked:
                              _rankingLayout == CommunityRankingLayout.horizontal,
                          child: Text(words.horizontal),
                        ),
                        CheckedPopupMenuItem(
                          value: CommunityRankingLayout.largeThumbnail,
                          checked: _rankingLayout ==
                              CommunityRankingLayout.largeThumbnail,
                          child: Text(words.largeThumbnail),
                        ),
                      ];
                    },
                  )
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final ranked = _rankingWorks(allWorks);
                        if (ranked.isEmpty) return _buildSearchEmptyState(l10n);
                        return CommunityRankingWorkList(
                          layout: _rankingLayout,
                          works: ranked,
                          bookmarkedIds: bookmarkedIds,
                          onTapWork: _openFloatingPreview,
                          onToggleBookmark: (w) => reportFailedCommunityEdit(
                            context,
                            communityService,
                            communityService.toggleBookmark(w.id),
                          ),
                          onTapAuthor: _openAuthorWorks,
                          bottomPadding: 88,
                        );
                      },
                    ),
                  ],
                ),
                tab: 1,
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
                    _scrollableContent(
                      Column(
                        children: [
                          searchRowFor(2),
                          _buildNoFavoriteAuthorsState(l10n),
                        ],
                      ),
                      tab: 2,
                    ),
                  );
                }
                if (works.isEmpty) {
                  return _pullToRefresh(
                    communityService,
                    _scrollableContent(
                      Column(
                        children: [
                          searchRowFor(2),
                          _buildSearchEmptyState(l10n),
                        ],
                      ),
                      tab: 2,
                    ),
                  );
                }
                return _pullToRefresh(
                  communityService,
                  _scrollableContent(
                    Column(
                      children: [
                        searchRowFor(2),
                        CommunityWorkGrid(
                          minTileWidth: _minimumTileWidth,
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
                      ],
                    ),
                    tab: 2,
                  ),
                );
              },
            ),
            Builder(
              builder: (context) {
                final works = _applySearch(
                  allWorks.toList(),
                  includeQuery: true,
                );
                return _pullToRefresh(
                  communityService,
                  _scrollableContent(
                    Column(
                      children: [
                        searchRowFor(3),
                        if (works.isEmpty)
                          _buildSearchEmptyState(l10n)
                        else
                          CommunityWorkGrid(
                            minTileWidth: _minimumTileWidth,
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
                      ],
                    ),
                    tab: 3,
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
    this.muteOnly = false,
    required this.initialWords,
    required this.initialTags,
    required this.initialHideAi,
    required this.initialDateFilter,
    required this.initialDateRange,
    required this.initialExactTag,
    required this.initialDurationMode,
    required this.initialUpToMinutes,
    required this.initialMinimumMinutes,
    required this.initialMaximumMinutes,
    required this.initialMinimumViews,
    required this.initialMinimumBookmarks,
    required this.initialTileWidth,
  });

  final bool muteOnly;
  final List<String> initialWords;
  final List<String> initialTags;
  final bool initialHideAi;
  final _PostDateFilter initialDateFilter;
  final DateTimeRange? initialDateRange;
  final bool initialExactTag;
  final _DurationFilterMode initialDurationMode;
  final double initialUpToMinutes;
  final int initialMinimumMinutes;
  final int initialMaximumMinutes;
  final int initialMinimumViews;
  final int initialMinimumBookmarks;
  final double initialTileWidth;

  @override
  State<_ContentFilterDialog> createState() => _ContentFilterDialogState();
}

class _ContentFilterDialogState extends State<_ContentFilterDialog> {
  late final List<_MuteEntry> _words;
  late final List<_MuteEntry> _tags;
  late bool _hideAi;
  late _PostDateFilter _dateFilter;
  DateTimeRange? _dateRange;
  late bool _exactTag;
  late _DurationFilterMode _durationMode;
  late double _upToMinutes;
  late int _minimumMinutes;
  late int _maximumMinutes;
  late int _minimumViews;
  late int _minimumBookmarks;
  late double _tileWidth;

  @override
  void initState() {
    super.initState();
    _words = widget.initialWords.map(_makeEntry).toList();
    _tags = widget.initialTags.map(_makeEntry).toList();
    _hideAi = widget.initialHideAi;
    _dateFilter = widget.initialDateFilter;
    _dateRange = widget.initialDateRange;
    _exactTag = widget.initialExactTag;
    _durationMode = widget.initialDurationMode;
    _upToMinutes = widget.initialUpToMinutes;
    _minimumMinutes = widget.initialMinimumMinutes;
    _maximumMinutes = widget.initialMaximumMinutes;
    _minimumViews = widget.initialMinimumViews;
    _minimumBookmarks = widget.initialMinimumBookmarks;
    _tileWidth = widget.initialTileWidth;
  }

  _MuteEntry _makeEntry(String value, {bool editing = false}) {
    final entry = _MuteEntry(value, editing: editing);
    entry.focusNode.addListener(() {
      if (!entry.focusNode.hasFocus &&
          entry.editing &&
          mounted &&
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
    required String emptyLabel,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ExpansionTile(
      key: Key('${keyPrefix}Accordion'),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      children: [
        const SizedBox(height: 6),
        Text(
          hint,
          softWrap: true,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton.icon(
          key: Key('${keyPrefix}AddButton'),
          onPressed: () => _add(entries),
          icon: const Icon(Icons.add),
          label: Text(l10n.communityMuteAddNew),
        ),
        if (entries.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(emptyLabel)),
        for (final entry in entries)
          Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  key: Key('${keyPrefix}Edit_${entries.indexOf(entry)}'),
                  tooltip: l10n.commonEdit,
                  onPressed: () => _edit(entry, entries),
                  icon: const Icon(Icons.edit_outlined),
                ),
                Expanded(
                  child: entry.editing
                      ? TextFormField(
                          key: Key(
                            '${keyPrefix}Entry_${entries.indexOf(entry)}',
                          ),
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
                      : InkWell(
                          key: Key(
                            '${keyPrefix}Display_${entries.indexOf(entry)}',
                          ),
                          onTap: () => _edit(entry, entries),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Text(
                              entry.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ),
                IconButton(
                  key: Key('${keyPrefix}Delete_${entries.indexOf(entry)}'),
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

  String _dateLabel(AppLocalizations l10n, _PostDateFilter date) =>
      switch (date) {
        _PostDateFilter.all => l10n.communityPostPeriodAll,
        _PostDateFilter.today => l10n.communityPostPeriodToday,
        _PostDateFilter.thisWeek => l10n.communityPostPeriodWeek,
        _PostDateFilter.thisMonth => l10n.communityPostPeriodMonth,
        _PostDateFilter.thisYear => l10n.communityPostPeriodYear,
        _PostDateFilter.custom => l10n.communityPostPeriodCustom,
      };

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2005),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateRange = picked;
        _dateFilter = _PostDateFilter.custom;
      });
    }
  }

  Future<void> _manageMutedAuthors() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communityMutedAuthors),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CommunityPlazaLabels.of(dialogContext).mutePrivacyNotice,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(child: SizedBox(
          width: 420,
          child: Consumer<CommunityService>(
            builder: (_, service, _) {
              final muted = service.mutedAuthorIds.toList()
                ..sort(
                  (a, b) => (service.authorNameOf(a) ?? a).compareTo(
                    service.authorNameOf(b) ?? b,
                  ),
                );
              if (muted.isEmpty) return Text(l10n.communityMutedAuthorsEmpty);
              return ListView.builder(
                shrinkWrap: true,
                itemCount: muted.length,
                itemBuilder: (_, i) {
                  final id = muted[i];
                  final name = service.authorNameOf(id) ?? id;
                  return ListTile(
                    key: ValueKey('communityMutedAuthor-$id'),
                    title: Text(name),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).push(
                        adMockMaterialPageRoute<void>(
                          builder: (_) => CommunityAuthorWorksScreen(
                            authorId: id,
                            authorName: name,
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      key: ValueKey('communityUnmuteAuthor-$id'),
                      tooltip: l10n.communityUnmuteAuthor,
                      onPressed: () => confirmCommunityAuthorMute(
                        context,
                        service,
                        id,
                        mute: false,
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  );
                },
              );
            },
          ))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
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
      title: Text(widget.muteOnly
          ? CommunityPlazaLabels.of(context).muteSettings
          : l10n.communityContentFilterTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.muteOnly) ...[
            Text(
              l10n.communityPostPeriodTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            DropdownButtonFormField<_PostDateFilter>(
              key: const Key('communityPostDateFilter'),
              initialValue: _dateFilter,
              isExpanded: true,
              items: [
                for (final date in _PostDateFilter.values)
                  DropdownMenuItem(
                    value: date,
                    child: Text(_dateLabel(l10n, date)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == _PostDateFilter.custom) {
                  _chooseDateRange();
                } else {
                  setState(() => _dateFilter = value);
                }
              },
            ),
            if (_dateFilter == _PostDateFilter.custom)
              TextButton.icon(
                key: const Key('communityPostDateChooseRange'),
                onPressed: _chooseDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _dateRange == null
                      ? l10n.communityPostPeriodChooseRange
                      : '${MaterialLocalizations.of(context).formatShortDate(_dateRange!.start)} - ${MaterialLocalizations.of(context).formatShortDate(_dateRange!.end)}',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              l10n.communityDurationFilterTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            DropdownButtonFormField<_DurationFilterMode>(
              key: const Key('communityDurationMode'),
              initialValue: _durationMode,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: _DurationFilterMode.all,
                  child: Text(l10n.communityDurationAny),
                ),
                DropdownMenuItem(
                  value: _DurationFilterMode.upTo,
                  child: Text(l10n.communityDurationUpTo),
                ),
                DropdownMenuItem(
                  value: _DurationFilterMode.range,
                  child: Text(l10n.communityDurationRange),
                ),
              ],
              onChanged: (value) => setState(
                () => _durationMode = value ?? _DurationFilterMode.all,
              ),
            ),
            if (_durationMode == _DurationFilterMode.upTo) ...[
              Text('${_upToMinutes.round()} ${l10n.communityDurationMinutes}'),
              Slider(
                key: const Key('communityDurationSlider'),
                value: _upToMinutes,
                min: 1,
                max: 60,
                divisions: 59,
                label: '${_upToMinutes.round()}',
                onChanged: (value) => setState(() => _upToMinutes = value),
              ),
            ],
            if (_durationMode == _DurationFilterMode.range)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('communityDurationMinimum'),
                      initialValue: '$_minimumMinutes',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.communityDurationMinimum,
                      ),
                      onChanged: (value) => _minimumMinutes =
                          (int.tryParse(value) ?? 0).clamp(0, 9999).toInt(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('communityDurationMaximum'),
                      initialValue: '$_maximumMinutes',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.communityDurationMaximum,
                      ),
                      onChanged: (value) => _maximumMinutes =
                          (int.tryParse(value) ?? 0).clamp(0, 9999).toInt(),
                    ),
                  ),
                ],
              ),
            for (final filter in [0, 1]) ...[
              const SizedBox(height: 12),
              Text(
                filter == 0
                    ? l10n.communityMinimumViews
                    : l10n.communityMinimumBookmarks,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              DropdownButtonFormField<int>(
                key: Key(
                  filter == 0
                      ? 'communityMinimumViews'
                      : 'communityMinimumBookmarks',
                ),
                initialValue: filter == 0 ? _minimumViews : _minimumBookmarks,
                isExpanded: true,
                items: [
                  for (final count in _communityThresholdChoices)
                    DropdownMenuItem(
                      value: count,
                      child: Text(
                        count == 0
                            ? l10n.communityThresholdAny
                            : filter == 0
                            ? l10n.communityMinimumViewsOption(
                                NumberFormat.decimalPattern().format(count),
                              )
                            : l10n.communityMinimumBookmarksOption(
                                NumberFormat.decimalPattern().format(count),
                              ),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  if (filter == 0) {
                    _minimumViews = value ?? 0;
                  } else {
                    _minimumBookmarks = value ?? 0;
                  }
                }),
              ),
            ],
            ],
            if (widget.muteOnly) ...[
            _section(
              title: l10n.communityMutedWords,
              hint: l10n.communityMutedWordsHint,
              keyPrefix: 'communityMutedWords',
              entries: _words,
              emptyLabel: l10n.communityMutedWordsEmpty,
            ),
            const SizedBox(height: 12),
            _section(
              title: l10n.communityMutedTags,
              hint: l10n.communityMutedTagsHint,
              keyPrefix: 'communityMutedTags',
              entries: _tags,
              emptyLabel: l10n.communityMutedTagsEmpty,
            ),
            ExpansionTile(
              key: const Key('communityMutedAuthorsAccordion'),
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              initiallyExpanded: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.communityMutedAuthors,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CommunityPlazaLabels.of(context).mutePrivacyNotice,
                    key: const Key('communityMutePrivacyNoticeSettings'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              children: [
                Consumer<CommunityService>(
                  builder: (_, service, _) {
                    final ids = service.mutedAuthorIds.toList()..sort();
                    if (ids.isEmpty) {
                      return Text(l10n.communityMutedAuthorsEmpty);
                    }
                    return Column(
                      children: [
                        for (final id in ids)
                          ListTile(
                            key: ValueKey('communityMutedAuthorInline-$id'),
                            title: Text(service.authorNameOf(id) ?? id),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              final name = service.authorNameOf(id) ?? id;
                              navigator.pop();
                              navigator.push(
                                adMockMaterialPageRoute<void>(
                                  builder: (_) => CommunityAuthorWorksScreen(
                                    authorId: id,
                                    authorName: name,
                                  ),
                                ),
                              );
                            },
                            trailing: IconButton(
                              key: ValueKey('communityUnmuteAuthorInline-$id'),
                              tooltip: l10n.communityUnmuteAuthor,
                              onPressed: () =>
                                  service.setAuthorMuted(id, false),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                TextButton.icon(
                  key: const Key('communityManageMutedAuthors'),
                  onPressed: _manageMutedAuthors,
                  icon: const Icon(Icons.person_off_outlined),
                  label: Text(l10n.communityMutedAuthors),
                ),
              ],
            ),
            ],
            if (!widget.muteOnly)
            SwitchTheme(
              data: SwitchTheme.of(
                context,
              ).copyWith(trackOutlineWidth: const WidgetStatePropertyAll(2)),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: opaqueOver(
                  scheme.primary.withValues(alpha: 0.2),
                  background,
                ),
                activeThumbColor: scheme.onPrimary,
                thumbIcon: WidgetStatePropertyAll(
                  Icon(
                    Icons.circle_outlined,
                    color: scheme.onSurface,
                    size: 20,
                  ),
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
              dateFilter:
                  _dateFilter == _PostDateFilter.custom && _dateRange == null
                  ? _PostDateFilter.all
                  : _dateFilter,
              dateRange: _dateRange,
              exactTag: _exactTag,
              durationMode: _durationMode,
              upToMinutes: _upToMinutes,
              minimumMinutes: _minimumMinutes,
              maximumMinutes: _maximumMinutes,
              minimumViews: _minimumViews,
              minimumBookmarks: _minimumBookmarks,
              tileWidth: _tileWidth,
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
    required this.dateFilter,
    required this.dateRange,
    required this.exactTag,
    required this.durationMode,
    required this.upToMinutes,
    required this.minimumMinutes,
    required this.maximumMinutes,
    required this.minimumViews,
    required this.minimumBookmarks,
    required this.tileWidth,
  });

  final bool hideAi;
  final List<String> words;
  final List<String> tags;
  final _PostDateFilter dateFilter;
  final DateTimeRange? dateRange;
  final bool exactTag;
  final _DurationFilterMode durationMode;
  final double upToMinutes;
  final int minimumMinutes;
  final int maximumMinutes;
  final int minimumViews;
  final int minimumBookmarks;
  final double tileWidth;
}
