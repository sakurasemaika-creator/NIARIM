import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/canvas_dock_panel.dart';
import '../../services/settings_service.dart';
import 'widgets/pc_workspace_layout_preview.dart';

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
    final l = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final locale = Localizations.localeOf(context).languageCode;
    final autoTitle = switch (locale) {
      'ja' => 'ツールウィンドウの自動収納',
      'ko' => '도구 창 자동 접기',
      'zh' => '自动折叠工具窗口',
      'es' => 'Contraer ventanas automáticamente',
      'fr' => 'Replier automatiquement les fenêtres',
      _ => 'Automatically fold tool windows',
    };
    final autoHelp = switch (locale) {
      'ja' => '高さを縮めても収まらないときだけ、最近使っていないウィンドウを一時収納します。操作中のものは維持し、空きが戻ると復元します。OFFでは列内スクロールのみ使用します。',
      'ko' => '공간이 부족하면 사용하지 않는 창을 임시로 접습니다. 활성 창은 유지되며 공간이 생기면 복원됩니다. 끄면 스크롤만 사용합니다.',
      'zh' => '空间不足时暂时折叠不常用窗口，保留正在使用的窗口，空间恢复后自动展开。关闭后仅滚动。',
      'es' => 'Si no caben, se pliegan temporalmente las ventanas menos usadas. La activa permanece abierta y se restauran al liberar espacio. Desactívalo para usar solo desplazamiento.',
      'fr' => 'En cas de manque de place, les fenêtres peu utilisées se replient temporairement. La fenêtre active reste ouverte et les autres reviennent quand la place le permet. Désactivez pour ne garder que le défilement.',
      _ => 'When windows no longer fit after shrinking, the least recently used fold temporarily. The active window stays open; folded windows restore when space returns. Turn off to use scrolling only.',
    };
    final resetWorkspaceTitle = switch (locale) {
      'ja' => 'ワークスペースを初期化',
      'ko' => '작업 공간 초기화',
      'zh' => '重置工作区',
      'es' => 'Restablecer espacio de trabajo',
      'fr' => 'Réinitialiser l’espace de travail',
      _ => 'Reset workspace',
    };
    final instruction = switch (locale) {
      'ja' =>
        'プレビューのウィンドウ端をドラッグして幅・高さを変更し、左上のハンドルを長押しして移動・入れ替えできます。ピンチで拡大できます。',
      'ko' =>
        '미리보기의 가장자리를 드래그하여 크기를 바꾸고, 창 손잡이를 길게 눌러 이동할 수 있습니다. 확대하려면 핀치하세요.',
      'zh' => '拖动预览窗口边缘调整大小，长按窗口手柄并拖动以移动或交换位置。双指缩放可放大预览。',
      'es' => 'Arrastra los bordes para cambiar el tamaño y mantén pulsado el asa de cada ventana para moverla. Pellizca para ampliar.',
      'fr' => 'Faites glisser les bords pour redimensionner les fenêtres et maintenez leur poignée pour les déplacer. Pincez pour zoomer.',
      _ => 'Drag window edges to resize. Long-press and drag a window grip to reorder or move it between sides. Pinch to zoom.',
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.pcWorkspaceLayoutScreenTitle)),
      body: SafeArea(
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              subtitle: Text(autoHelp, style: const TextStyle(fontSize: 12)),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              value: settings.desktopDockAutoCollapseEnabled,
              onChanged: (enabled) =>
                  settings.setDesktopDockAutoCollapseEnabled(enabled),
            ),
            Expanded(
              child: PcWorkspaceLayoutPreview(
                labelOf: (panel) => _panelLabel(l, panel),
              ),
            ),
            Padding(
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
          ],
        ),
      ),
    );
  }
}
