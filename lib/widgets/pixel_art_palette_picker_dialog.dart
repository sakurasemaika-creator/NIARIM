import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/color_palette.dart';
import '../services/pixel_art_palette_service.dart';
import '../widgets/confirm_delete.dart';
import 'pixel_art_palette_edit_dialog.dart';
import 'qr_import_dialog.dart';
import 'qr_share_dialog.dart';

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

  void _showShareSheet(ColorPalette palette) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<PixelArtPaletteService>();
    final payload = jsonEncode(palette.toJson());
    final qrAvailable = payload.length <= kQrShareSafeCharLimit;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.colorPickerShareViaFile),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final file = await service.exportPalette(palette.id);
                  if (!mounted) return;
                  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.colorPickerShareFailedSnackbar(e.toString()))));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n.colorPickerShareViaQr),
              subtitle: qrAvailable ? null : Text(l10n.qrShareTooLargeHint),
              onTap: qrAvailable
                  ? () {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        builder: (_) => QrShareDialog(title: palette.name, payload: payload),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showImportSheet() {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<PixelArtPaletteService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.colorPickerImportViaFile),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['niapixelpalette'],
                );
                final path = result?.files.firstOrNull?.path;
                if (path == null) return;
                try {
                  await service.importPaletteFile(path);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.colorPickerImportFailedSnackbar(e.toString()))));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n.colorPickerImportViaQr),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => QrImportDialog(
                    title: l10n.colorPickerImportViaQr,
                    onImport: (text) async {
                      await service.importPaletteJson(text);
                      return true;
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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
                            icon: const Icon(Icons.share_outlined, size: 20),
                            tooltip: l10n.colorPickerSharePaletteTooltip,
                            onPressed: () => _showShareSheet(p),
                          ),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text(l10n.commonAdd),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: l10n.colorPickerImportPaletteTooltip,
              onPressed: _showImportSheet,
            ),
          ],
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
