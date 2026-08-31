import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'community_follow_notifications_screen.dart';
import 'widgets/community_shorts_viewer.dart';
import 'widgets/community_work_card.dart';
import 'widgets/video_type_filter.dart';

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
  // ランキングの並び順。falseで降順（多い順、既定）、trueで昇順（少ない順）。
  bool _sortAscending = false;
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
  // 「総合」「縦画面のみ」「横画面のみ」の絞り込み。新着・ランキング・
  // お気に入り作者タブすべてで共通に使うタブ横断の状態（AppBar上の
  // プルダウンで切り替える）。
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
    // タグ検索から別のタグ検索へ連続でナビゲートした場合の保険。
    // 通常はpush()により毎回新しいStateが作られてinitState()側で
    // 初期値が適用されるが、go_router側の実装次第でState（この
    // Widgetインスタンス）が使い回された場合でも、新しいinitialTagFilterを
    // 取りこぼさないようにする。
    final newTag = widget.initialTagFilter;
    if (newTag != null && newTag.isNotEmpty && newTag != oldWidget.initialTagFilter) {
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

  /// タイトル・投稿者名のいずれかに検索語を含む作品のみへ絞り込む
  /// （大小文字を区別しない部分一致）。検索語が空のときは全件通す。
  /// タグ検索モード時はタイトル・投稿者名の代わりにタグへの部分一致で
  /// 絞り込む。
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
        .where((w) =>
            w.title.toLowerCase().contains(query) ||
            w.authorName.toLowerCase().contains(query))
        .toList();
  }

  List<CommunityWork> _newArrivals(List<CommunityWork> allWorks) => _applySearch(
      [...allWorks]..sort((a, b) => b.postedAt.compareTo(a.postedAt)));

  /// 期間別ランキングのスコア算出に使う「期間の長さ」。全期間はnull
  /// （減衰なし＝累計の再生・ブックマーク数をそのまま使う）。
  Duration? _periodWindow(_RankingPeriod period) => switch (period) {
        _RankingPeriod.allTime => null,
        _RankingPeriod.yearly => const Duration(days: 365),
        _RankingPeriod.monthly => const Duration(days: 30),
        _RankingPeriod.weekly => const Duration(days: 7),
        _RankingPeriod.daily => const Duration(days: 1),
      };

  /// ランキング対象の作品を並び替える。
  ///
  /// 以前は`_period`（年間/月間/週間/デイリー）に応じて「投稿日時が
  /// その期間内かどうか」で対象を絞り込んでいたが、ダミーデータの投稿日は
  /// 古いものが多く、月間・週間・デイリーのランキングがほぼ空になって
  /// しまうバグがあった。またそもそも「投稿日で足切りする」のは要件
  /// （期間内に再生・ブックマークされた回数で並び替える）とも異なる。
  ///
  /// 本来は期間ごとの再生・ブックマーク数の時系列集計が必要（backend側にも
  /// 未実装、backend/README.mdの「未実装・既知の制約」参照）だが、現段階
  /// ではその時系列データ自体を持たないため、「累計の再生・ブックマーク数」
  /// に対して投稿の新しさで重み付けする近似で代用する：期間の範囲内に
  /// 投稿された作品は満点（重み1.0）、範囲外の作品は古いほど重みが
  /// なだらかに下がる（0にはならない＝対象から除外されることはない）。
  /// これにより、期間タブを切り替えても一覧が0件になることはなく、かつ
  /// 「デイリー」を選べば直近に投稿された作品ほど上位に来やすくなる。
  List<CommunityWork> _rankingWorks(List<CommunityWork> allWorks) {
    final filtered = _applySearch(allWorks.toList());
    final window = _periodWindow(_period);
    final now = DateTime.now();
    double scoreOf(CommunityWork w) {
      final metric = _sort == _RankingSort.views ? w.viewCount : w.bookmarkCount;
      if (window == null) return metric.toDouble();
      final age = now.difference(w.postedAt);
      final windowSeconds = window.inSeconds.toDouble();
      final ageSeconds = age.inSeconds.toDouble().clamp(windowSeconds, double.infinity);
      final weight = windowSeconds / ageSeconds; // 範囲内なら1.0、古いほど0へ漸近
      return metric * weight;
    }

    final direction = _sortAscending ? 1 : -1;
    filtered.sort((a, b) => direction * scoreOf(a).compareTo(scoreOf(b)));
    return filtered.take(50).toList();
  }

  /// 作品カードタップ：フローティング動画プレビューウィンドウを開く
  /// （このウィンドウは画面遷移をまたいで表示され続ける。詳細は
  /// `CommunityFloatingPreview`のドキュメントコメントを参照）。
  void _openFloatingPreview(CommunityWork work) {
    context.read<CommunityPreviewService>().show(work);
  }

  void _openAuthorWorks(CommunityWork work) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
        ),
      ),
    );
  }

  /// ショートモードを開く：現在アクティブなタブ（新着/ランキング/お気に入り
  /// 作者）の一覧をisShortで絞り込み、全画面縦スクロールビューアへ
  /// 切り替える。ショート動画が1件も無い場合は、区別できないなら横動画も
  /// 交えてスクロールできて良いという依頼どおり、まず絞り込まずそのまま
  /// 全件を渡す（=横動画も混在してよい）。
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
      MaterialPageRoute(
        builder: (_) => CommunityShortsScreen(
          works: target,
          bookmarkedIds: communityService.bookmarkedIds,
          onToggleBookmark: (w) => communityService.toggleBookmark(w.id),
        ),
      ),
    );
  }

  /// 「投稿する」ボタンが押されたときの分岐。まだ一度も投稿したことが
  /// ない人（`worksByAuthor(kDummySelfAuthorId)`が空）に対しては、
  /// いきなりYouTubeの画面へ遷移させると驚かせてしまう（NIARIMが動画を
  /// どこかへアップロードしているように見えてしまう）ため、tips風の
  /// 説明カード（[_showPostInfoDialog]）を毎回必ず案内する。「初回タップ
  /// かどうか」ではなく「投稿実績があるかどうか」で判定するため、未投稿の
  /// 間は何度タップしても表示され続ける。既に一度でも投稿したことがある
  /// 人には、その説明はもう不要なため、単純な準備中案内のみを表示する。
  void _handlePostTap() {
    final hasPosted = context
        .read<CommunityService>()
        .worksByAuthor(kDummySelfAuthorId, includeHidden: true)
        .isNotEmpty;
    if (hasPosted) {
      _showPostComingSoonDialog();
    } else {
      _showPostInfoDialog();
    }
  }

  void _showPostInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline, size: 32),
        title: Text(l10n.communityPostInfoTitle),
        content: Text(l10n.communityPostInfoBody),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonOk)),
        ],
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
            // フォロー通知（Task#134継続）。バッジは未読数、タップで
            // 一覧画面（開いた時点で既読になる）を開く。
            IconButton(
              icon: Badge(
                label: Text('${communityService.unreadFollowNotificationCount}'),
                isLabelVisible: communityService.unreadFollowNotificationCount > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: l10n.communityFollowNotificationsTooltip,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const CommunityFollowNotificationsScreen(),
              )),
            ),
            VideoTypeFilterButton(
              value: _videoTypeFilter,
              onChanged: (v) => setState(() => _videoTypeFilter = v),
            ),
            // 縦画面モード（全画面縦スクロールビューア）は、「縦画面のみ」
            // 絞り込み中でなければ横動画も混在してしまい導線として紛らわしい
            // ため、「縦画面のみ」選択時にのみ表示する。
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
            Tab(text: l10n.communityTabFavoriteAuthors),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handlePostTap,
        icon: const Icon(Icons.video_call_outlined),
        label: Text(l10n.communityPostButton),
        // テーマ側のFAB共通形状（CircleBorder、丸型FAB用）を上書きする。
        // 円形のままだとアイコン+ラベルの横幅を確保できず、ラベル文字が
        // 円の外へはみ出す／切れてしまうため、拡張FAB本来の横長カプセル
        // 形状（StadiumBorder）へ戻す。
        shape: const StadiumBorder(),
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
                        const Spacer(),
                        // ワンタップで昇順/降順を切り替える矢印ボタン
                        // （ホーム画面の並び替え矢印＝SortModeControlと
                        // 同じ操作感に揃えている）。
                        IconButton(
                          icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                          tooltip: _sortAscending
                              ? l10n.communityRankingSortAscendingTooltip
                              : l10n.communityRankingSortDescendingTooltip,
                          onPressed: () => setState(() => _sortAscending = !_sortAscending),
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
            Builder(builder: (context) {
              // お気に入り作者（フォロー、Task#144）の新着一覧。
              // favoriteAuthorFeedは既にNIARIM側非公開作品を除外し新着順
              // （フォロー中の作者本人の投稿日時、またはフォロー中の作者に
              // よるリポストがより新しい場合はその日時）に並んでいるため、
              // 検索絞り込みのみ追加で適用する（Task#145：リポスト機能）。
              final feed = communityService.favoriteAuthorFeed;
              final works = _applySearch(feed.map((e) => e.work).toList());
              final repostedByNames = {
                for (final e in feed)
                  if (e.repostedByAuthorName != null) e.work.id: e.repostedByAuthorName!,
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
                  onToggleBookmark: (w) => communityService.toggleBookmark(w.id),
                  onTapAuthor: _openAuthorWorks,
                  repostedByNames: repostedByNames,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 「お気に入り作者」タブ：1人もフォローしていない場合の案内表示
  /// （ホーム画面の「ブクマ済み」タブが1件もブックマークが無い場合の
  /// 案内表示と同じ構成に揃えている）。
  Widget _buildNoFavoriteAuthorsState(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1, size: 64, color: scheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              l10n.communityFavoriteAuthorsEmptyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon'),
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
