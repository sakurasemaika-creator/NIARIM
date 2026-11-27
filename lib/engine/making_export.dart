import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../services/hw_video_encoder.dart';
import 'export_engine.dart';

/// メイキング動画の書き出しの形式。名前（[Enum.name]）がそのままファイルの
/// 拡張子。
enum MakingExportFormat { mp4, gif, webm, avi }

/// メイキング動画（記録したキャンバスの画像を順に並べた動画）の書き出し。
abstract final class MakingExport {
  /// メイキング動画のfps。
  static const int fps = 8;

  /// GIFの1コマの長さ（1/100秒単位）。
  static const int _gifFrameCentiseconds = 100 ~/ fps;

  /// GIFはエンコーダーがコマを持ち続けるので、この数ほどに間引く。
  static const int _gifTargetFrames = 50;

  /// GIFのコマの長辺の上限。
  static const int _gifMaxSide = 360;

  /// 公式エンドマークを付ける形式。作品の書き出しと同じく、GIFには付けない。
  static bool carriesOfficialEndCard(MakingExportFormat format) =>
      format != MakingExportFormat.gif;

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

  /// [snapshotPaths]（記録の画像。表示順）を[format]で[outputPath]へ書き出す。
  /// [appendEndCard]が真のときは、作品の書き出しと同じ公式エンドマーク
  /// （[ExportEngine.officialEndCardSeconds]秒）を最後に足す。
  static Future<void> export({
    required List<String> snapshotPaths,
    required MakingExportFormat format,
    required String outputPath,
    required bool appendEndCard,
    ExportEngine? engine,
  }) async {
    if (snapshotPaths.isEmpty) {
      throw ArgumentError.value(snapshotPaths, 'snapshotPaths');
    }
    final first = img.decodeImage(
      await File(snapshotPaths.first).readAsBytes(),
    );
    if (first == null) {
      throw StateError('Making snapshot image is unreadable.');
    }
    final width = first.width;
    final height = first.height;
    final endCard = appendEndCard && carriesOfficialEndCard(format)
        ? await (engine ?? ExportEngine()).renderOfficialEndCardPng(
            width: width,
            height: height,
          )
        : null;
    const endCardFrames = fps * ExportEngine.officialEndCardSeconds;

    switch (format) {
      case MakingExportFormat.mp4:
        Directory? staging;
        try {
          final framePaths = [...snapshotPaths];
          if (endCard != null) {
            staging = await _stagingDirectory();
            final endCardFile = File('${staging.path}/endcard.png');
            await endCardFile.writeAsBytes(endCard, flush: true);
            framePaths.addAll(List.filled(endCardFrames, endCardFile.path));
          }
          await HardwareVideoEncoder.encodeMp4(
            framePaths: framePaths,
            fps: fps,
            width: width,
            height: height,
            outputPath: outputPath,
          );
        } finally {
          await _removeStaging(staging);
        }
      case MakingExportFormat.gif:
        await _exportGif(snapshotPaths, outputPath);
      case MakingExportFormat.webm:
      case MakingExportFormat.avi:
        final staging = await _stagingDirectory();
        try {
          for (var i = 0; i < snapshotPaths.length; i++) {
            await File(snapshotPaths[i]).copy(_framePath(staging, i));
          }
          if (endCard != null) {
            // The frame pattern reads JPEG files, like the snapshots.
            final decoded = img.decodePng(endCard)!;
            final jpeg = img.encodeJpg(decoded, quality: 95);
            for (var i = 0; i < endCardFrames; i++) {
              await File(
                _framePath(staging, snapshotPaths.length + i),
              ).writeAsBytes(jpeg);
            }
          }
          final args = <String>[
            '-y',
            '-framerate',
            fps.toString(),
            '-i',
            '${staging.path}/frame_%06d.jpg',
          ];
          // YUV 4:2:0 encoders need even dimensions on some devices.
          args.addAll(['-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2']);
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
          final session = await FFmpegKit.executeWithArguments(args);
          if (!ReturnCode.isSuccess(await session.getReturnCode())) {
            throw StateError(
              'Video encoder failed: ${await session.getOutput() ?? ''}',
            );
          }
        } finally {
          await _removeStaging(staging);
        }
    }
  }

  static String _framePath(Directory staging, int index) =>
      '${staging.path}/frame_${index.toString().padLeft(6, '0')}.jpg';

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
    List<String> snapshotPaths,
    String outputPath,
  ) async {
    final encoder = newExportGifEncoder();
    // GIF palette frames remain resident in the encoder. Downsample and cap
    // this format to keep export memory bounded on phones.
    final step = gifStep(snapshotPaths.length);
    for (var i = 0; i < snapshotPaths.length; i += step) {
      final decoded = img.decodeImage(
        await File(snapshotPaths[i]).readAsBytes(),
      );
      if (decoded == null) continue;
      encoder.addFrame(_gifFrame(decoded), duration: _gifFrameCentiseconds);
    }
    if ((snapshotPaths.length - 1) % step != 0) {
      final last = img.decodeImage(
        await File(snapshotPaths.last).readAsBytes(),
      );
      if (last != null) {
        encoder.addFrame(_gifFrame(last), duration: _gifFrameCentiseconds);
      }
    }
    final gif = encoder.finish();
    if (gif == null || gif.isEmpty) {
      throw StateError('GIF encoder returned no data.');
    }
    await File(outputPath).writeAsBytes(gif, flush: true);
  }
}
