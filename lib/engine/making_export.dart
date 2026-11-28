import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'corner_logo.dart';
import 'export_engine.dart';
import 'making_log.dart';
import 'making_player.dart';
import 'making_video.dart';

/// メイキング動画の書き出しの形式。名前（[Enum.name]）がそのままファイルの
/// 拡張子。
enum MakingExportFormat { mp4, gif, webm, avi }

/// How [MakingFrames.writeFrames] gives the picture records of earlier
/// versions.
enum MakingPictureMode {
  /// The file as it is, whatever its size (the caller resizes it).
  asIs,

  /// The file as it is when it has the size asked for, else a PNG of it.
  sameSize,

  /// Always a PNG of the size asked for.
  png,
}

/// A video file that shows frames [start]…[start]+[frames]−1 of a making.
class MakingVideoSpan {
  const MakingVideoSpan({
    required this.start,
    required this.frames,
    required this.path,
    required this.width,
    required this.height,
    required this.fps,
  });

  final int start;
  final int frames;
  final String path;
  final int width;
  final int height;
  final int fps;
}

/// The frames of a making video, made as they are written.
abstract interface class MakingFrames {
  int get length;

  /// The size of the making's frames.
  int get width;
  int get height;

  /// The video files that already show some of the frames.
  List<MakingVideoSpan> get videoSpans;

  /// Writes frames [from]…[to]−1 as image files of exactly [width]×[height]
  /// in [directory] (the picture records as [pictures] says) and returns
  /// them in order.
  Future<List<String>> writeFrames(
    Directory directory,
    int from,
    int to, {
    required int width,
    required int height,
    MakingPictureMode pictures,
  });
}

/// A source of making frames that can write a chosen set of them at once
/// (the chosen frames of a video segment are read in one pass).
abstract interface class MakingFramePicker {
  /// Writes frames [indices] (increasing) as image files of exactly
  /// [width]×[height] in [directory] and returns them in order.
  Future<List<String>> writePickedFrames(
    Directory directory,
    List<int> indices, {
    required int width,
    required int height,
    MakingPictureMode pictures,
  });
}

/// Frames [indices] (increasing) of [source]: a shorter making video.
class MakingFrameSelection implements MakingFrames {
  MakingFrameSelection(this.source, this.indices);

  /// [count] frames of [source] spread evenly over it, the first and the
  /// last frame included (the finished picture ends the video).
  factory MakingFrameSelection.evenly(MakingFrames source, int count) {
    final total = source.length;
    if (count < 1 || count >= total) {
      return MakingFrameSelection(source, [for (var i = 0; i < total; i++) i]);
    }
    if (count == 1) return MakingFrameSelection(source, [total - 1]);
    return MakingFrameSelection(source, [
      for (var i = 0; i < count; i++) (i * (total - 1) / (count - 1)).round(),
    ]);
  }

  final MakingFrames source;
  final List<int> indices;

  @override
  int get length => indices.length;

  @override
  int get width => source.width;

  @override
  int get height => source.height;

  /// The segments show every frame, not the chosen ones.
  @override
  List<MakingVideoSpan> get videoSpans => const [];

  @override
  Future<List<String>> writeFrames(
    Directory directory,
    int from,
    int to, {
    required int width,
    required int height,
    MakingPictureMode pictures = MakingPictureMode.sameSize,
  }) async {
    final picked = indices.sublist(from, to);
    final source = this.source;
    if (source is MakingFramePicker) {
      return (source as MakingFramePicker).writePickedFrames(
        directory,
        picked,
        width: width,
        height: height,
        pictures: pictures,
      );
    }
    final paths = <String>[];
    var i = 0;
    while (i < picked.length) {
      var j = i + 1;
      while (j < picked.length && picked[j] == picked[j - 1] + 1) {
        j++;
      }
      paths.addAll(
        await source.writeFrames(
          directory,
          picked[i],
          picked[j - 1] + 1,
          width: width,
          height: height,
          pictures: pictures,
        ),
      );
      i = j;
    }
    return paths;
  }
}

/// メイキング動画（記録の1コマずつを順に並べた動画）の書き出し。
abstract final class MakingExport {
  /// メイキング動画のfps。
  static const int fps = MakingLog.fps;

  /// GIFの1コマの長さ（1/100秒単位）。
  static const int _gifFrameCentiseconds = 100 ~/ fps;

  /// GIFはエンコーダーがコマを持ち続けるので、この数ほどに間引く。
  static const int _gifTargetFrames = 50;

  /// GIFのコマの長辺の上限。
  static const int _gifMaxSide = 360;

  /// One encoder pass takes at most this many frames, and the frames waiting
  /// for it at most [maxChunkBytes] of files: a long making is encoded in
  /// parts that are put together without encoding them again.
  static const int maxChunkFrames = 240;
  static const int maxChunkBytes = 48 * 1024 * 1024;

  /// 公式エンドマークを付ける形式。作品の書き出しと同じく、GIFには付けず、
  /// 代わりに隅へNIARIMのロゴを入れる（[CornerLogoStamp]）。
  static bool carriesOfficialEndCard(MakingExportFormat format) =>
      format != MakingExportFormat.gif;

  /// 書き出しで選べるいちばん短い本編の長さ（秒）。
  static const int shortestSeconds = 1;

  /// [count]枚の記録を[format]で書き出すとき、選べる本編の長さの上限（秒）。
  /// メイキングは1回の操作を1コマにして[fps]で流すので、長さは操作の数で
  /// 決まる。書き出しでは、[shortestSeconds]からこの元の長さまでを1秒ごとに
  /// 選べる（長くはしない。上限を選ぶと元のまま）。GIFはもともと短く
  /// 間引くので選ばず、元の長さが[shortestSeconds]以下のときも選ばない（null）。
  static int? lengthLimitSeconds(int count, MakingExportFormat format) {
    if (format == MakingExportFormat.gif) return null;
    final original = count ~/ fps;
    return original > shortestSeconds ? original : null;
  }

  /// 本編の長さを[maxSeconds]秒（nullか[lengthLimitSeconds]以上なら元のまま）
  /// にしたとき書き出す記録の枚数。元の枚数より多くはならない。
  static int exportedCount(
    int count,
    MakingExportFormat format,
    int? maxSeconds,
  ) {
    final limit = lengthLimitSeconds(count, format);
    if (maxSeconds == null || limit == null || maxSeconds >= limit) {
      return count;
    }
    return math.max(shortestSeconds, maxSeconds) * fps;
  }

  /// GIFで使う記録の間隔（[count]枚から何枚ごとに1枚使うか）。
  static int gifStep(int count) =>
      (count / _gifTargetFrames).ceil().clamp(1, math.max(1, count)).toInt();

  /// [count]枚の記録を[format]で書き出したときの本編（エンドマークを除く）の
  /// 長さ（秒、切り捨て）。
  static int bodySeconds(int count, MakingExportFormat format) {
    if (format != MakingExportFormat.gif) return count ~/ fps;
    final step = gifStep(count);
    var frames = (count / step).ceil();
    if (count > 0 && (count - 1) % step != 0) frames++;
    return frames * _gifFrameCentiseconds ~/ 100;
  }

  /// [frames]（または記録の画像[snapshotPaths]。表示順）を[format]で
  /// [outputPath]へ書き出す。[officialMark]が真のときは、作品の書き出しと
  /// 同じ公式エンドマーク（[ExportEngine.officialEndCardSeconds]秒）を最後に
  /// 足す。GIFではエンドマークの代わりに、どのコマにも隅へNIARIMのロゴを
  /// 入れる。その隅は[watermarkAreas]（利用者のウォーターマークの描かれた所。
  /// キャンバスに対する0〜1の割合）を避けて選ぶ。MP4では、動画になった記録は
  /// エンコードし直さずにつなぐ。[maxSeconds]（元の長さより短い秒数）を
  /// 渡すと、本編がその長さになるよう、記録から最初と最後を含めて均等に
  /// コマを選ぶ（1秒のコマの数は変えない）。
  static Future<void> export({
    List<String>? snapshotPaths,
    MakingFrames? frames,
    required MakingExportFormat format,
    required String outputPath,
    required bool officialMark,
    List<ui.Rect> watermarkAreas = const [],
    ExportEngine? engine,
    void Function(int done, int total)? onProgress,
    MakingVideoTools? tools,
    int? maxSeconds,
  }) async {
    if (frames == null && (snapshotPaths == null || snapshotPaths.isEmpty)) {
      throw ArgumentError.value(snapshotPaths, 'snapshotPaths');
    }
    var source = frames ?? await MakingPictureFrames.of(snapshotPaths!);
    final count = exportedCount(source.length, format, maxSeconds);
    if (count < source.length) {
      source = MakingFrameSelection.evenly(source, count);
    }
    await _export(
      source,
      format: format,
      outputPath: outputPath,
      officialMark: officialMark,
      watermarkAreas: watermarkAreas,
      engine: engine,
      onProgress: onProgress,
      video: tools ?? MakingVideoTools.instance,
    );
  }

  static Future<void> _export(
    MakingFrames frames, {
    required MakingExportFormat format,
    required String outputPath,
    required bool officialMark,
    required List<ui.Rect> watermarkAreas,
    required ExportEngine? engine,
    required void Function(int done, int total)? onProgress,
    required MakingVideoTools video,
  }) async {
    if (frames.length == 0) throw ArgumentError.value(frames, 'frames');
    final width = frames.width;
    final height = frames.height;
    final staging = await _stagingDirectory();
    try {
      if (format == MakingExportFormat.gif) {
        await _exportGif(
          frames,
          staging,
          outputPath,
          cornerLogo: officialMark,
          watermarkAreas: watermarkAreas,
          onProgress: onProgress,
        );
        return;
      }
      String? endCard;
      if (officialMark) {
        final png = await (engine ?? ExportEngine()).renderOfficialEndCardPng(
          width: width,
          height: height,
        );
        endCard = '${staging.path}/endcard.png';
        await File(endCard).writeAsBytes(png, flush: true);
      }
      const endCardFrames = fps * ExportEngine.officialEndCardSeconds;
      final parts = <String>[];
      final partFrames = <int>[];
      var endCardAdded = false;
      Future<void> encode(List<String> paths, int first) async {
        final framePaths = [...paths];
        if (endCard != null &&
            !endCardAdded &&
            first + paths.length >= frames.length) {
          framePaths.addAll(List.filled(endCardFrames, endCard));
          endCardAdded = true;
        }
        if (framePaths.isEmpty) return;
        final part =
            '${staging.path}/part_${parts.length.toString().padLeft(4, '0')}.'
            '${format.name}';
        if (format == MakingExportFormat.mp4) {
          await video.encodeMp4(
            framePaths: framePaths,
            fps: fps,
            width: width,
            height: height,
            outputPath: part,
          );
        } else {
          await _encodeWithFfmpeg(video, framePaths, first, format, part);
        }
        parts.add(part);
        partFrames.add(framePaths.length);
      }

      // The video segments already are MP4 parts of this size.
      final spans = {
        if (format == MakingExportFormat.mp4)
          for (final span in frames.videoSpans)
            if (span.width == width && span.height == height && span.fps == fps)
              span.start: span,
      };
      final pictures = format == MakingExportFormat.mp4
          ? MakingPictureMode.sameSize
          : MakingPictureMode.png;
      var i = 0;
      var chunk = <String>[];
      var chunkStart = 0;
      var chunkBytes = 0;
      final written = <String>{};
      Future<void> flushChunk() async {
        await encode(chunk, chunkStart);
        for (final path in chunk) {
          if (written.remove(path)) await _delete(File(path));
        }
        chunk = [];
        chunkBytes = 0;
      }

      while (i < frames.length) {
        final span = spans[i];
        if (span != null) {
          if (chunk.isNotEmpty) await flushChunk();
          parts.add(span.path);
          partFrames.add(span.frames);
          i += span.frames;
          onProgress?.call(i, frames.length);
          continue;
        }
        if (chunk.isEmpty) chunkStart = i;
        // Up to the next segment, a few frames at a time (one pass reads
        // several frames of a segment).
        var to = math.min(frames.length, i + 16);
        for (final start in spans.keys) {
          if (start > i && start < to) to = start;
        }
        final paths = await frames.writeFrames(
          staging,
          i,
          to,
          width: width,
          height: height,
          pictures: pictures,
        );
        for (final path in paths) {
          if (path.startsWith(staging.path)) {
            written.add(path);
            chunkBytes += await File(path).length();
          }
        }
        chunk.addAll(paths);
        i = to;
        onProgress?.call(i, frames.length);
        if (chunk.length >= maxChunkFrames || chunkBytes >= maxChunkBytes) {
          await flushChunk();
        }
      }
      if (chunk.isNotEmpty || (endCard != null && !endCardAdded)) {
        // The end mark ends the last part (alone after a segment).
        if (chunk.isEmpty) chunkStart = frames.length;
        await flushChunk();
      }
      if (parts.length == 1 && parts.single.startsWith(staging.path)) {
        await _move(File(parts.single), outputPath);
      } else {
        await MakingVideo.concat(
          parts: parts,
          frames: partFrames,
          fps: fps,
          outputPath: outputPath,
          workDirectory: staging,
          tools: video,
        );
      }
    } finally {
      await _removeStaging(staging);
    }
  }

  static Future<void> _encodeWithFfmpeg(
    MakingVideoTools video,
    List<String> framePaths,
    int first,
    MakingExportFormat format,
    String outputPath,
  ) async {
    // The frames in the order and names the frame pattern reads.
    final dir = await Directory(
      '${File(outputPath).parent.path}/'
      'frames_${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    try {
      for (var i = 0; i < framePaths.length; i++) {
        final target = makingFramePath(dir, i);
        try {
          await Link(target).create(framePaths[i]);
        } on FileSystemException {
          await File(framePaths[i]).copy(target);
        }
      }
      final args = <String>[
        '-y',
        '-framerate',
        fps.toString(),
        '-i',
        '${dir.path}/f_%06d.png',
        // YUV 4:2:0 encoders need even dimensions on some devices.
        '-vf',
        'pad=ceil(iw/2)*2:ceil(ih/2)*2',
      ];
      if (format == MakingExportFormat.webm) {
        args.addAll([
          '-c:v',
          'libvpx-vp9',
          '-pix_fmt',
          'yuv420p',
          '-b:v',
          '2M',
        ]);
      } else {
        args.addAll(['-c:v', 'mjpeg', '-q:v', '3', '-pix_fmt', 'yuvj420p']);
      }
      args.add(outputPath);
      if (!await video.runFfmpeg(args)) {
        throw StateError('Video encoder failed for $outputPath.');
      }
    } finally {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Removed with the staging folder.
      }
    }
  }

  static Future<Directory> _stagingDirectory() async {
    final temp = await getTemporaryDirectory();
    final staging = Directory(
      '${temp.path}/niarim_making_export_${DateTime.now().microsecondsSinceEpoch}',
    );
    await staging.create(recursive: true);
    return staging;
  }

  static Future<void> _removeStaging(Directory? staging) async {
    if (staging == null) return;
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } on FileSystemException {
      // A leftover temporary folder does not affect the exported video.
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Removed with the staging folder.
    }
  }

  static Future<void> _move(File from, String to) async {
    try {
      await from.rename(to);
    } on FileSystemException {
      await from.copy(to);
      await _delete(from);
    }
  }

  static img.Image _gifFrame(img.Image decoded) {
    final maxSide = math.max(decoded.width, decoded.height);
    if (maxSide <= _gifMaxSide) return decoded;
    return img.copyResize(
      decoded,
      width: (decoded.width * _gifMaxSide / maxSide)
          .round()
          .clamp(1, _gifMaxSide)
          .toInt(),
      height: (decoded.height * _gifMaxSide / maxSide)
          .round()
          .clamp(1, _gifMaxSide)
          .toInt(),
    );
  }

  static Future<void> _exportGif(
    MakingFrames frames,
    Directory staging,
    String outputPath, {
    required bool cornerLogo,
    required List<ui.Rect> watermarkAreas,
    void Function(int done, int total)? onProgress,
  }) async {
    final encoder = newExportGifEncoder();
    CornerLogoStamp? logo;
    (int, int)? logoFrameSize;
    // The frames made for the GIF are made at its size.
    final scale = math.min(
      1.0,
      _gifMaxSide / math.max(frames.width, frames.height),
    );
    final gifWidth = math.max(2, (frames.width * scale).round());
    final gifHeight = math.max(2, (frames.height * scale).round());
    Future<void> add(int index) async {
      final path = (await frames.writeFrames(
        staging,
        index,
        index + 1,
        width: gifWidth,
        height: gifHeight,
        pictures: MakingPictureMode.asIs,
      )).single;
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (path.startsWith(staging.path)) await _delete(File(path));
      if (decoded == null) return;
      var frame = _gifFrame(decoded);
      if (cornerLogo) {
        // A canvas resized while recording gives snapshots of other sizes.
        if (logoFrameSize != (frame.width, frame.height)) logo = null;
        logoFrameSize = (frame.width, frame.height);
        logo ??= await CornerLogoStamp.render(
          CornerLogoPlacement(
            frame.width,
            frame.height,
            chooseLogoCorner(
              (corner) => fractionalAreasInside(
                watermarkAreas,
                frame.width,
                frame.height,
                CornerLogoPlacement(
                  frame.width,
                  frame.height,
                  corner,
                ).clearArea,
              ),
            ),
          ),
        );
        frame = logo!.stampOnto(frame);
      }
      encoder.addFrame(frame, duration: _gifFrameCentiseconds);
      onProgress?.call(index + 1, frames.length);
    }

    // GIF palette frames remain resident in the encoder. Downsample and cap
    // this format to keep export memory bounded on phones.
    final count = frames.length;
    final step = gifStep(count);
    for (var i = 0; i < count; i += step) {
      await add(i);
    }
    if ((count - 1) % step != 0) await add(count - 1);
    final gif = encoder.finish();
    if (gif == null || gif.isEmpty) {
      throw StateError('GIF encoder returned no data.');
    }
    await File(outputPath).writeAsBytes(gif, flush: true);
  }
}
