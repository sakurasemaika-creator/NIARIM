import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'widgets/community_work_card.dart';

enum _RankingPeriod { allTime, yearly, monthly, weekly, daily }

enum _RankingSort { views, bookmarks }

/// みんなの作品を見る画面。
///
/// `29_動画投稿・ランキング機能仕様.md`のバックエンド（YouTube投稿・
/// DynamoDB・ランキング集計）は未実装のため、この画面は表示確認用の
/// ダミーデータのみで動作するUI・デザインの作り込みに限定している。
/// 実際の動画埋め込み・投稿・通報送信・ブロック反映は行わず、該当操作を
/// タップすると「準備中」である旨を案内する。ブックマーク・タグの追加／
/// 削除／投稿者ロックの切り替えのみ、画面内の一時的な状態として見た目上
/// 反映する（アプリ再起動やこの画面を離れると元に戻る）。タグは誰でも
/// 追加・削除できるが、投稿者がロックしたタグは他ユーザーが削除できない
/// （`CommunityWork.kDummySelfAuthorId`を参照）。
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<CommunityWork> _allWorks;
  final Set<String> _bookmarkedIds = {};
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
    _allWorks = buildDummyCommunityWorks();
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

  /// タグチップのタップから呼ばれる。検索をそのタグのタグ検索モードへ
  /// 切り替えて絞り込む。
  void _filterByTag(String tag) {
    setState(() {
      _isSearching = true;
      _tagSearchMode = true;
      _searchQuery = tag;
      _searchController.text = tag;
    });
  }

  int _indexOfWork(String workId) => _allWorks.indexWhere((w) => w.id == workId);

  /// タグを追加する（誰でも可能）。同名タグが既にある場合は何もしない。
  void _addTag(CommunityWork work, String tag, void Function(void Function()) setSheetState) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final index = _indexOfWork(work.id);
    if (index == -1) return;
    final current = _allWorks[index];
    if (current.tags.contains(trimmed)) return;
    final updated = current.copyWith(tags: [...current.tags, trimmed]);
    setState(() => _allWorks[index] = updated);
    setSheetState(() {});
  }

  /// タグを削除する。ロックされているタグは削除できない
  /// （呼び出し元でロック中のタグに対しては削除ボタン自体を表示しない）。
  void _removeTag(CommunityWork work, String tag, void Function(void Function()) setSheetState) {
    final index = _indexOfWork(work.id);
    if (index == -1) return;
    final current = _allWorks[index];
    if (current.lockedTags.contains(tag)) return;
    final updated = current.copyWith(
      tags: current.tags.where((t) => t != tag).toList(),
      lockedTags: current.lockedTags.where((t) => t != tag).toSet(),
    );
    setState(() => _allWorks[index] = updated);
    setSheetState(() {});
  }

  /// タグのロック状態を切り替える（投稿者本人のみ呼び出し可能。
  /// UI側で`work.authorId == kDummySelfAuthorId`のときのみボタンを表示する）。
  void _toggleTagLock(CommunityWork work, String tag, void Function(void Function()) setSheetState) {
    final index = _indexOfWork(work.id);
    if (index == -1) return;
    final current = _allWorks[index];
    final lockedTags = {...current.lockedTags};
    if (lockedTags.contains(tag)) {
      lockedTags.remove(tag);
    } else {
      lockedTags.add(tag);
    }
    final updated = current.copyWith(lockedTags: lockedTags);
    setState(() => _allWorks[index] = updated);
    setSheetState(() {});
  }

  List<CommunityWork> get _newArrivals => _applySearch(
      [..._allWorks]..sort((a, b) => b.postedAt.compareTo(a.postedAt)));

  /// 期間フィルターに応じたダミーの対象作品を絞り込む。実データでは
  /// バックエンド側で期間別の再生数を集計するが、ここでは投稿日時のみで
  /// 簡易的に絞り込む（表示確認用）。
  List<CommunityWork> get _rankingWorks {
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
        ? _allWorks
        : _allWorks.where((w) => now.difference(w.postedAt) <= window!);
    final filtered = _applySearch(windowed.toList());
    filtered.sort((a, b) => _sort == _RankingSort.views
        ? b.viewCount.compareTo(a.viewCount)
        : b.bookmarkCount.compareTo(a.bookmarkCount));
    return filtered.take(50).toList();
  }

  void _toggleBookmark(CommunityWork work) {
    setState(() {
      if (_bookmarkedIds.contains(work.id)) {
        _bookmarkedIds.remove(work.id);
      } else {
        _bookmarkedIds.add(work.id);
      }
    });
  }

  void _openAuthorWorks(CommunityWork work) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
          works: _allWorks.where((w) => w.authorId == work.authorId).toList(),
          bookmarkedIds: _bookmarkedIds,
          onToggleBookmark: _toggleBookmark,
          onOpenWork: _openWorkDetail,
        ),
      ),
    );
  }

  void _showComingSoonSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openWorkDetail(CommunityWork work) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // タグの追加・削除・ロック切り替え後もシート内の表示へ反映
            // できるよう、_allWorksから最新の状態を都度読み直す。
            final currentWork = _allWorks[_indexOfWork(work.id)];
            final isBookmarked = _bookmarkedIds.contains(currentWork.id);
            final isAuthorSelf = currentWork.authorId == kDummySelfAuthorId;
            final scheme = Theme.of(sheetContext).colorScheme;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: kCommunityThumbnailGradients[
                                  work.thumbnailColorIndex % kCommunityThumbnailGradients.length],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 56),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(work.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openAuthorWorks(work);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(work.authorName.substring(0, 1),
                                style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
                          ),
                          const SizedBox(width: 6),
                          Text(work.authorName,
                              style: TextStyle(fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatCompactCount(work.viewCount), style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 14),
                        Icon(Icons.thumb_up_alt_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatCompactCount(work.likeCount), style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 14),
                        Icon(Icons.bookmark, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatCompactCount(work.bookmarkCount), style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.communityWorkDetailPostedLabel(_formatDate(work.postedAt)),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final tag in currentWork.tags)
                          _TagChip(
                            label: tag,
                            isLocked: currentWork.lockedTags.contains(tag),
                            // ロックの鍵アイコン自体は投稿者本人のみ操作可能
                            // （ロック中/解除中の切り替え）。それ以外の
                            // ユーザーには鍵アイコンのみ表示し操作はさせない。
                            onToggleLock: isAuthorSelf
                                ? () => _toggleTagLock(currentWork, tag, setSheetState)
                                : null,
                            // ロックされていないタグのみ誰でも削除できる。
                            onRemove: currentWork.lockedTags.contains(tag)
                                ? null
                                : () => _removeTag(currentWork, tag, setSheetState),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _filterByTag(tag);
                            },
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(l10n.communityAddTagButton),
                          onPressed: () => _showAddTagDialog(currentWork, setSheetState),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _showComingSoonSnackbar(l10n.communityWorkDetailViewOnYoutubeComingSoonSnackbar),
                            icon: const Icon(Icons.smart_display_outlined),
                            label: Text(l10n.communityWorkDetailViewOnYoutube),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setSheetState(() {
                            _toggleBookmark(work);
                          }),
                          icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                          label: Text(isBookmarked
                              ? l10n.communityWorkDetailBookmarkRemove
                              : l10n.communityWorkDetailBookmarkAdd),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showReportDialog(work);
                            },
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(l10n.communityWorkDetailReportButton),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showBlockConfirmDialog(work);
                            },
                            icon: const Icon(Icons.block, size: 18),
                            label: Text(l10n.communityWorkDetailBlockButton),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTagDialog(CommunityWork work, void Function(void Function()) setSheetState) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.communityAddTagDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.communityAddTagDialogHint),
            onSubmitted: (v) {
              Navigator.pop(ctx);
              _addTag(work, v, setSheetState);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addTag(work, controller.text, setSheetState);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(CommunityWork work) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = [
      l10n.communityReportReasonInappropriate,
      l10n.communityReportReasonCopyright,
      l10n.communityReportReasonSpam,
      l10n.communityReportReasonOther,
    ];
    String selected = reasons.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.communityReportDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.communityReportDialogBody),
              const SizedBox(height: 8),
              for (final reason in reasons)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(reason),
                  value: reason,
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v!),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showComingSoonSnackbar(l10n.communityReportComingSoonSnackbar);
              },
              child: Text(l10n.communityReportSubmitButton),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog(CommunityWork work) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.communityBlockConfirmTitle(work.authorName)),
        content: Text(l10n.communityBlockConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _showComingSoonSnackbar(l10n.communityBlockComingSoonSnackbar);
            },
            child: Text(l10n.communityWorkDetailBlockButton),
          ),
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

  String _formatDate(DateTime d) {
    final mo = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mo/$dd';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          ] else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.commonSearch,
              onPressed: () => setState(() => _isSearching = true),
            ),
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
              final works = _newArrivals;
              if (works.isEmpty) return _buildSearchEmptyState(l10n);
              return SingleChildScrollView(
                child: CommunityWorkGrid(
                  works: works,
                  bookmarkedIds: _bookmarkedIds,
                  onTapWork: _openWorkDetail,
                  onToggleBookmark: _toggleBookmark,
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
                    final ranked = _rankingWorks;
                    if (ranked.isEmpty) return _buildSearchEmptyState(l10n);
                    final rankNumbers = {
                      for (int i = 0; i < ranked.length; i++) ranked[i].id: i + 1,
                    };
                    return CommunityWorkGrid(
                      works: ranked,
                      bookmarkedIds: _bookmarkedIds,
                      onTapWork: _openWorkDetail,
                      onToggleBookmark: _toggleBookmark,
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

/// 作品詳細シートで使うタグ表示チップ。タップでそのタグによる絞り込みへ
/// 遷移し、ロックされていないタグには削除ボタン（誰でも操作可）、
/// 投稿者本人が見ている場合のみロック/解除の切り替えボタンを追加で表示する。
class _TagChip extends StatelessWidget {
  final String label;
  final bool isLocked;
  final VoidCallback? onToggleLock;
  final VoidCallback? onRemove;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.isLocked,
    required this.onToggleLock,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLocked) ...[
                Icon(Icons.lock, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (onToggleLock != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  tooltip: isLocked
                      ? l10n.communityTagUnlockTooltip
                      : l10n.communityTagLockTooltip,
                  icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                  onPressed: onToggleLock,
                ),
              if (onRemove != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  tooltip: l10n.communityRemoveTagTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
