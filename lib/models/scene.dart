import 'layer.dart';

class Scene {
  final String id;
  final int index;
  final List<Frame> frames;
  // ユーザーが変更したシーン名（仕様書05：シーン名変更ダイアログ）。
  // 未設定の場合はdisplayNameがindexから自動生成する。
  final String? name;

  const Scene({
    required this.id,
    required this.index,
    this.frames = const [],
    this.name,
  });

  String get displayName => name ?? 'Scene${index + 1}';

  Scene copyWith({
    String? id,
    int? index,
    List<Frame>? frames,
    Object? name = _sentinel,
  }) {
    return Scene(
      id: id ?? this.id,
      index: index ?? this.index,
      frames: frames ?? this.frames,
      name: name == _sentinel ? this.name : name as String?,
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
