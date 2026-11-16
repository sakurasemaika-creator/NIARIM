import 'coin_unlock_quote.dart';

/// Versioned Opal exchange prices for display and server quote checks.
abstract final class CoinBenefitPriceCatalog {
  static const version = 'v6-subscription-aligned-20261116';

  // v5 monthly weights scaled to 55,000 Opals for the six tools and All Ads.
  static const _monthlyCoins = <CoinUnlockTarget, int>{
    CoinUnlockTarget.endCardEdit: 4_310,
    CoinUnlockTarget.watermark: 6_470,
    CoinUnlockTarget.toneCurve: 6_470,
    CoinUnlockTarget.levelAdjustment: 5_390,
    CoinUnlockTarget.unlimitedDuration: 8_990,
    CoinUnlockTarget.customAutomation: 8_990,
    CoinUnlockTarget.projectListAds: 4_310,
    CoinUnlockTarget.canvasAds: 7_190,
    CoinUnlockTarget.timelineAds: 5_750,
    CoinUnlockTarget.processingAds: 3_590,
    CoinUnlockTarget.allAds: 14_380,
  };

  static const _productionTargets = <CoinUnlockTarget>[
    CoinUnlockTarget.endCardEdit,
    CoinUnlockTarget.watermark,
    CoinUnlockTarget.toneCurve,
    CoinUnlockTarget.levelAdjustment,
    CoinUnlockTarget.unlimitedDuration,
    CoinUnlockTarget.customAutomation,
  ];

  static const individualTargets = <CoinUnlockTarget>[
    ..._productionTargets,
    CoinUnlockTarget.projectListAds,
    CoinUnlockTarget.canvasAds,
    CoinUnlockTarget.timelineAds,
    CoinUnlockTarget.processingAds,
  ];

  static const _comparisonTargets = <CoinUnlockTarget>[
    ..._productionTargets,
    CoinUnlockTarget.allAds,
  ];

  static int get yearlyPremiumCoins => cost(
    CoinUnlockTarget.fullPremium,
    const CoinUnlockDuration(12, CoinDurationUnit.month),
  );

  static int _individualUnitCoins(
    CoinUnlockTarget target,
    CoinDurationUnit unit,
  ) {
    final month = _monthlyCoins[target];
    if (month == null) throw StateError('No reference price for $target');
    // Round each short-period tariff up to 10 Opals.
    return switch (unit) {
      CoinDurationUnit.hour => ((month + 59) ~/ 60) * 10,
      CoinDurationUnit.day => ((month + 29) ~/ 30) * 10,
      CoinDurationUnit.week => ((month * 3 + 39) ~/ 40) * 10,
      CoinDurationUnit.month => month,
    };
  }

  static int unitCoins(CoinUnlockTarget target, CoinDurationUnit unit) {
    if (target != CoinUnlockTarget.fullPremium) {
      return _individualUnitCoins(target, unit);
    }
    final total = _comparisonTargets.fold<int>(
      0,
      (sum, target) => sum + _individualUnitCoins(target, unit),
    );
    // Give the Complete Pack a 20% discount, rounded to the nearest 10 Opals.
    return ((total * 4 + 25) ~/ 50) * 10;
  }

  static int cost(CoinUnlockTarget target, CoinUnlockDuration duration) {
    if (!duration.isValid) throw StateError('Unsupported unlock duration');
    // Each complete 12-month block costs ten monthly units.
    final units = duration.unit == CoinDurationUnit.month
        ? duration.amount - 2 * (duration.amount ~/ 12)
        : duration.amount;
    return unitCoins(target, duration.unit) * units;
  }

  static int singleTotal(CoinUnlockDuration duration) =>
      _comparisonTargets.fold(0, (sum, target) => sum + cost(target, duration));

  static bool bundleIsCheaper(CoinUnlockDuration duration) =>
      cost(CoinUnlockTarget.fullPremium, duration) < singleTotal(duration);
}
