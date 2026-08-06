/// 名前を付けて保存するワークスペース設定（仕様書08・24）。
/// UIテーマとは独立して、左利きモード・PC/DeXモードの操作環境をまとめて保存する。
class WorkspacePreset {
  final String id;
  final String name;
  final bool isLeftHanded;
  final bool? forcePcMode; // null=自動

  const WorkspacePreset({
    required this.id,
    required this.name,
    required this.isLeftHanded,
    this.forcePcMode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isLeftHanded': isLeftHanded,
        'forcePcMode': forcePcMode,
      };

  factory WorkspacePreset.fromJson(Map<String, dynamic> json) => WorkspacePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        isLeftHanded: json['isLeftHanded'] as bool? ?? false,
        forcePcMode: json['forcePcMode'] as bool?,
      );
}
