import 'package:flutter/material.dart';
import '../../config/accent_text_theme.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/community_service.dart';
import '../../widgets/responsive.dart';

/// Milestones are computed from device-local previous counts. No follower
/// identities or per-person follow events are displayed or stored here.
/// Offline push notifications are not produced by this screen.
class CommunityFollowNotificationsScreen extends StatefulWidget {
  const CommunityFollowNotificationsScreen({super.key});

  @override
  State<CommunityFollowNotificationsScreen> createState() =>
      _CommunityFollowNotificationsScreenState();
}

class _CommunityFollowNotificationsScreenState
    extends State<CommunityFollowNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityService>().markMilestonesRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final notifications = context
        .watch<CommunityService>()
        .milestoneNotifications;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityMilestoneNotificationsTitle)),
      body: desktopCentered(
        context,
        notifications.isEmpty
            ? Center(
                child: Text(
                  l10n.communityFollowNotificationsEmpty,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            : ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final notification = notifications[index];
                  final message = notification.isFollower
                      ? l10n.communityFollowerMilestone(
                          notification.count.toString(),
                        )
                      : l10n.communityBookmarkMilestone(
                          notification.workTitle ?? '',
                          notification.count.toString(),
                        );
                  final time = notification.createdAt;
                  return ListTile(
                    leading: Icon(
                      notification.isFollower
                          ? Icons.people_outline
                          : Icons.bookmarks_outlined,
                      color: AccentTextTheme.of(context),
                    ),
                    title: Text(message),
                    subtitle: Text(
                      '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}',
                    ),
                  );
                },
              ),
      ),
    );
  }
}
