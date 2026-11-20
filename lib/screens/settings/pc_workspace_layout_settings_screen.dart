import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/canvas_dock_panel.dart';
import '../../services/settings_service.dart';
import 'widgets/pc_workspace_layout_preview.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/first_that_fits.dart';
import '../../widgets/keep_together_text.dart';

/// PC専用ワークスペースUIのドッキングパネルの並び順・幅を調整する設定画面。
class PcWorkspaceLayoutSettingsScreen extends StatefulWidget {
  const PcWorkspaceLayoutSettingsScreen({super.key});

  @override
  State<PcWorkspaceLayoutSettingsScreen> createState() =>
      _PcWorkspaceLayoutSettingsScreenState();
}

class _PcWorkspaceLayoutSettingsScreenState
    extends State<PcWorkspaceLayoutSettingsScreen> {
  /// 配置の見本の「全体を表示」（ボタンは画面の浮かぶボタンの場所に置く）。
  final _fitRequests = PcWorkspaceFitRequests();

  @override
  void dispose() {
    _fitRequests.dispose();
    super.dispose();
  }

  Future<void> _confirmReset(
    String title,
    String message,
    Future<void> Function() reset,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await reset();
  }

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
        CanvasDockPanel.reference => l10n.referenceWindowTitle,
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildLayout(context, constraints.maxHeight),
  );

  Widget _buildLayout(BuildContext context, double height) {
    final l = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final media = MediaQuery.of(context);
    final compact =
        height - media.padding.vertical < 380 + media.textScaler.scale(14) * 2;
    final resetActions = [
      (
        key: null,
        title: l.pcWorkspaceLayoutResetOrderButton,
        message: l.pcWorkspaceLayoutResetOrderConfirmBody,
        icon: Icons.restart_alt,
        reset: settings.resetDesktopDockOrderToHandedDefaults,
      ),
      (
        key: const Key('resetDesktopWorkspaceLayout'),
        title: l.pcLayoutResetWorkspace,
        message: l.pcWorkspaceLayoutResetWorkspaceConfirmBody,
        icon: Icons.settings_backup_restore,
        reset: settings.resetDesktopWorkspaceLayout,
      ),
      (
        key: null,
        title: l.pcWorkspaceLayoutResetWidthButton,
        message: l.pcWorkspaceLayoutResetSizeConfirmBody,
        icon: Icons.aspect_ratio_outlined,
        reset: () async {
          await settings.setDesktopToolPanelWidth(280);
          await settings.setDesktopPanelWidth(280);
          for (final panel in CanvasDockPanel.values) {
            await settings.setDesktopDockWidth(panel, 280);
            await settings.setDesktopDockHeight(panel, 260);
          }
        },
      ),
    ];
    Widget labelledReset(
      ({
        Key? key,
        String title,
        String message,
        IconData icon,
        Future<void> Function() reset,
      })
      action,
    ) => TextButton.icon(
      key: action.key,
      onPressed: () =>
          _confirmReset(action.title, action.message, action.reset),
      icon: Icon(action.icon),
      label: Text(action.title),
    );
    const autoCollapseKey = Key('desktopDockAutoCollapseSwitch');
    final autoCollapseEnabled = settings.desktopDockAutoCollapseEnabled;
    final autoCollapse = compact
        ? MergeSemantics(
            child: InkWell(
              // The switch supplies the toggle semantics for the whole tile.
              excludeFromSemantics: true,
              canRequestFocus: false,
              onTap: () => settings.setDesktopDockAutoCollapseEnabled(
                !autoCollapseEnabled,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    messageText(
                      l.pcLayoutAutoFoldTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Switch.adaptive(
                        key: autoCollapseKey,
                        value: autoCollapseEnabled,
                        onChanged: settings.setDesktopDockAutoCollapseEnabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : SwitchListTile.adaptive(
            key: autoCollapseKey,
            title: Text(l.pcLayoutAutoFoldTitle),
            subtitle: Text(
              l.pcLayoutAutoFoldHelp,
              style: const TextStyle(fontSize: 12),
            ),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            value: autoCollapseEnabled,
            onChanged: settings.setDesktopDockAutoCollapseEnabled,
          );
    final instructions = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.pcWorkspaceLayoutIntroHint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(l.pcLayoutInstruction, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
    final help = SingleChildScrollView(
      child: Column(
        children: [
          if (!compact) instructions,
          autoCollapse,
          if (compact) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.pcLayoutAutoFoldHelp,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            instructions,
          ],
        ],
      ),
    );
    final preview = PcWorkspaceLayoutPreview(
      labelOf: (panel) => _panelLabel(l, panel),
      fitRequests: _fitRequests,
    );
    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(l.pcWorkspaceLayoutScreenTitle)),
      // ボタンの段は本文ではなく画面の下の段（bottomNavigationBar）に置く。
      // 本文の列の最後に置いていた頃は、前の画面（ワークスペースの設定）で
      // 出た知らせが付いてきて段の上に重なり、出ている間押せなかった。
      // Scaffoldは知らせをこの段の上へ浮かべる。
      //
      // 配置の見本の「全体を表示」も、見本の右下（段のすぐ上）に重ねて
      // いた頃は付いてきた知らせに隠れた。浮かぶボタンの場所に置くと、
      // Scaffoldは知らせをボタンの上へ浮かべる（置く場所は見本の右下の
      // ままで、見本の上に重なる）。
      floatingActionButton: IconButton.filledTonal(
        key: const Key('pcWorkspaceFitPreview'),
        tooltip: l.pcViewFit,
        onPressed: _fitRequests.request,
        icon: const Icon(Icons.fit_screen),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            heightFactor: 1,
            child: compact
                ? FirstThatFits(
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final action in resetActions)
                            labelledReset(action),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: [
                          for (final action in resetActions)
                            IconButton(
                              key: action.key,
                              tooltip: action.title,
                              onPressed: () => _confirmReset(
                                action.title,
                                action.message,
                                action.reset,
                              ),
                              icon: Icon(action.icon),
                            ),
                        ],
                      ),
                    ],
                  )
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      for (final action in resetActions) labelledReset(action),
                    ],
                  ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (compact && constraints.maxWidth >= 540) {
              return Row(
                children: [
                  Expanded(flex: 2, child: help),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 3, child: preview),
                ],
              );
            }
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight / (compact ? 3 : 2),
                  ),
                  child: help,
                ),
                Expanded(child: preview),
              ],
            );
          },
        ),
      ),
    );
  }
}
