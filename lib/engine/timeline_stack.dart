import '../models/layer.dart';
import '../models/layer_mask.dart';
import '../models/scene.dart';
import '../models/scene_stack.dart';

/// Whether [type] is a timeline material placed on a track row (text, image
/// or video), stacked by the scene's 重なり順 rather than by the layer list.
bool isTimelineClipType(LayerType type) =>
    type == LayerType.timelineText ||
    type == LayerType.timelineImage ||
    type == LayerType.timelineVideo;

/// The track a timeline material belongs to, as a 重なり順 key; null for
/// the frame's own drawing layers.
String? stackKeyOf(Layer layer) => switch (layer.type) {
  LayerType.timelineText => stackTrackKey(StackTrackKind.text, layer.trackRow),
  LayerType.timelineImage => stackTrackKey(
    StackTrackKind.image,
    layer.trackRow,
  ),
  LayerType.timelineVideo => stackTrackKey(
    StackTrackKind.video,
    layer.trackRow,
  ),
  _ => null,
};

/// Where a unit goes when nothing was chosen: text rows in front (text 1
/// frontmost), then the frame's drawing, then image rows, then video rows.
(int, int) _defaultRank(String key) {
  if (key == kStackFrame) return (1, 0);
  final track = parseStackTrackKey(key);
  if (track == null) return (4, 0);
  return switch (track.kind) {
    StackTrackKind.text => (0, track.row),
    StackTrackKind.image => (2, track.row),
    StackTrackKind.video => (3, track.row),
  };
}

int _compareDefault(String a, String b) {
  final (ka, ra) = _defaultRank(a);
  final (kb, rb) = _defaultRank(b);
  return ka != kb ? ka.compareTo(kb) : ra.compareTo(rb);
}

/// [keys] in the default order, front first.
List<String> defaultStackOrder(Iterable<String> keys) =>
    keys.toSet().toList()..sort(_compareDefault);

/// [chosen] made to cover exactly [present]: units no longer there are
/// left out, and units not yet placed go where the default order puts them
/// among the others (a new text row in front, a new video row at the back).
List<String> normalizeStackOrder(List<String> chosen, Set<String> present) {
  final result = <String>[];
  for (final key in chosen) {
    if (present.contains(key) && !result.contains(key)) result.add(key);
  }
  for (final key in defaultStackOrder(present)) {
    if (result.contains(key)) continue;
    var at = result.length;
    for (var i = 0; i < result.length; i++) {
      if (_compareDefault(result[i], key) > 0) {
        at = i;
        break;
      }
    }
    result.insert(at, key);
  }
  return result;
}

/// [order] with the [selected] units one place toward the front
/// ([forward]) or the back: each passes its nearest unselected neighbour, so
/// the selected units keep their own order and a run of them moves as one.
/// Units already at that end stay.
List<String> stepStackSelection(
  List<String> order,
  Set<String> selected, {
  required bool forward,
}) {
  final result = [...order];
  void swapIfBlocked(int i, int toward) {
    if (selected.contains(result[i]) && !selected.contains(result[toward])) {
      final key = result[i];
      result[i] = result[toward];
      result[toward] = key;
    }
  }

  if (forward) {
    for (var i = 1; i < result.length; i++) {
      swapIfBlocked(i, i - 1);
    }
  } else {
    for (var i = result.length - 2; i >= 0; i--) {
      swapIfBlocked(i, i + 1);
    }
  }
  return result;
}

/// [order] with the [selected] units moved to the very front ([front]) or
/// back, keeping their own order.
List<String> stackSelectionToEnd(
  List<String> order,
  Set<String> selected, {
  required bool front,
}) {
  final chosen = [
    for (final k in order)
      if (selected.contains(k)) k,
  ];
  final others = [
    for (final k in order)
      if (!selected.contains(k)) k,
  ];
  return front ? [...chosen, ...others] : [...others, ...chosen];
}

/// [order] after the unit at [from] is dragged to [to] (its place once it
/// has been taken out). Dragging one of several [selected] units brings the
/// others along: they gather around it in their own order.
List<String> dragStackSelection(
  List<String> order,
  Set<String> selected,
  int from,
  int to,
) {
  final dragged = order[from];
  final moved = [...order]
    ..removeAt(from)
    ..insert(to, dragged);
  final group = [
    for (final k in order)
      if (selected.contains(k)) k,
  ];
  if (!selected.contains(dragged) || group.length < 2) return moved;
  final rest = [
    for (final k in moved)
      if (k == dragged || !selected.contains(k)) k,
  ];
  final at = rest.indexOf(dragged);
  return rest..replaceRange(at, at + 1, group);
}

/// The 重なり順 at [frameIndex] of [scene] for the units in [present] (the
/// frame's drawing is always one of them), front first.
List<String> stackOrderAt(Scene scene, int frameIndex, Set<String> present) =>
    normalizeStackOrder(scene.stack.chosenOrderAt(frameIndex), {
      ...present,
      kStackFrame,
    });

/// Layers composited together and then masked as one (the frame's drawing
/// with the scene's frame mask).
class LayerMaskGroup {
  const LayerMaskGroup({required this.layerIds, required this.mask});

  final Set<String> layerIds;
  final LayerMask mask;
}

/// A frame's layers in the order to composite them (front first) and the
/// runs of them to mask together.
typedef StackedFrameLayers = ({
  List<Layer> layers,
  List<LayerMaskGroup> maskGroups,
});

/// Whether timeline material [layer] shows at [frameIndex] of the scene it
/// is placed in: its own frame range (the material's home frame lists it
/// even outside its range).
bool _showsAt(Layer layer, int frameIndex) {
  if (layer.rangeMode != LayerRangeMode.frameRange) return true;
  final start = (layer.rangeStart ?? 1) - 1;
  final end = (layer.rangeEnd ?? start + 1) - 1;
  return frameIndex >= start && frameIndex <= end;
}

/// [resolved] (frame [frameIndex]'s layers as `resolveFrameLayers` gives
/// them, the frame's own first) put in the scene's 重なり順: watermarks in
/// front of everything, then each unit in turn — the frame's drawing layers
/// in their own order, or a track row's materials showing at this frame.
///
/// With [applyFrameMask] the scene's frame mask comes back as a mask group
/// over the drawing layers (the timeline preview and the export); the canvas
/// leaves it out, so the drawing is never hidden while being drawn.
StackedFrameLayers stackFrameLayers(
  Scene scene,
  int frameIndex,
  List<Layer> resolved, {
  bool applyFrameMask = true,
}) {
  final watermarks = <Layer>[];
  final drawing = <Layer>[];
  final rows = <String, List<Layer>>{};
  var hasClips = false;
  for (final layer in resolved) {
    if (layer.type == LayerType.watermark) {
      watermarks.add(layer);
      continue;
    }
    final key = stackKeyOf(layer);
    if (key == null) {
      drawing.add(layer);
      continue;
    }
    hasClips = true;
    if (!_showsAt(layer, frameIndex)) continue;
    (rows[key] ??= []).add(layer);
  }
  final frameMask = applyFrameMask ? scene.stack.frameMask : null;
  final maskGroups = frameMask == null || drawing.isEmpty
      ? const <LayerMaskGroup>[]
      : [
          LayerMaskGroup(
            layerIds: {for (final l in drawing) l.id},
            mask: frameMask,
          ),
        ];
  if (!hasClips && watermarks.isEmpty) {
    return (layers: resolved, maskGroups: maskGroups);
  }
  final order = stackOrderAt(scene, frameIndex, rows.keys.toSet());
  return (
    layers: [
      ...watermarks,
      for (final key in order)
        if (key == kStackFrame) ...drawing else ...?rows[key],
    ],
    maskGroups: maskGroups,
  );
}
