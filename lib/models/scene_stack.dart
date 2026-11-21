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

/// フレームの範囲（[start]〜[end]、どちらも0始まりで端を含む）だけに使う
/// 重なり順。範囲の外はシーン全体の順番。
class StackRange {
  final int start;
  final int end;

  /// 前面から順に並べた単位のキー。
  final List<String> order;

  const StackRange({
    required this.start,
    required this.end,
    required this.order,
  });

  bool contains(int frameIndex) => frameIndex >= start && frameIndex <= end;

  StackRange copyWith({int? start, int? end, List<String>? order}) =>
      StackRange(
        start: start ?? this.start,
        end: end ?? this.end,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'order': order};

  static StackRange? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['start'];
    final end = json['end'];
    final order = json['order'];
    if (start is! int || end is! int || order is! List) return null;
    return StackRange(
      start: start < end ? start : end,
      end: start < end ? end : start,
      order: order.whereType<String>().toList(),
    );
  }
}

/// シーンの重なり順とフレーム（イラスト）のマスク。
///
/// [order]はシーン全体の重なり順（前面から。空なら既定の順番）、
/// [ranges]は「フレーム指定」の順番（開始フレームの昇順、重ならない）。
class SceneStack {
  final List<String> order;
  final List<StackRange> ranges;

  /// フレーム（イラスト）のマスク。タイムラインのプレビューと書き出しに
  /// だけ効かせる（キャンバスで描いている間は隠さない）。
  final LayerMask? frameMask;

  const SceneStack({
    this.order = const [],
    this.ranges = const [],
    this.frameMask,
  });

  bool get isEmpty => order.isEmpty && ranges.isEmpty && frameMask == null;

  SceneStack copyWith({
    List<String>? order,
    List<StackRange>? ranges,
    Object? frameMask = _sentinel,
  }) => SceneStack(
    order: order ?? this.order,
    ranges: ranges ?? this.ranges,
    frameMask: identical(frameMask, _sentinel)
        ? this.frameMask
        : frameMask as LayerMask?,
  );

  /// The range [frameIndex] is in, if any.
  StackRange? rangeAt(int frameIndex) =>
      ranges.where((r) => r.contains(frameIndex)).firstOrNull;

  /// The order chosen for [frameIndex]: its range's, else the scene's
  /// (either may be empty: then the default).
  List<String> chosenOrderAt(int frameIndex) =>
      rangeAt(frameIndex)?.order ?? order;

  Map<String, dynamic> toJson() => {
    if (order.isNotEmpty) 'order': order,
    if (ranges.isNotEmpty) 'ranges': ranges.map((r) => r.toJson()).toList(),
    if (frameMask != null) 'frameMask': frameMask!.toJson(),
  };

  static SceneStack fromJson(Object? json) {
    if (json is! Map) return const SceneStack();
    final ranges =
        (json['ranges'] as List<dynamic>? ?? const [])
            .map(StackRange.fromJson)
            .whereType<StackRange>()
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return SceneStack(
      order: (json['order'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      ranges: ranges.isNotEmpty
          ? ranges
          : _rangesFromChanges(json['changes'] as List<dynamic>? ?? const []),
      frameMask: LayerMask.fromJson(json['frameMask']),
    );
  }

  /// Saved data from before 「フレーム指定」 held 「このフレームから」
  /// changes, each lasting until the next: each becomes the range up to the
  /// frame before the next change (the last one to the end of the scene).
  static List<StackRange> _rangesFromChanges(List<dynamic> changes) {
    final parsed = <({int frame, List<String> order})>[
      for (final c in changes)
        if (c is Map && c['frameIndex'] is int && c['order'] is List)
          (
            frame: c['frameIndex'] as int,
            order: (c['order'] as List).whereType<String>().toList(),
          ),
    ]..sort((a, b) => a.frame.compareTo(b.frame));
    return [
      for (var i = 0; i < parsed.length; i++)
        // An empty change went back to the scene's order: no range.
        if (parsed[i].order.isNotEmpty)
          StackRange(
            start: parsed[i].frame,
            end: i + 1 < parsed.length
                ? parsed[i + 1].frame - 1
                : kStackRangeOpenEnd,
            order: parsed[i].order,
          ),
    ];
  }
}

/// The end of a range converted from a 「このフレームから」 change with no
/// change after it (to the end of the scene, however long it gets).
const int kStackRangeOpenEnd = 1 << 20;

const Object _sentinel = Object();
