import 'package:flutter/material.dart';

import '../l10n/reward_unlock_labels.dart';
import '../l10n/login_bonus_labels.dart';

/// Signed-in account, server-authenticated coin ledger. No local balances,
/// purchase callbacks or user-supplied transaction amounts are displayed.
class CoinHistorySheet extends StatefulWidget {
  const CoinHistorySheet({
    super.key,
    required this.ownerId,
    required this.accountChanges,
    required this.currentAccountId,
    required this.fetchPage,
  });

  final String ownerId;
  final Listenable accountChanges;
  final String? Function() currentAccountId;
  final Future<Map<String, dynamic>> Function({String? cursor, int limit})
  fetchPage;

  @override
  State<CoinHistorySheet> createState() => _CoinHistorySheetState();
}

class _CoinHistorySheetState extends State<CoinHistorySheet> {
  final List<Map<String, dynamic>> _entries = [];
  String? _cursor;
  bool _loading = false;
  bool _loadedFirstPage = false;
  bool _error = false;
  bool _hasMore = true;
  bool _ownerActive = true;

  @override
  void initState() {
    super.initState();
    _ownerActive = widget.currentAccountId() == widget.ownerId;
    widget.accountChanges.addListener(_onAccountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ownerActive) _loadMore();
    });
  }

  void _onAccountChanged() {
    if (widget.currentAccountId() == widget.ownerId) return;
    if (!mounted || !_ownerActive) return;
    setState(() {
      _ownerActive = false;
      _entries.clear();
      _cursor = null;
      _hasMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loading ||
        !_hasMore ||
        !_ownerActive ||
        widget.currentAccountId() != widget.ownerId) {
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page = await widget.fetchPage(cursor: _cursor, limit: 20);
      if (!mounted ||
          !_ownerActive ||
          widget.currentAccountId() != widget.ownerId) {
        return;
      }
      final rawEntries = page['entries'];
      final rawCursor = page['nextCursor'];
      if (rawEntries is! List ||
          !(rawCursor == null || rawCursor is String) ||
          (rawCursor is String &&
              (rawCursor.isEmpty || rawCursor == _cursor))) {
        throw const FormatException('Invalid coin history response');
      }
      final parsed = <Map<String, dynamic>>[];
      for (final raw in rawEntries) {
        if (raw is! Map ||
            raw['source'] is! String ||
            raw['deltaCoins'] is! int ||
            raw['occurredAtEpochMs'] is! int ||
            (raw['occurredAtEpochMs'] as int) < 0 ||
            (raw['occurredAtEpochMs'] as int) > 8640000000000000) {
          throw const FormatException('Invalid coin transaction');
        }
        parsed.add(Map<String, dynamic>.from(raw));
      }
      setState(() {
        _entries.addAll(parsed);
        _cursor = rawCursor as String?;
        _hasMore = _cursor != null;
        _loadedFirstPage = true;
      });
    } catch (_) {
      if (mounted &&
          _ownerActive &&
          widget.currentAccountId() == widget.ownerId) {
        setState(() => _error = true);
      }
    } finally {
      if (mounted && _ownerActive) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    widget.accountChanges.removeListener(_onAccountChanged);
    super.dispose();
  }

  String _sourceLabel(
    BuildContext context,
    RewardUnlockLabels t,
    Map<String, dynamic> entry,
  ) {
    final source = entry['source'] as String;
    if (source == 'login-bonus') {
      final lb = LoginBonusLabels.of(context);
      final mission = entry['missionId'];
      return mission is String && mission.startsWith('login_daily_')
          ? lb['daily']
          : lb['title'];
    }
    return switch (source) {
      'rewarded-ad' => t['historyAd'],
      'creator-mission' || 'creator-grid' => t['historyMission'],
      'coin-redemption' => t['historyRedemption'],
      _ => t['historyOther'],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_ownerActive) return const SizedBox.shrink();
    final t = RewardUnlockLabels.of(context);
    final height = MediaQuery.sizeOf(context).height * .72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t['coinHistory'],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final row in _entries)
                      ListTile(
                        title: Text(_sourceLabel(context, t, row)),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(
                            row['occurredAtEpochMs'] as int,
                          ).toLocal().toString().substring(0, 16),
                        ),
                        trailing: Text(
                          '${(row['deltaCoins'] as int) > 0 ? '+' : ''}'
                          '${row['deltaCoins']} ${t['coins']}',
                          key: const Key('coinHistoryAmount'),
                        ),
                      ),
                    if (_loadedFirstPage && _entries.isEmpty && !_error)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          t['historyEmpty'],
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_error)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          t['historyError'],
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (!_loading && (_error || _hasMore))
                      TextButton(
                        key: const Key('coinHistoryMoreButton'),
                        onPressed: _loadMore,
                        child: Text(
                          _error ? t['rewardRefresh'] : t['historyMore'],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
