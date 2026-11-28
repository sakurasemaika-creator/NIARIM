import 'package:flutter/material.dart';

import '../../utils/app_locale.dart';
import '../../widgets/keep_together_text.dart';
import '../community/google_account_connect.dart';

/// ログインしていないときに出す「Googleアカウントを連携」（オパール・
/// ミッション・契約状態の画面、作品広場の通知の画面）。押すと、その画面の
/// ままGoogleアカウントでログインする（[connectGoogleAccount]）。以前は
/// 「自分の投稿」の画面へ移るだけで、そこの「Googleアカウントを追加」を
/// もう一度押す必要があり、押したボタンの名前と行き先が食い違っていた。
/// ログインの途中は押せない。
///
/// [filled]なら塗りのボタン（その画面でいちばんの操作のとき）、そうでなければ
/// 枠のボタン（ほかに主な操作がある画面）。
class RewardsSignInButton extends StatefulWidget {
  const RewardsSignInButton({super.key, this.filled = true});

  final bool filled;

  @override
  State<RewardsSignInButton> createState() => _RewardsSignInButtonState();
}

class _RewardsSignInButtonState extends State<RewardsSignInButton> {
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      await connectGoogleAccount(context);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    final onPressed = _connecting ? null : _connect;
    const icon = Icon(Icons.account_circle_outlined);
    final label = messageText(
      l10n.communitySignInPromptConnect,
      textAlign: TextAlign.center,
    );
    return widget.filled
        ? FilledButton.icon(
            key: const Key('rewardsSignInButton'),
            onPressed: onPressed,
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            key: const Key('rewardsSignInButton'),
            onPressed: onPressed,
            icon: icon,
            label: label,
          );
  }
}
