import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/onion_skin_settings.dart';
import '../../../services/performance_service.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/docked_panel_scope.dart';
import '../../../widgets/list_ink_clip.dart';
import '../../../widgets/typing_dialog_inset.dart';
import 'color_picker_panel.dart';
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

    return PanelSurface(
      width: 280,
      // 背の低い画面では、画面の下へはみ出さず設定部分がスクロールする。
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      // 見出しの行（題・入切・×）は×の押せる所がパネルの右端まで届くよう
      // 右の余白を取らず、その下の中身は右にも12pxの余白を取る。
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー：オニオンスキン全体ON/OFFと閉じる×を同じ行に置く
            // （以前は×だけの行が題の上にあり、44pxの空いた帯ができた）。
            // 題は入切の名前を兼ねるので、ドックでも出す。
            PanelHeaderRow(
              onClose: widget.onClose,
              showTitleWhenDocked: true,
              padding: EdgeInsets.zero,
              title: Text(
                l10n.onionSkinTitle,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              actions: [
                Switch(
                  value: _settings.enabled,
                  onChanged: (v) => _update(_settings.copyWith(enabled: v)),
                ),
              ],
            ),
            if (_settings.enabled) ...[
              const Divider(endIndent: 12),
              // 行に重ねたときの色を一覧の外（下の余白）へはみ出させない
              // （末尾のclipListInk）。
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      // 枚数が品質の設定で決まっているときは、変える場所を
                      // 案内する（所有者の判断、2026-11-27）。
                      if (!isCustom) ...[
                        Text(
                          l10n.onionSkinFrameCountHint,
                          key: const ValueKey('onionSkinFrameCountHint'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            key: const ValueKey('onionSkinOpenPerformance'),
                            onPressed: () =>
                                context.push('/settings/performance'),
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: Text(l10n.perfSettingsScreenTitle),
                          ),
                        ),
                        const Divider(),
                      ],
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
                                      _settings.copyWith(
                                        frameInterval: interval,
                                      ),
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
                  ),
                ).clipListInk(),
              ),
            ],
          ],
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
          // Any colour, in the app's colour picker (the owner's choice,
          // 2026-11-27; before, only the eight above).
          TextButton.icon(
            key: const ValueKey('onionSkinMoreColors'),
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: Text(l10n.onionSkinMoreColors),
            onPressed: () {
              Navigator.pop(ctx);
              _showFreeColorPicker(current, onChanged);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  void _showFreeColorPicker(Color current, ValueChanged<Color> onChanged) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: typingDialogInsetPadding(ctx),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: ColorPickerPanel(
            currentColor: current,
            onColorChanged: onChanged,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
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
        // 名前は残りの幅で折り返す（以前は名前を縮められない行に並べていて、
        // 文字2倍の英語で「Previous Frame」と「ON (Fixed)」が行から
        // はみ出した）。
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
          if (isCustom)
            LabeledSlider(
              label: l10n.onionSkinFrameCount,
              labelStyle: const TextStyle(fontSize: 11),
              value: frames.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              valueText: '$frames',
              valueStyle: const TextStyle(fontSize: 11),
              onChanged: (v) => onFramesChanged?.call(v.round()),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    l10n.onionSkinFrameCount,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.onionSkinFrameCountFixed(frames),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          // 色：行のどこを押しても色を選べる（以前は28×20の見本だけが押せた）。
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onShowColorPicker(color, onColorChanged),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      l10n.onionSkinColorLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 透明度（0〜1で持つが、直接入力と同じく百分率で動かす）
          LabeledSlider(
            label: l10n.onionSkinOpacityLabel,
            labelStyle: const TextStyle(fontSize: 11),
            value: opacity * 100,
            min: 0,
            max: 100,
            valueText: '${(opacity * 100).round()}%',
            valueStyle: const TextStyle(fontSize: 11),
            onChanged: (v) => onOpacityChanged(v / 100.0),
          ),
        ],
      ],
    );
  }
}
