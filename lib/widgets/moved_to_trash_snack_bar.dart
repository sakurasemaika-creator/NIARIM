import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/project_service.dart';
import '../utils/app_error_reporter.dart';
import 'app_toast_messenger.dart';
import 'copy_name_text.dart';
import 'project_trash_dialog.dart' show showProjectActionFailure;

/// 1回のゴミ箱への移動で移したもの（「元に戻す」で戻すもの）。
class _TrashMove {
  _TrashMove({
    required this.projectIds,
    required this.folderIds,
    _RestoreMark? mark,
  }) : _mark = mark ?? _RestoreMark();

  final List<String> projectIds;
  final List<String> folderIds;
  final _RestoreMark _mark;

  /// 戻し始めた（同じものを二度戻さない。取り下げた前の知らせが薄くなって
  /// いる途中にその「元に戻す」を押したときも、新しい知らせで二度戻さない）。
  /// [narrowedTo]で絞った写しとも同じ印を使う。
  bool get restoring => _mark.started;
  set restoring(bool value) => _mark.started = value;

  int get count => projectIds.length + folderIds.length;

  /// この移動のうち、[projectIds]・[folderIds]だけを戻すもの。
  _TrashMove narrowedTo(List<String> projectIds, List<String> folderIds) =>
      _TrashMove(projectIds: projectIds, folderIds: folderIds, mark: _mark);
}

class _RestoreMark {
  bool started = false;
}

/// ゴミ箱へ移した知らせの印（取り下げるときに、他の機能の知らせと
/// 見分ける）。知らせごとに別のキーになる。
class _MovedToTrashNoticeKey extends UniqueKey {
  _MovedToTrashNoticeKey(this.moves);

  /// この知らせの「元に戻す」で戻すもの（移した順）。
  final List<_TrashMove> moves;

  final _TrashNoticeState state = _TrashNoticeState();
}

/// [_MovedToTrashNoticeKey]の知らせの今の様子（キーは変えられないので別に
/// 持つ）。
class _TrashNoticeState {
  /// 閉じた・取り下げた・「元に戻す」が押された（次の移動に合わせない）。
  bool settled = false;

  // 素の[ScaffoldMessenger]（部品だけのテスト）で取り下げるときに使う。
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  bool visible = false;
  bool withdrawn = false;
}

/// 出し先ごとの、まだ「元に戻す」を押せるゴミ箱の知らせ。
final Expando<_MovedToTrashNoticeKey> _openTrashNotice =
    Expando<_MovedToTrashNoticeKey>('movedToTrashNotice');

/// 作品をゴミ箱へ移したことを伝え、その場で戻せるSnackBarを出す。
///
/// 前にゴミ箱へ移した知らせがまだ出ている・順番を待っている（「元に
/// 戻す」をまだ押していない）間に続けて移したときは、前の知らせを取り下げ、
/// 新しい知らせで両方の件数を伝え、その「元に戻す」で両方を戻す（前に
/// 移したものは、いまもゴミ箱にあるものだけを1回ずつ数える。以前は
/// 前の知らせを隠して出したので、続けて移すと前に移したものの「元に戻す」が
/// 消えた）。取り下げるのはゴミ箱の知らせだけで、出ている・待っている他の
/// 機能の知らせ（コピー・失敗の知らせ等）は閉じない（その後ろに並ぶ）。
///
/// 操作ボタンの付いたSnackBarは、既定では時間が来ても消えない
/// （[SnackBar.persist]の既定値が「操作ボタンがあるか」）。消えないと、
/// 次の画面へ移っても下のツールバーに重なり続け、後から出すSnackBarも
/// その後ろで待ち続けて表示されないので、時間で消す。
void showMovedToTrashSnackBar(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ProjectService service,
  List<String> projectIds, {
  List<String> folderIds = const [],
}) {
  // フォルダを1つだけ移したときは、件数ではなくそのフォルダの名前で伝える
  // （[showFolderMovedToTrashSnackBar]と同じ。以前はメニューからも選んで
  // 移したときも「1件をゴミ箱へ移動しました」だった）。
  final single = projectIds.isEmpty && folderIds.length == 1
      ? service.trashedFolders
            .where((t) => t.folder.id == folderIds.single)
            .firstOrNull
      : null;
  _showTrashNotice(
    messenger,
    l10n,
    service,
    _TrashMove(projectIds: [...projectIds], folderIds: [...folderIds]),
    folderName: single?.folder.name,
  );
}

/// フォルダを中身ごとゴミ箱へ移したことを伝え、その場で戻せるSnackBarを出す
/// （続けて移したときは[showMovedToTrashSnackBar]と同じく1つの知らせに
/// まとめる）。
void showFolderMovedToTrashSnackBar(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ProjectService service,
  ProjectFolder folder,
) {
  _showTrashNotice(
    messenger,
    l10n,
    service,
    _TrashMove(projectIds: const [], folderIds: [folder.id]),
    folderName: folder.name,
  );
}

void _showTrashNotice(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ProjectService service,
  _TrashMove move, {
  String? folderName,
}) {
  final earlier = _openTrashNotice[messenger];
  final carried = <_TrashMove>[];
  if (earlier != null && !earlier.state.settled) {
    carried.addAll(_stillInTrash(earlier.moves, service, newer: move));
    _withdraw(messenger, earlier);
  }
  final key = _MovedToTrashNoticeKey([...carried, move]);
  _openTrashNotice[messenger] = key;
  final total = key.moves.fold<int>(0, (sum, item) => sum + item.count);
  final controller = messenger.showSnackBar(
    SnackBar(
      key: key,
      // フォルダの名前が複製の名前なら、印（「(コピー 2)」）を途中で折り
      // 返さない。
      content: copyNameText(
        carried.isEmpty && folderName != null
            ? l10n.homeFolderMovedToTrashSnackbar(folderName)
            : l10n.homeMovedToTrashSnackbar(total),
        name: folderName ?? '',
      ),
      persist: false,
      duration: const Duration(seconds: 5),
      onVisible: () {
        key.state.visible = true;
        // 素のメッセンジャーで、順番を待っている間に取り下げた。
        if (key.state.withdrawn) key.state.controller?.close();
      },
      action: SnackBarAction(
        label: l10n.homeUndoAction,
        onPressed: () {
          key.state.settled = true;
          // 後から移したものを先に戻す（作品を移した後にその作品の
          // 入っていたフォルダを移したときは、フォルダが戻ってから作品を
          // 戻す）。1回の移動の中ではフォルダを先に戻す（中の作品は
          // フォルダと一緒に元の場所へ戻る）。
          final restores = <Future<void> Function()>[];
          for (final item in key.moves.reversed) {
            if (item.restoring) continue;
            item.restoring = true;
            restores.addAll([
              for (final id in item.folderIds)
                () => service.restoreTrashedFolder(id),
              for (final id in item.projectIds)
                () => service.restoreProject(id),
            ]);
          }
          _undo(messenger, l10n, restores);
        },
      ),
    ),
  );
  key.state.controller = controller;
  controller.closed.whenComplete(() {
    key.state.settled = true;
    if (identical(_openTrashNotice[messenger], key)) {
      _openTrashNotice[messenger] = null;
    }
  });
}

/// 前の知らせの[moves]のうち、まだ戻し始めておらず、いまもゴミ箱にある
/// もの（作品は1件ずつ移したまま、フォルダは中身ごと移したまま）。ゴミ箱の
/// タブから戻した・完全に削除した・戻してまた移した（[newer]にもある）ものは
/// 除き、同じものは後の移動の分だけを数える。以前は前の移動をそのまま足し、
/// ゴミ箱に1件しか無いのに「2件をゴミ箱へ移動しました」と言い、「元に戻す」は
/// 無いものを戻そうとした。
List<_TrashMove> _stillInTrash(
  List<_TrashMove> moves,
  ProjectService service, {
  required _TrashMove newer,
}) {
  final looseProjects = {for (final p in service.looseTrash) p.id};
  final trashedFolders = {for (final t in service.trashedFolders) t.folder.id};
  final seenProjects = {...newer.projectIds};
  final seenFolders = {...newer.folderIds};
  final kept = <_TrashMove>[];
  for (final previous in moves.reversed) {
    if (previous.restoring) continue;
    final projectIds = [
      for (final id in previous.projectIds)
        if (looseProjects.contains(id) && seenProjects.add(id)) id,
    ];
    final folderIds = [
      for (final id in previous.folderIds)
        if (trashedFolders.contains(id) && seenFolders.add(id)) id,
    ];
    if (projectIds.isEmpty && folderIds.isEmpty) continue;
    kept.insert(0, previous.narrowedTo(projectIds, folderIds));
  }
  return kept;
}

/// 前のゴミ箱の知らせを取り下げる（出ていれば薄くして閉じ、順番を待って
/// いれば出さずに下げる）。他の知らせには触れない。
void _withdraw(ScaffoldMessengerState messenger, _MovedToTrashNoticeKey key) {
  key.state.settled = true;
  if (messenger is AppToastMessengerState) {
    messenger.withdrawSnackBars((snackBar) => identical(snackBar.key, key));
    return;
  }
  // 素のメッセンジャー：閉じられるのは出ている知らせだけなので、待って
  // いる知らせは出た所で閉じる。
  key.state.withdrawn = true;
  if (key.state.visible) key.state.controller?.close();
}

/// ゴミ箱へ移せなかった（お気に入りが含まれる等）断りの知らせの印。
class _TrashRefusalKey extends UniqueKey {}

/// ゴミ箱へ移すのを断ったことを[message]で知らせる。出ている・待っている
/// 他の機能の知らせ（ゴミ箱へ移した知らせの「元に戻す」・失敗の知らせ等）は
/// 閉じずに、その後ろに並べる。前の断りの知らせがまだ出ている・待っている
/// ときは、それだけを取り下げる（続けて押しても断りが積み重ならない）。
void showTrashRefusedSnackBar(
  ScaffoldMessengerState messenger,
  String message,
) {
  if (messenger is AppToastMessengerState) {
    messenger.withdrawSnackBars((snackBar) => snackBar.key is _TrashRefusalKey);
  }
  messenger.showSnackBar(
    SnackBar(key: _TrashRefusalKey(), content: Text(message)),
  );
}

/// 「元に戻す」の[restores]を順に行う。戻せなかった（ゴミ箱の記録を保存
/// できない等）ときは、黙らずにホームのゴミ箱と同じ文で知らせる（以前は
/// 何も出ず、作品はゴミ箱に残ったままだった）。戻せるものは戻し切る。
Future<void> _undo(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  List<Future<void> Function()> restores,
) async {
  Object? failure;
  for (final restore in restores) {
    try {
      await restore();
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      failure ??= error;
    }
  }
  if (failure != null && messenger.mounted) {
    showProjectActionFailure(messenger, l10n, failure);
  }
}
