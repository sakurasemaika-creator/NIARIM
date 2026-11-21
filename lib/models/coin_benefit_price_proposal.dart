import 'coin_unlock_quote.dart';

/// Versioned Opal exchange prices for display and server quote checks.
abstract final class CoinBenefitPriceCatalog {
  static const version = 'v8-complete-pack-half-20261116';

  // Exchange prices in hour, day, week, and month order.
  static const _unitPrices = <CoinUnlockTarget, (int, int, int, int)>{
    CoinUnlockTarget.endCardEdit: (1_440, 2_880, 6_470, 8_620),
    CoinUnlockTarget.watermark: (2_160, 4_320, 9_710, 12_940),
    CoinUnlockTarget.toneCurve: (2_160, 4_320, 9_710, 12_940),
    CoinUnlockTarget.levelAdjustment: (1_800, 3_600, 8_090, 10_780),
    CoinUnlockTarget.unlimitedDuration: (3_000, 6_000, 13_490, 17_980),
    CoinUnlockTarget.customAutomation: (3_000, 6_000, 13_490, 17_980),
    CoinUnlockTarget.projectListAds: (1_440, 2_880, 6_470, 8_620),
    CoinUnlockTarget.canvasAds: (2_400, 4_800, 10_790, 14_380),
    CoinUnlockTarget.timelineAds: (1_920, 3_840, 8_630, 11_500),
    CoinUnlockTarget.processingAds: (1_200, 2_400, 5_390, 7_180),
    CoinUnlockTarget.allAds: (4_820, 9_580, 21_560, 28_760),
    CoinUnlockTarget.fullPremium: (9_190, 18_350, 41_260, 55_000),
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

  static int unitCoins(CoinUnlockTarget target, CoinDurationUnit unit) {
    final price = _unitPrices[target];
    if (price == null) throw StateError('No reference price for $target');
    return switch (unit) {
      CoinDurationUnit.hour => price.$1,
      CoinDurationUnit.day => price.$2,
      CoinDurationUnit.week => price.$3,
      CoinDurationUnit.month => price.$4,
    };
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
