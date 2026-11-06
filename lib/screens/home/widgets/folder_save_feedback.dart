import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/folder_persistence.dart';

String folderSaveFailureText(AppLocalizations l10n, Object error) =>
    error is FolderSaveException && error.partiallySaved
    ? l10n.folderChangesPartiallySaved
    : l10n.folderChangesSaveFailed;

/// Keep the action's geometry stable while its accepted save is pending.
class FolderSaveButton extends StatelessWidget {
  const FolderSaveButton({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
    this.style,
  });

  final String label;
  final bool saving;
  final VoidCallback? onPressed;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: style,
    onPressed: saving ? null : onPressed,
    child: Builder(
      builder: (context) => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: saving ? 0 : 1, child: Text(label)),
          if (saving)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: DefaultTextStyle.of(context).style.color,
                semanticsLabel: label,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Close only the submitting modal, including when another route covers it.
void closeFolderRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}
