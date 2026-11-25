import 'clip_speed.dart';
import 'export_audio.dart';
import 'timeline_video_time.dart';

/// What the timeline's preview plays for one sound at one moment of its
/// clip. The export reads the same part of the same file for that moment
/// ([buildExportAudioPlan]); `test/preview_export_sound_parity_test.dart`
/// compares the two over speeds, pitch changes, fades and kinds of sound.
class PreviewSoundAt {
  const PreviewSoundAt({
    required this.sourceSeconds,
    required this.rate,
    required this.pitchSemitones,
    required this.gain,
    required this.madeFromSeconds,
    required this.madeSeconds,
  });

  /// Where in the source file this moment is.
  final double sourceSeconds;

  /// The speed the sound plays at, and its pitch change.
  final double rate;
  final double pitchSemitones;

  /// The gain (volume and fades) at this moment.
  final double gain;

  /// The part of the file a sound with a pitch change is made from (the
  /// whole clip's sound, played from its start), and how long it lasts.
  final double madeFromSeconds;
  final double madeSeconds;

  /// Whether the preview plays a sound made with the export's filters (a
  /// pitch change) at 1x, rather than the file at [rate].
  bool get playsMadeSound => pitchSemitones != 0;

  /// Where the preview's player plays from: in the made sound, or in the
  /// file.
  double playerSecondsAt(double elapsedSeconds) =>
      playsMadeSound ? elapsedSeconds : sourceSeconds;

  /// The speed the preview's player plays at.
  double get playerRate => playsMadeSound ? 1 : rate;
}

/// An audio (or read-aloud) clip [elapsedFrames] into it, or null outside
/// it.
PreviewSoundAt? previewAudioClipAt({
  required int elapsedFrames,
  required int lengthFrames,
  required int sourceStartFrame,
  required double sourceStartFraction,
  required double rate,
  required double pitchSemitones,
  required double volume,
  required double fadeIn,
  required double fadeOut,
  required double framesPerSecond,
}) {
  if (elapsedFrames < 0 ||
      elapsedFrames >= lengthFrames ||
      framesPerSecond <= 0) {
    return null;
  }
  final source = sourcePositionAfter(
    startFrame: sourceStartFrame,
    startFraction: sourceStartFraction,
    elapsedFrames: elapsedFrames,
    rate: rate,
  );
  return PreviewSoundAt(
    sourceSeconds: (source.frame + source.fraction) / framesPerSecond,
    rate: rate,
    pitchSemitones: pitchSemitones,
    // Preview and export share the clip-relative fade envelope.
    gain: AudioClipEnvelope.gainAt(
      elapsedSeconds: elapsedFrames / framesPerSecond,
      clipSeconds: lengthFrames / framesPerSecond,
      volume: volume,
      fadeInSeconds: fadeIn,
      fadeOutSeconds: fadeOut,
    ),
    madeFromSeconds: (sourceStartFrame + sourceStartFraction) / framesPerSecond,
    madeSeconds: lengthFrames / framesPerSecond,
  );
}

/// A video's sound [elapsedFrames] into its clip, or null where it is
/// silent: outside the clip, and where the picture holds the last used
/// frame (its used range at [soundRate] has played).
PreviewSoundAt? previewVideoSoundAt({
  required int elapsedFrames,
  required int lengthFrames,
  required int trimStartFrame,
  required double trimStartFraction,
  required int trimEndFrame,
  required double soundRate,
  required double pitchSemitones,
  required double volume,
  required double framesPerSecond,
}) {
  if (elapsedFrames < 0 ||
      elapsedFrames >= lengthFrames ||
      framesPerSecond <= 0) {
    return null;
  }
  final sounding = TimelineVideoTimeMapper.soundingFrames(
    clipLengthFrames: lengthFrames,
    sourceTrimStartFrame: trimStartFrame + trimStartFraction,
    sourceTrimEndFrame: trimEndFrame,
    soundRate: soundRate,
  );
  if (elapsedFrames >= sounding) return null;
  final from = trimStartFrame + trimStartFraction;
  return PreviewSoundAt(
    sourceSeconds: (from + elapsedFrames * soundRate) / framesPerSecond,
    rate: soundRate,
    pitchSemitones: pitchSemitones,
    gain: volume.clamp(0.0, 1.0).toDouble(),
    madeFromSeconds: from / framesPerSecond,
    madeSeconds: sounding / framesPerSecond,
  );
}
