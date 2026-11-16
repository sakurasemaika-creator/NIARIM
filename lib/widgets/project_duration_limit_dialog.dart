import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

void showProjectDurationLimit(
  BuildContext context, {
  required bool hasUnlimitedDuration,
}) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.timelineDurationLimitTitle),
      content: Text(
        hasUnlimitedDuration
            ? l10n.timelineDurationLimitBodyPremium
            : l10n.timelineDurationLimitBodyFree,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(l10n.commonClose),
        ),
        if (!hasUnlimitedDuration) ...[
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              context.push('/premium');
            },
            child: Text(l10n.premiumComparisonPremium),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialog);
              context.push('/rewards');
            },
            child: Text(l10n.rewardNavigationExchange),
          ),
        ],
      ],
    ),
  );
}
