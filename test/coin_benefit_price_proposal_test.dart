import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  test('final owner-approved price model never implies a live redemption', () {
    expect(CoinBenefitPriceCatalog.version, 'v5-shortterm-rebalanced-20261113');
    expect(
      CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.fullPremium,
        const CoinUnlockDuration(1, CoinDurationUnit.month),
      ),
      55000,
    );
  });

  test('annual Premium equals the Japanese yearly price × 100 coins', () {
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
      216000,
    );
  });

  test('all final unit prices round up to whole tens', () {
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
      2000,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.day,
      ),
      4000,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.week,
      ),
      9000,
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
      CoinUnlockTarget.endCardEdit: [2000, 4000, 9000, 12000],
      CoinUnlockTarget.watermark: [3000, 6000, 13500, 18000],
      CoinUnlockTarget.toneCurve: [3000, 6000, 13500, 18000],
      CoinUnlockTarget.levelAdjustment: [2500, 5000, 11250, 15000],
      CoinUnlockTarget.unlimitedDuration: [4170, 8340, 18750, 25000],
      CoinUnlockTarget.customAutomation: [4170, 8340, 18750, 25000],
      CoinUnlockTarget.projectListAds: [2000, 4000, 9000, 12000],
      CoinUnlockTarget.canvasAds: [3340, 6670, 15000, 20000],
      CoinUnlockTarget.timelineAds: [2670, 5340, 12000, 16000],
      CoinUnlockTarget.processingAds: [1670, 3340, 7500, 10000],
      CoinUnlockTarget.allAds: [6670, 13340, 30000, 40000],
      CoinUnlockTarget.fullPremium: [10000, 25000, 45000, 55000],
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
