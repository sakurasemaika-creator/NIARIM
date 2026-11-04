import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  const calculator = CoinUnlockQuoteCalculator();
  const examplePrices = CoinUnlockUnitPrices(
    perHour: 2,
    perDay: 30,
    perWeek: 180,
    perMonth: 650,
  );
  final prices = <CoinUnlockTarget, CoinUnlockUnitPrices>{
    for (final target in CoinUnlockTarget.values) target: examplePrices,
  };

  test('時間・日・週・月の刻みの境界を検証する', () {
    expect(
      const CoinUnlockDuration(24, CoinDurationUnit.hour).isValid,
      isTrue,
    );
    expect(
      const CoinUnlockDuration(2, CoinDurationUnit.day).isValid,
      isTrue,
    );
    expect(
      const CoinUnlockDuration(6, CoinDurationUnit.day).isValid,
      isTrue,
    );
    expect(
      const CoinUnlockDuration(1, CoinDurationUnit.week).isValid,
      isTrue,
    );
    expect(
      const CoinUnlockDuration(3, CoinDurationUnit.week).isValid,
      isTrue,
    );
    expect(
      const CoinUnlockDuration(1, CoinDurationUnit.month).isValid,
      isTrue,
    );
  });

  test('複数の機能を別々の期間で見積もりできる', () {
    final quote = calculator.calculate(
      selections: const [
        CoinUnlockSelection(
          target: CoinUnlockTarget.toneCurve,
          duration: CoinUnlockDuration(2, CoinDurationUnit.hour),
        ),
        CoinUnlockSelection(
          target: CoinUnlockTarget.canvasAds,
          duration: CoinUnlockDuration(3, CoinDurationUnit.day),
        ),
      ],
      prices: prices,
      priceVersion: 'sample',
    );
    expect(quote.requiredCoins, 94);
    expect(quote.missingCoins(40), 54);
    expect(quote.progress(40), closeTo(40 / 94, 1e-10));
    expect(quote.isAchieved(94), isTrue);
    expect(quote.isAchieved(93), isFalse);
    expect(quote.progress(120), 1);
    expect(quote.missingCoins(120), 0);
  });

  test('全Premiumと個別商品を重複請求しない', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(
            target: CoinUnlockTarget.fullPremium,
            duration: CoinUnlockDuration(1, CoinDurationUnit.month),
          ),
          CoinUnlockSelection(
            target: CoinUnlockTarget.toneCurve,
            duration: CoinUnlockDuration(1, CoinDurationUnit.hour),
          ),
        ],
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsArgumentError,
    );
  });

  test('全広告非表示と画面広告非表示を重複請求しない', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(
            target: CoinUnlockTarget.allAds,
            duration: CoinUnlockDuration(1, CoinDurationUnit.week),
          ),
          CoinUnlockSelection(
            target: CoinUnlockTarget.timelineAds,
            duration: CoinUnlockDuration(1, CoinDurationUnit.hour),
          ),
        ],
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsArgumentError,
    );
  });

  test('同一機能の二重指定を防ぐ', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(
            target: CoinUnlockTarget.watermark,
            duration: CoinUnlockDuration(1, CoinDurationUnit.hour),
          ),
          CoinUnlockSelection(
            target: CoinUnlockTarget.watermark,
            duration: CoinUnlockDuration(2, CoinDurationUnit.hour),
          ),
        ],
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsArgumentError,
    );
  });

  test('月末開始の暦月追加は次月末へ丸める', () {
    const oneMonth = CoinUnlockDuration(1, CoinDurationUnit.month);
    expect(
      oneMonth.previewExpiry(DateTime.utc(2027, 1, 31, 12)),
      DateTime.utc(2027, 2, 28, 12),
    );
    expect(
      oneMonth.previewExpiry(DateTime.utc(2028, 1, 31, 12)),
      DateTime.utc(2028, 2, 29, 12),
    );
    expect(
      oneMonth.previewExpiry(DateTime.utc(2027, 12, 31, 12)),
      DateTime.utc(2028, 1, 31, 12),
    );
  });

  test('交換レートを未設定にした場合は成功扱いしない', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(
            target: CoinUnlockTarget.toneCurve,
            duration: CoinUnlockDuration(1, CoinDurationUnit.hour),
          ),
        ],
        prices: const {},
        priceVersion: 'sample',
      ),
      throwsStateError,
    );
  });
}
