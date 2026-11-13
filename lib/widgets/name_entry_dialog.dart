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
    this.failureText,
    this.showsProgress = false,
    this.closableWhileSubmitting = false,
  });

  final String title;
  final String confirmLabel;
  final String cancelLabel;
  final String initialName;
  final String? labelText;

  /// 入力欄の下に出す補足。
  final Widget? hint;

  /// [onSubmit]が失敗したときにダイアログの中に出す文（打った名前は残し、
  /// 名前を打ち直すと消える）。nullなら文は出さない。
  final String Function(Object error)? failureText;

  /// 確定の処理中、確定ボタンの中に進んでいる印を出す（保存に時間の
  /// かかることがあるフォルダの作成・名前の変更）。
  final bool showsProgress;

  /// 確定の処理中も「キャンセル」・戻る操作で閉じられる（閉じた後に処理が
  /// 終わっても、下の画面は閉じない）。既定では処理中は閉じない。
  final bool closableWhileSubmitting;

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
  Object? _failure;
  final _failureKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitting && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await widget.onSubmit(_controller.text.trim());
    } catch (error, stack) {
      // 失敗したら開いたまま、もう一度押せるようにする。
      AppErrorReporter.record(error, stack);
      if (mounted) {
        setState(() {
          _submitting = false;
          _failure = error;
        });
        // 横向き・大きな文字では文が欄の下の見えない所に出ることがある。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _failureKey.currentContext;
          if (mounted && target != null) Scrollable.ensureVisible(target);
        });
      }
      return;
    }
    // 閉じ始めた後（キャンセルした後）に終わった場合は何もしない（popすると
    // 下の画面を閉じてしまう）。保存の途中で別の画面（共有の受け取り等）が
    // 上に重なったときは、その下のこのダイアログだけを閉じる（閉じないと、
    // 済んだのに進んでいる印のまま残った）。
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 確定の処理中は閉じない（取り消したつもりでも名前は変わるため）。
    // [NameEntryDialog.closableWhileSubmitting]のときだけ閉じられる。
    return PopScope(
      canPop: !_submitting || widget.closableWhileSubmitting,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    // キーボードの分はここで遅れずに空ける。入力欄はキーボードが動くたびに
    // その時点の大きさで見える所までスクロールするので、ダイアログ自身に
    // 任せる（100msかけて縮む）と、縮み終える間に欄がまた見えない所へ
    // 押し出された。
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: _buildAlert(context),
      ),
    );
  }

  Widget _buildAlert(BuildContext context) {
    return AlertDialog(
      // 横向きでキーボードが開くと高さが足りない。スクロールしないと、入力欄が
      // 高さ0の並びの中で描かれず、見えない名前を打つことになった。
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _failure = null),
            // 空のままEnterを押しても欄から抜けず、続けて打てる。
            onEditingComplete: () {},
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.labelText,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.hint != null) ...[const SizedBox(height: 8), widget.hint!],
          if (_failure != null && widget.failureText != null) ...[
            const SizedBox(height: 12),
            Semantics(
              key: _failureKey,
              liveRegion: true,
              child: Text(widget.failureText!(_failure!)),
            ),
          ],
          // ボタンも中身と一緒にスクロールする（小さな画面・大きな文字で
          // キーボードが開くと、下に固定したボタンの行が入らずはみ出し、
          // 「作成」を押せなかった）。並び方はダイアログの操作の行と同じ。
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: _submitting && !widget.closableWhileSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    widget.cancelLabel,
                    style: TextStyle(shadows: cancelLabelShadows(context)),
                  ),
                ),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  // 確定の処理中は、ボタンの大きさを変えずに進んでいることを出す。
                  child: !widget.showsProgress
                      ? Text(widget.confirmLabel)
                      : Builder(
                          builder: (context) => Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: _submitting ? 0 : 1,
                                child: Text(widget.confirmLabel),
                              ),
                              if (_submitting)
                                SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    color: DefaultTextStyle.of(
                                      context,
                                    ).style.color,
                                    semanticsLabel: widget.confirmLabel,
                                  ),
                                ),
                            ],
                          ),
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
