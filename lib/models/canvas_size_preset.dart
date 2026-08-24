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
