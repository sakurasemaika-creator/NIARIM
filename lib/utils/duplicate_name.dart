import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../services/project_service.dart';

/// 複製した作品の名前。複製先のフォルダに同じ名前の複製が既にあれば番号を
/// 付ける（「作品1 (コピー)」「作品1 (コピー 2)」…）。番号が無いと、同じ
/// 作品を2回貼り付けたとき同じ名前の作品が並び、見分けられなかった。
/// 「共有」から取り込んだ作品はホームのフォルダに並ばないので数えない。
String duplicateProjectName(
  AppLocalizations l10n,
  String name, {
  required String? folderId,
  required Iterable<Project> projects,
}) {
  return numberedCopyName(l10n, name, {
    for (final p in projects)
      if (p.folderId == folderId && !p.isSharedImport) p.name,
  });
}

/// 複製したフォルダの名前。複製先に同じ名前のフォルダが既にあれば番号を
/// 付ける（作品の複製と同じ「(コピー)」「(コピー 2)」…）。
String duplicateFolderName(
  AppLocalizations l10n,
  String name, {
  required String? parentId,
  required Iterable<ProjectFolder> folders,
}) {
  return numberedCopyName(l10n, name, {
    for (final f in folders)
      if (f.parentFolderId == parentId) f.name,
  });
}

/// 複製の名前（「名前 (コピー)」）。[taken]に同じ名前があれば
/// 「名前 (コピー 2)」…と番号を付ける。
String numberedCopyName(AppLocalizations l10n, String name, Set<String> taken) {
  final plain = l10n.projectDuplicateName(name);
  if (!taken.contains(plain)) return plain;
  for (var number = 2; ; number++) {
    final numbered = l10n.projectDuplicateNameNumbered(name, number);
    if (!taken.contains(numbered)) return numbered;
  }
}
