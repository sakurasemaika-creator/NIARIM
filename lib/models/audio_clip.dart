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
  /// 元素材内で使用を開始するフレーム。分割・範囲カット後も素材位置を保持する。
  final int sourceStartFrame;

  /// The fraction of a source frame the sound starts after
  /// [sourceStartFrame] (0 ≤ f < 1), kept when a clip played at a speed
  /// other than 1× is split.
  final double sourceStartFraction;

  /// The playback speed (1.0 = normal). The pitch is kept.
  final double playbackRate;
  // 音声タイムラインの表示行番号（0始まり）。素材種別ごとに複数行の
  // タイムライン行を追加/削除できる。
  final int trackRow;

  /// True when this audio clip belongs to the dedicated speech track.
  final bool isReadAloud;

  const AudioClip({
    required this.id,
    required this.label,
    this.materialId,
    required this.startFrame,
    required this.lengthFrames,
    this.volume = 1.0,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.sourceStartFrame = 0,
    this.sourceStartFraction = 0,
    this.playbackRate = 1.0,
    this.trackRow = 0,
    this.isReadAloud = false,
  });

  AudioClip copyWith({
    String? label,
    Object? materialId = _sentinel,
    int? startFrame,
    int? lengthFrames,
    double? volume,
    double? fadeIn,
    double? fadeOut,
    int? sourceStartFrame,
    double? sourceStartFraction,
    double? playbackRate,
    int? trackRow,
    bool? isReadAloud,
  }) {
    return AudioClip(
      id: id,
      label: label ?? this.label,
      materialId: materialId == _sentinel
          ? this.materialId
          : materialId as String?,
      startFrame: startFrame ?? this.startFrame,
      lengthFrames: lengthFrames ?? this.lengthFrames,
      volume: volume ?? this.volume,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      sourceStartFrame: sourceStartFrame ?? this.sourceStartFrame,
      sourceStartFraction: sourceStartFraction ?? this.sourceStartFraction,
      playbackRate: playbackRate ?? this.playbackRate,
      trackRow: trackRow ?? this.trackRow,
      isReadAloud: isReadAloud ?? this.isReadAloud,
    );
  }
}

const Object _sentinel = Object();
