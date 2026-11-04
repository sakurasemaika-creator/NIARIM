/// リワードコインの見積もりで使用する純粋なドメインモデル。
///
/// このファイルはクライアントの表示・事前試算専用。コインの付与・消費、
/// 視聴完了検証、正規の交換価格、利用権の失効時刻は必ずバックエンドが確定する。
/// 現時点では本番用の価格定数を持たない。
library;

import 'dart:math' as math;

enum CoinUnlockTarget {
  endCardEdit,
  watermark,
  toneCurve,
  levelAdjustment,
  unlimitedDuration,
  customAutomation,
  projectListAds,
  canvasAds,
  timelineAds,
  processingAds,
  allAds,
  fullPremium,
}

enum CoinDurationUnit { hour, day, week, month }

/// UIは1〜24時間、2〜6日、1〜3週間、1か月以上から選択する。
/// 1日=24時間、1週間=7日、1か月=暦月（28〜31日）。
class CoinUnlockDuration {
  const CoinUnlockDuration(this.amount, this.unit)
    : assert(amount > 0),
      assert(
        (unit == CoinDurationUnit.hour && amount <= 24) ||
            (unit == CoinDurationUnit.day && amount >= 2 && amount <= 6) ||
            (unit == CoinDurationUnit.week && amount <= 3) ||
            (unit == CoinDurationUnit.month && amount >= 1),
      );

  final int amount;
  final CoinDurationUnit unit;

  /// 不正データがサーバーなどから届いてもreleaseビルドで黙認しない。
  bool get isValid =>
      switch (unit) {
        CoinDurationUnit.hour => amount >= 1 && amount <= 24,
        CoinDurationUnit.day => amount >= 2 && amount <= 6,
        CoinDurationUnit.week => amount >= 1 && amount <= 3,
        CoinDurationUnit.month => amount >= 1 && amount <= 120,
      };

  /// サーバーが計算した期限を正として使い、この関数は見積もり表示のみ。
  /// 暦月は月末（31日など）を次月の末日に丸める。
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
    final finalDay = date.isUtc
        ? DateTime.utc(year, month + 1, 0).day
        : DateTime(year, month + 1, 0).day;
    final day = math.min(date.day, finalDay);
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

/// 対象ごとの単価表。額面はAPI側で決める。0枚や負数は不正価格。
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

class CoinUnlockSelection {
  const CoinUnlockSelection({
    required this.target,
    required this.duration,
  });

  final CoinUnlockTarget target;
  final CoinUnlockDuration duration;
}

class CoinUnlockQuote {
  const CoinUnlockQuote({
    required this.selections,
    required this.requiredCoins,
    required this.priceVersion,
  });

  final List<CoinUnlockSelection> selections;
  final int requiredCoins;

  /// サーバー価格表のバージョン。目標保存時にもセットで保持する。
  final String priceVersion;

  int missingCoins(int balance) => math.max(requiredCoins - balance, 0);
  bool isAchieved(int balance) => balance >= requiredCoins;

  double progress(int balance) {
    if (requiredCoins <= 0) return 0;
    return (balance / requiredCoins).clamp(0.0, 1.0).toDouble();
  }
}

/// ユーザーが複数の対象・期間を指定した時に即時計算するための見積もり。
/// この結果を使って直接コインを減らしてはならない。
class CoinUnlockQuoteCalculator {
  const CoinUnlockQuoteCalculator();

  CoinUnlockQuote calculate({
    required List<CoinUnlockSelection> selections,
    required Map<CoinUnlockTarget, CoinUnlockUnitPrices> prices,
    required String priceVersion,
  }) {
    if (priceVersion.trim().isEmpty) {
      throw ArgumentError.value(priceVersion, 'priceVersion');
    }
    if (selections.isEmpty) {
      throw ArgumentError('At least one unlock must be selected');
    }
    final targets = <CoinUnlockTarget>{};
    for (final selection in selections) {
      if (!selection.duration.isValid) {
        throw ArgumentError('Unsupported duration: ${selection.target}');
      }
      if (!targets.add(selection.target)) {
        throw ArgumentError('Duplicate unlock target: ${selection.target}');
      }
      if (!prices.containsKey(selection.target)) {
        throw StateError('Missing prices: ${selection.target}');
      }
    }

    // 一括商品を個別対象と重複請求しない。画面側では一括商品を選んだ
    // 時点で被る個別項目を解除し、サーバー側も同じ条件で再検証する。
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

    var requiredCoins = 0;
    for (final selection in selections) {
      requiredCoins += prices[selection.target]!.cost(selection.duration);
    }
    return CoinUnlockQuote(
      selections: List.unmodifiable(selections),
      requiredCoins: requiredCoins,
      priceVersion: priceVersion,
    );
  }
}
