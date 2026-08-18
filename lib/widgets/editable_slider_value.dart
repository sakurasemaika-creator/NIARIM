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
    // 数値部分をタップすると直接入力できることに初見で気付きにくいという
    // ユーザー指摘のため、右側に小さな鉛筆マークを添える。周囲の多くの
    // 呼び出し元は固定幅のSizedBoxで数値表示を包んでいるため、レイアウト
    // 幅は変えずにStack+Positioned（clipBehavior: none）でマークを右側へ
    // わずかにはみ出させる形にしている（呼び出し元すべての幅を広げる
    // 変更は影響範囲が大きすぎるため）。
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
              child: Icon(Icons.edit, size: 9, color: (style?.color ?? Theme.of(context).colorScheme.onSurfaceVariant).withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
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
