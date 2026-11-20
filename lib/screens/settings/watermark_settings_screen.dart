import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../engine/watermark_render.dart';
import '../../models/bundled_fonts.dart';
import '../../models/watermark_asset.dart';
import '../../services/font_service.dart';
import '../../services/watermark_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/duplicate_name.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/labeled_slider.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../config/font_fallback.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/typing_dialog_inset.dart';
import '../../widgets/menu_surface.dart';
import '../../widgets/menu_card.dart';

/// ウォーターマーク登録・管理画面（プレミアム限定）。
/// 「設定項目：画像選択 / 文字入力 / …」のうち、画像・文字それぞれの
/// ウォーターマークを複数登録できる。位置・サイズ・透明度・表示範囲は
/// タイムラインへ追加後にレイヤーパネル・変形ツールから調整する。
/// 登録した項目はタイムラインの「＋ウォーターマーク」から選択して追加できる。
class WatermarkSettingsScreen extends StatelessWidget {
  const WatermarkSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Deep links must not bypass the Premium check in SettingsScreen.
    // Also react immediately to server-side entitlement expiry/revocation.
    if (!context.watch<PremiumService>().isFeatureAvailable(
      PremiumFeature.watermark,
    )) {
      return Scaffold(
        appBar: AppBar(title: FitOrHideTitle(l10n.settingsWatermarkTitle)),
        body: desktopCentered(
          context,
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PremiumLockWidget(
                feature: PremiumFeature.watermark,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        l10n.premiumBannerRegisterButton,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final service = context.watch<WatermarkService>();
    final assets = service.assets;

    return Scaffold(
      // topic: 'ウォーターマーク' はhelp_screen.dart側の項目タイトル（日本語固定の
      // 内部検索キー）と一致させる必要があるため、翻訳対象から除外している。
      appBar: AppBar(
        title: FitOrHideTitle(l10n.settingsWatermarkTitle),
        actions: const [HelpButton(topic: 'ウォーターマーク')],
      ),
      floatingActionButton: desktopCenteredFloatingAction(
        context,
        FloatingActionButton(
          tooltip: l10n.commonAdd,
          onPressed: () => _showAddSheet(context, service),
          child: const Icon(Icons.add),
        ),
      ),
      body: desktopCentered(
        context,
        assets.isEmpty
            ? EmptyStatePlaceholder(
                icon: Icons.branding_watermark,
                title: l10n.watermarkEmptyTitle,
                hint: l10n.watermarkEmptyHint,
                clearFloatingButtons: true,
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                    if (!await confirmDelete(
                      context,
                      itemName: assets[index].name,
                    )) {
                      return;
                    }
                    if (!context.mounted || !_canEditNow(context)) return;
                    service.removeWatermark(assets[index].id);
                  },
                  // タップで編集。過去に作成したウォーターマークの
                  // 編集もタップで後からできるようにする。
                  onTap: () => assets[index].type == WatermarkAssetType.text
                      ? _showTextWatermarkDialog(
                          context,
                          service,
                          existing: assets[index],
                        )
                      : _showImageWatermarkEditDialog(
                          context,
                          service,
                          assets[index],
                        ),
                ),
              ),
      ),
    );
  }

  // Dialogs can survive a Premium lease expiring; check again at commit.
  bool _canEditNow(BuildContext context) {
    if (!context.mounted) return false;
    if (context.read<PremiumService>().isFeatureAvailable(
      PremiumFeature.watermark,
    )) {
      return true;
    }
    showPremiumBanner(context, feature: PremiumFeature.watermark);
    return false;
  }

  void _showAddSheet(BuildContext context, WatermarkService service) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ScrollableSheetBody(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
      ),
    );
  }

  Future<void> _addImageWatermark(
    BuildContext context,
    WatermarkService service,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.firstOrNull?.path;
      if (path == null || !context.mounted || !_canEditNow(context)) return;
      await service.addWatermark(path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.watermarkAddedSnackbar)));
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.watermarkImageImportFailed)));
    }
  }

  /// 文字ウォーターマークの新規作成・編集を兼ねるダイアログ。過去に作成
  /// したウォーターマークの編集もタップで後からできるようにする。
  /// [existing]を渡すと編集モードになり、既存の内容で初期化する。
  void _showTextWatermarkDialog(
    BuildContext context,
    WatermarkService service, {
    WatermarkAsset? existing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: existing?.text ?? '');
    final fontService = context.read<FontService>();
    Color selected = existing != null
        ? Color(existing.textColor ?? 0xFFFFFFFF)
        : ThemeService.activeColorScheme.onSurface;
    String fontFamily = existing?.fontFamily ?? 'Roboto';
    final shadow = _ShadowOutlineState.from(existing);
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            insetPadding: typingDialogInsetPadding(ctx),
            title: Text(
              existing == null
                  ? l10n.watermarkTextDialogTitle
                  : l10n.commonEdit,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setS(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.watermarkTextFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // フォント選択（文字ウォーターマークもキャンバスの
                  // テキストツールと同じくフォントを自由に選べる）
                  MenuSurface(
                    child: DropdownButtonFormField<String>(
                      initialValue: fontFamily,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.canvasTextFontLabel,
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Roboto',
                          child: Text(l10n.canvasTextStandardFont),
                        ),
                        for (final f in kBundledFonts)
                          DropdownMenuItem(
                            value: f.family,
                            child: Text(
                              f.displayName,
                              style: TextStyle(fontFamily: f.family),
                            ),
                          ),
                        ...fontService.fonts.map(
                          (f) => DropdownMenuItem(
                            value: fontService.familyNameOf(f),
                            child: Text(
                              f.displayName,
                              style: TextStyle(
                                fontFamily: fontService.familyNameOf(f),
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setS(() => fontFamily = v ?? 'Roboto'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.watermarkTextColorLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => showDialog(
                          context: ctx,
                          builder: (pctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: typingDialogInsetPadding(
                              pctx,
                              usual: const EdgeInsets.all(16),
                            ),
                            child: ColorPickerPanel(
                              currentColor: selected,
                              onColorChanged: (c) => setS(() => selected = c),
                              onClose: () => Navigator.pop(pctx),
                            ),
                          ),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selected,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          l10n.watermarkTextColorTapHint,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (controller.text.trim().isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: _WatermarkPreview(
                        service: service,
                        asset: shadow.applyTo(
                          WatermarkAsset(
                            id: existing?.id ?? '',
                            name: '',
                            type: WatermarkAssetType.text,
                            text: controller.text.trim(),
                            textColor: selected.toARGB32(),
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    ),
                  _buildShadowOutlineSection(context, l10n, shadow, setS),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () async {
                        if (!context.mounted || !_canEditNow(context)) return;
                        final text = controller.text.trim();
                        if (existing == null) {
                          await service.addTextWatermark(
                            text,
                            color: selected.toARGB32(),
                            fontFamily: fontFamily,
                            shadowEnabled: shadow.shadowEnabled,
                            shadowColor: shadow.shadowColor.toARGB32(),
                            shadowOffsetX: shadow.shadowOffsetX,
                            shadowOffsetY: shadow.shadowOffsetY,
                            shadowBlur: shadow.shadowBlur,
                            outlineEnabled: shadow.outlineEnabled,
                            outlineColor: shadow.outlineColor.toARGB32(),
                            outlineWidth: shadow.outlineWidth,
                          );
                        } else {
                          await service.updateAsset(
                            shadow.applyTo(
                              existing.copyWith(
                                text: text,
                                textColor: selected.toARGB32(),
                                fontFamily: fontFamily,
                                name: WatermarkService.renamedTextWatermark(
                                  existing,
                                  text,
                                ),
                              ),
                            ),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: Text(existing == null ? l10n.commonAdd : l10n.commonOk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 画像ウォーターマークの編集ダイアログ。画像そのものの
  /// 差し替えは対象外とし、名前・ドロップシャドウ・縁取りの既定設定のみ
  /// 編集できる。
  void _showImageWatermarkEditDialog(
    BuildContext context,
    WatermarkService service,
    WatermarkAsset existing,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: existing.name);
    final shadow = _ShadowOutlineState.from(existing);
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: nameController,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            insetPadding: typingDialogInsetPadding(ctx),
            title: Text(l10n.commonEdit),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.folderNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: _WatermarkPreview(
                      service: service,
                      asset: shadow.applyTo(existing),
                    ),
                  ),
                  _buildShadowOutlineSection(context, l10n, shadow, setS),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () async {
                  if (!context.mounted || !_canEditNow(context)) return;
                  await service.updateAsset(
                    shadow.applyTo(
                      existing.copyWith(
                        name: nameController.text.trim().isEmpty
                            ? existing.name
                            : nameController.text.trim(),
                      ),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ドロップシャドウ・縁取りの設定UI（新規作成・編集の両ダイアログで共用）。
  Widget _buildShadowOutlineSection(
    BuildContext context,
    AppLocalizations l10n,
    _ShadowOutlineState s,
    StateSetter setS,
  ) {
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
          _colorRow(
            context,
            l10n.watermarkShadowColorLabel,
            s.shadowColor,
            (c) => setS(() => s.shadowColor = c),
          ),
          _sliderRow(
            l10n.watermarkShadowOffsetXLabel,
            s.shadowOffsetX,
            -30,
            30,
            (v) => setS(() => s.shadowOffsetX = v),
          ),
          _sliderRow(
            l10n.watermarkShadowOffsetYLabel,
            s.shadowOffsetY,
            -30,
            30,
            (v) => setS(() => s.shadowOffsetY = v),
          ),
          _sliderRow(
            l10n.watermarkShadowBlurLabel,
            s.shadowBlur,
            0,
            30,
            (v) => setS(() => s.shadowBlur = v),
          ),
        ],
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.watermarkOutlineLabel),
          value: s.outlineEnabled,
          onChanged: (v) => setS(() => s.outlineEnabled = v),
        ),
        if (s.outlineEnabled) ...[
          _colorRow(
            context,
            l10n.watermarkOutlineColorLabel,
            s.outlineColor,
            (c) => setS(() => s.outlineColor = c),
          ),
          _sliderRow(
            l10n.watermarkOutlineWidthLabel,
            s.outlineWidth,
            1,
            20,
            (v) => setS(() => s.outlineWidth = v),
          ),
        ],
      ],
    );
  }

  Widget _colorRow(
    BuildContext context,
    String label,
    Color color,
    ValueChanged<Color> onChanged,
  ) {
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
                insetPadding: typingDialogInsetPadding(
                  pctx,
                  usual: const EdgeInsets.all(16),
                ),
                child: ColorPickerPanel(
                  currentColor: color,
                  onColorChanged: onChanged,
                  onClose: () => Navigator.pop(pctx),
                ),
              ),
            ),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return LabeledSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      valueText: value.round().toString(),
      valueStyle: const TextStyle(fontSize: 11),
      onChanged: onChanged,
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

  factory _ShadowOutlineState.from(WatermarkAsset? asset) =>
      _ShadowOutlineState(
        shadowEnabled: asset?.shadowEnabled ?? false,
        shadowColor: Color(asset?.shadowColor ?? 0x99000000),
        shadowOffsetX: asset?.shadowOffsetX ?? 4,
        shadowOffsetY: asset?.shadowOffsetY ?? 4,
        shadowBlur: asset?.shadowBlur ?? 6,
        outlineEnabled: asset?.outlineEnabled ?? false,
        outlineColor: Color(asset?.outlineColor ?? 0xFFFFFFFF),
        outlineWidth: asset?.outlineWidth ?? 3,
      );

  WatermarkAsset applyTo(WatermarkAsset asset) => asset.copyWith(
    shadowEnabled: shadowEnabled,
    shadowColor: shadowColor.toARGB32(),
    shadowOffsetX: shadowOffsetX,
    shadowOffsetY: shadowOffsetY,
    shadowBlur: shadowBlur,
    outlineEnabled: outlineEnabled,
    outlineColor: outlineColor.toARGB32(),
    outlineWidth: outlineWidth,
  );
}

class _WatermarkTile extends StatelessWidget {
  final WatermarkAsset asset;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _WatermarkTile({
    required this.asset,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<WatermarkService>();
    return MenuCard(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: ThemeService.activeColorScheme.shadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: _WatermarkPreview(service: service, asset: asset),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(child: _WatermarkName(asset.name)),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    size: 16,
                    color: ThemeService.activeColorScheme.error,
                  ),
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

class _WatermarkPreview extends StatefulWidget {
  const _WatermarkPreview({required this.service, required this.asset});

  final WatermarkService service;
  final WatermarkAsset asset;

  @override
  State<_WatermarkPreview> createState() => _WatermarkPreviewState();
}

class _WatermarkPreviewState extends State<_WatermarkPreview> {
  ui.Image? _image;
  int _revision = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _WatermarkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.asset.toJson(), widget.asset.toJson())) _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final asset = widget.asset;
    const width = 240;
    const height = 144;
    ui.Image? image;
    try {
      final path = asset.type == WatermarkAssetType.image
          ? await widget.service.pathOf(asset.id)
          : null;
      final pixels = await rasterizeWatermark(
        asset,
        width,
        height,
        imagePath: path,
        preview: true,
      );
      if (pixels != null && mounted && revision == _revision) {
        final decoded = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels,
          width,
          height,
          ui.PixelFormat.rgba8888,
          decoded.complete,
        );
        image = await decoded.future;
      }
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
    if (!mounted || revision != _revision) {
      image?.dispose();
      return;
    }
    final previous = _image;
    setState(() {
      _image = image;
      _failed = image == null;
    });
    previous?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: _failed
            ? Icon(Icons.broken_image, color: scheme.onSurfaceVariant)
            : RawImage(image: _image, fit: BoxFit.contain),
      ),
    );
  }
}

/// タイルの下の透かしの名前（2行まで）。引き継ぎで足した複製
/// （「名前 (コピー)」）は、名前を縮めても複製の印は縮めずに出す（タイルは
/// 狭く、元の透かしと同じ名前の始まりしか見えないと、読み込みの知らせが
/// 出した名前を探せず、どちらを消すかも分からない）。
class _WatermarkName extends StatelessWidget {
  const _WatermarkName(this.name);

  final String name;

  static const _style = TextStyle(fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final copy = copyNameMark(name);
    if (copy == null) {
      return Text(
        name,
        style: localizedHeadingStyle(context, _style),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final mark = copy.mark.trimLeft();
    // 入りきれば1行、入らなければ名前を1行に縮め、印を次の行に出す。
    return Wrap(
      spacing: mark.length == copy.mark.length ? 0 : 4,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(
          copy.name,
          style: localizedHeadingStyle(context, _style),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            mark,
            style: localizedHeadingStyle(context, _style),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
