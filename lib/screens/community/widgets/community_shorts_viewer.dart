import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../router.dart';
import '../../../services/community_service.dart';
import 'community_work_card.dart' show communityThumbnailGradient;

enum CommunityShortsEndBehavior { loopCurrent, autoAdvance }

/// 「縦画面モード」。YouTubeプレーヤー領域の上にはNIARIM独自UIを重ねず、
/// 作者・タグ・制作情報・操作はすべて動画外の下部パネルへ分離する。
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
    final communityService = context.watch<CommunityService>();
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
                isBookmarked: communityService.isBookmarked(work.id),
                onToggleBookmark: () =>
                    communityService.toggleBookmark(work.id),
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
    final workTime = formatProjectWorkTime(work.projectWorkSeconds);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          // 将来のYouTubeプレーヤーはこの矩形だけを置き換える。
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
          // 作者・タグ・制作情報・詳細導線はすべて動画領域の外。
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
                      IconButton.filledTonal(
                        onPressed: () =>
                            appRouter.push('/community/work/${work.id}'),
                        tooltip: l10n.communityFloatingPreviewDetailButton,
                        icon: const Icon(Icons.info_outline_rounded),
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
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoItem(
                        icon: Icons.schedule_rounded,
                        text: _formatDuration(work.durationSeconds),
                      ),
                      if (work.projectFrameCount > 0)
                        _InfoItem(
                          icon: Icons.movie_outlined,
                          text: '${work.projectFrameCount}f',
                        ),
                      if (work.projectFps > 0)
                        _InfoItem(
                          icon: Icons.speed_rounded,
                          text: '${work.projectFps}fps',
                        ),
                      if (work.projectCanvasWidth > 0 &&
                          work.projectCanvasHeight > 0)
                        _InfoItem(
                          icon: Icons.aspect_ratio_rounded,
                          text:
                              '${work.projectCanvasWidth}×${work.projectCanvasHeight}',
                        ),
                      if (workTime.isNotEmpty)
                        _InfoItem(
                          icon: Icons.timer_outlined,
                          text: workTime,
                        ),
                      if (work.projectCreatedAt != null)
                        _InfoItem(
                          icon: Icons.edit_calendar_outlined,
                          text: _formatDate(work.projectCreatedAt!),
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
