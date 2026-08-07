import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// どの画面からでもヘルプページ（検索・アコーディオンで機能の使い方を
/// 確認できる画面）を開けるようにする「？」アイコン。各画面のAppBarへ
/// 追加して使う。
class HelpButton extends StatelessWidget {
  const HelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'ヘルプ',
      onPressed: () => context.push('/help'),
    );
  }
}
