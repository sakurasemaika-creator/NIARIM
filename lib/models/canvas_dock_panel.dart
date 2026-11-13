/// PC/DeXモードでキャンバス画面に常設ドッキング表示できるパネルの種類。
/// どれを既定でドッキング表示しておくかは`SettingsService`に保存され、
/// ワークスペースプリセット（`WorkspacePreset`）にも含めて保存・復元
/// できる。スマホ表示ではこの一覧は使わない（誤タップ防止のため常に
/// 全パネル非表示スタートのまま）。
enum CanvasDockPanel {
  brush,
  colorPicker,
  layer,
  tone,
  stamp,
  penSubTool,
  onionSkin,
  ruler,
  filter,
  quickTool,
  colorAdjust,
  canvasPreview,
}

/// Legacy per-material dock IDs remain readable in existing saved
/// workspaces. Their UI now lives inside the one tabbed pen-subtool window.
bool isLegacyMaterialDock(CanvasDockPanel value) =>
    value == CanvasDockPanel.brush ||
    value == CanvasDockPanel.tone ||
    value == CanvasDockPanel.stamp;

CanvasDockPanel canonicalCanvasDock(CanvasDockPanel value) =>
    isLegacyMaterialDock(value) ? CanvasDockPanel.penSubTool : value;

List<CanvasDockPanel> uniqueCanonicalCanvasDocks(
  Iterable<CanvasDockPanel> panels,
) {
  final seen = <CanvasDockPanel>{};
  return [
    for (final panel in panels)
      if (seen.add(canonicalCanvasDock(panel))) canonicalCanvasDock(panel),
  ];
}
