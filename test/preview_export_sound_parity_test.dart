import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/clip_speed.dart';
import 'package:niarim/engine/export_audio.dart';
import 'package:niarim/engine/pitched_sound_preview.dart';
import 'package:niarim/engine/preview_sound.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';

/// Spec 26 7.4: the preview and the export play the same sound. For every
/// frame of every clip, over 0.1x–100x, pitch changes, fades, fractions of
/// a frame, several tracks at once, read-aloud, and a video's sound (with
/// its speed, at 1x, and held where its picture holds its last frame), what
/// the preview plays ([previewAudioClipAt], [previewVideoSoundAt]) is the
/// part of the file, speed, pitch and gain the export plan reads for that
/// moment, and both stop at the same time. A sound with a pitch change is
/// made from exactly the export's description of it.
void main() {
  const fps = 10.0;
  const sceneFrames = 40;
  const rates = [0.1, 0.5, 1.0, 2.0, 16.0, 100.0];
  late File file;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('niarim-sound-parity-');
    file = File('${dir.path}/sound.wav')..writeAsBytesSync([0]);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  Future<List<ExportAudioSource>> planOf(Scene scene) async =>
      (await buildExportAudioPlan(
        scenes: [scene],
        sourceFps: fps.round(),
        pathOf: (_) async => file.path,
      )).sources;

  /// The export's file position, speed, pitch and gain [elapsed] frames
  /// into a clip starting at [startFrame], or null where it is silent.
  ({double seconds, double gain})? exportAt(
    ExportAudioSource source,
    int startFrame,
    int elapsed,
  ) {
    final t = (startFrame + elapsed) / fps - source.startSeconds;
    if (t < 0 || t >= source.durationSeconds - 1e-9) return null;
    return (
      seconds: source.sourceSeconds + t * source.playbackRate,
      gain: AudioClipEnvelope.gainAt(
        elapsedSeconds: elapsed / fps,
        clipSeconds: source.clipSeconds,
        volume: source.volume,
        fadeInSeconds: source.fadeInSeconds,
        fadeOutSeconds: source.fadeOutSeconds,
      ),
    );
  }

  void expectSame(
    PreviewSoundAt? preview,
    ExportAudioSource source,
    int startFrame,
    int elapsed,
    String what,
  ) {
    final export = exportAt(source, startFrame, elapsed);
    final reason = '$what at +$elapsed';
    if (export == null) {
      expect(preview, isNull, reason: '$reason: the export is silent');
      return;
    }
    expect(preview, isNotNull, reason: '$reason: the export sounds');
    expect(
      preview!.sourceSeconds,
      closeTo(export.seconds, 1e-9),
      reason: reason,
    );
    expect(preview.rate, source.playbackRate, reason: reason);
    expect(preview.pitchSemitones, source.pitchSemitones, reason: reason);
    expect(preview.gain, closeTo(export.gain, 1e-9), reason: reason);
    if (preview.playsMadeSound) {
      // The made sound starts where the export's sound starts and is the
      // export's description of it; the player is at the moment's place in
      // it at 1x.
      final made = PitchedSoundPreview.previewSource(
        path: source.path,
        sourceSeconds: preview.madeFromSeconds,
        durationSeconds: preview.madeSeconds,
        rate: preview.rate,
        pitchSemitones: preview.pitchSemitones,
      );
      expect(made.sourceSeconds, closeTo(source.sourceSeconds, 1e-9));
      expect(made.durationSeconds, closeTo(source.durationSeconds, 1e-9));
      expect(
        speedSoundFilters(
          made.playbackRate,
          pitchSemitones: made.pitchSemitones,
        ),
        speedSoundFilters(
          source.playbackRate,
          pitchSemitones: source.pitchSemitones,
        ),
      );
      expect(preview.playerRate, 1);
      expect(preview.playerSecondsAt(elapsed / fps), elapsed / fps);
    } else {
      expect(preview.playerRate, source.playbackRate, reason: reason);
      expect(
        preview.playerSecondsAt(elapsed / fps),
        closeTo(export.seconds, 1e-9),
      );
    }
  }

  test('audio clips: every speed, pitch change, fade and start, several '
      'tracks and read-aloud at once', () async {
    var checked = 0;
    for (final rate in rates) {
      for (final pitch in [0.0, 7.0, pitchMatchingSpeed(rate)]) {
        // Two tracks and a read-aloud clip playing together, with and
        // without fades and fractions of a frame.
        final clips = [
          AudioClip(
            id: 'music',
            label: 'music',
            materialId: 'm',
            startFrame: 3,
            lengthFrames: 12,
            sourceStartFrame: 5,
            sourceStartFraction: 0.25,
            playbackRate: rate,
            pitchSemitones: pitch,
            volume: 0.8,
            fadeIn: 0.3,
            fadeOut: 0.5,
          ),
          AudioClip(
            id: 'effect',
            label: 'effect',
            materialId: 'e',
            startFrame: 0,
            lengthFrames: 7,
            playbackRate: rate,
            trackRow: 1,
            volume: 0.5,
          ),
          AudioClip(
            id: 'speech',
            label: 'speech',
            materialId: 's',
            startFrame: 20,
            lengthFrames: 9,
            sourceStartFrame: 2,
            playbackRate: rate,
            pitchSemitones: -pitch,
            isReadAloud: true,
            fadeOut: 2,
          ),
        ];
        final sources = await planOf(
          Scene(
            id: 'S',
            index: 0,
            frames: [for (var i = 0; i < sceneFrames; i++) Frame(index: i)],
            audioClips: clips,
          ),
        );
        expect(sources, hasLength(clips.length));
        for (var c = 0; c < clips.length; c++) {
          final clip = clips[c];
          for (var e = -2; e < clip.lengthFrames + 2; e++) {
            expectSame(
              previewAudioClipAt(
                elapsedFrames: e,
                lengthFrames: clip.lengthFrames,
                sourceStartFrame: clip.sourceStartFrame,
                sourceStartFraction: clip.sourceStartFraction,
                rate: clip.playbackRate,
                pitchSemitones: clip.pitchSemitones,
                volume: clip.volume,
                fadeIn: clip.fadeIn,
                fadeOut: clip.fadeOut,
                framesPerSecond: fps,
              ),
              sources[c],
              clip.startFrame,
              e,
              '${clip.id} ${rate}x pitch $pitch',
            );
            checked++;
          }
        }
      }
    }
    expect(checked, greaterThan(500));
  });

  test('a video\'s sound: at its speed or at 1x, with a pitch change, '
      'silent where its last frame is held', () async {
    var checked = 0;
    // Used ranges of source frames 4.5–29 and 4–13 (the second ends on a
    // whole frame at 1x: frame 10 of the clip is the first silent one).
    for (final (fraction, end) in [(0.5, 29), (0.0, 13)]) {
      for (final rate in rates) {
        for (final follows in [true, false]) {
          for (final pitch in [0.0, -5.0]) {
            // At a high speed the used range is used up before the clip ends
            // and the rest is silent.
            final layer = Layer(
              id: 'v',
              name: 'v',
              type: LayerType.timelineVideo,
              materialId: 'v',
              rangeMode: LayerRangeMode.frameRange,
              rangeStart: 5,
              rangeEnd: 24,
              sourceTrimStart: 4,
              sourceTrimStartFraction: fraction,
              sourceTrimEnd: end,
              playbackRate: rate,
              videoSoundFollowsSpeed: follows,
              videoPitchSemitones: pitch,
              videoVolume: 0.6,
            );
            final sources = await planOf(
              Scene(
                id: 'S',
                index: 0,
                frames: [
                  for (var i = 0; i < sceneFrames; i++)
                    Frame(index: i, layers: i == 0 ? [layer] : const []),
                ],
              ),
            );
            final soundRate = follows ? rate : 1.0;
            final length = layer.rangeEnd! - layer.rangeStart! + 1;
            if (sources.isEmpty) {
              fail('the video has sound at ${rate}x');
            }
            for (var e = -2; e < length + 2; e++) {
              expectSame(
                previewVideoSoundAt(
                  elapsedFrames: e,
                  lengthFrames: length,
                  trimStartFrame: layer.sourceTrimStart!,
                  trimStartFraction: layer.sourceTrimStartFraction,
                  trimEndFrame: layer.sourceTrimEnd!,
                  soundRate: soundRate,
                  pitchSemitones: layer.videoPitchSemitones,
                  volume: layer.videoVolume,
                  framesPerSecond: fps,
                ),
                sources.single,
                layer.rangeStart! - 1,
                e,
                'video ${rate}x follows=$follows pitch $pitch',
              );
              checked++;
            }
            // The sound stops where the used range has played.
            final sounding = math.min(
              length.toDouble(),
              (end + 1 - 4 - fraction) / soundRate,
            );
            expect(
              sources.single.durationSeconds,
              closeTo(sounding / fps, 1e-9),
            );
          }
        }
      }
    }
    expect(checked, greaterThan(800));
  });
}
