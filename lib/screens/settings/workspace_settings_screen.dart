import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/quick_tool_entry.dart';
import '../../models/toolbar_item.dart';
import '../../services/quick_tool_service.dart';
import '../../services/settings_service.dart';
import '../../services/workspace_preset_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/confirm_delete.dart';

class WorkspaceSettingsScreen extends StatelessWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final presetService = context.watch<WorkspacePresetService>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workspaceScreenTitle), actions: const [HelpButton()]),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(context, l10n.workspaceToolbarEditSection),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // 仕様書08：ツールバー編集機能に対応する説明文。
            child: Text(l10n.workspaceToolbarEditHint,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          // 実際のキャンバス画面での横並び配置を模したプレビュー
          // （タスク#93：設定項目の一覧だけでは仕上がりが分かりにくいため）。
          _ToolbarPreview(
            order: settings.toolbarOrder,
            hidden: settings.hiddenToolbarItems,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final order = List<ToolbarItemId>.of(settings.toolbarOrder);
                    final item = order.removeAt(oldIndex);
                    order.insert(newIndex, item);
                    settings.setToolbarOrder(order);
                  },
                  children: [
                    for (final id in settings.toolbarOrder)
                      Builder(
                        key: ValueKey(id),
                        builder: (context) {
                          // 手のひらツール：強制スマホモード中は
                          // そもそもONにできないよう設定項目自体をグレーアウトする。
                          // PCモード固定・自動判定の場合は設定可能で、ONにした
                          // 場合でも実際の表示は横画面時のみ（canShowPanTool）。
                          final isPanForcedOff =
                              id == ToolbarItemId.pan && settings.forcePcMode == false;
                          return CheckboxListTile(
                            title: Text(id.label(l10n)),
                            subtitle: id == ToolbarItemId.pan
                                ? Text(isPanForcedOff
                                    ? l10n.workspaceToolbarPanDisabledHint
                                    : l10n.workspaceToolbarPcOnlyHint)
                                : null,
                            value: !settings.hiddenToolbarItems.contains(id),
                            onChanged: isPanForcedOff
                                ? null
                                : (v) => settings.setToolbarItemVisible(id, v ?? true),
                            secondary: const Icon(Icons.drag_handle),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          Builder(builder: (context) {
            // スマホモードではツールバーが画面下部に固定表示されるため、
            // 左右反転（左利きモード）が意味を持つのはパネルを常時
            // ドッキング表示するPC/DeXモードの場合のみ。スマホモードでは
            // 無効化し、その旨を案内する。
            final isPc = isWideScreen(context);
            return Card(
              child: SwitchListTile(
                title: Text(l10n.workspaceLeftHandedMode),
                subtitle: Text(isPc ? l10n.workspaceLeftHandedSubtitlePc : l10n.workspaceLeftHandedSubtitleMobile),
                value: settings.isLeftHanded,
                onChanged: isPc ? (v) => settings.setLeftHanded(v) : null,
              ),
            );
          }),
          const SizedBox(height: 20),
          _sectionLabel(context, l10n.workspacePcModeSection),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // 仕様書02：PC/DeXモードの手動固定機能に対応する説明文。
            child: Text(l10n.workspacePcModeHint,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Card(
            child: Column(
              children: [
                RadioListTile<bool?>(
                  title: Text(l10n.workspacePcModeAuto),
                  value: null,
                  groupValue: settings.forcePcMode,
                  onChanged: (v) => settings.setForcePcMode(v),
                ),
                RadioListTile<bool?>(
                  title: Text(l10n.workspacePcModeAlwaysPc),
                  value: true,
                  groupValue: settings.forcePcMode,
                  onChanged: (v) => settings.setForcePcMode(v),
                ),
                RadioListTile<bool?>(
                  title: Text(l10n.workspacePcModeAlwaysMobile),
                  value: false,
                  groupValue: settings.forcePcMode,
                  onChanged: (v) => settings.setForcePcMode(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, l10n.workspaceSaveSection),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.workspaceSaveHint,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          FilledButton.icon(
            onPressed: () => _showSaveDialog(context, settings, presetService),
            icon: const Icon(Icons.save),
            label: Text(l10n.workspaceSaveCurrentButton),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: presetService.presets.isEmpty
                ? null
                : () => _showLoadSheet(context, settings, presetService),
            icon: const Icon(Icons.folder_open),
            label: Text(presetService.presets.isEmpty ? l10n.workspaceLoadButtonEmpty : l10n.workspaceLoadButton),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      )),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  void _showSaveDialog(BuildContext context, SettingsService settings, WorkspacePresetService presetService) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final quickToolService = context.read<QuickToolService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.workspaceSaveDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.workspaceSaveDialogLabel, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              presetService.save(
                name,
                isLeftHanded: settings.isLeftHanded,
                forcePcMode: settings.forcePcMode,
                toolbarOrder: settings.toolbarOrder.map((e) => e.name).toList(),
                hiddenToolbarItems: settings.hiddenToolbarItems.map((e) => e.name).toList(),
                quickToolEntries: quickToolService.entries.map((e) => e.toJson()).toList(),
              );
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showLoadSheet(BuildContext context, SettingsService settings, WorkspacePresetService presetService) {
    final l10n = AppLocalizations.of(context)!;
    final quickToolService = context.read<QuickToolService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preset in presetService.presets)
              ListTile(
                leading: const Icon(Icons.dashboard_customize),
                title: Text(preset.name),
                subtitle: Text(preset.isLeftHanded ? l10n.workspaceLoadLeftHanded : l10n.workspaceLoadRightHanded),
                onTap: () {
                  settings.setLeftHanded(preset.isLeftHanded);
                  settings.setForcePcMode(preset.forcePcMode);
                  // 表示ツール・早替えツールも一括で切り替える（仕様書08）
                  settings.applyToolbarPreset(preset.toolbarOrderIds, preset.hiddenToolbarItemIds);
                  if (preset.quickToolEntries.isNotEmpty) {
                    quickToolService.replaceAll(
                        preset.quickToolEntries.map((e) => QuickToolEntry.fromJson(e)).toList());
                  }
                  Navigator.pop(ctx);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: l10n.commonDelete,
                  onPressed: () async {
                    if (!await confirmDelete(context, itemName: preset.name)) return;
                    presetService.delete(preset.id);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// キャンバス画面の実際のツールバー（横並び）を模したプレビュー
/// （タスク#93：設定のチェックボックス一覧だけでは仕上がりが分かり
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
              child: Text(l10n.workspaceEmptyToolbar,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
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
                        child: Icon(id.icon, size: 20, color: scheme.onSurface),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
