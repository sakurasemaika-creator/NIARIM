import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/creator_mission_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/project_service.dart';
import '../../widgets/responsive.dart';

/// Mission overview. Reading status is safe; coin claims are disabled pending
/// production anti-fraud. Local work time is explicitly a non-reward reference.
class CreatorMissionsScreen extends StatefulWidget {
  const CreatorMissionsScreen({super.key});

  @override
  State<CreatorMissionsScreen> createState() => _CreatorMissionsScreenState();
}

class _CreatorMissionsScreenState extends State<CreatorMissionsScreen> {
  String? _accountId;
  CommunityApi? _lastApi;
  Future<Map<String, dynamic>>? _statusFuture;

  void _refresh(CommunityApi client) {
    setState(() => _statusFuture = client.myCreatorMissions());
  }

  String _missionName(CreatorMissionLabels t, Map<String, dynamic> mission) {
    final required = (mission['required'] as num?)?.toInt() ?? 0;
    return switch (mission['kind']) {
      'verifiedEditSeconds' =>
        t.format('time', required ~/ 3600),
      'workBookmarks' =>
        t.format('work', required),
      'qualifiedWorks' =>
        t.format('works', required,
            each: (mission['eachWorkBookmarks'] as num?)?.toInt() ?? 0),
      'followers' =>
        t.format('followers', required),
      'niarimBookmarkRanking' =>
        t.format('rank', required),
      _ => mission['id'] as String? ?? '?',
    };
  }

  Widget _missionTile(BuildContext context, CreatorMissionLabels t,
      Map<String, dynamic> mission) {
    final theme = Theme.of(context);
    final claimed = mission['claimed'] == true;
    final pending = mission['pendingSince'] is num && !claimed;
    final status = claimed ? t.get('claimed')
        : pending ? t.get('pending') : t.get('notClaimed');
    final reward = (mission['coins'] as num?)?.toInt() ?? 0;
    return Card(
      child: ListTile(
        title: Text(_missionName(t, mission)),
        subtitle: Text(status),
        leading: Icon(claimed
            ? Icons.check_circle_outline
            : pending ? Icons.hourglass_empty : Icons.flag_outlined,
            color: claimed
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant),
        trailing: Text('+$reward ${t.get('coin')}',
            style: theme.textTheme.titleSmall),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = CreatorMissionLabels.of(context);
    final accountId = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    final localSeconds = context.watch<ProjectService>().projects
        .where((project) => !project.isSharedImport)
        .fold<int>(0, (sum, project) => sum + project.totalWorkSeconds);
    // Cache the future by authenticated account; never refetch on every
    // build or timer tick. Switching Google accounts invalidates old results.
    if (_accountId != accountId || !identical(_lastApi, api)) {
      _accountId = accountId;
      _lastApi = api;
      _statusFuture = accountId != null && api != null
          ? api.myCreatorMissions() : null;
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.get('title'))),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.get('subtitle'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(t.get('budget')),
          const SizedBox(height: 12),
          Text(t.format('localTime', localSeconds ~/ 3600)),
          Text(t.get('timeWarning'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(t.get('rankingWarning'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (accountId == null)
            Text(t.get('login'))
          else if (api == null)
            Text(t.get('offline'))
          else
            FutureBuilder<Map<String, dynamic>>(
              future: _statusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Semantics(
                      label: t.get('loading'),
                      child: const CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    children: [
                      Text(t.get('loadError')),
                      OutlinedButton(
                        onPressed: () => _refresh(api),
                        child: Text(t.get('retry')),
                      ),
                    ],
                  );
                }
                final info = snapshot.data!;
                final rows = (info['missions'] as List? ?? const [])
                    .whereType<Map>()
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (info['enabled'] != true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(t.get('upcoming')),
                      ),
                    for (final mission in rows)
                      _missionTile(context, t, mission),
                    TextButton(
                      onPressed: () => _refresh(api),
                      child: Text(t.get('retry')),
                    ),
                  ],
                );
              },
            ),
        ],
      )),
    );
  }
}
