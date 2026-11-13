import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/save_tree_service.dart';
import '../../../utils/app_error_reporter.dart';

/// 保存の画面から保存を消す。消せなかったとき（保存のファイルを消す権限が
/// 無い等）は記録して「保存データを削除できませんでした」と知らせ、falseを
/// 返す（消せなかった保存は一覧に残る。[SaveTreeService.deleteNode]）。
/// 以前は呼び出し元が例外を受けず、利用者には何も出なかった。
Future<bool> deleteSaveWithFeedback(
  BuildContext context,
  SaveTreeService service,
  String projectId,
  String nodeId,
) async {
  // 消している間に画面を離れても知らせる。
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = AppLocalizations.of(context)!.saveTreeDeleteFailedSnackbar;
  try {
    await service.deleteNode(projectId, nodeId);
    return true;
  } catch (error, stack) {
    AppErrorReporter.record(error, stack);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}
