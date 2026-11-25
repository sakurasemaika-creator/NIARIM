import 'dart:math' as math;

import '../models/layer_keyframe.dart';

/// Playback speed rules shared by the timeline (editing, preview) and the
/// export. A speed is a factor: 1.0 is normal, 2.0 twice as fast, 0.5 half.

/// The range a speed can be typed in.
const double minPlaybackRate = 0.01;
const double maxPlaybackRate = 100;

/// The range of the speed slider. Speeds outside it can still be typed.
const double sliderMinPlaybackRate = 0.1;
const double sliderMaxPlaybackRate = 16;

/// Speeds offered as one-tap choices.
const List<double> quickPlaybackRates = [0.25, 0.5, 1, 2, 4, 8, 16, 100];

/// Whether [rate] is a speed a clip can have: finite and within
/// [minPlaybackRate, maxPlaybackRate].
bool isValidPlaybackRate(double rate) =>
    rate.isFinite && rate >= minPlaybackRate && rate <= maxPlaybackRate;

/// The slider position (0–1) of [rate]. The slider is logarithmic so the
/// low speeds get as much travel as the high ones.
double playbackRateToSlider(double rate) {
  final clamped = rate.clamp(sliderMinPlaybackRate, sliderMaxPlaybackRate);
  return math.log(clamped / sliderMinPlaybackRate) /
      math.log(sliderMaxPlaybackRate / sliderMinPlaybackRate);
}

/// The speed at slider position [position] (0–1), rounded to two decimals
/// so dragging lands on readable values.
double sliderToPlaybackRate(double position) {
  final p = position.clamp(0.0, 1.0);
  final rate =
      sliderMinPlaybackRate *
      math.pow(sliderMaxPlaybackRate / sliderMinPlaybackRate, p);
  return (rate * 100).round() / 100;
}

/// Parses a typed speed ("1.5", "2x", "0,5"). Returns null for anything
/// that is not a valid speed, so an incomplete entry is never applied.
double? parsePlaybackRate(String text) {
  var normalized = text.trim().toLowerCase().replaceAll(',', '.');
  if (normalized.endsWith('x') || normalized.endsWith('×')) {
    normalized = normalized.substring(0, normalized.length - 1).trim();
  }
  final rate = double.tryParse(normalized);
  if (rate == null || !isValidPlaybackRate(rate)) return null;
  return rate;
}

/// How a speed reads in the editor: "1x", "1.5x", "0.25x".
String formatPlaybackRate(double rate) {
  var text = rate.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return '${text}x';
}

/// The timeline length (frames) of a clip that plays [sourceFrames] frames
/// of its material at [rate]: the source time divided by the speed, at
/// least one frame.
int timelineLengthForSource(double sourceFrames, double rate) {
  if (!isValidPlaybackRate(rate) || !sourceFrames.isFinite) return 1;
  return math.max(1, (sourceFrames / rate).round());
}

/// A source position split into whole frames and the fraction after them.
typedef SourcePosition = ({int frame, double fraction});

/// The source position [elapsedFrames] timeline frames into a clip that
/// starts at [startFrame] + [startFraction] and plays at [rate]: where the
/// right half of a clip split there starts.
SourcePosition sourcePositionAfter({
  required int startFrame,
  required double startFraction,
  required int elapsedFrames,
  required double rate,
}) {
  final position = startFrame + startFraction + elapsedFrames * rate;
  var frame = position.floor();
  var fraction = position - frame;
  // Values a hair below a whole frame are that frame (binary rounding).
  if (1 - fraction < 1e-9) {
    frame += 1;
    fraction = 0;
  }
  return (frame: frame, fraction: fraction < 1e-9 ? 0.0 : fraction);
}

/// [keyframes] with the time between them scaled for playing [factor]
/// times as fast, measured from [anchorFrame] (the start of the animation
/// that changes speed); values and easing are kept. Each key keeps its time
/// before rounding to a frame ([LayerKeyframe.exactFrame]) and the next
/// change starts from it, so a speed changed back returns every key to its
/// frame. Keyframes before
/// [anchorFrame] are not moved. Returns null when two keyframes would land
/// on the same frame, so a retime that cannot keep every key is refused.
List<LayerKeyframe>? retimeKeyframes(
  List<LayerKeyframe> keyframes, {
  required int anchorFrame,
  required double factor,
}) {
  // The ratio of two speeds can lie outside the speed range (0.01x→100x).
  if (!factor.isFinite || factor <= 0) return null;
  final result = <LayerKeyframe>[];
  final used = <int>{};
  for (final keyframe in keyframes) {
    if (keyframe.frameIndex < anchorFrame) {
      if (!used.add(keyframe.frameIndex)) return null;
      result.add(keyframe);
      continue;
    }
    // From the key's unrounded time, so changing the speed back and forth
    // does not move it a frame at a time.
    final exact = anchorFrame + (keyframe.exactTime - anchorFrame) / factor;
    final frame = exact.round();
    if (!used.add(frame)) return null;
    result.add(
      keyframe.copyWith(
        frameIndex: frame,
        exactFrame: (exact - frame).abs() < 1e-9 ? null : exact,
      ),
    );
  }
  result.sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
  return result;
}

/// Where each key of a range moves when the range plays [rate] times as
/// fast: the keys from [fromFrame] to [toFrame] (inclusive) are spaced by
/// 1 / [rate] from [fromFrame]; keys outside the range stay put. Returns old
/// frame → new frame for every key, or null when [rate] is not a speed, the
/// range has fewer than two keys, two keys would share a frame, a key would
/// pass a key after the range, or one would go past [lastFrame].
Map<int, int>? retimeKeyRange(
  Iterable<int> frames, {
  required int fromFrame,
  required int toFrame,
  required double rate,
  int? lastFrame,
}) {
  if (!isValidPlaybackRate(rate) || toFrame <= fromFrame) return null;
  final keys = frames.toSet().toList()..sort();
  final inRange = [
    for (final f in keys)
      if (f >= fromFrame && f <= toFrame) f,
  ];
  if (inRange.length < 2) return null;
  final next = keys.where((f) => f > toFrame).firstOrNull;
  final moved = <int, int>{};
  final used = <int>{
    for (final f in keys)
      if (f < fromFrame || f > toFrame) f,
  };
  for (final f in inRange) {
    final to = fromFrame + ((f - fromFrame) / rate).round();
    if ((next != null && to >= next) ||
        (lastFrame != null && to > lastFrame) ||
        !used.add(to)) {
      return null;
    }
    moved[f] = to;
  }
  return {for (final f in keys) f: moved[f] ?? f};
}

/// [keyframes] moved by [frames] (from [retimeKeyRange]); values and easing
/// are kept.
List<T> moveKeyframes<T>(
  List<T> keyframes,
  Map<int, int> frames, {
  required int Function(T key) frameOf,
  required T Function(T key, int frame) withFrame,
}) => [
  for (final key in keyframes)
    withFrame(key, frames[frameOf(key)] ?? frameOf(key)),
]..sort((a, b) => frameOf(a).compareTo(frameOf(b)));

/// The FFmpeg `atempo` factors that change the speed by [rate]. One filter
/// accepts 0.5–100, so slower speeds chain halvings.
List<double> atempoChain(double rate) {
  if (!isValidPlaybackRate(rate)) {
    throw ArgumentError.value(rate, 'rate', 'not a playback speed');
  }
  final chain = <double>[];
  var remaining = rate;
  while (remaining < 0.5) {
    chain.add(0.5);
    remaining /= 0.5;
  }
  chain.add(remaining);
  return chain;
}
