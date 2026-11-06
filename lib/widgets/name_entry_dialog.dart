import 'package:flutter/material.dart';

import '../config/accent_text_theme.dart';
import '../screens/canvas/widgets/canvas_icon_button.dart';

import '../utils/app_error_reporter.dart';

/// 名前を1つ入力するダイアログ（フォルダの作成・作品やフォルダの名前の
/// 変更）。入力欄のコントローラーはこのダイアログ自身が持ち、閉じ終えて
/// ツリーから外れるときに破棄する（閉じる途中で破棄すると落ちることがある）。
///
/// 空白だけの名前は確定できない（以前は空の名前に変更でき、カードから
/// 名前が消えた）。Enterでも確定でき、確定は1回だけ（ボタンを素早く2回
/// 押すとフォルダが2つできた）。
class NameEntryDialog extends StatefulWidget {
  const NameEntryDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onSubmit,
    this.initialName = '',
    this.labelText,
    this.hint,
  });

  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String initialName;
  final String? labelText;

  /// 入力欄の下に出す補足。
  final Widget? hint;

  /// 前後の空白を除いた名前を受け取る。終わったらダイアログを閉じる。
  final Future<void> Function(String name) onSubmit;

  @override
  State<NameEntryDialog> createState() => _NameEntryDialogState();
}

class _NameEntryDialogState extends State<NameEntryDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitting && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_controller.text.trim());
    } catch (error, stack) {
      // 失敗したら開いたまま、もう一度押せるようにする。
      AppErrorReporter.record(error, stack);
      if (mounted) setState(() => _submitting = false);
      return;
    }
    // 閉じ始めた後に終わった場合、popすると下の画面を閉じてしまう。
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 確定の処理中は閉じない（取り消したつもりでも名前は変わるため）。
    return PopScope(canPop: !_submitting, child: _buildDialog(context));
  }

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            // 空のままEnterを押しても欄から抜けず、続けて打てる。
            onEditingComplete: () {},
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.labelText,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.hint != null) ...[const SizedBox(height: 8), widget.hint!],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            widget.cancelLabel,
            style: TextStyle(shadows: cancelLabelShadows(context)),
          ),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// ダイアログの「キャンセル」（文字のボタン）の文字が下地とほとんど同じ色の
/// ときだけ縁取りを付ける。色はテーマ・外観で選んだまま変えない。
List<Shadow>? cancelLabelShadows(BuildContext context) {
  final theme = Theme.of(context);
  return CanvasIconButton.actionShadows(
    AccentTextTheme.of(context),
    theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
    theme.colorScheme,
  );
}
