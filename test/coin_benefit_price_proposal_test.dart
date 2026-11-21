import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  test('final owner-approved price model never implies a live redemption', () {
    expect(CoinBenefitPriceCatalog.version, 'v8-complete-pack-half-20261116');
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
      129400,
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
      1440,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.day,
      ),
      2880,
    );
    expect(
      CoinBenefitPriceCatalog.unitCoins(
        CoinUnlockTarget.endCardEdit,
        CoinDurationUnit.week,
      ),
      6470,
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
      CoinUnlockTarget.endCardEdit: [1440, 2880, 6470, 8620],
      CoinUnlockTarget.watermark: [2160, 4320, 9710, 12940],
      CoinUnlockTarget.toneCurve: [2160, 4320, 9710, 12940],
      CoinUnlockTarget.levelAdjustment: [1800, 3600, 8090, 10780],
      CoinUnlockTarget.unlimitedDuration: [3000, 6000, 13490, 17980],
      CoinUnlockTarget.customAutomation: [3000, 6000, 13490, 17980],
      CoinUnlockTarget.projectListAds: [1440, 2880, 6470, 8620],
      CoinUnlockTarget.canvasAds: [2400, 4800, 10790, 14380],
      CoinUnlockTarget.timelineAds: [1920, 3840, 8630, 11500],
      CoinUnlockTarget.processingAds: [1200, 2400, 5390, 7180],
      CoinUnlockTarget.allAds: [4820, 9580, 21560, 28760],
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
        [18380, 36700, 82520, 110000],
      );
      expect(
        CoinBenefitPriceCatalog.singleTotal(
          const CoinUnlockDuration(12, CoinDurationUnit.month),
        ),
        1100000,
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
