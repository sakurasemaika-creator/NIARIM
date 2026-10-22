import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../services/theme_service.dart';
import '../../models/app_theme_preset.dart';
import '../../widgets/responsive.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../../utils/reorder_index.dart';
import '../../widgets/theme_rescue_button.dart';
import 'theme_preview_gallery_screen.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeService = context.watch<ThemeService>();
    final presets = themeService.presets;
    final current = themeService.current;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.themeSettingsTitle),
        actions: [
          const HelpButton(topic: 'テーマ設定'),
          if (themeService.needsThemeRescue)
            ThemeRescueButton(
              iconOnly: MediaQuery.sizeOf(context).width < 520 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4,
            ),
        ],
      ),
      body: desktopCentered(
        context,
        ListView(
          children: [
            // 現在の配色をそのまま縮小表示する。描画の見本は全画面の
            // 41画面ギャラリーと共通で、固定画像・固定配色ではない。
            // タップで全画面に移動する。カラーピッカーの変更結果は
            // ThemeServiceの再描画によって即座にこの見本にも反映される。
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: const Key('themePreviewOpen'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ThemePreviewGalleryScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const ThemePreviewThumbnail(
                          key: Key('themeInlinePreview'),
                          height: 184,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                Localizations.localeOf(context).languageCode == 'ja'
                                    ? '画面プレビュー'
                                    : 'Screen preview',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Kuramubon',
                                  fontFamilyFallback: kHeadingFontFallback,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Localizations.localeOf(context).languageCode == 'ja'
                                    ? 'プロジェクト一覧の見本'
                                    : 'Project list sample',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      Localizations.localeOf(context).languageCode == 'ja'
                                          ? 'タップして全41画面を見る'
                                          : 'Tap to view all 41 screens',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.open_in_full,
                                    size: 17,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // カラーカスタマイズ：すべてカラーピッカー（HSV/RGB/HEX）で
            // 自由に設定できる。変更は即座にアプリ全体（現在のプリセット）へ
            // 反映される。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.themeColorCustomizeSection,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
            ),
            _ColorCustomizeTile(
              label: l10n.themeColorAccent,
              color: current.accentColor,
              onTap: () => _showColorPickerDialog(
                context,
                themeService,
                (p, c) => p.copyWith(accentColor: c),
                current.accentColor,
              ),
            ),
            _ColorCustomizeTile(
              label: l10n.themeColorText,
              color: current.textColor,
              onTap: () => _showColorPickerDialog(
                context,
                themeService,
                (p, c) => p.copyWith(textColor: c),
                current.textColor,
              ),
            ),
            _ColorCustomizeTile(
              label: l10n.themeColorPanelBg,
              color: current.panelBgColor,
              onTap: () => _showColorPickerDialog(
                context,
                themeService,
                (p, c) => p.copyWith(panelBgColor: c),
                current.panelBgColor,
              ),
            ),
            _ColorCustomizeTile(
              label: l10n.themeColorMenuBg,
              color: current.menuBgColor,
              onTap: () => _showColorPickerDialog(
                context,
                themeService,
                (p, c) => p.copyWith(menuBgColor: c),
                current.menuBgColor,
              ),
            ),
            _ColorCustomizeTile(
              label: l10n.themeColorSelection,
              color: current.selectionColor,
              onTap: () => _showColorPickerDialog(
                context,
                themeService,
                (p, c) => p.copyWith(selectionColor: c),
                current.selectionColor,
              ),
            ),
            _ColorCustomizeTile(
              label: l10n.themeColorUpdateMark,
              color: current.updateMarkColor,
              onTap: () => _showColorPickerDialog(
                context,
                themeService,
                (p, c) => p.copyWith(updateMarkColor: c),
                current.updateMarkColor,
              ),
            ),
            const Divider(),
            // テーマ一覧（ドラッグで並び替え可能）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.themePresetSection,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // ドラッグハンドルは行末の明示アイコンのみを使う。既定の
              // ドラッグハンドル（buildDefaultDragHandles）を有効にしたままだと
              // Flutterが自動でもう1つハンドルを追加してしまい、テーマ色の
              // スウォッチからはみ出た黒いハンドルが二重に見えるバグになっていた。
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) => themeService.reorder(
                oldIndex,
                preRemovalIndex(oldIndex, newIndex),
              ),
              children: [
                // 他の画面（設定トップ・セーブツリー等）と統一した、影付き
                // カードとして浮かせるデザイン（作り込みの一環）。
                //
                // カードのタップは「そのテーマの配色を現在の色へ取り込む」
                // だけで、テーマ自体の編集対象にはしない（取り込んだあとに
                // カラーカスタマイズで色を変えても、見本にしたテーマは
                // 書き換わらない）。そのためタップしてもチェックマークは
                // 付かない。テーマ自体を編集したい場合は三点メニューの
                // 「編集」から編集対象にする（そのときだけチェックが付き、
                // 背景をprimaryContainerに敷いて区別する）。
                for (final entry in presets.asMap().entries)
                  Padding(
                    key: ValueKey(entry.value.id),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Material(
                      color: current.id == entry.value.id
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 1,
                      shadowColor: ThemeService.activeColorScheme.shadow
                          .withValues(alpha: 0.15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          themeService.adoptPresetColors(entry.value.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.themeAdoptColorsSnackbar(entry.value.name),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              _PresetColorSwatch(preset: entry.value),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  entry.value.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    fontFamily: 'Kuramubon',
                                    fontFamilyFallback: kHeadingFontFallback,
                                  ),
                                ),
                              ),
                              if (current.id == entry.value.id)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.check,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 16,
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  entry.value.isFavorite
                                      ? Icons.star
                                      : Icons.star_outline,
                                  size: 16,
                                  color: entry.value.isFavorite
                                      ? ThemeService.activeColorScheme.tertiary
                                      : null,
                                ),
                                tooltip: l10n.commonFavoriteToggle,
                                onPressed: () =>
                                    themeService.toggleFavorite(entry.value.id),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16),
                                onSelected: (action) => _handleAction(
                                  context,
                                  action,
                                  entry.value,
                                  themeService,
                                ),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.commonEdit),
                                  ),
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text(l10n.commonRename),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text(l10n.themeDuplicateAction),
                                  ),
                                  PopupMenuItem(
                                    value: 'export',
                                    child: Text(l10n.themeExportMenuItem),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      l10n.commonDelete,
                                      style: TextStyle(
                                        color: ThemeService
                                            .activeColorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ReorderableDragStartListener(
                                index: entry.key,
                                child: const Icon(Icons.drag_handle, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.themeSaveAsNewButton),
                onPressed: () => _saveCurrentAsNew(context, themeService),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: Text(l10n.themeImportButton),
                onPressed: () => _importTheme(context, themeService),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// カラーピッカーダイアログを表示する（カラーカスタマイズ）。
  /// ドラッグ中は `ThemeService.previewCurrent()` でアプリ全体へ即時反映し、
  /// 閉じた時点でユーザーが選んだ色をそのまま保存する。
  ///
  /// 読みにくさを理由にユーザーの色選択を拒否しない。操作不能になる
  /// ほど色が近いテーマからの復旧は、起動画面右上のテーマ非依存の
  /// リセットボタンで行う（判定は `color_contrast.dart`）。
  void _showColorPickerDialog(
    BuildContext context,
    ThemeService service,
    AppThemePreset Function(AppThemePreset preset, Color color) update,
    Color initialColor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: initialColor,
          onColorChanged: (c) =>
              service.previewCurrent(update(service.current, c)),
          onClose: () {
            service.commitCurrent();
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    String action,
    AppThemePreset preset,
    ThemeService service,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      // このテーマ自体を編集対象にする（一覧でチェックが付き、以後の
      // カラーカスタマイズの変更はこのテーマへ上書き保存される）。
      // カードのタップは配色の取り込みだけなので、編集はここからのみ。
      case 'edit':
        service.applyPreset(preset.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.themeEditPresetSnackbar(preset.name))),
        );
      case 'rename':
        _showRenameDialog(context, preset, service);
      case 'duplicate':
        final copy = preset.copyWith(
          id: 'theme_${DateTime.now().millisecondsSinceEpoch}',
          name: l10n.themePresetDuplicateName(preset.name),
        );
        service.savePreset(copy);
      case 'delete':
        // お気に入り登録中は削除できない。
        if (preset.isFavorite) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
          );
        } else {
          service.deletePreset(preset.id);
        }
      case 'export':
        _exportTheme(context, preset);
    }
  }

  Future<void> _exportTheme(BuildContext context, AppThemePreset preset) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName.niatheme');
      await file.writeAsString(jsonEncode(preset.toJson()));
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.themeExportFailedSnackbar(e.toString()))),
      );
    }
  }

  Future<void> _importTheme(BuildContext context, ThemeService service) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['niatheme'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final content = await File(result.files.first.path!).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final preset = AppThemePreset.fromJson(
        json,
      ).copyWith(id: 'theme_${DateTime.now().millisecondsSinceEpoch}');
      service.savePreset(preset);
      service.applyPreset(preset.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.themeImportSuccessSnackbar)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.themeImportFailedSnackbar(e.toString()))),
      );
    }
  }

  void _showRenameDialog(
    BuildContext context,
    AppThemePreset preset,
    ThemeService service,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonRename),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              service.savePreset(preset.copyWith(name: controller.text));
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  void _saveCurrentAsNew(BuildContext context, ThemeService service) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: l10n.themeDefaultPresetName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.themePresetNameDialogTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final newPreset = service.current.copyWith(
                id: 'theme_${DateTime.now().millisecondsSinceEpoch}',
                name: controller.text,
              );
              service.savePreset(newPreset);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

/// カラーカスタマイズ項目1件：色見本＋ラベル＋タップでカラー
/// ピッカーを開く。
class _ColorCustomizeTile extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorCustomizeTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 他の画面（設定トップ・セーブツリー・テーマプリセット一覧）と統一した
    // 影付きカードデザイン（作り込みの一環）。
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: ThemeService.activeColorScheme.shadow.withValues(
          alpha: 0.15,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetColorSwatch extends StatelessWidget {
  final AppThemePreset preset;
  const _PresetColorSwatch({required this.preset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Row(
        children: [
          Expanded(child: Container(color: preset.panelBgColor)),
          Expanded(child: Container(color: preset.accentColor)),
        ],
      ),
    );
  }
}
