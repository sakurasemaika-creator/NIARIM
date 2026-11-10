import 'package:flutter/widgets.dart';

import '../utils/app_locale.dart';
import 'app_localizations.dart';

/// Labels for the reward exchange screen, looked up by key.
/// 文言はARB（app_*.arb）にある（以前はこのファイルに7言語の表を手で
/// 持っていて、同梱フォントの検査を通らず字の抜けが出ていた）。
/// 数を含む文言は、単数・複数をARBで決めるAppLocalizationsのメソッドを
/// 直接使う（数と単位の語をコードでつなげない）。
class RewardUnlockLabels {
  const RewardUnlockLabels._(this._l10n);
  final AppLocalizations _l10n;

  static RewardUnlockLabels of(BuildContext context) =>
      RewardUnlockLabels._(appLocalizationsOf(context));

  String operator [](String key) => switch (key) {
    'title' => _l10n.rewardUnlockTitle,
    'missionTitle' => _l10n.rewardUnlockMissionTitle,
    'missionSubtitle' => _l10n.rewardUnlockMissionSubtitle,
    'loading' => _l10n.rewardUnlockLoading,
    'paused' => _l10n.rewardUnlockPaused,
    'activeUntil' => _l10n.rewardUnlockActiveUntil,
    'subscriptionBenefit' => _l10n.rewardUnlockSubscriptionBenefit,
    'active' => _l10n.rewardUnlockActive,
    'activePremium' => _l10n.rewardUnlockActivePremium,
    'activeCampaign' => _l10n.rewardUnlockActiveCampaign,
    'activeUnavailable' => _l10n.rewardUnlockActiveUnavailable,
    'duration' => _l10n.rewardUnlockDuration,
    'chooseDuration' => _l10n.rewardUnlockChooseDuration,
    'chooseBenefits' => _l10n.rewardUnlockChooseBenefits,
    'pricePending' => _l10n.rewardUnlockPricePending,
    'notReady' => _l10n.rewardUnlockNotReady,
    'total' => _l10n.rewardUnlockTotal,
    'unavailable' => _l10n.rewardUnlockUnavailable,
    'balancePending' => _l10n.rewardUnlockBalancePending,
    'goal' => _l10n.rewardUnlockGoal,
    'redeem' => _l10n.rewardUnlockRedeem,
    'watchRewardedAd' => _l10n.rewardUnlockWatchRewardedAd,
    'rewardPending' => _l10n.rewardUnlockRewardPending,
    'rewardUnavailable' => _l10n.rewardUnlockRewardUnavailable,
    'rewardRefresh' => _l10n.rewardUnlockRewardRefresh,
    'coinHistory' => _l10n.rewardUnlockCoinHistory,
    'historyEmpty' => _l10n.rewardUnlockHistoryEmpty,
    'historyError' => _l10n.rewardUnlockHistoryError,
    'historyMore' => _l10n.rewardUnlockHistoryMore,
    'historyAd' => _l10n.rewardUnlockHistoryAd,
    'historyMission' => _l10n.rewardUnlockHistoryMission,
    'historyRedemption' => _l10n.rewardUnlockHistoryRedemption,
    'historyOther' => _l10n.rewardUnlockHistoryOther,
    'rewardQuotaReached' => _l10n.rewardUnlockRewardQuotaReached,
    'rewardQuotaUncapped' => _l10n.rewardUnlockRewardQuotaUncapped,
    'rewardQuotaCaution' => _l10n.rewardUnlockRewardQuotaCaution,
    'redemptionSuccess' => _l10n.rewardUnlockRedemptionSuccess,
    'redemptionUncertain' => _l10n.rewardUnlockRedemptionUncertain,
    'freeOnly' => _l10n.rewardUnlockFreeOnly,
    'subscribe' => _l10n.rewardUnlockSubscribe,
    'bestValue' => _l10n.rewardUnlockBestValue,
    'bestExplain' => _l10n.rewardUnlockBestExplain,
    'earning' => _l10n.rewardUnlockEarning,
    'hour' => _l10n.rewardUnlockHour,
    'day' => _l10n.rewardUnlockDay,
    'week' => _l10n.rewardUnlockWeek,
    'month' => _l10n.rewardUnlockMonth,
    'endCardEdit' => _l10n.rewardUnlockEndCardEdit,
    'watermark' => _l10n.rewardUnlockWatermark,
    'toneCurve' => _l10n.rewardUnlockToneCurve,
    'levelAdjustment' => _l10n.rewardUnlockLevelAdjustment,
    'unlimitedDuration' => _l10n.rewardUnlockUnlimitedDuration,
    'customAutomation' => _l10n.rewardUnlockCustomAutomation,
    'communityPostQuota' => _l10n.rewardUnlockCommunityPostQuota,
    'projectListAds' => _l10n.rewardUnlockProjectListAds,
    'canvasAds' => _l10n.rewardUnlockCanvasAds,
    'timelineAds' => _l10n.rewardUnlockTimelineAds,
    'processingAds' => _l10n.rewardUnlockProcessingAds,
    'allAds' => _l10n.rewardUnlockAllAds,
    'fullPremium' => _l10n.rewardUnlockFullPremium,
    'choose' => _l10n.rewardUnlockChoose,
    _ => key,
  };
}
