import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../engine/camera_engine.dart';
import '../engine/filter_engine.dart';
import '../engine/layer_compositor.dart';
import '../engine/tile_manager.dart';
import '../models/camera_keyframe.dart';
import '../models/effect_filter_instance.dart';
import '../models/layer.dart';
import '../models/scene.dart';

typedef ExportProgressCallback = void Function(int currentFrame, int totalFrames);

class ExportEngine {
  final CameraEngine _cameraEngine = CameraEngine();
  final FilterEngine _filterEngine = FilterEngine();

  /// フレームを合成してRGBA Uint8Listを返す。
  ///
  /// [drawingWidth]・[drawingHeight]は描画領域全体のサイズ（描画領域倍率を
  /// 反映済み）、[width]・[height]は書き出しサイズ。描画領域が書き出し領域より
  /// 広い場合（仕様書26）は、描画領域の中央にある書き出しサイズ分だけを
  /// 切り出す（キャンバス表示の赤枠と同じ中央配置）。
  /// 合成対象はTileManagerに実ピクセルデータを持つレイヤー種別（通常・
  /// 自動塗り用線画・自動塗り）全てで、不透明度・ブレンドモード・
  /// クリッピングを反映する（仕様書16）。[cameraKeyframes]が設定されている
  /// 場合はカメラのXY移動・拡大・回転を、[effectFilters]が設定されている場合は
  /// 演出フィルターを書き出し結果へ反映する（仕様書05・18）。
  Future<Uint8List> renderFrame({
    required List<Layer> layers,
    required TileManager tileManager,
    required String sceneId,
    required int frameIndex,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    List<CameraKeyframe> cameraKeyframes = const [],
    List<EffectFilterInstance> effectFilters = const [],
  }) async {
    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => frameLayerKey(sceneId, frameIndex, l.id),
      drawingWidth,
      drawingHeight,
    );

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

    // 描画領域の中央から書き出しサイズ分だけ切り出す（赤枠＝書き出し範囲）
    final offsetX = (drawingWidth - width) / 2;
    final offsetY = (drawingHeight - height) / 2;
    final kf = _cameraEngine.valueAt(cameraKeyframes, frameIndex);
    canvas.save();
    _cameraEngine.apply(canvas, kf, width.toDouble(), height.toDouble());
    canvas.drawImage(fullImage, ui.Offset(-offsetX, -offsetY), ui.Paint());
    canvas.restore();
    fullImage.dispose();

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();
    final rgba = byteData!.buffer.asUint8List();
    if (effectFilters.isEmpty) return rgba;
    return _filterEngine.applyEffectFilters(rgba, width, height, effectFilters, frameIndex);
  }

  Future<String> exportMp4({
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    required int drawingWidth,
    required int drawingHeight,
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
          sceneId: scene.id,
          frameIndex: frame.index,
          drawingWidth: drawingWidth,
          drawingHeight: drawingHeight,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          cameraKeyframes: scene.cameraKeyframes,
          effectFilters: scene.effectFilters,
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
    required int drawingWidth,
    required int drawingHeight,
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
          sceneId: scene.id,
          frameIndex: frame.index,
          drawingWidth: drawingWidth,
          drawingHeight: drawingHeight,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          cameraKeyframes: scene.cameraKeyframes,
          effectFilters: scene.effectFilters,
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
    required int drawingWidth,
    required int drawingHeight,
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
          sceneId: scene.id,
          frameIndex: frame.index,
          drawingWidth: drawingWidth,
          drawingHeight: drawingHeight,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          cameraKeyframes: scene.cameraKeyframes,
          effectFilters: scene.effectFilters,
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

  /// 無料版：本編動画の末尾へMIRANIMAロゴのエンドカード（約5秒）を自動追加する（仕様書06・13）。
  /// エンドカード素材は都度FFmpegで単色背景＋テキストのプレースホルダーとして生成する。
  /// 生成・結合に失敗した場合は書き出し自体を失敗させず、本編動画をそのまま返す。
  Future<String> appendEndCard({
    required String videoPath,
    required String format, // 'mp4' | 'webm'
    required int width,
    required int height,
    int logoDurationSeconds = 5,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final endCardPath =
        '${tmpDir.path}/endcard_${DateTime.now().millisecondsSinceEpoch}.$format';
    final codecArgs = format == 'webm'
        ? '-c:v libvpx-vp9 -pix_fmt yuva420p'
        : '-c:v libx264 -pix_fmt yuv420p';

    final genSession = await FFmpegKit.execute(
      '-y -f lavfi -i "color=c=black:s=${width}x$height:d=$logoDurationSeconds:r=30" '
      '-vf "drawtext=text=\'MIRANIMA\':fontcolor=white:fontsize=${(width * 0.08).round()}:'
      'x=(w-text_w)/2:y=(h-text_h)/2" $codecArgs "$endCardPath"',
    );
    if (!ReturnCode.isSuccess(await genSession.getReturnCode())) {
      return videoPath;
    }

    final outputPath =
        '${tmpDir.path}/output_endcard_${DateTime.now().millisecondsSinceEpoch}.$format';
    final concatSession = await FFmpegKit.execute(
      '-y -i "$videoPath" -i "$endCardPath" '
      '-filter_complex "[0:v]scale=$width:$height,setsar=1[v0];[1:v]scale=$width:$height,setsar=1[v1];'
      '[v0][v1]concat=n=2:v=1:a=0[outv]" '
      '-map "[outv]" $codecArgs "$outputPath"',
    );
    if (!ReturnCode.isSuccess(await concatSession.getReturnCode())) {
      return videoPath;
    }
    try {
      File(endCardPath).deleteSync();
      File(videoPath).deleteSync();
    } catch (_) {
      // 一時ファイル削除失敗は無視する
    }
    return outputPath;
  }
}
