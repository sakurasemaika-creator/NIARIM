import 'package:niarim/services/theme_service.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../models/save_node.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/help_button.dart';
import '../../widgets/projects_load_failure_notice.dart';
import '../../widgets/responsive.dart';
import 'save_tree_screen.dart';
import 'widgets/save_thumbnail_capture.dart';
import 'widgets/save_delete_feedback.dart';
import 'widgets/save_rename_button.dart';
import 'widgets/save_screen_app_bar.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';

export 'save_tree_screen.dart' show SaveTreeEntryMode, parseSaveTreeEntryMode;

class SaveManagementScreen extends StatelessWidget {
  final String projectId;
  final SaveTreeEntryMode entryMode;

  const SaveManagementScreen({
    super.key,
    required this.projectId,
    this.entryMode = SaveTreeEntryMode.quickSave,
  });

  @override
  Widget build(BuildContext context) {
    final saveService = context.watch<SaveTreeService>();
    if (saveService.isTreeMode) {
      return SaveTreeScreen(projectId: projectId, entryMode: entryMode);
    }
    return _GameStyleSlotScreen(projectId: projectId, entryMode: entryMode);
  }
}

class _GameStyleSlotScreen extends StatelessWidget {
  final String projectId;
  final SaveTreeEntryMode entryMode;

  const _GameStyleSlotScreen({
    required this.projectId,
    required this.entryMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final saveService = context.watch<SaveTreeService>();
    // スロット番号→ノードの対応表を1回だけ作る（行ごとの線形探索を避ける）。
    final bySlot = <int, SaveNode>{
      for (final n in saveService.getNodes(projectId))
        if (n.slotIndex >= 0) n.slotIndex: n,
    };

    return Scaffold(
      appBar: AppBar(
        title: SaveScreenTitle(l10n.saveTreeScreenTitleSlot),
        actions: const [
          HelpButton(topic: 'セーブツリー'),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 保存の一覧を読めなかった：空に見えるスロットにも保存があるかも
          // しれない（「保存データなし」とは言わない）。
          if (saveService.saveListUnreadable(projectId))
            ProjectsLoadFailureNotice(
              key: const Key('saveListLoadFailed'),
              message: l10n.saveTreeLoadFailedSnackbar,
              onRetry: () => saveService.retryReadList(projectId),
            ),
          Expanded(
            child: desktopCentered(
              context,
              ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                itemCount: saveService.slotMax,
                itemBuilder: (context, slotIndex) {
                  final node = bySlot[slotIndex];
                  return _GameSaveSlotTile(
                    projectId: projectId,
                    slotIndex: slotIndex,
                    memo: saveService.slotDisplayMemoOf(projectId, slotIndex),
                    node: node,
                    listUnread: saveService.saveListUnreadable(projectId),
                    // メモ＋ペン＝書き込み、ノート＝読み込み、ゴミ箱＝削除。
                    // 3つを全スロットへ常に出し、使えない操作は無効化して
                    // 見せる（空スロットは読み込み・削除ができない、
                    // クイックセーブ経由では読み込みを行わない）。
                    onWrite: () =>
                        _writeToSlot(context, saveService, slotIndex, node),
                    onLoad:
                        node == null || entryMode == SaveTreeEntryMode.quickSave
                        ? null
                        : () => _confirmAndRestore(context, saveService, node),
                    onDelete: node == null
                        ? null
                        : () => _deleteSlot(context, saveService, node),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// メモ＋ペン（書き込み）。空スロットはそのまま保存ダイアログ、既存データが
  /// あるスロットはサムネイルと保存日時を見せた上書き確認を挟む。
  Future<void> _writeToSlot(
    BuildContext context,
    SaveTreeService saveService,
    int slotIndex,
    SaveNode? node,
  ) async {
    if (node == null) {
      _showSaveDialog(context, saveService, slotIndex, null);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveTreeOverwriteAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.saveTreeOverwriteConfirmBody),
            const SizedBox(height: 14),
            _SlotConfirmationSummary(slotIndex: slotIndex, node: node),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      _showSaveDialog(context, saveService, slotIndex, node);
    }
  }

  /// ゴミ箱（削除）。
  Future<void> _deleteSlot(
    BuildContext context,
    SaveTreeService saveService,
    SaveNode node,
  ) async {
    if (!await confirmDelete(
      context,
      itemName: saveService.slotDisplayMemoOf(projectId, node.slotIndex),
    )) {
      return;
    }
    if (!context.mounted) return;
    await deleteSaveWithFeedback(context, saveService, projectId, node.id);
  }

  void _showSaveDialog(
    BuildContext context,
    SaveTreeService saveService,
    int slotIndex,
    SaveNode? existing,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final commentController = TextEditingController(
      text: saveService.slotDisplayMemoOf(projectId, slotIndex) ?? '',
    );
    var saving = false;
    String? failure;
    // メモの欄のEnterで押す「保存」ボタン（保存中は押せないので何もしない）。
    final saveButton = GlobalKey();
    showDialog<void>(
      context: context,
      // 保存中はボタンをスピナー表示にするため、ダイアログ内で状態を持つ。
      barrierDismissible: false,
      builder: (ctx) => DisposeOnUnmount(
        controller: commentController,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            // 小さい画面・大きな文字では、開いてすぐ出るキーボードの上に、
            // 打っている欄が見えるようにスクロールする。
            scrollable: true,
            title: Text(l10n.saveTreeSlotSaveDialogTitle(slotIndex + 1)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.saveTreeSlotOverwriteWarning(
                        _formatDate(existing.savedAt),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeService.activeColorScheme.tertiary,
                      ),
                    ),
                  ),
                TextField(
                  controller: commentController,
                  // 開いたらすぐ打てるように（クリックする前に打った字が
                  // どこにも入らなかった）。Enterで保存する。
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  // 保存を始めた後のEnter（次の画面を描く前の2回目も）は何もしない。
                  onSubmitted: (_) {
                    if (saving) return;
                    (saveButton.currentWidget as FilledButton?)?.onPressed
                        ?.call();
                  },
                  // Enterで欄からフォーカスを外さない（保存できなかったとき、
                  // 続けて打った字がどこにも入らない）。
                  onEditingComplete: () {},
                  decoration: InputDecoration(
                    labelText: l10n.saveTreeCommentLabel,
                    hintText: l10n.saveTreeCommentHint,
                  ),
                ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      failure!,
                      key: const Key('saveSlotDialogFailure'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                key: saveButton,
                // 保存はキャンバス全体の合成＋PNG化＋アーカイブ書き込みを伴い、
                // 大きなキャンバスでは数秒かかる。その間ボタンを押せたままに
                // すると同じスロットへの保存が二重に走り、同じファイルを
                // 同時に書き換えてしまうため、実行中は無効化する。
                onPressed: saving
                    ? null
                    : () async {
                        final ps = context.read<ProjectService>();
                        Project? project;
                        for (final candidate in ps.projects) {
                          if (candidate.id == projectId) {
                            project = candidate;
                            break;
                          }
                        }
                        if (project == null) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          return;
                        }
                        setDialogState(() => saving = true);
                        // 保存中に端末の「戻る」でダイアログを閉じても失敗を
                        // 知らせられるように、画面の知らせの出し先を先に取る。
                        final messenger = ScaffoldMessenger.of(context);
                        // 押したときに見せていたスロットの中身で保存する
                        // （保存している間に一覧を読めても、確かめていない
                        // 保存は消さない）。
                        final slotSave = saveService.beginSlotSave(
                          projectId,
                          slotIndex,
                          replacing: existing?.id,
                        );
                        // 保存はディスク書き込み・画像合成を伴うため失敗し得る
                        // （空き容量不足・ファイル書き込み失敗など）。以前は
                        // try/catchが無く、失敗すると例外が非同期の外へ抜けて
                        // ダイアログが閉じないまま何の表示も出ず、ユーザーには
                        // 「押しても何も起きない／画面がおかしくなる」と
                        // しか見えなかった。失敗を必ず画面へ出す。
                        try {
                          final thumbnail = await _generateThumbnail(
                            ps,
                            projectId,
                          );
                          await saveService.saveToSlot(
                            projectId: projectId,
                            slotIndex: slotIndex,
                            project: project,
                            scenes: ps.scenesOf(projectId),
                            tileManager: ps.tileManagerOf(projectId),
                            comment: commentController.text.isEmpty
                                ? null
                                : commentController.text,
                            thumbnailPngBytes: thumbnail,
                            intent: slotSave,
                          );
                          final kept = await saveService.setSlotMemo(
                            projectId,
                            slotIndex,
                            commentController.text,
                          );
                          // 閉じるのは自分のダイアログが一番上のときだけ（保存中に
                          // 戻るで閉じていたら、下の画面を閉じない）。
                          if (ctx.mounted &&
                              (ModalRoute.of(ctx)?.isCurrent ?? false)) {
                            Navigator.pop(ctx);
                          }
                          // 保存の一覧を読めていないので、メモ（打った
                          // コメント）は次の起動に残らないかもしれない
                          // （メモの欄と同じく知らせる）。
                          if (!kept && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.saveTreeLoadFailedSnackbar),
                              ),
                            );
                          }
                        } catch (e, st) {
                          AppErrorReporter.record(e, st);
                          // 開いたまま失敗を出す（閉じると打ったコメントが
                          // 消え、もう一度試すには打ち直すしかなかった）。
                          if (ctx.mounted &&
                              (ModalRoute.of(ctx)?.isCurrent ?? false)) {
                            setDialogState(() {
                              saving = false;
                              failure = l10n.saveTreeSaveFailedSnackbar('$e');
                            });
                          } else {
                            // 保存中に戻るでダイアログを閉じていた：画面に出す
                            // （以前は記録にだけ残り、誰にも知らされなかった）。
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.saveTreeSaveFailedSnackbar('$e'),
                                ),
                              ),
                            );
                          }
                        } finally {
                          slotSave.end();
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndRestore(
    BuildContext context,
    SaveTreeService saveService,
    SaveNode node,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveTreeRestoreAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.saveTreeProjectDetailResumeBody),
            const SizedBox(height: 14),
            _SlotConfirmationSummary(slotIndex: node.slotIndex, node: node),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.saveTreeRestoreAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final data = await saveService.loadNode(projectId, node.id);
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)));
      return;
    }

    context.read<ProjectService>().restoreFromAutosave(projectId, data);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.saveTreeRestoredSnackbar(
            saveService.slotDisplayMemoOf(projectId, node.slotIndex) ??
                l10n.saveTreeSlotFallbackName(node.slotIndex + 1),
          ),
        ),
        // Shared SnackBarThemeData already removes the thick shadow.
        // Keep this intentionally smaller corner radius.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 書き込み／読み込み確認ダイアログで対象セーブを取り違えないための要約。
/// サムネイル、スロット名、コメント、保存日時を同時に見せる。
class _SlotConfirmationSummary extends StatelessWidget {
  final int slotIndex;
  final SaveNode node;

  const _SlotConfirmationSummary({required this.slotIndex, required this.node});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _SlotThumbnail(node: node, size: 68),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.saveTreeSlotLabel(slotIndex + 1),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  context.watch<SaveTreeService>().slotDisplayMemoOf(
                        node.projectId,
                        slotIndex,
                      ) ??
                      l10n.saveTreeSlotFallbackName(slotIndex + 1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(node.savedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// セーブスロット1件ぶんの行。
///
/// 以前は行をタップするとボトムシートが開き、その中の
/// Three explicit actions are available for every slot. A phone-sized row
/// moves the controls beneath the preview, preserving readable names while
/// providing separated, at least 56dp-wide touch targets.
class _GameSaveSlotTile extends StatelessWidget {
  final String projectId;
  final int slotIndex;
  final String? memo;
  final SaveNode? node;
  final VoidCallback onWrite;
  final VoidCallback? onLoad;
  final VoidCallback? onDelete;

  /// 保存の一覧を読めなかった（空に見えても保存があるかもしれないので、
  /// 「保存データなし」と言わない）。
  final bool listUnread;

  const _GameSaveSlotTile({
    required this.projectId,
    required this.slotIndex,
    required this.memo,
    required this.node,
    this.listUnread = false,
    required this.onWrite,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasData = node != null;

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SlotActionButton(
          icon: Icons.edit_note,
          tooltip: l10n.saveTreeSlotWriteTooltip,
          color: scheme.onSurfaceVariant,
          onPressed: onWrite,
        ),
        const SizedBox(width: 14),
        _SlotActionButton(
          icon: Icons.menu_book_outlined,
          tooltip: l10n.saveTreeSlotLoadTooltip,
          color: scheme.onSurfaceVariant,
          onPressed: onLoad,
        ),
        const SizedBox(width: 14),
        _SlotActionButton(
          icon: Icons.delete_outline,
          tooltip: l10n.saveTreeSlotDeleteTooltip,
          color: AccentTextTheme.of(context),
          onPressed: onDelete,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: hasData
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        elevation: hasData ? 2 : 0,
        shadowColor: ThemeService.activeColorScheme.shadow.withValues(
          alpha: 0.16,
        ),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // The full row still opens the overwrite confirmation.
          onTap: onWrite,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 530;
              final details = Row(
                children: [
                  _SlotThumbnail(node: node, size: 58, listUnread: listUnread),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saveTreeSlotLabel(slotIndex + 1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              fit: FlexFit.loose,
                              child: Text(
                                memo?.isNotEmpty == true
                                    ? memo!
                                    : (hasData
                                          ? l10n.saveTreeSlotFallbackName(
                                              slotIndex + 1,
                                            )
                                          : listUnread
                                          ? ''
                                          : l10n.saveTreeNoDataLabel),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasData
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: SaveSlotMemoButton(
                                projectId: projectId,
                                slotIndex: slotIndex,
                                initialMemo: memo ?? '',
                              ),
                            ),
                          ],
                        ),
                        if (hasData) ...[
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(node!.savedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ] else if (memo?.isNotEmpty == true && !listUnread) ...[
                          const SizedBox(height: 3),
                          Text(
                            l10n.saveTreeNoDataLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!stacked) ...[const SizedBox(width: 16), actions],
                ],
              );
              return Container(
                constraints: const BoxConstraints(minHeight: 82),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasData
                        ? scheme.outlineVariant
                        : scheme.outlineVariant.withValues(alpha: 0.65),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: stacked
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          details,
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ],
                      )
                    : details,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlotActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _SlotActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 56, height: 56),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconSize: 28,
      icon: Icon(
        icon,
        color: enabled ? color : Theme.of(context).disabledColor,
      ),
    );
  }
}

class _SlotThumbnail extends StatelessWidget {
  final SaveNode? node;
  final double size;

  /// 保存の一覧を読めなかった：空に見えても保存があるかもしれないので、
  /// 「＋」（ここへ保存）ではなく、読めなかった印を出す。
  final bool listUnread;

  const _SlotThumbnail({
    required this.node,
    required this.size,
    this.listUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = node?.thumbnailPath;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? Icon(
              node == null
                  ? (listUnread ? Icons.folder_off_outlined : Icons.add)
                  : Icons.image_outlined,
              color: scheme.onSurfaceVariant,
            )
          : Image.file(
              File(path),
              fit: BoxFit.contain,
              // 保存済みサムネイルは長辺200px。ここでの表示は58pxなので、
              // 表示画素数に合わせてデコードして画像キャッシュを節約する。
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) =>
                  Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
            ),
    );
  }
}

Future<Uint8List?> _generateThumbnail(ProjectService ps, String projectId) =>
    captureSaveThumbnail(ps, projectId);

String _formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
