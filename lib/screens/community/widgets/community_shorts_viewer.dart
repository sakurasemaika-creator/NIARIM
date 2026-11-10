import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/community_work.dart';
import '../../../router.dart';
import '../../../services/community_service.dart';
import '../../../widgets/ad_banner_mock_widget.dart';
import '../community_author_works_screen.dart';
import 'community_playback_status_view.dart';
import 'community_youtube_player.dart';
import '../../../services/api/community_api.dart';
import '../community_edit_feedback.dart';
import '../../../utils/tolerant_preferences.dart';
import '../../../config/accent_text_theme.dart';

enum CommunityShortsEndBehavior { loopCurrent, autoAdvance }

/// 「縦画面モード」。YouTubeプレーヤー領域の上にはNIARIM独自UIを重ねず、
/// 作者・タグ・制作情報・操作はすべて動画外の下部パネルへ分離する。
class CommunityShortsScreen extends StatefulWidget {
  final List<CommunityWork> works;
  final int initialIndex;

  /// 呼び出し側との互換性のため残す初期スナップショット。
  /// 表示中のブックマーク状態はCommunityServiceをwatchして取得する。
  final Set<String> bookmarkedIds;

  /// 呼び出し側との互換性のため残す。現在の縦画面内操作は
  /// CommunityService.toggleBookmark()を直接呼ぶ。
  final void Function(CommunityWork work) onToggleBookmark;

  /// Opened by the poster from their own author page: their own works stay
  /// even when hidden or filtered out, as on that page.
  final bool ownerView;

  const CommunityShortsScreen({
    super.key,
    required this.works,
    this.initialIndex = 0,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    this.ownerView = false,
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
    final saved = prefs.readString(_endBehaviorPreferenceKey);
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

  /// Called by the real IFrame player when the active video ends.
  void _handlePlaybackEnded(
    int pageIndex,
    List<CommunityWork> visibleWorks, {
    VoidCallback? onLoopCurrent,
  }) {
    if (!mounted || pageIndex != _currentIndex || visibleWorks.isEmpty) return;

    if (_endBehavior == CommunityShortsEndBehavior.loopCurrent) {
      onLoopCurrent?.call();
      return;
    }

    final nextIndex = pageIndex + 1;
    if (nextIndex < visibleWorks.length) {
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (visibleWorks.length > 1) {
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
    // The works it was opened with, as they are now: a flag, tag or title
    // changed meanwhile, or a filter set meanwhile, applies at once.
    final visibleWorks = [
      for (final opened in widget.works)
        if (communityService.byId(opened.id) ?? opened case final work
            when (widget.ownerView && communityService.isOwnWork(work)) ||
                communityService.isDiscoverableForViewer(work))
          work,
    ];
    if (_currentIndex >= visibleWorks.length && visibleWorks.isNotEmpty) {
      _currentIndex = visibleWorks.length - 1;
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          // YouTube IFrame controls must never be covered by NIARIM's own
          // buttons. Keep exit / end behavior in a dedicated header.
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 8,
                    child: _TopControlButton(
                      tooltip: l10n.communityShortsModeExitTooltip,
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 8,
                    child: PopupMenuButton<CommunityShortsEndBehavior>(
                      tooltip: l10n.communityShortsEndBehaviorTooltip,
                      initialValue: _endBehavior,
                      onSelected: _setEndBehavior,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: CommunityShortsEndBehavior.loopCurrent,
                          child: _EndBehaviorMenuItem(
                            selected:
                                _endBehavior == CommunityShortsEndBehavior.loopCurrent,
                            icon: Icons.repeat_one_rounded,
                            label: l10n.communityShortsEndBehaviorLoop,
                          ),
                        ),
                        PopupMenuItem(
                          value: CommunityShortsEndBehavior.autoAdvance,
                          child: _EndBehaviorMenuItem(
                            selected:
                                _endBehavior == CommunityShortsEndBehavior.autoAdvance,
                            icon: Icons.vertical_align_bottom_rounded,
                            label: l10n.communityShortsEndBehaviorAutoAdvance,
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
            ),
          ),
          Expanded(
            child: PageView.builder(
                    controller: _controller,
                    scrollDirection: Axis.vertical,
                    itemCount: visibleWorks.length,
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemBuilder: (context, index) {
                      final work = visibleWorks[index];
                      return _ShortsVerifiedPage(
                        key: ValueKey('shorts-verified-${work.id}'),
                        work: work,
                        isCurrentPage: index == _currentIndex,
                        isBookmarked: communityService.isBookmarked(work.id),
                        onToggleBookmark: () => reportFailedCommunityEdit(
                          context,
                          communityService,
                          communityService.toggleBookmark(work.id),
                        ),
                        onPlaybackEnded: (onLoopCurrent) => _handlePlaybackEnded(
                          index,
                          visibleWorks,
                          onLoopCurrent: onLoopCurrent,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Revalidate each vertical-page activation (including when a queued next
/// video becomes current). No cached title or video is shown before approval.
class _ShortsVerifiedPage extends StatefulWidget {
  const _ShortsVerifiedPage({
    super.key,
    required this.work,
    required this.isCurrentPage,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onPlaybackEnded,
  });

  final CommunityWork work;
  final bool isCurrentPage;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final void Function(VoidCallback? onLoopCurrent) onPlaybackEnded;

  @override
  State<_ShortsVerifiedPage> createState() => _ShortsVerifiedPageState();
}

class _ShortsVerifiedPageState extends State<_ShortsVerifiedPage> {
  CommunityPlaybackStatus _status = CommunityPlaybackStatus.checking;
  int _checkEpoch = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  @override
  void didUpdateWidget(covariant _ShortsVerifiedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.id != widget.work.id ||
        (!oldWidget.isCurrentPage && widget.isCurrentPage)) {
      _status = CommunityPlaybackStatus.checking;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
    if (oldWidget.isCurrentPage && !widget.isCurrentPage) {
      // Invalidate an in-flight reply when the viewer swipes away.
      _checkEpoch++;
      _status = CommunityPlaybackStatus.checking;
    }
  }

  Future<void> _verify() async {
    if (!mounted || !widget.isCurrentPage) {
      return;
    }
    final id = widget.work.id;
    final epoch = ++_checkEpoch;
    setState(() => _status = CommunityPlaybackStatus.checking);
    final status = await context.read<CommunityService>().playbackStatus(id);
    if (!mounted || !widget.isCurrentPage ||
        widget.work.id != id || epoch != _checkEpoch) {
      return;
    }
    setState(() => _status = status);
  }

  /// IFrame control resume and replay are fresh action boundaries.
  Future<bool> _validateNativePlay() async {
    if (!mounted || !widget.isCurrentPage) {
      return false;
    }
    final id = widget.work.id;
    final epoch = ++_checkEpoch;
    final status = await context.read<CommunityService>().playbackStatus(id);
    if (!mounted || !widget.isCurrentPage ||
        widget.work.id != id || epoch != _checkEpoch) {
      return false;
    }
    if (status != CommunityPlaybackStatus.available) {
      setState(() => _status = status);
    }
    return status == CommunityPlaybackStatus.available;
  }

  void _handlePlaybackEnded(VoidCallback? replay) {
    // Before looping or moving to the next video, revalidate this video.
    _validateNativePlay().then((allowed) {
      if (mounted && widget.isCurrentPage && allowed) {
        widget.onPlaybackEnded(replay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrentPage) return const SizedBox.expand();
    if (_status != CommunityPlaybackStatus.available) {
      return SafeArea(
        child: Center(
          child: CommunityPlaybackStatusView(
            status: _status,
            onRetry: _verify,
          ),
        ),
      );
    }
    return _ShortsPage(
      work: widget.work,
      isCurrentPage: widget.isCurrentPage,
      isBookmarked: widget.isBookmarked,
      onToggleBookmark: widget.onToggleBookmark,
      onPlaybackEnded: _handlePlaybackEnded,
      validatePlayback: _validateNativePlay,
    );
  }
}

class _ShortsPage extends StatelessWidget {
  final CommunityWork work;
  final bool isCurrentPage;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final void Function(VoidCallback? onLoopCurrent) onPlaybackEnded;
  final Future<bool> Function() validatePlayback;

  const _ShortsPage({
    required this.work,
    required this.isCurrentPage,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onPlaybackEnded,
    required this.validatePlayback,
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

  void _openAuthorWorks(BuildContext context) {
    Navigator.of(context).push(
      adMockMaterialPageRoute(
        builder: (_) => CommunityAuthorWorksScreen(
          authorId: work.authorId,
          authorName: work.authorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final workTime = formatProjectWorkTime(work.projectWorkSeconds);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          // The whole region is the native YouTube IFrame surface. All NIARIM
          // controls remain outside it and do not cover YouTube controls.
          Expanded(
            child: CommunityYoutubePlayer(
              key: ValueKey('communityShortsYoutube-${work.id}'),
              videoId: work.id,
              playing: isCurrentPage,
              onEnded: (replay) => onPlaybackEnded(replay),
              validatePlayback: validatePlayback,
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
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openAuthorWorks(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        work.authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AccentTextTheme.of(context),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Kuramubon',
                                          fontFamilyFallback:
                                              kHeadingFontFallback,
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
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onToggleBookmark,
                        tooltip: isBookmarked
                            ? l10n.communityWorkDetailBookmarkRemove
                            : l10n.communityWorkDetailBookmarkAdd,
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked
                              ? AccentTextTheme.of(context)
                              : null,
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
                      if (work.durationSeconds > 0)
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
                        _InfoItem(icon: Icons.timer_outlined, text: workTime),
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
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: selected ? AccentTextTheme.of(context) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        if (selected)
          Icon(Icons.check, size: 18, color: AccentTextTheme.of(context)),
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
