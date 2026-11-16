import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  test('final owner-approved price model never implies a live redemption', () {
    expect(CoinBenefitPriceCatalog.version, 'v7-complete-pack-anchor-20261116');
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(1, CoinDurationUnit.month),
      ),
      55000,
    );
  });

  test('12-month blocks cost ten monthly units for every benefit', () {
    expect(CoinBenefitPriceCatalog.yearlyPremiumCoins, 550000);
    const month = CoinDurationUnit.month;
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(12, month),
      ),
      550000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(13, month),
      ),
      605000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(24, month),
      ),
      1100000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(11, month),
      ),
      605000,
    );
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.toneCurve,
        const CoinUnlockDuration(12, month),
      ),
      80900,
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
      900,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.day,
      ),
      1800,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.week,
      ),
      4050,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.fullPremium,
        CoinDurationUnit.month,
      ),
      55000,
    );
  });

  test('all 48 final benefit rates match the approved launch tariff', () {
    const rates = <CoinUnlockTarget, List<int>>{
      CoinUnlockTarget.endCardEdit: [900, 1800, 4050, 5390],
      CoinUnlockTarget.watermark: [1350, 2700, 6070, 8090],
      CoinUnlockTarget.toneCurve: [1350, 2700, 6070, 8090],
      CoinUnlockTarget.levelAdjustment: [1130, 2250, 5060, 6740],
      CoinUnlockTarget.unlimitedDuration: [1880, 3750, 8430, 11240],
      CoinUnlockTarget.customAutomation: [1880, 3750, 8430, 11240],
      CoinUnlockTarget.projectListAds: [900, 1800, 4050, 5390],
      CoinUnlockTarget.canvasAds: [1500, 3000, 6750, 8990],
      CoinUnlockTarget.timelineAds: [1200, 2400, 5400, 7190],
      CoinUnlockTarget.processingAds: [750, 1500, 3370, 4490],
      CoinUnlockTarget.allAds: [3000, 5990, 13470, 17960],
      CoinUnlockTarget.fullPremium: [9190, 18350, 41260, 55000],
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

  test(
    'six production features plus All Ads match the individual-price comparison',
    () {
      expect(
        CoinDurationUnit.values.map(
          (unit) =>
              CoinBenefitPriceCatalog.singleTotal(CoinUnlockDuration(1, unit)),
        ),
        [11490, 22940, 51580, 68750],
      );
      expect(
        CoinBenefitPriceCatalog.singleTotal(
          const CoinUnlockDuration(12, CoinDurationUnit.month),
        ),
        687500,
      );
    },
  );

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
