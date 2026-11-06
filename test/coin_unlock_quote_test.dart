import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/coin_unlock_quote.dart';

void main() {
  const calculator = CoinUnlockQuoteCalculator();
  const samplePrices = CoinUnlockUnitPrices(
    perHour: 2,
    perDay: 30,
    perWeek: 180,
    perMonth: 650,
  );
  final prices = <CoinUnlockTarget, CoinUnlockUnitPrices>{
    for (final target in CoinUnlockTarget.values) target: samplePrices,
  };

  test('時間・日・週・月の境界を共通期間で扱う', () {
    expect(const CoinUnlockDuration(24, CoinDurationUnit.hour).isValid, isTrue);
    expect(const CoinUnlockDuration(2, CoinDurationUnit.day).isValid, isTrue);
    expect(const CoinUnlockDuration(6, CoinDurationUnit.day).isValid, isTrue);
    expect(const CoinUnlockDuration(1, CoinDurationUnit.week).isValid, isTrue);
    expect(const CoinUnlockDuration(3, CoinDurationUnit.week).isValid, isTrue);
    expect(const CoinUnlockDuration(1, CoinDurationUnit.month).isValid, isTrue);
  });

  test('複数チェック項目に必ず同一の期間が適用される', () {
    final quote = calculator.calculate(
      selections: const [
        CoinUnlockSelection(target: CoinUnlockTarget.toneCurve),
        CoinUnlockSelection(target: CoinUnlockTarget.canvasAds),
      ],
      duration: const CoinUnlockDuration(3, CoinDurationUnit.day),
      prices: prices,
      priceVersion: 'sample',
    );
    expect(quote.duration.amount, 3);
    expect(quote.duration.unit, CoinDurationUnit.day);
    expect(quote.requiredCoins, 180);
    expect(quote.missingCoins(40), 140);
    expect(quote.progress(40), closeTo(40 / 180, 1e-10));
    expect(quote.isAchieved(179), isFalse);
    expect(quote.isAchieved(180), isTrue);
    expect(quote.progress(200), 1);
  });

  test('Full Premiumと個別商品を同時交換不可', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.fullPremium),
          CoinUnlockSelection(target: CoinUnlockTarget.toneCurve),
        ],
        duration: const CoinUnlockDuration(1, CoinDurationUnit.month),
        prices: prices,
        priceVersion: 'sample',
        fullPremiumMinimumCoins: 600,
      ),
      throwsArgumentError,
    );
  });

  test('全広告なしと個別の広告非表示を重複請求しない', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.allAds),
          CoinUnlockSelection(target: CoinUnlockTarget.timelineAds),
        ],
        duration: const CoinUnlockDuration(1, CoinDurationUnit.week),
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsArgumentError,
    );
  });

  test('同一機能の二重選択を防ぐ', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.watermark),
          CoinUnlockSelection(target: CoinUnlockTarget.watermark),
        ],
        duration: const CoinUnlockDuration(1, CoinDurationUnit.hour),
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsArgumentError,
    );
  });

  test('未実装の作品広場投稿上限緩和ではコイン交換できない', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.communityPostQuota),
        ],
        duration: const CoinUnlockDuration(2, CoinDurationUnit.day),
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsStateError,
    );
  });

  test('Full Premiumはサーバーで確認済みの最低価格なしでは不可', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.fullPremium),
        ],
        duration: const CoinUnlockDuration(1, CoinDurationUnit.month),
        prices: prices,
        priceVersion: 'sample',
      ),
      throwsStateError,
    );
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.fullPremium),
        ],
        duration: const CoinUnlockDuration(1, CoinDurationUnit.month),
        prices: prices,
        priceVersion: 'sample',
        fullPremiumMinimumCoins: 700,
      ),
      throwsStateError,
    );
    final quote = calculator.calculate(
      selections: const [
        CoinUnlockSelection(target: CoinUnlockTarget.fullPremium),
      ],
      duration: const CoinUnlockDuration(1, CoinDurationUnit.month),
      prices: prices,
      priceVersion: 'sample',
      fullPremiumMinimumCoins: 600,
    );
    expect(quote.requiredCoins, 650);
  });

  test('実際に一括商品が安い場合のみ「最もお得」とする', () {
    expect(
      calculator.isFullPremiumBestValue(
        duration: const CoinUnlockDuration(1, CoinDurationUnit.month),
        prices: prices,
        comparisonTargets: const [
          CoinUnlockTarget.toneCurve,
          CoinUnlockTarget.watermark,
          CoinUnlockTarget.allAds,
        ],
        fullPremiumMinimumCoins: 600,
      ),
      isTrue,
    );
    expect(
      calculator.isFullPremiumBestValue(
        duration: const CoinUnlockDuration(1, CoinDurationUnit.month),
        prices: prices,
        comparisonTargets: const [CoinUnlockTarget.toneCurve],
        fullPremiumMinimumCoins: 600,
      ),
      isFalse,
    );
  });

  test('既存のリワード利用時間は新規交換で後ろに延長される', () {
    final quote = calculator.calculate(
      selections: const [
        CoinUnlockSelection(target: CoinUnlockTarget.toneCurve),
        CoinUnlockSelection(target: CoinUnlockTarget.canvasAds),
      ],
      duration: const CoinUnlockDuration(3, CoinDurationUnit.hour),
      prices: prices,
      priceVersion: 'sample',
    );
    final now = DateTime.utc(2027, 2, 1, 12);
    final currentToneExpiry = now.add(const Duration(hours: 5));
    final preview = const CoinOverlapPlanner().preview(
      quote: quote,
      now: now,
      activeThrough: {CoinUnlockTarget.toneCurve: currentToneExpiry},
      subscriptionActive: false,
    );
    expect(preview[0].extendsExisting, isTrue);
    expect(preview[0].startsAt, currentToneExpiry);
    expect(preview[0].expiresAt, now.add(const Duration(hours: 8)));
    expect(preview[1].extendsExisting, isFalse);
    expect(preview[1].startsAt, now);
    expect(preview[1].expiresAt, now.add(const Duration(hours: 3)));
    expect(
      () => const CoinOverlapPlanner().preview(
        quote: quote,
        now: now,
        activeThrough: const {},
        subscriptionActive: true,
      ),
      throwsStateError,
    );
  });

  test('暦月追加は月末で丸め、うるう年も考慮する', () {
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

  test('交換レートが未設定なら見積もり成立にしない', () {
    expect(
      () => calculator.calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.toneCurve),
        ],
        duration: const CoinUnlockDuration(1, CoinDurationUnit.hour),
        prices: const {},
        priceVersion: 'sample',
      ),
      throwsStateError,
    );
  });
}
