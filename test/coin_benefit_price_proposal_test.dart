import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  test('final owner-approved price model never implies a live redemption', () {
    expect(CoinBenefitPriceCatalog.version, 'v6-subscription-aligned-20261116');
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(1, CoinDurationUnit.month),
      ),
      44000,
    );
  });

  test('12-month blocks cost ten monthly units for every benefit', () {
    expect(CoinBenefitPriceCatalog.yearlyPremiumCoins, 440000);
    const month = CoinDurationUnit.month;
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(12, month),
      ),
      440000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(13, month),
      ),
      484000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(24, month),
      ),
      880000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(11, month),
      ),
      484000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.toneCurve,
        const CoinUnlockDuration(12, month),
      ),
      64700,
    );
  });

  test('all final unit prices are whole tens', () {
    for (final target in CoinUnlockTarget.values) {
      if (target == CoinUnlockTarget.communityPostQuota) continue;
      for (final unit in CoinDurationUnit.values) {
        final cost = CoinBenefitPriceCatalog.unitCoins(target, unit);
        expect(cost % 10, 0, reason: '$target / $unit');
      }
    }
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.hour,
      ),
      720,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.day,
      ),
      1440,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.week,
      ),
      3240,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.fullPremium,
        CoinDurationUnit.month,
      ),
      44000,
    );
  });

  test('all 48 final benefit rates match the approved launch tariff', () {
    const rates = <CoinUnlockTarget, List<int>>{
      CoinUnlockTarget.endCardEdit: [720, 1440, 3240, 4310],
      CoinUnlockTarget.watermark: [1080, 2160, 4860, 6470],
      CoinUnlockTarget.toneCurve: [1080, 2160, 4860, 6470],
      CoinUnlockTarget.levelAdjustment: [900, 1800, 4050, 5390],
      CoinUnlockTarget.unlimitedDuration: [1500, 3000, 6750, 8990],
      CoinUnlockTarget.customAutomation: [1500, 3000, 6750, 8990],
      CoinUnlockTarget.projectListAds: [720, 1440, 3240, 4310],
      CoinUnlockTarget.canvasAds: [1200, 2400, 5400, 7190],
      CoinUnlockTarget.timelineAds: [960, 1920, 4320, 5750],
      CoinUnlockTarget.processingAds: [600, 1200, 2700, 3590],
      CoinUnlockTarget.allAds: [2400, 4800, 10790, 14380],
      CoinUnlockTarget.fullPremium: [7340, 14690, 33040, 44000],
    };
    for (final row in rates.entries) {
      expect(
        CoinDurationUnit.values
            .map((unit) => CoinBenefitPriceCatalog.unitCoins(row.key, unit))
            .toList(),
        row.value,
        reason: 'Final catalog drift: ${row.key}',
      );
    }
  });

  test('full Premium is strictly cheaper than all individual features', () {
    final periods = <CoinUnlockDuration>[
      const CoinUnlockDuration(1, CoinDurationUnit.hour),
      const CoinUnlockDuration(24, CoinDurationUnit.hour),
      const CoinUnlockDuration(2, CoinDurationUnit.day),
      const CoinUnlockDuration(6, CoinDurationUnit.day),
      const CoinUnlockDuration(1, CoinDurationUnit.week),
      const CoinUnlockDuration(3, CoinDurationUnit.week),
      const CoinUnlockDuration(1, CoinDurationUnit.month),
      const CoinUnlockDuration(12, CoinDurationUnit.month),
    ];
    for (final period in periods) {
      expect(CoinBenefitPriceCatalog.bundleIsCheaper(period), isTrue);
    }
  });

  test('six production features plus All Ads match the subscription basis', () {
    expect(
      CoinDurationUnit.values.map(
        (unit) =>
            CoinBenefitPriceCatalog.singleTotal(CoinUnlockDuration(1, unit)),
      ),
      [9180, 18360, 41300, 55000],
    );
    expect(
      CoinBenefitPriceCatalog.singleTotal(
        const CoinUnlockDuration(12, CoinDurationUnit.month),
      ),
      550000,
    );
  });

  test('all-ads bundle is cheaper than buying separate ad removals', () {
    for (final unit in CoinDurationUnit.values) {
      final duration = CoinUnlockDuration(
        unit == CoinDurationUnit.day ? 2 : 1,
        unit,
      );
      final adPieces = [
        CoinUnlockTarget.projectListAds,
        CoinUnlockTarget.canvasAds,
        CoinUnlockTarget.timelineAds,
        CoinUnlockTarget.processingAds,
      ];
      final pieces = adPieces.fold(
        0,
        (n, target) => n + CoinBenefitPriceCatalog.cost(target, duration),
      );
      expect(
        CoinBenefitPriceCatalog.cost(CoinUnlockTarget.allAds, duration),
        lessThan(pieces),
      );
    }
  });
}
