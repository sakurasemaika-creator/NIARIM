import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The server owns achievement detection; this widget only displays
/// newly achieved mission labels and a direct route to the claim page.
/// Never award any coins from this dialog.
Future<void> showMissionCompletionDialog(
  BuildContext context, {
  required List<String> titles,
}) async {
  if (!context.mounted || titles.isEmpty) return;
  final japanese = Localizations.localeOf(context).languageCode == 'ja';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('missionCompletedDialog'),
      scrollable: true,
      title: Text(japanese
          ? 'ミッションをクリアしました！'
          : 'Mission completed!'),
      content: Text([
        ...titles.map((title) => '・$title'),
        japanese ? 'ミッションページで報酬を受け取れます。'
            : 'Visit Missions to claim your reward.',
      ].join('\n\n')),
      actions: [
        TextButton(
          key: const Key('missionCompletedClose'),
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(japanese ? '閉じる' : 'Close'),
        ),
        FilledButton(
          key: const Key('missionCompletedGoToMissions'),
          onPressed: () {
            Navigator.pop(dialogContext);
            if (context.mounted) context.push('/rewards');
          },
          child: Text(japanese ? 'ミッションページへ' : 'Go to Missions'),
        ),
      ],
    ),
  );
}

/** Login visit responses contain only events crossed on the newly recorded
 * JST day. Duplicate opens return no events and cannot repeat this popup. */
Future<void> showServerMissionCompletions(
  BuildContext context,
  Map<String, dynamic> response,
) async {
  final records = (response['newlyAchieved'] as List? ?? const [])
      .whereType<Map>().toList();
  if (records.isEmpty || !context.mounted) return;
  final japanese = Localizations.localeOf(context).languageCode == 'ja';
  final names = records.map((row) {
    final days = (row['requiredDays'] as num?)?.toInt() ?? 0;
    return switch (row['period']) {
      'week' => japanese ? '週$days日ログイン' : 'Visit on $days days this week',
      'month' => japanese ? '月$days日ログイン' : 'Visit on $days days this month',
      _ => japanese ? '累計$days日ログイン'
          : 'Visit on $days separate days in total',
    };
  }).toList(growable: false);
  await showMissionCompletionDialog(context, titles: names);
}
