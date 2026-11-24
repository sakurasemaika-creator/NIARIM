import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/accent_text_theme.dart';

import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../config/font_fallback.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../l10n/community_channel_refresh_labels.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import 'community_error_text.dart';
import 'community_author_works_screen.dart';
import 'community_post_screen.dart';
import 'community_work_settings_screen.dart';
import 'widgets/community_top_edge_refresh.dart';
import 'widgets/community_work_counts.dart';
import '../../widgets/first_that_fits.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_card.dart';
import '../../widgets/sort_mode_control.dart';
import '../../widgets/collection_action_controls.dart';
import '../../widgets/collection_tile_layout.dart';
import '../../widgets/legal_consent.dart';
import '../../utils/responsive_tile_defaults.dart';
import 'widgets/community_thumbnail_placeholder.dart';
import 'widgets/community_work_card.dart' show CommunityWorkOrientation;
import 'widgets/community_list_controls.dart';
import 'widgets/video_type_filter.dart';

/// Owner hub opened from the community square.
///
/// The authenticated backend path is GET /me/works, so switching Google accounts
/// automatically switches the NIARIM owner list without persisting a generated
/// NIARIM author id on-device. Hidden works are included here and can be toggled
/// with PATCH /works/{videoId}; the work id remains the YouTube video id.
class CommunityMyWorksScreen extends StatefulWidget {
  const CommunityMyWorksScreen({super.key, this.startPosting = false});

  /// 開いたらすぐ投稿を始める（作品広場の「投稿する」から来たとき）。
  /// ログインしていなければ、いつもの「投稿する」と同じくログインから。
  final bool startPosting;

  @override
  State<CommunityMyWorksScreen> createState() => _CommunityMyWorksScreenState();
}

class _CommunityMyWorksScreenState extends State<CommunityMyWorksScreen> {
  bool _switchingAccount = false;
  bool _refreshingYouTubeChannel = false;
  bool _loadingWorks = false;
  Object? _worksError;
  List<CommunityWork>? _ownerWorks;
  String? _ownerStateAccountId;
  String? _observedAccountId;
  bool _observingAccount = false;
  int _ownerLoadGeneration = 0;
  Map<String, String> _youtubePrivacyById = const <String, String>{};
  Map<String, DateTime> _scheduledPublishById = const <String, DateTime>{};
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;
  bool _bulkBusy = false;
  CollectionViewSize? _viewSize;
  bool _detail = false;
  bool _sortByName = false;
  bool _sortAscending = false;
  VideoTypeFilter _filter = VideoTypeFilter.all;

  bool get _needsCompleteOwnList =>
      _sortByName || _sortAscending || _filter != VideoTypeFilter.all;

  void _updateListControls({
    bool? byName,
    bool? ascending,
    VideoTypeFilter? filter,
  }) {
    setState(() {
      _sortByName = byName ?? _sortByName;
      _sortAscending = ascending ?? _sortAscending;
      _filter = filter ?? _filter;
      _visibleOwnCount = CommunityService.pageSize;
      if (filter != null) {
        _selectedIds.clear();
        _selectionMode = false;
      }
    });
    if (_worksScrollController.hasClients) _worksScrollController.jumpTo(0);
    final service = context.read<CommunityService>();
    if (!_loadingWorks && _needsCompleteOwnList && service.hasMoreOwn) {
      unawaited(_loadMoreOwnerWorks());
    }
  }

  final ScrollController _worksScrollController = ScrollController();
  bool _loadingMoreOwnWorks = false;
  int _visibleOwnCount = CommunityService.pageSize;

  void _onWorksScroll() {
    if (!_worksScrollController.hasClients ||
        _worksScrollController.position.extentAfter > 220 ||
        _loadingWorks ||
        _loadingMoreOwnWorks) {
      return;
    }
    final service = context.read<CommunityService>();
    if (service.api == null) {
      final total = service
          .worksByAuthor(kDummySelfAuthorId, includeHidden: true)
          .length;
      if (_visibleOwnCount < total) {
        setState(() => _visibleOwnCount += CommunityService.pageSize);
      }
    } else if (service.hasMoreOwn) {
      _loadMoreOwnerWorks();
    }
  }

  Future<void> _loadMoreOwnerWorks() async {
    if (_loadingMoreOwnWorks || _loadingWorks) {
      return;
    }
    final generation = _ownerLoadGeneration;
    final accountId = context.read<GoogleAuthService>().account?.id;
    setState(() => _loadingMoreOwnWorks = true);
    final service = context.read<CommunityService>();
    try {
      do {
        final page = await service.loadMoreOwnWorks();
        if (!mounted ||
            generation != _ownerLoadGeneration ||
            accountId != context.read<GoogleAuthService>().account?.id ||
            page == null) {
          return;
        }
        setState(() {
          _ownerWorks = [
            ...?_ownerWorks,
            for (final w in page.works)
              if (!(_ownerWorks?.any((old) => old.id == w.workId) ?? false))
                w.toCommunityWork(),
          ];
          _youtubePrivacyById = {
            ..._youtubePrivacyById,
            for (final work in page.works)
              if (work.youtubePrivacyStatus != null)
                work.workId: work.youtubePrivacyStatus!,
          };
          _scheduledPublishById = {
            ..._scheduledPublishById,
            for (final work in page.works)
              if (work.scheduledPublishAt != null)
                work.workId: work.scheduledPublishAt!,
          };
        });
      } while (_needsCompleteOwnList && service.hasMoreOwn);
    } catch (error) {
      if (mounted && generation == _ownerLoadGeneration) {
        setState(() => _worksError = error);
      }
    } finally {
      if (mounted) setState(() => _loadingMoreOwnWorks = false);
    }
  }

  @override
  void dispose() {
    _worksScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _worksScrollController.addListener(_onWorksScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadOwnerWorks();
      if (widget.startPosting && mounted) _handlePostTap();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accountId = context.watch<GoogleAuthService>().account?.id;
    if (!_observingAccount) {
      _observingAccount = true;
      _observedAccountId = accountId;
      return;
    }
    if (_observedAccountId == accountId) return;
    _observedAccountId = accountId;
    _ownerLoadGeneration++;
    _ownerStateAccountId = accountId;
    _ownerWorks = null;
    _visibleOwnCount = CommunityService.pageSize;
    _youtubePrivacyById = const <String, String>{};
    _scheduledPublishById = const <String, DateTime>{};
    _worksError = null;
    _selectedIds.clear();
    _selectionMode = false;
    _loadingWorks = accountId != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _observedAccountId == accountId) _reloadOwnerWorks();
    });
  }

  Future<void> _reloadOwnerWorks() async {
    if (!mounted) return;
    final auth = context.read<GoogleAuthService>();
    final community = context.read<CommunityService>();
    final api = community.api;
    final generation = ++_ownerLoadGeneration;
    _visibleOwnCount = CommunityService.pageSize;
    if (_worksScrollController.hasClients) _worksScrollController.jumpTo(0);
    if (api == null || !auth.isSignedIn) {
      community.forgetOwner();
      setState(() {
        _ownerStateAccountId = null;
        _ownerWorks = null;
        _youtubePrivacyById = const <String, String>{};
        _scheduledPublishById = const <String, DateTime>{};
        _worksError = null;
        _loadingWorks = false;
        _selectedIds.clear();
        _selectionMode = false;
      });
      return;
    }

    final requestedAccountId = auth.account?.id;
    setState(() {
      _ownerStateAccountId = requestedAccountId;
      _loadingWorks = true;
      _worksError = null;
    });
    try {
      // Also tells the service who the poster is and keeps their works,
      // hidden ones included, in its store.
      final page = await community.loadOwnWorks();
      if (!mounted ||
          generation != _ownerLoadGeneration ||
          auth.account?.id != requestedAccountId ||
          page == null) {
        return;
      }
      final ownerId = community.currentUserId;
      if (ownerId != null) {
        unawaited(community.refreshFollowerCount(ownerId));
      }
      final works = page.works;
      final converted = works.map((w) => w.toCommunityWork()).toList()
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
      final privacy = <String, String>{
        for (final work in works)
          if (work.youtubePrivacyStatus != null)
            work.workId: work.youtubePrivacyStatus!,
      };
      final schedules = <String, DateTime>{
        for (final work in works)
          if (work.scheduledPublishAt != null)
            work.workId: work.scheduledPublishAt!,
      };
      if (!mounted) return;
      setState(() {
        _ownerWorks = converted;
        _youtubePrivacyById = privacy;
        _scheduledPublishById = schedules;
        final availableIds = converted.map((work) => work.id).toSet();
        _selectedIds.removeWhere((id) => !availableIds.contains(id));
        if (_selectedIds.isEmpty) _selectionMode = false;
      });
    } catch (error) {
      debugPrint('Own works could not be loaded: $error');
      if (!mounted ||
          generation != _ownerLoadGeneration ||
          auth.account?.id != requestedAccountId) {
        return;
      }
      setState(() => _worksError = error);
    } finally {
      if (mounted &&
          generation == _ownerLoadGeneration &&
          auth.account?.id == requestedAccountId) {
        setState(() => _loadingWorks = false);
        if (_needsCompleteOwnList && community.hasMoreOwn) {
          unawaited(_loadMoreOwnerWorks());
        }
      }
    }
  }

  void _showSnackBar(String message) {
    // SnackBarThemeData owns the same 18px rounded, shadow-free appearance.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Why a Google sign-in step failed. A refusal because another account
  /// operation is still running is told apart by that operation's flag.
  String _googleErrorText(
    AppLocalizations l10n,
    GoogleAuthService auth,
    Object error,
  ) => auth.authOperationInProgress
      ? l10n.communityGoogleAccountBusy
      : communityErrorText(l10n, error);

  /// A NIARIM-styled explanation before invoking the native Google account
  /// chooser. Browsing the plaza or opening My Works never triggers this.
  Future<bool> _confirmGoogleSignIn() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<GoogleAuthService>();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('communityGoogleSignInPrompt'),
            title: Text(l10n.communitySignInPromptTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.communitySignInPromptBody),
                if (!auth.isConfigured) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.communitySignInUnavailable,
                    style: TextStyle(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('communityGoogleSignInPromptConnect'),
                    onPressed: auth.isConfigured
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(l10n.communitySignInPromptConnect),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _switchOrAddGoogleAccount() async {
    final auth = context.read<GoogleAuthService>();
    final l10n = AppLocalizations.of(context)!;
    if (!auth.isConfigured) {
      await _confirmGoogleSignIn();
      return;
    }
    if (auth.authOperationInProgress) {
      _showSnackBar(l10n.communityGoogleAccountBusy);
      return;
    }

    if (!await ensureLegalConsent(context) || !mounted) return;
    setState(() => _switchingAccount = true);
    try {
      // The interactive picker keeps the current session if it is dismissed.
      // didChangeDependencies reloads owner-only data when the account changes.
      await auth.signInInteractively();
    } catch (error) {
      debugPrint('Google account switch failed: $error');
      if (!mounted) return;
      _showSnackBar(
        l10n.communityAccountSwitchFailed(_googleErrorText(l10n, auth, error)),
      );
    } finally {
      if (mounted) setState(() => _switchingAccount = false);
    }
  }

  Future<void> _refreshYoutubeChannel() async {
    if (_refreshingYouTubeChannel) return;
    final labels = CommunityChannelRefreshLabels.of(context);
    final auth = context.read<GoogleAuthService>();
    final service = context.read<CommunityService>();
    final api = service.api;
    if (api == null || !auth.isSignedIn) {
      _showSnackBar(labels.unavailable);
      return;
    }
    final accountId = auth.account?.id;
    setState(() => _refreshingYouTubeChannel = true);
    try {
      final token = await auth.youtubeReadAccessToken(promptIfNecessary: true);
      if (!mounted || auth.account?.id != accountId) return;
      if (token == null || token.isEmpty) {
        _showSnackBar(labels.noToken);
        return;
      }
      final profile = await api.refreshYoutubeChannelInfo(token);
      if (!mounted || auth.account?.id != accountId) return;
      final name = profile['channelName'] as String?;
      if (name != null && name.isNotEmpty) {
        service.applyMyYoutubeChannelName(name);
        setState(() {
          _ownerWorks = [
            for (final work in _ownerWorks ?? <CommunityWork>[])
              work.copyWith(authorName: name),
          ];
        });
      }
      _showSnackBar(labels.success);
    } catch (_) {
      if (!mounted || auth.account?.id != accountId) return;
      _showSnackBar(labels.failed);
    } finally {
      if (mounted) setState(() => _refreshingYouTubeChannel = false);
    }
  }

  Future<void> _handlePostTap() async {
    final auth = context.read<GoogleAuthService>();
    final l10n = AppLocalizations.of(context)!;
    if (!auth.isSignedIn) {
      if (!await _confirmGoogleSignIn() || !mounted) return;
      if (!await ensureLegalConsent(context) || !mounted) return;
      if (auth.authOperationInProgress) {
        _showSnackBar(l10n.communityGoogleAccountBusy);
        return;
      }
      try {
        await auth.signInInteractively();
        await _reloadOwnerWorks();
      } catch (error) {
        debugPrint('Google sign-in failed: $error');
        if (!mounted) return;
        _showSnackBar(
          l10n.communitySignInFailed(_googleErrorText(l10n, auth, error)),
        );
        return;
      }
    }
    if (!mounted) return;

    final videoId = await Navigator.of(context).push<String>(
      adMockMaterialPageRoute<String>(
        builder: (_) => const CommunityPostScreen(),
      ),
    );
    if (!mounted || videoId == null) return;
    await context.read<CommunityService>().refreshFromBackend();
    await _reloadOwnerWorks();
  }

  void _openOwnAuthorPage(List<CommunityWork> works) {
    final service = context.read<CommunityService>();
    final authorId =
        service.currentUserId ??
        (service.api == null ? kDummySelfAuthorId : null);
    if (authorId == null) {
      _showSnackBar(
        AppLocalizations.of(context)!.communityMyWorksAccountRequired,
      );
      return;
    }
    final account = context.read<GoogleAuthService>().account;
    final name = works.isNotEmpty
        ? works.first.authorName
        : (account?.displayName ??
              account?.email ??
              AppLocalizations.of(context)!.communityMyWorksTitle);
    Navigator.of(context).push(
      adMockMaterialPageRoute<void>(
        builder: (_) =>
            CommunityAuthorWorksScreen(authorId: authorId, authorName: name),
      ),
    );
  }

  void _toggleSelected(String workId) {
    if (_bulkBusy) return;
    setState(() {
      _selectionMode = true;
      if (!_selectedIds.add(workId)) _selectedIds.remove(workId);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _selectAll(List<CommunityWork> works) {
    if (_bulkBusy) return;
    setState(() {
      _selectedIds.addAll(works.map((work) => work.id));
      _selectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    if (_bulkBusy) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _openWorkSettings(CommunityWork work) async {
    if (_bulkBusy) return;
    final deleted = await Navigator.of(context).push<bool>(
      adMockMaterialPageRoute<bool>(
        builder: (_) => CommunityWorkSettingsScreen(
          workId: work.id,
          youtubePrivacyStatus: _youtubePrivacyById[work.id],
        ),
      ),
    );
    if (!mounted) return;
    if (deleted != true) {
      // A title edit is stored server-side. Reload the owner page so its
      // cached 25-item list also reflects the new title.
      await _reloadOwnerWorks();
      if (!mounted) return;
    }
    setState(() {
      if (deleted == true) {
        _ownerWorks?.removeWhere((item) => item.id == work.id);
        _youtubePrivacyById = Map.of(_youtubePrivacyById)..remove(work.id);
        _scheduledPublishById = Map.of(_scheduledPublishById)..remove(work.id);
        _selectedIds.remove(work.id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      }
    });
  }

  /// Sequential, idempotent visibility updates: a partial failure remains
  /// selected for retry. Never bulk-delete or bulk-update the AI declaration.
  /// 一括のボタン（アイコンつきの塗りのボタン）の名前[label]が、幅
  /// [buttonWidth]のボタンの中に1行で入るか。ボタンの左右の余白（16・24）、
  /// アイコン（18）と間（8）を除いた幅で、ボタンと同じ書式・文字の大きさで
  /// 測る。
  bool _bulkLabelFits(BuildContext context, String label, double buttonWidth) {
    final theme = Theme.of(context);
    final style = (theme.textTheme.labelLarge ?? const TextStyle()).merge(
      theme.filledButtonTheme.style?.textStyle?.resolve(const {}),
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width <= buttonWidth - 16 - 24 - 18 - 8;
  }

  Future<void> _applyBulkVisibility(
    List<CommunityWork> works,
    bool published,
  ) async {
    if (_bulkBusy || _selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<CommunityService>();
    final revision = service.accountRevision;
    final targets = [
      for (final work in works)
        if (_selectedIds.contains(work.id)) work,
    ];
    setState(() => _bulkBusy = true);
    var completed = 0;
    var failed = 0;
    for (final work in targets) {
      if (!mounted || service.accountRevision != revision) break;
      if (published && _youtubePrivacyById[work.id] == 'deleted') {
        failed++;
        continue;
      }
      try {
        if (work.isNiarimPublished != published) {
          await service.setNiarimVisibility(work.id, published);
        }
        completed++;
        if (mounted) setState(() => _selectedIds.remove(work.id));
      } on CommunityAccountChangedException {
        break;
      } catch (error) {
        debugPrint('Bulk visibility failed for ${work.id}: $error');
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
    _showSnackBar(l10n.communityMyWorksBulkResult(completed, failed));
  }

  String _visibilityLabel(AppLocalizations l10n, CommunityWork work) {
    final youtubePrivacy = _youtubePrivacyById[work.id];
    if (youtubePrivacy == 'deleted') {
      return l10n.communityMyWorksStatusDeletedOnYoutube;
    }
    final schedule = _scheduledPublishById[work.id];
    if (youtubePrivacy == 'private' && schedule != null) {
      final date = schedule.toLocal();
      if (schedule.isAfter(DateTime.now())) {
        return work.isNiarimPublished
            ? l10n.communityMyWorksStatusScheduled(date)
            : l10n.communityMyWorksStatusScheduledHidden(date);
      }
      return l10n.communityMyWorksStatusSchedulePassed;
    }
    if (youtubePrivacy == 'private') {
      return work.isNiarimPublished
          ? l10n.communityMyWorksStatusYoutubePrivate
          : l10n.communityMyWorksStatusHiddenYoutubePrivate;
    }
    return work.isNiarimPublished
        ? l10n.communityVisibilityPublishedBadge
        : l10n.communityVisibilityHiddenBadge;
  }

  IconData _visibilityIcon(CommunityWork work) {
    final youtubePrivacy = _youtubePrivacyById[work.id];
    if (youtubePrivacy == 'deleted') return Icons.delete_forever_outlined;
    if (youtubePrivacy == 'private' && _scheduledPublishById[work.id] != null) {
      return Icons.schedule;
    }
    if (youtubePrivacy == 'private') return Icons.lock_outline;
    return work.isNiarimPublished
        ? Icons.public
        : Icons.visibility_off_outlined;
  }

  Widget _workTile(
    BuildContext context,
    AppLocalizations l10n,
    CommunityWork work,
    CollectionViewSize size,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final deleted = _youtubePrivacyById[work.id] == 'deleted';
    final selected = _selectedIds.contains(work.id);
    final title = work.title.isEmpty ? work.id : work.title;
    final thumbnail = Stack(
      fit: StackFit.expand,
      children: [
        CommunityThumbnailPlaceholder(
          child: !deleted && work.thumbnailUrl.startsWith('https://')
              ? Image.network(
                  work.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                )
              : null,
        ),
        if (_selectionMode)
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Checkbox(
              key: ValueKey('communityMyWorksSelect-${work.id}'),
              value: selected,
              onChanged: _bulkBusy ? null : (_) => _toggleSelected(work.id),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: scheme.surface,
                child: Icon(_visibilityIcon(work), size: 15),
              ),
            ),
          ),
      ],
    );
    final details = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: collectionTileCaptionStyle(context),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          '${_visibilityLabel(l10n, work)}  •  ${l10n.communityYoutubeVideoIdLabel(work.id)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
      if (!deleted && !work.isUnavailable)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: CommunityWorkCounts(
                work: work,
                compact: true,
                fontSize: 10,
              ),
            ),
          ),
        ),
      if (_selectionMode)
        CollectionTileActions.selectionSpace
      else
        CollectionTileActions(
          compact: size == CollectionViewSize.small,
          leading: deleted ? null : CommunityWorkOrientation(work: work),
          children: [
            CollectionActionFrame(
              child: IconButton(
                key: ValueKey('communityMyWorksSettings-${work.id}'),
                tooltip: l10n.communityMyWorksSettingsTitle,
                onPressed: () => _openWorkSettings(work),
                padding: EdgeInsets.zero,
                iconSize: CollectionActionFrame.glyphSize,
                icon: const Icon(Icons.build_outlined),
              ),
            ),
          ],
        ),
    ];
    return MenuCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('communityMyWorksRow-${work.id}'),
        onTap: () {
          if (_selectionMode) {
            _toggleSelected(work.id);
          } else {
            context.read<CommunityPreviewService>().show(work);
          }
        },
        onLongPress: () {
          if (_selectionMode) {
            _toggleSelected(work.id);
          } else {
            setState(() {
              _selectionMode = true;
              _selectedIds.add(work.id);
            });
          }
        },
        child: _detail
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width < 400 ? 104 : 168,
                      child: thumbnail,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: details,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: thumbnail),
                  ...details,
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final communityService = context.watch<CommunityService>();
    final auth = context.watch<GoogleAuthService>();
    final account = auth.account;
    final accountLabel = account == null
        ? l10n.communityMyWorksAccountNotConnected
        : (account.displayName?.trim().isNotEmpty ?? false)
        ? account.displayName!.trim()
        : account.email;

    final usingBackendOwnerList =
        communityService.api != null && auth.isSignedIn;
    // The owner list keeps its own order and the works hidden from others,
    // but each row shows the store's copy, so an edit made anywhere (a
    // tag, the AI image/video flag, the visibility) shows here too.
    final hasCurrentOwnerState = _ownerStateAccountId == account?.id;
    final ownerId = usingBackendOwnerList && hasCurrentOwnerState
        ? communityService.currentUserId
        : null;
    final allWorks = usingBackendOwnerList
        ? [
            for (final w
                in (hasCurrentOwnerState ? _ownerWorks : null) ??
                    const <CommunityWork>[])
              communityService.byId(w.id) ?? w,
          ]
        : communityService.worksByAuthor(
            kDummySelfAuthorId,
            includeHidden: true,
          );

    final sorting =
        usingBackendOwnerList &&
        _needsCompleteOwnList &&
        (_loadingWorks || _loadingMoreOwnWorks);
    final sorted = sortCommunityWorks(
      _filter.apply(allWorks),
      byName: _sortByName,
      ascending: _sortAscending,
    );
    final works = sorting
        ? const <CommunityWork>[]
        : usingBackendOwnerList
        ? sorted
        : sorted.take(_visibleOwnCount).toList();
    final viewSize =
        _viewSize ?? defaultTileSizeFor(MediaQuery.sizeOf(context).width);
    return Scaffold(
      appBar: AppBar(
        // 選んでいる間の題は選んだ件数（画面名ではなく、ここにしか出ない
        // 情報）なので、入らない幅でも隠さず短い形で出す。
        title: _selectionMode
            ? _SelectionCountTitle(_selectedIds.length)
            : FitOrHideTitle(l10n.communityMyWorksTitle),
        actions: [
          CommunityWorkViewButton(
            detail: _detail,
            size: viewSize,
            onChanged: (value) => setState(() {
              _detail = value == CommunityWorkView.detail;
              _viewSize = value.tileSize ?? _viewSize;
            }),
          ),
          IconButton(
            tooltip: l10n.communityReloadTooltip,
            onPressed: _loadingWorks ? null : _reloadOwnerWorks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: CommunityTopEdgeRefresh(
          key: const Key('communityMyWorksPullRefresh'),
          controller: _worksScrollController,
          enabled: usingBackendOwnerList,
          onRefresh: () async {
            if (_loadingWorks || _bulkBusy || _loadingMoreOwnWorks) return;
            await _reloadOwnerWorks();
          },
          child: CustomScrollView(
            controller: _worksScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // At large text sizes the account controls can be taller than
              // the remaining viewport. Let them scroll with the work rows.
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // アカウント・投稿・自分のページへの道を1枚の面にまとめる。
                    // 主な操作の「投稿する」だけを塗りのボタンにし、ほかは
                    // 面の中の行にする（以前は塗りのボタンの下に幅の違う枠の
                    // ボタンが3つ積まれ、どれも同じ重さに見えた）。
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: GroupedSheet(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          scheme.surfaceContainerHighest,
                                      child: Icon(
                                        account == null
                                            ? Icons.person_outline
                                            : Icons.account_circle,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            accountLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (account != null &&
                                              account.email !=
                                                  accountLabel) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              account.email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (ownerId != null) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    key: const Key(
                                      'communityMyWorksSocialCounts',
                                    ),
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        l10n.communityAuthorFollowerCount(
                                          communityService.followerCountOf(
                                            ownerId,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        l10n.communityAuthorFollowingCount(
                                          communityService.followingCountOf(
                                            ownerId,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  key: const Key('communityMyWorksPostButton'),
                                  onPressed: _handlePostTap,
                                  icon: const Icon(Icons.video_call_outlined),
                                  label: Text(l10n.communityPostButton),
                                ),
                              ],
                            ),
                          ),
                          SheetRow(
                            key: const Key('communityMyWorksViewAuthorPage'),
                            icon: Icons.collections_outlined,
                            title: l10n.communityMyWorksViewAuthorPage,
                            onTap: () => _openOwnAuthorPage(works),
                          ),
                          if (account != null && communityService.api != null)
                            SheetRow(
                              key: const Key(
                                'communityMyWorksYoutubeChannelRefresh',
                              ),
                              leading: _refreshingYouTubeChannel
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_outlined),
                              title: CommunityChannelRefreshLabels.of(
                                context,
                              ).button,
                              showChevron: false,
                              onTap: _refreshingYouTubeChannel
                                  ? null
                                  : _refreshYoutubeChannel,
                            ),
                          SheetRow(
                            key: const Key('communityMyWorksAccountButton'),
                            leading: _switchingAccount
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.manage_accounts_outlined),
                            title: account == null
                                ? l10n.communityMyWorksAddAccount
                                : l10n.communityMyWorksSwitchAccount,
                            onTap: _switchingAccount
                                ? null
                                : _switchOrAddGoogleAccount,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        l10n.communityMyWorksManagementHeading,
                        key: const Key('communityMyWorksManagementHeading'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontFamily: headingFontFamilyFor(
                                Localizations.maybeLocaleOf(context),
                              ),
                              fontFamilyFallback: headingFontFallbackFor(
                                Localizations.maybeLocaleOf(context),
                              ),
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.communityAuthorWorksCount(works.length),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (_loadingWorks) ...[
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                          IconButton(
                            key: const Key('communityMyWorksSelectAll'),
                            onPressed: works.isEmpty || _bulkBusy
                                ? null
                                : () => _selectAll(works),
                            tooltip: l10n.homeSelectionAllSelect,
                            icon: const Icon(Icons.select_all),
                          ),
                          IconButton(
                            key: const Key('communityMyWorksClearSelection'),
                            onPressed: _selectedIds.isEmpty || _bulkBusy
                                ? null
                                : _clearSelection,
                            tooltip: l10n.homeSelectionAllDeselect,
                            icon: const Icon(Icons.deselect),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SortModeControl(
                              dateLabel: l10n.communityAuthorSortPosted,
                              sortByName: _sortByName,
                              sortAscending: _sortAscending,
                              onSortByNameChanged: (value) =>
                                  _updateListControls(
                                    byName: value,
                                    ascending: value,
                                  ),
                              onToggleDirection: () => _updateListControls(
                                ascending: !_sortAscending,
                              ),
                            ),
                          ),
                          VideoTypeFilterButton(
                            compact: true,
                            value: _filter,
                            onChanged: (value) =>
                                _updateListControls(filter: value),
                          ),
                        ],
                      ),
                    ),
                    if (_worksError != null &&
                        usingBackendOwnerList &&
                        hasCurrentOwnerState)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: MaterialBanner(
                          content: Text(
                            l10n.communityMyWorksLoadFailed(
                              communityErrorText(l10n, _worksError!),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: _reloadOwnerWorks,
                              child: Text(l10n.communityRetry),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (works.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 56,
                            color: AccentTextTheme.of(
                              context,
                            ).withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            sorting || (usingBackendOwnerList && _loadingWorks)
                                ? l10n.communityMyWorksLoading
                                : l10n.communityEmptyState,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: _detail
                      ? SliverList.separated(
                          itemCount: works.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _workTile(context, l10n, works[index], viewSize),
                        )
                      : SliverGrid.builder(
                          gridDelegate: collectionTileGridDelegate(
                            context,
                            viewSize.tileExtent,
                            actionBandHeight:
                                CollectionActionFrame.targetExtent,
                          ),
                          itemCount: works.length,
                          itemBuilder: (context, index) =>
                              _workTile(context, l10n, works[index], viewSize),
                        ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: _selectionMode ? 126 : 24),
                    child: _loadingMoreOwnWorks
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectionMode
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Material(
                  key: const Key('communityMyWorksBulkActions'),
                  // Material already defaults to elevation 0.
                  borderRadius: BorderRadius.circular(18),
                  color: scheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    // 名前が1行で入らない幅（長い言語・大きな文字）では、
                    // 2つともアイコンだけにする（名前は吹き出しと読み上げ。
                    // 所有者の判断3と同じ。文字は縮めない）。以前は名前が
                    // 3〜4行に折れてボタンが高くなり、作品の一覧が約20pxの
                    // 帯になった（DISC159）。
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final hideStyle = FilledButton.styleFrom(
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          side: BorderSide.none,
                        );
                        final spinner = _bulkBusy ? 8.0 + 18.0 : 0.0;
                        final buttonWidth =
                            (constraints.maxWidth - 8 - spinner) / 2;
                        final labelled =
                            _bulkLabelFits(
                              context,
                              l10n.communityMyWorksBulkPublish,
                              buttonWidth,
                            ) &&
                            _bulkLabelFits(
                              context,
                              l10n.communityMyWorksBulkHide,
                              buttonWidth,
                            );
                        void publish() => _applyBulkVisibility(works, true);
                        void hide() => _applyBulkVisibility(works, false);
                        return Row(
                          children: [
                            Expanded(
                              child: labelled
                                  ? FilledButton.icon(
                                      key: const Key(
                                        'communityMyWorksBulkPublish',
                                      ),
                                      onPressed: _bulkBusy ? null : publish,
                                      icon: const Icon(Icons.public),
                                      label: Text(
                                        l10n.communityMyWorksBulkPublish,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    )
                                  : FilledButton(
                                      key: const Key(
                                        'communityMyWorksBulkPublish',
                                      ),
                                      onPressed: _bulkBusy ? null : publish,
                                      child: Tooltip(
                                        message:
                                            l10n.communityMyWorksBulkPublish,
                                        child: const Icon(Icons.public),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: labelled
                                  ? FilledButton.tonalIcon(
                                      key: const Key(
                                        'communityMyWorksBulkHide',
                                      ),
                                      style: hideStyle,
                                      onPressed: _bulkBusy ? null : hide,
                                      icon: const Icon(
                                        Icons.visibility_off_outlined,
                                      ),
                                      label: Text(
                                        l10n.communityMyWorksBulkHide,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    )
                                  : FilledButton.tonal(
                                      key: const Key(
                                        'communityMyWorksBulkHide',
                                      ),
                                      style: hideStyle,
                                      onPressed: _bulkBusy ? null : hide,
                                      child: Tooltip(
                                        message: l10n.communityMyWorksBulkHide,
                                        child: const Icon(
                                          Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                            ),
                            if (_bulkBusy) ...[
                              const SizedBox(width: 8),
                              const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// 選んでいる間の上部バーの題（選んだ件数）。入る幅では「4件選択中」、
/// 入らなければチェックの印と数、それも入らなければ数だけを出す（字は
/// 縮めない）。短い形の全文は吹き出し（長押し・ホバー）と読み上げに残す。
class _SelectionCountTitle extends StatelessWidget {
  const _SelectionCountTitle(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!.homeSelectionCount(count);
    Widget short(Widget child) => Tooltip(
      message: text,
      excludeFromSemantics: true,
      child: Semantics(label: text, excludeSemantics: true, child: child),
    );
    return FirstThatFits(
      children: [
        Text(text, maxLines: 1, softWrap: false),
        short(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_box_outlined),
              const SizedBox(width: 4),
              Text('$count', maxLines: 1, softWrap: false),
            ],
          ),
        ),
        short(Text('$count', maxLines: 1, softWrap: false)),
      ],
    );
  }
}
