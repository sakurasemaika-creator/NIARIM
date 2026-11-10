import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/creator_mission_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/project_service.dart';
import '../../utils/app_locale.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/responsive.dart';
import 'login_bonus_panel.dart';
import 'recurring_missions_panel.dart';
import 'plaza_missions_panel.dart';

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
  const CreatorMissionsScreen({super.key, this.workId, this.embedded = false});
  final String? workId;
  final bool embedded;

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
  bool _bulkBusy = false;
  int _bulkPanelGeneration = 0;

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
        missionId: id,
        workId: workId,
      );
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != owner ||
          !identical(_api, api)) {
        return;
      }
      final t = CreatorMissionLabels.of(context);
      final message = receipt['pending'] == true
          ? t.get('holdStarted')
          : receipt['claimed'] == true
          ? t.get('claimReceived')
          : t.get('claimFailed');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _refresh(api);
    } catch (_) {
      if (mounted &&
          context.read<GoogleAuthService>().account?.id == owner &&
          identical(_api, api)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CreatorMissionLabels.of(context).get('claimFailed')),
          ),
        );
        _refresh(api);
      }
    } finally {
      if (mounted) setState(() => _claimBusy.remove(key));
    }
  }

  /// Collect every currently claimable server-verified mission. Individual
  /// endpoints retain their atomic wallet/idempotency protection. Failed or
  /// pending claims are never represented as credited coins.
  Future<void> _bulkClaim(
    CommunityApi api,
    Map<String, dynamic> pageData,
  ) async {
    if (_bulkBusy) return;
    final owner = context.read<GoogleAuthService>().account?.id;
    if (owner == null) return;
    setState(() => _bulkBusy = true);
    var received = 0;
    var failed = 0;
    try {
      bool sameOwner() =>
          mounted &&
          context.read<GoogleAuthService>().account?.id == owner &&
          identical(context.read<CommunityService>().api, api);

      // Query independent sources once. Do not infer earned coins locally.
      final statuses = await Future.wait<Map<String, dynamic>>([
        api.myLoginBonus(),
        api.myRecurringMissions(),
        api.myPlazaMissions(),
      ]);
      if (!sameOwner()) return;
      final login = statuses[0];
      final recurring = statuses[1];
      final plaza = statuses[2];

      Future<void> collect(
        Future<Map<String, dynamic>> Function() request,
      ) async {
        if (!sameOwner()) return;
        try {
          final receipt = await request();
          if (receipt['claimed'] == true &&
              receipt['duplicate'] != true &&
              receipt['pending'] != true) {
            received++;
          }
        } catch (_) {
          failed++;
        }
      }

      if (login['rewardEnabled'] == true) {
        if (login['visitedToday'] == true && login['dailyClaimed'] != true) {
          await collect(() => api.claimLoginBonus(kind: 'daily'));
        }
        for (final row in (login['milestones'] as List? ?? const [])) {
          if (row is! Map ||
              row['eligible'] != true ||
              row['claimed'] == true ||
              row['days'] is! num) {
            continue;
          }
          final days = (row['days'] as num).toInt();
          await collect(
            () => api.claimLoginBonus(kind: 'milestone', days: days),
          );
        }
      }
      for (final row in (recurring['missions'] as List? ?? const [])) {
        if (row is! Map || row['ready'] != true || row['id'] is! String) {
          continue;
        }
        final id = row['id'] as String;
        await collect(() => api.claimRecurringMission(missionId: id));
      }
      for (final row in (plaza['missions'] as List? ?? const [])) {
        if (row is! Map || row['ready'] != true || row['id'] is! String) {
          continue;
        }
        final id = row['id'] as String;
        await collect(() => api.claimPlazaMission(id));
      }
      for (final row in _rows(pageData)) {
        if (row['readyForClaim'] != true ||
            row['rewardEnabled'] != true ||
            row['claimed'] == true ||
            row['_genericTemplate'] == true) {
          continue;
        }
        final id = (row['id'] ?? row['missionId']) as String?;
        if (id == null || id.isEmpty) continue;
        final workId = row['_workId'] as String?;
        await collect(
          () => api.claimCreatorMission(missionId: id, workId: workId),
        );
      }
      if (mounted && sameOwner()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appLocalizationsOf(
                context,
              ).creatorMissionClaimAllResult(received, failed),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && context.read<GoogleAuthService>().account?.id == owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appLocalizationsOf(context).creatorMissionClaimAllLoadFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted && context.read<GoogleAuthService>().account?.id == owner) {
        setState(() {
          _bulkBusy = false;
          _bulkPanelGeneration++;
        });
        _refresh(api);
      }
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
          !identical(_api, api)) {
        return;
      }
      setState(() {
        _extraWorks.addAll(
          (data['items'] as List? ?? const []).whereType<Map>().map(
            (x) => Map<String, dynamic>.from(x),
          ),
        );
        _nextWorkCursor = data['nextCursor'] as String?;
        _loadedExtraPage = true;
      });
    } catch (_) {
      if (mounted && context.read<GoogleAuthService>().account?.id == owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              CreatorMissionLabels.of(context).get('workListError'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _moreBusy = false);
    }
  }

  String _goal(CreatorMissionLabels t, Map<String, dynamic> row) {
    final l10n = appLocalizationsOf(context);
    final required = (row['required'] as num?)?.toInt() ?? 0;
    final each = (row['eachWorkBookmarks'] as num?)?.toInt() ?? 0;
    final workTitle = row['_workTitle'] as String?;
    return switch (row['kind']) {
      'qualifiedWorks' =>
        each == 0
            ? l10n.creatorMissionWorksPublished(required)
            : l10n.creatorMissionWorksGoal(required, each),
      'workBookmarks' =>
        required == 0
            ? workTitle != null
                  ? l10n.creatorMissionNamedPublished(workTitle)
                  : t.get('genericPublished')
            : workTitle != null
            ? l10n.creatorMissionNamedBookmark(workTitle, required)
            : l10n.creatorMissionGenericBookmark(required),
      'followers' => l10n.creatorMissionFollowers(required),
      'verifiedEditSeconds' => l10n.creatorMissionTime(required ~/ 3600),
      'niarimBookmarkRanking' =>
        required == 1 ? t.get('rankOne') : l10n.creatorMissionRank(required),
      _ => row['id'] as String? ?? '?',
    };
  }

  List<String> _rankingMissingReasons(
    CreatorMissionLabels t,
    Map<String, dynamic> row,
  ) {
    if (row['kind'] != 'niarimBookmarkRanking') return const [];
    final l10n = appLocalizationsOf(context);
    final raw = row['rankingUnmetConditions'];
    final codes = raw is List ? raw.whereType<String>() : const <String>[];
    final count = (row['publishedWorkCount'] as num?)?.toInt() ?? 0;
    final minPublished =
        (row['rankingMinPublishedWorks'] as num?)?.toInt() ?? 100;
    final haveBookmarks = (row['rankingWorkBookmarks'] as num?)?.toInt() ?? 0;
    final neededBookmarks = (row['rankingMinBookmarks'] as num?)?.toInt() ?? 0;
    final rank = (row['progress'] as num?)?.toInt() ?? 51;
    final allowed = (row['rankingEffectiveRankLimit'] as num?)?.toInt() ?? 0;
    return [
      for (final code in codes)
        switch (code) {
          'selectWork' => t.get('rankSelectWork'),
          'workNotPublic' => t.get('rankWorkNotPublic'),
          'communityNotMeasured' => t.get('rankCommunityNotMeasured'),
          'communityTooSmall' => l10n.creatorMissionRankCommunityWait(
            count,
            minPublished,
          ),
          'notEnoughBookmarks' => l10n.creatorMissionRankBookmarkWait(
            haveBookmarks,
            neededBookmarks,
          ),
          'notRanked' => t.get('rankNotRanked'),
          'rankTooLow' => l10n.creatorMissionRankRankWait(rank, allowed),
          _ => t.get('notAchieved'),
        },
    ];
  }

  void _showDetails(CreatorMissionLabels t, Map<String, dynamic> row) {
    final l10n = appLocalizationsOf(context);
    final name = _goal(t, row);
    final claimed = row['claimed'] == true;
    final earned = row['eligible'] == true;
    final status = claimed
        ? t.get('claimed')
        : earned
        ? t.get('achieved')
        : row['eligible'] == null
        ? t.get('reviewing')
        : t.get('notAchieved');
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final goal = (row['required'] as num?)?.toInt() ?? 0;
    final progress =
        (row['progress'] as num?)?.toInt() ??
        (row['bookmarkCount'] as num?)?.toInt();
    final kind = row['kind'];
    final template = row['_genericTemplate'] == true;
    final details = <String>[
      name,
      status,
      if (progress != null && !template && kind == 'qualifiedWorks')
        l10n.creatorMissionDetailsWorksProgress(progress, goal),
      if (progress != null && !template && kind == 'workBookmarks' && goal > 0)
        l10n.creatorMissionDetailsWorkProgress(progress, goal),
      if (progress != null && kind == 'followers')
        l10n.creatorMissionDetailsFollowersProgress(progress, goal),
      if (kind == 'niarimBookmarkRanking' &&
          row['rankingPopulationKnown'] != true)
        t.get('rankPoolUnknown'),
      if (kind == 'niarimBookmarkRanking' &&
          row['rankingPopulationKnown'] == true)
        l10n.creatorMissionRankPoolCurrent(
          (row['publishedWorkCount'] as num?)?.toInt() ?? 0,
        ),
      if (kind == 'niarimBookmarkRanking' && row['rankingWorkBookmarks'] is num)
        l10n.creatorMissionRankBookmarkCurrent(
          (row['rankingWorkBookmarks'] as num).toInt(),
        ),
      if (kind == 'niarimBookmarkRanking' &&
          !template &&
          row['progress'] is num &&
          (row['progress'] as num).toInt() > 0 &&
          (row['progress'] as num).toInt() <= 50)
        l10n.creatorMissionRankCurrentPlace((row['progress'] as num).toInt()),
      if (kind == 'niarimBookmarkRanking' && !claimed)
        ..._rankingMissingReasons(t, row),
      if (kind == 'niarimBookmarkRanking' &&
          row['rankingMinPublishedWorks'] is num &&
          row['rankingMinBookmarks'] is num)
        l10n.creatorMissionRankingRequirements(
          (row['rankingMinPublishedWorks'] as num).toInt(),
          (row['rankingMinBookmarks'] as num).toInt(),
        ),
      if (kind == 'niarimBookmarkRanking' &&
          row['rankingEffectiveRankLimit'] is num &&
          (row['rankingEffectiveRankLimit'] as num).toInt() > 0)
        l10n.creatorMissionRankingEffective(
          (row['rankingEffectiveRankLimit'] as num).toInt(),
        ),
      if (kind == 'niarimBookmarkRanking' && row['rankingTopPercent'] is num)
        l10n.creatorMissionRankDetailsRules(
          (row['rankingTopPercent'] as num).toInt(),
          goal,
        ),
      if (kind == 'niarimBookmarkRanking') t.get('rankDetailsHold'),
      if (kind == 'workBookmarks') t.get('detailsCreatorBookmarkRule'),
      if (kind == 'qualifiedWorks') ...[
        t.get('detailsCreatorWorksRule'),
        t.get('detailsDraftCount'),
      ],
      if (kind == 'followers') t.get('detailsCreatorFollowerRule'),
      if (kind == 'verifiedEditSeconds') t.get('detailsCreatorTimeRule'),
      if (kind != 'niarimBookmarkRanking' && kind != 'verifiedEditSeconds')
        t.get('detailsCreatorClaimRule'),
      if (template) t.get('detailsTemplateRule'),
      if (row['perWork'] == true)
        t.get('detailsPerWorkRule')
      else
        t.get('detailsAccountRule'),
      if (row['pendingSince'] is num && !claimed && earned)
        t.get('detailsPending'),
      if (row['rewardEnabled'] != true) t.get('detailsOffline'),
      l10n.coinAmount(coins),
      t.get('detailsHint'),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('detailsTitle')),
        content: SingleChildScrollView(child: Text(details.join('\n\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).closeButtonTooltip),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    CreatorMissionLabels t,
    CommunityApi api,
    Map<String, dynamic> row,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true;
    final ready = row['readyForClaim'] == true;
    final pending =
        row['pendingSince'] is num && eligible && !ready && !claimed;
    final available = row['rewardEnabled'] == true;
    final id = (row['id'] ?? row['missionId']) as String? ?? '';
    final workId = row['_workId'] as String?;
    final actionKey = '$id:${workId ?? "account"}';
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final canClaim =
        missionClaimActionAllowed(
          eligible: eligible,
          ready: ready,
          claimed: claimed,
          enabled: available,
        ) &&
        !_claimBusy.contains(actionKey);
    final status = claimed
        ? t.get('claimed')
        : pending
        ? t.get('reviewing')
        : eligible
        ? t.get('achieved')
        : row['eligible'] == null && row['kind'] == 'qualifiedWorks'
        ? t.get('reviewing')
        : t.get('notAchieved');
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
              icon: Icon(
                eligible || claimed
                    ? Icons.priority_high_rounded
                    : Icons.help_outline,
              ),
              color: eligible && !claimed
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            // コインと受け取るボタンは文の横か下に置く（右端に固定すると、
            // 大きな文字や長い言語で文が単語の途中で折り返した）。
            Expanded(
              child: ActionBesideOrBelow(
                text: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_goal(t, row), style: theme.textTheme.bodyMedium),
                    Text(status, style: theme.textTheme.bodySmall),
                  ],
                ),
                action: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.toll_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          appLocalizationsOf(context).coinAmount(coins),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    if (claimed)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          t.get('claimed'),
                          style: theme.textTheme.labelSmall,
                        ),
                      )
                    else if (eligible && ready)
                      FilledButton(
                        key: ValueKey('claim_${id}_${workId ?? "account"}'),
                        onPressed: canClaim
                            ? () => _claim(api, id, workId)
                            : null,
                        child: _claimBusy.contains(actionKey)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(t.get('claim')),
                      )
                    else
                      OutlinedButton(
                        onPressed: null,
                        child: Text(
                          !available
                              ? t.get('upcoming')
                              : pending
                              ? t.get('reviewing')
                              : t.get('notAchieved'),
                        ),
                      ),
                  ],
                ),
              ),
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
      if (row['kind'] == 'niarimBookmarkRanking') {
        row['publishedWorkCount'] = account['publishedWorkCount'] ?? 0;
      }
      if (widget.workId != null) {
        row['_workId'] = row['perWork'] == true ? widget.workId : null;
        row['_workTitle'] = row['perWork'] == true ? selectedTitle : null;
        all.add(row);
      } else if (row['perWork'] == true) {
        // 28 per-work templates (including ranking), not claimable until a
        // specific work is selected; never suggest that rank alone qualifies.
        all.add({
          ...row,
          '_genericTemplate': true,
          'eligible': false,
          'claimed': false,
          'readyForClaim': false,
          'rewardEnabled': false,
          'pendingSince': null,
          if (row['kind'] == 'niarimBookmarkRanking')
            'rankingUnmetConditions': const ['selectWork'],
        });
      } else {
        all.add(row);
      }
    }
    for (final raw in (grid?['missions'] as List? ?? const [])) {
      if (raw is Map) all.add(Map<String, dynamic>.from(raw));
    }
    final earned = [...(works?['items'] as List? ?? const []), ..._extraWorks];
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
      final priority = missionSortPriority(
        a.value,
      ).compareTo(missionSortPriority(b.value));
      return priority != 0 ? priority : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList(growable: false);
  }

  Widget _body(
    CreatorMissionLabels t,
    CommunityApi api,
    Map<String, dynamic> data,
  ) {
    final account = data['account'] as Map<String, dynamic>;
    final grid = data['grid'] as Map<String, dynamic>?;
    final works = data['works'] as Map<String, dynamic>?;
    final rows = _rows(data);
    final cursor = _loadedExtraPage
        ? _nextWorkCursor
        : works?['nextCursor'] as String?;
    final candidateMinutes =
        ((account['candidateEditSeconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final verifiedMinutes =
        ((account['verifiedEditSeconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final localSeconds = context
        .watch<ProjectService>()
        .projects
        .where((project) => !project.isSharedImport)
        .fold<int>(0, (sum, project) => sum + project.totalWorkSeconds);
    final hasMore = cursor != null;
    final l10n = appLocalizationsOf(context);
    return desktopCentered(
      context,
      ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 1 + rows.length + (hasMore ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FilledButton.icon(
                    key: const Key('missionClaimAllButton'),
                    onPressed: _bulkBusy ? null : () => _bulkClaim(api, data),
                    icon: _bulkBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.inventory_2_outlined),
                    label: Text(l10n.creatorMissionClaimAll),
                  ),
                ),
                if (widget.workId == null) ...[
                  LoginBonusPanel(
                    key: ValueKey('login-bulk-$_bulkPanelGeneration'),
                  ),
                  const SizedBox(height: 12),
                  RecurringMissionsPanel(
                    key: ValueKey('recurring-bulk-$_bulkPanelGeneration'),
                  ),
                  const SizedBox(height: 12),
                  PlazaMissionsPanel(
                    key: ValueKey('plaza-bulk-$_bulkPanelGeneration'),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  t.get('subtitle'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(t.get('budget')),
                const SizedBox(height: 8),
                Text(l10n.creatorMissionLocalTime(localSeconds ~/ 3600)),
                Text(
                  account['editTimeVerificationReady'] == true
                      ? t.get('timeWarning')
                      : t.get('editTimeUnverified'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(l10n.creatorMissionCandidateMinutes(candidateMinutes)),
                Text(l10n.creatorMissionVerifiedMinutes(verifiedMinutes)),
                if (account['enabled'] != true &&
                    grid?['rewardEnabled'] != true)
                  Text(t.get('upcoming')),
                const SizedBox(height: 16),
              ],
            );
          }
          final rowIndex = index - 1;
          if (rowIndex < rows.length) return _tile(t, api, rows[rowIndex]);
          if (cursor != null && rowIndex == rows.length) {
            return OutlinedButton(
              onPressed: _moreBusy ? null : () => _more(api, cursor),
              child: Text(t.get('loadMore')),
            );
          }
          return TextButton.icon(
            onPressed: () => _refresh(api),
            icon: const Icon(Icons.refresh),
            label: Text(t.get('retry')),
          );
        },
      ),
    );
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
      appBar: widget.embedded ? null : AppBar(title: Text(t.get('title'))),
      body: owner == null
          ? Center(child: Text(t.get('login')))
          : api == null
          ? Center(child: Text(t.get('offline')))
          : FutureBuilder<Map<String, dynamic>>(
              future: _future,
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.get('loadError')),
                        OutlinedButton(
                          onPressed: () => _refresh(api),
                          child: Text(t.get('retry')),
                        ),
                      ],
                    ),
                  );
                }
                return _body(t, api, snapshot.data!);
              },
            ),
    );
  }
}
