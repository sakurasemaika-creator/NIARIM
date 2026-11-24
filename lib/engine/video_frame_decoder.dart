import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';

import 'video_frame_timeline.dart';

/// Runs one FFmpeg or FFprobe command line and reports whether it exited
/// successfully. On a device this is FFmpegKit; tests inject the system
/// binaries, so both run the exact argument lists built below.
typedef MediaToolRunner = Future<bool> Function(List<String> arguments);

class VideoFrameDecodeException implements Exception {
  const VideoFrameDecodeException(this.message);

  final String message;

  @override
  String toString() => 'VideoFrameDecodeException: $message';
}

/// One decoded video frame as straight (non-premultiplied) RGBA bytes of
/// exactly [width]×[height] pixels: the source frame, rotated as its
/// metadata says, scaled to fit with its aspect ratio kept, centred, and
/// padded with transparent black. This is the placement the timeline uses
/// when it rasterises an image material onto the canvas. Opaque pixels and
/// transparent-black padding read the same premultiplied or not.
class DecodedVideoFrame {
  const DecodedVideoFrame({
    required this.rgba,
    required this.width,
    required this.height,
    required this.frameIndex,
  });

  final Uint8List rgba;
  final int width;
  final int height;

  /// Index into the material's [VideoFrameTimeline].
  final int frameIndex;
}

/// Decodes video material frames for both the timeline preview and the
/// offline export. Implementations must return the frame the
/// [VideoFrameTimeline] selects, never a neighbouring or placeholder frame.
abstract interface class VideoFrameDecoder {
  /// Reads the frame presentation table of [path]. Throws
  /// [VideoFrameDecodeException] when the file is missing, unreadable or has
  /// no video frames.
  Future<VideoFrameTimeline> probe(String path);

  /// Decodes frame [frameIndex] of [path] at [width]×[height].
  Future<DecodedVideoFrame> decode({
    required String path,
    required VideoFrameTimeline timeline,
    required int frameIndex,
    required int width,
    required int height,
  });
}

/// swscale flags fixed for every decode so that preview and export scale
/// identically; `accurate_rnd` and `bitexact` avoid platform-specific
/// rounding shortcuts.
const videoFrameScaleFlags = 'bicubic+accurate_rnd+full_chroma_int+bitexact';

/// FFprobe arguments that write the packet presentation table of the first
/// video stream as JSON to [outputPath].
List<String> videoFrameProbeArguments(String path, String outputPath) => [
  '-v',
  'error',
  '-select_streams',
  'v:0',
  '-show_entries',
  'packet=pts,flags'
      ':stream=time_base,width,height'
      ':stream_tags=rotate'
      ':stream_side_data=rotation'
      ':format=start_time',
  '-of',
  'json',
  '-o',
  outputPath,
  '-i',
  path,
];

/// FFmpeg arguments that write one frame, selected by an accurate input
/// seek to [seekTime], as raw RGBA of exactly [width]×[height] to
/// [outputPath]. See [DecodedVideoFrame] for the placement.
List<String> videoFrameDecodeArguments({
  required String path,
  required Duration seekTime,
  required int width,
  required int height,
  required String outputPath,
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
  '-frames:v',
  '1',
  '-an',
  '-sn',
  '-dn',
  '-vf',
  'scale=$width:$height:force_original_aspect_ratio=decrease'
      ':flags=$videoFrameScaleFlags,'
      'format=rgba,'
      'pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black@0',
  '-f',
  'rawvideo',
  '-pix_fmt',
  'rgba',
  '-y',
  outputPath,
];

/// Seconds with exactly six decimals, built from integers so no binary
/// floating-point rounding enters the seek time.
String formatSeekSeconds(Duration time) {
  final micros = time.inMicroseconds;
  if (micros < 0) throw ArgumentError.value(time, 'time', 'must be >= 0');
  final seconds = micros ~/ Duration.microsecondsPerSecond;
  final fraction = micros % Duration.microsecondsPerSecond;
  return '$seconds.${fraction.toString().padLeft(6, '0')}';
}

class FfmpegVideoFrameDecoder implements VideoFrameDecoder {
  FfmpegVideoFrameDecoder({
    required this.workDirectory,
    required this.runFfmpeg,
    required this.runFfprobe,
  });

  /// The decoder FFmpegKit provides on the device.
  factory FfmpegVideoFrameDecoder.ffmpegKit(Directory workDirectory) =>
      FfmpegVideoFrameDecoder(
        workDirectory: workDirectory,
        runFfmpeg: (arguments) async {
          final session = await FFmpegKit.executeWithArguments(arguments);
          return ReturnCode.isSuccess(await session.getReturnCode());
        },
        runFfprobe: (arguments) async {
          final session = await FFprobeKit.executeWithArguments(arguments);
          return ReturnCode.isSuccess(await session.getReturnCode());
        },
      );

  /// Holds each command's output file only until it has been read.
  final Directory workDirectory;
  final MediaToolRunner runFfmpeg;
  final MediaToolRunner runFfprobe;

  static int _sequence = 0;

  Future<File> _scratchFile(String extension) async {
    await workDirectory.create(recursive: true);
    final name =
        'video_frame_${DateTime.now().microsecondsSinceEpoch}_'
        '${_sequence++}.$extension';
    return File('${workDirectory.path}/$name');
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A leftover scratch file is removed with its job directory.
    }
  }

  @override
  Future<VideoFrameTimeline> probe(String path) async {
    if (!await File(path).exists()) {
      throw VideoFrameDecodeException('Video material file is missing: $path');
    }
    final output = await _scratchFile('json');
    try {
      final ok = await runFfprobe(videoFrameProbeArguments(path, output.path));
      if (!ok || !await output.exists()) {
        throw VideoFrameDecodeException('Could not probe video: $path');
      }
      final timeline = VideoFrameTimeline.parseFfprobeJson(
        await output.readAsString(),
      );
      if (timeline == null || timeline.isEmpty) {
        throw VideoFrameDecodeException('No video frames in: $path');
      }
      return timeline;
    } finally {
      await _deleteQuietly(output);
    }
  }

  @override
  Future<DecodedVideoFrame> decode({
    required String path,
    required VideoFrameTimeline timeline,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Frame size must be positive: ${width}x$height');
    }
    final seekTime = timeline.seekTimeFor(frameIndex);
    if (!await File(path).exists()) {
      throw VideoFrameDecodeException('Video material file is missing: $path');
    }
    final output = await _scratchFile('rgba');
    try {
      final ok = await runFfmpeg(
        videoFrameDecodeArguments(
          path: path,
          seekTime: seekTime,
          width: width,
          height: height,
          outputPath: output.path,
        ),
      );
      final expected = width * height * 4;
      final bytes = ok && await output.exists()
          ? await output.readAsBytes()
          : null;
      if (bytes == null || bytes.length != expected) {
        throw VideoFrameDecodeException(
          'Could not decode frame $frameIndex of $path '
          '(${bytes?.length ?? 0} of $expected bytes)',
        );
      }
      return DecodedVideoFrame(
        rgba: bytes,
        width: width,
        height: height,
        frameIndex: frameIndex,
      );
    } finally {
      await _deleteQuietly(output);
    }
  }
}
