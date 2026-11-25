import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_audio.dart';
import 'package:niarim/engine/speed_sound_preview.dart';

final _ffmpegTests =
    Platform.environment['NIARIM_VIDEO_FRAME_FFMPEG_TESTS'] == '1';

Future<bool> _ffmpeg(List<String> arguments) async {
  final run = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    ...arguments,
  ]);
  return run.exitCode == 0;
}

/// The left channel's samples of a 16-bit stereo WAV after its 44-byte
/// header.
List<int> _left(String path) {
  final wav = File(path).readAsBytesSync();
  final samples = Int16List.view(
    wav.buffer,
    wav.offsetInBytes + 44,
    (wav.length - 44) ~/ 2,
  );
  return [for (var i = 0; i < samples.length; i += 2) samples[i]];
}

double _hertz(List<int> left) {
  var crossings = 0;
  for (var i = 1; i < left.length; i++) {
    if ((left[i - 1] < 0) != (left[i] < 0)) crossings++;
  }
  return crossings / 2 / (left.length / exportAudioSampleRate);
}

/// The preview of a sound whose pitch follows its speed plays a sound made
/// with the export's own FFmpeg arguments, so it sounds as the export does.
void main() {
  test('only a sound whose pitch is not kept and whose speed is not 1x is '
      'made', () {
    expect(SpeedSoundPreview.needed(rate: 2, preservePitch: false), isTrue);
    expect(SpeedSoundPreview.needed(rate: 0.5, preservePitch: false), isTrue);
    expect(SpeedSoundPreview.needed(rate: 2, preservePitch: true), isFalse);
    expect(SpeedSoundPreview.needed(rate: 1, preservePitch: false), isFalse);
  });

  test('the preview asks FFmpeg for the export\'s arguments, once per '
      'sound, and plays nothing until it is ready', () async {
    final dir = Directory.systemTemp.createTempSync('speed-sound-args-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final calls = <List<String>>[];
    final finish = Completer<void>();
    final preview = SpeedSoundPreview(
      workDir: () async => dir,
      runFfmpeg: (arguments) async {
        calls.add(arguments);
        await finish.future;
        File(arguments.last).writeAsBytesSync([1]);
        return true;
      },
    );
    var ready = 0;
    String? ask() => preview.soundFor(
      path: '/song.wav',
      sourceSeconds: 1.5,
      durationSeconds: 2,
      rate: 0.5,
      onReady: () => ready++,
    );
    expect(ask(), isNull);
    expect(ask(), isNull);
    await pumpEventQueue();
    // One sound, made once with what the export would use for it.
    expect(calls, hasLength(1));
    final exported = exportAudioSourceArguments(
      const ExportAudioSource(
        path: '/song.wav',
        startSeconds: 0,
        sourceSeconds: 1.5,
        durationSeconds: 2,
        clipSeconds: 2,
        playbackRate: 0.5,
        preservePitch: false,
      ),
      calls.single.last,
    );
    expect(calls.single, exported);
    expect(
      calls.single[calls.single.indexOf('-af') + 1],
      startsWith('aresample=48000,asetrate=24000,aresample=48000'),
    );
    finish.complete();
    await pumpEventQueue();
    expect(ready, 1);
    expect(ask(), calls.single.last);

    // Another speed is another sound.
    expect(
      preview.soundFor(
        path: '/song.wav',
        sourceSeconds: 1.5,
        durationSeconds: 2,
        rate: 2,
      ),
      isNull,
    );
    await pumpEventQueue();
    expect(calls, hasLength(2));

    preview.dispose();
    expect(dir.existsSync(), isFalse);
    expect(ask(), isNull);
  });

  test('a sound FFmpeg cannot make stays silent (not played with its pitch '
      'kept)', () async {
    final dir = Directory.systemTemp.createTempSync('speed-sound-fail-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    var ready = 0;
    final preview = SpeedSoundPreview(
      workDir: () async => dir,
      runFfmpeg: (_) async => false,
    );
    String? ask() => preview.soundFor(
      path: '/silent.mp4',
      sourceSeconds: 0,
      durationSeconds: 1,
      rate: 2,
      onReady: () => ready++,
    );
    expect(ask(), isNull);
    await pumpEventQueue();
    expect(ask(), isNull);
    expect(ready, 0);
    preview.dispose();
  });

  test('the made sound is the export\'s sound: the same samples, an octave up '
      'at 2x and down at 0.5x, as long as the clip', () async {
    final dir = Directory.systemTemp.createTempSync('speed-sound-real-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    // 0–1 s: 440 Hz, 1–2 s: 660 Hz.
    final source = '${dir.path}/tones.wav';
    expect(
      await _ffmpeg([
        '-y', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1', //
        '-f', 'lavfi', '-i', 'sine=frequency=660:duration=1',
        '-filter_complex', '[0][1]concat=n=2:v=0:a=1',
        '-ar', '44100', source,
      ]),
      isTrue,
    );
    final work = Directory('${dir.path}/preview')..createSync();
    final preview = SpeedSoundPreview(
      workDir: () async => work,
      runFfmpeg: _ffmpeg,
    );
    addTearDown(preview.dispose);

    Future<String> made(double from, double seconds, double rate) async {
      final ready = Completer<void>();
      expect(
        preview.soundFor(
          path: source,
          sourceSeconds: from,
          durationSeconds: seconds,
          rate: rate,
          onReady: ready.complete,
        ),
        isNull,
      );
      await ready.future.timeout(const Duration(seconds: 30));
      return preview.soundFor(
        path: source,
        sourceSeconds: from,
        durationSeconds: seconds,
        rate: rate,
      )!;
    }

    // 2x for 0.4 s reads 0–0.8 s (440 Hz) and is heard at 880 Hz.
    final fast = _left(await made(0, 0.4, 2));
    expect(fast.length / exportAudioSampleRate, closeTo(0.4, 0.01));
    expect(_hertz(fast), closeTo(880, 15));
    // 0.5x for 1 s reads 1.2–1.7 s (660 Hz) and is heard at 330 Hz.
    final slowPath = await made(1.2, 1, 0.5);
    final slow = _left(slowPath);
    expect(slow.length / exportAudioSampleRate, closeTo(1, 0.01));
    expect(_hertz(slow), closeTo(330, 10));

    // The export's sound of the same clip at full volume: the same samples.
    final exported = '${dir.path}/exported.wav';
    expect(
      await _ffmpeg(
        exportAudioSourceArguments(
          ExportAudioSource(
            path: source,
            startSeconds: 3,
            sourceSeconds: 1.2,
            durationSeconds: 1,
            clipSeconds: 1,
            playbackRate: 0.5,
            preservePitch: false,
          ),
          exported,
        ),
      ),
      isTrue,
    );
    expect(_left(exported), slow);
  }, skip: _ffmpegTests ? false : 'Needs NIARIM_VIDEO_FRAME_FFMPEG_TESTS=1');
}
