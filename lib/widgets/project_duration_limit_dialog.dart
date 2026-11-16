import 'package:flutter/material.dart';
import 'premium_lock_widget.dart';

import '../l10n/app_localizations.dart';

void showProjectDurationLimit(
  BuildContext context, {
  required bool hasUnlimitedDuration,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (!hasUnlimitedDuration) {
    showPremiumBanner(context, reason: l10n.timelineDurationLimitBodyFree);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.timelineDurationLimitTitle),
      content: Text(l10n.timelineDurationLimitBodyPremium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(l10n.commonClose),
        ),
      ],
    ),
  );
}
