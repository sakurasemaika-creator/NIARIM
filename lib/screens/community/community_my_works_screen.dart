import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/community_work.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/responsive.dart';
import 'widgets/community_work_card.dart';

/// 投稿広場から開く「自分の投稿」専用画面。
///
/// 自分の公開・非公開投稿をまとめて確認しつつ、投稿開始とGoogleアカウントの
/// 追加／切り替えを同じ場所で行えるようにする。GoogleアカウントはNIARIM
/// バックエンド認証とYouTube投稿認可で共通利用するため、ここで切り替えた
/// アカウントが以後の投稿フローにも使われる。
class CommunityMyWorksScreen extends StatefulWidget {
  const CommunityMyWorksScreen({super.key});

  @override
  State<CommunityMyWorksScreen> createState() => _CommunityMyWorksScreenState();
}

class _CommunityMyWorksScreenState extends State<CommunityMyWorksScreen> {
  bool _switchingAccount = false;

  Future<void> _switchOrAddGoogleAccount() async {
    final auth = context.read<GoogleAuthService>();
    if (!auth.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google認証がまだ設定されていません')),
      );
      return;
    }

    setState(() => _switchingAccount = true);
    try {
      // google_sign_in 7.xでは現在のセッションが残っていると同一アカウントが
      // そのまま再利用されることがあるため、明示的な「切り替え・追加」操作
      // では一度サインアウトしてからアカウント選択UIを開く。
      if (auth.isSignedIn) {
        await auth.signOut();
      }
      await auth.signInInteractively();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Googleアカウントを変更できませんでした: $error')),
      );
    } finally {
      if (mounted) setState(() => _switchingAccount = false);
    }
  }

  void _handlePostTap() {
    final l10n = AppLocalizations.of(context)!;
    final hasPosted = context
        .read<CommunityService>()
        .worksByAuthor(kDummySelfAuthorId, includeHidden: true)
        .isNotEmpty;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: hasPosted ? null : const Icon(Icons.info_outline, size: 32),
        title: Text(
          hasPosted
              ? l10n.communityPostComingSoonTitle
              : l10n.communityPostInfoTitle,
        ),
        content: Text(
          hasPosted
              ? l10n.communityPostComingSoonBody
              : l10n.communityPostInfoBody,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final communityService = context.watch<CommunityService>();
    final auth = context.watch<GoogleAuthService>();
    final works = communityService.worksByAuthor(
      kDummySelfAuthorId,
      includeHidden: true,
    )..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    final account = auth.account;
    final accountLabel = account == null
        ? 'Googleアカウント未接続'
        : (account.displayName?.trim().isNotEmpty ?? false)
        ? account.displayName!.trim()
        : account.email;

    return Scaffold(
      appBar: AppBar(title: const Text('自分の投稿')),
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
              child: Text(
                l10n.communityAuthorWorksCount(works.length),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
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
                              l10n.communityEmptyState,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: CommunityWorkGrid(
                        works: works,
                        bookmarkedIds: communityService.bookmarkedIds,
                        onTapWork: (work) => context
                            .read<CommunityPreviewService>()
                            .show(work),
                        onToggleBookmark: (work) =>
                            communityService.toggleBookmark(work.id),
                        bottomPadding: 24,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
