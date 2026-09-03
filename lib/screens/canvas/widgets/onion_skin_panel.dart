import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/onion_skin_settings.dart';
import '../../../services/performance_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';

class OnionSkinPanel extends StatefulWidget {
  final OnionSkinSettings settings;
  final ValueChanged<OnionSkinSettings> onChanged;
  final VoidCallback onClose;

  const OnionSkinPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<OnionSkinPanel> createState() => _OnionSkinPanelState();
}

class _OnionSkinPanelState extends State<OnionSkinPanel> {
  late OnionSkinSettings _settings;
  bool _pendingSync = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(OnionSkinSettings s) {
    setState(() => _settings = s);
    widget.onChanged(s);
  }

  @override
  void didUpdateWidget(OnionSkinPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // widget.settingsが外部から更新された場合のみローカル状態を同期
    if (widget.settings != oldWidget.settings) {
      setState(() => _settings = widget.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final perf = context.watch<PerformanceService>();
    final isCustom = perf.qualityLevel == QualityLevel.custom;

    // プリセット時：PerformanceServiceの値に同期（枚数・ON/OFF固定）
    if (!isCustom) {
      final expectedPrev = perf.prevOnionSkinFrames;
      final expectedNext = perf.nextOnionSkinFrames;
      if (!_pendingSync &&
          (_settings.prevFrames != expectedPrev ||
              _settings.nextFrames != expectedNext ||
              !_settings.showPrev ||
              !_settings.showNext)) {
        _pendingSync = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pendingSync = false;
          if (!mounted) return;
          _update(
            _settings.copyWith(
              showPrev: true,
              showNext: true,
              prevFrames: expectedPrev,
              nextFrames: expectedNext,
            ),
          );
        });
      }
    }

    return Card(
      elevation: 8,
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelCenterCloseBar(onClose: widget.onClose),
              // ヘッダー：オニオンスキン全体ON/OFF
              Row(
                children: [
                  Text(
                    l10n.onionSkinTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _settings.enabled,
                    onChanged: (v) => _update(_settings.copyWith(enabled: v)),
                  ),
                ],
              ),
              if (_settings.enabled) ...[
                const Divider(),
                // ── 前フレーム ──
                _OnionSideSection(
                  label: l10n.onionSkinPrevFrame,
                  showToggle: _settings.showPrev,
                  frames: _settings.prevFrames,
                  color: _settings.prevColor,
                  opacity: _settings.prevOpacity,
                  isCustom: isCustom,
                  onShowChanged: isCustom
                      ? (v) => _update(_settings.copyWith(showPrev: v))
                      : null,
                  onFramesChanged: isCustom
                      ? (v) => _update(_settings.copyWith(prevFrames: v))
                      : null,
                  onColorChanged: (c) =>
                      _update(_settings.copyWith(prevColor: c)),
                  onOpacityChanged: (v) =>
                      _update(_settings.copyWith(prevOpacity: v)),
                  onShowColorPicker: _showColorPicker,
                ),
                const Divider(),
                // ── 後フレーム ──
                _OnionSideSection(
                  label: l10n.onionSkinNextFrame,
                  showToggle: _settings.showNext,
                  frames: _settings.nextFrames,
                  color: _settings.nextColor,
                  opacity: _settings.nextOpacity,
                  isCustom: isCustom,
                  onShowChanged: isCustom
                      ? (v) => _update(_settings.copyWith(showNext: v))
                      : null,
                  onFramesChanged: isCustom
                      ? (v) => _update(_settings.copyWith(nextFrames: v))
                      : null,
                  onColorChanged: (c) =>
                      _update(_settings.copyWith(nextColor: c)),
                  onOpacityChanged: (v) =>
                      _update(_settings.copyWith(nextOpacity: v)),
                  onShowColorPicker: _showColorPicker,
                ),
                const Divider(),
                // ── 共通設定 ──
                Text(
                  l10n.onionSkinFrameInterval,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: OnionSkinSettings.frameIntervalOptions
                      .map(
                        (interval) => ChoiceChip(
                          label: Text('$interval'),
                          selected: _settings.frameInterval == interval,
                          onSelected: (selected) {
                            if (selected) {
                              _update(
                                _settings.copyWith(frameInterval: interval),
                              );
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.onionSkinFadeByDistance,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _settings.fadeByDistance,
                  onChanged: (v) =>
                      _update(_settings.copyWith(fadeByDistance: v)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(Color current, ValueChanged<Color> onChanged) {
    final l10n = AppLocalizations.of(context)!;
    const presets = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.yellow,
      Colors.white,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.onionSkinColorPickerTitle),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    onChanged(c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == current
                            ? Theme.of(ctx).colorScheme.primary
                            : Theme.of(ctx).colorScheme.outlineVariant,
                        width: c == current ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}

// ── 前/後フレームの設定セクション ──
class _OnionSideSection extends StatelessWidget {
  final String label;
  final bool showToggle;
  final int frames;
  final Color color;
  final double opacity;
  final bool isCustom;
  final ValueChanged<bool>? onShowChanged; // null=プリセット固定
  final ValueChanged<int>? onFramesChanged; // null=プリセット固定
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onOpacityChanged;
  final void Function(Color, ValueChanged<Color>) onShowColorPicker;

  const _OnionSideSection({
    required this.label,
    required this.showToggle,
    required this.frames,
    required this.color,
    required this.opacity,
    required this.isCustom,
    required this.onShowChanged,
    required this.onFramesChanged,
    required this.onColorChanged,
    required this.onOpacityChanged,
    required this.onShowColorPicker,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 表示トグル（カスタム時は操作可、プリセット時は固定ON）
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const Spacer(),
            if (isCustom)
              Switch(value: showToggle, onChanged: onShowChanged)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.onionSkinOnFixed,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        // ON時のみ詳細設定を表示
        if (showToggle) ...[
          // 表示枚数
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  l10n.onionSkinFrameCount,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              if (isCustom) ...[
                Expanded(
                  child: SteppedSlider(
                    min: 1,
                    max: 10,
                    divisions: 9,
                    value: frames.toDouble(),
                    onChanged: (v) => onFramesChanged?.call(v.round()),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: EditableSliderValue(
                    text: '$frames',
                    style: const TextStyle(fontSize: 11),
                    value: frames,
                    min: 1,
                    max: 10,
                    onChanged: (v) => onFramesChanged?.call(v.round()),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Text(
                  l10n.onionSkinFrameCountFixed(frames),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          // 色
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  l10n.onionSkinColorLabel,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onShowColorPicker(color, onColorChanged),
                child: Container(
                  width: 28,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 透明度
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  l10n.onionSkinOpacityLabel,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Expanded(
                child: SteppedSlider(
                  min: 0,
                  max: 1,
                  step: 0.01,
                  value: opacity,
                  onChanged: onOpacityChanged,
                ),
              ),
              SizedBox(
                width: 32,
                child: EditableSliderValue(
                  text: '${(opacity * 100).round()}%',
                  style: const TextStyle(fontSize: 11),
                  value: (opacity * 100).round(),
                  min: 0,
                  max: 100,
                  onChanged: (v) => onOpacityChanged(v / 100.0),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
