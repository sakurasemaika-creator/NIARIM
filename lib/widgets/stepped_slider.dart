import 'package:flutter/material.dart';

/// Slider本体の左右に「－」「＋」ボタンを添えた共通ウィジェット。指や
/// マウスでの細かいドラッグ操作が難しい環境でも、ボタンタップだけで
/// [step]刻みの微調整ができるようにする。既存の`Slider(...)`をそのまま
/// `SteppedSlider(...)`へ置き換えるだけで使える（プロパティ構成は
/// Sliderに準拠）。
class SteppedSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  // ボタン1回あたりの増減幅。既定は1（0〜100等の一般的な整数レンジ向け）。
  // 0〜1・-1〜1のような小数レンジのスライダーでは、呼び出し側で0.01〜0.1
  // 程度の小さい値を指定する。
  final double step;
  // nullの場合はSlider同様に操作不可（無効）表示になる。
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final String? label;

  const SteppedSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.divisions,
    this.step = 1,
    this.activeColor,
    this.inactiveColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
          tooltip: '-$step',
          onPressed: (onChanged == null || clamped <= min)
              ? null
              : () {
                  final v = (clamped - step).clamp(min, max);
                  onChanged!(v);
                  onChangeEnd?.call(v);
                },
        ),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
          tooltip: '+$step',
          onPressed: (onChanged == null || clamped >= max)
              ? null
              : () {
                  final v = (clamped + step).clamp(min, max);
                  onChanged!(v);
                  onChangeEnd?.call(v);
                },
        ),
      ],
    );
  }
}
