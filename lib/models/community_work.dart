import 'dart:math';

/// みんなの作品画面で表示する投稿作品1件分のデータ。
/// バックエンド（29_動画投稿・ランキング機能仕様.md）が未実装のため、
/// 現段階ではUI・デザイン確認用のダミーデータのみを保持するモデル。
class CommunityWork {
  final String id;
  final String title;
  final String authorId;
  final String authorName;
  final int viewCount;
  final int likeCount;
  final int bookmarkCount;
  final DateTime postedAt;
  final int durationSeconds;
  // サムネイル画像の代わりに表示するプレースホルダーの配色を選ぶための
  // インデックス（実際のサムネイル取得はバックエンド実装後に対応）。
  final int thumbnailColorIndex;

  const CommunityWork({
    required this.id,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.viewCount,
    required this.likeCount,
    required this.bookmarkCount,
    required this.postedAt,
    required this.durationSeconds,
    required this.thumbnailColorIndex,
  });
}

/// 表示確認用のダミー作品一覧を生成する（バックエンド未実装のため）。
/// 同じ内容を毎回返せるよう固定シードの乱数を使う。
List<CommunityWork> buildDummyCommunityWorks() {
  final random = Random(42);
  final authors = [
    ('author_01', 'あにめ工房ミラ'),
    ('author_02', 'sakura_draws'),
    ('author_03', 'ペン先ラボ'),
    ('author_04', 'コマ撮り部'),
    ('author_05', 'inkdrop'),
    ('author_06', 'よあけスタジオ'),
  ];
  final titleParts1 = ['夜明けの', '小さな', '静かな', '走れ', '約束の', '君だけの', '雨上がりの', '最後の'];
  final titleParts2 = ['冒険', '手紙', '約束', '街', '夏休み', 'メロディ', '記憶', '交差点'];

  return List.generate(24, (i) {
    final author = authors[i % authors.length];
    final title = '${titleParts1[i % titleParts1.length]}${titleParts2[(i * 3) % titleParts2.length]}';
    final views = 50 + random.nextInt(200000);
    return CommunityWork(
      id: 'work_${i.toString().padLeft(3, '0')}',
      title: title,
      authorId: author.$1,
      authorName: author.$2,
      viewCount: views,
      likeCount: (views * (0.02 + random.nextDouble() * 0.08)).round(),
      bookmarkCount: 5 + random.nextInt(3000),
      postedAt: DateTime.now().subtract(Duration(days: random.nextInt(400), hours: random.nextInt(24))),
      durationSeconds: 15 + random.nextInt(105),
      thumbnailColorIndex: i % 6,
    );
  });
}

/// 数値を「1.2K」「3.4M」のような簡略表記へ変換する（言語非依存の
/// 汎用表記のため、この画面のダミー統計表示に限りロケール別翻訳は行わない）。
String formatCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}
