import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/creator_mission_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/project_service.dart';
import '../../widgets/responsive.dart';

/// Display-only policy. The server must independently verify every request.
bool missionClaimActionAllowed({
  required bool eligible,
  required bool ready,
  required bool claimed,
  required bool enabled,
}) => eligible && ready && !claimed && enabled;

/// The user explicitly requests each reward. Never credit coins from a GET,
/// a local counter, or a Flutter button callback.
int missionSortPriority(Map<String, dynamic> row) {
  if (row['_genericTemplate'] == true) return 4;
  final claimed = row['claimed'] == true;
  final eligible = row['eligible'] == true;
  if (eligible && !claimed) {
    return row['readyForClaim'] == true ? 0 : 1;
  }
  if (claimed) return 2;
  return 3;
}

class CreatorMissionsScreen extends StatefulWidget {
  const CreatorMissionsScreen({super.key, this.workId});
  final String? workId;

  @override
  State<CreatorMissionsScreen> createState() => _CreatorMissionsScreenState();
}

class _CreatorMissionsScreenState extends State<CreatorMissionsScreen> {
  String? _owner;
  String? _workId;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _future;
  final List<Map<String, dynamic>> _extraWorks = [];
  final Set<String> _claimBusy = {};
  String? _nextWorkCursor;
  bool _loadedExtraPage = false;
  bool _moreBusy = false;

  Future<Map<String, dynamic>> _fetch(CommunityApi api) async {
    final results = await Future.wait(<Future<Map<String, dynamic>>>[
      api.myCreatorMissions(workId: widget.workId),
      if (widget.workId == null) api.myWorkCountMissions(),
      if (widget.workId == null) api.myWorkMissionAchievements(),
    ]);
    return {
      'account': results[0],
      if (widget.workId == null) 'grid': results[1],
      if (widget.workId == null) 'works': results[2],
    };
  }

  void _refresh(CommunityApi api) => setState(() {
    _future = _fetch(api);
    _extraWorks.clear();
    _nextWorkCursor = null;
    _loadedExtraPage = false;
  });

  Future<void> _claim(CommunityApi api, String id, String? workId) async {
    final owner = context.read<GoogleAuthService>().account?.id;
    if (owner == null) return;
    final key = '$id:${workId ?? "account"}';
    if (_claimBusy.contains(key)) return;
    setState(() => _claimBusy.add(key));
    try {
      final receipt = await api.claimCreatorMission(
        missionId: id, workId: workId,
      );
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != owner ||
          !identical(_api, api)) return;
      final t = CreatorMissionLabels.of(context);
      final message = receipt['pending'] == true ? t.get('holdStarted')
          : receipt['claimed'] == true ? t.get('claimReceived')
          : t.get('claimFailed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
      _refresh(api);
    } catch (_) {
      if (mounted &&
          context.read<GoogleAuthService>().account?.id == owner &&
          identical(_api, api)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(CreatorMissionLabels.of(context).get('claimFailed'))));
        _refresh(api);
      }
    } finally {
      if (mounted) setState(() => _claimBusy.remove(key));
    }
  }

  Future<void> _more(CommunityApi api, String cursor) async {
    if (_moreBusy) return;
    final owner = context.read<GoogleAuthService>().account?.id;
    if (owner == null) return;
    setState(() => _moreBusy = true);
    try {
      final data = await api.myWorkMissionAchievements(cursor: cursor);
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != owner ||
          !identical(_api, api)) return;
      setState(() {
        _extraWorks.addAll((data['items'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x)));
        _nextWorkCursor = data['nextCursor'] as String?;
        _loadedExtraPage = true;
      });
    } catch (_) {
      if (mounted &&
          context.read<GoogleAuthService>().account?.id == owner) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(CreatorMissionLabels.of(context).get('workListError'))));
      }
    } finally {
      if (mounted) setState(() => _moreBusy = false);
    }
  }

  String _goal(CreatorMissionLabels t, Map<String, dynamic> row) {
    final required = (row['required'] as num?)?.toInt() ?? 0;
    final each = (row['eachWorkBookmarks'] as num?)?.toInt() ?? 0;
    final workTitle = row['_workTitle'] as String?;
    final generic = row['_genericTemplate'] == true;
    return switch (row['kind']) {
      'qualifiedWorks' => each == 0
          ? t.format('worksPublished', required)
          : t.format('worksGoal', required, each: each),
      'workBookmarks' => required == 0
          ? workTitle != null
              ? '$workTitle${t.get('namedPublished')}'
              : t.get('genericPublished')
          : workTitle != null
              ? '$workTitle${t.format('namedBookmark', required)}'
              : generic
                  ? t.format('genericBookmark', required)
                  : t.format('genericBookmark', required),
      'followers' => t.format('followers', required),
      'verifiedEditSeconds' => t.format('time', required ~/ 3600),
      'niarimBookmarkRanking' => t.format('rank', required),
      _ => row['id'] as String? ?? '?',
    };
  }

  void _showDetails(CreatorMissionLabels t, Map<String, dynamic> row) {
    final name = _goal(t, row);
    final claimed = row['claimed'] == true;
    final earned = row['eligible'] == true;
    final status = claimed ? t.get('claimed')
        : earned ? t.get('achieved')
        : row['eligible'] == null ? t.get('reviewing')
        : t.get('notAchieved');
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('detailsTitle')),
        content: Text(
          '$name\n\n$status\n$coins ${t.get('coin')}\n\n${t.get('detailsHint')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).closeButtonTooltip),
          ),
        ],
      ),
    );
  }

  Widget _tile(CreatorMissionLabels t, CommunityApi api,
      Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true;
    final ready = row['readyForClaim'] == true;
    final pending = row['pendingSince'] is num && !ready && !claimed;
    final available = row['rewardEnabled'] == true;
    final id = (row['id'] ?? row['missionId']) as String? ?? '';
    final workId = row['_workId'] as String?;
    final actionKey = '$id:${workId ?? "account"}';
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final canClaim = missionClaimActionAllowed(
      eligible: eligible, ready: ready,
      claimed: claimed, enabled: available,
    ) && !_claimBusy.contains(actionKey);
    final status = claimed ? t.get('claimed')
        : pending ? t.get('reviewing')
        : eligible ? t.get('achieved')
        : row['eligible'] == null && row['kind'] == 'qualifiedWorks'
            ? t.get('reviewing') : t.get('notAchieved');
    return Card(
      key: ValueKey('mission_$id:${workId ?? "template"}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              key: ValueKey('missionDetails_$id:${workId ?? "template"}'),
              tooltip: t.get('detailsTooltip'),
              onPressed: () => _showDetails(t, row),
              icon: Icon(eligible || claimed
                  ? Icons.priority_high_rounded : Icons.help_outline),
              color: eligible && !claimed
                  ? scheme.primary : scheme.onSurfaceVariant,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_goal(t, row),
                    style: theme.textTheme.bodyMedium),
                  Text(status, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.toll_outlined,
                    size: 16, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text('$coins ${t.get('coin')}',
                    style: theme.textTheme.labelSmall),
                ]),
                if (claimed)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(t.get('claimed'),
                      style: theme.textTheme.labelSmall),
                  )
                else if (eligible && ready)
                  FilledButton(
                    key: ValueKey('claim_${id}_${workId ?? "account"}'),
                    onPressed: canClaim ? () => _claim(api, id, workId) : null,
                    child: _claimBusy.contains(actionKey)
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.get('claim')),
                  )
                else
                  OutlinedButton(
                    onPressed: null,
                    child: Text(pending ? t.get('reviewing')
                        : t.get('notAchieved')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) {
    final account = data['account'] as Map<String, dynamic>;
    final grid = data['grid'] as Map<String, dynamic>?;
    final works = data['works'] as Map<String, dynamic>?;
    final selectedTitle = account['selectedWorkTitle'] as String?;
    final all = <Map<String, dynamic>>[];
    for (final raw in (account['missions'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      if (widget.workId != null) {
        row['_workId'] = row['perWork'] == true ? widget.workId : null;
        row['_workTitle'] = row['perWork'] == true ? selectedTitle : null;
        all.add(row);
      } else if (row['perWork'] == true) {
        // 24 perpetual gray templates, even if there are already achievements.
        all.add({...row,
          '_genericTemplate': true, 'eligible': false,
          'claimed': false, 'readyForClaim': false,
          'rewardEnabled': false, 'pendingSince': null,
        });
      } else {
        all.add(row);
      }
    }
    for (final raw in (grid?['missions'] as List? ?? const [])) {
      if (raw is Map) all.add(Map<String, dynamic>.from(raw));
    }
    final earned = [
      ...(works?['items'] as List? ?? const []),
      ..._extraWorks,
    ];
    for (final raw in earned) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      all.add({
        ...row,
        'id': row['missionId'],
        'eligible': true,
        'perWork': true,
        'rewardEnabled': works?['rewardEnabled'] == true,
        '_workId': row['workId'],
        '_workTitle': row['workTitle'],
      });
    }
    // Dart's list sort is not stable; use the original index as the tie break.
    final indexed = all.asMap().entries.toList();
    indexed.sort((a, b) {
      final priority = missionSortPriority(a.value)
          .compareTo(missionSortPriority(b.value));
      return priority != 0 ? priority : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList(growable: false);
  }

  Widget _body(CreatorMissionLabels t, CommunityApi api,
      Map<String, dynamic> data) {
    final account = data['account'] as Map<String, dynamic>;
    final grid = data['grid'] as Map<String, dynamic>?;
    final works = data['works'] as Map<String, dynamic>?;
    final rows = _rows(data);
    final cursor = _loadedExtraPage
        ? _nextWorkCursor : works?['nextCursor'] as String?;
    final candidateMinutes =
        ((account['candidateEditSeconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final localSeconds = context.watch<ProjectService>().projects
        .where((project) => !project.isSharedImport)
        .fold<int>(0, (sum, project) => sum + project.totalWorkSeconds);
    final hasMore = cursor != null;
    return desktopCentered(context, ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 1 + rows.length + (hasMore ? 1 : 0) + 1,
      itemBuilder: (context, index) {
        if (index == 0) return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.get('subtitle'),
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(t.get('budget')),
            const SizedBox(height: 8),
            Text(t.format('localTime', localSeconds ~/ 3600)),
            Text(t.get('timeWarning'),
              style: Theme.of(context).textTheme.bodySmall),
            Text(t.get('rankingWarning'),
              style: Theme.of(context).textTheme.bodySmall),
            Text(t.format('candidateMinutes', candidateMinutes)),
            if (account['enabled'] != true && grid?['rewardEnabled'] != true)
              Text(t.get('upcoming')),
            const SizedBox(height: 16),
          ],
        );
        final rowIndex = index - 1;
        if (rowIndex < rows.length) return _tile(t, api, rows[rowIndex]);
        if (cursor != null && rowIndex == rows.length) {
          return OutlinedButton(
            onPressed: _moreBusy ? null : () => _more(api, cursor),
            child: Text(t.get('loadMore')));
        }
        return TextButton.icon(
          onPressed: () => _refresh(api),
          icon: const Icon(Icons.refresh),
          label: Text(t.get('retry')),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = CreatorMissionLabels.of(context);
    final owner = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    if (_owner != owner || _workId != widget.workId || !identical(_api, api)) {
      _owner = owner;
      _workId = widget.workId;
      _api = api;
      _extraWorks.clear();
      _nextWorkCursor = null;
      _loadedExtraPage = false;
      _claimBusy.clear();
      _future = owner != null && api != null ? _fetch(api) : null;
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.get('title'))),
      body: owner == null
          ? Center(child: Text(t.get('login')))
          : api == null
            ? Center(child: Text(t.get('offline')))
            : FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(child: Semantics(
                      label: t.get('loading'),
                      child: const CircularProgressIndicator()));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.get('loadError')),
                        OutlinedButton(
                          onPressed: () => _refresh(api),
                          child: Text(t.get('retry')),
                        ),
                      ],
                    ));
                  }
                  return _body(t, api, snapshot.data!);
                },
              ),
    );
  }
}
