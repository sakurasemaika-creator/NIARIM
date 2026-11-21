import '../../../l10n/app_localizations.dart';
import '../../../services/save_tree_service.dart';

/// メモ・名前を保存の一覧と一緒に残せなかったときの知らせの文。一覧を
/// 書けなかったとき（空き容量が無い等）は「メモを保存できませんでした」、
/// 一覧を読めていないときは「保存データの読み込みに失敗しました」。
String saveListProblemText(
  AppLocalizations l10n,
  SaveTreeService service,
  String projectId,
) => service.saveListUnwritten(projectId)
    ? l10n.saveTreeMemoNotSavedSnackbar
    : l10n.saveTreeLoadFailedSnackbar;
