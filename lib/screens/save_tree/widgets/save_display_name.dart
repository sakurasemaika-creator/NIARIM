import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/save_node.dart';
import '../../../services/save_tree_service.dart';

/// 保存に付けた名前（スロットのメモ・ツリーの保存のコメント）。空・空白
/// だけなら名前は無い（null）。
///
/// メモを付けずにスロットへ保存すると、スロットのメモは「空」として残る
/// （[SaveTreeService.slotMemoOf]）。それをそのまま名前に使うと、確認・
/// 知らせが「「」を削除しますか？」「読み込みました（）」になった。
String? givenSaveName(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  return name;
}

/// スロットの保存を文の中で呼ぶ名前。メモが無ければ、スロットの行の見出しと
/// 同じ名前（「スロット1」。以前は確認・知らせだけ「スロット 1」と、見出しと
/// 違う形で呼んでいた）。
String slotSaveName(AppLocalizations l10n, String? memo, int slotIndex) =>
    givenSaveName(memo) ?? l10n.saveTreeSlotLabel(slotIndex + 1);

/// ツリーの保存を文の中で呼ぶ名前。名前が無ければ、行に出ている保存の日時
/// （「2026/11/13 13:56の保存」）。どれも「保存」と呼ぶと、削除の確認で
/// どの保存を消すのか分からない。
String treeSaveName(AppLocalizations l10n, SaveNode node) =>
    givenSaveName(node.comment) ??
    l10n.saveTreeNodeDatedName(formatSaveTime(node.savedAt, l10n.localeName));

/// 保存の画面の行と同じ形の日時。表示言語の日付と時刻の書き方
/// （ja「2026/11/13 13:56」、en「11/13/2026 1:56 PM」。プロジェクト詳細・
/// 作品一覧の日時と同じ）。以前は言語に関係なく「2026/11/13 13:56」だった
/// （DISC134）。
String formatSaveTime(DateTime dt, String localeName) =>
    DateFormat.yMd(localeName).add_jm().format(dt);

/// 保存を文の中で呼ぶ名前（スロットはスロットのメモ、ツリーは保存の名前）。
String saveNameOf(
  AppLocalizations l10n,
  SaveTreeService saves,
  SaveNode node,
) => node.isTreeMode
    ? treeSaveName(l10n, node)
    : slotSaveName(
        l10n,
        saves.slotDisplayMemoOf(node.projectId, node.slotIndex),
        node.slotIndex,
      );
