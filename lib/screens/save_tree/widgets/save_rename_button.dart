import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/save_node.dart';
import '../../../services/save_tree_service.dart';

/// Shared memo editor for empty slots, saved slots, and tree nodes.
/// Editing this text must never rewrite a saved archive or its thumbnail.
///
/// [allowBlank]がfalse（ツリーの保存の名前）のときは、空の名前で確定できない。
Future<String?> _showMemoEditor(
  BuildContext context,
  String initial, {
  bool allowBlank = true,
}) => showDialog<String>(
  context: context,
  builder: (_) => _MemoEditorDialog(initial: initial, allowBlank: allowBlank),
);

/// メモ（スロット・保存の名前）の欄。メモは1行の名前として出す（スロット・
/// ツリーの行は1行）ので改行を入れない：Enterで確定し（同じメモを書く保存の
/// ダイアログと同じ。以前はEnterが改行になり確定できなかった）、貼り付けた
/// 改行は空白にする。100字まで見えるように欄は折り返して出す。
class _MemoEditorDialog extends StatefulWidget {
  const _MemoEditorDialog({required this.initial, this.allowBlank = true});

  final String initial;

  /// 空のメモで確定できるか（スロットのメモは空にして消せる。ツリーの保存の
  /// 名前は空にできないので、空の間は「保存」を押せずEnterでも閉じない。
  /// 以前は確定したように閉じ、何も変わらず何も言わなかった）。
  final bool allowBlank;

  @override
  State<_MemoEditorDialog> createState() => _MemoEditorDialogState();
}

class _MemoEditorDialogState extends State<_MemoEditorDialog> {
  // 行・段落の区切り（U+2028・U+2029・U+0085）、縦タブ・改ページも改行と
  // 同じく扱う（残すと、1行の行にはメモの前半しか出なかった）。
  static final _lineBreaks = RegExp(
    r'\r\n|[\r\n\u000B\u000C\u0085\u2028\u2029]',
  );

  static const _maxLength = 100;

  // 前の版で改行を入れたメモも、語を失わずに1行で開く。
  late final TextEditingController _controller = TextEditingController(
    text: _oneLine(widget.initial),
  );

  // 確定・取り消しは1回だけ（次の画面を描く前の2回目のEnterで、ダイアログの
  // 下の画面まで閉じないように）。
  bool _closed = false;

  // 保存のダイアログ（字数の上限なし）・前の版で100字より長く付けた名前は、
  // 1字直しただけで100字に切らない（上限を超えていることは欄の数が
  // エラーの色で出す）。
  late final bool _longBefore = _controller.text.characters.length > _maxLength;

  bool get _canSave => widget.allowBlank || _controller.text.trim().isNotEmpty;

  static String _oneLine(String text) => text.replaceAll(_lineBreaks, ' ');

  void _close([String? memo]) {
    if (_closed || (memo != null && !_canSave)) return;
    _closed = true;
    Navigator.of(context).pop(memo == null ? null : _oneLine(memo));
  }

  @override
  void dispose() {
    // 閉じ終えてツリーから外れるときに破棄する（閉じる途中は欄がまだ使う）。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.saveTreeCommentLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: _maxLength,
        maxLengthEnforcement: _longBefore ? MaxLengthEnforcement.none : null,
        minLines: 1,
        maxLines: 3,
        // 折り返して出すが、複数行の入力ではない（Enterは改行ではなく確定）。
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.deny(_lineBreaks, replacementString: ' '),
        ],
        decoration: InputDecoration(hintText: l10n.saveTreeCommentHint),
        // Enterで欄からフォーカスを外さない。
        onEditingComplete: () {},
        onSubmitted: (_) => _close(_controller.text),
      ),
      actions: [
        TextButton(onPressed: () => _close(), child: Text(l10n.commonCancel)),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _canSave ? () => _close(_controller.text) : null,
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}

/// Slot name is independent of whether an archive exists. The same pencil
/// therefore remains tappable before save, after overwrite, and after delete.
class SaveSlotMemoButton extends StatelessWidget {
  const SaveSlotMemoButton({
    super.key,
    required this.projectId,
    required this.slotIndex,
    required this.initialMemo,
  });

  final String projectId;
  final int slotIndex;
  final String initialMemo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: Key('saveSlotMemo_${projectId}_${slotIndex}'),
      tooltip: l10n.saveTreeCommentLabel,
      icon: const Icon(Icons.edit_outlined, size: 17),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: () async {
        final memo = await _showMemoEditor(context, initialMemo);
        if (memo == null || !context.mounted) return;
        final kept = await context.read<SaveTreeService>().setSlotMemo(
          projectId,
          slotIndex,
          memo,
        );
        // 保存の一覧を読めていないので、メモは次に起動したときに残らない
        // かもしれない（スロットに出ているだけで保存できたように見えた）。
        if (!kept && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
          );
        }
      },
    );
  }
}

/// Tree nodes keep individually named historical snapshots. They do not
/// inherit the independent memo behavior of the fixed save slots.
class SaveRenameButton extends StatelessWidget {
  const SaveRenameButton({
    super.key,
    required this.node,
    required this.fallbackName,
  });

  final SaveNode node;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: Key('saveRename_${node.id}'),
      tooltip: l10n.saveTreeCommentLabel,
      icon: const Icon(Icons.edit_outlined, size: 17),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: () async {
        final memo = await _showMemoEditor(
          context,
          node.comment ?? fallbackName,
          allowBlank: false,
        );
        if (memo == null || !context.mounted) return;
        // Empty means "clear" only for slots. An archived tree snapshot must
        // retain a readable title until the storage service supports null.
        if (memo.trim().isEmpty) return;
        final ok = await context.read<SaveTreeService>().renameSave(
          node.projectId,
          node.id,
          memo,
        );
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
          );
        }
      },
    );
  }
}
