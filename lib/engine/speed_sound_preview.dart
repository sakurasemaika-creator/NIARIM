import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';

import 'export_audio.dart';

/// The sounds the timeline's preview plays when a clip's pitch follows its
/// speed (its pitch is not kept).
///
/// The preview's players can change a sound's speed only with its pitch
/// kept. So such a sound is made once, with the export's own FFmpeg
/// arguments ([exportAudioSourceArguments] with the same
/// [speedSoundFilters]), at full volume and without fades (the preview
/// applies those as it plays), and the preview plays it at 1×: what is heard
/// is what the export writes.
///
/// Until a sound is ready the preview plays nothing for it rather than the
/// sound with its pitch kept.
class SpeedSoundPreview {
  SpeedSoundPreview({
    required this.workDir,
    Future<bool> Function(List<String> arguments)? runFfmpeg,
  }) : _run = runFfmpeg ?? _runWithFfmpegKit;

  /// Makes the folder the sounds are written to (removed by [dispose]).
  final Future<Directory> Function() workDir;
  final Future<bool> Function(List<String> arguments) _run;
  final Map<String, String?> _ready = {};
  final Map<String, Future<String?>> _making = {};
  Directory? _dir;
  var _count = 0;
  var _disposed = false;

  static Future<bool> _runWithFfmpegKit(List<String> arguments) async {
    final session = await FFmpegKit.executeWithArguments(arguments);
    return ReturnCode.isSuccess(await session.getReturnCode());
  }

  /// Whether a sound at [rate] needs one made here: only when its pitch is
  /// not kept and it plays at a speed other than 1×.
  static bool needed({required double rate, required bool preservePitch}) =>
      !preservePitch && rate != 1;

  /// The sound made for [path] from [sourceSeconds] of the file, lasting
  /// [durationSeconds] at [rate], or null while it is being made or when it
  /// could not be made. [onReady] is called once a sound asked for here
  /// becomes ready.
  String? soundFor({
    required String path,
    required double sourceSeconds,
    required double durationSeconds,
    required double rate,
    void Function()? onReady,
  }) {
    if (_disposed || durationSeconds <= 0) return null;
    final key = _keyOf(path, sourceSeconds, durationSeconds, rate);
    if (_ready.containsKey(key)) return _ready[key];
    _making.putIfAbsent(key, () async {
      final made = await make(
        path: path,
        sourceSeconds: sourceSeconds,
        durationSeconds: durationSeconds,
        rate: rate,
      );
      _making.remove(key);
      if (_disposed) return null;
      _ready[key] = made;
      if (made != null) onReady?.call();
      return made;
    });
    return null;
  }

  /// Makes the sound [soundFor] gives and returns its file (a 48 kHz stereo
  /// WAV), or null when FFmpeg could not make it.
  Future<String?> make({
    required String path,
    required double sourceSeconds,
    required double durationSeconds,
    required double rate,
  }) async {
    final dir = _dir ??= await workDir();
    if (_disposed) return null;
    final output = '${dir.path}/speed_sound_${_count++}.wav';
    final ok = await _run(
      exportAudioSourceArguments(
        previewSource(
          path: path,
          sourceSeconds: sourceSeconds,
          durationSeconds: durationSeconds,
          rate: rate,
        ),
        output,
      ),
    );
    return ok && File(output).existsSync() ? output : null;
  }

  /// The export's description of the sound made here: the whole clip, at
  /// full volume, its pitch following [rate].
  static ExportAudioSource previewSource({
    required String path,
    required double sourceSeconds,
    required double durationSeconds,
    required double rate,
  }) => ExportAudioSource(
    path: path,
    startSeconds: 0,
    sourceSeconds: sourceSeconds,
    durationSeconds: durationSeconds,
    clipSeconds: durationSeconds,
    playbackRate: rate,
    preservePitch: false,
  );

  static String _keyOf(
    String path,
    double sourceSeconds,
    double durationSeconds,
    double rate,
  ) =>
      '$path|${sourceSeconds.toStringAsFixed(4)}|'
      '${durationSeconds.toStringAsFixed(4)}|$rate';

  void dispose() {
    _disposed = true;
    _ready.clear();
    _making.clear();
    final dir = _dir;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // A file still open by a player: the temporary folder is cleaned
        // by the system later.
      }
    }
  }
}
