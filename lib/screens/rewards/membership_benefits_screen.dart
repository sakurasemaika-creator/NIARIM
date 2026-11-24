import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/accent_text_theme.dart';
import '../../l10n/reward_navigation_labels.dart';
import '../../l10n/reward_unlock_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/premium_service.dart';
import '../../utils/app_locale.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/responsive.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_card.dart';
import 'rewards_sign_in_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final t = RewardNavigationLabels.of(context);
    final reward = RewardUnlockLabels.of(context);
    // 期限の日時はその言語の日付の書き方でARBの文に入れる（以前は「年月日
    // 時分」を組み立てて語とつないでいて、どの言語でも日本語の日付だった）。
    final l10n = appLocalizationsOf(context);
    final premium = context.watch<PremiumService>();
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
      appBar: AppBar(title: FitOrHideTitle(t['membership'])),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 下の見出し・本文・ボタンと同じ左右の端にそろえる（カードの既定の
            // 外側の余白で、カードだけ4px内側に寄っていた）。先頭の印で、
            // プレミアム（オパールで解放中も）か無料かを一目で分ける。
            MenuCard(
              key: const Key('membershipStatusCard'),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isPlayMember || premium.hasCoinPremium
                          ? Icons.workspace_premium_outlined
                          : Icons.person_outline,
                      size: 28,
                      color: AccentTextTheme.of(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (isPlayMember &&
                              premium.verifiedExpiryDate != null)
                            Text(
                              l10n.rewardNavigationMembershipExpiresAt(
                                premium.verifiedExpiryDate!.toLocal(),
                              ),
                            ),
                          // 見出しがすでに「オパールで解放中」のときは期限だけを出す
                          // （同じ語を2行続けない）。
                          if (coinExpiry != null)
                            Text(
                              isPlayMember
                                  ? l10n.rewardNavigationMembershipCoinExpiresAt(
                                      coinExpiry.toLocal(),
                                    )
                                  : l10n.rewardNavigationMembershipExpiresAt(
                                      coinExpiry.toLocal(),
                                    ),
                            ),
                        ],
                      ),
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
            if (_owner == null) ...[
              messageText(t['membershipLogin']),
              const SizedBox(height: 12),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: RewardsSignInButton(filled: false),
              ),
            ] else if (_api == null)
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
                          color: AccentTextTheme.of(context),
                        ),
                        title: Text(reward[feature]),
                        subtitle: Text(
                          paused
                              ? reward['paused']
                              : date != null
                              ? l10n.rewardNavigationMembershipExpiresAt(
                                  date.toLocal(),
                                )
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
                // 1字だけの行を作らない：日本語は最後の語（「詳しく見る」）を
                // 途中で折らず（320pxで「…詳しく見 / る」と折れた）、韓国語の
                // 語も途中で折らない（「보 / 기」）。
                label: messageText(t['membershipDetail'], keepLastPhrase: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
