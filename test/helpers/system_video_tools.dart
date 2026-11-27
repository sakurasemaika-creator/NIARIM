import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:niarim/engine/making_video.dart';

/// The making's video tools made of the system's `ffmpeg`/`ffprobe`, in
/// place of the device's H.264 encoder and FFmpegKit.
///
/// The MP4 encoder works like the device's: H.264 without B-frames, a key
/// frame every 2 seconds, and the bit rate the device's encoder is given
/// (0.1 bit per pixel, at least 1 Mbit/s); x264 spends about all of it (an
/// encoder that spends less only makes the segments smaller). With [crf] it
/// spends what the picture needs instead.
class SystemVideoTools extends MakingVideoTools {
  SystemVideoTools({this.crf, this.failEncode = false, this.garble = false});

  final int? crf;

  /// The encoder fails (a device without a working one).
  final bool failEncode;

  /// The encoder writes a video of the right length that does not show the
  /// pictures (a broken device encoder).
  final bool garble;

  /// The frame paths of each encode, in order.
  final List<List<String>> encoded = [];

  /// The FFmpeg command lines run.
  final List<List<String>> ffmpegRuns = [];

  static Future<bool> available() async {
    for (final tool in ['ffmpeg', 'ffprobe']) {
      try {
        if ((await Process.run(tool, ['-version'])).exitCode != 0) {
          return false;
        }
      } on ProcessException {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> encodeMp4({
    required List<String> framePaths,
    required int fps,
    required int width,
    required int height,
    required String outputPath,
  }) async {
    encoded.add([...framePaths]);
    if (failEncode) throw StateError('No video encoder on this device.');
    final dir = await Directory.systemTemp.createTemp('niarim-system-encode-');
    try {
      final extensions = {
        for (final path in framePaths) path.split('.').last.toLowerCase(),
      };
      final List<String> input;
      if (extensions.length == 1) {
        final extension = extensions.single;
        for (var i = 0; i < framePaths.length; i++) {
          await Link(
            '${dir.path}/${i.toString().padLeft(6, '0')}.$extension',
          ).create(File(framePaths[i]).absolute.path);
        }
        input = ['-framerate', '$fps', '-i', '${dir.path}/%06d.$extension'];
      } else {
        // Pictures of several kinds: as raw pixels.
        final raw = File('${dir.path}/frames.rgba').openWrite();
        for (final path in framePaths) {
          final image = img.decodeImage(await File(path).readAsBytes())!;
          raw.add(
            image
                .convert(numChannels: 4)
                .getBytes(order: img.ChannelOrder.rgba),
          );
        }
        await raw.close();
        input = [
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgba',
          '-s',
          '${width}x$height',
          '-framerate',
          '$fps',
          '-i',
          '${dir.path}/frames.rgba',
        ];
      }
      final bitRate = math.max(1000000, (width * height * fps * 0.1).round());
      final args = [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        ...input,
        if (garble) ...['-vf', 'negate,hue=h=120'],
        '-c:v',
        'libx264',
        '-profile:v',
        'main',
        '-bf',
        '0',
        '-preset',
        'veryfast',
        if (crf != null) ...['-crf', '$crf'] else ...['-b:v', '$bitRate'],
        '-g',
        '${fps * 2}',
        '-keyint_min',
        '${fps * 2}',
        '-sc_threshold',
        '0',
        '-pix_fmt',
        'yuv420p',
        outputPath,
      ];
      final result = await Process.run('ffmpeg', args);
      if (result.exitCode != 0) {
        throw StateError('ffmpeg could not encode: ${result.stderr}');
      }
    } finally {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<bool> runFfmpeg(List<String> arguments) async {
    ffmpegRuns.add(arguments);
    final result = await Process.run('ffmpeg', arguments);
    return result.exitCode == 0;
  }

  @override
  Future<bool> runFfprobe(List<String> arguments) async {
    final result = await Process.run('ffprobe', arguments);
    return result.exitCode == 0;
  }
}
