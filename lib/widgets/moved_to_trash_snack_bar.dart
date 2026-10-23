import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/project_service.dart';

/// 作品をゴミ箱へ移したことを伝え、その場で戻せるSnackBarを出す。
///
/// 操作ボタンの付いたSnackBarは、既定では時間が来ても消えない
/// （[SnackBar.persist]の既定値が「操作ボタンがあるか」）。消えないと、
/// 次の画面へ移っても下のツールバーに重なり続け、後から出すSnackBarも
/// その後ろで待ち続けて表示されないので、時間で消す。
void showMovedToTrashSnackBar(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ProjectService service,
  List<String> projectIds,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.homeMovedToTrashSnackbar(projectIds.length)),
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.homeUndoAction,
          onPressed: () {
            for (final id in projectIds) {
              service.restoreProject(id);
            }
          },
        ),
      ),
    );
}
