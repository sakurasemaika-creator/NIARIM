import '../l10n/app_localizations.dart';
import '../models/coin_unlock_quote.dart';

/// 特典交換の期間の文言（「1時間」「2日間」「1 hour」「2 hours」…）。
///
/// 数と単位は翻訳の文言の中でつなぐ。コードで数の後ろへ単位の語を足すと、
/// 単数形と数の後ろの空白が要る言語で「1hours」になり、空白を足せば
/// 空白の要らない言語で「1 か月」になる。
String coinUnlockDurationLabel(
  AppLocalizations l10n,
  CoinUnlockDuration duration,
) => switch (duration.unit) {
  CoinDurationUnit.hour => l10n.rewardDurationHours(duration.amount),
  CoinDurationUnit.day => l10n.rewardDurationDays(duration.amount),
  CoinDurationUnit.week => l10n.rewardDurationWeeks(duration.amount),
  CoinDurationUnit.month => l10n.rewardDurationMonths(duration.amount),
};

/// ミッションの目標・進み具合の時間（サーバーは秒で返す）。1時間以上は
/// 「時間」、それより短ければ「分」で出す（「10分」「1時間」「10 minutes」）。
String missionDurationLabel(AppLocalizations l10n, int seconds) =>
    seconds >= 3600
    ? l10n.missionDurationHours(seconds ~/ 3600)
    : l10n.missionDurationMinutes(seconds ~/ 60);
