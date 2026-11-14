import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/canvas_dock_panel.dart';
import '../../services/settings_service.dart';
import 'widgets/pc_workspace_layout_preview.dart';

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
    final l = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final autoTitle = l.pcLayoutAutoFoldTitle;
    final autoHelp = l.pcLayoutAutoFoldHelp;
    final resetWorkspaceTitle = l.pcLayoutResetWorkspace;
    final instruction = l.pcLayoutInstruction;
    return Scaffold(
      appBar: AppBar(title: Text(l.pcWorkspaceLayoutScreenTitle)),
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
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await settings.resetDesktopDockOrderToHandedDefaults();
                },
                icon: const Icon(Icons.restart_alt),
                label: Text(l.pcWorkspaceLayoutResetOrderButton),
              ),
              TextButton.icon(
                key: const Key('resetDesktopWorkspaceLayout'),
                onPressed: settings.resetDesktopWorkspaceLayout,
                icon: const Icon(Icons.settings_backup_restore),
                label: Text(resetWorkspaceTitle),
              ),
              TextButton.icon(
                onPressed: () async {
                  await settings.setDesktopToolPanelWidth(280);
                  await settings.setDesktopPanelWidth(280);
                  for (final panel in CanvasDockPanel.values) {
                    await settings.setDesktopDockWidth(panel, 280);
                    await settings.setDesktopDockHeight(panel, 260);
                  }
                },
                icon: const Icon(Icons.aspect_ratio_outlined),
                label: Text(l.pcWorkspaceLayoutResetWidthButton),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        // 文字を大きくした端末では、説明とスイッチだけで縦が埋まり、配置の
        // 見本が押し出されて列がはみ出していた。説明とスイッチは高さの半分
        // までにし、収まらなければその中でスクロールする。
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight / 2,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.pcWorkspaceLayoutIntroHint,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              instruction,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile.adaptive(
                        key: const Key('desktopDockAutoCollapseSwitch'),
                        title: Text(autoTitle),
                        subtitle: Text(
                          autoHelp,
                          style: const TextStyle(fontSize: 12),
                        ),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        value: settings.desktopDockAutoCollapseEnabled,
                        onChanged: (enabled) =>
                            settings.setDesktopDockAutoCollapseEnabled(enabled),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PcWorkspaceLayoutPreview(
                  labelOf: (panel) => _panelLabel(l, panel),
                  fitRequests: _fitRequests,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
