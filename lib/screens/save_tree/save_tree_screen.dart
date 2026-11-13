import 'dart:typed_data';

import 'package:niarim/services/theme_service.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../models/save_node.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/projects_load_failure_notice.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import 'widgets/save_delete_feedback.dart';
import 'widgets/save_rename_button.dart';
import 'widgets/save_screen_app_bar.dart';
import 'widgets/save_thumbnail_capture.dart';

/// セーブツリー（SaveTree/）の合計容量がこれを超えた場合にユーザーへ通知する
/// 閾値。「容量が大きくなる場合はユーザーへ通知」するために使う。ツリー方式は
/// 各ノードが差分でなく完全なアーカイブとして保存され保存件数に比例して
/// 増え続けるため、スロット方式（件数上限あり）と異なり自然には頭打ちにならない。
const int _saveTreeSizeWarningThresholdBytes = 300 * 1024 * 1024; // 300MB

/// 保存ノードのサムネイルを生成する（先頭シーン・先頭フレームを縮小合成）。
/// 生成できない場合（シーン・フレームが存在しない等）はnullを返す。
Future<Uint8List?> _generateSaveNodeThumbnail(
  ProjectService ps,
  String projectId,
) => captureSaveThumbnail(ps, projectId);

/// スロット番号→そのスロットのノードの対応表。
Map<int, SaveNode> _nodesBySlot(List<SaveNode> nodes) {
  final map = <int, SaveNode>{};
  for (final n in nodes) {
    if (n.slotIndex >= 0) map[n.slotIndex] = n;
  }
  return map;
}

/// 親ノードID（rootはnull）→子ノード一覧の対応表を1回の走査で作る。
///
/// `SaveTreeService.getChildren()`は呼ぶたびに全ノードを走査して新しい
/// リストを作るため、ツリーを再帰的にたどりながら毎ノードで呼ぶと
/// ノード数の2乗の走査になる。木の構築前にこの表を1つ作って使い回す。
/// ツリー表示1行分の位置情報（[continues]は自身を含む各深さで
/// 「まだ次の兄弟が続くか」）。実際のウィジェットは表示される行だけ作る。
typedef _TreeRowSpec = ({
  SaveNode node,
  int depth,
  List<bool> continues,
  bool hasChildren,
});

Map<String?, List<SaveNode>> _childrenIndex(List<SaveNode> nodes) {
  final index = <String?, List<SaveNode>>{};
  for (final n in nodes) {
    (index[n.parentId] ??= <SaveNode>[]).add(n);
  }
  return index;
}

/// セーブツリー／セーブスロット画面をどこから開いたか。過去のセーブへの「復元」（現在の内容を破棄する
/// 操作）を許可するか、許可する場合にどの確認フローを見せるかをこれで
/// 分岐する。
enum SaveTreeEntryMode {
  /// タイムラインモードから：編集セッションが生きている状態で開くため、
  /// ノードごとに「上書きする（現在の内容でこのノードを保存し直す）」
  /// 「ここから再開する（このノードの内容で現在のセッションを置き換える）」
  /// の2択＋各操作の確認ダイアログを出す。
  timeline,

  /// プロジェクト詳細画面から：まだ編集セッションを始めていない場面の
  /// ため、「ここから作業を再開する」か「キャンセルして閉じる」だけの
  /// シンプルな確認にする（上書きの概念はここにはない）。
  projectDetail,

  /// それ以外（キャンバス画面の保存ボタン等）：新規保存の作成・一覧の
  /// 閲覧はできるが、過去のセーブへの復元（＝現在の内容の破棄）は
  /// この2つの入口からのみ行えるようにするため、ここでは無効化する。
  quickSave,
}

/// クエリパラメータ（例：`/save-tree/xxx?entry=timeline`）からエントリ
/// モードを解決する。未指定・不明な値は最も制限の強いquickSaveへ倒す。
SaveTreeEntryMode parseSaveTreeEntryMode(String? raw) => switch (raw) {
  'timeline' => SaveTreeEntryMode.timeline,
  'projectDetail' => SaveTreeEntryMode.projectDetail,
  _ => SaveTreeEntryMode.quickSave,
};

class SaveTreeScreen extends StatefulWidget {
  final String projectId;
  final SaveTreeEntryMode entryMode;
  const SaveTreeScreen({
    super.key,
    required this.projectId,
    this.entryMode = SaveTreeEntryMode.quickSave,
  });

  @override
  State<SaveTreeScreen> createState() => _SaveTreeScreenState();
}

class _SaveTreeScreenState extends State<SaveTreeScreen> {
  String? _selectedNodeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final saveService = context.watch<SaveTreeService>();
    final isTreeMode = saveService.isTreeMode;

    return Scaffold(
      appBar: AppBar(
        title: SaveScreenTitle(
          isTreeMode
              ? l10n.saveTreeScreenTitleTree
              : l10n.saveTreeScreenTitleSlot,
        ),
        actions: [
          const HelpButton(topic: 'セーブツリー'),
          if (isTreeMode)
            SaveTreeBarSaveButton(
              onPressed: () => _showTreeSaveDialog(
                context,
                widget.projectId,
                saveService,
                _selectedNodeId,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 保存の一覧を読めなかった：空に見えるスロット・ツリーにも保存が
          // あるかもしれない（「保存データなし」とは言わない）。
          if (saveService.saveListUnreadable(widget.projectId))
            ProjectsLoadFailureNotice(
              key: const Key('saveListLoadFailed'),
              message: l10n.saveTreeLoadFailedSnackbar,
              onRetry: () => saveService.retryReadList(widget.projectId),
            ),
          Expanded(
            child: isTreeMode
                ? _TreeView(
                    projectId: widget.projectId,
                    nodes: saveService.getNodes(widget.projectId),
                    saveService: saveService,
                    selectedNodeId: _selectedNodeId,
                    onNodeSelected: (id) =>
                        setState(() => _selectedNodeId = id),
                    entryMode: widget.entryMode,
                  )
                : desktopCentered(
                    context,
                    _SlotView(
                      projectId: widget.projectId,
                      saveService: saveService,
                      entryMode: widget.entryMode,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// ツリー方式での新規保存ダイアログ（トップの「保存」ボタン・ノードの
/// 「上書きする」選択の両方から呼ぶため、Widgetをまたいで使えるよう
/// トップレベル関数にしている）。
void _showTreeSaveDialog(
  BuildContext context,
  String projectId,
  SaveTreeService service,
  String? parentId,
) {
  final l10n = AppLocalizations.of(context)!;
  final commentController = TextEditingController();
  var saving = false;
  String? failure;
  // メモの欄のEnterで押す「保存」ボタン（保存中は押せないので何もしない）。
  final saveButton = GlobalKey();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DisposeOnUnmount(
      controller: commentController,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          // 小さい画面・大きな文字では、開いてすぐ出るキーボードの上に、
          // 打っている欄が見えるようにスクロールする。
          scrollable: true,
          title: Text(l10n.commonSave),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  parentId != null
                      ? l10n.saveTreeSaveAsChildHint
                      : l10n.saveTreeSaveAsRootHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextField(
                controller: commentController,
                // 開いたらすぐ打てるように。Enterで保存する。
                autofocus: true,
                textInputAction: TextInputAction.done,
                // 保存を始めた後のEnter（次の画面を描く前の2回目も）は何もしない。
                onSubmitted: (_) {
                  if (saving) return;
                  (saveButton.currentWidget as FilledButton?)?.onPressed
                      ?.call();
                },
                // Enterで欄からフォーカスを外さない。
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
                    key: const Key('saveTreeDialogFailure'),
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
              // スロット方式の保存ダイアログと同じ方針：保存中は二重実行を
              // 防ぐためボタンを無効化し、失敗は必ず画面へ出す（以前は
              // try/catchが無く、失敗しても何の表示も出ないまま
              // ダイアログが閉じずに固まって見えていた）。
              onPressed: saving
                  ? null
                  : () async {
                      final ps = context.read<ProjectService>();
                      final project = ps.projects
                          .where((p) => p.id == projectId)
                          .firstOrNull;
                      if (project == null) {
                        Navigator.pop(ctx);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final comment = commentController.text.isEmpty
                            ? null
                            : commentController.text;
                        final scenes = ps.scenesOf(projectId);
                        final tileManager = ps.tileManagerOf(projectId);
                        final thumb = await _generateSaveNodeThumbnail(
                          ps,
                          projectId,
                        );
                        await service.saveAsChild(
                          projectId: projectId,
                          project: project,
                          scenes: scenes,
                          tileManager: tileManager,
                          parentId: parentId,
                          comment: comment,
                          thumbnailPngBytes: thumb,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          await _warnIfSaveTreeSizeLarge(context, projectId);
                        }
                      } catch (e, st) {
                        AppErrorReporter.record(e, st);
                        // 開いたまま失敗を出す（閉じると打ったコメントが
                        // 消え、もう一度試すには打ち直すしかなかった）。
                        if (ctx.mounted) {
                          setDialogState(() {
                            saving = false;
                            failure = l10n.saveTreeSaveFailedSnackbar('$e');
                          });
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

/// セーブツリーの合計容量が閾値を超えている場合に通知する
/// 「容量が大きくなる場合はユーザーへ通知」するために使う。
Future<void> _warnIfSaveTreeSizeLarge(
  BuildContext context,
  String projectId,
) async {
  final sizeBytes = await NiaproSerializer.saveTreeSizeBytes(projectId);
  if (sizeBytes < _saveTreeSizeWarningThresholdBytes) return;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(0);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.saveTreeSizeWarningSnackbar(mb)),
      duration: const Duration(seconds: 5),
    ),
  );
}

enum _SaveNodeChoice { overwrite, resume }

/// セーブノードに対する「復元」操作を、開いた入口（[entryMode]）に応じた
/// 確認フローで実行する。
/// タイムラインモードからは編集セッションが生きているため「上書きする」
/// （[onOverwrite]：スロット方式ならそのスロットへの保存ダイアログ、
/// ツリー方式ならこのノードを親とした新規保存ダイアログを開く）か
/// 「ここから再開する」（[onResume]：実際にrestoreFromAutosaveを呼ぶ）かを
/// 選ばせ、それぞれ破壊的な結果を確認するダイアログを挟む。プロジェクト
/// 詳細画面からは、まだ編集セッションが無いため上書きの概念を出さず
/// 「ここから作業を再開する」か「キャンセルして閉じる」のシンプルな確認
/// のみにする。quickSaveモードからは呼び出し禁止（呼び出し元でボタン
/// 自体を非表示にすること）。
Future<void> _handleSaveNodeRestore(
  BuildContext context,
  SaveTreeEntryMode entryMode,
  SaveNode node, {
  required VoidCallback onOverwrite,
  required Future<void> Function() onResume,
}) async {
  assert(entryMode != SaveTreeEntryMode.quickSave);
  final l10n = AppLocalizations.of(context)!;
  final nodeTitle = node.comment ?? l10n.saveTreeNodeDefaultTitle;
  if (entryMode == SaveTreeEntryMode.timeline) {
    final choice = await showDialog<_SaveNodeChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nodeTitle),
        content: Text(l10n.saveTreeTimelineActionChoiceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SaveNodeChoice.overwrite),
            child: Text(l10n.saveTreeOverwriteAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _SaveNodeChoice.resume),
            child: Text(l10n.saveTreeRestoreAction),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _SaveNodeChoice.overwrite) {
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
      if (ok == true) onOverwrite();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveTreeRestoreAction),
        content: Text(l10n.saveTreeProjectDetailResumeBody),
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
    if (ok == true) await onResume();
    return;
  }
  // プロジェクト詳細画面から：シンプルな「ここから作業を再開する」か
  // 「キャンセルして閉じる」のみ（上書きの概念はここにはない）。
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.saveTreeRestoreAction),
      content: Text(l10n.saveTreeProjectDetailResumeBody),
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
  if (ok == true) await onResume();
}

// ─────────────────────────────────────────────
// スロット方式ビュー
// ─────────────────────────────────────────────
class _SlotView extends StatelessWidget {
  final String projectId;
  final SaveTreeService saveService;
  final SaveTreeEntryMode entryMode;

  const _SlotView({
    required this.projectId,
    required this.saveService,
    required this.entryMode,
  });

  @override
  Widget build(BuildContext context) {
    // スロット番号からノードを引く表を1回だけ作る。行ごとに
    // firstWhereで線形探索すると行数×ノード数の走査になり、
    // castのラッパーも毎行生成されていた。
    final bySlot = _nodesBySlot(saveService.getNodes(projectId));
    return ListView.builder(
      itemCount: saveService.slotMax,
      itemBuilder: (context, slotIndex) {
        final node = bySlot[slotIndex];
        return _SlotTile(
          projectId: projectId,
          slotIndex: slotIndex,
          node: node,
          listUnread: saveService.saveListUnreadable(projectId),
          onSave: () => _showSlotSaveDialog(context, slotIndex, node),
          onRestore: (node != null && entryMode != SaveTreeEntryMode.quickSave)
              ? () => _restore(context, node)
              : null,
          onDelete: node != null
              ? () async {
                  if (!await confirmDelete(context, itemName: node.comment)) {
                    return;
                  }
                  if (!context.mounted) return;
                  await deleteSaveWithFeedback(
                    context,
                    saveService,
                    projectId,
                    node.id,
                  );
                }
              : null,
        );
      },
    );
  }

  void _showSlotSaveDialog(
    BuildContext context,
    int slotIndex,
    SaveNode? existing,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final commentController = TextEditingController(
      text: saveService.slotDisplayMemoOf(projectId, slotIndex) ?? '',
    );
    // メモの欄のEnterで押す「保存」ボタン。
    final saveButton = GlobalKey();
    // 保存に失敗したときの文（ダイアログの中）。
    final failureText = GlobalKey<_SlotSaveFailureTextState>();
    // 二度押し・Enterの繰り返しで同じスロットへ二重に保存しない（失敗した
    // ときは押し直せるように戻す）。押したときに見せていたスロットの中身で
    // 保存する（保存している間に一覧を読めても、確かめていない保存は消さない）。
    var saving = false;
    SlotSave? slotSave;
    Future<void> once(Future<void> Function() save) async {
      if (saving) return;
      saving = true;
      slotSave = saveService.beginSlotSave(
        projectId,
        slotIndex,
        replacing: existing?.id,
      );
      try {
        await save();
      } catch (e, st) {
        // 保存の管理の画面と同じく、ダイアログを開いたまま中に失敗を出す
        // （打ったメモは欄に残る。以前は何も出なかった）。閉じた後なら
        // 画面に出す。
        AppErrorReporter.record(e, st);
        final message = l10n.saveTreeSaveFailedSnackbar('$e');
        final shown = failureText.currentState?.show(message) ?? false;
        if (!shown && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } finally {
        saving = false;
        slotSave?.end();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: commentController,
        builder: (ctx) => AlertDialog(
          // 小さい画面・大きな文字では、開いてすぐ出るキーボードの上に、
          // 打っている欄が見えるようにスクロールする。
          scrollable: true,
          title: Text(l10n.saveTreeSlotSaveDialogTitle(slotIndex + 1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existing != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
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
                // Enterで欄からフォーカスを外さない。
                onEditingComplete: () {},
                decoration: InputDecoration(
                  labelText: l10n.saveTreeCommentLabel,
                  hintText: l10n.saveTreeCommentHint,
                ),
              ),
              _SlotSaveFailureText(key: failureText),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: saveButton,
              onPressed: () => once(() async {
                final ps = context.read<ProjectService>();
                final project = ps.projects
                    .where((p) => p.id == projectId)
                    .firstOrNull;
                if (project == null) {
                  Navigator.pop(ctx);
                  return;
                }
                final comment = commentController.text.isEmpty
                    ? null
                    : commentController.text;
                final scenes = ps.scenesOf(projectId);
                final tileManager = ps.tileManagerOf(projectId);
                final thumb = await _generateSaveNodeThumbnail(ps, projectId);
                await saveService.saveToSlot(
                  projectId: projectId,
                  slotIndex: slotIndex,
                  project: project,
                  scenes: scenes,
                  tileManager: tileManager,
                  comment: comment,
                  thumbnailPngBytes: thumb,
                  intent: slotSave,
                );
                final kept = await saveService.setSlotMemo(
                  projectId,
                  slotIndex,
                  commentController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                // 保存の一覧を読めていないので、メモ（打ったコメント）は次の
                // 起動に残らないかもしれない（メモの欄と同じく知らせる）。
                if (!kept && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
                  );
                }
              }),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, SaveNode node) async {
    await _handleSaveNodeRestore(
      context,
      entryMode,
      node,
      onOverwrite: () => _showSlotSaveDialog(context, node.slotIndex, node),
      onResume: () => _doRestore(context, node),
    );
  }

  Future<void> _doRestore(BuildContext context, SaveNode node) async {
    final l10n = AppLocalizations.of(context)!;
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
        // Shared SnackBarThemeData already removes the thick shadow.
        // Keep this intentionally smaller corner radius.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// セーブノードのサムネイル画像。thumbnailPathが無い・読み込めない場合は
/// プレースホルダーアイコンを表示する。
class _SaveNodeThumbnail extends StatelessWidget {
  final SaveNode? node;
  final double size;

  /// 保存の一覧を読めなかった：空に見えても保存があるかもしれないので、
  /// 「＋」（ここへ保存）ではなく、読めなかった印を出す。
  final bool listUnread;

  const _SaveNodeThumbnail({
    required this.node,
    this.size = 48,
    this.listUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = node?.thumbnailPath;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null
          ? Image.file(
              File(path),
              fit: BoxFit.contain,
              // 保存されているサムネイルは長辺200pxだが、ここでの表示は
              // 40〜48px。指定しないと200px相当のまま画像キャッシュに載る
              // ため、実際に表示する画素数へ落としてデコードする。
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (context, error, stackTrace) =>
                  _placeholderIcon(context),
            )
          : _placeholderIcon(context),
    );
  }

  Widget _placeholderIcon(BuildContext context) => Center(
    child: Icon(
      node != null
          ? Icons.image
          : (listUnread ? Icons.folder_off_outlined : Icons.add),
      size: size / 2,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// スロットへの保存のダイアログの中の、保存に失敗したときの文。ダイアログが
/// 閉じている（閉じかけている）ときは[show]がfalseを返す。
class _SlotSaveFailureText extends StatefulWidget {
  const _SlotSaveFailureText({super.key});

  @override
  State<_SlotSaveFailureText> createState() => _SlotSaveFailureTextState();
}

class _SlotSaveFailureTextState extends State<_SlotSaveFailureText> {
  String? _message;

  bool show(String message) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return false;
    }
    setState(() => _message = message);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        key: const Key('saveSlotDialogFailure'),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String projectId;
  final int slotIndex;
  final SaveNode? node;
  final VoidCallback onSave;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  /// 保存の一覧を読めなかった（空に見えても保存があるかもしれないので、
  /// 「保存データなし」と言わない）。
  final bool listUnread;

  const _SlotTile({
    required this.projectId,
    required this.slotIndex,
    required this.node,
    this.listUnread = false,
    required this.onSave,
    this.onRestore,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final memo = context.watch<SaveTreeService>().slotDisplayMemoOf(
      projectId,
      slotIndex,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: ThemeService.activeColorScheme.shadow.withValues(
          alpha: 0.15,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _SaveNodeThumbnail(
                    node: node,
                    size: 58,
                    listUnread: listUnread,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saveTreeSlotLabel(slotIndex + 1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
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
                                    : (node == null
                                          ? (listUnread
                                                ? ''
                                                : l10n.saveTreeNoDataLabel)
                                          : l10n.saveTreeSlotFallbackName(
                                              slotIndex + 1,
                                            )),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        if (node != null)
                          Text(
                            _formatDate(node!.savedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else if (memo?.isNotEmpty == true && !listUnread)
                          Text(
                            l10n.saveTreeNoDataLabel,
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SaveTreeSlotActionButton(
                      icon: Icons.edit_note,
                      tooltip: l10n.saveTreeSlotWriteTooltip,
                      color: scheme.onSurfaceVariant,
                      onPressed: onSave,
                    ),
                    const SizedBox(width: 14),
                    _SaveTreeSlotActionButton(
                      icon: Icons.menu_book_outlined,
                      tooltip: l10n.saveTreeSlotLoadTooltip,
                      color: scheme.onSurfaceVariant,
                      onPressed: onRestore,
                    ),
                    const SizedBox(width: 14),
                    _SaveTreeSlotActionButton(
                      icon: Icons.delete_outline,
                      tooltip: l10n.saveTreeSlotDeleteTooltip,
                      color: scheme.error,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SaveTreeSlotActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _SaveTreeSlotActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
        color: onPressed == null ? Theme.of(context).disabledColor : color,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ツリー方式ビュー
// ─────────────────────────────────────────────
class _TreeView extends StatelessWidget {
  final String projectId;
  final List<SaveNode> nodes;
  final SaveTreeService saveService;
  final String? selectedNodeId;
  final ValueChanged<String?> onNodeSelected;
  final SaveTreeEntryMode entryMode;

  const _TreeView({
    required this.projectId,
    required this.nodes,
    required this.saveService,
    required this.selectedNodeId,
    required this.onNodeSelected,
    required this.entryMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final childrenIndex = _childrenIndex(nodes);
    final roots = childrenIndex[null] ?? const <SaveNode>[];
    if (roots.isEmpty) {
      // 保存の一覧を読めなかった：「保存データがありません」とは言わない
      // （上の知らせが読めなかったことと「再試行」を出す）。
      if (saveService.saveListUnreadable(projectId)) {
        return const SizedBox.shrink();
      }
      final scheme = Theme.of(context).colorScheme;
      return Container(
        alignment: Alignment.center,
        // 長い言語・大きな文字でも、見出しと案内を画面の端に付けない。
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_tree_outlined,
                size: 40,
                color: AccentTextTheme.of(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.saveTreeEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  // 上部の「保存」は、入らない幅ではアイコンだけになるので、
                  // 案内にもそのアイコンを添える。
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.save,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: l10n.saveTreeEmptyHint),
                ],
              ),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    // 画面下から上へ伸びる木のような見た目にする。
    // フラット化した行リストをDFS順（root→子→孫…）で構築し、reverse:trueで
    // 表示することで、rootが画面最下部・深い子孫ほど上に積み上がる形になる。
    // 各行には祖先の分岐が下（reverse後は下方向）へ続くかを示す接続線を
    // 添える（一般的なツリーコマンドの罫線と同じアルゴリズム）。
    // 行そのもの（ListTile・サムネイル・三点メニュー・接続線）はここでは
    // 作らず、位置情報だけの軽い一覧に畳んでからListView.builderへ渡す。
    // ListView(children:)だと、実際に描画されるのは画面内の行だけでも、
    // 行のウィジェットオブジェクト自体は毎回のbuildで全ノードぶん作られて
    // 捨てられる。
    // Iterative DFS avoids recursive stack overflow on extremely deep
    // histories and still produces the same bottom-to-top node order.
    final rows = <_TreeRowSpec>[];
    final work =
        <
          ({
            List<SaveNode> siblings,
            int index,
            int depth,
            List<bool> ancestors,
          })
        >[];
    for (int i = roots.length - 1; i >= 0; i--) {
      work.add((siblings: roots, index: i, depth: 0, ancestors: const []));
    }
    while (work.isNotEmpty) {
      final next = work.removeLast();
      final node = next.siblings[next.index];
      final hasNext = next.index + 1 < next.siblings.length;
      final continues = [...next.ancestors, hasNext];
      final children = childrenIndex[node.id] ?? const <SaveNode>[];
      rows.add((
        node: node,
        depth: next.depth,
        continues: continues,
        hasChildren: children.isNotEmpty,
      ));
      for (int i = children.length - 1; i >= 0; i--) {
        work.add((
          siblings: children,
          index: i,
          depth: next.depth + 1,
          ancestors: continues,
        ));
      }
    }

    // Deep branches must remain accessible without forcing a narrow tile to
    // lay out inside a negative width on small phones. Horizontal scrolling
    // is enabled only when the deepest visible indent exceeds the viewport.
    final deepest = rows.fold<int>(
      0,
      (maxDepth, row) => row.depth > maxDepth ? row.depth : maxDepth,
    );
    return LayoutBuilder(
      builder: (context, viewport) {
        final fullWidth = (deepest + 1) * 24.0 + 280.0;
        final contentWidth = fullWidth > viewport.maxWidth
            ? fullWidth
            : viewport.maxWidth;
        return SingleChildScrollView(
          key: const Key('saveTreeHorizontalScroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: viewport.maxHeight,
            child: ListView.builder(
              reverse: true,
              itemCount: rows.length,
              itemBuilder: (context, i) =>
                  _buildTreeRow(context, l10n, rows[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTreeRow(
    BuildContext context,
    AppLocalizations l10n,
    _TreeRowSpec spec,
  ) {
    final node = spec.node;
    final depth = spec.depth;
    final continues = spec.continues;
    final isSelected = selectedNodeId == node.id;
    return Stack(
      children: [
        // The painter spans each row's actual rendered height and meets the
        // adjacent row at the edge, including when text scale increases.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TreeConnectorPainter(
                depth: depth,
                continues: continues,
                hasChildren: spec.hasChildren,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: (depth + 1) * 24.0),
          child: ListTile(
            selected: isSelected,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            leading: _SaveNodeThumbnail(node: node, size: 40),
            title: Row(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    node.comment ?? l10n.saveTreeNodeDefaultTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SaveRenameButton(
                  node: node,
                  fallbackName: l10n.saveTreeNodeDefaultTitle,
                ),
              ],
            ),
            subtitle: Text(_formatDate(node.savedAt)),
            onTap: () => onNodeSelected(isSelected ? null : node.id),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, node),
              itemBuilder: (_) => [
                // 過去のセーブへの復元は、タイムラインモード・プロジェクト
                // 詳細画面からの2つの入口からのみ行える。
                if (entryMode != SaveTreeEntryMode.quickSave)
                  PopupMenuItem(
                    value: 'restore',
                    child: Text(l10n.saveTreeRestoreAction),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    l10n.commonDelete,
                    style: TextStyle(
                      color: ThemeService.activeColorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    SaveNode node,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case 'restore':
        await _handleSaveNodeRestore(
          context,
          entryMode,
          node,
          onOverwrite: () =>
              _showTreeSaveDialog(context, projectId, saveService, node.id),
          onResume: () => _doRestore(context, node),
        );
        break;
      case 'delete':
        // A tree node contains a complete historical archive. Never delete it
        // directly from a popup menu without confirming the chosen save.
        if (!await confirmDelete(
          context,
          itemName: node.comment ?? l10n.saveTreeNodeDefaultTitle,
        )) {
          return;
        }
        if (!context.mounted) return;
        await deleteSaveWithFeedback(context, saveService, projectId, node.id);
        break;
    }
  }

  Future<void> _doRestore(BuildContext context, SaveNode node) async {
    final l10n = AppLocalizations.of(context)!;
    final data = await saveService.loadNode(projectId, node.id);
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)));
      return;
    }
    context.read<ProjectService>().restoreFromAutosave(projectId, data);
    // 「セーブ・ロードした地点から次の枝が伸びる」という設計上、復元した
    // ノードをそのまま選択状態にする。三点メニューの「復元」は行の
    // タップ（選択トグル）とは独立した導線のため、これを呼ばないと
    // 「行を選択せずに三点メニューから直接復元した」場合、次の保存が
    // 復元前の選択状態（別ノードや未選択）を親にしてしまい、意図しない
    // 位置に枝分かれするバグがあった。
    onNodeSelected(node.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.saveTreeRestoredSnackbar(
            node.comment ?? l10n.saveTreeNodeDefaultName,
          ),
        ),
        // Shared SnackBarThemeData already removes the thick shadow.
        // Keep this intentionally smaller corner radius.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Full-height connectors for the bottom-up (reverse:true) save tree.
/// A node's parent is rendered directly below its descendants. Each child
/// connects downward to its parent; each parent with children connects upward.
/// This prevents the disconnected stubs caused by fixed-height gutter lines.
class _TreeConnectorPainter extends CustomPainter {
  final int depth;
  final List<bool> continues;
  final bool hasChildren;
  final Color color;

  _TreeConnectorPainter({
    required this.depth,
    required this.continues,
    required this.hasChildren,
    required this.color,
  });

  static const double _columnWidth = 24.0;
  static double _x(int level) => _columnWidth * level + _columnWidth / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final middle = size.height / 2;

    void vertical(int column, double top, double bottom) {
      canvas.drawLine(
        Offset(_x(column), top),
        Offset(_x(column), bottom),
        paint,
      );
    }

    // Descendants of a node with later siblings must preserve the
    // ancestor's vertical branch all the way through their own rows.
    for (var ancestorDepth = 1; ancestorDepth < depth; ancestorDepth++) {
      if (continues[ancestorDepth]) {
        vertical(ancestorDepth - 1, 0, size.height);
      }
    }
    if (depth > 0) {
      // Parent sits immediately below (the reversed list).
      vertical(depth - 1, middle, size.height);
      if (continues[depth]) vertical(depth - 1, 0, middle);
      canvas.drawLine(
        Offset(_x(depth - 1), middle),
        Offset(_columnWidth * (depth + 1), middle),
        paint,
      );
    } else if (hasChildren) {
      canvas.drawLine(
        Offset(_x(0), middle),
        Offset(_columnWidth, middle),
        paint,
      );
    }
    if (hasChildren) vertical(depth, 0, middle);
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) =>
      oldDelegate.depth != depth ||
      oldDelegate.hasChildren != hasChildren ||
      oldDelegate.continues != continues ||
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────
// 保存データ変更画面（保存方式変更・スロット数削減時に表示）
// ─────────────────────────────────────────────

/// 保存方式変更が必要かどうかを判定し、必要なら変更フローを開始する
/// 設定画面からは呼ばない。SaveTreeScreenから呼ぶ。
/// [newIsTreeMode] 変更後のモード
/// [newSlotMax] スロット方式の場合の新スロット数（ツリー方式ならnull）
Future<void> showSaveModeChangeFlowIfNeeded({
  required BuildContext context,
  required String projectId,
  required SaveTreeService saveService,
  required bool newIsTreeMode,
  int? newSlotMax,
  // 設定画面から複数プロジェクトへ順番に適用する場合、どのプロジェクトの
  // 変更画面かを示すために使う。単一プロジェクト文脈からの
  // 呼び出しでは省略可能。
  String? projectName,
}) async {
  final nodes = saveService.getNodes(projectId);
  final currentIsTree = saveService.isTreeMode;

  // 同じモード内でスロット数増加のみ→即時適用して終了
  if (!currentIsTree && !newIsTreeMode) {
    final nextMax = newSlotMax ?? saveService.slotMax;
    if (nextMax >= saveService.slotMax) {
      saveService.setSlotMax(nextMax);
      return;
    }
  }

  // ツリー方式への変更は保存数無制限なので変更画面不要。
  // スロット→ツリーの場合はアーカイブを復元する。
  // ツリー→ツリー（変更なし）の場合は復元しない。
  if (newIsTreeMode) {
    if (!currentIsTree) {
      saveService.restoreArchive(projectId);
    }
    saveService.setTreeMode(true);
    return;
  }

  // スロット方式への変更（ツリー→スロット、またはスロット数削減）
  final limit = newSlotMax ?? saveService.slotMax;
  final needsSelection = nodes.length > limit;

  if (!needsSelection) {
    saveService.setSlotMax(limit);
    saveService.setTreeMode(false);
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    adMockMaterialPageRoute(
      builder: (_) => _SaveModeChangeScreen(
        projectId: projectId,
        saveService: saveService,
        newIsTreeMode: false,
        newSlotMax: limit,
        projectName: projectName,
      ),
    ),
  );
}

class _SaveModeChangeScreen extends StatefulWidget {
  final String projectId;
  final SaveTreeService saveService;
  final bool newIsTreeMode;
  final int? newSlotMax;
  final String? projectName;

  const _SaveModeChangeScreen({
    required this.projectId,
    required this.saveService,
    required this.newIsTreeMode,
    required this.newSlotMax,
    this.projectName,
  });

  @override
  State<_SaveModeChangeScreen> createState() => _SaveModeChangeScreenState();
}

class _SaveModeChangeScreenState extends State<_SaveModeChangeScreen> {
  final Set<String> _selectedIds = {};
  bool _showSelectionList = false;
  late final bool _initialIsTreeMode;
  int get _limit =>
      widget.newSlotMax ?? widget.saveService.getNodes(widget.projectId).length;
  int _effectiveLimit(int nodeCount) => nodeCount < _limit ? nodeCount : _limit;

  @override
  void initState() {
    super.initState();
    _initialIsTreeMode = widget.saveService.isTreeMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nodes = widget.saveService.getNodes(widget.projectId);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.projectName == null
              ? l10n.saveTreeChangeDataTitle
              : l10n.saveTreeChangeDataTitleWithProject(widget.projectName!),
        ),
        leading: _showSelectionList
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.saveTreeBackButton,
                onPressed: () => setState(() => _showSelectionList = false),
              )
            : null,
      ),
      body: _showSelectionList
          ? _buildSelectionBody(context, l10n, nodes)
          : _buildButtonBody(context, l10n, nodes),
    );
  }

  Widget _buildButtonBody(
    BuildContext context,
    AppLocalizations l10n,
    List<SaveNode> nodes,
  ) {
    return desktopCentered(
      context,
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.saveTreeChangeExceedMessage,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.saveTreeKeepableCountLabel(_limit),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                _autoSelectLatest(nodes);
                _showDiscardDialog(context, nodes);
              },
              child: Text(l10n.saveTreeKeepLatestButton(_limit)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _showSelectionList = true),
              child: Text(l10n.saveTreeSelectDataButton),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBody(
    BuildContext context,
    AppLocalizations l10n,
    List<SaveNode> nodes,
  ) {
    final limitReached = _selectedIds.length >= _limit;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.saveTreeSelectedCountLabel(_selectedIds.length, _limit),
            style: TextStyle(
              fontSize: 12,
              color: limitReached
                  ? ThemeService.activeColorScheme.tertiary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: _initialIsTreeMode
              ? _SelectableTreeView(
                  projectId: widget.projectId,
                  nodes: nodes,
                  saveService: widget.saveService,
                  selectedIds: _selectedIds,
                  limitReached: limitReached,
                  onToggle: _toggleNode,
                )
              : _SelectableSlotView(
                  nodes: nodes,
                  slotMax: widget.saveService.slotMax,
                  selectedIds: _selectedIds,
                  limitReached: limitReached,
                  onToggle: _toggleNode,
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showSelectionList = false),
                  child: Text(l10n.saveTreeBackButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _selectedIds.length >= _effectiveLimit(nodes.length)
                      ? () => _showDiscardDialog(context, nodes)
                      : null,
                  child: Text(l10n.saveTreeNextButton),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleNode(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < _limit) {
        _selectedIds.add(id);
      }
    });
  }

  void _autoSelectLatest(List<SaveNode> nodes) {
    final sorted = [...nodes]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(sorted.take(_limit).map((n) => n.id));
    });
  }

  void _showDiscardDialog(BuildContext context, List<SaveNode> nodes) {
    final discardCount = nodes.length - _selectedIds.length;
    var applying = false;
    showDialog(
      context: context,
      builder: (ctx) => _DiscardChoiceDialog(
        discardCount: discardCount,
        onConfirm: (archive) async {
          // 変え終えてから閉じる（以前は待たずに閉じ、選ばなかった保存を
          // 消せなかったときの例外を誰も受けなかった）。二度押しで2回変えない。
          if (applying) return;
          applying = true;
          final messenger = ScaffoldMessenger.of(context);
          final failed = AppLocalizations.of(
            context,
          )!.saveTreeDeleteFailedSnackbar;
          var done = false;
          try {
            done = await widget.saveService.applyModeChange(
              projectId: widget.projectId,
              keepIds: _selectedIds.toList(),
              archive: archive,
              newIsTreeMode: widget.newIsTreeMode,
              newSlotMax: widget.newSlotMax,
            );
          } catch (error, stack) {
            AppErrorReporter.record(error, stack);
          }
          // 閉じるのは自分のダイアログと変更の画面だけ（その間に戻る操作で
          // 閉じていたら、下の画面を閉じない）。
          if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) {
            Navigator.pop(ctx);
          }
          if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
            Navigator.pop(context);
          }
          // 消せなかった保存は退避に残した（ツリー方式へ戻すと出る）。
          if (!done) messenger.showSnackBar(SnackBar(content: Text(failed)));
        },
        onBack: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ─── 選択可能スロットビュー ───
class _SelectableSlotView extends StatelessWidget {
  final List<SaveNode> nodes;
  final int slotMax;
  final Set<String> selectedIds;
  final bool limitReached;
  final ValueChanged<String> onToggle;

  const _SelectableSlotView({
    required this.nodes,
    required this.slotMax,
    required this.selectedIds,
    required this.limitReached,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bySlot = _nodesBySlot(nodes);
    return ListView.builder(
      itemCount: slotMax,
      itemBuilder: (context, slotIndex) {
        final node = bySlot[slotIndex];
        if (node == null) return const SizedBox.shrink();
        final isSelected = selectedIds.contains(node.id);
        final isDisabled = limitReached && !isSelected;
        return ListTile(
          enabled: !isDisabled,
          leading: Checkbox(
            value: isSelected,
            onChanged: isDisabled ? null : (_) => onToggle(node.id),
          ),
          title: Text(
            node.comment ?? l10n.saveTreeSlotFallbackName(slotIndex + 1),
            style: TextStyle(
              color: isDisabled
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          subtitle: Text(_formatDate(node.savedAt)),
          onTap: isDisabled ? null : () => onToggle(node.id),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─── 選択可能ツリービュー ───
class _SelectableTreeView extends StatelessWidget {
  final String projectId;
  final List<SaveNode> nodes;
  final SaveTreeService saveService;
  final Set<String> selectedIds;
  final bool limitReached;
  final ValueChanged<String> onToggle;

  const _SelectableTreeView({
    required this.projectId,
    required this.nodes,
    required this.saveService,
    required this.selectedIds,
    required this.limitReached,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final childrenIndex = _childrenIndex(nodes);
    final roots = childrenIndex[null] ?? const <SaveNode>[];
    if (roots.isEmpty) {
      return Center(child: Text(l10n.saveTreeEmptyTitle));
    }
    // 親子関係を1回の走査で平坦化してからListView.builderへ渡す。
    // 再帰でColumnを入れ子にしていた頃は、全ノードのListTileとCheckboxを
    // 毎回のbuild（＝チェックを1つ付け外しするたび）で作り直していた。
    final rows = <({SaveNode node, int depth})>[];
    void flatten(SaveNode node, int depth) {
      rows.add((node: node, depth: depth));
      for (final child in childrenIndex[node.id] ?? const <SaveNode>[]) {
        flatten(child, depth + 1);
      }
    }

    for (final root in roots) {
      flatten(root, 0);
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) =>
          _buildNode(context, l10n, rows[i].node, rows[i].depth),
    );
  }

  Widget _buildNode(
    BuildContext context,
    AppLocalizations l10n,
    SaveNode node,
    int depth,
  ) {
    final isSelected = selectedIds.contains(node.id);
    final isDisabled = limitReached && !isSelected;
    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0),
      child: ListTile(
        enabled: !isDisabled,
        leading: Checkbox(
          value: isSelected,
          onChanged: isDisabled ? null : (_) => onToggle(node.id),
        ),
        title: Text(
          node.comment ?? l10n.saveTreeNodeDefaultTitle,
          style: TextStyle(
            color: isDisabled
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        subtitle: Text(_formatDate(node.savedAt)),
        onTap: isDisabled ? null : () => onToggle(node.id),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─── 未選択データの処理選択ダイアログ ───
class _DiscardChoiceDialog extends StatefulWidget {
  final int discardCount;
  final ValueChanged<bool> onConfirm; // true=アーカイブ、false=削除
  final VoidCallback onBack;

  const _DiscardChoiceDialog({
    required this.discardCount,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  State<_DiscardChoiceDialog> createState() => _DiscardChoiceDialogState();
}

class _DiscardChoiceDialogState extends State<_DiscardChoiceDialog> {
  bool _archive = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.saveTreeDiscardDialogTitle),
      // 選択状態と変更通知はRadioGroupがまとめて持つ（各RadioListTileの
      // groupValue/onChangedはFlutter 3.32で非推奨になった）。
      content: RadioGroup<bool>(
        groupValue: _archive,
        onChanged: (v) => setState(() => _archive = v!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<bool>(
              value: true,
              title: Text(l10n.saveTreeArchiveOptionTitle),
              subtitle: Text(
                l10n.saveTreeArchiveOptionSubtitle,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            RadioListTile<bool>(
              value: false,
              title: Text(l10n.saveTreeDeleteOptionTitle),
              subtitle: Text(
                l10n.saveTreeDeleteOptionSubtitle(widget.discardCount),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onBack,
          child: Text(l10n.saveTreeBackButton),
        ),
        FilledButton(
          onPressed: () => widget.onConfirm(_archive),
          child: Text(l10n.saveTreeApplyChangeButton),
        ),
      ],
    );
  }
}
