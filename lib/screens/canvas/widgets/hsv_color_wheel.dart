import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 正方形（彩度・明度）＋外側カラーサークル（色相）のタップ選択式カラー
/// ピッカー（仕様書20：色管理仕様、タスク#91）。従来のH/S/Vスライダー方式に
/// 代わるもの。外周のリングをタップ・ドラッグすると色相が、内側の正方形を
/// タップ・ドラッグすると彩度（横）・明度（縦）が変わる。
class HsvColorWheel extends StatelessWidget {
  final double hue;
  final double saturation;
  final double value;
  final ValueChanged<double> onHueChanged;
  final void Function(double saturation, double value) onSvChanged;
  final VoidCallback? onChangeEnd;
  final double size;
  // 透明色への切り替えボタン（仕様書20：カラーピッカーは常に透明色も選択
  // できるようにする）。円の外側・左下の空きスペースに配置する。
  final bool isTransparent;
  final VoidCallback? onToggleTransparent;

  const HsvColorWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onHueChanged,
    required this.onSvChanged,
    this.onChangeEnd,
    this.size = 220,
    this.isTransparent = false,
    this.onToggleTransparent,
  });

  double get _ringThickness => size * 0.14;
  double get _squareSize => (size - _ringThickness * 2) * 0.72;

  @override
  Widget build(BuildContext context) {
    final ringThickness = _ringThickness;
    final squareSize = _squareSize;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _handleRing(d.localPosition),
            onPanUpdate: (d) => _handleRing(d.localPosition),
            onPanEnd: (_) => onChangeEnd?.call(),
            onTapDown: (d) => _handleRing(d.localPosition),
            onTapUp: (_) => onChangeEnd?.call(),
            child: CustomPaint(
              size: Size(size, size),
              painter: _HueRingPainter(hue: hue, thickness: ringThickness),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _handleSquare(d.localPosition, squareSize),
            onPanUpdate: (d) => _handleSquare(d.localPosition, squareSize),
            onPanEnd: (_) => onChangeEnd?.call(),
            onTapDown: (d) => _handleSquare(d.localPosition, squareSize),
            onTapUp: (_) => onChangeEnd?.call(),
            child: SizedBox(
              width: squareSize,
              height: squareSize,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
                      ),
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (saturation * squareSize) - 8,
                    top: ((1 - value) * squareSize) - 8,
                    child: _marker(),
                  ),
                ],
              ),
            ),
          ),
          if (onToggleTransparent != null)
            Positioned(
              left: size * 0.03,
              bottom: size * 0.03,
              child: _TransparentToggleButton(
                isActive: isTransparent,
                onTap: onToggleTransparent!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
      ),
    );
  }

  void _handleRing(Offset localPos) {
    final center = Offset(size / 2, size / 2);
    final v = localPos - center;
    var deg = math.atan2(v.dy, v.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    onHueChanged(deg);
  }

  void _handleSquare(Offset localPos, double squareSize) {
    final s = (localPos.dx / squareSize).clamp(0.0, 1.0);
    final v = 1.0 - (localPos.dy / squareSize).clamp(0.0, 1.0);
    onSvChanged(s, v);
  }
}

class _HueRingPainter extends CustomPainter {
  final double hue;
  final double thickness;

  _HueRingPainter({required this.hue, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - thickness;
    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    const colors = [
      Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
      Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
    ];
    final ringPaint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawCircle(center, (outerRadius + innerRadius) / 2, ringPaint);

    // 現在の色相位置のマーカー。
    final angle = hue * math.pi / 180;
    final markerCenter = center + Offset(math.cos(angle), math.sin(angle)) * (outerRadius + innerRadius) / 2;
    canvas.drawCircle(markerCenter, thickness / 2 - 2, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(markerCenter, thickness / 2 - 2, Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_HueRingPainter old) => old.hue != hue || old.thickness != thickness;
}

/// 透明色への切り替えボタン（仕様書20）。チェッカー柄の円で「透明」を表現し、
/// 現在すでに透明色を選択中の場合は縁を強調表示する。
class _TransparentToggleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _TransparentToggleButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        child: ClipOval(
          child: Stack(
            children: [
              CustomPaint(size: const Size(26, 26), painter: _MiniCheckerPainter()),
              if (isActive)
                const Center(child: Icon(Icons.check, size: 14, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 6.5;
    final light = Paint()..color = const Color(0xFFEEEEEE);
    final dark = Paint()..color = const Color(0xFFAAAAAA);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final isDark = ((x / cell).floor() + (y / cell).floor()) % 2 == 0;
        if (isDark) canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniCheckerPainter oldDelegate) => false;
}
