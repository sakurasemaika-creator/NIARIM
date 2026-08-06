import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../engine/tile_manager.dart';
import '../models/layer.dart';
import '../models/scene.dart';

typedef ExportProgressCallback = void Function(int currentFrame, int totalFrames);

class ExportEngine {
  /// フレームを合成してRGBA Uint8Listを返す
  Future<Uint8List> renderFrame({
    required List<Layer> layers,
    required TileManager tileManager,
    required int width,
    required int height,
    required int backgroundColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 背景色
    final bgA = (backgroundColor >> 24) & 0xFF;
    final bgR = (backgroundColor >> 16) & 0xFF;
    final bgG = (backgroundColor >> 8) & 0xFF;
    final bgB = backgroundColor & 0xFF;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = ui.Color.fromARGB(bgA, bgR, bgG, bgB),
    );

    // 下のレイヤーから順に合成（layersは上が先頭なので逆順）
    for (final layer in layers.reversed) {
      if (!layer.isVisible || layer.type != LayerType.normal) continue;
      final image = await tileManager.compositeLayerToImage(layer.id);
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
      image.dispose();
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();
    return byteData!.buffer.asUint8List();
  }

  Future<String> exportMp4({
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    required int width,
    required int height,
    required int backgroundColor,
    ExportProgressCallback? onProgress,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final framesDir = Directory('${tmpDir.path}/export_frames');
    if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
    framesDir.createSync();

    int globalIndex = 0;
    int totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);

    for (final scene in scenes) {
      for (final frame in scene.frames) {
        final rgba = await renderFrame(
          layers: frame.layers,
          tileManager: tileManager,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
        );
        final pngBytes = img.encodePng(
          img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4),
        );
        final file = File('${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png');
        await file.writeAsBytes(pngBytes);
        onProgress?.call(globalIndex + 1, totalFrames);
        globalIndex++;
      }
    }

    final outputPath = '${tmpDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final session = await FFmpegKit.execute(
      '-y -framerate $fps -i "${framesDir.path}/frame_%06d.png" '
      '-c:v libx264 -pix_fmt yuv420p "$outputPath"',
    );
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('FFmpeg failed: ${await session.getOutput()}');
    }
    framesDir.deleteSync(recursive: true);
    return outputPath;
  }

  Future<String> exportGif({
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    required int width,
    required int height,
    required int backgroundColor,
    ExportProgressCallback? onProgress,
  }) async {
    // image v4: アニメーションGIFはimg.Imageにフレームを追加する
    img.Image? gifImage;
    int totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);
    int index = 0;
    final delayMs = (1000 / fps).round();

    for (final scene in scenes) {
      for (final frame in scene.frames) {
        final rgba = await renderFrame(
          layers: frame.layers,
          tileManager: tileManager,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
        );
        final imgFrame = img.Image.fromBytes(
          width: width, height: height, bytes: rgba.buffer, numChannels: 4,
        );
        imgFrame.frameDuration = delayMs;
        if (gifImage == null) {
          gifImage = imgFrame;
        } else {
          gifImage.addFrame(imgFrame);
        }
        onProgress?.call(++index, totalFrames);
      }
    }

    final gifBytes = img.encodeGif(gifImage!);
    final tmpDir = await getTemporaryDirectory();
    final outputPath = '${tmpDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.gif';
    await File(outputPath).writeAsBytes(gifBytes);
    return outputPath;
  }

  Future<String> exportWebm({
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    required int width,
    required int height,
    required int backgroundColor,
    ExportProgressCallback? onProgress,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final framesDir = Directory('${tmpDir.path}/export_webm_frames');
    if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
    framesDir.createSync();

    int globalIndex = 0;
    int totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);

    for (final scene in scenes) {
      for (final frame in scene.frames) {
        final rgba = await renderFrame(
          layers: frame.layers,
          tileManager: tileManager,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
        );
        final pngBytes = img.encodePng(
          img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4),
        );
        final file = File('${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png');
        await file.writeAsBytes(pngBytes);
        onProgress?.call(globalIndex + 1, totalFrames);
        globalIndex++;
      }
    }

    final outputPath = '${tmpDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.webm';
    final session = await FFmpegKit.execute(
      '-y -framerate $fps -i "${framesDir.path}/frame_%06d.png" '
      '-c:v libvpx-vp9 -pix_fmt yuva420p "$outputPath"',
    );
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('FFmpeg failed: ${await session.getOutput()}');
    }
    framesDir.deleteSync(recursive: true);
    return outputPath;
  }
}
