import 'coin_unlock_quote.dart';
import 'coin_economy_scale.dart';

/// Owner-approved final launch unit-price table.
/// Pricing is fixed, but this client calculator cannot debit a wallet or
/// activate unsupported benefits. A live purchase still requires an
/// authenticated, approved, server-versioned quote and atomic redemption.
abstract final class CoinBenefitPriceCatalog {
  static const version = 'v4-min10-repriced-20261113';

  /// Exactly the Japanese annual Premium plan price × 100 coins.
  static const yearlyPremiumCoins =
      CoinEconomyScale.yearlyPlanYen * CoinEconomyScale.referenceCoinsPerYen;

  static const _monthlyCoins = <CoinUnlockTarget, int>{
    CoinUnlockTarget.endCardEdit: 12_000,
    CoinUnlockTarget.watermark: 18_000,
    CoinUnlockTarget.toneCurve: 18_000,
    CoinUnlockTarget.levelAdjustment: 15_000,
    CoinUnlockTarget.unlimitedDuration: 25_000,
    CoinUnlockTarget.customAutomation: 25_000,
    CoinUnlockTarget.projectListAds: 12_000,
    CoinUnlockTarget.canvasAds: 20_000,
    CoinUnlockTarget.timelineAds: 16_000,
    CoinUnlockTarget.processingAds: 10_000,
    CoinUnlockTarget.allAds: 40_000,
    CoinUnlockTarget.fullPremium: 55_000,
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
        CoinDurationUnit.hour => 5000,
        CoinDurationUnit.day => 10000,
        CoinDurationUnit.week => 30000,
        CoinDurationUnit.month => month,
      };
    }
    final raw = switch (unit) {
      CoinDurationUnit.hour => (month / 24).ceil(),
      CoinDurationUnit.day => (month / 10).ceil(),
      CoinDurationUnit.week => (month / 2).ceil(),
      CoinDurationUnit.month => month,
    };
    // Round the ones digit UP so each unit quote is a multiple of 10.
    return ((raw + 9) ~/ 10) * 10;
  }

  static int cost(CoinUnlockTarget target, CoinUnlockDuration duration) {
    if (!duration.isValid) throw StateError('Unsupported unlock duration');
    if (target == CoinUnlockTarget.fullPremium &&
        duration.unit == CoinDurationUnit.month) {
      // Use annual-plan pricing for each complete 12-month block. A
      // 12-month selection must NOT be charged 12 × the monthly tariff.
      return (duration.amount ~/ 12) * yearlyPremiumCoins +
          (duration.amount % 12) *
              unitCoins(CoinUnlockTarget.fullPremium, CoinDurationUnit.month);
    }
    return unitCoins(target, duration.unit) * duration.amount;
  }

  static int singleTotal(CoinUnlockDuration duration) =>
      individualTargets.fold(0, (sum, target) => sum + cost(target, duration));

  static bool bundleIsCheaper(CoinUnlockDuration duration) =>
      cost(CoinUnlockTarget.fullPremium, duration) < singleTotal(duration);
}
