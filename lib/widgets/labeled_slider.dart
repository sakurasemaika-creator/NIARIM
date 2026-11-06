import 'package:flutter/material.dart';

import 'editable_slider_value.dart';
import 'stepped_slider.dart';

/// 1行目に項目名と値、2行目に［－］スライダー［＋］を並べる共通の
/// スライダー行。項目名や値をスライダーと同じ行に置くと、スマホの狭い
/// 画面ではそのぶんスライダーが縮み、つまみを動かせる幅がほとんど
/// 残らない。項目名と値を上の行へ出し、スライダー本体を－と＋の間で
/// 画面の横幅いっぱいに広げる。
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.valueText,
    this.editable = true,
    this.isInt = true,
    this.divisions,
    this.step = 1,
    this.labelTrailing,
    this.activeColor,
    this.inactiveColor,
    this.sliderLabel,
    this.showSteppers = true,
    this.labelStyle,
    this.valueStyle,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  /// 1行目に出す項目名。
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// 1行目の右端に出す値。nullなら出さない。
  final String? valueText;

  /// 値をタップして直接入力できるか。
  final bool editable;

  /// 直接入力を整数で受けるか。
  final bool isInt;
  final int? divisions;

  /// ［－］［＋］1回の増減幅。
  final double step;

  /// 項目名の右に添えるもの（説明のアイコン・スイッチ等）。
  final Widget? labelTrailing;
  final Color? activeColor;
  final Color? inactiveColor;

  /// つまみを動かしている間の吹き出し（[Slider.label]）。
  final String? sliderLabel;
  final bool showSteppers;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final valueTextStyle = valueStyle ?? const TextStyle(fontSize: 12);
    final shown = valueText;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1行目：項目名と値（値は右端。鉛筆マークは値の右へはみ出して
          // 描かれるので、そのぶん右に余白を取る）。
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 20),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: labelStyle ?? const TextStyle(fontSize: 12),
                        ),
                      ),
                      ?labelTrailing,
                    ],
                  ),
                ),
                if (shown != null)
                  editable && onChanged != null
                      ? EditableSliderValue(
                          text: shown,
                          style: valueTextStyle,
                          textAlign: TextAlign.right,
                          title: label,
                          value: value,
                          min: min,
                          max: max,
                          isInt: isInt,
                          onChanged: (v) {
                            final next = v.toDouble().clamp(min, max);
                            onChanged!(next);
                            onChangeEnd?.call(next);
                          },
                        )
                      : Text(
                          shown,
                          style: valueTextStyle,
                          textAlign: TextAlign.right,
                        ),
              ],
            ),
          ),
          // 2行目：－・スライダー・＋だけで横幅いっぱいを使う。
          SteppedSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            step: step,
            compact: true,
            label: sliderLabel,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            showSteppers: showSteppers,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}
