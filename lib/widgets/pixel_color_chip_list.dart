import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/canvas/widgets/color_picker_panel.dart';

/// 「色を指定する」モード共通の色チップ編集UI。
/// 各色はチップ（タップでカラーピッカーを開いて変更）＋隣接するゴミ箱
/// ボタン（削除。最低1色は残すため色が1つの時は無効化）の行として並び、
/// 末尾に色を追加する＋ボタンを表示する。ブラシのピクセルモード・
/// ドット絵フィルター（描画・演出）・ドット絵専用パレット編集の
/// いずれからも共用する。
class PixelColorChipList extends StatelessWidget {
  final List<int> colors;
  final ValueChanged<List<int>> onChanged;

  const PixelColorChipList({
    super.key,
    required this.colors,
    required this.onChanged,
  });

  void _editColor(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(colors[index]),
          onColorChanged: (c) {
            final updated = List<int>.from(colors);
            updated[index] = c.toARGB32();
            onChanged(updated);
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _addColor() => onChanged([...colors, 0xFF000000]);

  void _removeColor(int index) {
    if (colors.length <= 1) return;
    final updated = List<int>.from(colors)..removeAt(index);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < colors.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _editColor(context, i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(colors[i]),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: l10n.pixelColorChipDeleteTooltip,
                  onPressed: colors.length > 1 ? () => _removeColor(i) : null,
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: _addColor,
          icon: const Icon(Icons.add),
          label: Text(l10n.pixelColorChipAddButton),
        ),
      ],
    );
  }
}
