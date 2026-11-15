/// ツール早替え機能の1エントリー。
/// [toolKey]はDrawingTool（lib/screens/canvas/canvas_screen.dart）のenum名
/// （DrawingTool.values.byNameで復元する）。
class QuickToolEntry {
  final String id;

  /// 足したときの名前（最初からあるものは日本語）。画面ではこれを出さず、
  /// 表示のたびに名前を作る（`quickToolDisplayLabel`）：消しゴム・スポイト・
  /// バケツは種類から今の言語で、ブラシは[brushId]のブラシの今の名前と
  /// [sizeOverride]の太さで（ブラシが無ければこの名前）。保存の形を変えない
  /// よう（前の版・引き継ぎで読めるよう）残している。
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'toolKey': toolKey,
    'brushId': brushId,
    'sizeOverride': sizeOverride,
  };

  factory QuickToolEntry.fromJson(Map<String, dynamic> json) => QuickToolEntry(
    id: json['id'] as String,
    label: json['label'] as String,
    toolKey: json['toolKey'] as String,
    brushId: json['brushId'] as String?,
    sizeOverride: (json['sizeOverride'] as num?)?.toDouble(),
  );
}
