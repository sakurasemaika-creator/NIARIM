/// フォロー通知1件（Task#134継続：「フォローされたら通知が来るように
/// してほしい」という要望を受けた実装）。
///
/// バックエンド未実装のため、現段階ではアプリ内通知（in-app notification）
/// としてのみ実装している。真のプッシュ通知（アプリを閉じていても、他
/// ユーザーの操作をトリガーに届く）にはFirebase Cloud Messaging等の導入
/// と、そもそも他ユーザーの操作を検知できるサーバー側の実装（16章）が
/// 必要で、現状のNIARIMには両方とも存在しない。詳細は
/// `29_動画投稿・ランキング機能仕様.md` 21.3節・22.6節を参照。
class CommunityFollowNotification {
  final String id;
  final String followerId;
  final String followerName;
  final DateTime followedAt;
  final bool isRead;

  const CommunityFollowNotification({
    required this.id,
    required this.followerId,
    required this.followerName,
    required this.followedAt,
    this.isRead = false,
  });

  CommunityFollowNotification copyWith({bool? isRead}) => CommunityFollowNotification(
        id: id,
        followerId: followerId,
        followerName: followerName,
        followedAt: followedAt,
        isRead: isRead ?? this.isRead,
      );
}
