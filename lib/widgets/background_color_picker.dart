import 'package:flutter/material.dart';

import '../screens/canvas/widgets/color_picker_panel.dart';
import '../utils/app_locale.dart';
import 'typing_dialog_inset.dart';

/// プロジェクト背景色の決まった候補。新規作成とキャンバス設定で共通。
/// これに加えて「ほかの色」でカラーピッカーから好きな不透明の色を選べる
/// （以前の「黒」もここから選ぶ。所有者の判断、2026-11-28「背景黒を選択肢から
/// 無くして代わりにカラーピッカーから自由に選べるようにする」）。
const List<Color> kProjectBackgroundColorChoices = [
  Colors.white,
  Colors.transparent,
];

/// 「ほかの色」のスウォッチの印のキー。
const Key kBackgroundColorOtherKey = ValueKey<String>('backgroundColorOther');

/// 「透明」背景色スウォッチ用の市松模様を描画する。
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 8.0;
    final light = Paint()..color = Colors.grey[300]!;
    final dark = Paint()..color = Colors.grey[400]!;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final isDark = ((x / cell).round() + (y / cell).round()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), isDark ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 新規プロジェクト作成・キャンバスの背景色変更で共用する色スウォッチ。
/// 白は純白の円を優先し、アクセント色の輪やチェックを中へ描かない。
/// 選択状態はテーマの中立色の外枠で区別する。
class BackgroundColorSwatchPicker extends StatelessWidget {
  const BackgroundColorSwatchPicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final words = appLocalizationsOf(context);
    final other = !kProjectBackgroundColorChoices.contains(selectedColor);
    return Wrap(
      spacing: 12,
      children: [
        for (final color in kProjectBackgroundColorChoices)
          _Swatch(
            key: ValueKey<Color>(color),
            label: color == Colors.white
                ? words.timelineColorWhite
                : words.canvasBackgroundTransparent,
            selected: selectedColor == color,
            fill: color,
            onPressed: () => onChanged(color),
          ),
        _Swatch(
          key: kBackgroundColorOtherKey,
          label: words.backgroundColorOther,
          selected: other,
          fill: other ? selectedColor : null,
          onPressed: () => _pickOther(context),
        ),
      ],
    );
  }

  /// カラーピッカーで不透明な色を選ぶ。動かしている間は何度も知らせず、
  /// 閉じたときに選んだ色を1回だけ[onChanged]へ渡す（キャンバスのシートは
  /// 知らせを受けると閉じ、作品の背景色の変更は1回の取り消しになる）。
  Future<void> _pickOther(BuildContext context) async {
    final start = kProjectBackgroundColorChoices.contains(selectedColor)
        ? Colors.black
        : selectedColor;
    Color? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: typingDialogInsetPadding(
          ctx,
          usual: const EdgeInsets.all(16),
        ),
        child: ColorPickerPanel(
          currentColor: start,
          opaqueOnly: true,
          onColorChanged: (color) => picked = color,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
    final chosen = picked;
    if (chosen != null && chosen != selectedColor) onChanged(chosen);
  }
}

/// 背景色の1つのスウォッチ。[fill]がnullなら「ほかの色」の印（まだ選んで
/// いない）を描く。
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.label,
    required this.selected,
    required this.fill,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color? fill;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = fill;
    final isWhite = color == Colors.white;
    // Fill the *entire* circle with the selected background.
    // A theme-derived neutral outline sits outside the fill so
    // transparent pixels never show the accent color underneath.
    final light =
        color == null ||
        color == Colors.transparent ||
        color.computeLuminance() > 0.4;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: IconButton(
          iconSize: 44,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          style: ButtonStyle(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: colors.onSurface, width: 2)
                  : BorderSide.none,
            ),
          ),
          onPressed: onPressed,
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected || isWhite || color == null
                  ? Border.all(
                      color: selected
                          ? colors.onSurfaceVariant
                          : colors.outlineVariant,
                      width: selected ? 2 : 1,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (color == Colors.transparent)
                      CustomPaint(painter: CheckerboardPainter())
                    else if (color != null)
                      ColoredBox(color: color),
                    if (color == null)
                      Icon(
                        Icons.palette_outlined,
                        size: 22,
                        color: colors.onSurfaceVariant,
                      )
                    else if (selected && !isWhite)
                      Center(
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: light ? Colors.black87 : Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
