import 'dart:math';

/// この画面には実際のログイン・ユーザー識別基盤（バックエンド未実装、
/// `29_動画投稿・ランキング機能仕様.md`4章のNIARIM User ID）が無いため、
/// 「投稿者のみタグをロックできる」という挙動をUI上で確認するための
/// 仮の自分自身の投稿者IDとして扱う。実際のログイン機能実装後は、
/// 認証済みのNIARIM User IDと`work.authorId`を比較する形に置き換える。
const String kDummySelfAuthorId = 'author_01';

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
  // ユーザーが自由に追加・削除できるタグ（誰でも編集可能）。
  final List<String> tags;
  // tagsのうち、投稿者がロックして他ユーザーが削除できないようにした
  // タグの集合（tagsの部分集合）。
  final Set<String> lockedTags;
  // NIARIM作品広場独自の公開/非公開設定（29_動画投稿・ランキング機能
  // 仕様.md 13章）。YouTube側の公開設定とは独立しており、trueのときのみ
  // 新着・ランキング・（自分以外から見た）投稿者別作品一覧に表示される。
  // 投稿者本人は非公開にした作品も自分の投稿者別作品一覧からは引き続き
  // 確認・再公開できる（CommunityService.worksByAuthorのincludeHidden参照）。
  final bool isNiarimPublished;
  // ショート動画（縦長・TikTok/Instagramリール/YouTubeショート風）かどうか。
  // 「横動画とショートをアプリ側で区別できるか」の調査の結論：YouTube Data
  // APIには「これはShortsである」という直接のフラグは存在しない（YouTube
  // 自身も動画の長さ・アスペクト比から内部判定している）。一方NIARIM側は
  // 投稿元となるプロジェクトのキャンバスサイズ（Project.drawingWidth/
  // drawingHeight）を投稿時点で把握しているため、縦長（高さ>幅）かどうかで
  // 確実に判定できる。バックエンド未実装の現段階ではこの判定結果を
  // ダミーデータ側で模擬している（buildDummyCommunityWorks参照）。
  final bool isShort;

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
    this.tags = const [],
    this.lockedTags = const {},
    this.isNiarimPublished = true,
    this.isShort = false,
  });

  CommunityWork copyWith({
    List<String>? tags,
    Set<String>? lockedTags,
    bool? isNiarimPublished,
    bool? isShort,
  }) {
    return CommunityWork(
      id: id,
      title: title,
      authorId: authorId,
      authorName: authorName,
      viewCount: viewCount,
      likeCount: likeCount,
      bookmarkCount: bookmarkCount,
      postedAt: postedAt,
      durationSeconds: durationSeconds,
      thumbnailColorIndex: thumbnailColorIndex,
      tags: tags ?? this.tags,
      lockedTags: lockedTags ?? this.lockedTags,
      isNiarimPublished: isNiarimPublished ?? this.isNiarimPublished,
      isShort: isShort ?? this.isShort,
    );
  }
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
  final tagPool = ['オリジナル', '手描き', 'コマ撮り風', 'ループ', 'BGMあり', '実験的', '風景', 'キャラクター'];

  return List.generate(24, (i) {
    final author = authors[i % authors.length];
    final title = '${titleParts1[i % titleParts1.length]}${titleParts2[(i * 3) % titleParts2.length]}';
    final views = 50 + random.nextInt(200000);
    // 各作品に2〜3個のタグを割り当て、そのうち1個をロック状態にする
    // （投稿者ロックの見た目上の挙動を確認できるようにするため）。
    final tagCount = 2 + random.nextInt(2);
    final tags = <String>{};
    while (tags.length < tagCount) {
      tags.add(tagPool[random.nextInt(tagPool.length)]);
    }
    final tagList = tags.toList();
    final lockedTags = {tagList[random.nextInt(tagList.length)]};
    // ショート動画かどうか（約35%をショートにして横動画と混在させ、
    // グリッド・ショートモード双方の見た目を確認しやすくする）。実際の
    // 判定基準はキャンバスの縦横比（isShortの説明コメント参照）だが、
    // ダミーデータではその判定結果のみを模擬する。
    final isShort = random.nextDouble() < 0.35;
    return CommunityWork(
      id: 'work_${i.toString().padLeft(3, '0')}',
      title: title,
      authorId: author.$1,
      authorName: author.$2,
      viewCount: views,
      likeCount: (views * (0.02 + random.nextDouble() * 0.08)).round(),
      bookmarkCount: 5 + random.nextInt(3000),
      postedAt: DateTime.now().subtract(Duration(days: random.nextInt(400), hours: random.nextInt(24))),
      // ショート動画は実際のYouTube Shorts同様、短尺（3〜60秒程度）に
      // 寄せる。横動画は従来どおりの幅を持たせる。
      durationSeconds: isShort ? 3 + random.nextInt(58) : 15 + random.nextInt(105),
      thumbnailColorIndex: i % 6,
      tags: tagList,
      lockedTags: lockedTags,
      isShort: isShort,
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
