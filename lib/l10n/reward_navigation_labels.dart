import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Names and subscription entry copy for rewards navigation.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
/// 数や日時を含む文言は、単数・複数や日付の書き方をARBで決める
/// AppLocalizationsのメソッドを直接使う（数・日付と語をコードでつなげない）。
class RewardNavigationLabels {
  const RewardNavigationLabels._(this._l10n);
  final AppLocalizations _l10n;

  static RewardNavigationLabels of(BuildContext context) =>
      RewardNavigationLabels._(appLocalizationsOf(context));

  String operator [](String key) => switch (key) {
    'exchange' => _l10n.rewardNavigationExchange,
    'hub' => _l10n.rewardNavigationHub,
    'earnTab' => _l10n.rewardNavigationEarnTab,
    'missions' => _l10n.rewardNavigationMissions,
    'earn' => _l10n.rewardNavigationEarn,
    'membership' => _l10n.rewardNavigationMembership,
    'membershipDetail' => _l10n.rewardNavigationMembershipDetail,
    'membershipFree' => _l10n.rewardNavigationMembershipFree,
    'membershipMonthly' => _l10n.rewardNavigationMembershipMonthly,
    'membershipYearly' => _l10n.rewardNavigationMembershipYearly,
    'membershipPlay' => _l10n.rewardNavigationMembershipPlay,
    'membershipCoin' => _l10n.rewardNavigationMembershipCoin,
    'membershipBenefit' => _l10n.rewardNavigationMembershipBenefit,
    'membershipNoBenefit' => _l10n.rewardNavigationMembershipNoBenefit,
    'membershipUpsell' => _l10n.rewardNavigationMembershipUpsell,
    'membershipUnavailable' => _l10n.rewardNavigationMembershipUnavailable,
    'membershipLogin' => _l10n.rewardNavigationMembershipLogin,
    'premiumCompare' => _l10n.rewardNavigationPremiumCompare,
    'premiumJoin' => _l10n.rewardNavigationPremiumJoin,
    'premiumPlans' => _l10n.rewardNavigationPremiumPlans,
    'earnDescription' => _l10n.rewardNavigationEarnDescription,
    'earnUnavailable' => _l10n.rewardNavigationEarnUnavailable,
    _ => key,
  };
}
