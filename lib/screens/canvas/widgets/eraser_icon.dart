import 'package:flutter/material.dart';

/// 消しゴムツール用の専用アイコン。Flutter標準のMaterial Iconsには
/// 「消しゴム」を表す適切なグリフが存在しないため（ink_eraser等の新しい
/// Material Symbolsはこのアプリが使っている従来版アイコンフォントには
/// 含まれていない）、実際の消しゴムらしい斜めの角丸長方形＋ベベル線を
/// Canvas描画で表現する。
class EraserIcon extends StatelessWidget {
  final double size;
  final Color color;
  const EraserIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _EraserPainter(color));
}

class _EraserPainter extends CustomPainter {
  final Color color;
  _EraserPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.5);

    final body = Rect.fromCenter(center: Offset.zero, width: size.width * 0.92, height: size.height * 0.5);
    final rrect = RRect.fromRectAndRadius(body, Radius.circular(size.height * 0.14));
    canvas.drawRRect(rrect, Paint()..color = color);

    // 消しゴムの角の面取り（ベベル）ラインを1本入れて、単なる角丸長方形
    // ではなく消しゴムらしいシルエットにする。
    final bevelX = body.left + body.width * 0.28;
    canvas.drawLine(
      Offset(bevelX, body.top),
      Offset(bevelX, body.bottom),
      Paint()
        ..color = color
        ..strokeWidth = size.width * 0.05,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserPainter oldDelegate) => oldDelegate.color != color;
}
