import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  test('final owner-approved price model never implies a live redemption', () {
    expect(CoinBenefitPriceCatalog.version, 'v1-final-20261110');
    expect(CoinBenefitPriceCatalog.cost(
      CoinUnlockTarget.fullPremium,
      const CoinUnlockDuration(1, CoinDurationUnit.month),
    ), 60000);
  });

  test('all final unit prices round up to whole tens', () {
    for (final target in CoinUnlockTarget.values) {
      if (target == CoinUnlockTarget.communityPostQuota) continue;
      for (final unit in CoinDurationUnit.values) {
        final cost = CoinBenefitPriceCatalog.unitCoins(target, unit);
        expect(cost % 10, 0, reason: '$target / $unit');
      }
    }
    expect(CoinBenefitPriceCatalog.unitCoins(
      CoinUnlockTarget.endCardEdit, CoinDurationUnit.hour), 70);
    expect(CoinBenefitPriceCatalog.unitCoins(
      CoinUnlockTarget.endCardEdit, CoinDurationUnit.day), 290);
    expect(CoinBenefitPriceCatalog.unitCoins(
      CoinUnlockTarget.endCardEdit, CoinDurationUnit.week), 2170);
    expect(CoinBenefitPriceCatalog.unitCoins(
      CoinUnlockTarget.fullPremium, CoinDurationUnit.month), 60000);
  });

  test('all 48 final benefit rates match the approved launch tariff', () {
    const rates = <CoinUnlockTarget, List<int>>{
      CoinUnlockTarget.endCardEdit: [70, 290, 2170, 8000],
      CoinUnlockTarget.watermark: [120, 500, 3790, 14000],
      CoinUnlockTarget.toneCurve: [110, 470, 3520, 13000],
      CoinUnlockTarget.levelAdjustment: [90, 360, 2710, 10000],
      CoinUnlockTarget.unlimitedDuration: [150, 650, 4870, 18000],
      CoinUnlockTarget.customAutomation: [170, 720, 5410, 20000],
      CoinUnlockTarget.projectListAds: [80, 330, 2440, 9000],
      CoinUnlockTarget.canvasAds: [130, 540, 4060, 15000],
      CoinUnlockTarget.timelineAds: [100, 430, 3250, 12000],
      CoinUnlockTarget.processingAds: [50, 220, 1630, 6000],
      CoinUnlockTarget.allAds: [300, 1290, 9730, 36000],
      CoinUnlockTarget.fullPremium: [500, 2500, 18000, 60000],
    };
    for (final row in rates.entries) {
      expect(
        CoinDurationUnit.values.map((unit) =>
          CoinBenefitPriceCatalog.unitCoins(row.key, unit)).toList(),
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
      final duration=CoinUnlockDuration(
        unit==CoinDurationUnit.day ? 2 : 1, unit);
      final adPieces = [
        CoinUnlockTarget.projectListAds,
        CoinUnlockTarget.canvasAds,
        CoinUnlockTarget.timelineAds,
        CoinUnlockTarget.processingAds,
      ];
      final pieces = adPieces.fold(0, (n,target) =>
        n+CoinBenefitPriceCatalog.cost(target,duration));
      expect(CoinBenefitPriceCatalog.cost(
        CoinUnlockTarget.allAds,duration), lessThan(pieces));
    }
  });
}
