import 'dart:ui';

import 'package:niarim/models/coin_unlock_quote.dart';

/// 特典交換で選べる152通りの期間（1〜24時間・2〜6日・1〜3週間・1〜120か月）。
/// 画面やモデルから取らず、仕様の範囲をここに書いてある。
final List<CoinUnlockDuration> offeredRewardDurations = [
  for (var i = 1; i <= 24; i++) CoinUnlockDuration(i, CoinDurationUnit.hour),
  for (var i = 2; i <= 6; i++) CoinUnlockDuration(i, CoinDurationUnit.day),
  for (var i = 1; i <= 3; i++) CoinUnlockDuration(i, CoinDurationUnit.week),
  for (var i = 1; i <= 120; i++) CoinUnlockDuration(i, CoinDurationUnit.month),
];

/// 1つの表示言語での交換期間の書き方（テストの正解表）。
class RewardDurationLanguage {
  const RewardDurationLanguage({
    required this.code,
    required this.locale,
    required this.spaced,
    required this.units,
    required this.pinned,
    required this.redeemConfirmation,
  });

  final String code;
  final Locale locale;

  /// 数と単位の間に空白を入れる言語か（英語・スペイン語・フランス語）。
  final bool spaced;

  /// 単位ごとの（1のときの形, 2以上のときの形）。
  final Map<CoinDurationUnit, (String, String)> units;

  /// 「単位_数」ごとの、手で書いた正解の文言。
  final Map<String, String> pinned;

  /// 全機能を55000コインで1か月と引き換えるときの確認の文。
  final String redeemConfirmation;

  String label(CoinUnlockDuration duration) {
    final (one, other) = units[duration.unit]!;
    final separator = spaced ? ' ' : '';
    return '${duration.amount}$separator${duration.amount == 1 ? one : other}';
  }
}

const rewardDurationLanguages = <RewardDurationLanguage>[
  RewardDurationLanguage(
    code: 'ja',
    locale: Locale('ja'),
    spaced: false,
    units: {
      CoinDurationUnit.hour: ('時間', '時間'),
      CoinDurationUnit.day: ('日間', '日間'),
      CoinDurationUnit.week: ('週間', '週間'),
      CoinDurationUnit.month: ('か月', 'か月'),
    },
    pinned: {
      'hour_2': '2時間',
      'day_2': '2日間',
      'week_1': '1週間',
      'month_1': '1か月',
      'month_12': '12か月',
      'hour_1': '1時間',
    },
    redeemConfirmation: '全機能＋全広告なし · 1か月 · 55000 コイン',
  ),
  RewardDurationLanguage(
    code: 'en',
    locale: Locale('en'),
    spaced: true,
    units: {
      CoinDurationUnit.hour: ('hour', 'hours'),
      CoinDurationUnit.day: ('day', 'days'),
      CoinDurationUnit.week: ('week', 'weeks'),
      CoinDurationUnit.month: ('month', 'months'),
    },
    pinned: {
      'hour_2': '2 hours',
      'day_2': '2 days',
      'week_1': '1 week',
      'month_1': '1 month',
      'month_12': '12 months',
      'hour_1': '1 hour',
    },
    redeemConfirmation: 'All features + no ads · 1 month · 55000 coins',
  ),
  RewardDurationLanguage(
    code: 'es',
    locale: Locale('es'),
    spaced: true,
    units: {
      CoinDurationUnit.hour: ('hora', 'horas'),
      CoinDurationUnit.day: ('día', 'días'),
      CoinDurationUnit.week: ('semana', 'semanas'),
      CoinDurationUnit.month: ('mes', 'meses'),
    },
    pinned: {
      'hour_2': '2 horas',
      'day_2': '2 días',
      'week_1': '1 semana',
      'month_1': '1 mes',
      'month_12': '12 meses',
      'hour_1': '1 hora',
    },
    redeemConfirmation:
        'Todas las funciones y sin anuncios · 1 mes · 55000 monedas',
  ),
  RewardDurationLanguage(
    code: 'fr',
    locale: Locale('fr'),
    spaced: true,
    units: {
      CoinDurationUnit.hour: ('heure', 'heures'),
      CoinDurationUnit.day: ('jour', 'jours'),
      CoinDurationUnit.week: ('semaine', 'semaines'),
      CoinDurationUnit.month: ('mois', 'mois'),
    },
    pinned: {
      'hour_2': '2 heures',
      'day_2': '2 jours',
      'week_1': '1 semaine',
      'month_1': '1 mois',
      'month_12': '12 mois',
      'hour_1': '1 heure',
    },
    redeemConfirmation:
        'Toutes les fonctions sans publicité · 1 mois · 55000 pièces',
  ),
  RewardDurationLanguage(
    code: 'ko',
    locale: Locale('ko'),
    spaced: false,
    units: {
      CoinDurationUnit.hour: ('시간', '시간'),
      CoinDurationUnit.day: ('일', '일'),
      CoinDurationUnit.week: ('주', '주'),
      CoinDurationUnit.month: ('개월', '개월'),
    },
    pinned: {
      'hour_2': '2시간',
      'day_2': '2일',
      'week_1': '1주',
      'month_1': '1개월',
      'month_12': '12개월',
      'hour_1': '1시간',
    },
    redeemConfirmation: '전체 기능 + 광고 없음 · 1개월 · 55000 코인',
  ),
  RewardDurationLanguage(
    code: 'zh',
    locale: Locale('zh'),
    spaced: false,
    units: {
      CoinDurationUnit.hour: ('小时', '小时'),
      CoinDurationUnit.day: ('天', '天'),
      CoinDurationUnit.week: ('周', '周'),
      CoinDurationUnit.month: ('个月', '个月'),
    },
    pinned: {
      'hour_2': '2小时',
      'day_2': '2天',
      'week_1': '1周',
      'month_1': '1个月',
      'month_12': '12个月',
      'hour_1': '1小时',
    },
    redeemConfirmation: '全部功能＋无广告 · 1个月 · 55000 金币',
  ),
  RewardDurationLanguage(
    code: 'zh_Hant',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    spaced: false,
    units: {
      CoinDurationUnit.hour: ('小時', '小時'),
      CoinDurationUnit.day: ('天', '天'),
      CoinDurationUnit.week: ('週', '週'),
      CoinDurationUnit.month: ('個月', '個月'),
    },
    pinned: {
      'hour_2': '2小時',
      'day_2': '2天',
      'week_1': '1週',
      'month_1': '1個月',
      'month_12': '12個月',
      'hour_1': '1小時',
    },
    redeemConfirmation: '全部功能＋無廣告 · 1個月 · 55000 金幣',
  ),
];

final _digitThenLatinLetter = RegExp(r'\d\p{Script=Latin}', unicode: true);
final _numberSpaceWord = RegExp(r'^(\d+) (\S+)$');
final _numberThenCounter = RegExp(r'^(\d+)([^\d\s]+)$');

/// [label]が[language]の書き方の決まりに反していれば、その理由。
/// 正解表（[RewardDurationLanguage.label]）と突き合わせるのとは別に、
/// 「数字のすぐ後ろにラテン文字」「1なのに複数形」「数と助数詞の間の空白」を
/// 1件ずつ見る。
String? rewardDurationLabelProblem(
  RewardDurationLanguage language,
  CoinUnlockDuration duration,
  String label,
) {
  if (_digitThenLatinLetter.hasMatch(label)) {
    return '数字のすぐ後ろにラテン文字が続いている';
  }
  final (one, other) = language.units[duration.unit]!;
  if (language.spaced) {
    final match = _numberSpaceWord.firstMatch(label);
    if (match == null) return '「数 空白1つ 単位」の形になっていない';
    if (match.group(1) != '${duration.amount}') return '数が違う';
    final word = match.group(2)!;
    if (duration.amount == 1 && one != other && word == other) {
      return '1なのに複数形';
    }
    if (duration.amount != 1 && one != other && word == one) {
      return '2以上なのに単数形';
    }
    return null;
  }
  if (RegExp(r'\s').hasMatch(label)) return '数と助数詞の間に空白がある';
  final match = _numberThenCounter.firstMatch(label);
  if (match == null) return '「数＋助数詞」の形になっていない';
  if (match.group(1) != '${duration.amount}') return '数が違う';
  return null;
}
