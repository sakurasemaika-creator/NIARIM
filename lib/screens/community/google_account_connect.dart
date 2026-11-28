import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/legal_consent.dart';
import '../rewards/opal_gifts.dart';
import 'community_error_text.dart';

/// Googleアカウントでログインする前の、NIARIMの説明のダイアログ（ログイン
/// で何ができるか。この端末でログインを使えないときはその理由）。「Google
/// アカウントを連携」を押したら真。作品広場を見るだけ・「自分の投稿」を
/// 開くだけでは出さない。
Future<bool> confirmGoogleSignIn(BuildContext context) async {
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
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
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

/// 「Googleアカウントを連携」を押した画面のまま、Googleアカウントでログイン
/// する（オパール・ミッション・作品広場の通知など、ログインしていないときに
/// 出すボタン）。以前は「自分の投稿」の画面へ移るだけで、そこで「Google
/// アカウントを追加」をもう一度押す必要があった。ログインすると、押した画面が
/// アカウントの変化を受けて中身を読み直す。
///
/// この端末でログインを使えないときは、その理由の説明（[confirmGoogleSignIn]）
/// を出す。ほかのアカウントの操作の途中・失敗は知らせる。
Future<void> connectGoogleAccount(BuildContext context) async {
  final auth = context.read<GoogleAuthService>();
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!auth.isConfigured) {
    await confirmGoogleSignIn(context);
    return;
  }
  if (auth.authOperationInProgress) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.communityGoogleAccountBusy)),
    );
    return;
  }
  if (!await ensureLegalConsent(context) || !context.mounted) return;
  try {
    await auth.signInInteractively();
    // 作ったばかりのNIARIMのアカウントには、クーポンの入力を1度だけ案内する
    // （「自分の投稿」からログインしたときと同じ）。
    if (context.mounted) await maybeOfferOpalCouponAfterSignIn(context);
  } catch (error) {
    debugPrint('Google sign-in failed: $error');
    if (!context.mounted) return;
    final reason = auth.authOperationInProgress
        ? l10n.communityGoogleAccountBusy
        : communityErrorText(l10n, error);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.communitySignInFailed(reason))),
    );
  }
}
