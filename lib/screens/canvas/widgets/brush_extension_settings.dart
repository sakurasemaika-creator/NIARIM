import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

import '../../../models/brush.dart';
import '../../../models/brush_extension_defaults.dart';
import '../../../widgets/help_button.dart';

class BrushExtensionLabels {
  final String lateralRepeat;
  final String lateralRepeatCount;
  final String lateralRepeatSpacing;
  final String outline;
  final String outlineWidth;
  final String outlineColor;
  final String outlineKeepOverlap;
  final String outlineKeepOverlapHelp;
  final String outlineAccent;
  final String outlineAccentWidth;
  final String outlineAccentHelp;
  final String colorPicker;
  final String eyedropper;
  final String fold;
  final String foldCurveStart;
  final String foldLength;
  final String foldAngle;
  final String foldModeHelp;
  final String foldLengthHelp;
  final String foldAngleHelp;
  final String foldCurveStartHelp;
  final String foldCrescentDepthThreshold;
  final String foldMode;
  final String foldModeWaveTopView;
  final String foldModeWaveLowAngle;
  final String foldModeCurlRight;
  final String foldModeCurlLeft;
  final String foldModeCrescent;

  const BrushExtensionLabels({
    required this.lateralRepeat,
    required this.lateralRepeatCount,
    required this.lateralRepeatSpacing,
    required this.outline,
    required this.outlineWidth,
    required this.outlineColor,
    this.outlineKeepOverlap = 'Keep overlaps',
    this.outlineKeepOverlapHelp = '',
    this.outlineAccent = 'Weight variation',
    this.outlineAccentWidth = 'Outline width at the apex',
    this.outlineAccentHelp = '',
    required this.colorPicker,
    required this.eyedropper,
    required this.fold,
    required this.foldCurveStart,
    required this.foldLength,
    required this.foldAngle,
    this.foldModeHelp = '',
    this.foldLengthHelp = '',
    this.foldAngleHelp = '',
    this.foldCurveStartHelp = '',
    this.foldCrescentDepthThreshold = 'Crescent minimum depth / pen width',
    required this.foldMode,
    required this.foldModeWaveTopView,
    required this.foldModeWaveLowAngle,
    required this.foldModeCurlRight,
    required this.foldModeCurlLeft,
    required this.foldModeCrescent,
  });

  factory BrushExtensionLabels.fromLocalizations(AppLocalizations l) =>
      BrushExtensionLabels(
        lateralRepeat: l.brushLateralRepeat,
        lateralRepeatCount: l.brushLateralRepeatCount,
        lateralRepeatSpacing: l.brushLateralRepeatSpacing,
        outline: l.brushOutline,
        outlineWidth: l.brushOutlineWidth,
        outlineColor: l.brushOutlineColor,
        outlineKeepOverlap: l.brushOutlineKeepOverlap,
        outlineKeepOverlapHelp: l.brushOutlineKeepOverlapHelp,
        outlineAccent: l.brushOutlineAccent,
        outlineAccentWidth: l.brushOutlineAccentWidth,
        outlineAccentHelp: l.brushOutlineAccentHelp,
        colorPicker: l.brushOutlineColorPicker,
        eyedropper: l.brushOutlineEyedropper,
        fold: l.brushFold,
        foldCurveStart: l.brushFoldCurveStart,
        foldLength: l.brushFoldLength,
        foldAngle: l.brushFoldAngle,
        foldModeHelp: l.brushFoldModeHelp,
        foldLengthHelp: l.brushFoldLengthHelp,
        foldAngleHelp: l.brushFoldAngleHelp,
        foldCurveStartHelp: l.brushFoldCurveStartHelp,
        foldCrescentDepthThreshold: l.brushFoldCrescentDepthThreshold,
        foldMode: l.brushFoldMode,
        foldModeWaveTopView: l.brushFoldModeWaveTopView,
        foldModeWaveLowAngle: l.brushFoldModeWaveLowAngle,
        foldModeCurlRight: l.brushFoldModeCurlRight,
        foldModeCurlLeft: l.brushFoldModeCurlLeft,
        foldModeCrescent: l.brushFoldModeCrescent,
      );

  const BrushExtensionLabels.japanese()
    : lateralRepeat = '横方向反復',
      lateralRepeatCount = '横方向反復個数',
      lateralRepeatSpacing = '横方向間隔',
      outline = '縁取り',
      outlineWidth = '縁取り幅',
      outlineColor = '縁取り色',
      outlineKeepOverlap = '重なりを維持する',
      outlineKeepOverlapHelp =
          'オンでは、ストローク同士が重なった所にも縁取りを描きます。'
          'オフでは、重なった所は縁取りも折り返し線も描かず、'
          '全体の周りだけを縁取ります。',
      outlineAccent = '強弱',
      outlineAccentWidth = '頂点の縁取り幅',
      outlineAccentHelp =
          'ストロークのカーブの頂点に向かって縁取り線を太くします。'
          'カーブの始まりと終わりは縁取り幅のまま、頂点でこの太さになるよう'
          '徐々に太くなります。',
      colorPicker = 'カラーピッカー',
      eyedropper = 'スポイト',
      fold = '折り畳みモード',
      foldCurveStart = '折り返し線のカーブ開始位置',
      foldLength = '折り返し長さ',
      foldAngle = '折り返し角度',
      foldModeHelp = 'ストロークに沿った折り畳み方を選択します。',
      foldLengthHelp = '折り畳みが伸びる長さを調整します。ブラシサイズに連動します。',
      foldAngleHelp =
          'ストロークのカーブに対する折り畳みの強さを調整します。'
          '50%でストロークのカーブに自然に連動します。',
      foldCurveStartHelp =
          '折り返し線が曲がり始める位置を調整し、髪やリボンの厚みを表現します。'
          '0%では分岐位置からすぐにカーブします。',
      foldCrescentDepthThreshold = '三日月にするカーブの深さ（ペン幅比）',
      foldMode = '折り畳みタイプ',
      foldModeWaveTopView = 'ウェーブ俯瞰',
      foldModeWaveLowAngle = 'ウェーブ煽り',
      foldModeCurlRight = '右巻き',
      foldModeCurlLeft = '左巻き',
      foldModeCrescent = '三日月カール';
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
          _integerSlider(
            l.lateralRepeatCount,
            _brush.lateralRepeatCount,
            1,
            10,
            (v) => _set(_brush.copyWith(lateralRepeatCount: v)),
          ),
          _slider(
            l.lateralRepeatSpacing,
            _brush.lateralRepeatSpacing,
            0,
            4,
            (v) => _set(_brush.copyWith(lateralRepeatSpacing: v)),
            suffix: '×',
          ),
        ],
        const Divider(),
        SwitchListTile(
          dense: true,
          title: Text(l.outline),
          value: _brush.outlineEnabled,
          onChanged: (v) => _set(_brush.copyWith(outlineEnabled: v)),
        ),
        if (_brush.outlineEnabled) ...[
          _slider(
            l.outlineWidth,
            _brush.outlineWidth,
            0.25,
            8,
            (v) => _set(_brush.copyWith(outlineWidth: v)),
          ),
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
          CheckboxListTile(
            key: const Key('brush-outline-keep-overlap'),
            dense: true,
            title: Text(l.outlineKeepOverlap),
            subtitle: l.outlineKeepOverlapHelp.isEmpty
                ? null
                : Text(l.outlineKeepOverlapHelp),
            value: _brush.outlineKeepOverlap,
            onChanged: (v) =>
                _set(_brush.copyWith(outlineKeepOverlap: v ?? true)),
          ),
          CheckboxListTile(
            key: const Key('brush-outline-accent'),
            dense: true,
            title: Text(l.outlineAccent),
            subtitle: l.outlineAccentHelp.isEmpty
                ? null
                : Text(l.outlineAccentHelp),
            value: _brush.outlineAccentEnabled,
            onChanged: (v) =>
                _set(_brush.copyWith(outlineAccentEnabled: v ?? false)),
          ),
          if (_brush.outlineAccentEnabled)
            KeyedSubtree(
              key: const Key('brush-outline-accent-width'),
              child: _slider(
                l.outlineAccentWidth,
                _brush.outlineAccentWidth,
                0.25,
                24,
                (v) => _set(_brush.copyWith(outlineAccentWidth: v)),
                divisions: 95,
                suffix: 'px',
              ),
            ),
          SwitchListTile(
            dense: true,
            title: Text(l.fold),
            secondary: const HelpButton(
              key: Key('brush-fold-help'),
              topic: '折り返し',
            ),
            value: _brush.foldEnabled,
            onChanged: (v) => _set(_brush.copyWith(foldEnabled: v)),
          ),
          if (_brush.foldEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: DropdownButtonFormField<HairFoldMode>(
                key: const Key('brush-fold-mode'),
                initialValue: _brush.foldMode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.foldMode,
                  helperText: l.foldModeHelp.isEmpty ? null : l.foldModeHelp,
                  helperMaxLines: 3,
                ),
                items: HairFoldMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(
                          _foldModeLabel(mode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) _set(_brush.copyWith(foldMode: mode));
                },
              ),
            ),
            KeyedSubtree(
              key: const Key('brush-fold-length'),
              child: _ratioSlider(
                l.foldLength,
                _brush.foldLengthRatio,
                (v) => _set(_brush.copyWith(foldLengthRatio: v)),
                help: l.foldLengthHelp,
              ),
            ),
            KeyedSubtree(
              key: const Key('brush-fold-angle'),
              child: _ratioSlider(
                l.foldAngle,
                _brush.foldAngleRatio,
                (v) => _set(_brush.copyWith(foldAngleRatio: v)),
                help: l.foldAngleHelp,
              ),
            ),
            KeyedSubtree(
              key: const Key('brush-fold-curve-start'),
              child: _ratioSlider(
                l.foldCurveStart,
                _brush.foldCurveStartRatio,
                (v) => _set(_brush.copyWith(foldCurveStartRatio: v)),
                help: l.foldCurveStartHelp,
              ),
            ),
            if (_brush.foldMode == HairFoldMode.crescent)
              KeyedSubtree(
                key: const Key('brush-crescent-depth-threshold'),
                child: _slider(
                  l.foldCrescentDepthThreshold,
                  _brush.foldCrescentDepthThreshold,
                  0,
                  BrushExtensionDefaults.maxFoldCrescentDepthThreshold,
                  (v) => _set(_brush.copyWith(foldCrescentDepthThreshold: v)),
                  divisions: 60,
                  displayValue:
                      '${(_brush.foldCrescentDepthThreshold * 100).round()}%',
                ),
              ),
          ],
        ],
      ],
    );
  }

  String _foldModeLabel(HairFoldMode mode) => switch (mode) {
    HairFoldMode.waveTopView => widget.labels.foldModeWaveTopView,
    HairFoldMode.waveLowAngle => widget.labels.foldModeWaveLowAngle,
    HairFoldMode.curlRight => widget.labels.foldModeCurlRight,
    HairFoldMode.curlLeft => widget.labels.foldModeCurlLeft,
    HairFoldMode.crescent => widget.labels.foldModeCrescent,
  };

  Widget _integerSlider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> changed,
  ) => _slider(
    label,
    value.toDouble(),
    min.toDouble(),
    max.toDouble(),
    (v) => changed(v.round()),
    divisions: max - min,
    suffix: '',
  );

  Widget _ratioSlider(
    String label,
    double value,
    ValueChanged<double> changed, {
    double max = 1,
    String help = '',
  }) => _slider(
    label,
    value,
    0,
    max,
    changed,
    divisions: 100,
    displayValue: '${(value * 100).round()}%',
    help: help,
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> changed, {
    int? divisions,
    String? suffix,
    String? displayValue,
    String help = '',
  }) {
    final safe = value.clamp(min, max).toDouble();
    final shown =
        displayValue ??
        '${safe.toStringAsFixed(safe == safe.roundToDouble() ? 0 : 2)}${suffix ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(shown),
            ],
          ),
          Slider(
            value: safe,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: changed,
          ),
          if (help.isNotEmpty)
            Text(help, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
