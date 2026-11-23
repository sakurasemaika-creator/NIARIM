import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_toast_messenger.dart';

class _LayerLockedNoticeKey extends UniqueKey {}

/// Says that the layer is locked, each time a locked layer is drawn on or
/// filtered. The previous one of these notices is withdrawn first (shown or
/// waiting), but another feature's notice (an "Undo" and the like) is left
/// alone.
void showLayerLockedNotice(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  if (messenger is AppToastMessengerState) {
    messenger.withdrawSnackBars(
      (snackBar) => snackBar.key is _LayerLockedNoticeKey,
    );
  }
  messenger.showSnackBar(
    SnackBar(
      key: _LayerLockedNoticeKey(),
      content: Text(AppLocalizations.of(context)!.canvasLayerLockedNotice),
      duration: const Duration(seconds: 3),
    ),
  );
}
