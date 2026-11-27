import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/signal_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/api/community_api.dart';
import '../../services/api/niarim_api_exception.dart';
import 'widgets/community_playback_status_view.dart';
import 'widgets/community_youtube_player.dart';
import 'widgets/community_work_description.dart';
import 'widgets/community_youtube_comments_section.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/responsive.dart';
import 'community_author_works_screen.dart';
import 'community_error_text.dart';
import 'community_moderation.dart';
import 'community_edit_feedback.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import 'package:intl/intl.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/button_row_or_stack.dart';
import '../../widgets/first_that_fits.dart';
import '../../widgets/typing_dialog_inset.dart';
import 'widgets/community_work_counts.dart';

/// 作品詳細画面（別ルート、`/community/work/:id`）。
/// 横画面フローティングプレビューの「詳細へ」と縦画面の詳細情報アイコンは
/// どちらもこの同一画面へ遷移する。YouTube統計に加えて、投稿元NIARIM
/// プロジェクトのFPS・フレーム数・制作時間・制作日時・キャンバスサイズも
/// 同じ画面で確認できる。
enum _TagAction { search, edit, delete, toggleLock }

class CommunityWorkDetailScreen extends StatefulWidget {
  final String workId;
  const CommunityWorkDetailScreen({super.key, required this.workId});

  @override
  State<CommunityWorkDetailScreen> createState() =>
      _CommunityWorkDetailScreenState();
}

class _CommunityWorkDetailScreenState extends State<CommunityWorkDetailScreen> {
  static const double _minPreviewHeight = 200;
  static const double _defaultPreviewHeight = 220;
  double _previewHeight = _defaultPreviewHeight;
  bool _aiDisclosureBusy = false;
  CommunityPlaybackStatus _playbackStatus = CommunityPlaybackStatus.checking;
  CommunityWork? _ownerOnlyWork;
  String? _ownerOnlyAccountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPlaybackStatus();
      _loadOwnerOnlyWorkIfNeeded();
    });
  }

  /// Hidden works cannot be returned from the public feed. Fetch the exact
  /// owner-owned item for a notification deep link without leaking private
  /// video metadata to other users.
  Future<void> _loadOwnerOnlyWorkIfNeeded() async {
    if (!mounted) return;
    final community = context.read<CommunityService>();
    final auth = context.read<GoogleAuthService?>();
    final accountId = auth?.account?.id;
    // A public-feed placeholder is not proof that the owner's private work
    // details are available. Only a real cached work can skip owner lookup.
    final cached = community.byId(widget.workId);
    if ((cached != null && !cached.isUnavailable) ||
        accountId == null ||
        community.api == null) {
      return;
    }
    try {
      final response = await community.api!.myWork(widget.workId);
      if (!mounted ||
          context.read<GoogleAuthService?>()?.account?.id != accountId) {
        return;
      }
      setState(() {
        _ownerOnlyAccountId = accountId;
        _ownerOnlyWork = response.toCommunityWork();
      });
    } on Object catch (error) {
      debugPrint('Owner detail fetch unavailable: $error');
    }
  }

  Future<CommunityPlaybackStatus> _checkPlaybackStatus() async {
    if (!mounted) return CommunityPlaybackStatus.unknown;
    setState(() => _playbackStatus = CommunityPlaybackStatus.checking);
    final status = await context.read<CommunityService>().playbackStatus(
      widget.workId,
    );
    if (mounted) setState(() => _playbackStatus = status);
    return status;
  }

  /// The external YouTube button is also an action boundary: never open a
  /// cached work without checking NIARIM and YouTube visibility again.
  Future<void> _openYoutubeIfAvailable(String workId) async {
    // 開けないときも黙らずに知らせる（以前は動画が見られない状態だと、
    // 押しても何も起きなかった）。
    void openFailed() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.communityWorkDetailYoutubeOpenFailed,
          ),
        ),
      );
    }

    if (!CommunityYoutubePlayer.isValidVideoId(workId)) {
      openFailed();
      return;
    }
    final status = await _checkPlaybackStatus();
    if (!mounted || widget.workId != workId) return;
    if (status != CommunityPlaybackStatus.available) {
      openFailed();
      return;
    }
    final url = Uri.https('www.youtube.com', '/watch', {'v': workId});
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        openFailed();
      }
    } catch (_) {
      openFailed();
    }
  }

  /// With a backend an edit can be refused or lost; it is undone, and the
  /// viewer is told.
  Future<void> _reportFailedEdit(
    CommunityService service,
    Future<bool?> edit,
  ) => reportFailedCommunityEdit(context, service, edit);

  Future<void> _applyTagAction(
    CommunityService service,
    String workId,
    CommunityTagAction action,
    String tag, {
    String? replacement,
  }) async {
    final cached = service.byId(workId);
    final accountId = context.read<GoogleAuthService?>()?.account?.id;
    final privateWork = _ownerOnlyWork;
    final client = service.api;
    if ((cached == null || cached.isUnavailable) &&
        privateWork?.id == workId &&
        accountId != null &&
        accountId == _ownerOnlyAccountId &&
        client != null) {
      final revision = service.accountRevision;
      try {
        final work = await client.updateTag(
          workId,
          action: action,
          tag: tag,
          newTag: replacement,
        );
        if (!mounted ||
            revision != service.accountRevision ||
            context.read<GoogleAuthService?>()?.account?.id != accountId) {
          return;
        }
        setState(() {
          _ownerOnlyWork = _ownerOnlyWork?.copyWith(
            tags: work.tags,
            lockedTags: work.lockedTags.toSet(),
          );
        });
      } on NiarimApiException catch (error) {
        if (!mounted ||
            revision != service.accountRevision ||
            context.read<GoogleAuthService?>()?.account?.id != accountId) {
          return;
        }
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.isUnauthorized
                  ? l10n.communityEditSignInRequired
                  : communityApiErrorCodeText(l10n, error.code) ??
                        l10n.communityEditFailed,
            ),
          ),
        );
      }
      return;
    }

    if (cached == null || cached.isUnavailable) return;
    final edit = switch (action) {
      CommunityTagAction.add => service.addTag(workId, tag),
      CommunityTagAction.remove => service.removeTag(workId, tag),
      CommunityTagAction.rename => service.renameTag(workId, tag, replacement!),
      CommunityTagAction.lock || CommunityTagAction.unlock =>
        cached.tags.contains(tag) &&
                service.isOwnWork(cached) &&
                cached.lockedTags.contains(tag) ==
                    (action == CommunityTagAction.unlock)
            ? service.toggleTagLock(workId, tag)
            : Future<bool?>.value(),
    };
    await _reportFailedEdit(service, edit);
  }

  Future<void> _setAiImageVideoDisclosure(
    CommunityService service,
    String workId,
    bool value,
  ) async {
    if (_aiDisclosureBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(
      context,
    )!.communityAiImageVideoUpdateFailed;
    setState(() => _aiDisclosureBusy = true);
    try {
      await service.setAiImageVideoDisclosure(workId, value);
    } on CommunityAccountChangedException {
      return;
    } catch (error) {
      debugPrint('AI image/video disclosure update failed: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _aiDisclosureBusy = false);
    }
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

  void _showAddTagDialog(CommunityService communityService, String workId) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => AlertDialog(
          insetPadding: typingDialogInsetPadding(ctx),
          title: Text(l10n.communityAddTagDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.communityAddTagDialogHint,
            ),
            onSubmitted: (v) {
              Navigator.pop(ctx);
              _applyTagAction(
                communityService,
                workId,
                CommunityTagAction.add,
                v,
              );
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
                _applyTagAction(
                  communityService,
                  workId,
                  CommunityTagAction.add,
                  controller.text,
                );
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagActions(
    CommunityService service,
    CommunityWork work,
    String tag,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final locked = work.lockedTags.contains(tag);
    final ownerAccount = context.read<GoogleAuthService?>()?.account?.id;
    final owner =
        service.isOwnWork(work) ||
        (identical(work, _ownerOnlyWork) &&
            ownerAccount != null &&
            ownerAccount == _ownerOnlyAccountId);
    final accountRevision = service.accountRevision;
    final action = await showDialog<_TagAction>(
      context: context,
      builder: (ctx) {
        final actions = [
          (
            value: null,
            label: locked && !owner ? l10n.commonOk : l10n.commonCancel,
            icon: locked && !owner ? Icons.check : Icons.close,
          ),
          if (owner || !locked)
            (
              value: _TagAction.edit,
              label: l10n.commonEdit,
              icon: Icons.edit_outlined,
            ),
          if (!locked)
            (
              value: _TagAction.delete,
              label: l10n.commonDelete,
              icon: Icons.delete_outline,
            ),
          if (owner)
            (
              value: _TagAction.toggleLock,
              label: locked
                  ? l10n.communityTagUnlockAction
                  : l10n.communityTagLockAction,
              icon: locked ? Icons.lock_open_outlined : Icons.lock_outline,
            ),
        ];
        final largeText = MediaQuery.textScalerOf(ctx).scale(14) >= 21;
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          titlePadding: EdgeInsets.fromLTRB(24, largeText ? 32 : 24, 24, 0),
          contentPadding: EdgeInsets.fromLTRB(
            24,
            largeText ? 24 : 16,
            24,
            largeText ? 28 : 20,
          ),
          actionsPadding: EdgeInsets.fromLTRB(12, 0, 12, largeText ? 22 : 12),
          title: Text(tag),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locked
                    ? l10n.communityTagLockedMessage
                    : l10n.communityTagEditPrompt,
              ),
              if (locked) ...[
                SizedBox(height: largeText ? 16 : 10),
                Text(l10n.communityTagUnlockBeforeDelete),
              ],
              // ヘルプ・縦画面の視聴と同じく、タグからそのタグの作品を探せる
              // （以前はこの画面だけ、編集・削除しか選べなかった）。下の操作の
              // 並びとは分けて置く（並びに入れると狭い画面で文字が入らない）。
              SizedBox(height: largeText ? 16 : 12),
              OutlinedButton.icon(
                key: const Key('communityTagSearch'),
                onPressed: () => Navigator.pop(ctx, _TagAction.search),
                icon: const Icon(Icons.search),
                label: Text(l10n.communityTagSearchAction),
              ),
            ],
          ),
          actions: [
            FirstThatFits(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, action.value),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: Text(action.label),
                      ),
                  ],
                ),
                Wrap(
                  spacing: largeText ? 6 : 0,
                  runSpacing: largeText ? 8 : 0,
                  children: [
                    for (final action in actions)
                      IconButton(
                        tooltip: action.label,
                        onPressed: () => Navigator.pop(ctx, action.value),
                        icon: Icon(action.icon),
                      ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
    if (!mounted ||
        action == null ||
        accountRevision != service.accountRevision) {
      return;
    }
    switch (action) {
      case _TagAction.search:
        context.push('/community', extra: tag);
      case _TagAction.toggleLock:
        await _applyTagAction(
          service,
          work.id,
          locked ? CommunityTagAction.unlock : CommunityTagAction.lock,
          tag,
        );
      case _TagAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.communityTagDeleteConfirm),
            content: Text(tag),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                style: warningFilledButtonStyle(ctx),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        );
        if (mounted &&
            confirmed == true &&
            accountRevision == service.accountRevision) {
          await _applyTagAction(
            service,
            work.id,
            CommunityTagAction.remove,
            tag,
          );
        }
      case _TagAction.edit:
        final controller = TextEditingController(text: tag);
        final replacement = await showDialog<String>(
          context: context,
          builder: (ctx) => DisposeOnUnmount(
            controller: controller,
            builder: (ctx) => AlertDialog(
              insetPadding: typingDialogInsetPadding(ctx),
              title: Text(l10n.commonEdit),
              content: TextField(
                key: const Key('communityDetailTagEditor'),
                controller: controller,
                autofocus: true,
                maxLength: 30,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.communityAddTagDialogHint,
                ),
                onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  child: Text(l10n.commonApply),
                ),
              ],
            ),
          ),
        );
        if (mounted &&
            replacement != null &&
            replacement.isNotEmpty &&
            replacement != tag &&
            accountRevision == service.accountRevision) {
          await _applyTagAction(
            service,
            work.id,
            CommunityTagAction.rename,
            tag,
            replacement: replacement,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasPreviousRoute = ModalRoute.of(context)?.canPop ?? false;
    final router = GoRouter.maybeOf(context);
    AppBar detailAppBar() => AppBar(
      leading: hasPreviousRoute
          ? const BackButton()
          : router == null
          ? null
          : BackButton(onPressed: () => router.go('/community')),
      title: FitOrHideTitle(l10n.communityWorkDetailTitle),
    );

    final communityService = context.watch<CommunityService>();
    final currentAccount = context.watch<GoogleAuthService?>()?.account?.id;
    final ownerFallback =
        currentAccount != null && currentAccount == _ownerOnlyAccountId
        ? _ownerOnlyWork
        : null;
    final cachedWork = communityService.byId(widget.workId);
    // Owner-authorized details take precedence over a public unavailable
    // placeholder (e.g. a previously saved private work).
    final work = cachedWork == null || cachedWork.isUnavailable
        ? (ownerFallback ?? cachedWork)
        : cachedWork;
    final isOwner =
        work != null &&
        (ownerFallback != null || communityService.isOwnWork(work));
    if (work == null ||
        (!isOwner && !communityService.isDiscoverableForViewer(work))) {
      final hiddenByViewer =
          work != null && work.isNiarimPublished && !work.isUnavailable;
      return Scaffold(
        appBar: detailAppBar(),
        body: hiddenByViewer
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      communityService.isAuthorMuted(work.authorId) &&
                          !communityService.isAuthorBlocked(work.authorId)
                      // 作者をミュートしたので隠れたときは、そう書いてその場で
                      // 解除できる（以前は「表示フィルター」と書かれ、その
                      // 画面にミュートは無かった）。
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            messageText(
                              l10n.communityWorkHiddenByMuteMessage,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('communityWorkHiddenUnmute'),
                              onPressed: () => confirmCommunityAuthorMute(
                                context,
                                communityService,
                                work.authorId,
                                mute: false,
                              ),
                              child: Text(l10n.communityUnmuteAuthor),
                            ),
                          ],
                        )
                      : Text(
                          l10n.communityWorkHiddenByFilterMessage,
                          textAlign: TextAlign.center,
                        ),
                ),
              )
            : CommunityPlaybackStatusView(
                status: _playbackStatus,
                onRetry: _checkPlaybackStatus,
              ),
      );
    }
    // The cached public work may have been privatized or deleted after it
    // entered a feed/ranking. Non-owners must never see its title, author,
    // description or thumbnail until a fresh server + YouTube check succeeds.
    // Owners can still manage their own private uploads.
    if (!isOwner && _playbackStatus != CommunityPlaybackStatus.available) {
      return Scaffold(
        appBar: detailAppBar(),
        body: Center(
          child: CommunityPlaybackStatusView(
            status: _playbackStatus,
            onRetry: _checkPlaybackStatus,
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final isBookmarked = communityService.isBookmarked(work.id);
    final bookmarkIcon = isBookmarked ? Icons.bookmark : Icons.bookmark_border;
    final bookmarkLabel = isBookmarked
        ? l10n.communityWorkDetailBookmarkRemove
        : l10n.communityWorkDetailBookmarkAdd;
    void toggleBookmark() => _reportFailedEdit(
      communityService,
      communityService.toggleBookmark(work.id),
    );
    final isAuthorSelf = isOwner;
    final isReposted = communityService.isRepostedBySelf(work.id);
    final repostAccent = isReposted ? AccentTextTheme.of(context) : null;
    final canAddTag = work.tags.length < CommunityService.maxTagsPerWork;
    final maxPreviewHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(
      _minPreviewHeight,
      500.0,
    );
    final previewHeight = _previewHeight.clamp(
      _minPreviewHeight,
      maxPreviewHeight,
    );

    return Scaffold(
      appBar: detailAppBar(),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!communityService.isBackendConnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.communitySampleBadge,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              if (_playbackStatus == CommunityPlaybackStatus.available)
                CommunityYoutubePlayer(
                  key: ValueKey('communityDetailYoutube-${work.id}'),
                  videoId: work.id,
                  playing: false,
                  detailPreviewHeight: previewHeight,
                  detailDurationSeconds: work.durationSeconds,
                  validatePlayback: () async {
                    final status = await context
                        .read<CommunityService>()
                        .playbackStatus(work.id);
                    if (mounted &&
                        widget.workId == work.id &&
                        status != CommunityPlaybackStatus.available) {
                      setState(() => _playbackStatus = status);
                    }
                    return mounted &&
                        widget.workId == work.id &&
                        status == CommunityPlaybackStatus.available;
                  },
                )
              else
                SizedBox(
                  height: previewHeight,
                  width: double.infinity,
                  child: CommunityPlaybackStatusView(
                    status: _playbackStatus,
                    onRetry: _checkPlaybackStatus,
                  ),
                ),
              Semantics(
                label: l10n.communityFloatingPreviewResizeTooltip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: Tooltip(
                    message: l10n.communityFloatingPreviewResizeTooltip,
                    child: GestureDetector(
                      key: const Key('communityWorkDetailPreviewResizeHandle'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) => setState(() {
                        _previewHeight = (previewHeight + d.delta.dy).clamp(
                          _minPreviewHeight,
                          maxPreviewHeight,
                        );
                      }),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        alignment: Alignment.center,
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                work.title,
                style: localizedUserNameStyle(
                  context,
                  work.title,
                  localizedHeadingStyle(
                    context,
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              CommunityWorkDescription(
                key: ValueKey('communityWorkDescription-${work.id}'),
                workId: work.id,
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
                            // 作者の頭文字の丸は中立の面の色（差し色の淡い
                            // 丸は飾りで、名前のリンクの差し色と重なった）。
                            backgroundColor: scheme.surfaceContainerHighest,
                            child: Text(
                              work.authorName.substring(0, 1),
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              work.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: localizedHeadingStyle(
                                context,
                                TextStyle(
                                  fontSize: 14,
                                  color: AccentTextTheme.of(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isAuthorSelf)
                    IconButton(
                      onPressed: () => _reportFailedEdit(
                        communityService,
                        communityService.toggleFavoriteAuthor(work.authorId),
                      ),
                      icon: Icon(
                        communityService.isFavoriteAuthor(work.authorId)
                            ? Icons.person_remove_alt_1
                            : Icons.person_add_alt_1,
                        color: communityService.isFavoriteAuthor(work.authorId)
                            ? scheme.onSurfaceVariant
                            : AccentTextTheme.of(context),
                      ),
                      tooltip: communityService.isFavoriteAuthor(work.authorId)
                          ? l10n.communityFavoriteAuthorFollowing
                          : l10n.communityFavoriteAuthorFollow,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              CommunityWorkCounts(
                work: work,
                fontSize: 14,
                postedLabel: l10n.communityWorkDetailPostedLabel(
                  DateFormat.yMd(
                    l10n.localeName,
                  ).add_Hm().format(work.postedAt.toLocal()),
                ),
              ),
              if (_hasProjectMetadata(work) ||
                  work.containsGenerativeAiImageOrVideo) ...[
                const SizedBox(height: 12),
                _ProjectMetadataCard(work: work),
              ],
              // 自分の作品の2つの設定は、別々の色の箱にせず1枚の面に並べる。
              if (isAuthorSelf) ...[
                const SizedBox(height: 16),
                GroupedSheet(
                  children: [
                    _NiarimVisibilitySwitch(
                      isPublished: work.isNiarimPublished,
                      onChanged: () => _reportFailedEdit(
                        communityService,
                        communityService.toggleNiarimVisibility(work.id),
                      ),
                    ),
                    _AiImageVideoSwitch(
                      value: work.containsGenerativeAiImageOrVideo,
                      onChanged: _aiDisclosureBusy
                          ? null
                          : (value) => _setAiImageVideoDisclosure(
                              communityService,
                              work.id,
                              value,
                            ),
                    ),
                  ],
                ),
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
                      onTap: () => _showTagActions(communityService, work, tag),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(l10n.communityAddTagButton),
                    onPressed: canAddTag
                        ? () => _showAddTagDialog(communityService, work.id)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CommunityYoutubeCommentsSection(
                key: ValueKey('communityYoutubeComments-${work.id}'),
                workId: work.id,
                onOpenYouTube: () => _openYoutubeIfAvailable(work.id),
              ),
              const SizedBox(height: 20),
              // 2つのボタンは、名前の幅のまま1行に入るなら並べ（「YouTubeで
              // 見る」を広げる）、入らなければ1つずつの行に分ける（狭い幅・
              // 大きな文字で「YouTubeで見る」が押しつぶされ、名前が語の途中で
              // 折れた）。行の幅いっぱいでも名前が1行に入らなければアイコン
              // （名前は吹き出しと読み上げ）。
              ButtonRowOrStack(
                children: [
                  FirstThatFits(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openYoutubeIfAvailable(work.id),
                        icon: const Icon(Icons.smart_display_outlined),
                        label: Text(l10n.communityWorkDetailViewOnYoutube),
                      ),
                      Tooltip(
                        message: l10n.communityWorkDetailViewOnYoutube,
                        child: FilledButton(
                          onPressed: () => _openYoutubeIfAvailable(work.id),
                          child: const Icon(Icons.smart_display_outlined),
                        ),
                      ),
                    ],
                  ),
                  FirstThatFits(
                    children: [
                      OutlinedButton.icon(
                        style: isReposted
                            ? OutlinedButton.styleFrom(
                                foregroundColor: repostAccent,
                                side: BorderSide(color: repostAccent!),
                              )
                            : null,
                        onPressed: () => _reportFailedEdit(
                          communityService,
                          communityService.toggleRepost(work.id),
                        ),
                        icon: const Icon(Icons.repeat),
                        label: Text(
                          isReposted
                              ? l10n.communityRepostedButton
                              : l10n.communityRepostButton,
                        ),
                      ),
                      IconButton.outlined(
                        color: repostAccent,
                        onPressed: () => _reportFailedEdit(
                          communityService,
                          communityService.toggleRepost(work.id),
                        ),
                        tooltip: isReposted
                            ? l10n.communityRepostedButton
                            : l10n.communityRepostButton,
                        icon: const Icon(Icons.repeat),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FirstThatFits(
                  children: [
                    OutlinedButton.icon(
                      onPressed: toggleBookmark,
                      icon: Icon(bookmarkIcon),
                      label: Text(bookmarkLabel),
                    ),
                    IconButton.outlined(
                      onPressed: toggleBookmark,
                      tooltip: bookmarkLabel,
                      icon: Icon(bookmarkIcon),
                    ),
                  ],
                ),
              ),
              if (!isOwner) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          reportCommunityContent(context, workId: work.id),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(l10n.communityWorkDetailReportButton),
                    ),
                    TextButton.icon(
                      onPressed: () => confirmCommunityAuthorMute(
                        context,
                        communityService,
                        work.authorId,
                        mute: true,
                      ),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: Text(l10n.communityMuteConfirmAction),
                    ),
                    if (communityService.isBackendConnected)
                      TextButton.icon(
                        onPressed: () => confirmCommunityBlock(
                          context,
                          work.authorId,
                          blocked: true,
                        ),
                        icon: const Icon(Icons.block, size: 18),
                        label: Text(l10n.communityBlockAuthor),
                      ),
                  ],
                ),
              ],
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
    (work.projectCanvasWidth > 0 && work.projectCanvasHeight > 0);

class _ProjectMetadataCard extends StatelessWidget {
  final CommunityWork work;

  const _ProjectMetadataCard({required this.work});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workTime = formatProjectWorkTime(l10n, work.projectWorkSeconds);
    // 作品の情報（コマ数・fps・大きさ・制作時間）は用紙の上に並べる（淡い色の
    // 箱に入れると、下の設定の面とも違う3つ目の面になっていた）。
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
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
                text: l10n.pcStatusFps(work.projectFps),
              ),
            if (work.projectCanvasWidth > 0 && work.projectCanvasHeight > 0)
              _ProjectMetaItem(
                icon: Icons.aspect_ratio_rounded,
                text: '${work.projectCanvasWidth}×${work.projectCanvasHeight}',
              ),
            if (workTime.isNotEmpty || work.containsGenerativeAiImageOrVideo)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (workTime.isNotEmpty)
                    Flexible(
                      child: _ProjectMetaItem(
                        icon: Icons.timer_outlined,
                        text: workTime,
                      ),
                    ),
                  if (workTime.isNotEmpty &&
                      work.containsGenerativeAiImageOrVideo)
                    const SizedBox(width: 14),
                  if (work.containsGenerativeAiImageOrVideo)
                    Flexible(
                      child: _ProjectMetaItem(
                        key: const ValueKey('communityDetailAiImageVideoLabel'),
                        icon: Icons.smart_toy_outlined,
                        text: l10n.communityContainsGenerativeAiImageVideo,
                      ),
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

  const _ProjectMetaItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isLocked;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: isLocked ? l10n.communityTagLockedMessage : null,
      child: ActionChip(
        key: ValueKey('communityDetailTag-$label'),
        avatar: SizedBox(
          width: 16,
          height: 16,
          child: Icon(
            isLocked ? Icons.lock_outline : Icons.edit_outlined,
            size: 15,
            color: scheme.onSurfaceVariant,
          ),
        ),
        label: Text(label),
        onPressed: onTap,
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
    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isPublished ? Icons.public : Icons.lock_outline,
              color: isPublished
                  ? AccentTextTheme.of(context)
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.communityVisibilityCardTitle,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPublished
                        ? l10n.communityVisibilityPublishedDesc
                        : l10n.communityVisibilityHiddenDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
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
    );
  }
}

/// The poster's 「AI画像・AI動画使用」 declaration, changeable after posting.
class _AiImageVideoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _AiImageVideoSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              color: value
                  ? AccentTextTheme.of(context)
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.communityContainsGenerativeAiImageVideo,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.communityContainsGenerativeAiImageVideoHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              key: const ValueKey('communityDetailAiImageVideoSwitch'),
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
