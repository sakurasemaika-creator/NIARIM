import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/color_palette.dart';
import '../services/pixel_art_palette_service.dart';
import '../widgets/confirm_delete.dart';
import 'pixel_art_palette_edit_dialog.dart';

/// 「パレットから選ぶ」のポップアップ。保存済みのドット絵専用パレット一覧
/// （[PixelArtPaletteService]）から1つタップして選択し、「適用」を押すと
/// そのパレットの色リストを[Navigator.pop]の戻り値として返す
/// （呼び出し側はこれを[PixelColorMode.explicit]の色として複製する
/// スナップショット方式。以後パレットを編集してもこの適用結果には
/// 影響しない）。各行には編集・削除ボタンがあり、新規パレットは
/// 「追加」ボタンから[PixelArtPaletteEditDialog]で作成する。
class PixelArtPalettePickerDialog extends StatefulWidget {
  const PixelArtPalettePickerDialog({super.key});

  @override
  State<PixelArtPalettePickerDialog> createState() => _PixelArtPalettePickerDialogState();
}

class _PixelArtPalettePickerDialogState extends State<PixelArtPalettePickerDialog> {
  String? _selectedId;

  void _openEditor({ColorPalette? existing}) {
    showDialog(
      context: context,
      builder: (_) => PixelArtPaletteEditDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(ColorPalette palette) async {
    final ok = await confirmDelete(context, itemName: palette.name);
    if (!ok || !mounted) return;
    await context.read<PixelArtPaletteService>().deletePalette(palette.id);
    if (_selectedId == palette.id) setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palettes = context.watch<PixelArtPaletteService>().palettes;
    final selected = palettes.where((p) => p.id == _selectedId).firstOrNull;

    return AlertDialog(
      title: Text(l10n.pixelArtPalettePickerTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: palettes.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.pixelArtPalettePickerEmpty),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: palettes.length,
                  itemBuilder: (context, index) {
                    final p = palettes[index];
                    final isSelected = p.id == _selectedId;
                    return ListTile(
                      selected: isSelected,
                      onTap: () => setState(() => _selectedId = p.id),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(p.name),
                      subtitle: _ColorSwatchRow(colors: p.colors),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: l10n.commonEdit,
                            onPressed: () => _openEditor(existing: p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: l10n.commonDelete,
                            onPressed: () => _confirmDelete(p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: Text(l10n.commonAdd),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.of(context).pop(selected.colors),
              child: Text(l10n.pixelArtPalettePickerApplyButton),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final List<int> colors;

  const _ColorSwatchRow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      children: [
        for (final c in colors.take(12))
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(c),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
      ],
    );
  }
}
