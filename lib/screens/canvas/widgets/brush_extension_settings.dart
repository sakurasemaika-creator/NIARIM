import 'package:flutter/material.dart';

import '../../../models/brush.dart';

class BrushExtensionLabels {
  final String lateralRepeat;
  final String lateralRepeatCount;
  final String lateralRepeatSpacing;
  final String outline;
  final String outlineWidth;
  final String outlineColor;
  final String colorPicker;
  final String eyedropper;
  final String fold;
  final String foldTriggerAngle;
  final String yBranchAngle;
  final String yBranchLength;
  final String yBranchWidth;
  final String yBranchEndTaper;

  const BrushExtensionLabels({
    required this.lateralRepeat,
    required this.lateralRepeatCount,
    required this.lateralRepeatSpacing,
    required this.outline,
    required this.outlineWidth,
    required this.outlineColor,
    required this.colorPicker,
    required this.eyedropper,
    required this.fold,
    required this.foldTriggerAngle,
    required this.yBranchAngle,
    required this.yBranchLength,
    required this.yBranchWidth,
    required this.yBranchEndTaper,
  });

  const BrushExtensionLabels.japanese()
      : lateralRepeat = '横方向反復',
        lateralRepeatCount = '横方向反復個数',
        lateralRepeatSpacing = '横方向間隔',
        outline = '縁取り',
        outlineWidth = '縁取り幅',
        outlineColor = '縁取り色',
        colorPicker = 'カラーピッカー',
        eyedropper = 'スポイト',
        fold = '折り返し',
        foldTriggerAngle = '発生角度',
        yBranchAngle = 'Y字枝分かれ角度',
        yBranchLength = 'Y字長さ',
        yBranchWidth = 'Y字太さ',
        yBranchEndTaper = 'Y字終点入り抜き';
}

class BrushExtensionSettings extends StatefulWidget {
  final Brush brush;
  final ValueChanged<Brush> onChanged;
  final BrushExtensionLabels labels;
  final VoidCallback? onPickOutlineColor;
  final VoidCallback? onEyedropOutlineColor;

  const BrushExtensionSettings({
    super.key,
    required this.brush,
    required this.onChanged,
    required this.labels,
    required this.onPickOutlineColor,
    required this.onEyedropOutlineColor,
  });

  @override
  State<BrushExtensionSettings> createState() => _BrushExtensionSettingsState();
}

class _BrushExtensionSettingsState extends State<BrushExtensionSettings> {
  late Brush _brush;

  @override
  void initState() {
    super.initState();
    _brush = widget.brush;
  }

  @override
  void didUpdateWidget(covariant BrushExtensionSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brush != widget.brush) _brush = widget.brush;
  }

  void _set(Brush value) {
    setState(() => _brush = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          dense: true,
          title: Text(l.lateralRepeat),
          value: _brush.lateralRepeatEnabled,
          onChanged: (v) => _set(_brush.copyWith(lateralRepeatEnabled: v)),
        ),
        if (_brush.lateralRepeatEnabled) ...[
          _integerSlider(l.lateralRepeatCount, _brush.lateralRepeatCount, 1, 10,
              (v) => _set(_brush.copyWith(lateralRepeatCount: v))),
          _slider(l.lateralRepeatSpacing, _brush.lateralRepeatSpacing, 0, 4,
              (v) => _set(_brush.copyWith(lateralRepeatSpacing: v)),
              suffix: '×'),
        ],
        const Divider(),
        SwitchListTile(
          dense: true,
          title: Text(l.outline),
          value: _brush.outlineEnabled,
          onChanged: (v) => _set(_brush.copyWith(outlineEnabled: v)),
        ),
        if (_brush.outlineEnabled) ...[
          _slider(l.outlineWidth, _brush.outlineWidth, 0.25, 8,
              (v) => _set(_brush.copyWith(outlineWidth: v))),
          ListTile(
            dense: true,
            title: Text(l.outlineColor),
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(_brush.outlineColor),
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  key: const Key('brush-outline-color-picker'),
                  tooltip: l.colorPicker,
                  onPressed: widget.onPickOutlineColor,
                  icon: const Icon(Icons.palette_outlined),
                ),
                IconButton(
                  key: const Key('brush-outline-eyedropper'),
                  tooltip: l.eyedropper,
                  onPressed: widget.onEyedropOutlineColor,
                  icon: const Icon(Icons.colorize),
                ),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            title: Text(l.fold),
            value: _brush.foldEnabled,
            onChanged: (v) => _set(_brush.copyWith(foldEnabled: v)),
          ),
          if (_brush.foldEnabled) ...[
            _slider(l.foldTriggerAngle, _brush.foldTriggerAngle, 30, 170,
                (v) => _set(_brush.copyWith(foldTriggerAngle: v)), suffix: '°'),
            _slider(l.yBranchAngle, _brush.yBranchAngle, 10, 120,
                (v) => _set(_brush.copyWith(yBranchAngle: v)), suffix: '°'),
            _ratioSlider(l.yBranchLength, _brush.yBranchLengthRatio,
                (v) => _set(_brush.copyWith(yBranchLengthRatio: v))),
            _ratioSlider(l.yBranchWidth, _brush.yBranchWidthRatio,
                (v) => _set(_brush.copyWith(yBranchWidthRatio: v)), max: 0.5),
            _ratioSlider(l.yBranchEndTaper, _brush.yBranchEndTaperRatio,
                (v) => _set(_brush.copyWith(yBranchEndTaperRatio: v))),
          ],
        ],
      ],
    );
  }

  Widget _integerSlider(String label, int value, int min, int max, ValueChanged<int> changed) =>
      _slider(label, value.toDouble(), min.toDouble(), max.toDouble(),
          (v) => changed(v.round()), divisions: max - min, suffix: '');

  Widget _ratioSlider(String label, double value, ValueChanged<double> changed,
          {double max = 1}) =>
      _slider(label, value, 0, max, changed, divisions: 100,
          displayValue: '${(value * 100).round()}%');

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> changed,
      {int? divisions, String? suffix, String? displayValue}) {
    final safe = value.clamp(min, max).toDouble();
    final shown = displayValue ?? '${safe.toStringAsFixed(safe == safe.roundToDouble() ? 0 : 2)}${suffix ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label)), Text(shown)]),
          Slider(
            value: safe,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: changed,
          ),
        ],
      ),
    );
  }
}
