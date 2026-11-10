import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  test('reference price model never implies a live redemption', () {
    expect(CoinBenefitPriceProposal.version, 'proposal-v2-rounded10');
    expect(CoinBenefitPriceProposal.cost(
      CoinUnlockTarget.fullPremium,
      const CoinUnlockDuration(1, CoinDurationUnit.month),
    ), 60000);
  });

  test('all reference unit prices round up to whole tens', () {
    for (final target in CoinUnlockTarget.values) {
      if (target == CoinUnlockTarget.communityPostQuota) continue;
      for (final unit in CoinDurationUnit.values) {
        final cost = CoinBenefitPriceProposal.unitCoins(target, unit);
        expect(cost % 10, 0, reason: '$target / $unit');
      }
    }
    expect(CoinBenefitPriceProposal.unitCoins(
      CoinUnlockTarget.endCardEdit, CoinDurationUnit.hour), 70);
    expect(CoinBenefitPriceProposal.unitCoins(
      CoinUnlockTarget.endCardEdit, CoinDurationUnit.day), 290);
    expect(CoinBenefitPriceProposal.unitCoins(
      CoinUnlockTarget.endCardEdit, CoinDurationUnit.week), 2170);
    expect(CoinBenefitPriceProposal.unitCoins(
      CoinUnlockTarget.fullPremium, CoinDurationUnit.month), 60000);
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
      expect(CoinBenefitPriceProposal.bundleIsCheaper(period), isTrue);
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
        n+CoinBenefitPriceProposal.cost(target,duration));
      expect(CoinBenefitPriceProposal.cost(
        CoinUnlockTarget.allAds,duration), lessThan(pieces));
    }
  });
}
