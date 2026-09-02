import 'package:flutter/material.dart';

/// プロジェクトの背景色として選択できる色の一覧。
/// 新規プロジェクト作成画面・キャンバスモードの背景色変更で共通して使う。
const List<Color> kProjectBackgroundColorChoices = [
  Colors.white,
  Colors.black,
  Colors.transparent,
  Color(0xFFF5F5DC),
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

/// [kProjectBackgroundColorChoices]から1色を選ばせる丸スウォッチのRow。
/// 新規プロジェクト作成画面・キャンバスモード「設定・編集」の背景色変更
/// ダイアログの両方から使い、選択肢を確実に一致させる。
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
    return Wrap(
      spacing: 12,
      children: kProjectBackgroundColorChoices.map((color) {
        final isSelected = selectedColor == color;
        final isLight =
            color == Colors.white ||
            color == Colors.transparent ||
            color == const Color(0xFFF5F5DC);
        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (color == Colors.transparent)
                  CustomPaint(
                    size: const Size(40, 40),
                    painter: CheckerboardPainter(),
                  )
                else
                  Container(color: color),
                if (isSelected)
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
