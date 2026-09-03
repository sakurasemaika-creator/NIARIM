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
            right: -11,
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
      ),
    );
    if (result != null) onChanged(result.clamp(min, max));
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
  });

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

  num? _parse(String s) => widget.isInt ? int.tryParse(s) : double.tryParse(s);

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
        onSubmitted: (v) => Navigator.pop(context, _parse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _parse(_controller.text)),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
