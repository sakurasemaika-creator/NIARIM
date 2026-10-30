import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

/// ゴミ箱へ移した・消した作品や、古いリンク・存在しないIDから開いたときの
/// 画面。戻る先が無くてもプロジェクトの一覧へ戻れるようにする。
class ProjectNotFoundView extends StatelessWidget {
  const ProjectNotFoundView({super.key, this.homeButtonKey});

  /// 「プロジェクトの一覧へ」のボタンのKey（画面ごとのテスト用）。
  final Key? homeButtonKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectDetailNotFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.projectDetailNotFoundBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: homeButtonKey,
                onPressed: () => context.go('/home'),
                child: Text(l10n.projectDetailNotFoundBackToList),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
