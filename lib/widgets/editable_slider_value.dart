import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// スライダーの数値表示部分をタップすると、直接テキスト入力で値を変更
/// できるようにする共通ウィジェット（ユーザー指示：アプリ内のスライダーは
/// すべて数値部分のタップで直接入力できるようにする）。既存のSlider横に
/// 置いているTextをこれに差し替えるだけで使える。
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
    return GestureDetector(
      onTap: () => _showInputDialog(context),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }

  Future<void> _showInputDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(
        text: isInt ? value.round().toString() : _trimZeros(value.toDouble()));
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: title != null ? Text(title!) : null,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt, signed: min < 0),
          onSubmitted: (v) => Navigator.pop(ctx, _parse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, _parse(ctrl.text)), child: Text(l10n.commonOk)),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) onChanged(result.clamp(min, max));
  }

  num? _parse(String s) => isInt ? int.tryParse(s) : double.tryParse(s);

  String _trimZeros(double v) {
    var s = v.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }
}
