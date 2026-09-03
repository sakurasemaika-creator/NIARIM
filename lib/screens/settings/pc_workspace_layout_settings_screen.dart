import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/canvas_dock_panel.dart';
import '../../services/settings_service.dart';
import '../../config/font_fallback.dart';

/// PC専用ワークスペースUIのドッキングパネルの並び順・幅を調整する設定画面。
class PcWorkspaceLayoutSettingsScreen extends StatelessWidget {
  const PcWorkspaceLayoutSettingsScreen({super.key});

  String _panelLabel(AppLocalizations l10n, CanvasDockPanel panel) =>
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pcWorkspaceLayoutScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.pcWorkspaceLayoutIntroHint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, l10n.pcWorkspaceLayoutToolOrderSection),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.pcWorkspaceLayoutToolOrderHint,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _OrderCard(
            order: settings.toolOptionDockOrder,
            labelOf: (p) => _panelLabel(l10n, p),
            onReorder: (order) => settings.setToolOptionDockOrder(order),
            onReset: () => settings.resetToolOptionDockOrder(),
            resetLabel: l10n.pcWorkspaceLayoutResetOrderButton,
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, l10n.pcWorkspaceLayoutRightOrderSection),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.pcWorkspaceLayoutRightOrderHint,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _OrderCard(
            order: settings.rightDockOrder,
            labelOf: (p) => _panelLabel(l10n, p),
            onReorder: (order) => settings.setRightDockOrder(order),
            onReset: () => settings.resetRightDockOrder(),
            resetLabel: l10n.pcWorkspaceLayoutResetOrderButton,
          ),
          SizedBox(height: 20),
          _sectionLabel(context, l10n.pcWorkspaceLayoutWidthSection),
          Card(
            elevation: 1,
            shadowColor: ThemeService.activeColorScheme.shadow.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.pcWorkspaceLayoutToolWidthLabel),
                  trailing: Text('${settings.desktopToolPanelWidth.round()}px'),
                ),
                ListTile(
                  title: Text(l10n.pcWorkspaceLayoutRightWidthLabel),
                  trailing: Text('${settings.desktopPanelWidth.round()}px'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        settings.setDesktopToolPanelWidth(280.0);
                        settings.setDesktopPanelWidth(280.0);
                      },
                      child: Text(l10n.pcWorkspaceLayoutResetWidthButton),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
}

/// ドッキングパネルの積み重ね順を編集するドラッグ並べ替え可能な一覧カード。
class _OrderCard extends StatelessWidget {
  final List<CanvasDockPanel> order;
  final String Function(CanvasDockPanel) labelOf;
  final ValueChanged<List<CanvasDockPanel>> onReorder;
  final VoidCallback onReset;
  final String resetLabel;

  const _OrderCard({
    required this.order,
    required this.labelOf,
    required this.onReorder,
    required this.onReset,
    required this.resetLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: ThemeService.activeColorScheme.shadow.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // onReorderItemはnewIndexを「削除後の位置」へ調整済みで渡すため、
            // 従来必要だった `if (newIndex > oldIndex) newIndex -= 1;` は不要。
            onReorderItem: (oldIndex, newIndex) {
              final next = List<CanvasDockPanel>.of(order);
              final item = next.removeAt(oldIndex);
              next.insert(newIndex, item);
              onReorder(next);
            },
            children: [
              for (final entry in order.asMap().entries)
                ListTile(
                  key: ValueKey(entry.value),
                  title: Text(labelOf(entry.value)),
                  trailing: ReorderableDragStartListener(
                    index: entry.key,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onReset, child: Text(resetLabel)),
            ),
          ),
        ],
      ),
    );
  }
}
