import 'package:niarim/services/theme_service.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/layer_compositor.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../models/save_node.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import 'save_tree_screen.dart';
import '../../config/font_fallback.dart';

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
        title: Text(l10n.saveTreeScreenTitleSlot),
        actions: const [
          HelpButton(topic: 'セーブツリー'),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
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
                    slotIndex: slotIndex,
                    node: node,
                    // ペン＝書き込み、本＝読み込み、ゴミ箱＝削除。
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

  /// ペン（書き込み）。空スロットはそのまま保存ダイアログ、既存データが
  /// あるスロットは上書き確認を挟む。
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
        content: Text(l10n.saveTreeOverwriteConfirmBody),
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
    if (!await confirmDelete(context, itemName: node.comment)) return;
    await saveService.deleteNode(projectId, node.id);
  }

  void _showSaveDialog(
    BuildContext context,
    SaveTreeService saveService,
    int slotIndex,
    SaveNode? existing,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final commentController = TextEditingController(
      text: existing?.comment ?? '',
    );
    var saving = false;
    showDialog<void>(
      context: context,
      // 保存中はボタンをスピナー表示にするため、ダイアログ内で状態を持つ。
      barrierDismissible: false,
      builder: (ctx) => DisposeOnUnmount(
        controller: commentController,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
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
                  decoration: InputDecoration(
                    labelText: l10n.saveTreeCommentLabel,
                    hintText: l10n.saveTreeCommentHint,
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
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e, st) {
                          AppErrorReporter.record(e, st);
                          if (ctx.mounted) {
                            setDialogState(() => saving = false);
                            Navigator.pop(ctx);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.saveTreeSaveFailedSnackbar('$e'),
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
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
        content: Text(
          entryMode == SaveTreeEntryMode.projectDetail
              ? l10n.saveTreeProjectDetailResumeBody
              : l10n.saveTreeResumeConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.saveTreeResumeFromHereAction),
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
            node.comment ?? l10n.saveTreeSlotFallbackName(node.slotIndex + 1),
          ),
        ),
      ),
    );
  }
}

/// セーブスロット1件ぶんの行。
///
/// 以前は行をタップするとボトムシートが開き、その中の
/// 「上書きする／復元／削除」を選ぶ形だった。操作が2段になるうえ、
/// どのスロットに対する操作なのかがシートの中では分からなくなるため、
/// **各スロットの行に3つのボタンを直接置く**形へ変更した。
/// ペン＝セーブデータの書き込み、本＝読み込み、ゴミ箱＝削除。
class _GameSaveSlotTile extends StatelessWidget {
  final int slotIndex;
  final SaveNode? node;

  /// ペン（このスロットへ保存）。空スロットでも押せる。
  final VoidCallback onWrite;

  /// 本（このスロットから読み込む）。空スロット・クイックセーブ経由では
  /// nullを渡して無効表示にする。
  final VoidCallback? onLoad;

  /// ゴミ箱（このスロットを削除）。空スロットではnull。
  final VoidCallback? onDelete;

  const _GameSaveSlotTile({
    required this.slotIndex,
    required this.node,
    required this.onWrite,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasData = node != null;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
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
          // 行全体のタップは主操作（＝ペンと同じ書き込み）に割り当てる。
          // ボタンが小さい端末でも押しやすくするための補助で、
          // 既存データがある場合はペンと同じく上書き確認を挟む。
          onTap: onWrite,
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasData
                    ? scheme.outlineVariant
                    : scheme.outlineVariant.withValues(alpha: 0.65),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _SlotThumbnail(node: node, size: 58),
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
                      Text(
                        hasData
                            ? (node!.comment ??
                                  l10n.saveTreeSlotFallbackName(slotIndex + 1))
                            : l10n.saveTreeNoDataLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasData
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
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
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // ペン＝書き込み（セーブ）、本＝読み込み（ロード）、
                // ゴミ箱＝削除。読み込みが本なので、書き込みは
                // 「その本へ書き入れる」ペンで揃える（フロッピーディスクだと
                // 本と別の比喩が混ざる）。スロットには名前変更のような
                // 「編集」操作が無いので、ペン＝編集との取り違えも起きない。
                // 3つとも全スロットに出し、使えないものは無効表示にする
                // （`test/save_slot_action_buttons_test.dart`が監視）。
                _SlotActionButton(
                  icon: Icons.edit,
                  tooltip: l10n.saveTreeSlotWriteTooltip,
                  color: scheme.primary,
                  onPressed: onWrite,
                ),
                _SlotActionButton(
                  icon: Icons.menu_book,
                  tooltip: l10n.saveTreeSlotLoadTooltip,
                  color: scheme.onSurfaceVariant,
                  onPressed: onLoad,
                ),
                _SlotActionButton(
                  icon: Icons.delete_outline,
                  tooltip: l10n.saveTreeSlotDeleteTooltip,
                  color: scheme.error,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// セーブスロット行に並ぶ小さな操作ボタン。
///
/// 標準の`IconButton`は48dpのタップ判定を確保するため、3つ並べると
/// 行の右側だけで150dp近くを占め、スロット名やサムネイルが押し出される。
/// 判定を確保しつつ幅を抑えるため、密度を詰めたうえで固定幅にしている。
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      iconSize: 22,
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

  const _SlotThumbnail({required this.node, required this.size});

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
              node == null ? Icons.add : Icons.image_outlined,
              color: scheme.onSurfaceVariant,
            )
          : Image.file(
              File(path),
              fit: BoxFit.cover,
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

Future<Uint8List?> _generateThumbnail(
  ProjectService ps,
  String projectId,
) async {
  final scenes = ps.scenesOf(projectId);
  if (scenes.isEmpty || scenes.first.frames.isEmpty) return null;
  final scene = scenes.first;
  final frame = scene.frames.first;
  final tileManager = ps.tileManagerOf(projectId);
  final w = tileManager.canvasWidth;
  final h = tileManager.canvasHeight;
  if (w <= 0 || h <= 0) return null;

  const thumbMax = 200;
  final scale = thumbMax / math.max(w, h);
  final tw = (w * scale).round().clamp(1, thumbMax);
  final th = (h * scale).round().clamp(1, thumbMax);
  final fullImage = await LayerCompositor.composite(
    tileManager,
    ps.layersOf(projectId, scene.id, frame.index),
    (layer) => ps.tileKeyFor(projectId, scene.id, frame.index, layer.id),
    w,
    h,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    fullImage,
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
    ui.Paint(),
  );
  fullImage.dispose();
  final picture = recorder.endRecording();
  final thumbImage = await picture.toImage(tw, th);
  final byteData = await thumbImage.toByteData(format: ui.ImageByteFormat.png);
  thumbImage.dispose();
  return byteData?.buffer.asUint8List();
}

String _formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
