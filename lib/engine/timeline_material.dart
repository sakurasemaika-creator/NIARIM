import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextAlign;

import '../models/layer.dart';
import '../models/layer_keyframe.dart';
import '../models/text_object.dart';
import 'layer_keyframe_engine.dart';
import 'text_render.dart';

/// A new timeline text: white letters with a dark outline, centred, about
/// an eighth of the canvas's shorter side tall (a title that reads over
/// any picture).
TextObject newTimelineText({
  required String id,
  required String text,
  required int canvasWidth,
  required int canvasHeight,
}) {
  final shortSide = math.min(canvasWidth, canvasHeight);
  final size = (shortSide * 0.12).clamp(12.0, 400.0).roundToDouble();
  return TextObject(
    id: id,
    text: text,
    fontSize: size,
    color: const ui.Color(0xFFFFFFFF),
    align: TextAlign.center,
    outline: TextOutline(
      enabled: true,
      color: const ui.Color(0xFF000000),
      width: math.max(2.0, (size * 0.06).roundToDouble()),
    ),
  );
}

/// [text] drawn with its block centred on the canvas: a timeline text is
/// moved, scaled and turned by its keyframes, which turn about the canvas
/// centre, so it turns about its own middle.
Future<Uint8List?> rasterizeTimelineText(
  TextObject text,
  int canvasWidth,
  int canvasHeight, {
  bool pixelMode = false,
}) => rasterizeTextObject(
  text,
  canvasWidth,
  canvasHeight,
  pixelMode: pixelMode,
  center: ui.Offset(canvasWidth / 2, canvasHeight / 2),
);

/// The name a timeline text shows on its row: its first line, shortened.
String timelineTextName(String text, String fallback) {
  final firstLine = text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return fallback;
  final runes = firstLine.runes.toList();
  return runes.length <= 16
      ? firstLine
      : '${String.fromCharCodes(runes.take(16))}…';
}

/// The scene frame a timeline material first shows at.
int materialFirstFrame(Layer layer) => math.max(0, (layer.rangeStart ?? 1) - 1);

final LayerKeyframeEngine _engine = LayerKeyframeEngine();

/// Where the material is at [frameIndex] (its one keyframe, or the values
/// between its keyframes).
LayerKeyframe materialTransformAt(Layer layer, int frameIndex) =>
    layer.keyframes.isEmpty
    ? LayerKeyframe(frameIndex: materialFirstFrame(layer))
    : _engine.valueAt(layer.keyframes, frameIndex);

/// The keyframe at exactly [frameIndex], if any.
LayerKeyframe? materialKeyframeAt(Layer layer, int frameIndex) =>
    layer.keyframes.where((k) => k.frameIndex == frameIndex).firstOrNull;

List<LayerKeyframe> _sorted(Iterable<LayerKeyframe> keyframes) =>
    keyframes.toList()..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));

/// [layer]'s keyframes after [change] to its position at [frameIndex].
///
/// With one keyframe or none the material does not move, and the change
/// applies to the whole of it (the one keyframe changes where it is). With
/// two or more it moves, and the change is recorded at [frameIndex] (a
/// keyframe is made there when there is none), as in animation software.
List<LayerKeyframe> editMaterialTransform(
  Layer layer,
  int frameIndex,
  LayerKeyframe Function(LayerKeyframe current) change,
) {
  final keyframes = layer.keyframes;
  if (keyframes.length <= 1) {
    final base = keyframes.isEmpty
        ? LayerKeyframe(frameIndex: materialFirstFrame(layer))
        : keyframes.single;
    return [change(base).copyWith(frameIndex: base.frameIndex)];
  }
  final existing = materialKeyframeAt(layer, frameIndex);
  final base = (existing ?? _engine.valueAt(keyframes, frameIndex)).copyWith(
    frameIndex: frameIndex,
    easing: existing?.easing ?? _easingBefore(keyframes, frameIndex),
  );
  final updated = change(base).copyWith(frameIndex: frameIndex);
  return _sorted([
    for (final k in keyframes)
      if (k.frameIndex != frameIndex) k,
    updated,
  ]);
}

/// A keyframe made between two others carries on the way the one before it
/// eases into the next.
LayerKeyframeEasing _easingBefore(List<LayerKeyframe> keyframes, int frame) {
  LayerKeyframe? before;
  for (final k in keyframes) {
    if (k.frameIndex < frame &&
        (before == null || k.frameIndex > before.frameIndex)) {
      before = k;
    }
  }
  return before?.easing ?? LayerKeyframeEasing.linear;
}

/// [layer]'s keyframes with one added at [frameIndex] holding where the
/// material now is there. A material without keyframes first gets one at
/// its first frame, so it starts moving from there.
List<LayerKeyframe> addMaterialKeyframe(Layer layer, int frameIndex) {
  if (materialKeyframeAt(layer, frameIndex) != null) return layer.keyframes;
  final first = materialFirstFrame(layer);
  final keyframes = layer.keyframes.isEmpty
      ? [LayerKeyframe(frameIndex: first)]
      : layer.keyframes;
  if (keyframes.any((k) => k.frameIndex == frameIndex)) return keyframes;
  final current = _engine
      .valueAt(keyframes, frameIndex)
      .copyWith(
        frameIndex: frameIndex,
        easing: _easingBefore(keyframes, frameIndex),
      );
  return _sorted([...keyframes, current]);
}

/// [layer]'s keyframes without the one at [frameIndex].
List<LayerKeyframe> removeMaterialKeyframe(Layer layer, int frameIndex) => [
  for (final k in layer.keyframes)
    if (k.frameIndex != frameIndex) k,
];
