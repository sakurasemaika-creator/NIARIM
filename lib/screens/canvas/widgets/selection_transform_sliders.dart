import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/labeled_slider.dart';

/// 位置・倍率・角度の相対調整。入力・ステッパー・ドラッグで確定できる。
class SelectionTransformSliders extends StatelessWidget {
  const SelectionTransformSliders({
    super.key,
    required this.moveX,
    required this.moveY,
    required this.scale,
    required this.rotateDeg,
    required this.onChanged,
    required this.onCommit,
    required this.maxMove,
  });

  final double moveX;
  final double moveY;

  /// 倍率。1.0が等倍（＝変化なし）。
  final double scale;
  final double rotateDeg;

  /// 4値のいずれかが動いたとき。確定はせずライブプレビューだけ更新する。
  final void Function({
    double? moveX,
    double? moveY,
    double? scale,
    double? rotateDeg,
  })
  onChanged;

  /// スライダーから指を離したとき（＝実画素へ確定してよいとき）。
  final VoidCallback onCommit;

  /// 移動量スライダーの端の値（キャンバスpx）。キャンバスの大きさに合わせる。
  final double maxMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget row({
      required String label,
      required String valueText,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onSlide,
      bool isInt = true,
      double step = 1,
    }) => LabeledSlider(
      label: label,
      valueText: valueText,
      value: value,
      min: min,
      max: max,
      isInt: isInt,
      step: step,
      labelStyle: TextStyle(fontSize: 11, color: scheme.onSurface),
      valueStyle: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      onChanged: onSlide,
      onChangeEnd: (value) {
        onSlide(value);
        onCommit();
      },
    );

    String signed(double v) => '${v >= 0 ? '+' : ''}${v.round()}';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height / 3,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(
              label: l10n.canvasSelectionSliderMoveX,
              valueText: signed(moveX),
              value: moveX,
              min: -maxMove,
              max: maxMove,
              onSlide: (v) => onChanged(moveX: v),
            ),
            row(
              label: l10n.canvasSelectionSliderMoveY,
              valueText: signed(moveY),
              value: moveY,
              min: -maxMove,
              max: maxMove,
              onSlide: (v) => onChanged(moveY: v),
            ),
            row(
              label: l10n.canvasSelectionSliderScale,
              valueText: '${scale.toStringAsFixed(2)}x',
              value: scale,
              min: 0.2,
              max: 3.0,
              isInt: false,
              step: 0.05,
              onSlide: (v) => onChanged(scale: v),
            ),
            row(
              label: l10n.canvasSelectionSliderRotate,
              valueText: '${signed(rotateDeg)}°',
              value: rotateDeg,
              min: -180,
              max: 180,
              onSlide: (v) => onChanged(rotateDeg: v),
            ),
          ],
        ),
      ),
    );
  }
}
