import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/reward_navigation_labels.dart';
import '../../l10n/reward_unlock_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/responsive.dart';

/// Current entitlements are read from the authenticated server; plan details
/// are shown only when Google Play verification is still valid.
class MembershipBenefitsScreen extends StatefulWidget {
  const MembershipBenefitsScreen({super.key});

  @override
  State<MembershipBenefitsScreen> createState() =>
      _MembershipBenefitsScreenState();
}

class _MembershipBenefitsScreenState extends State<MembershipBenefitsScreen> {
  String? _owner;
  CommunityApi? _api;
  Future<Map<String, dynamic>>? _state;

  Future<Map<String, dynamic>> _fetch(CommunityApi api, String owner) async {
    final result = await api.myRewardState();
    if (!mounted ||
        _owner != owner ||
        !identical(_api, api) ||
        context.read<GoogleAuthService>().account?.id != owner) {
      return result;
    }
    // Refresh coin-purchased Premium from the authenticated entitlement list,
    // even if the user has never opened the separate exchange screen.
    DateTime? activeUntil;
    for (final row in (result['entitlements'] as List? ?? const [])) {
      if (row is! Map ||
          row['feature'] != 'fullPremium' ||
          row['status'] != 'active' ||
          row['expiresAtEpochMs'] is! num) {
        continue;
      }
      final date = DateTime.fromMillisecondsSinceEpoch(
        (row['expiresAtEpochMs'] as num).toInt(),
      );
      if (date.isAfter(DateTime.now())) activeUntil = date;
    }
    context.read<PremiumService>().applyServerCoinPremiumExpiry(
      activeUntil,
      accountId: owner,
    );
    return result;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    if (_owner != owner || !identical(_api, api)) {
      _owner = owner;
      _api = api;
      _state = owner != null && api != null ? _fetch(api, owner) : null;
    }
  }

  String _fmt(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = RewardNavigationLabels.of(context);
    final reward = RewardUnlockLabels.of(context);
    final premium = context.watch<PremiumService>();
    final scheme = Theme.of(context).colorScheme;
    final isPlayMember = premium.hasVerifiedPlayPremium;
    final plan = premium.verifiedSubscriptionProductId;
    final tier = isPlayMember
        ? (plan == PremiumService.yearlyProductId
              ? t['membershipYearly']
              : plan == PremiumService.monthlyProductId
              ? t['membershipMonthly']
              : t['membershipPlay'])
        : premium.hasCoinPremium
        ? t['membershipCoin']
        : t['membershipFree'];
    final coinExpiry = premium.activeCoinPremiumExpiry;
    return Scaffold(
      appBar: AppBar(title: Text(t['membership'])),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tier, style: Theme.of(context).textTheme.titleLarge),
                    if (isPlayMember && premium.verifiedExpiryDate != null)
                      Text(
                        '${t['membershipExpires']}: '
                        '${_fmt(premium.verifiedExpiryDate!)}',
                      ),
                    if (coinExpiry != null)
                      Text(
                        '${t['membershipCoin']} · '
                        '${t['membershipExpires']}: ${_fmt(coinExpiry)}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t['membershipBenefit'],
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_owner == null)
              Text(t['membershipLogin'])
            else if (_api == null)
              Text(t['membershipUnavailable'])
            else
              FutureBuilder<Map<String, dynamic>>(
                future: _state,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Text(t['membershipUnavailable']);
                  }
                  final entries =
                      (snapshot.data!['entitlements'] as List? ?? const [])
                          .whereType<Map>()
                          .toList();
                  if (entries.isEmpty) {
                    return Text(t['membershipNoBenefit']);
                  }
                  return Column(
                    children: entries.map((item) {
                      final feature = item['feature'] as String? ?? '';
                      final paused = item['status'] == 'paused';
                      final end = item['expiresAtEpochMs'];
                      final date = end is num
                          ? DateTime.fromMillisecondsSinceEpoch(end.toInt())
                          : null;
                      return ListTile(
                        leading: Icon(
                          Icons.verified_outlined,
                          color: scheme.primary,
                        ),
                        title: Text(reward[feature]),
                        subtitle: Text(
                          paused
                              ? reward['paused']
                              : date != null
                              ? '${t['membershipExpires']}: ${_fmt(date)}'
                              : t['membershipUnavailable'],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            if (!isPlayMember) ...[
              const SizedBox(height: 28),
              Text(
                t['membershipUpsell'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('membershipLearnPremiumButton'),
                icon: const Icon(Icons.info_outline),
                onPressed: () => context.push('/premium'),
                label: Text(t['membershipDetail']),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
