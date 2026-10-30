import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/docked_panel_scope.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';

/// レイヤー全体の自由変形・メッシュ変形のコントロールパネル。
/// 実際の格子点ドラッグ・ワーププレビューはCanvasArea側
/// （キャンバス上）で行い、このパネルは分割数（メッシュの細かさ）・
/// 全体の回転・拡大縮小のスライダーと、確定（適用）・キャンセルの操作
/// のみを担う。範囲選択の変形と異なり、選択範囲なしで現在レイヤー全体を
/// 対象にする。
class MeshTransformPanel extends StatelessWidget {
  static const _sliderPadding = EdgeInsets.symmetric(horizontal: 8);

  final int density;
  final double rotateDeg;
  final double scaleValue;
  final ValueChanged<int> onDensityChanged;
  final ValueChanged<double> onRotateChanged;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  const MeshTransformPanel({
    super.key,
    required this.density,
    required this.rotateDeg,
    required this.scaleValue,
    required this.onDensityChanged,
    required this.onRotateChanged,
    required this.onScaleChanged,
    required this.onApply,
    required this.onCancel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PanelSurface(
      width: 240,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelCenterCloseBar(onClose: onClose),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              l10n.meshTransformPanelTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.meshTransformPanelHint,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 12),
          LabeledSlider(
            padding: _sliderPadding,
            label: l10n.meshTransformDensityLabel,
            valueText: '$density×$density',
            editable: false,
            value: density.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => onDensityChanged(v.round()),
          ),
          LabeledSlider(
            padding: _sliderPadding,
            label: l10n.meshTransformRotateLabel,
            valueText: '${rotateDeg.round()}°',
            editable: false,
            value: rotateDeg,
            min: -180,
            max: 180,
            onChanged: onRotateChanged,
          ),
          LabeledSlider(
            padding: _sliderPadding,
            label: l10n.meshTransformScaleLabel,
            valueText: '${scaleValue.toStringAsFixed(2)}×',
            editable: false,
            value: scaleValue,
            min: 0.2,
            max: 3.0,
            step: 0.05,
            onChanged: onScaleChanged,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onApply,
                    child: Text(l10n.meshTransformApplyButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
