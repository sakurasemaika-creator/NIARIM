/// ツール早替え機能の1エントリー（仕様書08）。
/// [toolKey]はDrawingTool（lib/screens/canvas/canvas_screen.dart）のenum名
/// （DrawingTool.values.byNameで復元する）。
class QuickToolEntry {
  final String id;
  final String label;
  final String toolKey;
  // toolKeyが'pen'の場合のみ使用
  final String? brushId;
  final double? sizeOverride;

  const QuickToolEntry({
    required this.id,
    required this.label,
    required this.toolKey,
    this.brushId,
    this.sizeOverride,
  });
}
