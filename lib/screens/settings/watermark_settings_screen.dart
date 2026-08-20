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
import '../../widgets/editable_slider_value.dart';
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
                  // タップで編集。過去に作成したウォーターマークの
                  // 編集もタップで後からできるようにする。
                  onTap: () => assets[index].type == WatermarkAssetType.text
                      ? _showTextWatermarkDialog(context, service, existing: assets[index])
                      : _showImageWatermarkEditDialog(context, service, assets[index]),
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

  /// 文字ウォーターマークの新規作成・編集を兼ねるダイアログ。過去に作成
  /// したウォーターマークの編集もタップで後からできるようにする。
  /// [existing]を渡すと編集モードになり、既存の内容で初期化する。
  void _showTextWatermarkDialog(BuildContext context, WatermarkService service, {WatermarkAsset? existing}) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: existing?.text ?? '');
    final fontService = context.read<FontService>();
    Color selected = existing != null ? Color(existing.textColor ?? 0xFFFFFFFF) : Colors.white;
    String fontFamily = existing?.fontFamily ?? 'Roboto';
    final shadow = _ShadowOutlineState.from(existing);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? l10n.watermarkTextDialogTitle : l10n.commonEdit),
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
                          border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.watermarkTextColorTapHint, style: const TextStyle(fontSize: 11)),
                  ],
                ),
                _buildShadowOutlineSection(context, l10n, shadow, setS),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                if (existing == null) {
                  await service.addTextWatermark(
                    text, color: selected.toARGB32(), fontFamily: fontFamily,
                    shadowEnabled: shadow.shadowEnabled, shadowColor: shadow.shadowColor.toARGB32(),
                    shadowOffsetX: shadow.shadowOffsetX, shadowOffsetY: shadow.shadowOffsetY,
                    shadowBlur: shadow.shadowBlur,
                    outlineEnabled: shadow.outlineEnabled, outlineColor: shadow.outlineColor.toARGB32(),
                    outlineWidth: shadow.outlineWidth,
                  );
                } else {
                  await service.updateAsset(existing.copyWith(
                    text: text, textColor: selected.toARGB32(), fontFamily: fontFamily,
                    name: text.length > 12 ? '${text.substring(0, 12)}…' : text,
                    shadowEnabled: shadow.shadowEnabled, shadowColor: shadow.shadowColor.toARGB32(),
                    shadowOffsetX: shadow.shadowOffsetX, shadowOffsetY: shadow.shadowOffsetY,
                    shadowBlur: shadow.shadowBlur,
                    outlineEnabled: shadow.outlineEnabled, outlineColor: shadow.outlineColor.toARGB32(),
                    outlineWidth: shadow.outlineWidth,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? l10n.commonAdd : l10n.commonOk),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  /// 画像ウォーターマークの編集ダイアログ。画像そのものの
  /// 差し替えは対象外とし、名前・ドロップシャドウ・縁取りの既定設定のみ
  /// 編集できる。
  void _showImageWatermarkEditDialog(BuildContext context, WatermarkService service, WatermarkAsset existing) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: existing.name);
    final shadow = _ShadowOutlineState.from(existing);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.commonEdit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.folderNameLabel, border: const OutlineInputBorder()),
                ),
                _buildShadowOutlineSection(context, l10n, shadow, setS),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                await service.updateAsset(existing.copyWith(
                  name: nameController.text.trim().isEmpty ? existing.name : nameController.text.trim(),
                  shadowEnabled: shadow.shadowEnabled, shadowColor: shadow.shadowColor.toARGB32(),
                  shadowOffsetX: shadow.shadowOffsetX, shadowOffsetY: shadow.shadowOffsetY,
                  shadowBlur: shadow.shadowBlur,
                  outlineEnabled: shadow.outlineEnabled, outlineColor: shadow.outlineColor.toARGB32(),
                  outlineWidth: shadow.outlineWidth,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    ).then((_) => nameController.dispose());
  }

  /// ドロップシャドウ・縁取りの設定UI（新規作成・編集の両ダイアログで共用）。
  Widget _buildShadowOutlineSection(
      BuildContext context, AppLocalizations l10n, _ShadowOutlineState s, StateSetter setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.watermarkDropShadowLabel),
          value: s.shadowEnabled,
          onChanged: (v) => setS(() => s.shadowEnabled = v),
        ),
        if (s.shadowEnabled) ...[
          _colorRow(context, l10n.watermarkShadowColorLabel, s.shadowColor,
              (c) => setS(() => s.shadowColor = c)),
          _sliderRow(l10n.watermarkShadowOffsetXLabel, s.shadowOffsetX, -30, 30,
              (v) => setS(() => s.shadowOffsetX = v)),
          _sliderRow(l10n.watermarkShadowOffsetYLabel, s.shadowOffsetY, -30, 30,
              (v) => setS(() => s.shadowOffsetY = v)),
          _sliderRow(l10n.watermarkShadowBlurLabel, s.shadowBlur, 0, 30,
              (v) => setS(() => s.shadowBlur = v)),
        ],
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.watermarkOutlineLabel),
          value: s.outlineEnabled,
          onChanged: (v) => setS(() => s.outlineEnabled = v),
        ),
        if (s.outlineEnabled) ...[
          _colorRow(context, l10n.watermarkOutlineColorLabel, s.outlineColor,
              (c) => setS(() => s.outlineColor = c)),
          _sliderRow(l10n.watermarkOutlineWidthLabel, s.outlineWidth, 1, 20,
              (v) => setS(() => s.outlineWidth = v)),
        ],
      ],
    );
  }

  Widget _colorRow(BuildContext context, String label, Color color, ValueChanged<Color> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (pctx) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: ColorPickerPanel(
                  currentColor: color,
                  onColorChanged: onChanged,
                  onClose: () => Navigator.pop(pctx),
                ),
              ),
            ),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
        SizedBox(
          width: 32,
          child: EditableSliderValue(
            text: value.round().toString(),
            style: const TextStyle(fontSize: 11),
            value: value, min: min, max: max,
            onChanged: (v) => onChanged(v.toDouble()),
          ),
        ),
      ],
    );
  }
}

/// ドロップシャドウ・縁取り編集ダイアログ用の一時的な可変状態
/// （WatermarkAssetは不変のため、ダイアログ内での編集用に使う）。
class _ShadowOutlineState {
  bool shadowEnabled;
  Color shadowColor;
  double shadowOffsetX;
  double shadowOffsetY;
  double shadowBlur;
  bool outlineEnabled;
  Color outlineColor;
  double outlineWidth;

  _ShadowOutlineState({
    required this.shadowEnabled,
    required this.shadowColor,
    required this.shadowOffsetX,
    required this.shadowOffsetY,
    required this.shadowBlur,
    required this.outlineEnabled,
    required this.outlineColor,
    required this.outlineWidth,
  });

  factory _ShadowOutlineState.from(WatermarkAsset? asset) => _ShadowOutlineState(
        shadowEnabled: asset?.shadowEnabled ?? false,
        shadowColor: Color(asset?.shadowColor ?? 0x99000000),
        shadowOffsetX: asset?.shadowOffsetX ?? 4,
        shadowOffsetY: asset?.shadowOffsetY ?? 4,
        shadowBlur: asset?.shadowBlur ?? 6,
        outlineEnabled: asset?.outlineEnabled ?? false,
        outlineColor: Color(asset?.outlineColor ?? 0xFFFFFFFF),
        outlineWidth: asset?.outlineWidth ?? 3,
      );
}

class _WatermarkTile extends StatelessWidget {
  final WatermarkAsset asset;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _WatermarkTile({required this.asset, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<WatermarkService>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
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
