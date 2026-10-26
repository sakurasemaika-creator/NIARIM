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
        return GestureDetector(
          key: ValueKey<Color>(color),
          onTap: () => onChanged(color),
          child: Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isWhite
                    ? (selected ? colors.onSurfaceVariant : colors.outlineVariant)
                    : (selected ? colors.primary : colors.outlineVariant),
                width: selected ? (isWhite ? 2 : 3) : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // サイズを厳密に満たし、白い円の内側に背景色が
                // 見える隙間を作らない。
                Positioned.fill(
                  child: color == Colors.transparent
                      ? CustomPaint(painter: CheckerboardPainter())
                      : ColoredBox(color: color),
                ),
                // 白だけはスウォッチ内部を白一色のまま見せる。
                if (selected && !isWhite)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: isLight ? Colors.black87 : Colors.white,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
