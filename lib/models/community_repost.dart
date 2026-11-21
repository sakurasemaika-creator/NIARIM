/// リポスト（他ユーザーの作品を自分をフォローしているユーザーへ広める
/// 再共有）の記録。X（旧Twitter）の「リポスト」と同じ考え方：ある作品を
/// リポストすると、フォロー中の作者タブでは元の投稿者をフォローしていない
/// 場合でも、リポストした作者をフォローしていればその作品が新着順の
/// 一覧に混ざって表示される（`CommunityService.favoriteAuthorFeed`）。
///
/// バックエンド（`29_動画投稿・ランキング機能仕様.md`）は未実装のため、
/// ブックマーク・お気に入り作者と同じくアプリ内の一時状態のみを保持する。
class CommunityRepost {
  final String workId;
  final String reposterId;
  final String reposterName;
  final DateTime repostedAt;

  const CommunityRepost({
    required this.workId,
    required this.reposterId,
    required this.reposterName,
    required this.repostedAt,
  });
}
