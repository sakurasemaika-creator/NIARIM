/// セーブツリー：手動保存履歴管理モデル
class SaveNode {
  final String id;
  final String projectId;
  final DateTime savedAt;
  final String? comment;
  final String? thumbnailPath;
  final String? parentId; // ツリー方式の親ノード（nullはルート）
  final int slotIndex; // スロット方式の場合のスロット番号（-1=ツリー方式）

  const SaveNode({
    required this.id,
    required this.projectId,
    required this.savedAt,
    this.comment,
    this.thumbnailPath,
    this.parentId,
    this.slotIndex = -1,
  });

  bool get isTreeMode => slotIndex < 0;

  /// 保存の一覧（SaveTree/index.json）へ書く形。作品のIDとサムネイルの場所は
  /// 置き場所のフォルダから決めるので書かない。
  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    if (comment != null) 'comment': comment,
    if (parentId != null) 'parentId': parentId,
    'slotIndex': slotIndex,
  };

  /// [toJson]の形から読む。形の合わない項目はnull（読み飛ばす）。
  static SaveNode? fromJson(
    Object? json, {
    required String projectId,
    String? thumbnailPath,
  }) {
    if (json is! Map) return null;
    final id = json['id'];
    final savedAt = json['savedAt'];
    if (id is! String || id.isEmpty || savedAt is! String) return null;
    final at = DateTime.tryParse(savedAt);
    if (at == null) return null;
    final comment = json['comment'];
    final parentId = json['parentId'];
    final slot = json['slotIndex'];
    return SaveNode(
      id: id,
      projectId: projectId,
      savedAt: at,
      comment: comment is String ? comment : null,
      thumbnailPath: thumbnailPath,
      parentId: parentId is String ? parentId : null,
      slotIndex: slot is int ? slot : -1,
    );
  }
}
