import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/creator_mission_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/project_service.dart';
import '../../widgets/responsive.dart';

/// A button is permitted only for an achieved, unclaimed and server-approved
/// mission. This client policy is advisory; the atomic backend check is final.
bool missionClaimActionAllowed({
  required bool eligible, required bool ready,
  required bool claimed, required bool enabled,
}) => eligible && ready && !claimed && enabled;

/// The GET endpoints never mint coins. A user must explicitly tap Claim.
/// The server remembers account-wide and per-work claimed bits durably.
class CreatorMissionsScreen extends StatefulWidget {
  const CreatorMissionsScreen({super.key, this.workId});
  final String? workId;
  @override
  State<CreatorMissionsScreen> createState() => _CreatorMissionsScreenState();
}

class _CreatorMissionsScreenState extends State<CreatorMissionsScreen> {
  String? _owner;
  String? _work;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _accountFuture;
  Future<Map<String, dynamic>>? _workFuture;
  final List<Map<String, dynamic>> _extraWorks = [];
  final Set<String> _claimBusy = {};
  String? _nextCursor;
  bool _nextLoaded = false;
  bool _moreBusy = false;

  void _reset(CommunityApi api) {
    _accountFuture = api.myCreatorMissions(workId: widget.workId);
    _workFuture = widget.workId == null ? api.myWorkMissionAchievements() : null;
    _extraWorks.clear();
    _nextCursor = null;
    _nextLoaded = false;
  }

  void _refresh(CommunityApi api) => setState(() => _reset(api));

  String _missionName(CreatorMissionLabels t, Map<String, dynamic> row) {
    final n = (row['required'] as num?)?.toInt() ?? 0;
    return switch (row['kind']) {
      'verifiedEditSeconds' => t.format('time', n ~/ 3600),
      'workBookmarks' => t.format('work', n),
      'qualifiedWorks' => t.format('works', n,
          each: (row['eachWorkBookmarks'] as num?)?.toInt() ?? 0),
      'followers' => t.format('followers', n),
      'niarimBookmarkRanking' => t.format('rank', n),
      _ => (row['id'] ?? row['missionId']) as String? ?? '?',
    };
  }

  Future<void> _claim(CommunityApi api, String missionId, String? workId) async {
    final owner = context.read<GoogleAuthService>().account?.id;
    if (owner == null) return;
    final key = '$missionId:${workId ?? ""}';
    if (_claimBusy.contains(key)) return;
    setState(() => _claimBusy.add(key));
    try {
      final result = await api.claimCreatorMission(
        missionId: missionId, workId: workId,
      );
      if (!mounted || context.read<GoogleAuthService>().account?.id != owner) return;
      final t = CreatorMissionLabels.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['pending'] == true ? t.get('holdStarted')
            : result['claimed'] == true ? t.get('claimReceived')
            : t.get('claimFailed')),
      ));
      _refresh(api);
    } catch (_) {
      if (mounted && context.read<GoogleAuthService>().account?.id == owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CreatorMissionLabels.of(context).get('claimFailed'))),
        );
        _refresh(api);
      }
    } finally {
      if (mounted) setState(() => _claimBusy.remove(key));
    }
  }

  Future<void> _loadMore(CommunityApi api, String cursor) async {
    if (_moreBusy) return;
    final owner = context.read<GoogleAuthService>().account?.id;
    if (owner == null) return;
    setState(() => _moreBusy = true);
    try {
      final result = await api.myWorkMissionAchievements(cursor: cursor);
      if (!mounted || context.read<GoogleAuthService>().account?.id != owner) return;
      setState(() {
        _extraWorks.addAll((result['items'] as List? ?? const [])
          .whereType<Map>().map((x) => Map<String, dynamic>.from(x)));
        _nextCursor = result['nextCursor'] as String?;
        _nextLoaded = true;
      });
    } catch (_) {
      if (mounted && context.read<GoogleAuthService>().account?.id == owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CreatorMissionLabels.of(context).get('workListError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _moreBusy = false);
    }
  }

  Widget _tile(CreatorMissionLabels t, CommunityApi api,
      Map<String, dynamic> row, {String? workId, String? workTitle,
      bool? enabledOverride}) {
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true || workTitle != null;
    final ready = row['readyForClaim'] == true;
    final enabled = enabledOverride ?? (row['rewardEnabled'] == true);
    final key = (row['id'] ?? row['missionId']) as String? ?? '';
    final actionKey = '$key:${workId ?? ""}';
    final pending = row['pendingSince'] is num && !ready && !claimed;
    final allowAction = missionClaimActionAllowed(
      eligible: eligible, ready: ready, claimed: claimed, enabled: enabled,
    );
    final title = _missionName(t, row);
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    return Card(
      child: ListTile(
        title: Text(workTitle == null ? title : '$workTitle · $title',
          maxLines: 3, overflow: TextOverflow.ellipsis),
        subtitle: Text(claimed ? t.get('claimed')
          : pending ? t.get('pending')
          : eligible ? t.get('achieved') : t.get('notClaimed')),
        leading: Icon(claimed ? Icons.check_circle_outline
          : pending ? Icons.hourglass_empty
          : eligible ? Icons.verified_outlined : Icons.flag_outlined),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('+$coins ${t.get('coin')}',
              style: Theme.of(context).textTheme.labelMedium),
            if (eligible && !claimed && ready)
              FilledButton(
                key: ValueKey('claim_${key}_${workId ?? "account"}'),
                onPressed: allowAction && !_claimBusy.contains(actionKey)
                    ? () => _claim(api, key, workId) : null,
                child: _claimBusy.contains(actionKey)
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t.get('claim')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _workAchievements(CreatorMissionLabels t, CommunityApi api) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _workFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return Text(t.get('workListError'));
        }
        final data = snapshot.data!;
        final rows = [
          ...(data['items'] as List? ?? const [])
            .whereType<Map>().map((x) => Map<String, dynamic>.from(x)),
          ..._extraWorks,
        ];
        final cursor = _nextLoaded
            ? _nextCursor : data['nextCursor'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.get('workSection'),
              style: Theme.of(context).textTheme.titleMedium),
            Text(t.get('workWarning'),
              style: Theme.of(context).textTheme.bodySmall),
            if (rows.isEmpty) Text(t.get('noAchievements')),
            for (final row in rows)
              _tile(t, api, row,
                workId: row['workId'] as String?,
                workTitle: row['workTitle'] as String? ?? '',
                enabledOverride: data['rewardEnabled'] == true),
            if (cursor != null)
              OutlinedButton(
                onPressed: _moreBusy ? null : () => _loadMore(api, cursor),
                child: Text(t.get('loadMore')),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = CreatorMissionLabels.of(context);
    final owner = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    final localSeconds = context.watch<ProjectService>().projects
        .where((p) => !p.isSharedImport)
        .fold<int>(0, (sum, p) => sum + p.totalWorkSeconds);
    if (_owner != owner || _work != widget.workId || !identical(_api, api)) {
      _owner = owner;
      _work = widget.workId;
      _api = api;
      _extraWorks.clear();
      _nextCursor = null;
      _nextLoaded = false;
      _accountFuture = owner != null && api != null
          ? api.myCreatorMissions(workId: widget.workId) : null;
      _workFuture = owner != null && api != null && widget.workId == null
          ? api.myWorkMissionAchievements() : null;
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
          if (owner == null) Text(t.get('login'))
          else if (api == null) Text(t.get('offline'))
          else FutureBuilder<Map<String, dynamic>>(
            future: _accountFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(child: Semantics(label:t.get('loading'),
                  child: const CircularProgressIndicator()));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Column(children: [
                  Text(t.get('loadError')),
                  OutlinedButton(onPressed: () => _refresh(api),
                    child: Text(t.get('retry'))),
                ]);
              }
              final info = snapshot.data!;
              final rows = (info['missions'] as List? ?? const [])
                .whereType<Map>()
                .map((x) => Map<String, dynamic>.from(x));
              final minutes = ((info['candidateEditSeconds'] as num?)?.toInt() ?? 0) ~/ 60;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.format('candidateMinutes', minutes)),
                  const SizedBox(height: 8),
                  if (info['enabled'] != true)
                    Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: Text(t.get('upcoming'))),
                  if (widget.workId != null && info['selectedWorkTitle'] is String)
                    Text(info['selectedWorkTitle'] as String,
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final row in rows)
                    if (widget.workId != null || row['perWork'] != true)
                      _tile(t, api, row,
                        workId: row['perWork'] == true ? widget.workId : null,
                        workTitle: row['perWork'] == true
                          ? info['selectedWorkTitle'] as String? : null),
                  if (widget.workId == null)
                    _workAchievements(t, api),
                  TextButton(onPressed: () => _refresh(api),
                    child: Text(t.get('retry'))),
                ],
              );
            },
          ),
        ],
      )),
    );
  }
}
