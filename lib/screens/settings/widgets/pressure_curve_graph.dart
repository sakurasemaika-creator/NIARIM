import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 筆圧カーブのグラフエディタ（仕様書08・タスク#93）。X軸＝実際の筆圧
/// （0〜1）、Y軸＝反映される太さ・不透明度の倍率（0〜1）として、
/// 現在のカーブ形状（y = x^exponent）を曲線で表示する。グラフ上の
/// x=0.5の点（ハンドル）をドラッグすると、その高さに応じてexponentを
/// 逆算して更新する（数値スライダーより直感的に形を確認・調整できる）。
class PressureCurveGraph extends StatelessWidget {
  final double exponent;
  final ValueChanged<double> onExponentChanged;
  final double size;

  const PressureCurveGraph({
    super.key,
    required this.exponent,
    required this.onExponentChanged,
    this.size = 200,
  });

  void _handleDrag(Offset localPos) {
    final x = (localPos.dx / size).clamp(0.02, 0.98);
    final y = (1.0 - localPos.dy / size).clamp(0.02, 0.98);
    // y = x^exponent を解く： exponent = ln(y) / ln(x)
    final newExponent = (math.log(y) / math.log(x)).clamp(0.3, 3.0);
    onExponentChanged(newExponent);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanStart: (d) => _handleDrag(d.localPosition),
      onPanUpdate: (d) => _handleDrag(d.localPosition),
      onTapDown: (d) => _handleDrag(d.localPosition),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: CustomPaint(
          painter: _PressureCurvePainter(exponent: exponent, color: scheme.primary),
        ),
      ),
    );
  }
}

class _PressureCurvePainter extends CustomPainter {
  final double exponent;
  final Color color;
  _PressureCurvePainter({required this.exponent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final t = i / 4;
      canvas.drawLine(Offset(size.width * t, 0), Offset(size.width * t, size.height), gridPaint);
      canvas.drawLine(Offset(0, size.height * t), Offset(size.width, size.height * t), gridPaint);
    }
    // 傾き1の参考対角線（筆圧をそのまま反映する基準線）
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );

    final path = Path();
    for (int i = 0; i <= 100; i++) {
      final x = i / 100;
      final y = math.pow(x, exponent).toDouble();
      final p = Offset(x * size.width, (1 - y) * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // ドラッグ用ハンドル（x=0.5地点の現在の高さ）
    final midY = math.pow(0.5, exponent).toDouble();
    final handle = Offset(size.width * 0.5, (1 - midY) * size.height);
    canvas.drawCircle(handle, 8, Paint()..color = color);
    canvas.drawCircle(
      handle,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PressureCurvePainter old) => old.exponent != exponent || old.color != color;
}
