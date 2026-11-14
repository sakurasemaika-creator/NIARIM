import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/project_service.dart';
import 'app_toast_messenger.dart';
import 'copy_name_text.dart';
import 'project_trash_dialog.dart' show runProjectAction;

/// 作品の複製の知らせの印（続けて複製したとき、前の知らせだけを取り下げる）。
class _ProjectDuplicatedKey extends UniqueKey {}

/// 作品を複製したことを、できた複製の名前と一緒に知らせる。前の複製の知らせが
/// 出ている・待っているときはそれだけを取り下げ、ほかの機能の知らせ（ゴミ箱へ
/// 移した知らせの「元に戻す」等）は閉じない。
void showProjectDuplicatedSnackBar(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String name,
) {
  if (messenger is AppToastMessengerState) {
    messenger.withdrawSnackBars(
      (snackBar) => snackBar.key is _ProjectDuplicatedKey,
    );
  }
  messenger.showSnackBar(
    SnackBar(
      key: _ProjectDuplicatedKey(),
      // 複製の印（「(コピー 2)」）は途中で折り返さない。
      content: copyNameText(l10n.projectDuplicatedSnackbar(name), name: name),
    ),
  );
}

/// [projectId]の作品を複製し、できたら複製の名前を知らせる（プロジェクト
/// 詳細・ホームの作品のメニューの「複製」で同じ）。以前はプロジェクト詳細から
/// 複製しても何も出ず、複製できたか分からなかった。複製できなかったときは
/// 作品の操作の失敗の知らせを出す。
Future<void> duplicateProjectWithNotice(
  BuildContext context,
  ProjectService service,
  String projectId, {
  required CopyNamer namer,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  String? created;
  var duplicated = false;
  await runProjectAction(context, () async {
    duplicated = await service.duplicateProject(
      projectId,
      namer: (name, taken) => created = namer(name, taken),
    );
  });
  final name = created;
  if (duplicated && name != null && messenger.mounted) {
    showProjectDuplicatedSnackBar(messenger, l10n, name);
  }
}
