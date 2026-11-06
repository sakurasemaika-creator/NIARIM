import 'layer.dart';
import 'material_asset.dart' show MaterialType;

/// タイムラインの素材の列の種類（列の追加・削除・名前の単位）。素材の
/// ファイル種別（[MaterialType]）とは別で、テキストの列もある。
enum TimelineRowKind {
  image,
  video,
  audio,
  text;

  static TimelineRowKind fromMaterial(MaterialType type) => switch (type) {
    MaterialType.image => TimelineRowKind.image,
    MaterialType.video => TimelineRowKind.video,
    MaterialType.audio => TimelineRowKind.audio,
  };

  /// この列に置かれる素材のレイヤー種別（音源はレイヤーを持たないのでnull）。
  LayerType? get layerType => switch (this) {
    TimelineRowKind.image => LayerType.timelineImage,
    TimelineRowKind.video => LayerType.timelineVideo,
    TimelineRowKind.text => LayerType.timelineText,
    TimelineRowKind.audio => null,
  };
}
