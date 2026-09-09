import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/responsive.dart';
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
    final api = context.read<CommunityService>().api;
    if (api == null || !auth.isSignedIn) {
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
      final works = await api.myWorks();
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
      if (!mounted) return;
      setState(() => _worksError = error);
    } finally {
      if (mounted) setState(() => _loadingWorks = false);
    }
  }

  Future<void> _switchOrAddGoogleAccount() async {
    final auth = context.read<GoogleAuthService>();
    if (!auth.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google認証がまだ設定されていません')));
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Googleアカウントを変更できませんでした: $error')));
    } finally {
      if (mounted) setState(() => _switchingAccount = false);
    }
  }

  Future<void> _handlePostTap() async {
    final auth = context.read<GoogleAuthService>();
    if (!auth.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google認証がまだ設定されていません')));
      return;
    }

    if (!auth.isSignedIn) {
      try {
        await auth.signInInteractively();
        await _reloadOwnerWorks();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Googleログインに失敗しました: $error')));
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

  Future<void> _setVisibility(CommunityWork work, bool published) async {
    final youtubePrivacy = _youtubePrivacyById[work.id];
    if (published && youtubePrivacy == 'deleted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YouTubeから削除された動画はNIARIMで再公開できません')),
      );
      return;
    }

    final api = context.read<CommunityService>().api;
    if (api == null || _visibilityBusy.contains(work.id)) return;
    setState(() => _visibilityBusy.add(work.id));
    try {
      final updated = await api.updateWorkVisibility(
        work.id,
        isNiarimPublished: published,
      );
      if (!mounted) return;
      final next = updated.toCommunityWork();
      setState(() {
        final works = _ownerWorks;
        if (works == null) return;
        final i = works.indexWhere((w) => w.id == next.id);
        if (i >= 0) works[i] = next;
      });
      await context.read<CommunityService>().refreshFromBackend();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('公開状態を変更できませんでした: $error')));
    } finally {
      if (mounted) setState(() => _visibilityBusy.remove(work.id));
    }
  }

  String _visibilityLabel(CommunityWork work) {
    final youtubePrivacy = _youtubePrivacyById[work.id];
    if (youtubePrivacy == 'deleted') {
      return 'YouTubeから削除済み • NIARIMでは再公開できません';
    }
    if (youtubePrivacy == 'private') {
      if (work.isNiarimPublished) {
        return 'NIARIM公開ON • YouTube非公開のため一時非表示';
      }
      return 'NIARIM非公開 • YouTubeも非公開';
    }
    return work.isNiarimPublished ? '公開中' : '非公開';
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
        ? 'Googleアカウント未接続'
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
        title: const Text('自分の投稿'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
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
                                  ? 'Googleアカウントを追加'
                                  : 'Googleアカウントを切り替え・追加',
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
                  content: Text('自分の投稿を読み込めませんでした: $_worksError'),
                  actions: [
                    TextButton(
                      onPressed: _reloadOwnerWorks,
                      child: const Text('再試行'),
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
                                  ? '投稿を読み込んでいます…'
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
                            subtitle: Text(
                              '${_visibilityLabel(work)}  •  videoId: ${work.id}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
