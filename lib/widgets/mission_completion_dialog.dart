import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/font_fallback.dart';
import '../utils/app_locale.dart';
import '../utils/coin_duration_label.dart';

/// The server owns achievement detection; this widget only displays
/// newly achieved mission labels and a direct route to the claim page.
/// Never award any coins from this dialog.
Future<void> showMissionCompletionDialog(
  BuildContext context, {
  required List<String> titles,
}) async {
  if (!context.mounted || titles.isEmpty) return;
  final l10n = appLocalizationsOf(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('missionCompletedDialog'),
      scrollable: true,
      title: Text(
        l10n.missionCompletedTitle,
        style: const TextStyle(
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      content: Text(
        [
          ...titles.map((title) => '・$title'),
          l10n.missionCompletedBody,
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          key: const Key('missionCompletedClose'),
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.commonClose),
        ),
        FilledButton(
          key: const Key('missionCompletedGoToMissions'),
          onPressed: () {
            Navigator.pop(dialogContext);
            if (context.mounted) context.push('/rewards');
          },
          child: Text(l10n.missionCompletedGoToMissions),
        ),
      ],
    ),
  );
}

/// Login visit responses contain only events crossed on the newly recorded
/// JST day. Duplicate opens return no events and cannot repeat this popup.
Future<void> showServerMissionCompletions(
  BuildContext context,
  Map<String, dynamic> response,
) async {
  final records = (response['newlyAchieved'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  if (records.isEmpty || !context.mounted) return;
  final l10n = appLocalizationsOf(context);
  final names = records
      .map((row) {
        final days = (row['requiredDays'] as num?)?.toInt() ?? 0;
        return switch (row['period']) {
          'week' => l10n.missionLoginWeek(days),
          'month' => l10n.missionLoginMonth(days),
          _ => l10n.missionLoginTotal(days),
        };
      })
      .toList(growable: false);
  await showMissionCompletionDialog(context, titles: names);
}

/// 作品広場の滞在の記録（/me/missions/plaza/pulse）の応答で、新しく達成した
/// 滞在ミッションを知らせる。期間と目標の時間はその言語の文で出す。
Future<void> showPlazaMissionCompletions(
  BuildContext context,
  Map<String, dynamic> response,
) async {
  final records = (response['newlyAchieved'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  if (records.isEmpty || !context.mounted) return;
  final l10n = appLocalizationsOf(context);
  final names = records
      .map((row) {
        final seconds = (row['requiredSeconds'] as num?)?.toInt() ?? 0;
        // 'day'・'week'以外はマンスリー（作品広場のミッションの欄と同じ決まり）。
        final period = switch (row['period']) {
          'day' => 'day',
          'week' => 'week',
          _ => 'month',
        };
        return l10n.plazaMissionCompletedItem(
          period,
          l10n.plazaMissionGoal(missionDurationLabel(l10n, seconds)),
        );
      })
      .toList(growable: false);
  await showMissionCompletionDialog(context, titles: names);
}
