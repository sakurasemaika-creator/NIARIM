import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/accent_text_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/creator_mission_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/community_notice.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/responsive.dart';
import '../../widgets/fit_or_hide_title.dart';

/// Shows the plaza activity history and mission achievements.
class CommunityFollowNotificationsScreen extends StatefulWidget {
  const CommunityFollowNotificationsScreen({super.key});

  @override
  State<CommunityFollowNotificationsScreen> createState() =>
      _CommunityFollowNotificationsScreenState();
}

class _CommunityFollowNotificationsScreenState
    extends State<CommunityFollowNotificationsScreen> {
  String? _accountId;
  String? _ownerId;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _feedFuture;
  final List<Map<String, dynamic>> _extra = [];
  String? _nextPage;
  bool _pageInitialized = false;
  String? _nextScanCursor;
  bool _scanHasMore = false;
  bool _loadingMore = false;
  bool _scanningMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityService>().markMilestonesRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accountId = context.watch<GoogleAuthService>().account?.id;
    final community = context.watch<CommunityService>();
    final api = community.api;
    final ownerId = accountId == null ? null : community.currentUserId;
    if (accountId != _accountId ||
        ownerId != _ownerId ||
        !identical(api, _api)) {
      _accountId = accountId;
      _ownerId = ownerId;
      _api = api;
      _extra.clear();
      _nextPage = null;
      _pageInitialized = false;
      _nextScanCursor = null;
      _scanHasMore = false;
      _feedFuture = accountId != null && api != null ? _loadFirst(api) : null;
    }
  }

  Future<Map<String, dynamic>> _loadFirst(CommunityApi api) async {
    final owner = _ownerId;
    Map<String, dynamic>? sync;
    try {
      sync = await api.syncMyMissionActivity();
    } catch (error) {
      // A failed catch-up scan must never hide previously saved history.
      debugPrint('Mission activity backfill unavailable: $error');
    }
    final result = await _loadPage(api, owner);
    return {...result, 'sync': sync};
  }

  Future<Map<String, dynamic>> _loadPage(
    CommunityApi api,
    String? owner, {
    String? cursor,
  }) async {
    final page = await api.myMissionActivity(
      cursor: cursor,
      includeCommunity: true,
    );
    final responseOwner = page['noticeOwner'];
    if (responseOwner != null && owner != null && responseOwner != owner) {
      return {'events': const []};
    }
    return page;
  }

  void _refresh(CommunityApi api) => setState(() {
    _extra.clear();
    _nextPage = null;
    _pageInitialized = false;
    _scanHasMore = false;
    _nextScanCursor = null;
    _feedFuture = _loadFirst(api);
  });

  Future<void> _more(CommunityApi api) async {
    final cursor = _nextPage;
    if (_loadingMore || cursor == null) return;
    final owner = _accountId;
    final noticeOwner = _ownerId;
    setState(() => _loadingMore = true);
    try {
      final data = await _loadPage(api, noticeOwner, cursor: cursor);
      if (!mounted ||
          owner != _accountId ||
          noticeOwner != _ownerId ||
          !identical(api, _api)) {
        return;
      }
      setState(() {
        _extra.addAll(
          (data['events'] as List? ?? const []).whereType<Map>().map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
        );
        _nextPage = data['nextCursor'] as String?;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              CreatorMissionLabels.of(context).get('activityError'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _scanMore(CommunityApi api) async {
    if (_scanningMore) return;
    final owner = _accountId;
    final noticeOwner = _ownerId;
    setState(() => _scanningMore = true);
    try {
      final sync = await api.syncMyMissionActivity(workCursor: _nextScanCursor);
      final page = await _loadPage(api, noticeOwner);
      if (!mounted ||
          owner != _accountId ||
          noticeOwner != _ownerId ||
          !identical(api, _api)) {
        return;
      }
      setState(() {
        _nextScanCursor = sync['nextWorkCursor'] as String?;
        _scanHasMore = sync['hadMore'] == true;
        _extra.clear();
        _nextPage = page['nextCursor'] as String?;
        _pageInitialized = true;
        _feedFuture = Future.value({...page, 'sync': sync});
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              CreatorMissionLabels.of(context).get('activityError'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningMore = false);
    }
  }

  String _message(CreatorMissionLabels t, Map<String, dynamic> event) {
    final l10n = AppLocalizations.of(context)!;
    final community = communityNoticeText(l10n, event['kind']);
    if (community != null) return community;
    final required = event['required'] is num
        ? (event['required'] as num).toInt()
        : 0;
    if (event['kind'] == 'loginMilestone') {
      return l10n.loginBonusActivityMilestone(required);
    }
    final name =
        event['workTitle'] is String &&
            (event['workTitle'] as String).isNotEmpty
        ? event['workTitle'] as String
        : t.get('genericPublished');
    final each = event['eachWorkBookmarks'] is num
        ? (event['eachWorkBookmarks'] as num).toInt()
        : 0;
    return switch (event['kind']) {
      'workPublished' => l10n.creatorMissionActivityPublished(name),
      'workBookmarks' => l10n.creatorMissionActivityWorkBookmarks(
        name,
        required,
      ),
      'workReposts' => l10n.creatorMissionActivityWorkReposts(name, required),
      'qualifiedWorks' when each == 0 =>
        l10n.creatorMissionActivityWorksPublished(required),
      'qualifiedWorks' => l10n.creatorMissionActivityWorksBookmarks(
        required,
        each,
      ),
      'followers' => l10n.creatorMissionActivityFollowers(required),
      _ => t.get('activityTitle'),
    };
  }

  /// 端末の現地時刻を表示言語の書き方で表示する。
  String _dateText(DateTime date) => DateFormat.yMd(
    AppLocalizations.of(context)!.localeName,
  ).add_jm().format(date);

  String _date(CreatorMissionLabels t, Map<String, dynamic> event) {
    final raw = event['occurredAt'];
    final date = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    if (date == null) return t.get('reviewing');
    final stamp = _dateText(date);
    return event['dateIsObserved'] == true
        ? '$stamp · ${t.get('activityObserved')}'
        : stamp;
  }

  void _openMissions() {
    context.push('/creator-missions');
  }

  Widget _noticeWithLocalHistory({required String message, Widget? action}) {
    final l10n = AppLocalizations.of(context)!;
    final local = context.watch<CommunityService>().milestoneNotifications;
    final notice = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 通知がまだ1つも無いときは、ほかの空の表示と同じ「中身の
          // まだ無いコマ」の印を出す（文とボタンだけが浮いていた）。
          if (local.isEmpty) ...[
            const EmptyFrameMark(icon: Icons.notifications_none_outlined),
            const SizedBox(height: 16),
          ],
          messageText(
            message,
            textAlign: TextAlign.center,
            keepLastPhrase: true,
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
    if (local.isEmpty) {
      return Center(child: SingleChildScrollView(child: notice));
    }
    return ListView.separated(
      itemCount: local.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        if (index == 0) return notice;
        final notification = local[index - 1];
        final message = notification.isFollower
            ? l10n.communityFollowerMilestone(notification.count.toString())
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(message),
          subtitle: Text(_dateText(time)),
          onTap: _openMissions,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = CreatorMissionLabels.of(context);
    final api = _api;
    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(t.get('activityTitle')),
        actions: [
          if (api != null && _accountId != null)
            IconButton(
              tooltip: t.get('retry'),
              icon: const Icon(Icons.refresh),
              onPressed: () => _refresh(api),
            ),
          IconButton(
            key: const Key('plazaNotificationSettings'),
            tooltip: devicePushLabel(AppLocalizations.of(context)!),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(communityNotificationSettingsRoute),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        _accountId == null
            ? _noticeWithLocalHistory(
                message: l10n.communityFollowNotificationsSignInRequired,
                action: FilledButton(
                  onPressed: () => context.push(communityMyWorksRoute),
                  child: Text(l10n.communitySignInPromptConnect),
                ),
              )
            : api == null
            ? _noticeWithLocalHistory(message: t.get('activityError'))
            : FutureBuilder<Map<String, dynamic>>(
                future: _feedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: Semantics(
                        label: t.get('loading'),
                        child: const CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.hasError) {
                    return _noticeWithLocalHistory(
                      message: t.get('activityError'),
                      action: OutlinedButton(
                        onPressed: () => _refresh(api),
                        child: Text(t.get('retry')),
                      ),
                    );
                  }
                  final page = snapshot.data!;
                  final sync = page['sync'] as Map<String, dynamic>?;
                  if (sync != null &&
                      !_scanHasMore &&
                      _nextScanCursor == null) {
                    _scanHasMore = sync['hadMore'] == true;
                    _nextScanCursor = sync['nextWorkCursor'] as String?;
                  }
                  if (!_pageInitialized) {
                    _nextPage = page['nextCursor'] as String?;
                    _pageInitialized = true;
                  }
                  final items = [
                    ...(page['events'] as List? ?? const [])
                        .whereType<Map>()
                        .map((x) => Map<String, dynamic>.from(x)),
                    ..._extra,
                  ];
                  if (items.isEmpty && !_scanHasMore && _nextPage == null) {
                    return Center(
                      child: Text(l10n.communityFollowNotificationsEmpty),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:
                        items.length +
                        (_nextPage != null ? 1 : 0) +
                        (_scanHasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
                        if (_nextPage != null && index == items.length) {
                          return TextButton.icon(
                            onPressed: _loadingMore ? null : () => _more(api),
                            icon: const Icon(Icons.expand_more),
                            label: Text(t.get('activityHistoryMore')),
                          );
                        }
                        return OutlinedButton.icon(
                          onPressed: _scanningMore
                              ? null
                              : () => _scanMore(api),
                          icon: const Icon(Icons.refresh),
                          label: Text(t.get('activitySyncMore')),
                        );
                      }
                      final event = items[index];
                      final icon = switch (event['kind']) {
                        'scheduledRelease' => Icons.schedule_outlined,
                        'workPosted' ||
                        'workPublicationConfirmed' ||
                        'workPublished' => Icons.movie_creation_outlined,
                        'workBookmarks' => Icons.bookmarks_outlined,
                        'workReposts' => Icons.repeat,
                        'qualifiedWorks' => Icons.emoji_events_outlined,
                        'followers' => Icons.people_outline,
                        'loginMilestone' => Icons.calendar_month_outlined,
                        _ => Icons.flag_outlined,
                      };
                      final route = notificationRoute(event['targetRoute']);
                      final canOpen =
                          route != null && route != communityNotificationsRoute;
                      return ListTile(
                        key: ValueKey('missionActivity_${event['eventId']}'),
                        leading: Icon(icon, color: AccentTextTheme.of(context)),
                        title: Text(_message(t, event)),
                        subtitle: Text(_date(t, event)),
                        trailing: canOpen
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: canOpen ? () => context.push(route) : null,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
