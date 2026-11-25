import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';

import '../models/layer.dart';
import '../models/scene.dart';
import 'clip_speed.dart';
import 'timeline_video_time.dart';

/// One sound in an exported video: a stretch of an audio file (a clip on an
/// audio track) or the sound of a video material.
///
/// Times are in seconds. [startSeconds] is where it starts in the exported
/// video, [sourceSeconds] where it starts in the file. The fades follow the
/// timeline's playback: the fade-in from the clip's start, the fade-out to
/// the clip's own end ([clipSeconds]), which a clip cut short by the end of
/// its scene or the 90-second limit does not reach.
class ExportAudioSource {
  const ExportAudioSource({
    required this.path,
    required this.startSeconds,
    required this.sourceSeconds,
    required this.durationSeconds,
    required this.clipSeconds,
    this.volume = 1,
    this.fadeInSeconds = 0,
    this.fadeOutSeconds = 0,
    this.playbackRate = 1,
    this.pitchSemitones = 0,
  });

  final String path;
  final double startSeconds;
  final double sourceSeconds;

  /// Seconds the sound lasts in the exported video. At [playbackRate] it
  /// reads `durationSeconds * playbackRate` seconds of the file.
  final double durationSeconds;
  final double clipSeconds;
  final double volume;
  final double fadeInSeconds;
  final double fadeOutSeconds;

  /// The clip's speed.
  final double playbackRate;

  /// The pitch change in semitones; the speed itself keeps the pitch.
  final double pitchSemitones;
}

/// The sounds of an export and how many could not be included (a material
/// whose file is missing).
class ExportAudioPlan {
  const ExportAudioPlan(this.sources, {this.missing = 0});

  static const empty = ExportAudioPlan([]);

  final List<ExportAudioSource> sources;
  final int missing;

  bool get isEmpty => sources.isEmpty;
}

/// The sounds of [scenes] played one after another, as the timeline plays
/// them: each scene starts where the previous one ends, a clip only sounds
/// while its scene is on screen, and nothing sounds after [maxSeconds] (the
/// first 90 seconds of a long work). [pathOf] gives a material's file, or
/// null when it is missing.
Future<ExportAudioPlan> buildExportAudioPlan({
  required List<Scene> scenes,
  required int sourceFps,
  int? maxSeconds,
  required Future<String?> Function(String materialId) pathOf,
}) async {
  if (sourceFps <= 0) return ExportAudioPlan.empty;
  final fps = sourceFps.toDouble();
  final totalFrames = scenes.fold<int>(0, (n, s) => n + s.frames.length);
  final limitFrames = maxSeconds == null
      ? totalFrames
      : math.min(totalFrames, maxSeconds * sourceFps);
  final sources = <ExportAudioSource>[];
  var missing = 0;
  var sceneStart = 0;

  Future<void> add({
    required String? materialId,
    required int startFrame,
    required int lengthFrames,
    required int sourceFrame,
    required int sceneFrames,
    required double volume,
    double fadeIn = 0,
    double fadeOut = 0,
    double sourceFraction = 0,
    double rate = 1,
    double pitchSemitones = 0,
    double? soundingFrames,
  }) async {
    if (materialId == null || volume <= 0 || lengthFrames <= 0) return;
    final start = math.max(0, startFrame);
    // Within the scene and before the export's end, and for a video only
    // over the part of the clip that plays its used range (silent where the
    // picture holds the last frame).
    var end = math
        .min(
          math.min(startFrame + lengthFrames, sceneFrames) + sceneStart,
          limitFrames,
        )
        .toDouble();
    if (soundingFrames != null) {
      end = math.min(end, sceneStart + startFrame + soundingFrames);
    }
    final from = sceneStart + start;
    if (end <= from) return;
    final path = await pathOf(materialId);
    if (path == null || !File(path).existsSync()) {
      missing++;
      return;
    }
    sources.add(
      ExportAudioSource(
        path: path,
        startSeconds: from / fps,
        sourceSeconds:
            math.max(
              0,
              sourceFrame + sourceFraction + (start - startFrame) * rate,
            ) /
            fps,
        durationSeconds: (end - from) / fps,
        clipSeconds: lengthFrames / fps,
        volume: volume.clamp(0.0, 1.0),
        fadeInSeconds: math.max(0, fadeIn),
        fadeOutSeconds: math.max(0, fadeOut),
        playbackRate: isValidPlaybackRate(rate) ? rate : 1,
        pitchSemitones: isValidPitchSemitones(pitchSemitones)
            ? pitchSemitones
            : 0,
      ),
    );
  }

  for (final scene in scenes) {
    if (sceneStart >= limitFrames) break;
    final sceneFrames = scene.frames.length;
    for (final clip in scene.audioClips) {
      await add(
        materialId: clip.materialId,
        startFrame: clip.startFrame,
        lengthFrames: clip.lengthFrames,
        sourceFrame: clip.sourceStartFrame,
        sceneFrames: sceneFrames,
        volume: clip.volume,
        fadeIn: clip.fadeIn,
        fadeOut: clip.fadeOut,
        sourceFraction: clip.sourceStartFraction,
        rate: clip.playbackRate,
        pitchSemitones: clip.pitchSemitones,
      );
    }
    // A video material is a layer; its sound plays over the frames it shows.
    final seen = <String>{};
    for (final frame in scene.frames) {
      for (final layer in frame.layers) {
        if (layer.type != LayerType.timelineVideo || !seen.add(layer.id)) {
          continue;
        }
        final start = (layer.rangeStart ?? 1) - 1;
        final end = layer.rangeEnd ?? (start + 1);
        await add(
          materialId: layer.materialId,
          startFrame: start,
          lengthFrames: end - start,
          sourceFrame: layer.sourceTrimStart ?? 0,
          sceneFrames: sceneFrames,
          volume: layer.videoVolume,
          sourceFraction: layer.sourceTrimStartFraction,
          rate: layer.videoSoundFollowsSpeed ? layer.playbackRate : 1,
          pitchSemitones: layer.videoPitchSemitones,
          soundingFrames: TimelineVideoTimeMapper.layerSoundingFrames(layer),
        );
      }
    }
    sceneStart += sceneFrames;
  }
  return ExportAudioPlan(sources, missing: missing);
}

/// The shared linear gain envelope for timeline audio clips. Preview uses
/// [gainAt] at the current timeline clock; offline export uses [ffmpegFilters]
/// with the same clip-relative fade boundaries.
class AudioClipEnvelope {
  const AudioClipEnvelope._();

  static double gainAt({
    required double elapsedSeconds,
    required double clipSeconds,
    required double volume,
    double fadeInSeconds = 0,
    double fadeOutSeconds = 0,
  }) {
    if (!elapsedSeconds.isFinite ||
        !clipSeconds.isFinite ||
        !volume.isFinite ||
        clipSeconds <= 0 ||
        elapsedSeconds < 0 ||
        elapsedSeconds >= clipSeconds) {
      return 0;
    }
    var gain = volume.clamp(0.0, 1.0).toDouble();
    if (fadeInSeconds > 0 && elapsedSeconds < fadeInSeconds) {
      gain *= (elapsedSeconds / fadeInSeconds).clamp(0.0, 1.0);
    }
    final remainingSeconds = clipSeconds - elapsedSeconds;
    if (fadeOutSeconds > 0 && remainingSeconds < fadeOutSeconds) {
      gain *= (remainingSeconds / fadeOutSeconds).clamp(0.0, 1.0);
    }
    return gain.clamp(0.0, 1.0).toDouble();
  }

  static List<String> ffmpegFilters({
    required double clipSeconds,
    required double durationSeconds,
    required double volume,
    double fadeInSeconds = 0,
    double fadeOutSeconds = 0,
  }) {
    // When a fade is longer than the clip, the preview envelope is
    // (clipDuration - elapsed) / fadeDuration from the very first sample.
    // Scale the base gain and use a clip-length fade to reproduce that slope.
    final fadeOutScale = fadeOutSeconds > clipSeconds && clipSeconds > 0
        ? clipSeconds / fadeOutSeconds
        : 1.0;
    final baseVolume = (volume.clamp(0.0, 1.0) * fadeOutScale)
        .clamp(0.0, 1.0)
        .toDouble();
    final filters = <String>['volume=${baseVolume.toStringAsFixed(3)}'];
    if (fadeInSeconds > 0) {
      filters.add('afade=t=in:st=0:d=${_seconds(fadeInSeconds)}');
    }
    final fadeStart = math.max(0.0, clipSeconds - fadeOutSeconds);
    if (fadeOutSeconds > 0 && fadeStart < durationSeconds) {
      final effectiveFadeDuration = math.min(fadeOutSeconds, clipSeconds);
      filters.add(
        'afade=t=out:st=${_seconds(fadeStart)}'
        ':d=${_seconds(effectiveFadeDuration)}',
      );
    }
    return filters;
  }
}

String _seconds(double s) => s.toStringAsFixed(3);

/// The sample rate and channels of the mix (Opus needs 48 kHz).
const int exportAudioSampleRate = 48000;
const int exportAudioChannels = 2;

/// The FFmpeg filters that play a sound at [rate] with its pitch changed
/// by [pitchSemitones]. The speed keeps the pitch (`atempo`). A pitch change
/// reads the samples [pitchFactorOf] times faster (`asetrate`, which raises
/// the pitch and the speed together) and then sets the tempo back to [rate]
/// with `atempo`, so the length is the same with or without it. The export
/// and the preview of a sound with a pitch change use these same filters.
List<String> speedSoundFilters(double rate, {double pitchSemitones = 0}) {
  final tempo = <String>[];
  void tempoOf(double factor) {
    if ((factor - 1).abs() < 1e-9) return;
    // One atempo takes 0.5–100 (as [atempoChain]); a pitch change can push
    // the factor past either end, so the steps go on as far as needed.
    var left = factor;
    while (left < 0.5) {
      tempo.add('atempo=0.5');
      left /= 0.5;
    }
    while (left > 100) {
      tempo.add('atempo=100.0');
      left /= 100;
    }
    tempo.add('atempo=$left');
  }

  if (pitchSemitones == 0) {
    tempoOf(rate);
    return tempo;
  }
  // The sample rate is a whole number: the tempo makes up for its rounding.
  final rateHz = (exportAudioSampleRate * pitchFactorOf(pitchSemitones))
      .round();
  tempoOf(rate * exportAudioSampleRate / rateHz);
  return [
    'aresample=$exportAudioSampleRate',
    'asetrate=$rateHz',
    'aresample=$exportAudioSampleRate',
    ...tempo,
  ];
}

/// FFmpeg arguments that cut [source] out of its file, apply its volume and
/// fades, and write it as 48 kHz stereo 16-bit WAV to [output]. A file without
/// sound (a silent video) makes FFmpeg fail; that source is then left out.
List<String> exportAudioSourceArguments(
  ExportAudioSource source,
  String output,
) {
  final filters = AudioClipEnvelope.ffmpegFilters(
    clipSeconds: source.clipSeconds,
    durationSeconds: source.durationSeconds,
    volume: source.volume,
    fadeInSeconds: source.fadeInSeconds,
    fadeOutSeconds: source.fadeOutSeconds,
  );
  final rate = source.playbackRate;
  final tempo = speedSoundFilters(rate, pitchSemitones: source.pitchSemitones);
  return [
    '-y',
    '-ss',
    _seconds(source.sourceSeconds),
    '-t',
    _seconds(source.durationSeconds * rate),
    '-i',
    source.path,
    '-vn',
    '-af',
    // The speed first, so the fades and volume act on exported time.
    [...tempo, ...filters].join(','),
    '-ac',
    '$exportAudioChannels',
    '-ar',
    '$exportAudioSampleRate',
    '-c:a',
    'pcm_s16le',
    output,
  ];
}

/// FFmpeg arguments that place each prepared sound ([inputs], with where it
/// starts in the video) and add them up, padded with silence to
/// [totalSeconds] (the whole video, end mark included), as one WAV.
List<String> exportAudioMixArguments(
  List<({String path, double startSeconds})> inputs,
  double totalSeconds,
  String output,
) {
  final args = <String>['-y'];
  for (final input in inputs) {
    args.addAll(['-i', input.path]);
  }
  final graph = StringBuffer();
  for (var i = 0; i < inputs.length; i++) {
    final ms = (inputs[i].startSeconds * 1000).round();
    graph.write('[$i:a]adelay=$ms:all=1[d$i];');
  }
  for (var i = 0; i < inputs.length; i++) {
    graph.write('[d$i]');
  }
  // Sounds that play at once are added (like the timeline's players), not
  // averaged.
  graph.write(
    'amix=inputs=${inputs.length}:duration=longest:normalize=0,'
    'apad=whole_dur=${_seconds(totalSeconds)},'
    'atrim=0:${_seconds(totalSeconds)}[mix]',
  );
  args.addAll([
    '-filter_complex',
    graph.toString(),
    '-map',
    '[mix]',
    '-ac',
    '$exportAudioChannels',
    '-ar',
    '$exportAudioSampleRate',
    '-c:a',
    'pcm_s16le',
    output,
  ]);
  return args;
}

/// The result of preparing an export's sound: the WAV of the whole video's
/// sound (null when nothing sounds) and how many sounds were left out (a
/// missing material, a file FFmpeg could not read).
class ExportAudioMix {
  const ExportAudioMix(this.path, this.leftOut);

  final String? path;
  final int leftOut;
}

/// Mixes [plan] into one WAV in [workDir] for a video of [totalSeconds].
Future<ExportAudioMix> mixExportAudio({
  required ExportAudioPlan plan,
  required double totalSeconds,
  required Directory workDir,
  bool Function()? cancelled,
}) async {
  var leftOut = plan.missing;
  if (plan.isEmpty || totalSeconds <= 0) {
    return ExportAudioMix(null, leftOut);
  }
  final prepared = <({String path, double startSeconds})>[];
  for (var i = 0; i < plan.sources.length; i++) {
    if (cancelled?.call() == true) return ExportAudioMix(null, leftOut);
    final source = plan.sources[i];
    final output = '${workDir.path}/sound_$i.wav';
    final session = await FFmpegKit.executeWithArguments(
      exportAudioSourceArguments(source, output),
    );
    if (ReturnCode.isSuccess(await session.getReturnCode()) &&
        File(output).existsSync()) {
      prepared.add((path: output, startSeconds: source.startSeconds));
    } else {
      leftOut++;
    }
  }
  if (prepared.isEmpty) return ExportAudioMix(null, leftOut);
  final mixPath = '${workDir.path}/sound_mix.wav';
  final session = await FFmpegKit.executeWithArguments(
    exportAudioMixArguments(prepared, totalSeconds, mixPath),
  );
  if (!ReturnCode.isSuccess(await session.getReturnCode())) {
    return ExportAudioMix(null, leftOut + prepared.length);
  }
  return ExportAudioMix(mixPath, leftOut);
}
