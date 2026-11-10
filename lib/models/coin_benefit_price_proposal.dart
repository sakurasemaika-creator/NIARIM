import 'coin_unlock_quote.dart';

/// Informational only: these are NOT server-approved, spendable prices.
/// The real exchange button still requires an authenticated backend quote.
abstract final class CoinBenefitPriceProposal {
  static const version = 'proposal-v2-rounded10';

  static const _monthlyCoins = <CoinUnlockTarget, int>{
    CoinUnlockTarget.endCardEdit: 8000,
    CoinUnlockTarget.watermark: 14000,
    CoinUnlockTarget.toneCurve: 13000,
    CoinUnlockTarget.levelAdjustment: 10000,
    CoinUnlockTarget.unlimitedDuration: 18000,
    CoinUnlockTarget.customAutomation: 20000,
    CoinUnlockTarget.projectListAds: 9000,
    CoinUnlockTarget.canvasAds: 15000,
    CoinUnlockTarget.timelineAds: 12000,
    CoinUnlockTarget.processingAds: 6000,
    CoinUnlockTarget.allAds: 36000,
    CoinUnlockTarget.fullPremium: 60000,
  };

  static const individualTargets = <CoinUnlockTarget>[
    CoinUnlockTarget.endCardEdit,
    CoinUnlockTarget.watermark,
    CoinUnlockTarget.toneCurve,
    CoinUnlockTarget.levelAdjustment,
    CoinUnlockTarget.unlimitedDuration,
    CoinUnlockTarget.customAutomation,
    CoinUnlockTarget.projectListAds,
    CoinUnlockTarget.canvasAds,
    CoinUnlockTarget.timelineAds,
    CoinUnlockTarget.processingAds,
  ];

  static int unitCoins(CoinUnlockTarget target, CoinDurationUnit unit) {
    final month = _monthlyCoins[target];
    if (month == null) throw StateError('No reference price for $target');
    if (unit == CoinDurationUnit.month) return month;
    if (target == CoinUnlockTarget.fullPremium) {
      return switch (unit) {
        CoinDurationUnit.hour => 500,
        CoinDurationUnit.day => 2500,
        CoinDurationUnit.week => 18000,
        CoinDurationUnit.month => month,
      };
    }
    final raw = switch (unit) {
      CoinDurationUnit.hour => (month / 120).ceil(),
      CoinDurationUnit.day => (month / 28).ceil(),
      CoinDurationUnit.week => (month / 3.7).ceil(),
      CoinDurationUnit.month => month,
    };
    // Round the ones digit UP so each unit quote is a multiple of 10.
    return ((raw + 9) ~/ 10) * 10;
  }

  static int cost(CoinUnlockTarget target, CoinUnlockDuration duration) =>
      unitCoins(target, duration.unit) * duration.amount;

  static int singleTotal(CoinUnlockDuration duration) =>
      individualTargets.fold(0, (sum, target) => sum + cost(target, duration));

  static bool bundleIsCheaper(CoinUnlockDuration duration) =>
      cost(CoinUnlockTarget.fullPremium, duration) < singleTotal(duration);
}
