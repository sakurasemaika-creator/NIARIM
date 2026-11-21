import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/api/community_api.dart';

/// Standalone, themed, localized alternative to a raw YouTube playback error.
/// Works inside the floating preview, detail view and future embedded player.
class CommunityPlaybackStatusView extends StatelessWidget {
  const CommunityPlaybackStatusView({
    super.key,
    required this.status,
    this.onRetry,
  });

  final CommunityPlaybackStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // Never claim that a public API absence proves deletion.
    final (title, description) = switch (status) {
      CommunityPlaybackStatus.deleted => (
        l10n.communityPlaybackDeletedTitle,
        l10n.communityPlaybackDeletedBody,
      ),
      CommunityPlaybackStatus.private => (
        l10n.communityPlaybackPrivateTitle,
        l10n.communityPlaybackPrivateBody,
      ),
      CommunityPlaybackStatus.unavailable => (
        l10n.communityPlaybackUnavailableTitle,
        l10n.communityPlaybackUnavailableBody,
      ),
      CommunityPlaybackStatus.unknown => (
        l10n.communityPlaybackUnknownTitle,
        l10n.communityPlaybackUnknownBody,
      ),
      CommunityPlaybackStatus.checking || CommunityPlaybackStatus.available => (
        l10n.communityPlaybackCheckingTitle,
        l10n.communityPlaybackCheckingBody,
      ),
    };
    final icon = switch (status) {
      CommunityPlaybackStatus.deleted => Icons.delete_outline,
      CommunityPlaybackStatus.private => Icons.lock_outline,
      CommunityPlaybackStatus.unavailable => Icons.visibility_off_outlined,
      CommunityPlaybackStatus.unknown => Icons.cloud_off_outlined,
      CommunityPlaybackStatus.checking => Icons.hourglass_top_rounded,
      CommunityPlaybackStatus.available => Icons.play_circle_outline,
    };

    return Container(
      key: const Key('communityPlaybackStatusPanel'),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == CommunityPlaybackStatus.checking)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: scheme.primary,
                  ),
                )
              else
                Icon(icon, size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                title,
                key: const Key('communityPlaybackStatusTitle'),
                maxLines: 3,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 4,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (onRetry != null &&
                  status != CommunityPlaybackStatus.checking) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('communityPlaybackRetry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.communityPlaybackRecheck),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
