import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/project_service.dart';

void showProjectAutosaveNotice(BuildContext context, String projectId) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null ||
      !context.read<ProjectService>().takeAutosaveRecoveryNotice(projectId)) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context)!.projectAutosaveRecovered),
    ),
  );
}
