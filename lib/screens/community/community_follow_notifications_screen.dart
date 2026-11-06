import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/creator_mission_labels.dart';
import '../../l10n/login_bonus_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/responsive.dart';

/// The plaza bell shows durable, server-owned mission achievements.
/// Existing local follower milestones are retained as an offline fallback.
/// A tap opens the mission claim screen; notifications NEVER mint coins.
class CommunityFollowNotificationsScreen extends StatefulWidget {
  const CommunityFollowNotificationsScreen({super.key});

  @override
  State<CommunityFollowNotificationsScreen> createState() =>
      _CommunityFollowNotificationsScreenState();
}

class _CommunityFollowNotificationsScreenState
    extends State<CommunityFollowNotificationsScreen> {
  String? _accountId;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _feedFuture;
  final List<Map<String, dynamic>> _extra = [];
  String? _nextPage;
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
    final api = context.read<CommunityService>().api;
    if (accountId != _accountId || !identical(api, _api)) {
      _accountId = accountId;
      _api = api;
      _extra.clear();
      _nextPage = null;
      _nextScanCursor = null;
      _scanHasMore = false;
      _feedFuture = accountId != null && api != null ? _loadFirst(api) : null;
    }
  }

  Future<Map<String, dynamic>> _loadFirst(CommunityApi api) async {
    Map<String, dynamic>? sync;
    try {
      sync = await api.syncMyMissionActivity();
    } catch (error) {
      // A failed catch-up scan must never hide previously saved history.
      debugPrint('Mission activity backfill unavailable: $error');
    }
    final result = await api.myMissionActivity();
    return {...result, 'sync': sync};
  }

  void _refresh(CommunityApi api) => setState(() {
    _extra.clear();
    _nextPage = null;
    _scanHasMore = false;
    _nextScanCursor = null;
    _feedFuture = _loadFirst(api);
  });

  Future<void> _more(CommunityApi api) async {
    final cursor = _nextPage;
    if (_loadingMore || cursor == null) return;
    final owner = _accountId;
    setState(() => _loadingMore = true);
    try {
      final data = await api.myMissionActivity(cursor: cursor);
      if (!mounted || owner != _accountId || !identical(api, _api)) return;
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
    setState(() => _scanningMore = true);
    try {
      final sync = await api.syncMyMissionActivity(workCursor: _nextScanCursor);
      final page = await api.myMissionActivity();
      if (!mounted || owner != _accountId || !identical(api, _api)) return;
      setState(() {
        _nextScanCursor = sync['nextWorkCursor'] as String?;
        _scanHasMore = sync['hadMore'] == true;
        _extra.clear();
        _nextPage = page['nextCursor'] as String?;
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
    if (event['kind'] == 'loginMilestone') {
      final days = (event['required'] as num?)?.toInt() ?? 0;
      return LoginBonusLabels.of(
        context,
      )['activityMilestone'].replaceAll('{n}', '$days');
    }
    final name =
        event['workTitle'] is String &&
            (event['workTitle'] as String).isNotEmpty
        ? event['workTitle'] as String
        : t.get('genericPublished');
    final required = event['required'] is num
        ? (event['required'] as num).toInt()
        : 0;
    final each = event['eachWorkBookmarks'] is num
        ? (event['eachWorkBookmarks'] as num).toInt()
        : 0;
    final key = switch (event['kind']) {
      'workPublished' => 'activityPublished',
      'workBookmarks' => 'activityWorkBookmarks',
      'qualifiedWorks' when each == 0 => 'activityWorksPublished',
      'qualifiedWorks' => 'activityWorksBookmarks',
      'followers' => 'activityFollowers',
      _ => 'activityTitle',
    };
    return t
        .get(key)
        .replaceAll('{title}', name)
        .replaceAll('{works}', '$required')
        .replaceAll(
          '{count}',
          event['kind'] == 'qualifiedWorks' ? '$each' : '$required',
        );
  }

  String _date(CreatorMissionLabels t, Map<String, dynamic> event) {
    final raw = event['occurredAt'];
    final date = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    if (date == null) return t.get('reviewing');
    final stamp =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
    return event['dateIsObserved'] == true
        ? '$stamp · ${t.get('activityObserved')}'
        : stamp;
  }

  void _openMissions() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/creator-missions');
  }

  Widget _offlineFallback() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final local = context.watch<CommunityService>().milestoneNotifications;
    if (local.isEmpty) {
      return Center(child: Text(l10n.communityFollowNotificationsEmpty));
    }
    return ListView.separated(
      itemCount: local.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final notification = local[index];
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
            color: scheme.primary,
          ),
          title: Text(message),
          subtitle: Text(
            '${time.year}/${time.month.toString().padLeft(2, '0')}/'
            '${time.day.toString().padLeft(2, '0')}',
          ),
          onTap: _openMissions,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = CreatorMissionLabels.of(context);
    final api = _api;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('activityTitle')),
        actions: [
          if (api != null && _accountId != null)
            IconButton(
              tooltip: t.get('retry'),
              icon: const Icon(Icons.refresh),
              onPressed: () => _refresh(api),
            ),
        ],
      ),
      body: desktopCentered(
        context,
        _accountId == null || api == null
            ? _offlineFallback()
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
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.get('activityError')),
                        OutlinedButton(
                          onPressed: () => _refresh(api),
                          child: Text(t.get('retry')),
                        ),
                        Expanded(child: _offlineFallback()),
                      ],
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
                  if (_nextPage == null && _extra.isEmpty) {
                    _nextPage = page['nextCursor'] as String?;
                  }
                  final items = [
                    ...(page['events'] as List? ?? const [])
                        .whereType<Map>()
                        .map((x) => Map<String, dynamic>.from(x)),
                    ..._extra,
                  ];
                  if (items.isEmpty && !_scanHasMore) {
                    return Center(child: Text(t.get('activityEmpty')));
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
                        'workPublished' => Icons.movie_creation_outlined,
                        'workBookmarks' => Icons.bookmarks_outlined,
                        'qualifiedWorks' => Icons.emoji_events_outlined,
                        'followers' => Icons.people_outline,
                        'loginMilestone' => Icons.calendar_month_outlined,
                        _ => Icons.flag_outlined,
                      };
                      return ListTile(
                        key: ValueKey('missionActivity_${event['eventId']}'),
                        leading: Icon(icon, color: scheme.primary),
                        title: Text(_message(t, event)),
                        subtitle: Text(_date(t, event)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openMissions,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
