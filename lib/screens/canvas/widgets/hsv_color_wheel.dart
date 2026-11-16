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

  /// Where the transparent-colour button sits (its left edge, its top edge
  /// above the wheel's bottom, and its size).
  static const double _transparentLeft = 2;
  static const double _transparentBottomGap = 31;
  static const double _transparentSize = 26;

  double get _ringThickness => size * 0.14;
  // Leave a subtle but definite gap between the ring and SV square at
  // every picker width, including compact PC docks and mobile.
  double get _squareSize => (size - _ringThickness * 2) * 0.67;

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
    // Tuck the accessory controls into the unused outer corners of the
    // wheel. Keep their hit targets outside the hue ring and remove the
    // former generous clearance that made the controls look detached.
    final width = math.max(size, controlsWidth ?? size);
    // The mode pill follows the hue ring's exact lower-right tangent.
    // Only 2px of clearance remains; its 28px hit target never overlaps
    // the wheel, even in the narrowest supported color-picker dock.
    final radius = size / 2;
    // The pill is measured at the current text size (its names are never
    // shrunk): a fixed 66×28 pill grew with large text, cut into the ring
    // and ran over the sliders below in a narrow PC dock.
    final segment = _SliderModePill.segmentSize(context);
    final pill = _SliderModePill.sizeFor(segment);
    const pillRight = 6.0; // Keep clear of the scroll bar on phones.
    final pillLeft = width - pillRight - pill.width;
    final horizontalDistance = pillLeft - width / 2;
    // A pill wider than the right half of the ring moves below the ring
    // (its own row) instead of cutting into it.
    var modeTop = horizontalDistance <= 0
        ? 2 * radius + 2
        : radius +
              math.sqrt(
                math.max(
                  0.0,
                  radius * radius - horizontalDistance * horizontalDistance,
                ),
              ) +
              2;
    // Nor does it cover the transparent-colour button at the lower left.
    if (onToggleTransparent != null &&
        pillLeft < _transparentLeft + _transparentSize + 4) {
      modeTop = math.max(
        modeTop,
        size - _transparentBottomGap + _transparentSize + 4,
      );
    }
    return SizedBox(
      width: width,
      height: math.max(size, modeTop + pill.height),
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
                  onPanUpdate: (d) =>
                      _handleSquare(d.localPosition, squareSize),
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
                            borderRadius: BorderRadius.zero,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                              ],
                            ),
                          ),
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.zero,
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
              left: _transparentLeft,
              top: size - _transparentBottomGap,
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
                segment: segment,
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
        width: HsvColorWheel._transparentSize,
        height: HsvColorWheel._transparentSize,
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
///
/// 区画の大きさは、今の文字の大きさで名前（HSV・RGB）が入る大きさ（少なくとも
/// 32×26）。名前は縮めない（[HsvColorWheel]がこの大きさで置き場所を決める）。
class _SliderModePill extends StatelessWidget {
  const _SliderModePill({
    required this.showHsv,
    required this.onChanged,
    required this.segment,
  });

  final bool showHsv;
  final ValueChanged<bool> onChanged;

  /// 1つの区画の大きさ（[segmentSize]）。
  final Size segment;

  static const _labels = ['HSV', 'RGB'];
  static const _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );

  /// 1つの区画の大きさ：長い方の名前が今の文字の大きさで入り、左右に4px・
  /// 上下に2pxの余白が残る大きさ（少なくとも32×26）。
  static Size segmentSize(BuildContext context) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    );
    var width = 0.0;
    var height = 0.0;
    final style = DefaultTextStyle.of(context).style.merge(_labelStyle);
    for (final label in _labels) {
      painter
        ..text = TextSpan(text: label, style: style)
        ..layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
    }
    painter.dispose();
    return Size(
      math.max(32, (width + 8).ceilToDouble()),
      math.max(26, (height + 4).ceilToDouble()),
    );
  }

  /// 2つの区画と枠（1px）を合わせたピルの大きさ。
  static Size sizeFor(Size segment) =>
      Size(segment.width * 2 + 2, segment.height + 2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(segment.height / 2 + 1);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: segment.height + 2,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment('HSV', true, scheme, radius),
            _segment('RGB', false, scheme, radius),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    String label,
    bool hsv,
    ColorScheme scheme,
    BorderRadius radius,
  ) {
    final selected = showHsv == hsv;
    void select() => onChanged(hsv);
    return Semantics(
      key: ValueKey('color-slider-mode-${hsv ? 'hsv' : 'rgb'}'),
      button: true,
      selected: selected,
      label: label,
      onTap: select,
      child: InkWell(
        excludeFromSemantics: true,
        borderRadius: radius,
        onTap: select,
        child: Container(
          width: segment.width,
          height: segment.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: radius,
          ),
          child: ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: _labelStyle.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
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
