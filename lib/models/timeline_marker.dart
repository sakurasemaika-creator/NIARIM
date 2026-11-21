/// タイムライン上の特定フレームにコメントを付けて、ワンタップでそこへ
/// 移動できるマーカー（タイムスタンプ）。シーン（開始〜終了フレームの
/// 範囲を単位に操作する）とは役割が異なり、こちらは「その一瞬」を指す
/// ための機能。同じシーンの範囲内に複数のタイムスタンプを打てるため、
/// 「0〜300フレームは雨のシーン」といったシーン単位の管理と、
/// 「120フレーム目に音声が入る」「180フレーム目は口パク『あ』」といった
/// フレーム単位のメモを両立できる。
class TimelineMarker {
  final String id;
  final int frameIndex;
  final String comment;
  final int? color;

  const TimelineMarker({
    required this.id,
    required this.frameIndex,
    this.comment = '',
    this.color,
  });

  TimelineMarker copyWith({int? frameIndex, String? comment, int? color}) {
    return TimelineMarker(
      id: id,
      frameIndex: frameIndex ?? this.frameIndex,
      comment: comment ?? this.comment,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'frameIndex': frameIndex,
    'comment': comment,
    if (color != null) 'color': color,
  };

  factory TimelineMarker.fromJson(Map<String, dynamic> j) => TimelineMarker(
    id: j['id'] as String,
    frameIndex: j['frameIndex'] as int,
    comment: j['comment'] as String? ?? '',
    color: j['color'] as int?,
  );
}
