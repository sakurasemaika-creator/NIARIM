import 'audio_clip.dart';
import 'camera_keyframe.dart';
import 'effect_filter_instance.dart';
import 'layer.dart';
import 'layer_group.dart';
import 'timeline_marker.dart';

class Scene {
  final String id;
  final int index;
  final List<Frame> frames;
  // ユーザーが変更したシーン名（仕様書05：シーン名変更ダイアログ）。
  // 未設定の場合はdisplayNameがindexから自動生成する。
  final String? name;
  // カメラのXY移動・拡大・回転キーフレーム（仕様書05）。シーンごとに管理する。
  final List<CameraKeyframe> cameraKeyframes;
  // 演出フィルター（仕様書18）。シーンごとに管理し、プレビュー再生・書き出し時のみ適用する非破壊編集。
  final List<EffectFilterInstance> effectFilters;
  // 音声トラックのクリップ（仕様書05）。シーンごとに管理する（音声はレイヤーを持たない）。
  final List<AudioClip> audioClips;
  // 画像・動画・音源タイムライン行のカスタム名（仕様書05：「素材種別ごとに
  // 複数行のタイムライン行を追加/削除できるようにする。行名はタップで
  // ユーザーがテキスト変更できる」）。リストの長さ＝行数（最低1）。
  // 要素がnullの行は既定表示（種別名＋行番号）を使う。
  final List<String?> imageRowNames;
  final List<String?> videoRowNames;
  final List<String?> audioRowNames;
  // 複数レイヤーをまとめて1つのキーフレームで動かすグループ
  // （パーツ単位アニメーションの拡張）。シーンごとに管理する。
  final List<LayerGroup> groups;
  // タイムスタンプ（特定フレームへのワンタップ移動＋コメント）。シーンが
  // 「範囲」を単位にするのに対し、こちらは「瞬間」を指すためのもので、
  // 同じシーンの範囲内に複数打てる。
  final List<TimelineMarker> markers;

  const Scene({
    required this.id,
    required this.index,
    this.frames = const [],
    this.name,
    this.cameraKeyframes = const [],
    this.effectFilters = const [],
    this.audioClips = const [],
    this.imageRowNames = const [],
    this.videoRowNames = const [],
    this.audioRowNames = const [],
    this.groups = const [],
    this.markers = const [],
  });

  String get displayName => name ?? 'Scene${index + 1}';

  Scene copyWith({
    String? id,
    int? index,
    List<Frame>? frames,
    Object? name = _sentinel,
    List<CameraKeyframe>? cameraKeyframes,
    List<EffectFilterInstance>? effectFilters,
    List<AudioClip>? audioClips,
    List<String?>? imageRowNames,
    List<String?>? videoRowNames,
    List<String?>? audioRowNames,
    List<LayerGroup>? groups,
    List<TimelineMarker>? markers,
  }) {
    return Scene(
      id: id ?? this.id,
      index: index ?? this.index,
      frames: frames ?? this.frames,
      name: name == _sentinel ? this.name : name as String?,
      cameraKeyframes: cameraKeyframes ?? this.cameraKeyframes,
      effectFilters: effectFilters ?? this.effectFilters,
      audioClips: audioClips ?? this.audioClips,
      imageRowNames: imageRowNames ?? this.imageRowNames,
      videoRowNames: videoRowNames ?? this.videoRowNames,
      audioRowNames: audioRowNames ?? this.audioRowNames,
      groups: groups ?? this.groups,
      markers: markers ?? this.markers,
    );
  }
}

const Object _sentinel = Object();

class Frame {
  final int index;
  final List<Layer> layers;
  /// 保持セル数（1=保持なし、2以上=このフレームをn枚分保持）
  final int hold;

  const Frame({
    required this.index,
    this.layers = const [],
    this.hold = 1,
  });

  Frame copyWith({
    int? index,
    List<Layer>? layers,
    int? hold,
  }) {
    return Frame(
      index: index ?? this.index,
      layers: layers ?? this.layers,
      hold: hold ?? this.hold,
    );
  }
}
