/// キャンバス（書き出し）の1辺の範囲。新規プロジェクトのカスタムサイズと
/// 保存したサイズで同じ範囲を使う（長辺はFull HD相当まで）。
const int kMinCanvasEdge = 64;
const int kMaxCanvasEdge = 1920;

/// [value]をキャンバスの1辺の範囲に収める。
int clampCanvasEdge(int value) => value.clamp(kMinCanvasEdge, kMaxCanvasEdge);

/// ユーザーが保存したカスタムキャンバスサイズプリセット。
class CanvasSizePreset {
  final String id;
  final String name;
  final int width;
  final int height;

  const CanvasSizePreset({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
  });

  CanvasSizePreset copyWith({String? name, int? width, int? height}) =>
      CanvasSizePreset(
        id: id,
        name: name ?? this.name,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'width': width,
    'height': height,
  };

  factory CanvasSizePreset.fromJson(Map<String, dynamic> json) =>
      CanvasSizePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
      );
}
