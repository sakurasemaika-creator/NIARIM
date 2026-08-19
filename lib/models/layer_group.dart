import 'layer_keyframe.dart';

/// 複数レイヤーをまとめて1つのキーフレームストリームで動かすためのグループ
/// （パーツ単位アニメーションの拡張）。例えば「腕」が肌・袖の2枚の自動塗り
/// パーツで構成されている場合、この2枚をグループ化して1回のキーフレーム
/// 操作でまとめて動かせるようにする。グループの変形は各メンバーレイヤー
/// 自身のキーフレーム（設定されていれば）に重ねて適用される
/// （グループ＝全体の動き、レイヤー個別＝その上への微調整、という関係）。
class LayerGroup {
  final String id;
  final String name;
  final List<String> memberLayerIds;
  final List<LayerKeyframe> keyframes;

  const LayerGroup({
    required this.id,
    required this.name,
    this.memberLayerIds = const [],
    this.keyframes = const [],
  });

  LayerGroup copyWith({
    String? name,
    List<String>? memberLayerIds,
    List<LayerKeyframe>? keyframes,
  }) {
    return LayerGroup(
      id: id,
      name: name ?? this.name,
      memberLayerIds: memberLayerIds ?? this.memberLayerIds,
      keyframes: keyframes ?? this.keyframes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberLayerIds': memberLayerIds,
        'keyframes': keyframes.map((k) => k.toJson()).toList(),
      };

  factory LayerGroup.fromJson(Map<String, dynamic> j) => LayerGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        memberLayerIds: (j['memberLayerIds'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        keyframes: (j['keyframes'] as List<dynamic>? ?? const [])
            .map((k) => LayerKeyframe.fromJson(k as Map<String, dynamic>))
            .toList(),
      );
}
