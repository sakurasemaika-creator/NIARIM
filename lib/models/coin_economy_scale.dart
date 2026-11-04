/// NIARIM reward coin denomination and reference plan-price display.
///
/// This is a NON-CASH comparison scale, not an exchange rate, a value of a
/// rewarded impression, or a promise that a coin can be bought/redeemed for
/// yen. Coins are non-transferable and non-convertible into money.
///
/// Never derive actual coin rewards or spendable quotes from these constants.
/// Those must come from authenticated, server-versioned settings after
/// verifying the AdMob ad unit reward and conservative revenue assumptions.
library;

abstract final class CoinEconomyScale {
  /// Product design reference: 1 yen of displayed plan price maps to 100 coins.
  static const int referenceCoinsPerYen = 100;

  /// Premium plan reference prices only; not active redemption prices.
  static const int monthlyPlanYen = 550;
  static const int yearlyPlanYen = 5500;

  static const int monthlyFullPremiumReferenceCoins =
      monthlyPlanYen * referenceCoinsPerYen;
  static const int yearlyFullPremiumReferenceCoins =
      yearlyPlanYen * referenceCoinsPerYen;

  /// Used for an integer-only reference display, never actual ad income.
  static int referenceCoinsForPlanYen(int yen) {
    if (yen < 0) throw ArgumentError.value(yen, 'yen');
    return yen * referenceCoinsPerYen;
  }
}
