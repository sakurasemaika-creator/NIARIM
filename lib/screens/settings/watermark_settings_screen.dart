import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bundled_fonts.dart';
import '../../models/watermark_asset.dart';
import '../../services/font_service.dart';
import '../../services/watermark_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/confirm_delete.dart';
import '../canvas/widgets/color_picker_panel.dart';

/// ウォーターマーク登録・管理画面（プレミアム限定、仕様書01・08・13）。
/// 「設定項目：画像選択 / 文字入力 / …」のうち、画像・文字それぞれの
/// ウォーターマークを複数登録できる。位置・サイズ・透明度・表示範囲は
/// タイムラインへ追加後にレイヤーパネル・変形ツールから調整する。
/// 登録した項目はタイムラインの「＋ウォーターマーク」から選択して追加できる。
class WatermarkSettingsScreen extends StatelessWidget {
  const WatermarkSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<WatermarkService>();
    final assets = service.assets;

    return Scaffold(
      // topic: 'ウォーターマーク' はhelp_screen.dart側の項目タイトル（日本語固定の
      // 内部検索キー）と一致させる必要があるため、翻訳対象から除外している。
      appBar: AppBar(title: Text(l10n.settingsWatermarkTitle), actions: const [HelpButton(topic: 'ウォーターマーク')]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, service),
        child: const Icon(Icons.add),
      ),
      body: desktopCentered(
        context,
        assets.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.branding_watermark, size: 44, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.watermarkEmptyTitle,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(l10n.watermarkEmptyHint,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: assets.length,
                itemBuilder: (context, index) => _WatermarkTile(
                  asset: assets[index],
                  onDelete: () async {
                    if (!await confirmDelete(context, itemName: assets[index].name)) return;
                    service.removeWatermark(assets[index].id);
                  },
                ),
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WatermarkService service) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.watermarkAddFromImage),
              onTap: () {
                Navigator.pop(ctx);
                _addImageWatermark(context, service);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(l10n.watermarkAddText),
              onTap: () {
                Navigator.pop(ctx);
                _showTextWatermarkDialog(context, service);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImageWatermark(BuildContext context, WatermarkService service) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    await service.addWatermark(result.files.first.path!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.watermarkAddedSnackbar)),
    );
  }

  void _showTextWatermarkDialog(BuildContext context, WatermarkService service) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final fontService = context.read<FontService>();
    Color selected = Colors.white;
    String fontFamily = 'Roboto';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.watermarkTextDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.watermarkTextFieldLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // フォント選択（仕様書08・13：文字ウォーターマークもキャンバスの
                // テキストツールと同じくフォントを自由に選べるようにした）
                DropdownButtonFormField<String>(
                  initialValue: fontFamily,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.canvasTextFontLabel, isDense: true),
                  items: [
                    DropdownMenuItem(value: 'Roboto', child: Text(l10n.canvasTextStandardFont)),
                    for (final f in kBundledFonts)
                      DropdownMenuItem(
                        value: f.family,
                        child: Text(f.displayName, style: TextStyle(fontFamily: f.family)),
                      ),
                    ...fontService.fonts.map((f) => DropdownMenuItem(
                          value: fontService.familyNameOf(f),
                          child: Text(f.displayName, style: TextStyle(fontFamily: fontService.familyNameOf(f))),
                        )),
                  ],
                  onChanged: (v) => setS(() => fontFamily = v ?? 'Roboto'),
                ),
                const SizedBox(height: 12),
                Text(l10n.watermarkTextColorLabel, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => showDialog(
                        context: ctx,
                        builder: (pctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(16),
                          child: ColorPickerPanel(
                            currentColor: selected,
                            onColorChanged: (c) => setS(() => selected = c),
                            onClose: () => Navigator.pop(pctx),
                          ),
                        ),
                      ),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: selected,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.watermarkTextColorTapHint, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                await service.addTextWatermark(text, color: selected.toARGB32(), fontFamily: fontFamily);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }
}

class _WatermarkTile extends StatelessWidget {
  final WatermarkAsset asset;
  final VoidCallback onDelete;
  const _WatermarkTile({required this.asset, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<WatermarkService>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: asset.type == WatermarkAssetType.text
                ? Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      asset.text ?? '',
                      style: TextStyle(
                        color: Color(asset.textColor ?? 0xFFFFFFFF),
                        fontFamily: asset.fontFamily,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  )
                : FutureBuilder<String?>(
                    future: service.pathOf(asset.id),
                    builder: (context, snapshot) {
                      final path = snapshot.data;
                      if (path == null) {
                        return Center(child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant));
                      }
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Image.file(File(path), fit: BoxFit.contain),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(asset.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: l10n.commonDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
