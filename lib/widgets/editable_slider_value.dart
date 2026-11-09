import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// スライダーの数値表示部分をタップすると、直接テキスト入力で値を変更
/// できるようにする共通ウィジェット。既存のSlider横に置いているTextを
/// これに差し替えるだけで使える。
class EditableSliderValue extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final num value;
  final num min;
  final num max;
  final String? title;
  // trueの場合は整数入力（小数点キーボードを出さない・int.tryParseで検証）。
  final bool isInt;
  final ValueChanged<num> onChanged;
  final TextAlign? textAlign;
  final double editIconRight;

  const EditableSliderValue({
    super.key,
    required this.text,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.style,
    this.title,
    this.isInt = true,
    this.textAlign,
    this.editIconRight = -11,
  });

  @override
  Widget build(BuildContext context) {
    // 数値部分がタップ可能なことは初見で気付きにくいため、右側に小さな
    // 鉛筆マークを添える。周囲の多くの呼び出し元は固定幅のSizedBoxで
    // 数値表示を包んでいるため、レイアウト幅は変えずにStack+Positioned
    // （clipBehavior: none）でマークを右側へわずかにはみ出させる形にして
    // いる（呼び出し元すべての幅を広げる変更は影響範囲が大きすぎるため）。
    return GestureDetector(
      onTap: () => _showInputDialog(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(text, style: style, textAlign: textAlign),
          Positioned(
            right: editIconRight,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(
                Icons.edit,
                size: 9,
                color:
                    (style?.color ??
                            Theme.of(context).colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInputDialog(BuildContext context) async {
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => _NumberInputDialog(
        title: title,
        initialValue: value,
        isInt: isInt,
        signed: min < 0,
        min: min,
        max: max,
      ),
    );
    if (result != null && result.isFinite) onChanged(result.clamp(min, max));
  }
}

/// 入力欄のTextEditingControllerを自身のStateで管理するダイアログ本体。
/// ダイアログの呼び出し元（EditableSliderValue._showInputDialog）で
/// controllerを生成してshowDialog完了直後にdispose()すると、閉じる
/// トランジションアニメーション中にまだTextFieldがcontrollerを参照して
/// おり「TextEditingController was used after being disposed」になる
/// （アニメーション完了はshowDialogのFuture解決より後）。Stateのdispose()
/// はウィジェットが実際にツリーから外れるタイミング（アニメーション完了後）
/// まで呼ばれないため、ここへ持たせることでこの競合を避けられる。
class _NumberInputDialog extends StatefulWidget {
  final String? title;
  final num initialValue;
  final bool isInt;
  final bool signed;

  const _NumberInputDialog({
    required this.title,
    required this.initialValue,
    required this.isInt,
    required this.signed,
    required this.min,
    required this.max,
  });

  final num min;
  final num max;

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.isInt
          ? widget.initialValue.round().toString()
          : _trimZeros(widget.initialValue.toDouble()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 打った文字のうち、範囲の中の有限の数だけを受け付ける（「NaN」
  // 「Infinity」も数として読めるので、そのまま渡すと太さが数でなくなった）。
  // 全角の数字・記号は半角へ寄せる。
  num? _parse(String s) {
    final text = s.trim().replaceAllMapped(
      RegExp('[０-９．－]'),
      (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0),
    );
    final value = widget.isInt ? int.tryParse(text) : double.tryParse(text);
    if (value == null || !value.isFinite) return null;
    if (value < widget.min || value > widget.max) return null;
    return value;
  }

  String? _error;

  /// 範囲の中の数なら閉じて返す。そうでなければ開いたまま範囲を知らせる
  /// （以前は黙って閉じる・黙って範囲へ丸めていた）。
  void _submit(String text) {
    final value = _parse(text);
    if (value == null) {
      setState(() => _error = _rangeText());
      return;
    }
    Navigator.pop(context, value);
  }

  String _format(num v) =>
      widget.isInt ? v.round().toString() : _trimZeros(v.toDouble());

  String _rangeText() =>
      AppLocalizations.of(context)!
          .numberInputRangeError(_format(widget.min), _format(widget.max));

  String _trimZeros(double v) {
    var s = v.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: widget.title != null ? Text(widget.title!) : null,
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          decimal: !widget.isInt,
          signed: widget.signed,
        ),
        decoration: InputDecoration(
          helperText: _error == null ? _rangeText() : null,
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        // 確定できなかったときに欄からフォーカスが外れないように。
        onEditingComplete: () {},
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
