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
}
