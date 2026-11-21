import 'package:flutter/material.dart';
import 'premium_lock_widget.dart';

import '../l10n/app_localizations.dart';
import '../services/premium_service.dart';

void showProjectDurationLimit(
  BuildContext context, {
  required bool hasUnlimitedDuration,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (!hasUnlimitedDuration) {
    showPremiumBanner(context, feature: PremiumFeature.unlimitedDuration);
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
