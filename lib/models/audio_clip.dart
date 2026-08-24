/// タイムライン音声トラックのクリップ。
/// レイヤーではなくシーンに直接紐づく（音声は視覚的なピクセルを持たないため）。
class AudioClip {
  final String id;
  final String label;
  final String? materialId; // 参照している素材ID
  final int startFrame;
  final int lengthFrames;
  final double volume; // 0.0〜1.0
  final double fadeIn; // フェードイン秒数
  final double fadeOut; // フェードアウト秒数
  // 音声タイムラインの表示行番号（0始まり）。素材種別ごとに複数行の
  // タイムライン行を追加/削除できる。
  final int trackRow;

  const AudioClip({
    required this.id,
    required this.label,
    this.materialId,
    required this.startFrame,
    required this.lengthFrames,
    this.volume = 1.0,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.trackRow = 0,
  });

  AudioClip copyWith({
    String? label,
    Object? materialId = _sentinel,
    int? startFrame,
    int? lengthFrames,
    double? volume,
    double? fadeIn,
    double? fadeOut,
    int? trackRow,
  }) {
    return AudioClip(
      id: id,
      label: label ?? this.label,
      materialId: materialId == _sentinel ? this.materialId : materialId as String?,
      startFrame: startFrame ?? this.startFrame,
      lengthFrames: lengthFrames ?? this.lengthFrames,
      volume: volume ?? this.volume,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      trackRow: trackRow ?? this.trackRow,
    );
  }
}

const Object _sentinel = Object();
