import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/layer_mask.dart';
import 'labeled_slider.dart';

/// Shape choice of a mask, including none.
enum _MaskChoice { none, rectangle, ellipse }

/// Edits a timeline mask: none, a rectangle or an ellipse, where it is, how
/// big, turned how far, how soft its edge is and whether it hides the inside
/// instead. Positions and sizes are percentages of the canvas, so a mask
/// keeps its place when the canvas size changes.
class LayerMaskEditor extends StatelessWidget {
  const LayerMaskEditor({
    super.key,
    required this.mask,
    required this.onChanged,
    this.hint,
  });

  final LayerMask? mask;
  final ValueChanged<LayerMask?> onChanged;

  /// What the mask applies to, shown under the shape choice.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = mask;
    final choice = current == null
        ? _MaskChoice.none
        : current.shape == LayerMaskShape.ellipse
        ? _MaskChoice.ellipse
        : _MaskChoice.rectangle;
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      String unit,
      LayerMask Function(LayerMask m, double v) apply,
    ) => LabeledSlider(
      label: label,
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: (max - min).round(),
      valueText: '${value.round()}$unit',
      onChanged: (v) => onChanged(apply(current!, v)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<_MaskChoice>(
          segments: [
            ButtonSegment(
              value: _MaskChoice.none,
              icon: const Icon(Icons.block, size: 16),
              label: Text(l10n.timelineMaskNone),
            ),
            ButtonSegment(
              value: _MaskChoice.rectangle,
              icon: const Icon(Icons.crop_square, size: 16),
              label: Text(l10n.timelineMaskRectangle),
            ),
            ButtonSegment(
              value: _MaskChoice.ellipse,
              icon: const Icon(Icons.circle_outlined, size: 16),
              label: Text(l10n.timelineMaskEllipse),
            ),
          ],
          selected: {choice},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            switch (s.first) {
              case _MaskChoice.none:
                onChanged(null);
              case _MaskChoice.rectangle:
                onChanged(
                  (current ?? const LayerMask()).copyWith(
                    shape: LayerMaskShape.rectangle,
                  ),
                );
              case _MaskChoice.ellipse:
                onChanged(
                  (current ?? const LayerMask()).copyWith(
                    shape: LayerMaskShape.ellipse,
                  ),
                );
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            hint ?? l10n.timelineMaskHint,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (current != null) ...[
          slider(
            l10n.timelineMaskCenterX,
            current.centerX,
            -50,
            150,
            '%',
            (m, v) => m.copyWith(centerX: v),
          ),
          slider(
            l10n.timelineMaskCenterY,
            current.centerY,
            -50,
            150,
            '%',
            (m, v) => m.copyWith(centerY: v),
          ),
          slider(
            l10n.timelineMaskWidth,
            current.width,
            1,
            200,
            '%',
            (m, v) => m.copyWith(width: v),
          ),
          slider(
            l10n.timelineMaskHeight,
            current.height,
            1,
            200,
            '%',
            (m, v) => m.copyWith(height: v),
          ),
          slider(
            l10n.layerKeyframeRotationLabel,
            current.rotation,
            -180,
            180,
            '°',
            (m, v) => m.copyWith(rotation: v),
          ),
          slider(
            l10n.timelineMaskFeather,
            current.feather,
            0,
            50,
            '%',
            (m, v) => m.copyWith(feather: v),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              l10n.timelineMaskInvert,
              style: const TextStyle(fontSize: 13),
            ),
            value: current.invert,
            onChanged: (v) => onChanged(current.copyWith(invert: v)),
          ),
        ],
      ],
    );
  }
}
