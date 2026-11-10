import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/app_locale.dart';
import '../../widgets/action_beside_or_below.dart';

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

  String _t(String ja, String en) =>
      Localizations.localeOf(context).languageCode == 'ja' ? ja : en;

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
  String _goal(int seconds) => seconds >= 3600
      ? _l10n.missionDurationHours(seconds ~/ 3600)
      : _l10n.missionDurationMinutes(seconds ~/ 60);

  void _showMissionDetails(Map row, bool enabled) {
    final id = row['id'] as String? ?? '';
    final period = row['period'] as String? ?? 'day';
    final goal = (row['requiredSeconds'] as num?)?.toInt() ?? 0;
    final progress = (row['progressSeconds'] as num?)?.toInt() ?? 0;
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true;
    final label = _t(
      '作品広場を合計${_goal(goal)}開く',
      'Keep Works Plaza open for ${_goal(goal)}',
    );
    final periodName = _period(period);
    final details = [
      label,
      _t(
        '【達成条件】$periodNameの期間中、NIARIMの作品広場を開いている時間の合計が${_goal(goal)}以上になると達成です。動画を再生したり、画面を操作したりする必要はありません。',
        'CONDITIONS: Keep NIARIM Works Plaza open for at least ${_goal(goal)} in the $periodName period. Video playback and interaction are not required.',
      ),
      _t(
        '計測はサーバー時刻に基づく定期通信で行います。端末が申告した秒数は使用しません。通信が長く途切れた時間やページを閉じていた時間は加算されません。',
        'Time is measured by authenticated server-time heartbeats, not client-reported seconds. Long connection gaps and time with the page closed do not count.',
      ),
      _t(
        '期間は日本時間で区切り、1日は午前0時に、週は月曜日に、月は1日に切り替わります。',
        'Periods use Japan time (JST): days reset at midnight, weeks start on Monday and months start on the first.',
      ),
      _t(
        '現在の閲覧時間：${_goal(progress)} / ${_goal(goal)}',
        'Current open time: ${_goal(progress)} / ${_goal(goal)}',
      ),
      _t(
        '【受取】条件を満たすと$coinsコインを受け取れます。各ミッションの受取は同じ期間中に1回限りです。次の期間には再度挑戦できます。前の期間の報酬は期間終了後に受け取れません。',
        'CLAIM: Earn $coins coins for this milestone. Each milestone pays once per period. You may earn it again in a new period, but cannot claim an expired period.',
      ),
      claimed
          ? _t('この期間の報酬は受取済みです。', 'Already claimed for this period.')
          : eligible
          ? _t('条件達成済みです。', 'Goal completed.')
          : _t('まだ達成条件を満たしていません。', 'Goal not yet completed.'),
      if (!enabled)
        _t('コインの受取機能は現在準備中です。', 'Coin payouts are currently unavailable.'),
    ].join('\n\n');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: ValueKey('plazaMissionDetailsDialog_$id'),
        title: Text(_t('達成条件', 'Mission details')),
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
        tooltip: _t('達成条件を確認', 'View mission details'),
        onPressed: () => _showMissionDetails(row, enabled),
        icon: Icon(
          eligible || claimed
              ? Icons.priority_high_rounded
              : Icons.help_outline,
        ),
      ),
      title: Text(_l10n.plazaMissionGoal(_goal(goal))),
      // 受け取るボタンは説明の横か下に置き、題には行の幅をすべて使わせる。
      subtitle: ActionBesideOrBelow(
        text: Text(
          '${_goal(progress)} / ${_goal(goal)} · ${_l10n.coinAmount(coins)}',
        ),
        action: claimed
            ? Text(_l10n.missionClaimed)
            : OutlinedButton(
                key: ValueKey('claimPlaza_$id'),
                onPressed: enabled && eligible && !_claiming.contains(id)
                    ? () => _claim(id)
                    : null,
                child: Text(
                  !enabled && eligible
                      ? _l10n.missionComingSoon
                      : eligible
                      ? _l10n.missionClaim
                      : _l10n.missionNotYet,
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
                Row(
                  children: [
                    const Icon(Icons.timer_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _l10n.plazaMissionsTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: _l10n.missionRefresh,
                      onPressed: () =>
                          setState(() => _state = _api!.myPlazaMissions()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
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
