import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 「みんなのアニメを見る」機能（動画公開・ランキング機能）が
/// 実装されるまでの仮画面。導線ボタン自体は先行して用意し、機能実装時に
/// この画面をランキング／新着一覧画面へ差し替える。
class CommunityComingSoonScreen extends StatelessWidget {
  const CommunityComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.splashViewCommunityButton)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 64, color: scheme.primary.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text(l10n.communityComingSoonTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon')),
              const SizedBox(height: 8),
              Text(
                l10n.communityComingSoonBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
