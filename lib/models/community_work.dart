import 'dart:math';
import 'package:intl/intl.dart';

/// この画面には実際のログイン・ユーザー識別基盤（バックエンド未実装、
/// `29_動画投稿・ランキング機能仕様.md`4章のNIARIM User ID）が無いため、
/// 「投稿者のみタグをロックできる」という挙動をUI上で確認するための
/// 仮の自分自身の投稿者IDとして扱う。実際のログイン機能実装後は、
/// 認証済みのNIARIM User IDと`work.authorId`を比較する形に置き換える。
const String kDummySelfAuthorId = 'author_01';

/// 作品広場画面で表示する投稿作品1件分のデータ。
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

  /// 投稿元NIARIMプロジェクト由来の制作情報。
  ///
  /// 作品広場を単なるYouTube動画一覧にせず、NIARIM固有の「どう作られた
  /// 作品か」を横画面詳細・縦画面の両方で同じように表示するために保持する。
  /// 本番APIで値がまだ無い古い作品は0/nullになり、UI側では項目自体を隠す。
  final int projectFps;
  final int projectFrameCount;
  final int projectWorkSeconds;
  final DateTime? projectCreatedAt;
  final int projectCanvasWidth;
  final int projectCanvasHeight;

  // サムネイル画像の代わりに表示するプレースホルダーの配色を選ぶための
  // インデックス（実際のサムネイル取得はバックエンド実装後に対応）。
  final int thumbnailColorIndex;
  // ユーザーが自由に追加・削除できるタグ（誰でも編集可能）。
  final List<String> tags;
  // tagsのうち、投稿者がロックして他ユーザーが削除できないようにした
  // タグの集合（tagsの部分集合）。
  final Set<String> lockedTags;
  // 作品広場独自の公開/非公開設定。
  final bool isNiarimPublished;
  // ショート動画（縦長）かどうか。
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
    this.projectFps = 0,
    this.projectFrameCount = 0,
    this.projectWorkSeconds = 0,
    this.projectCreatedAt,
    this.projectCanvasWidth = 0,
    this.projectCanvasHeight = 0,
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
    int? projectFps,
    int? projectFrameCount,
    int? projectWorkSeconds,
    DateTime? projectCreatedAt,
    int? projectCanvasWidth,
    int? projectCanvasHeight,
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
      projectFps: projectFps ?? this.projectFps,
      projectFrameCount: projectFrameCount ?? this.projectFrameCount,
      projectWorkSeconds: projectWorkSeconds ?? this.projectWorkSeconds,
      projectCreatedAt: projectCreatedAt ?? this.projectCreatedAt,
      projectCanvasWidth: projectCanvasWidth ?? this.projectCanvasWidth,
      projectCanvasHeight: projectCanvasHeight ?? this.projectCanvasHeight,
      tags: tags ?? this.tags,
      lockedTags: lockedTags ?? this.lockedTags,
      isNiarimPublished: isNiarimPublished ?? this.isNiarimPublished,
      isShort: isShort ?? this.isShort,
    );
  }
}

/// 表示確認用のダミー作品一覧を生成する。
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
  final titleParts1 = [
    '夜明けの',
    '小さな',
    '静かな',
    '走れ',
    '約束の',
    '君だけの',
    '雨上がりの',
    '最後の',
  ];
  final titleParts2 = ['冒険', '手紙', '約束', '街', '夏休み', 'メロディ', '記憶', '交差点'];
  final tagPool = [
    'オリジナル',
    '手描き',
    'コマ撮り風',
    'ループ',
    'BGMあり',
    '実験的',
    '風景',
    'キャラクター',
  ];

  return List.generate(24, (i) {
    final author = authors[i % authors.length];
    final title =
        '${titleParts1[i % titleParts1.length]}${titleParts2[(i * 3) % titleParts2.length]}';
    final views = 50 + random.nextInt(200000);
    final tagCount = 2 + random.nextInt(2);
    final tags = <String>{};
    while (tags.length < tagCount) {
      tags.add(tagPool[random.nextInt(tagPool.length)]);
    }
    final tagList = tags.toList();
    final lockedTags = {tagList[random.nextInt(tagList.length)]};
    final isShort = random.nextDouble() < 0.35;
    final durationSeconds = isShort
        ? 3 + random.nextInt(58)
        : 15 + random.nextInt(105);
    final fps = [12, 24, 30][random.nextInt(3)];
    final postedAt = DateTime.now().subtract(
      Duration(days: random.nextInt(400), hours: random.nextInt(24)),
    );
    final projectCreatedAt = postedAt.subtract(
      Duration(days: 1 + random.nextInt(45), hours: random.nextInt(24)),
    );
    final projectWorkSeconds = 900 + random.nextInt(18 * 60 * 60);

    return CommunityWork(
      id: 'work_${i.toString().padLeft(3, '0')}',
      title: title,
      authorId: author.$1,
      authorName: author.$2,
      viewCount: views,
      likeCount: (views * (0.02 + random.nextDouble() * 0.08)).round(),
      bookmarkCount: 5 + random.nextInt(3000),
      postedAt: postedAt,
      durationSeconds: durationSeconds,
      thumbnailColorIndex: i % 6,
      projectFps: fps,
      projectFrameCount: fps * durationSeconds,
      projectWorkSeconds: projectWorkSeconds,
      projectCreatedAt: projectCreatedAt,
      projectCanvasWidth: isShort ? 1080 : 1920,
      projectCanvasHeight: isShort ? 1920 : 1080,
      tags: tagList,
      lockedTags: lockedTags,
      isShort: isShort,
    );
  });
}

/// 再生数・ブックマーク数等の統計を表示用に整形する。
String formatCompactCount(int value, String languageCode) {
  if (languageCode == 'ja') {
    return NumberFormat.decimalPattern('ja').format(value);
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}

/// 制作時間を作品広場用の短い表記へ整形する。
String formatProjectWorkTime(int totalSeconds) {
  if (totalSeconds <= 0) return '';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${max(1, minutes)}m';
}
