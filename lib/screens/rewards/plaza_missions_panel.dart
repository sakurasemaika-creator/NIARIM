import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';

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
          !identical(_api, api)) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['claimed'] == true
            ? _t('コインを受け取りました', 'Coins received')
            : _t('受取に失敗しました', 'Could not claim')),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('受取に失敗しました', 'Could not claim')),
        ));
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
    'day' => _t('デイリー', 'Daily'),
    'week' => _t('ウィークリー', 'Weekly'),
    _ => _t('マンスリー', 'Monthly'),
  };
  String _goal(int seconds) => seconds >= 3600
      ? _t('${seconds ~/ 3600}時間', '${seconds ~/ 3600} hours')
      : _t('${seconds ~/ 60}分', '${seconds ~/ 60} minutes');

  Widget _row(Map row, bool enabled) {
    final id = row['id'] as String? ?? '';
    final goal = (row['requiredSeconds'] as num?)?.toInt() ?? 0;
    final progress = (row['progressSeconds'] as num?)?.toInt() ?? 0;
    final coins = (row['coins'] as num?)?.toInt() ?? 0;
    final claimed = row['claimed'] == true;
    final eligible = row['eligible'] == true;
    return ListTile(
      key: ValueKey('plazaMission_$id'),
      leading: Icon(claimed ? Icons.check_circle_outline
          : eligible ? Icons.emoji_events_outlined : Icons.timer_outlined),
      title: Text(_t('作品広場を合計${_goal(goal)}開く',
          'Keep Works Plaza open for ${_goal(goal)}')),
      subtitle: Text(_t('${_goal(progress)} / ${_goal(goal)} · $coins コイン',
          '${_goal(progress)} / ${_goal(goal)} · $coins coins')),
      trailing: claimed
          ? Text(_t('受取済み', 'Claimed'))
          : OutlinedButton(
              key: ValueKey('claimPlaza_$id'),
              onPressed: enabled && eligible && !_claiming.contains(id)
                  ? () => _claim(id) : null,
              child: Text(!enabled && eligible ? _t('準備中', 'Coming soon')
                  : eligible ? _t('受け取る', 'Claim')
                  : _t('未達成', 'Not yet')),
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
                return Row(children: [
                  Expanded(child: Text(_t('作品広場ミッションを読み込めません',
                      'Plaza missions unavailable'))),
                  IconButton(
                    onPressed: () => setState(
                      () => _state = _api!.myPlazaMissions(),
                    ), icon: const Icon(Icons.refresh),
                  ),
                ]);
              }
              return const LinearProgressIndicator();
            }
            final data = snapshot.data!;
            final missions = (data['missions'] as List? ?? const [])
                .whereType<Map>().toList();
            final enabled = data['enabled'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_t('作品広場の滞在ミッション',
                      'Works Plaza open-time missions'),
                      style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip: _t('更新', 'Refresh'),
                    onPressed: () => setState(
                      () => _state = _api!.myPlazaMissions(),
                    ),
                    icon: const Icon(Icons.refresh),
                  ),
                ]),
                Text(_t('再生・操作は不要。作品広場を開いている時間を日本時間で集計します。',
                    'No playback or interaction required. Time is counted in JST.'),
                    style: Theme.of(context).textTheme.bodySmall),
                if (!enabled)
                  Text(_t('コインの受取は準備中です', 'Coin payouts are not yet enabled'),
                      style: Theme.of(context).textTheme.bodySmall),
                for (final period in ['day', 'week', 'month']) ...[
                  const SizedBox(height: 8),
                  Text(_period(period),
                      style: Theme.of(context).textTheme.titleSmall),
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
