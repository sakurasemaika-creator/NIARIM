import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../config/font_fallback.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/responsive.dart';
import 'community_error_text.dart';
import 'community_author_works_screen.dart';
import 'community_post_screen.dart';
import 'community_work_settings_screen.dart';

/// Owner hub opened from the community square.
///
/// The authenticated backend path is GET /me/works, so switching Google accounts
/// automatically switches the NIARIM owner list without persisting a generated
/// NIARIM author id on-device. Hidden works are included here and can be toggled
/// with PATCH /works/{videoId}; the work id remains the YouTube video id.
class CommunityMyWorksScreen extends StatefulWidget {
  const CommunityMyWorksScreen({super.key});

  @override
  State<CommunityMyWorksScreen> createState() => _CommunityMyWorksScreenState();
}

class _CommunityMyWorksScreenState extends State<CommunityMyWorksScreen> {
  bool _switchingAccount = false;
  bool _loadingWorks = false;
  Object? _worksError;
  List<CommunityWork>? _ownerWorks;
  String? _ownerStateAccountId;
  String? _observedAccountId;
  bool _observingAccount = false;
  int _ownerLoadGeneration = 0;
  Map<String, String> _youtubePrivacyById = const <String, String>{};
  final Set<String> _selectedIds = <String>{};
  bool _selectionMode = false;
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadOwnerWorks());
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
    _youtubePrivacyById = const <String, String>{};
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
    if (api == null || !auth.isSignedIn) {
      community.forgetOwner();
      setState(() {
        _ownerStateAccountId = null;
        _ownerWorks = null;
        _youtubePrivacyById = const <String, String>{};
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
      final works = page.works;
      final converted = works.map((w) => w.toCommunityWork()).toList()
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
      final privacy = <String, String>{
        for (final work in works)
          if (work.youtubePrivacyStatus != null)
            work.workId: work.youtubePrivacyStatus!,
      };
      if (!mounted) return;
      setState(() {
        _ownerWorks = converted;
        _youtubePrivacyById = privacy;
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
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide.none,
        ),
        elevation: 0,
      ),
    );
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
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton.icon(
                key: const Key('communityGoogleSignInPromptConnect'),
                onPressed: auth.isConfigured
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(l10n.communitySignInPromptConnect),
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

    setState(() => _switchingAccount = true);
    try {
      // Force account chooser instead of silently reusing the current session.
      if (auth.isSignedIn) await auth.signOut();
      if (mounted) {
        setState(() {
          _ownerWorks = null;
          _youtubePrivacyById = const <String, String>{};
          _worksError = null;
        });
      }
      await auth.signInInteractively();
      await _reloadOwnerWorks();
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

  Future<void> _handlePostTap() async {
    final auth = context.read<GoogleAuthService>();
    final l10n = AppLocalizations.of(context)!;
    if (!auth.isSignedIn) {
      if (!await _confirmGoogleSignIn() || !mounted) return;
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
    setState(() {
      if (deleted == true) {
        _ownerWorks?.removeWhere((item) => item.id == work.id);
        _youtubePrivacyById = Map.of(_youtubePrivacyById)..remove(work.id);
        _selectedIds.remove(work.id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      }
    });
  }

  /// Sequential, idempotent visibility updates: a partial failure remains
  /// selected for retry. Never bulk-delete or bulk-update the AI declaration.
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
    if (youtubePrivacy == 'private') return Icons.lock_outline;
    return work.isNiarimPublished
        ? Icons.public
        : Icons.visibility_off_outlined;
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
    final works = usingBackendOwnerList
        ? [
            for (final w
                in (hasCurrentOwnerState ? _ownerWorks : null) ??
                    const <CommunityWork>[])
              communityService.byId(w.id) ?? w,
          ]
        : (communityService.worksByAuthor(
            kDummySelfAuthorId,
            includeHidden: true,
          )..sort((a, b) => b.postedAt.compareTo(a.postedAt)));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? l10n.homeSelectionCount(_selectedIds.length)
              : l10n.communityMyWorksTitle,
        ),
        actions: [
          IconButton(
            tooltip: l10n.communityReloadTooltip,
            onPressed: _loadingWorks ? null : _reloadOwnerWorks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              account == null
                                  ? Icons.person_outline
                                  : Icons.account_circle,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    account.email != accountLabel) ...[
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
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            key: const Key('communityMyWorksPostButton'),
                            onPressed: _handlePostTap,
                            icon: const Icon(Icons.video_call_outlined),
                            label: Text(l10n.communityPostButton),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('communityMyWorksViewAuthorPage'),
                            onPressed: () => _openOwnAuthorPage(works),
                            icon: const Icon(Icons.collections_outlined),
                            label: Text(l10n.communityMyWorksViewAuthorPage),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('communityMyWorksAccountButton'),
                            onPressed: _switchingAccount
                                ? null
                                : _switchOrAddGoogleAccount,
                            icon: _switchingAccount
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.manage_accounts_outlined),
                            label: Text(
                              account == null
                                  ? l10n.communityMyWorksAddAccount
                                  : l10n.communityMyWorksSwitchAccount,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.communityMyWorksManagementHeading,
                key: const Key('communityMyWorksManagementHeading'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
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
            Expanded(
              child: works.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 56,
                              color: scheme.primary.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              usingBackendOwnerList && _loadingWorks
                                  ? l10n.communityMyWorksLoading
                                  : l10n.communityEmptyState,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        _selectionMode ? 126 : 24,
                      ),
                      itemCount: works.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final work = works[index];
                        final youtubePrivacy = _youtubePrivacyById[work.id];
                        final deleted = youtubePrivacy == 'deleted';
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            key: ValueKey('communityMyWorksRow-${work.id}'),
                            onLongPress: () {
                              if (!_selectionMode) {
                                setState(() {
                                  _selectionMode = true;
                                  _selectedIds.add(work.id);
                                });
                              } else {
                                _toggleSelected(work.id);
                              }
                            },
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelected(work.id);
                              } else {
                                context.read<CommunityPreviewService>().show(
                                  work,
                                );
                              }
                            },
                            selected: _selectedIds.contains(work.id),
                            leading: _selectionMode
                                ? Checkbox(
                                    key: ValueKey(
                                      'communityMyWorksSelect-${work.id}',
                                    ),
                                    value: _selectedIds.contains(work.id),
                                    onChanged: _bulkBusy
                                        ? null
                                        : (_) => _toggleSelected(work.id),
                                  )
                                : CircleAvatar(
                                    backgroundColor:
                                        work.isNiarimPublished && !deleted
                                        ? scheme.primaryContainer
                                        : scheme.surfaceContainerHighest,
                                    child: Icon(_visibilityIcon(work)),
                                  ),
                            title: Text(
                              work.title.isEmpty ? work.id : work.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_visibilityLabel(l10n, work)}  •  '
                              '${l10n.communityYoutubeVideoIdLabel(work.id)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _selectionMode
                                ? null
                                : IconButton(
                                    key: ValueKey(
                                      'communityMyWorksSettings-${work.id}',
                                    ),
                                    tooltip: l10n.communityMyWorksSettingsTitle,
                                    onPressed: () => _openWorkSettings(work),
                                    icon: const Icon(Icons.build_outlined),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
                  elevation: 0,
                  borderRadius: BorderRadius.circular(18),
                  color: scheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('communityMyWorksBulkPublish'),
                            onPressed: _bulkBusy
                                ? null
                                : () => _applyBulkVisibility(works, true),
                            icon: const Icon(Icons.public),
                            label: Text(l10n.communityMyWorksBulkPublish),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const Key('communityMyWorksBulkHide'),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.onPrimaryContainer,
                              side: BorderSide.none,
                            ),
                            onPressed: _bulkBusy
                                ? null
                                : () => _applyBulkVisibility(works, false),
                            icon: const Icon(Icons.visibility_off_outlined),
                            label: Text(l10n.communityMyWorksBulkHide),
                          ),
                        ),
                        if (_bulkBusy) ...[
                          const SizedBox(width: 8),
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
