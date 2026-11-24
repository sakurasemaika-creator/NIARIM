import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/community_notice.dart';
import '../../utils/app_locale.dart';
import '../../widgets/keep_together_text.dart';

/// オパール・ミッション・契約状態の画面で、ログインしていないときに出す
/// 「Googleアカウントを連携」。押すと、作品広場の通知の画面と同じく、
/// 連携の操作がある「自分の投稿」の画面へ移る（以前は「ログインすると
/// 確認できます」の文だけで、どこでログインするのかが分からなかった）。
///
/// [filled]なら塗りのボタン（その画面でいちばんの操作のとき）、そうでなければ
/// 枠のボタン（ほかに主な操作がある画面）。
class RewardsSignInButton extends StatelessWidget {
  const RewardsSignInButton({super.key, this.filled = true});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    void open() => context.push(communityMyWorksRoute);
    const icon = Icon(Icons.account_circle_outlined);
    final label = messageText(
      l10n.communitySignInPromptConnect,
      textAlign: TextAlign.center,
    );
    return filled
        ? FilledButton.icon(
            key: const Key('rewardsSignInButton'),
            onPressed: open,
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            key: const Key('rewardsSignInButton'),
            onPressed: open,
            icon: icon,
            label: label,
          );
  }
}
