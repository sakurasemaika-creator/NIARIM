import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_economy_scale.dart';

void main() {
  test('initial rewarded-ad offer and reference coin scale', () {
    expect(CoinEconomyScale.initialRewardedCoinsPerCompletion, 10);
    expect(CoinEconomyScale.initialRewardOfferVersion, 'launch-v1-10-coins');
    expect(CoinEconomyScale.referenceCoinsPerYen, 100);
    expect(CoinEconomyScale.monthlyFullPremiumReferenceCoins, 55000);
    expect(CoinEconomyScale.yearlyFullPremiumReferenceCoins, 550000);
  });
}
