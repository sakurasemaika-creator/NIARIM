import 'layer_mask.dart';

/// 重なり順の単位：フレーム（イラスト）。
const String kStackFrame = 'frame';

/// 重なり順の単位：素材トラックの列（`text:0`・`image:1`・`video:0`…）。
String stackTrackKey(StackTrackKind kind, int row) => '${kind.name}:$row';

/// 重なり順に並ぶ素材トラックの種類。
enum StackTrackKind { text, image, video }

/// [key]が素材トラックの列なら種類と列番号、フレーム（イラスト）や
/// 読めないキーならnull。
({StackTrackKind kind, int row})? parseStackTrackKey(String key) {
  final colon = key.indexOf(':');
  if (colon <= 0) return null;
  final kind = StackTrackKind.values
      .where((k) => k.name == key.substring(0, colon))
      .firstOrNull;
  final row = int.tryParse(key.substring(colon + 1));
  if (kind == null || row == null || row < 0) return null;
  return (kind: kind, row: row);
}

/// あるフレームから先の重なり順（次の変更まで続く）。
class StackChange {
  final int frameIndex;

  /// 前面から順に並べた単位のキー。
  final List<String> order;

  const StackChange({required this.frameIndex, required this.order});

  Map<String, dynamic> toJson() => {'frameIndex': frameIndex, 'order': order};

  static StackChange? fromJson(Object? json) {
    if (json is! Map) return null;
    final frame = json['frameIndex'];
    final order = json['order'];
    if (frame is! int || order is! List) return null;
    return StackChange(
      frameIndex: frame,
      order: order.whereType<String>().toList(),
    );
  }
}

/// シーンの重なり順とフレーム（イラスト）のマスク。
///
/// [order]はシーン全体の重なり順（前面から。空なら既定の順番）、
/// [changes]は「このフレームから」の変更（フレーム番号の昇順）。
class SceneStack {
  final List<String> order;
  final List<StackChange> changes;

  /// フレーム（イラスト）のマスク。タイムラインのプレビューと書き出しに
  /// だけ効かせる（キャンバスで描いている間は隠さない）。
  final LayerMask? frameMask;

  const SceneStack({
    this.order = const [],
    this.changes = const [],
    this.frameMask,
  });

  bool get isEmpty => order.isEmpty && changes.isEmpty && frameMask == null;

  SceneStack copyWith({
    List<String>? order,
    List<StackChange>? changes,
    Object? frameMask = _sentinel,
  }) => SceneStack(
    order: order ?? this.order,
    changes: changes ?? this.changes,
    frameMask: identical(frameMask, _sentinel)
        ? this.frameMask
        : frameMask as LayerMask?,
  );

  /// The order chosen for [frameIndex]: the last change at or before it,
  /// else the scene's order (either may be empty: then the default).
  List<String> chosenOrderAt(int frameIndex) {
    List<String>? chosen;
    var at = -1;
    for (final change in changes) {
      if (change.frameIndex <= frameIndex && change.frameIndex > at) {
        chosen = change.order;
        at = change.frameIndex;
      }
    }
    return chosen ?? order;
  }

  /// The change that starts exactly at [frameIndex], if any.
  StackChange? changeAt(int frameIndex) =>
      changes.where((c) => c.frameIndex == frameIndex).firstOrNull;

  Map<String, dynamic> toJson() => {
    if (order.isNotEmpty) 'order': order,
    if (changes.isNotEmpty) 'changes': changes.map((c) => c.toJson()).toList(),
    if (frameMask != null) 'frameMask': frameMask!.toJson(),
  };

  static SceneStack fromJson(Object? json) {
    if (json is! Map) return const SceneStack();
    final changes =
        (json['changes'] as List<dynamic>? ?? const [])
            .map(StackChange.fromJson)
            .whereType<StackChange>()
            .toList()
          ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    return SceneStack(
      order: (json['order'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      changes: changes,
      frameMask: LayerMask.fromJson(json['frameMask']),
    );
  }
}

const Object _sentinel = Object();
