/// リワードコインの見積もり・期間・重複延長の表示用ドメインモデル。
///
/// 権限、残高、広告収益による最低価格、消費、凍結・再開は認証済み
/// サーバー側のみを正とする。このモデルで交換成立を確定してはならない。
library;

import 'dart:math' as math;

enum CoinUnlockTarget {
  endCardEdit,
  watermark,
  toneCurve,
  levelAdjustment,
  unlimitedDuration,
  customAutomation,
  // 作品広場の投稿上限緩和は未実装。サーバー側実装確認まで交換不可。
  communityPostQuota,
  projectListAds,
  canvasAds,
  timelineAds,
  processingAds,
  allAds,
  fullPremium;

  bool get isRedeemableNow => this != CoinUnlockTarget.communityPostQuota;
}

enum CoinDurationUnit { hour, day, week, month }

/// 全チェック項目が共通して使う「ひとつの期間」。
class CoinUnlockDuration {
  const CoinUnlockDuration(this.amount, this.unit)
    : assert(amount > 0),
      assert(
        (unit == CoinDurationUnit.hour && amount <= 24) ||
            (unit == CoinDurationUnit.day && amount >= 2 && amount <= 6) ||
            (unit == CoinDurationUnit.week && amount >= 1 && amount <= 3) ||
            (unit == CoinDurationUnit.month && amount >= 1 && amount <= 120),
      );

  final int amount;
  final CoinDurationUnit unit;

  bool get isValid => switch (unit) {
        CoinDurationUnit.hour => amount >= 1 && amount <= 24,
        CoinDurationUnit.day => amount >= 2 && amount <= 6,
        CoinDurationUnit.week => amount >= 1 && amount <= 3,
        CoinDurationUnit.month => amount >= 1 && amount <= 120,
      };

  /// UIのプレビューに限定。正式な期限はサーバーのUTC時刻で確定。
  DateTime previewExpiry(DateTime activatedAt) {
    if (!isValid) throw StateError('Unsupported unlock duration');
    return switch (unit) {
      CoinDurationUnit.hour => activatedAt.add(Duration(hours: amount)),
      CoinDurationUnit.day => activatedAt.add(Duration(days: amount)),
      CoinDurationUnit.week => activatedAt.add(Duration(days: 7 * amount)),
      CoinDurationUnit.month => _addCalendarMonths(activatedAt, amount),
    };
  }

  static DateTime _addCalendarMonths(DateTime date, int months) {
    final monthZeroBased = date.month - 1 + months;
    final year = date.year + monthZeroBased ~/ 12;
    final month = monthZeroBased % 12 + 1;
    final lastDay = date.isUtc
        ? DateTime.utc(year, month + 1, 0).day
        : DateTime(year, month + 1, 0).day;
    final day = math.min(date.day, lastDay);
    return date.isUtc
        ? DateTime.utc(
            year, month, day, date.hour, date.minute, date.second,
            date.millisecond, date.microsecond,
          )
        : DateTime(
            year, month, day, date.hour, date.minute, date.second,
            date.millisecond, date.microsecond,
          );
  }
}

/// 交換レートはサーバー価格表から受け取る。こちらは表示用の演算のみ。
class CoinUnlockUnitPrices {
  const CoinUnlockUnitPrices({
    required this.perHour,
    required this.perDay,
    required this.perWeek,
    required this.perMonth,
  });

  final int perHour;
  final int perDay;
  final int perWeek;
  final int perMonth;

  int cost(CoinUnlockDuration duration) {
    if (!duration.isValid) throw StateError('Unsupported unlock duration');
    final unitPrice = switch (duration.unit) {
      CoinDurationUnit.hour => perHour,
      CoinDurationUnit.day => perDay,
      CoinDurationUnit.week => perWeek,
      CoinDurationUnit.month => perMonth,
    };
    if (unitPrice <= 0) throw StateError('Invalid exchange rate');
    return unitPrice * duration.amount;
  }
}

/// チェックボックスで選択する項目。時間は持たず、見積もりで一括指定する。
class CoinUnlockSelection {
  const CoinUnlockSelection({required this.target});
  final CoinUnlockTarget target;
}

class CoinUnlockQuote {
  const CoinUnlockQuote({
    required this.selections,
    required this.duration,
    required this.requiredCoins,
    required this.priceVersion,
  });

  final List<CoinUnlockSelection> selections;
  final CoinUnlockDuration duration;
  final int requiredCoins;
  final String priceVersion;

  int missingCoins(int balance) => math.max(requiredCoins - balance, 0);
  bool isAchieved(int balance) => balance >= requiredCoins;

  double progress(int balance) {
    if (requiredCoins <= 0) return 0;
    return (balance / requiredCoins).clamp(0.0, 1.0).toDouble();
  }
}

/// 同じコイン交換で選んだすべての特典を、一つの期間で見積もる。
/// fullPremiumはサーバーが計算した収益下限を渡さなければ計算不能にする。
class CoinUnlockQuoteCalculator {
  const CoinUnlockQuoteCalculator();

  CoinUnlockQuote calculate({
    required List<CoinUnlockSelection> selections,
    required CoinUnlockDuration duration,
    required Map<CoinUnlockTarget, CoinUnlockUnitPrices> prices,
    required String priceVersion,
    int? fullPremiumMinimumCoins,
  }) {
    if (priceVersion.trim().isEmpty) {
      throw ArgumentError.value(priceVersion, 'priceVersion');
    }
    if (!duration.isValid) throw ArgumentError('Unsupported duration');
    if (selections.isEmpty) {
      throw ArgumentError('At least one unlock must be selected');
    }

    final targets = <CoinUnlockTarget>{};
    for (final selection in selections) {
      if (!selection.target.isRedeemableNow) {
        throw StateError('Premium entitlement is not implemented');
      }
      if (!targets.add(selection.target)) {
        throw ArgumentError('Duplicate unlock target: ${selection.target}');
      }
      if (!prices.containsKey(selection.target)) {
        throw StateError('Missing prices: ${selection.target}');
      }
    }
    if (targets.contains(CoinUnlockTarget.fullPremium) && targets.length > 1) {
      throw ArgumentError('Full Premium cannot overlap other unlocks');
    }

    final hasIndividualAds = targets.any((target) =>
        target == CoinUnlockTarget.projectListAds ||
        target == CoinUnlockTarget.canvasAds ||
        target == CoinUnlockTarget.timelineAds ||
        target == CoinUnlockTarget.processingAds);
    if (targets.contains(CoinUnlockTarget.allAds) && hasIndividualAds) {
      throw ArgumentError('All ads cannot overlap ad placements');
    }

    var total = 0;
    for (final selection in selections) {
      total += prices[selection.target]!.cost(duration);
    }

    if (targets.contains(CoinUnlockTarget.fullPremium)) {
      if (fullPremiumMinimumCoins == null || fullPremiumMinimumCoins <= 0) {
        throw StateError('Full Premium revenue floor has not been verified');
      }
      // サーバー側の保守的な収益下限を下回るレートの配布を防ぐ。
      // この比較自体が広告の最終精算を保証するわけではない。
      if (total < fullPremiumMinimumCoins) {
        throw StateError('Full Premium price is below the revenue floor');
      }
    }

    return CoinUnlockQuote(
      selections: List.unmodifiable(selections),
      duration: duration,
      requiredCoins: total,
      priceVersion: priceVersion,
    );
  }

  /// 「最もお得」バッジはコインで同じ期間・同じ権利を揃えた場合のみ表示。
  bool isFullPremiumBestValue({
    required CoinUnlockDuration duration,
    required Map<CoinUnlockTarget, CoinUnlockUnitPrices> prices,
    required Iterable<CoinUnlockTarget> comparisonTargets,
    required int fullPremiumMinimumCoins,
  }) {
    if (!duration.isValid || fullPremiumMinimumCoins <= 0) return false;
    final bundle = prices[CoinUnlockTarget.fullPremium];
    if (bundle == null) return false;
    final bundleCost = bundle.cost(duration);
    if (bundleCost < fullPremiumMinimumCoins) return false;
    final individualTargets = comparisonTargets.toSet();
    if (individualTargets.isEmpty ||
        individualTargets.contains(CoinUnlockTarget.fullPremium) ||
        individualTargets.contains(CoinUnlockTarget.communityPostQuota)) {
      return false;
    }
    var separateCost = 0;
    for (final target in individualTargets) {
      final unitPrices = prices[target];
      if (unitPrices == null) return false;
      separateCost += unitPrices.cost(duration);
    }
    return bundleCost < separateCost;
  }
}

/// 新規コイン交換時の表示用プレビュー。既存の同一特典に残り時間がある
/// 場合は先に取得済みの権利を失わないよう、後ろに共通期間を足す。
/// bundleが他の権利を包含する場合の一時停止・再開はサーバーが処理する。
class CoinOverlapPreview {
  const CoinOverlapPreview({
    required this.target,
    required this.startsAt,
    required this.expiresAt,
    required this.extendsExisting,
  });

  final CoinUnlockTarget target;
  final DateTime startsAt;
  final DateTime expiresAt;
  final bool extendsExisting;
}

class CoinOverlapPlanner {
  const CoinOverlapPlanner();

  List<CoinOverlapPreview> preview({
    required CoinUnlockQuote quote,
    required DateTime now,
    required Map<CoinUnlockTarget, DateTime> activeThrough,
    required bool subscriptionActive,
  }) {
    if (subscriptionActive) {
      throw StateError('Subscription already covers these Premium rights');
    }
    return List.unmodifiable(quote.selections.map((selection) {
      final lastExpiry = activeThrough[selection.target];
      final extendsExisting =
          lastExpiry != null && lastExpiry.isAfter(now);
      final startsAt = extendsExisting ? lastExpiry : now;
      return CoinOverlapPreview(
        target: selection.target,
        startsAt: startsAt,
        expiresAt: quote.duration.previewExpiry(startsAt),
        extendsExisting: extendsExisting,
      );
    }));
  }
}
