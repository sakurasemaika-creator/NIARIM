import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/responsive.dart';
import 'community_error_text.dart';
import 'community_post_screen.dart';

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
  Map<String, String> _youtubePrivacyById = const <String, String>{};
  final Set<String> _visibilityBusy = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadOwnerWorks());
  }

  Future<void> _reloadOwnerWorks() async {
    if (!mounted) return;
    final auth = context.read<GoogleAuthService>();
    final community = context.read<CommunityService>();
    final api = community.api;
    if (api == null || !auth.isSignedIn) {
      community.forgetOwner();
      setState(() {
        _ownerWorks = null;
        _youtubePrivacyById = const <String, String>{};
        _worksError = null;
        _loadingWorks = false;
      });
      return;
    }

    setState(() {
      _loadingWorks = true;
      _worksError = null;
    });
    try {
      // Also tells the service who the poster is and keeps their works,
      // hidden ones included, in its store.
      final page = (await community.loadOwnWorks())!;
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
      });
    } catch (error) {
      debugPrint('Own works could not be loaded: $error');
      if (!mounted) return;
      setState(() => _worksError = error);
    } finally {
      if (mounted) setState(() => _loadingWorks = false);
    }
  }

  void _showSnackBar(String message) {
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

  Future<void> _switchOrAddGoogleAccount() async {
    final auth = context.read<GoogleAuthService>();
    final l10n = AppLocalizations.of(context)!;
    if (!auth.isConfigured) {
      _showSnackBar(l10n.communityGoogleSignInNotConfigured);
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
    if (!auth.isConfigured) {
      _showSnackBar(l10n.communityGoogleSignInNotConfigured);
      return;
    }

    if (!auth.isSignedIn) {
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

  Future<void> _setAiImageVideoDisclosure(
    CommunityWork work,
    bool value,
  ) async {
    if (_visibilityBusy.contains(work.id)) return;
    final community = context.read<CommunityService>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _visibilityBusy.add(work.id));
    try {
      // The service applies the server's reply, so every browsing surface
      // reflects it at once.
      final next = await community.setAiImageVideoDisclosure(work.id, value);
      if (!mounted) return;
      setState(() {
        final works = _ownerWorks;
        if (works == null) return;
        final i = works.indexWhere((w) => w.id == next.id);
        if (i >= 0) works[i] = next;
      });
    } catch (error) {
      debugPrint('AI image/video disclosure update failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.communityAiImageVideoUpdateFailed)),
      );
    } finally {
      if (mounted) setState(() => _visibilityBusy.remove(work.id));
    }
  }

  Future<void> _setVisibility(CommunityWork work, bool published) async {
    final l10n = AppLocalizations.of(context)!;
    final youtubePrivacy = _youtubePrivacyById[work.id];
    if (published && youtubePrivacy == 'deleted') {
      _showSnackBar(l10n.communityMyWorksDeletedCannotPublish);
      return;
    }

    final community = context.read<CommunityService>();
    if (community.api == null || _visibilityBusy.contains(work.id)) return;
    setState(() => _visibilityBusy.add(work.id));
    try {
      // The service applies the reply, so every surface follows at once.
      final next = await community.setNiarimVisibility(work.id, published);
      if (!mounted) return;
      setState(() {
        final works = _ownerWorks;
        if (works == null) return;
        final i = works.indexWhere((w) => w.id == next.id);
        if (i >= 0) works[i] = next;
      });
    } catch (error) {
      debugPrint('Visibility update failed: $error');
      if (!mounted) return;
      _showSnackBar(
        l10n.communityVisibilityChangeFailed(communityErrorText(l10n, error)),
      );
    } finally {
      if (mounted) setState(() => _visibilityBusy.remove(work.id));
    }
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
    final works = usingBackendOwnerList
        ? (_ownerWorks ?? const <CommunityWork>[])
        : (communityService.worksByAuthor(
            kDummySelfAuthorId,
            includeHidden: true,
          )..sort((a, b) => b.postedAt.compareTo(a.postedAt)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.communityMyWorksTitle),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            key: const Key('communityMyWorksPostButton'),
                            onPressed: _handlePostTap,
                            icon: const Icon(Icons.video_call_outlined),
                            label: Text(l10n.communityPostButton),
                          ),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Text(
                    l10n.communityAuthorWorksCount(works.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
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
                ],
              ),
            ),
            if (_worksError != null && usingBackendOwnerList)
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: works.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final work = works[index];
                        final busy = _visibilityBusy.contains(work.id);
                        final youtubePrivacy = _youtubePrivacyById[work.id];
                        final deleted = youtubePrivacy == 'deleted';
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () => context
                                .read<CommunityPreviewService>()
                                .show(work),
                            leading: CircleAvatar(
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
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_visibilityLabel(l10n, work)}  •  '
                                  '${l10n.communityYoutubeVideoIdLabel(work.id)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (usingBackendOwnerList ||
                                    communityService.api == null)
                                  CheckboxListTile(
                                    key: ValueKey(
                                      'communityMyWorksAi-${work.id}',
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value:
                                        work.containsGenerativeAiImageOrVideo,
                                    onChanged: busy
                                        ? null
                                        : (v) => _setAiImageVideoDisclosure(
                                            work,
                                            v ?? false,
                                          ),
                                    title: Text(
                                      l10n.communityContainsGenerativeAiImageVideo,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: usingBackendOwnerList
                                ? SizedBox(
                                    width: 58,
                                    child: busy
                                        ? const Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : Switch.adaptive(
                                            value: work.isNiarimPublished,
                                            onChanged:
                                                deleted &&
                                                    !work.isNiarimPublished
                                                ? null
                                                : (v) =>
                                                      _setVisibility(work, v),
                                          ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
