/// PC/DeXモードでキャンバス画面に常設ドッキング表示できるパネルの種類
/// （仕様書08：ワークスペース設定＞PC版で既定で開くパネル）。
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
