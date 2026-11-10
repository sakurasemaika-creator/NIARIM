import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/app_locale.dart';
import '../../widgets/action_beside_or_below.dart';

/// Server counts visits by JST day; only a confirmed POST claim can credit coins.
class RecurringMissionsPanel extends StatefulWidget {
  const RecurringMissionsPanel({super.key});

  @override
  State<RecurringMissionsPanel> createState() => _RecurringMissionsPanelState();
}

class _RecurringMissionsPanelState extends State<RecurringMissionsPanel> {
  String? _owner;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _future;
  final _busy = <String>{};

  String _label(BuildContext context, String ja, String en) =>
      Localizations.localeOf(context).languageCode == 'ja' ? ja : en;

  Future<Map<String, dynamic>> _load(CommunityApi api) async {
    try {
      await api.visitLoginBonus();
    } catch (_) {
      // Opening the panel never creates a local or unverified coin grant.
    }
    return api.myRecurringMissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    if (_owner != owner || !identical(_api, api)) {
      _owner = owner;
      _api = api;
      _busy.clear();
      _future = owner != null && api != null ? _load(api) : null;
    }
  }

  Future<void> _claim(String id) async {
    final owner = _owner;
    final api = _api;
    if (owner == null || api == null || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final result = await api.claimRecurringMission(missionId: id);
      if (!mounted ||
          owner != _owner ||
          !identical(api, _api) ||
          context.read<GoogleAuthService>().account?.id != owner) {
        return;
      }
      final l10n = appLocalizationsOf(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['claimed'] == true
                ? l10n.missionCoinsReceived
                : l10n.missionClaimUnconfirmed,
          ),
        ),
      );
    } catch (_) {
      if (mounted && owner == _owner && identical(api, _api)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appLocalizationsOf(context).missionClaimUnconfirmed),
          ),
        );
      }
    } finally {
      if (mounted && owner == _owner && identical(api, _api)) {
        setState(() {
          _busy.remove(id);
          _future = _load(api);
        });
      }
    }
  }

  void _showMissionDetails(BuildContext context, Map raw, bool enabled) {
    final period = raw['period'] == 'week' ? 'week' : 'month';
    final week = period == 'week';
    final requiredDays = (raw['requiredDays'] as num?)?.toInt() ?? 0;
    final progressDays = (raw['progressDays'] as num?)?.toInt() ?? 0;
    final coins = (raw['coins'] as num?)?.toInt() ?? 0;
    final claimed = raw['claimed'] == true;
    final eligible = raw['eligible'] == true;
    final title = _label(
      context,
      week ? '週に$requiredDays日ログイン' : '月に$requiredDays日ログイン',
      week
          ? 'Sign in on $requiredDays days this week'
          : 'Sign in on $requiredDays days this month',
    );
    final details = [
      title,
      _label(
        context,
        '【達成条件】日本時間の${week ? '同じ週（月曜日から日曜日）' : '同じ月（1日から末日）'}内に、異なる日付で$requiredDays日以上ログインしてください。連続ログインは必要ありません。1日に複数回ログインしても1日として数えます。ログイン日数はサーバーで確認します。',
        'CONDITIONS: Sign in on $requiredDays distinct days in the same ${week ? 'Monday–Sunday week' : 'calendar month'}, using Japan time (JST). Consecutive days are not required; multiple sign-ins on one day count as one. The server verifies visits.',
      ),
      _label(
        context,
        '現在の達成日数：$progressDays / $requiredDays 日',
        'Current progress: $progressDays / $requiredDays days',
      ),
      _label(
        context,
        '【受取】条件を満たすと$coinsコインを受け取れます。同じ期間の同じ段階は1回限りです。新しい週・月には進捗がリセットされ、再度達成できます。期間終了後は前の期間の報酬を受け取れません。',
        'CLAIM: Completing the goal grants $coins coins. Each milestone can pay only once per period. Progress resets in a new week/month; rewards from the previous period cannot be claimed later.',
      ),
      claimed
          ? _label(
              context,
              'この期間の報酬は受取済みです。',
              'Already claimed for this period.',
            )
          : eligible
          ? _label(context, '条件達成済みです。', 'Goal completed.')
          : _label(context, 'まだ達成条件を満たしていません。', 'Goal not yet completed.'),
      if (!enabled)
        _label(
          context,
          'コインの受取機能は現在準備中です。',
          'Coin payouts are currently unavailable.',
        ),
    ].join('\n\n');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_label(dialogContext, '達成条件', 'Mission details')),
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

  Widget _item(BuildContext context, Map raw, bool enabled) {
    final id = raw['id'] as String? ?? '';
    final requiredDays = (raw['requiredDays'] as num?)?.toInt() ?? 0;
    final days = (raw['progressDays'] as num?)?.toInt() ?? 0;
    final coins = (raw['coins'] as num?)?.toInt() ?? 0;
    final achieved = raw['eligible'] == true;
    final claimed = raw['claimed'] == true;
    final l10n = appLocalizationsOf(context);
    return ListTile(
      key: Key('recurringMission_$id'),
      // Keep the help/exclamation control to the LEFT of the mission title.
      leading: IconButton(
        key: Key('recurringMissionDetails_$id'),
        tooltip: _label(context, '達成条件を確認', 'View mission details'),
        onPressed: () => _showMissionDetails(context, raw, enabled),
        icon: Icon(
          achieved || claimed
              ? Icons.priority_high_rounded
              : Icons.help_outline,
        ),
      ),
      title: Text(
        _label(
          context,
          raw['period'] == 'week'
              ? '週に$requiredDays日ログイン'
              : '月に$requiredDays日ログイン',
          raw['period'] == 'week'
              ? 'Sign in on $requiredDays days this week'
              : 'Sign in on $requiredDays days this month',
        ),
      ),
      // 受け取るボタンは説明の横か下に置き、題には行の幅をすべて使わせる。
      subtitle: ActionBesideOrBelow(
        text: Text(
          '${l10n.recurringMissionProgress(days, requiredDays)}'
          ' · ${l10n.coinAmount(coins)}',
        ),
        action: claimed
            ? Text(l10n.missionClaimed)
            : OutlinedButton(
                key: Key('claimRecurring_$id'),
                onPressed: enabled && achieved && !_busy.contains(id)
                    ? () => _claim(id)
                    : null,
                child: Text(
                  !enabled && achieved
                      ? l10n.missionComingSoon
                      : achieved
                      ? l10n.missionClaim
                      : l10n.missionNotYet,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_owner == null || _api == null) return const SizedBox.shrink();
    final l10n = appLocalizationsOf(context);
    return Card(
      key: const Key('recurringMissionsPanel'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Row(
                children: [
                  Expanded(child: Text(l10n.recurringMissionsUnavailable)),
                  IconButton(
                    onPressed: () => setState(() => _future = _load(_api!)),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              );
            }
            final data = snapshot.data!;
            final enabled = data['enabled'] == true;
            final missions = (data['missions'] as List? ?? const [])
                .whereType<Map>()
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_repeat_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.recurringMissionsTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _future = _load(_api!)),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                Text(
                  l10n.recurringMissionsNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!enabled)
                  Text(
                    l10n.missionPayoutPending,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final period in ['week', 'month']) ...[
                  const SizedBox(height: 8),
                  Text(
                    period == 'week'
                        ? l10n.missionPeriodWeekly
                        : l10n.missionPeriodMonthly,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final row in missions.where(
                    (m) => m['period'] == period,
                  ))
                    _item(context, row, enabled),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
