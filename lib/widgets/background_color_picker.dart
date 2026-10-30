import 'package:flutter/material.dart';

/// プロジェクト背景色の候補。新規作成とキャンバス設定で共通。
/// 淡い黄色のプリセットは廃止し、白・黒・透明の3色に統一する。
const List<Color> kProjectBackgroundColorChoices = [
  Colors.white,
  Colors.black,
  Colors.transparent,
];

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
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      children: kProjectBackgroundColorChoices.map((color) {
        final selected = selectedColor == color;
        final isWhite = color == Colors.white;
        final isLight = isWhite || color == Colors.transparent;
        // Fill the *entire* circle with the selected background.
        // A theme-derived neutral outline sits outside the fill so
        // transparent pixels never show the accent color underneath.
        return GestureDetector(
          key: ValueKey<Color>(color),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(color),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: colors.onSurfaceVariant, width: 2)
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
                        else
                          ColoredBox(color: color),
                        if (selected && !isWhite)
                          Center(
                            child: Icon(
                              Icons.check,
                              size: 18,
                              color: isLight ? Colors.black87 : Colors.white,
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
      }).toList(),
    );
  }
}
