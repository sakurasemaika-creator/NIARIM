import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/theme_service.dart';

/// 正方形（彩度・明度）＋外側カラーサークル（色相）のタップ選択式カラー
/// ピッカー。従来のH/S/Vスライダー方式に
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
  /// Width available to the controls under the ring; lets both buttons sit
  /// at the panel edges without making the wheel itself narrow.
  final double? controlsWidth;
  final VoidCallback? onEyedropperTap;
  final String? eyedropperTooltip;
  // 透明色への切り替えボタン（カラーピッカーは常に透明色も選択
  // できるようにする）。円の外側・左下の空きスペースに配置する。
  final bool isTransparent;
  final VoidCallback? onToggleTransparent;
  // 円の右下に置くHSV/RGBスライダーモード選択ピル。
  final bool showHsvSliders;
  final ValueChanged<bool>? onSliderModeChanged;

  const HsvColorWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onHueChanged,
    required this.onSvChanged,
    this.onChangeEnd,
    this.size = 220,
    this.controlsWidth,
    this.onEyedropperTap,
    this.eyedropperTooltip,
    this.isTransparent = false,
    this.onToggleTransparent,
    this.showHsvSliders = true,
    this.onSliderModeChanged,
  });

  double get _ringThickness => size * 0.14;
  double get _squareSize => (size - _ringThickness * 2) * 0.72;

  @override
  Widget build(BuildContext context) {
    final ringThickness = _ringThickness;
    final squareSize = _squareSize;
    // マーカーの縁取りはテーマのメニュー背景色連動にする（ホイール自体は
    // 色相・彩度・明度を表す機能上のグラデーションのため色固定のまま）。
    final markerOutlineColor = context
        .watch<ThemeService>()
        .current
        .menuBgColor;
    // Controls occupy the empty corners of the ring's bounding square.
    // They are moved up into the unused space, not over the hue ring itself:
    // the ring is centered and its lower edge only touches the middle.
    // Keeping the bottom 20px visible also avoids wasting a 36px row.
    final width = math.max(size, controlsWidth ?? size);
    // The pill occupies the lower-right corner, at a mathematically safe
    // tangent to the hue ring. In a narrow dock it moves down just enough
    // to avoid overlap; in a wide dock it sits higher. No wasted bottom row.
    final radius = size / 2;
    const pillWidth = 66.0; // Two 32px segments and the 1px borders.
    const pillRight = -6.0;
    final pillLeft = width - pillRight - pillWidth;
    final horizontalDistance = pillLeft - width / 2;
    final modeTop = radius +
        math.sqrt(math.max(
          0.0,
          radius * radius - horizontalDistance * horizontalDistance,
        )) +
        5;
    return SizedBox(
      width: width,
      height: math.max(size, modeTop + 28),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
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
                    painter: _HueRingPainter(
                      hue: hue,
                      thickness: ringThickness,
                      markerOutlineColor: markerOutlineColor,
                    ),
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
                              colors: [
                                Colors.white,
                                HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                              ],
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
                          child: _marker(markerOutlineColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onEyedropperTap != null)
            Positioned(
              // In compact docks the 40px touch target needs a few pixels
              // of the panel's outer padding to stay clear of the hue ring.
              right: -5,
              top: -5,
              child: IconButton(
                key: const ValueKey('color-picker-eyedropper'),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.colorize, size: 18),
                tooltip: eyedropperTooltip,
                onPressed: onEyedropperTap,
              ),
            ),
          if (onToggleTransparent != null)
            Positioned(
              left: 2,
              top: size - 27,
              child: _TransparentToggleButton(
                isActive: isTransparent,
                onTap: onToggleTransparent!,
              ),
            ),
          if (onSliderModeChanged != null)
            Positioned(
              right: pillRight,
              top: modeTop,
              child: _SliderModePill(
                showHsv: showHsvSliders,
                onChanged: onSliderModeChanged!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker(Color outlineColor) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: outlineColor, width: 2),
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
  final Color markerOutlineColor;

  _HueRingPainter({
    required this.hue,
    required this.thickness,
    required this.markerOutlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - thickness;
    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    const colors = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    final ringPaint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawCircle(center, (outerRadius + innerRadius) / 2, ringPaint);

    // 現在の色相位置のマーカー。
    final angle = hue * math.pi / 180;
    final markerCenter =
        center +
        Offset(math.cos(angle), math.sin(angle)) *
            (outerRadius + innerRadius) /
            2;
    canvas.drawCircle(
      markerCenter,
      thickness / 2 - 2,
      Paint()
        ..color = markerOutlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      markerCenter,
      thickness / 2 - 2,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_HueRingPainter old) =>
      old.hue != hue ||
      old.thickness != thickness ||
      old.markerOutlineColor != markerOutlineColor;
}

/// 透明色への切り替えボタン。チェッカー柄の円で「透明」を表現し、
/// 現在すでに透明色を選択中の場合は縁を強調表示する。
class _TransparentToggleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _TransparentToggleButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('color-picker-transparent-toggle'),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        child: ClipOval(
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(26, 26),
                painter: _MiniCheckerPainter(),
              ),
              if (isActive)
                const Center(
                  child: Icon(Icons.check, size: 14, color: Colors.black87),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 左下の透明色トグルと右下位置が対称になるように配置する。
/// 選択中のモードだけを強調し、タップしたモードの3スライダーを表示する。
class _SliderModePill extends StatelessWidget {
  const _SliderModePill({
    required this.showHsv,
    required this.onChanged,
  });

  final bool showHsv;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'HSV / RGB',
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment('HSV', true, scheme),
            _segment('RGB', false, scheme),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool hsv, ColorScheme scheme) {
    final selected = showHsv == hsv;
    return InkWell(
      key: ValueKey('color-slider-mode-${hsv ? 'hsv' : 'rgb'}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(hsv),
      child: Container(
        constraints: const BoxConstraints(minWidth: 32),
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: selected ? scheme.onPrimary : scheme.onSurface,
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
