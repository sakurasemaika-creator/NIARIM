import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../engine/camera_engine.dart';
import '../engine/filter_engine.dart';
import '../engine/layer_compositor.dart';
import '../engine/layer_keyframe_engine.dart';
import '../engine/layer_range_resolver.dart';
import '../engine/tile_manager.dart';
import '../models/camera_keyframe.dart';
import '../models/effect_filter_instance.dart';
import '../models/layer.dart';
import '../models/scene.dart';
import '../services/hw_video_encoder.dart';

typedef ExportProgressCallback = void Function(int currentFrame, int totalFrames);

/// 書き出し中のキャンセル要求を伝えるためのトークン（仕様書06・13：
/// 誤タップ対応のキャンセルボタン）。フレーム生成ループの各反復で
/// チェックされ、キャンセルされていれば[ExportCancelledException]を
/// 投げてループを打ち切る。ハードウェアエンコーダー（MediaCodec）・
/// FFmpegセッションによる最終エンコード処理自体は安全に中断する手段が
/// ないため、その段階でキャンセルされた場合は処理を最後まで実行した上で
/// 呼び出し側（export_screen.dart）が出力ファイルを破棄する。
class ExportCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// [ExportCancelToken]経由でユーザーが書き出しをキャンセルしたことを示す。
class ExportCancelledException implements Exception {
  const ExportCancelledException();
  @override
  String toString() => 'ExportCancelledException: 書き出しがキャンセルされました';
}

class ExportEngine {
  final CameraEngine _cameraEngine = CameraEngine();
  final LayerKeyframeEngine _layerKeyframeEngine = LayerKeyframeEngine();
  final FilterEngine _filterEngine = FilterEngine();

  /// 書き出し結果（MP4/GIF/WebM）の保存先。以前は`getTemporaryDirectory()`
  /// （OSがいつ削除してもよいキャッシュ領域）に書き出しており、書き出し
  /// 完了後にアプリがバックグラウンドに回っただけで消えてしまう場合が
  /// あった。書き出し先が分からず不安という指摘もあったため、アプリの
  /// 永続領域（他の保存データと同じ`getApplicationDocumentsDirectory()`
  /// 配下）に固定の`exports`フォルダを作り、そこへ保存するよう変更した。
  /// フレーム生成用の中間PNGファイルは引き続き一時領域（`export_frames`等）
  /// を使い、書き出し完了後に削除する（最終出力ファイルのみ永続化する）。
  ///
  /// staticかつpublicにしているのは、「作品一覧」タブ（プロジェクト一覧
  /// 画面）から過去の書き出し結果を一覧表示するために、ExportEngineの
  /// インスタンスを作らずアクセスできるようにするため。
  static Future<Directory> exportsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 作品一覧タブ用：exportsフォルダ内の書き出し済みファイル一覧を
  /// 更新日時の新しい順で返す。
  static Future<List<File>> listExportedFiles() async {
    final dir = await exportsDir();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

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
    Map<String, LayerHome> layerHomes = const {},
  }) async {
    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => resolveTileKey(layerHomes, sceneId, frameIndex, l.id),
      drawingWidth,
      drawingHeight,
      keyframeOf: (l) =>
          l.keyframes.isEmpty ? null : _layerKeyframeEngine.valueAt(l.keyframes, frameIndex),
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

  /// 無料版のエンドカード（NIARIMロゴ、約5秒）のフレーム画像をPNGとして
  /// 生成する（仕様書06・13）。FFmpegのdrawtextフィルターに依存せず、
  /// 他のテキスト描画と同じdart:uiのParagraphBuilderで焼き込む。
  Future<Uint8List> _renderEndCardPng({required int width, required int height}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFFFFFFF),
        fontSize: width * 0.08,
        fontWeight: ui.FontWeight.bold,
      ))
      ..addText('NIARIM');
    final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width.toDouble()));
    canvas.drawParagraph(paragraph, ui.Offset(0, (height - paragraph.height) / 2));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();
    final rgba = byteData!.buffer.asUint8List();
    return img.encodePng(
      img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4),
    );
  }

  /// MP4書き出し（仕様書13）。Android標準のハードウェアH.264エンコーダー
  /// （MediaCodec、android/app側のネイティブ実装）を使う。FFmpeg/libx264
  /// （GPLライセンス）は使わないことで、コピーレフト・H.264特許
  /// ロイヤリティの論点を回避する。[appendEndCard]がtrueの場合、無料版の
  /// エンドカード（約5秒）を本編フレーム列の末尾へ同一エンコード内で
  /// 追加する（動画結合ではなく同一パスの重複指定でエンコーダー側が
  /// 静止フレームとして扱う）。
  Future<String> exportMp4({
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    bool appendEndCard = false,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final framesDir = Directory('${tmpDir.path}/export_frames');
    if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
    framesDir.createSync();

    int globalIndex = 0;
    int totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);
    // 共通・タイムライン素材・ウォーターマークレイヤーの表示範囲を反映するため、
    // 書き出しジョブ開始時に一度だけホーム位置インデックスを構築する（仕様書05・16）。
    final layerHomes = buildLayerHomeIndex(scenes);
    final framePaths = <String>[];

    for (final scene in scenes) {
      for (final frame in scene.frames) {
        if (cancelToken?.isCancelled == true) {
          framesDir.deleteSync(recursive: true);
          throw const ExportCancelledException();
        }
        final rgba = await renderFrame(
          layers: resolveFrameLayers(scenes, layerHomes, scene.id, frame.index, frame.layers),
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
          layerHomes: layerHomes,
        );
        final pngBytes = img.encodePng(
          img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: 4),
        );
        final file = File('${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png');
        await file.writeAsBytes(pngBytes);
        framePaths.add(file.path);
        onProgress?.call(globalIndex + 1, totalFrames);
        globalIndex++;
      }
    }

    if (appendEndCard) {
      final endCardBytes = await _renderEndCardPng(width: width, height: height);
      final endCardFile = File('${framesDir.path}/endcard.png');
      await endCardFile.writeAsBytes(endCardBytes);
      for (int i = 0; i < fps * 5; i++) {
        framePaths.add(endCardFile.path);
      }
    }

    final exportsDir = await ExportEngine.exportsDir();
    final outputPath = '${exportsDir.path}/niarim_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await HardwareVideoEncoder.encodeMp4(
      framePaths: framePaths,
      fps: fps,
      width: width,
      height: height,
      outputPath: outputPath,
    );
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
    ExportCancelToken? cancelToken,
  }) async {
    // image v4: アニメーションGIFはimg.Imageにフレームを追加する
    img.Image? gifImage;
    int totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);
    int index = 0;
    final delayMs = (1000 / fps).round();
    final layerHomes = buildLayerHomeIndex(scenes);

    for (final scene in scenes) {
      for (final frame in scene.frames) {
        if (cancelToken?.isCancelled == true) throw const ExportCancelledException();
        final rgba = await renderFrame(
          layers: resolveFrameLayers(scenes, layerHomes, scene.id, frame.index, frame.layers),
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
          layerHomes: layerHomes,
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
    final exportsDir = await ExportEngine.exportsDir();
    final outputPath = '${exportsDir.path}/niarim_${DateTime.now().millisecondsSinceEpoch}.gif';
    await File(outputPath).writeAsBytes(gifBytes);
    return outputPath;
  }

  /// WebM書き出し（VP9、仕様書13）。libvpxはBSDライセンスかつVP9自体が
  /// ロイヤリティフリーのため、引き続きFFmpeg（GPLコーデックを含まない
  /// LGPL版のffmpeg_kit_flutter_new_video）で問題ない。[appendEndCard]が
  /// trueの場合、無料版のエンドカードをフレーム列の末尾へ同一シーケンス内で
  /// 追加する（FFmpegのdrawtext/concatフィルターには依存しない。ffmpegの
  /// image2デマルチプレクサは連番ファイルを要求するため、エンドカード画像を
  /// 必要フレーム数ぶん物理的に複製する）。
  Future<String> exportWebm({
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    bool appendEndCard = false,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final framesDir = Directory('${tmpDir.path}/export_webm_frames');
    if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
    framesDir.createSync();

    int globalIndex = 0;
    int totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);
    final layerHomes = buildLayerHomeIndex(scenes);

    for (final scene in scenes) {
      for (final frame in scene.frames) {
        if (cancelToken?.isCancelled == true) {
          framesDir.deleteSync(recursive: true);
          throw const ExportCancelledException();
        }
        final rgba = await renderFrame(
          layers: resolveFrameLayers(scenes, layerHomes, scene.id, frame.index, frame.layers),
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
          layerHomes: layerHomes,
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

    if (appendEndCard) {
      final endCardBytes = await _renderEndCardPng(width: width, height: height);
      for (int i = 0; i < fps * 5; i++) {
        final file = File('${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png');
        await file.writeAsBytes(endCardBytes);
        globalIndex++;
      }
    }

    final exportsDir = await ExportEngine.exportsDir();
    final outputPath = '${exportsDir.path}/niarim_${DateTime.now().millisecondsSinceEpoch}.webm';
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
