import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/app_locale.dart';
import '../../utils/coin_duration_label.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/button_label_room.dart';
import '../../widgets/keep_together_text.dart';
import 'mission_panel_heading.dart';

/// Authenticated, read-only view until the server explicitly enables payouts.
/// A permanently open Plaza page counts: video playback is not a requirement.
class PlazaMissionsPanel extends StatefulWidget {
  const PlazaMissionsPanel({super.key, this.refreshToken = 0});
  final int refreshToken;

  @override
  State<PlazaMissionsPanel> createState() => _PlazaMissionsPanelState();
}

class _PlazaMissionsPanelState extends State<PlazaMissionsPanel> {
  String? _owner;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _state;
  final Set<String> _claiming = {};

  AppLocalizations get _l10n => appLocalizationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshIfChanged();
  }

  @override
  void didUpdateWidget(covariant PlazaMissionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken && _api != null) {
      _state = _api!.myPlazaMissions();
    }
  }

  void _refreshIfChanged() {
    final owner = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    if (owner != _owner || !identical(api, _api)) {
      _owner = owner;
      _api = api;
      _claiming.clear();
      _state = owner != null && api != null ? api.myPlazaMissions() : null;
    }
  }

  Future<void> _claim(String id) async {
    final owner = _owner;
    final api = _api;
    if (owner == null || api == null || _claiming.contains(id)) return;
    setState(() => _claiming.add(id));
    try {
      final result = await api.claimPlazaMission(id);
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != owner ||
          !identical(_api, api)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['claimed'] == true
                ? _l10n.missionCoinsReceived
                : _l10n.missionClaimFailed,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.missionClaimFailed)));
      }
    } finally {
      if (mounted && identical(_api, api) && _owner == owner) {
        setState(() {
          _claiming.remove(id);
          _state = api.myPlazaMissions();
        });
      }
    }
  }

  String _period(String value) => switch (value) {
    'day' => _l10n.missionPeriodDaily,
    'week' => _l10n.missionPeriodWeekly,
    _ => _l10n.missionPeriodMonthly,
  };
  String _goal(int seconds) => missionDurationLabel(_l10n, seconds);

  void _showMissionDetails(Map row, bool enabled) {
    final id = row['id'] as String? ?? '';
    final period = row['period'] as String? ?? 'day';
    final goal = (row['requiredSeconds'] as num?)?.toInt() ?? 0;
    final progress = (row['progressSeconds'] as num?)?.toInt() ?? 0;
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true;
    final details = [
      _l10n.plazaMissionGoal(_goal(goal)),
      // 'day'・'week'以外はマンスリー（_periodと同じ決まり）。
      _l10n.plazaMissionDetailsConditions(period, _goal(goal)),
      _l10n.plazaMissionDetailsMeasurement,
      _l10n.plazaMissionDetailsPeriods,
      _l10n.plazaMissionDetailsProgress(_goal(progress), _goal(goal)),
      _l10n.plazaMissionDetailsClaim(coins),
      claimed
          ? _l10n.missionDetailsClaimedThisPeriod
          : eligible
          ? _l10n.missionDetailsGoalCompleted
          : _l10n.missionDetailsGoalNotCompleted,
      if (!enabled) _l10n.missionDetailsPayoutUnavailable,
    ].join('\n\n');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: ValueKey('plazaMissionDetailsDialog_$id'),
        title: Text(_l10n.missionDetailsTitle),
        content: SingleChildScrollView(child: Text(details)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              MaterialLocalizations.of(dialogContext).closeButtonTooltip,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Map row, bool enabled) {
    final id = row['id'] as String? ?? '';
    final goal = (row['requiredSeconds'] as num?)?.toInt() ?? 0;
    final progress = (row['progressSeconds'] as num?)?.toInt() ?? 0;
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true;
    return ListTile(
      key: ValueKey('plazaMission_$id'),
      // Keep the help/exclamation control to the LEFT of the mission title.
      leading: IconButton(
        key: ValueKey('plazaMissionDetails_$id'),
        tooltip: _l10n.missionDetailsTooltip,
        onPressed: () => _showMissionDetails(row, enabled),
        icon: Icon(
          eligible || claimed
              ? Icons.priority_high_rounded
              : Icons.help_outline,
        ),
      ),
      // 時間・コインの数と単位（「15分」「1コイン」「40小時」）は途中で
      // 行を変えない。
      title: KeepTogetherText(
        _l10n.plazaMissionGoal(_goal(goal)),
        keep: [_goal(goal)],
      ),
      // 受け取るボタンは説明の横か下に置き、題には行の幅をすべて使わせる。
      subtitle: ActionBesideOrBelow(
        text: KeepTogetherText(
          '${_goal(progress)} / ${_goal(goal)} · ${_l10n.coinAmount(coins)}',
          keep: [_goal(progress), _goal(goal), _l10n.coinAmount(coins)],
        ),
        action: claimed
            ? Text(_l10n.missionClaimed)
            : OutlinedButton(
                key: ValueKey('claimPlaza_$id'),
                onPressed: enabled && eligible && !_claiming.contains(id)
                    ? () => _claim(id)
                    : null,
                child: ButtonLabelRoom(
                  child: Text(
                    !enabled && eligible
                        ? _l10n.missionComingSoon
                        : eligible
                        ? _l10n.missionClaim
                        : _l10n.missionNotYet,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_owner == null || _api == null) return const SizedBox.shrink();
    return Card(
      key: const Key('plazaMissionsPanel'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _state,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Expanded(child: Text(_l10n.plazaMissionsUnavailable)),
                    IconButton(
                      onPressed: () =>
                          setState(() => _state = _api!.myPlazaMissions()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                );
              }
              return const LinearProgressIndicator();
            }
            final data = snapshot.data!;
            final missions = (data['missions'] as List? ?? const [])
                .whereType<Map>()
                .toList();
            final enabled = data['enabled'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MissionPanelHeading(
                  icon: Icons.timer_outlined,
                  title: _l10n.plazaMissionsTitle,
                  action: IconButton(
                    tooltip: _l10n.missionRefresh,
                    onPressed: () =>
                        setState(() => _state = _api!.myPlazaMissions()),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                Text(
                  _l10n.plazaMissionsNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!enabled)
                  Text(
                    _l10n.missionPayoutPending,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final period in ['day', 'week', 'month']) ...[
                  const SizedBox(height: 8),
                  Text(
                    _period(period),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final m in missions.where((x) => x['period'] == period))
                    _row(m, enabled),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
