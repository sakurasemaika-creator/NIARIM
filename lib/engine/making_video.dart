import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/foundation.dart';

import '../services/hw_video_encoder.dart';
import 'video_frame_decoder.dart';
import 'video_frame_timeline.dart';

/// The video tools the making uses: the device's H.264 encoder for MP4, and
/// FFmpeg/FFprobe for the other formats, for reading the video segments and
/// for putting MP4 files together. Tests put the system's tools in its place
/// ([instance]).
abstract class MakingVideoTools {
  const MakingVideoTools();

  /// The tools of the device.
  static const MakingVideoTools device = _DeviceVideoTools();

  static MakingVideoTools _instance = device;

  /// The tools in use.
  static MakingVideoTools get instance => _instance;

  @visibleForTesting
  static set instance(MakingVideoTools tools) => _instance = tools;

  /// Encodes the image files [framePaths] (PNG or JPEG of [width]×[height],
  /// shown in order; a path given again shows the same picture again) as an
  /// H.264 MP4 at [fps] frames per second.
  Future<void> encodeMp4({
    required List<String> framePaths,
    required int fps,
    required int width,
    required int height,
    required String outputPath,
  });

  /// Runs FFmpeg with [arguments]; whether it succeeded.
  Future<bool> runFfmpeg(List<String> arguments);

  /// Runs FFprobe with [arguments]; whether it succeeded.
  Future<bool> runFfprobe(List<String> arguments);

  /// A decoder of video frames using these tools.
  FfmpegVideoFrameDecoder decoder(Directory workDirectory) =>
      FfmpegVideoFrameDecoder(
        workDirectory: workDirectory,
        runFfmpeg: runFfmpeg,
        runFfprobe: runFfprobe,
      );
}

class _DeviceVideoTools extends MakingVideoTools {
  const _DeviceVideoTools();

  @override
  Future<void> encodeMp4({
    required List<String> framePaths,
    required int fps,
    required int width,
    required int height,
    required String outputPath,
  }) async {
    await HardwareVideoEncoder.encodeMp4(
      framePaths: framePaths,
      fps: fps,
      width: width,
      height: height,
      outputPath: outputPath,
    );
  }

  @override
  Future<bool> runFfmpeg(List<String> arguments) async {
    final session = await FFmpegKit.executeWithArguments(arguments);
    return ReturnCode.isSuccess(await session.getReturnCode());
  }

  @override
  Future<bool> runFfprobe(List<String> arguments) async {
    final session = await FFprobeKit.executeWithArguments(arguments);
    return ReturnCode.isSuccess(await session.getReturnCode());
  }
}

/// Working with the video segments and video parts of a making.
abstract final class MakingVideo {
  /// FFmpeg arguments that put the MP4 files [parts] (of [frames] frames each
  /// at [fps], made the same way) one after another in [outputPath] without
  /// encoding them again. [listPath] is the list FFmpeg reads.
  static List<String> concatArguments(String listPath, String outputPath) => [
    '-hide_banner',
    '-nostdin',
    '-loglevel',
    'error',
    '-y',
    '-f',
    'concat',
    '-safe',
    '0',
    '-i',
    listPath,
    '-map',
    '0:v:0',
    '-c',
    'copy',
    outputPath,
  ];

  /// The list FFmpeg's concat reader takes: each file and how long it lasts
  /// (so each starts right after the one before, whatever the files say of
  /// their last frame).
  static String concatList(List<String> parts, List<int> frames, int fps) {
    final text = StringBuffer('ffconcat version 1.0\n');
    for (var i = 0; i < parts.length; i++) {
      final escaped = parts[i].replaceAll("'", r"'\''");
      final micros = frames[i] * 1000000 ~/ fps;
      text
        ..writeln("file '$escaped'")
        ..writeln(
          'duration ${micros ~/ 1000000}.'
          '${(micros % 1000000).toString().padLeft(6, '0')}',
        );
    }
    return text.toString();
  }

  /// Puts the MP4 files [parts] together in [outputPath] (copied when there
  /// is one) and checks it has every frame.
  static Future<void> concat({
    required List<String> parts,
    required List<int> frames,
    required int fps,
    required String outputPath,
    required Directory workDirectory,
    MakingVideoTools? tools,
  }) async {
    if (parts.length == 1) {
      await File(parts.single).copy(outputPath);
      return;
    }
    final video = tools ?? MakingVideoTools.instance;
    await workDirectory.create(recursive: true);
    final list = File(
      '${workDirectory.path}/concat_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    await list.writeAsString(concatList(parts, frames, fps), flush: true);
    try {
      final ok = await video.runFfmpeg(concatArguments(list.path, outputPath));
      if (!ok || !await File(outputPath).exists()) {
        throw StateError('The making video parts could not be put together.');
      }
      final timeline = await probe(outputPath, workDirectory, tools: video);
      final expected = frames.fold(0, (a, b) => a + b);
      if (timeline.frameCount != expected) {
        throw StateError(
          'The making video has ${timeline.frameCount} of $expected frames.',
        );
      }
    } finally {
      if (await list.exists()) await list.delete();
    }
  }

  /// The frames of the video at [path].
  static Future<VideoFrameTimeline> probe(
    String path,
    Directory workDirectory, {
    MakingVideoTools? tools,
  }) => (tools ?? MakingVideoTools.instance).decoder(workDirectory).probe(path);

  /// FFmpeg arguments that write [count] frames of the video at [path], from
  /// the one [seekTime] selects, as PNG files of exactly [width]×[height]
  /// named by [pattern] (`…%06d.png`) numbered from [startNumber].
  static List<String> extractArguments({
    required String path,
    required Duration seekTime,
    required int count,
    required int width,
    required int height,
    required String pattern,
    required int startNumber,
  }) => [
    '-hide_banner',
    '-nostdin',
    '-loglevel',
    'error',
    '-ss',
    formatSeekSeconds(seekTime),
    '-i',
    path,
    '-map',
    '0:v:0',
    '-an',
    '-sn',
    '-dn',
    '-vf',
    'scale=$width:$height:flags=$videoFrameScaleFlags,format=rgb24',
    '-fps_mode',
    'passthrough',
    '-frames:v',
    '$count',
    '-start_number',
    '$startNumber',
    '-y',
    pattern,
  ];

  /// How far a frame decoded from a segment may be from the picture it was
  /// made from, compared in small blocks (the mean of each block: the
  /// encoder's loss of fine detail averages out, a wrong picture does not):
  /// the mean difference per channel (out of 255), and how many blocks may
  /// be far off. A segment the device's encoder got wrong (a green or grey
  /// picture, the wrong frame) is far beyond both.
  static const double maxMeanDifference = 10;
  static const double maxFarOffShare = 0.02;

  /// Whether the straight RGBA [decoded] shows the opaque RGBA [source] (both
  /// [width]×[height]), as a video frame can.
  static bool looksLike(
    Uint8List decoded,
    Uint8List source,
    int width,
    int height,
  ) {
    if (decoded.length != width * height * 4 ||
        source.length != width * height * 4) {
      return false;
    }
    // Blocks of about 1/64 of the shorter side.
    final block = math.max(1, math.min(width, height) ~/ 64);
    final columns = (width + block - 1) ~/ block;
    final rows = (height + block - 1) ~/ block;
    final sums = Int64List(columns * rows * 3);
    final counts = Int32List(columns * rows);
    for (var y = 0; y < height; y++) {
      final rowBlock = (y ~/ block) * columns;
      var i = y * width * 4;
      for (var x = 0; x < width; x++, i += 4) {
        final b = rowBlock + x ~/ block;
        sums[b * 3] += decoded[i] - source[i];
        sums[b * 3 + 1] += decoded[i + 1] - source[i + 1];
        sums[b * 3 + 2] += decoded[i + 2] - source[i + 2];
        counts[b]++;
      }
    }
    var total = 0.0;
    var farOff = 0;
    for (var b = 0; b < counts.length; b++) {
      var worst = 0.0;
      for (var c = 0; c < 3; c++) {
        final d = (sums[b * 3 + c] / counts[b]).abs();
        total += d;
        if (d > worst) worst = d;
      }
      if (worst > 48) farOff++;
    }
    return total / (counts.length * 3) <= maxMeanDifference &&
        farOff / counts.length <= maxFarOffShare;
  }
}
