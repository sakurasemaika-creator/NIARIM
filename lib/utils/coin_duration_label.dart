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
