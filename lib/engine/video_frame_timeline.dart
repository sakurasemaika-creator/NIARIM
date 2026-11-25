import 'dart:convert';

/// The presentation timestamps of one video material's frames, and the one
/// rule both the timeline preview and the offline export use to choose which
/// decoded frame belongs to a source time.
///
/// Timestamps are microseconds from the container's start (FFmpeg's `-ss`
/// origin), sorted and unique. The table comes from the demuxed packets, so
/// it does not depend on a nominal frame rate: a variable-frame-rate video
/// and a video whose rate is not reported select frames the same way.
///
/// Selection rule: the frame shown at time `t` is the last frame whose
/// presentation time is at most `t + selectionTolerance`. Before the first
/// frame the first frame is shown; after the last frame the last frame is
/// held. The tolerance absorbs the rounding of millisecond container time
/// bases and of the project-FPS to microsecond conversion, and stays far
/// below the frame interval of any real video (≥ 4 ms at 240 fps).
class VideoFrameTimeline {
  VideoFrameTimeline._(
    List<int> presentationMicros, {
    this.displayWidth,
    this.displayHeight,
  }) : _presentationMicros = List.unmodifiable(presentationMicros);

  /// Builds a timeline from presentation times (microseconds from the
  /// container start). Negative times cannot be reached by an FFmpeg seek
  /// (they lie before the container origin), so they are dropped, as are
  /// duplicates.
  factory VideoFrameTimeline.fromPresentationMicros(
    Iterable<int> presentationMicros, {
    int? displayWidth,
    int? displayHeight,
  }) {
    final sorted = presentationMicros.where((t) => t >= 0).toSet().toList()
      ..sort();
    return VideoFrameTimeline._(
      sorted,
      displayWidth: displayWidth,
      displayHeight: displayHeight,
    );
  }

  static const selectionTolerance = Duration(microseconds: 500);

  final List<int> _presentationMicros;

  /// Display size after rotation metadata, when the probe reported it.
  /// Informational only (e.g. for thumbnail cell sizing); decoding lets
  /// FFmpeg apply the rotation itself.
  final int? displayWidth;
  final int? displayHeight;

  int get frameCount => _presentationMicros.length;

  bool get isEmpty => _presentationMicros.isEmpty;

  Duration presentationTimeOf(int index) =>
      Duration(microseconds: _presentationMicros[index]);

  /// The index of the frame shown at [sourceTime], or null when the video
  /// has no frames.
  int? frameIndexAt(Duration sourceTime) {
    if (_presentationMicros.isEmpty) return null;
    final limit = sourceTime.inMicroseconds + selectionTolerance.inMicroseconds;
    // Last index with pts <= limit.
    var low = 0;
    var high = _presentationMicros.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_presentationMicros[mid] <= limit) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found < 0 ? 0 : found;
  }

  /// The `-ss` time that makes FFmpeg output exactly frame [index].
  ///
  /// FFmpeg's accurate input seek outputs the first frame whose timestamp is
  /// at or after the seek time (measured in
  /// `test/video_frame_ffmpeg_decoder_test.dart`). Seeking to the midpoint
  /// between the previous frame and this one selects this frame with half a
  /// frame interval of margin on both sides, so rounding of either timestamp
  /// (start-time offset, microsecond and decimal conversion, time-base
  /// rescaling) cannot move the result to a neighbouring frame.
  Duration seekTimeFor(int index) {
    RangeError.checkValidIndex(index, _presentationMicros, 'index');
    if (index == 0) return Duration.zero;
    final previous = _presentationMicros[index - 1];
    final current = _presentationMicros[index];
    return Duration(microseconds: previous + ((current - previous) >> 1));
  }

  /// Parses the JSON written by `videoFrameProbeArguments`. Returns null
  /// when the file has no video stream or its time base is unusable.
  static VideoFrameTimeline? parseFfprobeJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final streams = decoded['streams'];
    if (streams is! List || streams.isEmpty || streams.first is! Map) {
      return null;
    }
    final stream = streams.first as Map;
    final timeBase = _parseRational(stream['time_base']);
    if (timeBase == null) return null;
    final (numerator, denominator) = timeBase;

    final format = decoded['format'];
    final startSeconds = format is Map
        ? double.tryParse('${format['start_time']}')
        : null;
    final startMicros = startSeconds == null || !startSeconds.isFinite
        ? 0
        : (startSeconds * 1000000).round();

    final presentation = <int>[];
    final packets = decoded['packets'];
    if (packets is List) {
      for (final packet in packets) {
        if (packet is! Map) continue;
        final flags = packet['flags'];
        // 'D': the demuxer marks packets an edit list discards; players
        // never show them and FFmpeg drops them on decode.
        if (flags is String && flags.contains('D')) continue;
        final pts = packet['pts'];
        if (pts is! int) continue;
        final micros = (pts * numerator * 1000000 / denominator).round();
        presentation.add(micros - startMicros);
      }
    }

    var width = stream['width'] is int ? stream['width'] as int : null;
    var height = stream['height'] is int ? stream['height'] as int : null;
    final rotation = _rotationOf(stream);
    if (rotation != null && rotation % 180 != 0) {
      final swap = width;
      width = height;
      height = swap;
    }
    return VideoFrameTimeline.fromPresentationMicros(
      presentation,
      displayWidth: width,
      displayHeight: height,
    );
  }

  static (int, int)? _parseRational(Object? value) {
    if (value is! String) return null;
    final parts = value.split('/');
    if (parts.length != 2) return null;
    final numerator = int.tryParse(parts[0]);
    final denominator = int.tryParse(parts[1]);
    if (numerator == null ||
        denominator == null ||
        numerator <= 0 ||
        denominator <= 0) {
      return null;
    }
    return (numerator, denominator);
  }

  static int? _rotationOf(Map stream) {
    final sideData = stream['side_data_list'];
    if (sideData is List) {
      for (final entry in sideData) {
        if (entry is Map && entry['rotation'] is num) {
          return (entry['rotation'] as num).round();
        }
      }
    }
    final tags = stream['tags'];
    if (tags is Map) return int.tryParse('${tags['rotate']}');
    return null;
  }
}
