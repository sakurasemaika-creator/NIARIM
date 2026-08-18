import 'package:flutter/material.dart';
import '../../../widgets/editable_slider_value.dart';

class BrushSizeSlider extends StatelessWidget {
  final double brushSize;
  final int opacity;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<int> onOpacityChanged;

  const BrushSizeSlider({
    super.key,
    required this.brushSize,
    required this.opacity,
    required this.onSizeChanged,
    required this.onOpacityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8),
              const SizedBox(width: 8),
              Expanded(child: Slider(min: 1, max: 500, value: brushSize, onChanged: onSizeChanged)),
              // 数値部分をタップすると直接入力できる（ユーザー指示）。
              SizedBox(
                width: 40,
                child: EditableSliderValue(
                  text: '${brushSize.round()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  value: brushSize, min: 1, max: 500,
                  onChanged: (v) => onSizeChanged(v.toDouble()),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.opacity, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Slider(min: 1, max: 100, value: opacity.toDouble(), onChanged: (v) => onOpacityChanged(v.round()))),
              SizedBox(
                width: 40,
                child: EditableSliderValue(
                  text: '$opacity%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  value: opacity, min: 1, max: 100,
                  onChanged: (v) => onOpacityChanged(v.round()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
