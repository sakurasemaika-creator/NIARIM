import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../router.dart';
import '../../services/community_service.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'widgets/community_work_card.dart';
import '../../config/font_fallback.dart';

/// 作品詳細画面（別ルート、`/community/work/:id`）。
/// 横画面フローティングプレビューの「詳細へ」と縦画面の詳細情報アイコンは
/// どちらもこの同一画面へ遷移する。YouTube統計に加えて、投稿元NIARIM
/// プロジェクトのFPS・フレーム数・制作時間・制作日時・キャンバスサイズも
/// 同じ画面で確認できる。
class CommunityWorkDetailScreen extends StatefulWidget {
  final String workId;
  const CommunityWorkDetailScreen({super.key, required this.workId});

  @override
  State<CommunityWorkDetailScreen> createState() =>
      _CommunityWorkDetailScreenState();
}

class _CommunityWorkDetailScreenState extends State<CommunityWorkDetailScreen> {
  static const double _minPreviewHeight = 140;
  static const double _defaultPreviewHeight = 220;
  double _previewHeight = _defaultPreviewHeight;

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

  void _showComingSoonSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddTagDialog(CommunityService communityService, String workId) {
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
            decoration: InputDecoration(
              hintText: l10n.communityAddTagDialogHint,
            ),
            onSubmitted: (v) {
              Navigator.pop(ctx);
              communityService.addTag(workId, v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                communityService.addTag(workId, controller.text);
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
    final detailController = TextEditingController();
    bool showDetailError = false;
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: detailController,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.communityReportDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.communityReportDialogBody),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (v) => setDialogState(() => selected = v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final reason in reasons)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(reason),
                            value: reason,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: l10n.communityReportDetailLabel,
                      hintText: l10n.communityReportDetailHint,
                      errorText: showDetailError
                          ? l10n.communityReportDetailRequiredError
                          : null,
                    ),
                    onChanged: (_) {
                      if (showDetailError) {
                        setDialogState(() => showDetailError = false);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  if (detailController.text.trim().isEmpty) {
                    setDialogState(() => showDetailError = true);
                    return;
                  }
                  Navigator.pop(ctx);
                  _showComingSoonSnackbar(
                    l10n.communityReportComingSoonSnackbar,
                  );
                  _showBlockConfirmDialog(work);
                },
                child: Text(l10n.communityReportSubmitButton),
              ),
            ],
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeService.activeColorScheme.error,
            ),
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

  String _formatDate(DateTime d) {
    final mo = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mo/$dd';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final communityService = context.watch<CommunityService>();
    final work = communityService.byId(widget.workId);
    if (work == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.communityWorkDetailTitle)),
        body: Center(child: Text(l10n.communityWorkNotFoundMessage)),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final isBookmarked = communityService.isBookmarked(work.id);
    final isAuthorSelf = work.authorId == kDummySelfAuthorId;
    final isReposted = communityService.isRepostedBySelf(work.id);
    final maxPreviewHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(
      _minPreviewHeight,
      500.0,
    );
    final previewHeight = _previewHeight.clamp(
      _minPreviewHeight,
      maxPreviewHeight,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityWorkDetailTitle)),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: previewHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: communityThumbnailGradient(
                          Theme.of(context).colorScheme,
                          work.thumbnailColorIndex,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: ThemeService.activeColorScheme.onSurface
                            .withValues(alpha: 0.70),
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onVerticalDragUpdate: (d) => setState(() {
                  _previewHeight = (previewHeight + d.delta.dy).clamp(
                    _minPreviewHeight,
                    maxPreviewHeight,
                  );
                }),
                child: Container(
                  height: 20,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Text(
                work.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAuthorWorks(work),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              work.authorName.substring(0, 1),
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              work.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isAuthorSelf)
                    IconButton(
                      onPressed: () =>
                          communityService.toggleFavoriteAuthor(work.authorId),
                      icon: Icon(
                        communityService.isFavoriteAuthor(work.authorId)
                            ? Icons.person_remove_alt_1
                            : Icons.person_add_alt_1,
                        color: communityService.isFavoriteAuthor(work.authorId)
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                      tooltip: communityService.isFavoriteAuthor(work.authorId)
                          ? l10n.communityFavoriteAuthorFollowing
                          : l10n.communityFavoriteAuthorFollow,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(work.viewCount, languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(work.likeCount, languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.bookmark,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(work.bookmarkCount, languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.repeat, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    formatCompactCount(
                      communityService.repostCountOf(work.id),
                      languageCode,
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.communityWorkDetailPostedLabel(_formatDate(work.postedAt)),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if (_hasProjectMetadata(work)) ...[
                const SizedBox(height: 12),
                _ProjectMetadataCard(work: work),
              ],
              if (isAuthorSelf) ...[
                const SizedBox(height: 12),
                _NiarimVisibilitySwitch(
                  isPublished: work.isNiarimPublished,
                  onChanged: () =>
                      communityService.toggleNiarimVisibility(work.id),
                ),
              ] else if (!work.isNiarimPublished) ...[
                const SizedBox(height: 12),
                _NiarimHiddenNotice(),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in work.tags)
                    _TagChip(
                      label: tag,
                      isLocked: work.lockedTags.contains(tag),
                      onToggleLock: isAuthorSelf
                          ? () => communityService.toggleTagLock(work.id, tag)
                          : null,
                      onRemove: work.lockedTags.contains(tag)
                          ? null
                          : () => communityService.removeTag(work.id, tag),
                      onTap: () => appRouter.push('/community', extra: tag),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(l10n.communityAddTagButton),
                    onPressed: () =>
                        _showAddTagDialog(communityService, work.id),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showComingSoonSnackbar(
                        l10n.communityWorkDetailViewOnYoutubeComingSoonSnackbar,
                      ),
                      icon: const Icon(Icons.smart_display_outlined),
                      label: Text(l10n.communityWorkDetailViewOnYoutube),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => communityService.toggleBookmark(work.id),
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: Text(
                      isBookmarked
                          ? l10n.communityWorkDetailBookmarkRemove
                          : l10n.communityWorkDetailBookmarkAdd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => communityService.toggleRepost(work.id),
                  icon: Icon(
                    Icons.repeat,
                    color: isReposted ? scheme.primary : null,
                  ),
                  label: Text(
                    isReposted
                        ? l10n.communityRepostedButton
                        : l10n.communityRepostButton,
                    style: TextStyle(color: isReposted ? scheme.primary : null),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: isReposted ? BorderSide(color: scheme.primary) : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showReportDialog(work),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(l10n.communityWorkDetailReportButton),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showBlockConfirmDialog(work),
                      icon: const Icon(Icons.block, size: 18),
                      label: Text(l10n.communityWorkDetailBlockButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasProjectMetadata(CommunityWork work) =>
    work.projectFps > 0 ||
    work.projectFrameCount > 0 ||
    work.projectWorkSeconds > 0 ||
    work.projectCreatedAt != null ||
    (work.projectCanvasWidth > 0 && work.projectCanvasHeight > 0);

class _ProjectMetadataCard extends StatelessWidget {
  final CommunityWork work;

  const _ProjectMetadataCard({required this.work});

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final workTime = formatProjectWorkTime(work.projectWorkSeconds);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.animation_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'NIARIM',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                if (work.projectFrameCount > 0)
                  _ProjectMetaItem(
                    icon: Icons.movie_outlined,
                    text: '${work.projectFrameCount}f',
                  ),
                if (work.projectFps > 0)
                  _ProjectMetaItem(
                    icon: Icons.speed_rounded,
                    text: '${work.projectFps}fps',
                  ),
                if (work.projectCanvasWidth > 0 &&
                    work.projectCanvasHeight > 0)
                  _ProjectMetaItem(
                    icon: Icons.aspect_ratio_rounded,
                    text:
                        '${work.projectCanvasWidth}×${work.projectCanvasHeight}',
                  ),
                if (workTime.isNotEmpty)
                  _ProjectMetaItem(
                    icon: Icons.timer_outlined,
                    text: workTime,
                  ),
                if (work.projectCreatedAt != null)
                  _ProjectMetaItem(
                    icon: Icons.edit_calendar_outlined,
                    text: _formatDate(work.projectCreatedAt!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProjectMetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

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
              Text(
                label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
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

class _NiarimVisibilitySwitch extends StatelessWidget {
  final bool isPublished;
  final VoidCallback onChanged;

  const _NiarimVisibilitySwitch({
    required this.isPublished,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPublished ? Icons.public : Icons.lock_outline,
                color: isPublished ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.communityVisibilityCardTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPublished
                          ? l10n.communityVisibilityPublishedDesc
                          : l10n.communityVisibilityHiddenDesc,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: isPublished, onChanged: (_) => onChanged()),
            ],
          ),
        ),
      ),
    );
  }
}

class _NiarimHiddenNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.communityVisibilityHiddenNotice,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
