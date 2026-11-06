import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/color_palette.dart';
import '../services/pixel_art_palette_service.dart';
import 'pixel_color_chip_list.dart';

/// ドット絵専用パレットの新規作成・編集ダイアログ。
/// パレット名（未入力ならエラー表示して保存を拒否する）と、色チップの
/// 追加・編集・削除（[PixelColorChipList]を流用）を行う。
/// [existing]を渡すと編集モード（既存の色・名前で初期化し、保存時は
/// 上書き）、nullなら新規作成モード。
class PixelArtPaletteEditDialog extends StatefulWidget {
  final ColorPalette? existing;

  const PixelArtPaletteEditDialog({super.key, this.existing});

  @override
  State<PixelArtPaletteEditDialog> createState() =>
      _PixelArtPaletteEditDialogState();
}

class _PixelArtPaletteEditDialogState extends State<PixelArtPaletteEditDialog> {
  late final TextEditingController _nameController;
  late List<int> _colors;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _colors = List<int>.from(widget.existing?.colors ?? const [0xFF000000]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n.pixelArtPaletteNameRequiredError);
      return;
    }
    final service = context.read<PixelArtPaletteService>();
    if (widget.existing != null) {
      await service.updatePalette(
        widget.existing!.id,
        name: name,
        colors: _colors,
      );
    } else {
      await service.addPalette(name, _colors);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.existing != null
            ? l10n.pixelArtPaletteEditTitle
            : l10n.pixelArtPaletteAddTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.pixelArtPaletteNameLabel,
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 16),
            PixelColorChipList(
              colors: _colors,
              onChanged: (c) => setState(() => _colors = c),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
