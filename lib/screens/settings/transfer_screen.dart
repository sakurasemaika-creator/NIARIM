import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/niatra_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/brush_service.dart';
import '../../services/palette_service.dart';
import '../../services/pixel_art_palette_service.dart';
import '../../services/settings_service.dart';
import '../../services/stamp_service.dart';
import '../../services/theme_service.dart';
import '../../services/tone_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  // キー自体はNiatraSerializer.export()/applyTo()が内部で
  // selectedItems['設定']等と直接照合するための固定識別子であり、
  // UI表示用の文字列ではないため翻訳しない（表示ラベルは_itemLabel()で
  // 別途ローカライズする）。
  final Map<String, bool> _items = {
    '設定': true,
    '素材': true,
    'ブラシ': true,
    'プリセット': true,
    'UIテーマ': true,
    'パレット': true,
  };
  bool _isBusy = false;

  String _itemLabel(AppLocalizations l10n, String key) => switch (key) {
        '設定' => l10n.transferItemSettings,
        '素材' => l10n.transferItemMaterials,
        'ブラシ' => l10n.transferItemBrush,
        'プリセット' => l10n.transferItemPresets,
        'UIテーマ' => l10n.transferItemTheme,
        'パレット' => l10n.transferItemPalette,
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // topicはヘルプ画面側の項目タイトル（日本語固定の内部検索キー）と
      // 一致させる必要があるため翻訳しない。
      appBar: AppBar(title: Text(l10n.transferScreenTitle), actions: const [HelpButton(topic: '引き継ぎ（.niatra）')]),
      body: desktopCentered(context, Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.transferInstructionHint,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Card(
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    children: [
                      for (final key in _items.keys) ...[
                        if (key != _items.keys.first) const Divider(height: 1),
                        CheckboxListTile(
                          title: Text(_itemLabel(l10n, key)),
                          value: _items[key],
                          onChanged: (v) => setState(() => _items[key] = v!),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: _isBusy ? null : _import,
                  child: Text(l10n.transferImport),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isBusy ? null : () => setState(() => _items.updateAll((_, _) => true)),
                  child: Text(l10n.homeSelectionAllSelect),
                ),
                TextButton(
                  onPressed: _isBusy ? null : () => setState(() => _items.updateAll((_, _) => false)),
                  child: Text(l10n.homeSelectionAllDeselect),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (!_isBusy && _items.values.any((v) => v)) ? _export : null,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                  label: Text(l10n.transferExport),
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }

  Future<void> _export() async {
    setState(() => _isBusy = true);
    try {
      // メモリ上でZIPバイト列を生成してから共有する（Web版ではpath_provider
      // が使えずローカルファイルを作れないため、ファイルI/Oを介さない方式に
      // 統一している）。
      final bytes = await NiatraSerializer.export(
        selectedItems: _items,
        settings: context.read<SettingsService>(),
        brush: context.read<BrushService>(),
        tone: context.read<ToneService>(),
        stamp: context.read<StampService>(),
        autofillPresets: context.read<AutofillPresetService>(),
        theme: context.read<ThemeService>(),
        palette: context.read<PaletteService>(),
        pixelArtPalette: context.read<PixelArtPaletteService>(),
      );
      if (!mounted) return;
      final fileName = 'niarim_${DateTime.now().millisecondsSinceEpoch}.niatra';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: 'application/octet-stream')],
      ));
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transferExportSuccessSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transferExportFailedSnackbar(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _import() async {
    // withData: trueでバイト列も取得しておく（Web版はpathがnullになり
    // ファイルパスから読み込めないため、その場合はバイト列側を使う）。
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['niatra'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null && picked.bytes == null) return;
    if (!mounted) return;
    setState(() => _isBusy = true);
    try {
      final data = picked.bytes != null
          ? NiatraSerializer.loadFromBytes(picked.bytes!)
          : await NiatraSerializer.load(picked.path!);
      if (!mounted) return;
      NiatraSerializer.applyTo(
        data,
        settings: context.read<SettingsService>(),
        brush: context.read<BrushService>(),
        tone: context.read<ToneService>(),
        stamp: context.read<StampService>(),
        autofillPresets: context.read<AutofillPresetService>(),
        theme: context.read<ThemeService>(),
        palette: context.read<PaletteService>(),
        pixelArtPalette: context.read<PixelArtPaletteService>(),
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transferImportSuccessSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transferImportFailedSnackbar(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
