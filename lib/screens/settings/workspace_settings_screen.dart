import 'package:niarim/services/theme_service.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/canvas_dock_panel.dart';
import '../../models/quick_tool_entry.dart';
import '../../models/toolbar_item.dart';
import '../../models/workspace_preset.dart';
import '../../services/premium_service.dart';
import '../../services/quick_tool_service.dart';
import '../../services/settings_service.dart';
import '../../services/workspace_preset_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/qr_import_dialog.dart';
import '../../widgets/qr_share_dialog.dart';
import 'pc_workspace_layout_settings_screen.dart';
import '../../config/font_fallback.dart';
import '../../widgets/scrollable_sheet_body.dart';

class WorkspaceSettingsScreen extends StatelessWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final presetService = context.watch<WorkspacePresetService>();
    final premium = context.watch<PremiumService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceScreenTitle),
        actions: const [HelpButton(topic: 'ワークスペース設定')],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel(context, l10n.workspaceToolbarEditSection),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // ツールバー編集機能に対応する説明文。
              child: Text(
                l10n.workspaceToolbarEditHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // 実際のキャンバス画面での横並び配置を模したプレビュー
            // （設定項目の一覧だけでは仕上がりが分かりにくいため）。
            _ToolbarPreview(
              order: settings.toolbarOrder,
              hidden: settings.hiddenToolbarItems,
            ),
            SizedBox(height: 8),
            Card(
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // ドラッグハンドルは行末に明示アイコンとして置く（既定の
                    // ドラッグハンドルを有効にしたままだと、Flutterが自動で
                    // もう1つハンドルを追加してしまい、二重に表示されるバグに
                    // なっていた。テーマ設定の並べ替えと同じ不具合）。
                    buildDefaultDragHandles: false,
                    // onReorderItemはnewIndexを「削除後の位置」へ調整済みで
                    // 渡すため、従来の `newIndex -= 1` 補正は不要。
                    onReorderItem: (oldIndex, newIndex) {
                      final order = List<ToolbarItemId>.of(
                        settings.toolbarOrder,
                      );
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                      settings.setToolbarOrder(order);
                    },
                    children: [
                      for (final entry in settings.toolbarOrder.asMap().entries)
                        Builder(
                          key: ValueKey(entry.value),
                          builder: (context) {
                            final id = entry.value;
                            // 手のひらツール：強制スマホモード中は
                            // そもそもONにできないよう設定項目自体をグレーアウトする。
                            // PCモード固定・自動判定の場合は設定可能で、ONにした
                            // 場合でも実際の表示は横画面時のみ（canShowPanTool）。
                            final isPanForcedOff =
                                id == ToolbarItemId.pan &&
                                settings.forcePcMode == false;
                            return CheckboxListTile(
                              title: Text(id.label(l10n)),
                              subtitle: id == ToolbarItemId.pan
                                  ? Text(
                                      isPanForcedOff
                                          ? l10n.workspaceToolbarPanDisabledHint
                                          : l10n.workspaceToolbarPcOnlyHint,
                                    )
                                  : null,
                              value: !settings.hiddenToolbarItems.contains(id),
                              onChanged: isPanForcedOff
                                  ? null
                                  : (v) => settings.setToolbarItemVisible(
                                      id,
                                      v ?? true,
                                    ),
                              secondary: ReorderableDragStartListener(
                                index: entry.key,
                                child: const Icon(Icons.drag_handle),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => settings.resetToolbarDefault(),
                        child: Text(l10n.workspaceResetToolbarDefault),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.workspacePanelLayoutSection),
            Builder(
              builder: (context) {
                // スマホモードではツールバーが画面下部に固定表示されるため、
                // 左右反転（左利きモード）が意味を持つのはパネルを常時
                // ドッキング表示するPC/DeXモードの場合のみ。ただし判定は
                // 「設定画面を開いた時点の画面幅」ではなく forcePcMode の設定値
                // で行う（自動判定・PC固定の場合は、縦画面でこの設定画面を
                // 開いていても有効にしておく必要がある。横画面へ回転した時に
                // 初めてパネルがドッキング表示され、左利きモードが必要になる
                // ため）。強制スマホモード時のみ無効化する。
                final forceMobile = settings.forcePcMode == false;
                return Card(
                  elevation: 1,
                  shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                    alpha: 0.15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: SwitchListTile(
                    title: Text(l10n.workspaceLeftHandedMode),
                    subtitle: Text(
                      forceMobile
                          ? l10n.workspaceLeftHandedSubtitleMobile
                          : l10n.workspaceLeftHandedSubtitlePc,
                    ),
                    value: settings.isLeftHanded,
                    onChanged: forceMobile
                        ? null
                        : (v) => settings.setLeftHanded(v),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.workspacePcModeSection),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // PC/DeXモードの手動固定機能に対応する説明文。
              child: Text(
                l10n.workspacePcModeHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              // 選択状態と変更通知はRadioGroupがまとめて持つ
              // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
              child: RadioGroup<bool?>(
                groupValue: settings.forcePcMode,
                onChanged: (v) => settings.setForcePcMode(v),
                child: Column(
                  children: [
                    RadioListTile<bool?>(
                      title: Text(l10n.workspacePcModeAuto),
                      value: null,
                    ),
                    RadioListTile<bool?>(
                      title: Text(l10n.workspacePcModeAlwaysPc),
                      value: true,
                    ),
                    RadioListTile<bool?>(
                      title: Text(l10n.workspacePcModeAlwaysMobile),
                      value: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.workspaceDockPanelSection),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // PC/DeXモードでは複数パネルを同時にドッキング表示できる
              // （スマホ版は誤操作防止のため対象外、常に非表示スタート）。
              child: Text(
                l10n.workspaceDockPanelHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  for (final panel in CanvasDockPanel.values)
                    CheckboxListTile(
                      dense: true,
                      title: Text(_dockPanelLabel(l10n, panel)),
                      value: settings.defaultDockedPanels.contains(panel),
                      onChanged: (v) {
                        final next = Set<CanvasDockPanel>.of(
                          settings.defaultDockedPanels,
                        );
                        if (v ?? false) {
                          next.add(panel);
                        } else {
                          next.remove(panel);
                        }
                        settings.setDefaultDockedPanels(next);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                adMockMaterialPageRoute(
                  builder: (_) => const PcWorkspaceLayoutSettingsScreen(),
                ),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: Text(l10n.workspacePcLayoutButton),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.workspaceTimelineSection),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.workspaceTimelineHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.workspaceTimelineTrackHeightLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 実物大プレビュー：数字だけでは実際の見え方が
                    // 分かりにくいため、実際のクリップと同じ見た目・
                    // 高さの見本を1:1スケールで表示する。
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 160,
                        height: SettingsService.trackHeightForLevel(
                          settings.timelineTrackHeightLevel,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeService.activeColorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.workspaceTimelinePreviewLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: ThemeService.activeColorScheme.onSurface,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Slider(
                      value: settings.timelineTrackHeightLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '${settings.timelineTrackHeightLevel}',
                      onChanged: (v) =>
                          settings.setTimelineTrackHeightLevel(v.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.workspaceEndCardSection),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.workspaceEndCardHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SwitchListTile(
                secondary: premium.isPremium
                    ? null
                    : Icon(
                        Icons.lock,
                        color: ThemeService.activeColorScheme.tertiary,
                      ),
                title: Text(l10n.workspaceEndCardDefaultHiddenTitle),
                value:
                    premium.isPremium &&
                    settings.endCardDefaultHiddenForPremium,
                onChanged: premium.isPremium
                    ? (v) => settings.setEndCardDefaultHiddenForPremium(v)
                    : (_) => showPremiumBanner(context),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.workspaceSaveSection),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.workspaceSaveHint,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // 「適用」は名前の登録を必要とせず、UI・外観設定と同じくその場で
            // アプリ全体へ反映するだけの操作（各設定項目は変更のたびに
            // 即座に反映済みだが、変更内容が確かに反映されたことを
            // 明示的に確認できるようにする）。
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.workspaceAppliedSnackbar)),
                );
              },
              icon: const Icon(Icons.check),
              label: Text(l10n.workspaceApplyCurrentButton),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _showSaveDialog(context, settings, presetService),
              icon: const Icon(Icons.save),
              label: Text(l10n.workspaceSaveAsButton),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: presetService.presets.isEmpty
                  ? null
                  : () => _showShareSheet(context, presetService),
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.workspaceShareButton),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showLoadSheet(context, settings, presetService),
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.workspaceLoadButton),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _dockPanelLabel(AppLocalizations l10n, CanvasDockPanel panel) =>
      switch (panel) {
        CanvasDockPanel.brush => l10n.workspaceDockPanelBrush,
        CanvasDockPanel.colorPicker => l10n.workspaceDockPanelColorPicker,
        CanvasDockPanel.layer => l10n.workspaceDockPanelLayer,
        CanvasDockPanel.tone => l10n.workspaceDockPanelTone,
        CanvasDockPanel.stamp => l10n.workspaceDockPanelStamp,
        CanvasDockPanel.penSubTool => l10n.workspaceDockPanelPenSubTool,
        CanvasDockPanel.onionSkin => l10n.workspaceDockPanelOnionSkin,
        CanvasDockPanel.ruler => l10n.workspaceDockPanelRuler,
        CanvasDockPanel.filter => l10n.workspaceDockPanelFilter,
        CanvasDockPanel.quickTool => l10n.workspaceDockPanelQuickTool,
        CanvasDockPanel.colorAdjust => l10n.workspaceDockPanelColorAdjust,
        CanvasDockPanel.canvasPreview => l10n.workspaceDockPanelCanvasPreview,
      };

  void _showSaveDialog(
    BuildContext context,
    SettingsService settings,
    WorkspacePresetService presetService,
  ) {
    final quickToolService = context.read<QuickToolService>();
    showDialog(
      context: context,
      builder: (_) => _WorkspaceSaveDialog(
        settings: settings,
        presetService: presetService,
        quickToolEntries: quickToolService.entries
            .map((e) => e.toJson())
            .toList(),
      ),
    );
  }

  /// 保存済みワークスペースを1つ選んでファイルとして共有する。
  void _showShareSheet(
    BuildContext context,
    WorkspacePresetService presetService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.workspaceShareSelectTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
            ),
            for (final preset in presetService.presets)
              Builder(
                builder: (context) {
                  final payload = jsonEncode(preset.toJson());
                  final qrAvailable = payload.length <= kQrShareSafeCharLimit;
                  return ListTile(
                    leading: const Icon(Icons.dashboard_customize),
                    title: Text(preset.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.qr_code_2),
                      tooltip: qrAvailable
                          ? l10n.colorPickerShareViaQr
                          : l10n.qrShareTooLargeHint,
                      onPressed: qrAvailable
                          ? () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => QrShareDialog(
                                  title: preset.name,
                                  payload: payload,
                                ),
                              );
                            }
                          : null,
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        final file = await presetService.exportPreset(
                          preset.id,
                        );
                        if (!context.mounted) return;
                        await SharePlus.instance.share(
                          ShareParams(files: [XFile(file.path)]),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.workspaceShareFailedSnackbar(e.toString()),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showLoadSheet(
    BuildContext context,
    SettingsService settings,
    WorkspacePresetService presetService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final quickToolService = context.read<QuickToolService>();

    void applyPreset(WorkspacePreset preset) {
      settings.setLeftHanded(preset.isLeftHanded);
      settings.setForcePcMode(preset.forcePcMode);
      // 表示ツール・早替えツールも一括で切り替える。
      settings.applyToolbarPreset(
        preset.toolbarOrderIds,
        preset.hiddenToolbarItemIds,
      );
      if (preset.quickToolEntries.isNotEmpty) {
        quickToolService.replaceAll(
          preset.quickToolEntries
              .map((e) => QuickToolEntry.fromJson(e))
              .toList(),
        );
      }
      // PC版で既定で開くパネルも一括で切り替える。保存時点で1枚も選んで
      // いなかった場合（空リスト）は、アプリの既定値を保つため上書きしない。
      if (preset.defaultDockedPanels.isNotEmpty) {
        final map = CanvasDockPanel.values.asNameMap();
        final panels = preset.defaultDockedPanels
            .map((n) => map[n])
            .whereType<CanvasDockPanel>()
            .toSet();
        settings.setDefaultDockedPanels(panels);
      }
      if (preset.desktopPanelWidth != null) {
        settings.setDesktopPanelWidth(preset.desktopPanelWidth!);
      }
      if (preset.desktopToolPanelWidth != null) {
        settings.setDesktopToolPanelWidth(preset.desktopToolPanelWidth!);
      }
      if (preset.toolOptionDockOrder.isNotEmpty) {
        final map = CanvasDockPanel.values.asNameMap();
        final order = preset.toolOptionDockOrder
            .map((n) => map[n])
            .whereType<CanvasDockPanel>()
            .toList();
        settings.setToolOptionDockOrder(order);
      }
      if (preset.rightDockOrder.isNotEmpty) {
        final map = CanvasDockPanel.values.asNameMap();
        final order = preset.rightDockOrder
            .map((n) => map[n])
            .whereType<CanvasDockPanel>()
            .toList();
        settings.setRightDockOrder(order);
      }
    }

    Future<void> importFromFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['niaworkspace'],
      );
      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        return;
      }
      try {
        await presetService.importPresetFile(result.files.first.path!);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.workspaceImportFailedSnackbar(e.toString())),
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 端末内の一覧より上に、外部ファイル（.niaworkspace）からの
            // 読み込みを常設する。
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l10n.workspaceImportFromFileButton),
              onTap: () {
                Navigator.pop(ctx);
                importFromFile();
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
                      await presetService.importPresetJson(text);
                      return true;
                    },
                  ),
                );
              },
            ),
            if (presetService.presets.isNotEmpty) const Divider(height: 1),
            for (final preset in presetService.presets)
              ListTile(
                leading: const Icon(Icons.dashboard_customize),
                title: Text(preset.name),
                subtitle: Text(
                  preset.isLeftHanded
                      ? l10n.workspaceLoadLeftHanded
                      : l10n.workspaceLoadRightHanded,
                ),
                onTap: () {
                  applyPreset(preset);
                  Navigator.pop(ctx);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.commonRename,
                      onPressed: () => _showRenamePresetDialog(
                        context,
                        presetService,
                        preset,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: ThemeService.activeColorScheme.error,
                      ),
                      tooltip: l10n.commonDelete,
                      onPressed: () async {
                        if (!await confirmDelete(
                          context,
                          itemName: preset.name,
                        )) {
                          return;
                        }
                        presetService.delete(preset.id);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRenamePresetDialog(
    BuildContext context,
    WorkspacePresetService presetService,
    WorkspacePreset preset,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.commonRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.workspaceSaveDialogLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                presetService.rename(preset.id, name);
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「ワークスペースに名前を付けて保存・上書き保存」ダイアログ。
/// 新規保存（名前必須）と上書き保存（既存の一覧から選択、名前は
/// 未入力なら元の名前を再利用）の両方をここでまとめて扱う。
class _WorkspaceSaveDialog extends StatefulWidget {
  final SettingsService settings;
  final WorkspacePresetService presetService;
  final List<Map<String, dynamic>> quickToolEntries;

  const _WorkspaceSaveDialog({
    required this.settings,
    required this.presetService,
    required this.quickToolEntries,
  });

  @override
  State<_WorkspaceSaveDialog> createState() => _WorkspaceSaveDialogState();
}

class _WorkspaceSaveDialogState extends State<_WorkspaceSaveDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveNew() {
    final l10n = AppLocalizations.of(context)!;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = l10n.workspaceNameRequiredError);
      return;
    }
    widget.presetService.save(
      name,
      isLeftHanded: widget.settings.isLeftHanded,
      forcePcMode: widget.settings.forcePcMode,
      toolbarOrder: widget.settings.toolbarOrder.map((e) => e.name).toList(),
      hiddenToolbarItems: widget.settings.hiddenToolbarItems
          .map((e) => e.name)
          .toList(),
      quickToolEntries: widget.quickToolEntries,
      defaultDockedPanels: widget.settings.defaultDockedPanels
          .map((e) => e.name)
          .toList(),
      desktopPanelWidth: widget.settings.desktopPanelWidth,
      desktopToolPanelWidth: widget.settings.desktopToolPanelWidth,
      toolOptionDockOrder: widget.settings.toolOptionDockOrder
          .map((e) => e.name)
          .toList(),
      rightDockOrder: widget.settings.rightDockOrder
          .map((e) => e.name)
          .toList(),
    );
    Navigator.pop(context);
  }

  Future<void> _overwrite() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.presetService.presets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.workspaceNoSavedPresets)));
      return;
    }
    final selected = await showModalBottomSheet<WorkspacePreset>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.workspaceOverwriteSelectTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
            ),
            for (final preset in widget.presetService.presets)
              ListTile(
                leading: const Icon(Icons.dashboard_customize),
                title: Text(preset.name),
                onTap: () => Navigator.pop(ctx, preset),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.workspaceOverwriteConfirmTitle),
        content: Text(l10n.workspaceOverwriteConfirmBody(selected.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final newName = _controller.text.trim();
    await widget.presetService.overwrite(
      selected.id,
      newName: newName.isEmpty ? null : newName,
      isLeftHanded: widget.settings.isLeftHanded,
      forcePcMode: widget.settings.forcePcMode,
      toolbarOrder: widget.settings.toolbarOrder.map((e) => e.name).toList(),
      hiddenToolbarItems: widget.settings.hiddenToolbarItems
          .map((e) => e.name)
          .toList(),
      quickToolEntries: widget.quickToolEntries,
      defaultDockedPanels: widget.settings.defaultDockedPanels
          .map((e) => e.name)
          .toList(),
      desktopPanelWidth: widget.settings.desktopPanelWidth,
      desktopToolPanelWidth: widget.settings.desktopToolPanelWidth,
      toolOptionDockOrder: widget.settings.toolOptionDockOrder
          .map((e) => e.name)
          .toList(),
      rightDockOrder: widget.settings.rightDockOrder
          .map((e) => e.name)
          .toList(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.workspaceSaveDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.workspaceSaveDialogLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          if (_errorText != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                _errorText!,
                style: TextStyle(
                  color: ThemeService.activeColorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _overwrite,
          child: Text(l10n.workspaceOverwriteButton),
        ),
        FilledButton(onPressed: _saveNew, child: Text(l10n.commonSave)),
      ],
    );
  }
}

/// キャンバス画面の実際のツールバー（横並び）を模したプレビュー
/// （設定のチェックボックス一覧だけでは仕上がりが分かり
/// にくいため、非表示にしたツールが除かれた状態の並びをそのまま示す）。
class _ToolbarPreview extends StatelessWidget {
  final List<ToolbarItemId> order;
  final Set<ToolbarItemId> hidden;

  const _ToolbarPreview({required this.order, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 手のひらツールはPCモード限定のため、プレビューも実際のツールバーと
    // 同じ条件でフィルタリングして表示のズレを防ぐ。
    final visible = order
        .where((id) => !hidden.contains(id))
        .where((id) => id != ToolbarItemId.pan || canShowPanTool(context))
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: visible.isEmpty
          ? Center(
              child: Text(
                l10n.workspaceEmptyToolbar,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  for (final id in visible)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message: id.label(l10n),
                        child: id.buildIcon(size: 20, color: scheme.onSurface),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
