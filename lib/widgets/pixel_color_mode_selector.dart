import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/pixel_color_mode.dart';
import 'editable_slider_value.dart';
import 'pixel_art_palette_picker_dialog.dart';
import 'pixel_color_chip_list.dart';
import 'stepped_slider.dart';

/// ブラシのピクセルモード・ドット絵フィルター（描画・演出）共通の配色方式
/// セレクター。プルダウンで「色を指定しない／パレットから選ぶ／色を
/// 指定する／色数を指定する」の4択を提供する。
///
/// 「パレットから選ぶ」は永続化される[PixelColorMode]の値ではなく
/// （[PixelColorMode.palette]自体は保存されない。models/pixel_color_mode.dart
/// 参照）、選んだ瞬間に[PixelArtPalettePickerDialog]でパレットの色を
/// 複製してexplicitモードへ切り替えるスナップショット方式のアクション
/// 項目として扱う。そのため[mode]（現在保存されている値）にはnone・
/// count・explicitのいずれかだけが渡ってくる想定。
class PixelColorModeSelector extends StatelessWidget {
  final PixelColorMode mode;
  final int colorLevels;
  final List<int> explicitColors;
  final ValueChanged<PixelColorMode> onModeChanged;
  final ValueChanged<int> onColorLevelsChanged;
  final ValueChanged<List<int>> onExplicitColorsChanged;
  final int maxColorLevels;

  const PixelColorModeSelector({
    super.key,
    required this.mode,
    required this.colorLevels,
    required this.explicitColors,
    required this.onModeChanged,
    required this.onColorLevelsChanged,
    required this.onExplicitColorsChanged,
    this.maxColorLevels = 256,
  });

  Future<void> _openPalettePicker(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => const PixelArtPalettePickerDialog(),
    );
    if (result != null && result.isNotEmpty) {
      onModeChanged(PixelColorMode.explicit);
      onExplicitColorsChanged(result);
    }
  }

  String _label(AppLocalizations l10n, PixelColorMode m) => switch (m) {
    PixelColorMode.none => l10n.pixelColorModeNone,
    PixelColorMode.palette => l10n.pixelColorModePalette,
    PixelColorMode.explicit => l10n.pixelColorModeExplicit,
    PixelColorMode.count => l10n.pixelColorModeCount,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pixelColorModeLabel, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        DropdownButtonFormField<PixelColorMode>(
          initialValue: mode,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          items: [
            for (final m in PixelColorMode.values)
              DropdownMenuItem(value: m, child: Text(_label(l10n, m))),
          ],
          onChanged: (v) {
            if (v == null) return;
            if (v == PixelColorMode.palette) {
              _openPalettePicker(context);
              return;
            }
            onModeChanged(v);
          },
        ),
        if (mode == PixelColorMode.count) ...[
          const SizedBox(height: 8),
          EditableSliderValue(
            text: l10n.pixelColorLevelsLabel(colorLevels),
            style: const TextStyle(fontSize: 11),
            value: colorLevels,
            min: 1,
            max: maxColorLevels,
            onChanged: (v) => onColorLevelsChanged(v.round()),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: SteppedSlider(
              value: colorLevels.toDouble().clamp(1, maxColorLevels.toDouble()),
              min: 1,
              max: maxColorLevels.toDouble(),
              step: 1,
              onChanged: (v) => onColorLevelsChanged(v.round()),
            ),
          ),
        ] else if (mode == PixelColorMode.explicit) ...[
          const SizedBox(height: 8),
          PixelColorChipList(
            colors: explicitColors,
            onChanged: onExplicitColorsChanged,
          ),
        ],
      ],
    );
  }
}
