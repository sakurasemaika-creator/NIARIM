import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../router.dart';
import 'community_work_card.dart' show communityThumbnailGradient;

/// 縦画面モードで1本の動画が最後まで再生されたときの挙動。
///
/// [loopCurrent] は同じ作品を先頭から再生、[autoAdvance] は次の作品へ
/// 自動スクロールする。ユーザーの選択はSharedPreferencesへ保存し、次回
/// 縦画面モードを開いたときにも引き継ぐ。
enum CommunityShortsEndBehavior { loopCurrent, autoAdvance }

/// 「縦画面モード」：新着・ランキング・お気に入り作者一覧から切り替えられる
/// 全画面縦スクロール連続再生ビューア（Task#159）。
///
/// 【横動画/縦動画の区別について】YouTube Data APIには「これはShortsで
/// ある」という直接のフラグが無いが、NIARIM側は投稿元プロジェクトの
/// キャンバスサイズ（縦長かどうか）を投稿時点で把握できるため、確実に
/// 判定できる（詳細はCommunityWork.isShortのドキュメントコメント参照）。
/// このビューアには呼び出し元で事前にisShortのみへ絞り込んだ一覧を渡す。
///
/// 現在は実際のYouTube埋め込みプレーヤーが未接続のため、動画領域には既存の
/// プレースホルダーを表示する。ただし本物のプレーヤーへ差し替える際に
/// そのまま使えるよう、次の再生状態管理を先に実装している。
/// - [_currentIndex] のページだけを自動再生対象にする。
/// - プレーヤーの再生終了イベントから[_handlePlaybackEnded]を呼ぶ。
/// - 「同じ動画をループ」ならプレーヤー側を0秒へ戻して再生する。
/// - 「次の動画へ」ならPageViewを次ページへ自動スクロールする。
///
/// ★**本物のYouTube埋め込みプレーヤーを入れる前に、必ず
/// `docs/AI設計書/28_継続タスク（未着手一覧）.md`の該当項目を読むこと。**
/// YouTube API利用ポリシー上、独自UIをプレーヤーの前面に重ねない必要が
/// ある。そのため本実装では、作品名・投稿者・タグ・制作情報・各種操作を
/// 動画領域の**外側**に配置し、将来の実プレーヤー接続時にも構造を崩さず
/// 済むレイアウトにしている。また同時自動再生は常に1本だけとする。
class CommunityShortsScreen extends StatefulWidget {
  final List<CommunityWork> works;
  final int initialIndex;
  final Set<String> bookmarkedIds;
  final void Function(CommunityWork work) onToggleBookmark;

  const CommunityShortsScreen({
    super.key,
    required this.works,
    this.initialIndex = 0,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
  });

  @override
  State<CommunityShortsScreen> createState() => _CommunityShortsScreenState();
}

class _CommunityShortsScreenState extends State<CommunityShortsScreen> {
  static const _endBehaviorPreferenceKey =
      'community_vertical_video_end_behavior';

  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;
  CommunityShortsEndBehavior _endBehavior =
      CommunityShortsEndBehavior.loopCurrent;

  @override
  void initState() {
    super.initState();
    _loadEndBehavior();
  }

  Future<void> _loadEndBehavior() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_endBehaviorPreferenceKey);
    if (!mounted || saved == null) return;
    final restored = CommunityShortsEndBehavior.values.where(
      (value) => value.name == saved,
    );
    if (restored.isEmpty) return;
    setState(() => _endBehavior = restored.first);
  }

  Future<void> _setEndBehavior(CommunityShortsEndBehavior value) async {
    if (_endBehavior == value) return;
    setState(() => _endBehavior = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endBehaviorPreferenceKey, value.name);
  }

  /// 実プレーヤー接続時に、現在ページの動画が最後まで再生された瞬間に呼ぶ。
  ///
  /// 現時点のプレースホルダーには動画の時間軸が存在しないため、このメソッド
  /// 自体を擬似タイマーで呼ぶことはしない。そうすると「再生していないのに
  /// 勝手にページだけ動く」不自然なUIになるためである。
  ///
  /// [loopCurrent]の場合のseekTo(Duration.zero) + play()はプレーヤー固有API
  /// なので、実プレーヤーWidget側で[onLoopCurrent]を受けて実行する。
  void _handlePlaybackEnded(int pageIndex, {VoidCallback? onLoopCurrent}) {
    if (!mounted || pageIndex != _currentIndex || widget.works.isEmpty) return;

    if (_endBehavior == CommunityShortsEndBehavior.loopCurrent) {
      onLoopCurrent?.call();
      return;
    }

    final nextIndex = pageIndex + 1;
    if (nextIndex < widget.works.length) {
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // 実運用ではここで次ページをAPIから追加取得する。ダミーデータは有限なので
    // 最終作品では先頭へ戻し、縦画面フィード自体が停止しないようにする。
    if (widget.works.length > 1) {
      _controller.animateToPage(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      onLoopCurrent?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: widget.works.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final work = widget.works[index];
              return _ShortsPage(
                work: work,
                isCurrentPage: index == _currentIndex,
                isBookmarked: widget.bookmarkedIds.contains(work.id),
                onToggleBookmark: () => widget.onToggleBookmark(work),
                // 実プレーヤー接続時は、そのプレーヤーのonEndedからこの
                // callbackを呼ぶ。loop時のseek/play callbackも同時に渡す。
                onPlaybackEnded: (onLoopCurrent) => _handlePlaybackEnded(
                  index,
                  onLoopCurrent: onLoopCurrent,
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: _TopControlButton(
              tooltip: l10n.communityShortsModeExitTooltip,
              icon: Icons.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: PopupMenuButton<CommunityShortsEndBehavior>(
              tooltip: _settingsTooltip(context),
              initialValue: _endBehavior,
              onSelected: _setEndBehavior,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: CommunityShortsEndBehavior.loopCurrent,
                  child: _EndBehaviorMenuItem(
                    selected:
                        _endBehavior == CommunityShortsEndBehavior.loopCurrent,
                    icon: Icons.repeat_one_rounded,
                    label: _endBehaviorLabel(
                      context,
                      CommunityShortsEndBehavior.loopCurrent,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: CommunityShortsEndBehavior.autoAdvance,
                  child: _EndBehaviorMenuItem(
                    selected:
                        _endBehavior == CommunityShortsEndBehavior.autoAdvance,
                    icon: Icons.vertical_align_bottom_rounded,
                    label: _endBehaviorLabel(
                      context,
                      CommunityShortsEndBehavior.autoAdvance,
                    ),
                  ),
                ),
              ],
              child: Material(
                color: scheme.surface.withValues(alpha: 0.88),
                shape: const CircleBorder(),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _endBehavior == CommunityShortsEndBehavior.loopCurrent
                        ? Icons.repeat_one_rounded
                        : Icons.vertical_align_bottom_rounded,
                    color: scheme.onSurface,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortsPage extends StatelessWidget {
  final CommunityWork work;
  final bool isCurrentPage;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  /// 実プレーヤーの再生終了時に呼ぶためのフック。
  /// 引数は「同じ動画を先頭から再生する処理」。現在はプレースホルダーなので
  /// 呼び出し元だけを用意し、実プレーヤー接続時に利用する。
  final void Function(VoidCallback? onLoopCurrent) onPlaybackEnded;

  const _ShortsPage({
    required this.work,
    required this.isCurrentPage,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onPlaybackEnded,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '$minutes:${remain.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final gradient = communityThumbnailGradient(
      scheme,
      work.thumbnailColorIndex,
    );
    final languageCode = Localizations.localeOf(context).languageCode;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          // 動画領域。将来のYouTubeプレーヤーはこの領域だけを置き換える。
          // 作品情報・タグ・操作は下のパネルへ分離しているため、プレーヤーの
          // 前面へ独自UIを重ねない構造を保てる。
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: ThemeService.activeColorScheme.onSurface.withValues(
                        alpha: 0.70,
                      ),
                      size: 76,
                    ),
                    const SizedBox(height: 10),
                    // 「現在ページだけを自動再生対象にする」状態をUIモックでも
                    // 明示できるよう、非アクティブページでは小さな一時停止
                    // アイコンに切り替える。実プレーヤー接続時はこの表示を削除。
                    Icon(
                      isCurrentPage
                          ? Icons.volume_off_rounded
                          : Icons.pause_rounded,
                      color: ThemeService.activeColorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: scheme.surface,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          work.authorName.substring(0, 1),
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              work.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              work.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onToggleBookmark,
                        tooltip: isBookmarked
                            ? l10n.communityWorkDetailBookmarkRemove
                            : l10n.communityWorkDetailBookmarkAdd,
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? scheme.primary : null,
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            appRouter.push('/community/work/${work.id}'),
                        child: Text(
                          l10n.communityFloatingPreviewDetailButton,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (work.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tag in work.tags)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                avatar: work.lockedTags.contains(tag)
                                    ? const Icon(Icons.lock_outline, size: 13)
                                    : null,
                                label: Text('#$tag'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    appRouter.push('/community', extra: tag),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  // NIARIM固有の制作・作品情報。単なるShortsクローンにせず、
                  // 「この作品がNIARIMでどう作られたか」へ繋げる情報帯として
                  // 将来はキャンバスサイズ/FPS/使用ブラシ等もここへ追加する。
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoItem(
                        icon: Icons.schedule_rounded,
                        text: _formatDuration(work.durationSeconds),
                      ),
                      _InfoItem(
                        icon: Icons.calendar_today_outlined,
                        text: _formatDate(work.postedAt),
                      ),
                      _InfoItem(
                        icon: Icons.play_arrow_rounded,
                        text: formatCompactCount(work.viewCount, languageCode),
                      ),
                      _InfoItem(
                        icon: Icons.bookmark_outline,
                        text: formatCompactCount(
                          work.bookmarkCount,
                          languageCode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _TopControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      elevation: 1,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: scheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _EndBehaviorMenuItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;

  const _EndBehaviorMenuItem({
    required this.selected,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: selected ? scheme.primary : null),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        if (selected) Icon(Icons.check, size: 18, color: scheme.primary),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

String _settingsTooltip(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ja' => '再生終了時の動作',
    'es' => 'Acción al terminar el vídeo',
    'fr' => 'Action à la fin de la vidéo',
    'ko' => '재생 종료 동작',
    'zh' => '播放结束时的操作',
    _ => 'When video ends',
  };
}

String _endBehaviorLabel(
  BuildContext context,
  CommunityShortsEndBehavior behavior,
) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return switch ((languageCode, behavior)) {
    ('ja', CommunityShortsEndBehavior.loopCurrent) => '同じ動画をループ再生',
    ('ja', CommunityShortsEndBehavior.autoAdvance) => '次の動画へ自動スクロール',
    ('es', CommunityShortsEndBehavior.loopCurrent) => 'Repetir el mismo vídeo',
    ('es', CommunityShortsEndBehavior.autoAdvance) =>
      'Ir automáticamente al siguiente vídeo',
    ('fr', CommunityShortsEndBehavior.loopCurrent) => 'Répéter la même vidéo',
    ('fr', CommunityShortsEndBehavior.autoAdvance) =>
      'Passer automatiquement à la vidéo suivante',
    ('ko', CommunityShortsEndBehavior.loopCurrent) => '같은 동영상 반복 재생',
    ('ko', CommunityShortsEndBehavior.autoAdvance) => '다음 동영상으로 자동 이동',
    ('zh', CommunityShortsEndBehavior.loopCurrent) => '循环播放当前视频',
    ('zh', CommunityShortsEndBehavior.autoAdvance) => '自动滚动到下一个视频',
    (_, CommunityShortsEndBehavior.loopCurrent) => 'Loop this video',
    (_, CommunityShortsEndBehavior.autoAdvance) =>
      'Auto-scroll to next video',
  };
}
