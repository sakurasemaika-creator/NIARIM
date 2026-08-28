import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'widgets/community_work_card.dart';

enum _RankingPeriod { allTime, yearly, monthly, weekly, daily }

enum _RankingSort { views, bookmarks }

/// みんなの作品を見る画面。
///
/// `29_動画投稿・ランキング機能仕様.md`のバックエンド（YouTube投稿・
/// DynamoDB・ランキング集計）は未実装のため、この画面は表示確認用の
/// ダミーデータ（`CommunityService`）のみで動作するUI・デザインの
/// 作り込みに限定している。作品カードをタップするとフローティング動画
/// プレビューウィンドウ（`CommunityFloatingPreview`）が開き、そこから
/// 「詳細へ」ボタンで作品詳細画面（別ルート、`CommunityWorkDetailScreen`）
/// へ遷移する。実際の動画埋め込み・投稿は行わず、該当操作をタップすると
/// 「準備中」である旨を案内する。
class CommunityScreen extends StatefulWidget {
  // 作品詳細画面でタグをタップした際、「タグ検索モードで、この
  // タグを検索語にした状態」でこの画面へ戻ってくるための初期値。
  // 詳細画面はプッシュされた別ルートであり、常にこの画面のインスタンスが
  // まだ生きているとは限らない（フローティングプレビュー経由で他の画面
  // からも詳細画面へ遷移できるため）ため、メソッド直接呼び出しではなく
  // ルート引数（`GoRouterState.extra`）経由でこの初期値を渡す。
  final String? initialTagFilter;

  const CommunityScreen({super.key, this.initialTagFilter});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _RankingPeriod _period = _RankingPeriod.allTime;
  _RankingSort _sort = _RankingSort.views;
  // 作品タイトル・投稿者名のいずれかに一致する作品へ絞り込む検索。
  // バックエンド未実装のため、現状はこの画面が保持するダミーデータへの
  // クライアント側フィルタとして実装している（実データ接続時は
  // 29_動画投稿・ランキング機能仕様.mdの一覧系エンドポイントへ検索
  // クエリパラメータを追加する形になる想定）。
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  // trueのときは検索語をタグの完全一致・部分一致として扱う
  // （「検索ボックスをタグ検索モードに切り替える」機能）。タグチップを
  // 直接タップした場合もこのモードへ切り替えて絞り込む。
  bool _tagSearchMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final initialTag = widget.initialTagFilter;
    if (initialTag != null && initialTag.isNotEmpty) {
      _isSearching = true;
      _tagSearchMode = true;
      _searchQuery = initialTag;
      _searchController.text = initialTag;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// タイトル・投稿者名のいずれかに検索語を含む作品のみへ絞り込む
  /// （大小文字を区別しない部分一致）。検索語が空のときは全件通す。
  /// タグ検索モード時はタイトル・投稿者名の代わりにタグへの部分一致で
  /// 絞り込む。
  List<CommunityWork> _applySearch(List<CommunityWork> works) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return works;
    if (_tagSearchMode) {
      return works
          .where((w) => w.tags.any((t) => t.toLowerCase().contains(query)))
          .toList();
    }
    return works
        .where((w) =>
            w.title.toLowerCase().contains(query) ||
            w.authorName.toLowerCase().contains(query))
        .toList();
  }

  List<CommunityWork> _newArrivals(List<CommunityWork> allWorks) => _applySearch(
      [...allWorks]..sort((a, b) => b.postedAt.compareTo(a.postedAt)));

  /// 期間フィルターに応じたダミーの対象作品を絞り込む。実データでは
  /// バックエンド側で期間別の再生数を集計するが、ここでは投稿日時のみで
  /// 簡易的に絞り込む（表示確認用）。
  List<CommunityWork> _rankingWorks(List<CommunityWork> allWorks) {
    final now = DateTime.now();
    Duration? window;
    switch (_period) {
      case _RankingPeriod.allTime:
        window = null;
      case _RankingPeriod.yearly:
        window = const Duration(days: 365);
      case _RankingPeriod.monthly:
        window = const Duration(days: 30);
      case _RankingPeriod.weekly:
        window = const Duration(days: 7);
      case _RankingPeriod.daily:
        window = const Duration(days: 1);
    }
    final windowed = window == null
        ? allWorks
        : allWorks.where((w) => now.difference(w.postedAt) <= window!);
    final filtered = _applySearch(windowed.toList());
    filtered.sort((a, b) => _sort == _RankingSort.views
        ? b.viewCount.compareTo(a.viewCount)
        : b.bookmarkCount.compareTo(a.bookmarkCount));
    return filtered.take(50).toList();
  }

  /// 作品カードタップ：フローティング動画プレビューウィンドウを開く
  /// （このウィンドウは画面遷移をまたいで表示され続ける。詳細は
  /// `CommunityFloatingPreview`のドキュメントコメントを参照）。
  void _openFloatingPreview(CommunityWork work) {
    context.read<CommunityPreviewService>().show(work);
  }

  void _openAuthorWorks(CommunityWork work) {
    final communityService = context.read<CommunityService>();
    final isSelf = work.authorId == kDummySelfAuthorId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
          // 自分自身の投稿者ページを開いた場合のみ、NIARIM側で非公開に
          // した作品も含めて表示する（再公開の導線を確保するため）。
          works: communityService.worksByAuthor(work.authorId, includeHidden: isSelf),
          bookmarkedIds: communityService.bookmarkedIds,
          onToggleBookmark: (w) => communityService.toggleBookmark(w.id),
          onOpenWork: _openFloatingPreview,
        ),
      ),
    );
  }

  void _showPostComingSoonDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.communityPostComingSoonTitle),
        content: Text(l10n.communityPostComingSoonBody),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonOk)),
        ],
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
            // 通常のタイトル・投稿者名検索と、タグ検索の切り替えボタン。
            // タグをタップした場合もこのモードに切り替わる。
            IconButton(
              icon: Icon(_tagSearchMode ? Icons.sell : Icons.sell_outlined),
              tooltip: _tagSearchMode
                  ? l10n.communityTagSearchModeOnTooltip
                  : l10n.communityTagSearchModeOffTooltip,
              onPressed: () => setState(() {
                _tagSearchMode = !_tagSearchMode;
                _searchQuery = '';
                _searchController.clear();
              }),
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
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.commonSearch,
              onPressed: () => setState(() => _isSearching = true),
            ),
            // topic: 'みんなの作品を見る' はhelp_screen.dart側の項目タイトル
            // （日本語固定の内部検索キー）と一致させる必要があるため、
            // 翻訳対象から除外している。
            const HelpButton(topic: 'みんなの作品を見る'),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.communityTabNew),
            Tab(text: l10n.communityTabRanking),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostComingSoonDialog,
        icon: const Icon(Icons.video_call_outlined),
        label: Text(l10n.communityPostButton),
      ),
      body: desktopCentered(
        context,
        TabBarView(
          controller: _tabController,
          children: [
            Builder(builder: (context) {
              final works = _newArrivals(allWorks);
              if (works.isEmpty) return _buildSearchEmptyState(l10n);
              return SingleChildScrollView(
                child: CommunityWorkGrid(
                  works: works,
                  bookmarkedIds: bookmarkedIds,
                  onTapWork: _openFloatingPreview,
                  onToggleBookmark: (w) => communityService.toggleBookmark(w.id),
                  onTapAuthor: _openAuthorWorks,
                ),
              );
            }),
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
                          avatar: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: Text(l10n.communityRankingSortViews),
                          selected: _sort == _RankingSort.views,
                          onSelected: (_) => setState(() => _sort = _RankingSort.views),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.bookmark, size: 16),
                          label: Text(l10n.communityRankingSortBookmarks),
                          selected: _sort == _RankingSort.bookmarks,
                          onSelected: (_) => setState(() => _sort = _RankingSort.bookmarks),
                        ),
                      ],
                    ),
                  ),
                  Builder(builder: (context) {
                    final ranked = _rankingWorks(allWorks);
                    if (ranked.isEmpty) return _buildSearchEmptyState(l10n);
                    final rankNumbers = {
                      for (int i = 0; i < ranked.length; i++) ranked[i].id: i + 1,
                    };
                    return CommunityWorkGrid(
                      works: ranked,
                      bookmarkedIds: bookmarkedIds,
                      onTapWork: _openFloatingPreview,
                      onToggleBookmark: (w) => communityService.toggleBookmark(w.id),
                      onTapAuthor: _openAuthorWorks,
                      rankNumbers: rankNumbers,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 検索・期間絞り込みの結果、表示する作品が0件になった場合のプレース
  /// ホルダー。検索語が入力されている場合は「該当なし」の案内を、
  /// それ以外（期間フィルターのみで0件等）は汎用の空表示を出す。
  Widget _buildSearchEmptyState(AppLocalizations l10n) {
    final query = _searchQuery.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? l10n.communityEmptyState : l10n.communitySearchNoResults(query),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
