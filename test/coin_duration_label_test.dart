import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/utils/coin_duration_label.dart';

import 'helpers/reward_duration_oracle.dart';

/// 交換期間の文言（数＋単位）は、7言語とも翻訳ファイルの複数形の規則で作る。
void main() {
  test('選べる期間は152通りで、範囲の外の期間は作れない', () {
    expect(offeredRewardDurations, hasLength(152));
    expect(offeredRewardDurations.every((d) => d.isValid), isTrue);

    final offered = {
      for (final d in offeredRewardDurations) (d.unit, d.amount),
    };
    for (final unit in CoinDurationUnit.values) {
      for (var amount = 0; amount <= 130; amount++) {
        if (offered.contains((unit, amount))) continue;
        expect(
          () => CoinUnlockDuration(amount, unit),
          throwsAssertionError,
          reason: '${unit.name} $amount',
        );
      }
    }
  });

  test('書き方の検査は、以前の文言（1hours・1 months・1 か月）を見つける', () {
    RewardDurationLanguage of(String code) =>
        rewardDurationLanguages.singleWhere((l) => l.code == code);
    const oneHour = CoinUnlockDuration(1, CoinDurationUnit.hour);
    const twoHours = CoinUnlockDuration(2, CoinDurationUnit.hour);
    const oneMonth = CoinUnlockDuration(1, CoinDurationUnit.month);

    for (final (code, duration, label) in [
      ('en', oneHour, '1hours'),
      ('en', twoHours, '2hours'),
      ('en', oneHour, '1 hours'),
      ('en', twoHours, '2 hour'),
      ('en', oneMonth, '1 months'),
      ('en', oneHour, '1  hour'),
      ('es', oneHour, '1horas'),
      ('es', oneMonth, '1 meses'),
      ('fr', oneHour, '1heures'),
      ('fr', oneHour, '1 heures'),
      ('fr', oneMonth, '1mois'),
      ('ja', oneMonth, '1 か月'),
      ('ko', oneMonth, '1 개월'),
      ('zh', oneMonth, '1 个月'),
      ('zh_Hant', oneMonth, '1　個月'),
      ('ja', twoHours, '1時間'),
    ]) {
      expect(
        rewardDurationLabelProblem(of(code), duration, label),
        isNotNull,
        reason: '$code "$label"',
      );
    }
    expect(rewardDurationLabelProblem(of('en'), oneHour, '1 hour'), isNull);
    expect(rewardDurationLabelProblem(of('fr'), oneMonth, '1 mois'), isNull);
    expect(rewardDurationLabelProblem(of('ja'), oneMonth, '1か月'), isNull);
  });

  for (final language in rewardDurationLanguages) {
    test('152通りすべての文言が正しい（${language.code}）', () {
      final l10n = lookupAppLocalizations(language.locale);
      final labels = <String>{};
      for (final duration in offeredRewardDurations) {
        final label = coinUnlockDurationLabel(l10n, duration);
        final where =
            '${language.code} ${duration.unit.name} '
            '${duration.amount} "$label"';
        expect(label, language.label(duration), reason: where);
        expect(
          rewardDurationLabelProblem(language, duration, label),
          isNull,
          reason: where,
        );
        labels.add(label);
      }
      expect(labels, hasLength(152), reason: '同じ文言になる期間がある');

      for (final MapEntry(key: name, value: expected)
          in language.pinned.entries) {
        final [unitName, amount] = name.split('_');
        expect(
          coinUnlockDurationLabel(
            l10n,
            CoinUnlockDuration(
              int.parse(amount),
              CoinDurationUnit.values.byName(unitName),
            ),
          ),
          expected,
          reason: '${language.code} $name',
        );
      }
    });
  }

  test('単数・複数は言語ごとの規則で決まる（フランス語は0も単数）', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    final fr = lookupAppLocalizations(const Locale('fr'));

    expect(en.rewardDurationHours(0), '0 hours');
    expect(en.rewardDurationHours(1), '1 hour');
    expect(en.rewardDurationDays(1), '1 day');
    expect(en.rewardDurationDays(7), '7 days');
    expect(en.rewardDurationWeeks(1), '1 week');
    expect(en.rewardDurationMonths(1), '1 month');

    expect(es.rewardDurationHours(0), '0 horas');
    expect(es.rewardDurationDays(1), '1 día');
    expect(es.rewardDurationWeeks(1), '1 semana');
    expect(es.rewardDurationMonths(1), '1 mes');
    expect(es.rewardDurationMonths(2), '2 meses');

    expect(fr.rewardDurationHours(0), '0 heure');
    expect(fr.rewardDurationHours(1), '1 heure');
    expect(fr.rewardDurationHours(2), '2 heures');
    expect(fr.rewardDurationDays(0), '0 jour');
    expect(fr.rewardDurationDays(1), '1 jour');
    expect(fr.rewardDurationWeeks(0), '0 semaine');
    expect(fr.rewardDurationWeeks(2), '2 semaines');
    expect(fr.rewardDurationMonths(0), '0 mois');
    expect(fr.rewardDurationMonths(1), '1 mois');
    expect(fr.rewardDurationMonths(120), '120 mois');
  });

  test('日本語は期間の言い方（日付と読める「2日」にしない）', () {
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(ja.rewardDurationHours(24), '24時間');
    expect(ja.rewardDurationDays(2), '2日間');
    expect(ja.rewardDurationDays(6), '6日間');
    expect(ja.rewardDurationWeeks(3), '3週間');
    expect(ja.rewardDurationMonths(120), '120か月');
  });

  test('必要コインは152通りとも単価×数のまま', () {
    const toneCurve = CoinUnlockUnitPrices(
      perHour: 4,
      perDay: 20,
      perWeek: 110,
      perMonth: 450,
    );
    const watermark = CoinUnlockUnitPrices(
      perHour: 3,
      perDay: 15,
      perWeek: 80,
      perMonth: 300,
    );
    int unitPrice(CoinDurationUnit unit, List<int> prices) =>
        prices[CoinDurationUnit.values.indexOf(unit)];

    for (final duration in offeredRewardDurations) {
      final where = '${duration.unit.name} ${duration.amount}';
      final tone =
          duration.amount * unitPrice(duration.unit, [4, 20, 110, 450]);
      final mark = duration.amount * unitPrice(duration.unit, [3, 15, 80, 300]);
      expect(toneCurve.cost(duration), tone, reason: where);
      expect(watermark.cost(duration), mark, reason: where);

      final quote = const CoinUnlockQuoteCalculator().calculate(
        selections: const [
          CoinUnlockSelection(target: CoinUnlockTarget.toneCurve),
          CoinUnlockSelection(target: CoinUnlockTarget.watermark),
        ],
        duration: duration,
        prices: const {
          CoinUnlockTarget.toneCurve: toneCurve,
          CoinUnlockTarget.watermark: watermark,
        },
        priceVersion: 'fixture',
      );
      expect(quote.requiredCoins, tone + mark, reason: where);
      expect(quote.duration, same(duration), reason: where);
    }
  });

  test('特典交換の画面は数と単位をコードでつながない', () {
    final source = File(
      'lib/screens/rewards/reward_unlock_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains(r"'${value.amount}$unit'")));
    expect(source, isNot(contains(r"1 ${t['month']}")));
    expect(source, isNot(contains('_durationText')));
    // 期間のボタン・シートの各行・交換の確認の3か所。
    expect(
      'coinUnlockDurationLabel('.allMatches(source).length,
      greaterThanOrEqualTo(3),
    );
  });
}
