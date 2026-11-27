import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'corner_logo.dart';
import 'export_audio.dart';
import 'export_filename.dart';
import 'filter_engine.dart' show EffectFilterType;
import 'frame_png.dart';
import 'gif_palette.dart';
import '../engine/layer_range_resolver.dart';
import '../engine/timeline_stack.dart';
import '../engine/tile_manager.dart';
import '../engine/timeline_frame_renderer.dart';
import '../engine/timeline_video_layer_pixels.dart';
import '../engine/video_frame_decoder.dart';
import '../engine/video_frame_provider.dart';
import '../engine/video_material_snapshot.dart';
import '../models/camera_keyframe.dart';
import '../models/effect_filter_instance.dart';
import '../models/layer.dart';
import '../models/layer_group.dart';
import '../models/scene.dart';
import '../services/hw_video_encoder.dart';
import '../services/export_storage.dart';
import '../utils/app_error_reporter.dart';

typedef ExportProgressCallback =
    void Function(int currentFrame, int totalFrames);

/// 書き出し中のキャンセル要求を伝えるためのトークン（誤タップ対応の
/// キャンセルボタン）。フレーム生成ループの各反復で
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

/// An export listing and the metadata read during the same storage scan.
class ExportedFileListing {
  ExportedFileListing._(this.files, this.stats);

  final List<File> files;
  final Map<File, FileStat> stats;
}

/// Samples the existing timeline at the output frame rate. Frame indices used
/// for effects and the camera always belong to the original scene.
class ExportTiming {
  const ExportTiming({
    required this.sourceFps,
    required this.outputFps,
    this.maxSeconds,
  });

  final int sourceFps;
  final int outputFps;
  final int? maxSeconds;

  static int sourceFrames(List<Scene> scenes) =>
      scenes.fold(0, (total, scene) => total + scene.frames.length);

  int outputFrames(List<Scene> scenes) {
    final total = sourceFrames(scenes);
    final limit = maxSeconds;
    final capped = limit == null ? total : math.min(total, limit * sourceFps);
    return capped == 0
        ? 0
        : math.max(1, (capped * outputFps / sourceFps).round());
  }

  /// The source frame (counted over all scenes) output frame [outputIndex]
  /// shows: the rule [samples] follows, which the timeline's preview at the
  /// output frame rate uses too.
  int sourceFrameOf(int outputIndex) => outputIndex * sourceFps ~/ outputFps;

  /// The first output frame showing source frame [sourceFrame] or a later
  /// one.
  int firstOutputFrom(int sourceFrame) =>
      (sourceFrame * outputFps + sourceFps - 1) ~/ sourceFps;

  Iterable<({Scene scene, Frame frame})> samples(List<Scene> scenes) sync* {
    final count = outputFrames(scenes);
    var outputIndex = 0;
    var end = 0;
    for (final scene in scenes) {
      for (final frame in scene.frames) {
        end++;
        while (outputIndex < count &&
            outputIndex * sourceFps < end * outputFps) {
          yield (scene: scene, frame: frame);
          outputIndex++;
        }
        if (outputIndex == count) return;
      }
    }
  }

  /// GIF stores delays in centiseconds. Round cumulative time so individual
  /// frame quantization does not accumulate over the length of the project.
  int gifDelayMs(int index) =>
      ((index * 100 / outputFps).round() -
          ((index - 1) * 100 / outputFps).round()) *
      10;
}

/// The encoder for exported GIFs. The image package's default (neural
/// quantizer + Floyd–Steinberg dithering) maps a flat white to a palette
/// entry like 252 and dithers the difference, so flat paper showed streaks
/// (39% of a 480×360 frame). The octree method keeps the frame's own colours
/// exactly and, without dithering, flat areas stay flat.
///
/// Each frame is turned into a palette image first by [GifPaletteMapper]
/// (the octree method on the frame's bytes; the image package's own octree
/// quantizer is slow and sends merged colours to the wrong palette entry).
img.GifEncoder newExportGifEncoder() => _ExportGifEncoder();

class _ExportGifEncoder extends img.GifEncoder {
  _ExportGifEncoder()
    : super(
        quantizerType: img.QuantizerType.octree,
        dither: img.DitherKernel.none,
      );

  final GifPaletteMapper _palette = GifPaletteMapper();

  @override
  void addFrame(img.Image image, {int? duration}) => super.addFrame(
    image.hasPalette ? image : _palette.paletteFrame(image),
    duration: duration,
  );
}

Uint8List _encodeGifFrames(
  ({
    String path,
    int width,
    int height,
    int frameCount,
    ExportTiming timing,
    CornerLogoStamp? logo,
  })
  request,
) {
  final (:path, :width, :height, :frameCount, :timing, :logo) = request;
  final encoder = newExportGifEncoder();
  final input = File(path).openSync();
  final frameBytes = width * height * 4;
  try {
    for (var index = 0; index < frameCount; index++) {
      final rgba = input.readSync(frameBytes);
      if (rgba.length != frameBytes) {
        throw const FileSystemException('Incomplete GIF frame data');
      }
      logo?.stampOntoBytes(rgba, width, height, 4);
      final frame = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        bytesOffset: rgba.offsetInBytes,
        numChannels: 4,
      );
      encoder.addFrame(
        frame,
        duration: frameCount == 1 ? null : timing.gifDelayMs(index + 1) ~/ 10,
      );
    }
    return encoder.finish()!;
  } finally {
    input.closeSync();
  }
}

class ExportEngine {
  ExportEngine({
    VideoFrameDecoder Function(Directory workDirectory)? videoDecoderFor,
  }) : videoDecoderFor = videoDecoderFor ?? FfmpegVideoFrameDecoder.ffmpegKit;

  /// Makes the decoder one export job uses for its video materials' frames,
  /// writing its scratch files under the job's own folder.
  final VideoFrameDecoder Function(Directory workDirectory) videoDecoderFor;

  /// How many video layers of the last export could not show their frames
  /// (a missing or unreadable material file, a frame that could not be
  /// decoded). Those layers drew nothing; the rest of the export is written.
  int videoLeftOut = 0;

  final TimelineFrameRenderer _frameRenderer = TimelineFrameRenderer();

  /// 書き出し結果（MP4/GIF/WebM）の保存先。`getTemporaryDirectory()`
  /// （OSがいつ削除してもよいキャッシュ領域）ではなく、他の保存データと
  /// 同じ永続領域（`getApplicationDocumentsDirectory()`配下）に固定の
  /// アプリ専用の`niarim/exports`フォルダを作り、そこへ保存する。
  /// 以前の共有`exports`フォルダは一覧で引き続き読み取るが初期化で削除しない。
  /// フレーム生成用の中間PNGファイルは一時領域（`export_frames`等）を使い、
  /// 書き出し完了後に削除する（最終出力ファイルのみ永続化する）。
  ///
  /// staticかつpublicにしているのは、「作品一覧」タブ（プロジェクト一覧
  /// 画面）から過去の書き出し結果を一覧表示するために、ExportEngineの
  /// インスタンスを作らずアクセスできるようにするため。
  static Future<Directory> exportsDir() async {
    return ExportStorage.createManagedDirectory();
  }

  // 直近の一覧結果のキャッシュ。スプラッシュ表示中に先読みしておいた結果を
  // 「作品一覧」タブが再利用することで、タブ表示時のディスクアクセス待ちを
  // 省略できる。
  static ExportedFileListing? _cachedExportedFiles;
  static int _cachedStorageGeneration = -1;
  static Future<ExportedFileListing>? _exportListingInFlight;
  static int _exportListingInFlightGeneration = -1;

  /// 作品一覧タブ用：exportsフォルダ内の書き出し済みファイル一覧を
  /// 更新日時の新しい順で返す。[forceRefresh]がfalse（既定）かつキャッシュが
  /// あればそれを返す。ファイルの追加・削除後は[forceRefresh]をtrueにして
  /// 呼び出す。
  static Future<List<File>> listExportedFiles({
    bool forceRefresh = false,
  }) async =>
      (await listExportedFileMetadata(forceRefresh: forceRefresh)).files;

  static Future<ExportedFileListing> listExportedFileMetadata({
    bool forceRefresh = false,
  }) async {
    final generation = ExportStorage.generation;
    final pending = _exportListingInFlight;
    if (!forceRefresh &&
        pending != null &&
        _exportListingInFlightGeneration == generation) {
      return pending;
    }
    if (!forceRefresh &&
        _cachedExportedFiles != null &&
        _cachedStorageGeneration == generation) {
      return _cachedExportedFiles!;
    }
    final scan = _readExportListing();
    _exportListingInFlight = scan;
    _exportListingInFlightGeneration = generation;
    try {
      final listing = await scan;
      if (identical(_exportListingInFlight, scan) &&
          generation == ExportStorage.generation) {
        _cachedExportedFiles = listing;
        _cachedStorageGeneration = generation;
      }
      return listing;
    } finally {
      if (identical(_exportListingInFlight, scan)) {
        _exportListingInFlight = null;
      }
    }
  }

  static Future<ExportedFileListing> _readExportListing() async {
    final files = await ExportStorage.listFiles();
    // Bound pending OS requests and yield to the UI between batches.
    const batchSize = 256;
    final stats = Map<File, FileStat>.identity();
    for (var start = 0; start < files.length; start += batchSize) {
      final batch = files.skip(start).take(batchSize).toList();
      final results = await Future.wait(batch.map((file) => file.stat()));
      for (final (i, stat) in results.indexed) {
        if (stat.type == FileSystemEntityType.file) stats[batch[i]] = stat;
      }
    }
    final sorted = files.where(stats.containsKey).toList()
      ..sort((a, b) {
        final byTime = stats[b]!.modified.compareTo(stats[a]!.modified);
        return byTime == 0 ? a.path.compareTo(b.path) : byTime;
      });
    return ExportedFileListing._(
      List.unmodifiable(sorted),
      Map.unmodifiable(stats),
    );
  }

  /// フレームを合成して乗算済みRGBAのUint8Listを返す。
  ///
  /// [drawingWidth]・[drawingHeight]は描画領域全体のサイズ（描画領域倍率を
  /// 反映済み）、[width]・[height]は書き出しサイズ。描画領域が書き出し領域より
  /// 広い場合は、描画領域の中央にある書き出しサイズ分だけを
  /// 切り出す（キャンバス表示の赤枠と同じ中央配置）。
  /// 合成対象はTileManagerに実ピクセルデータを持つレイヤー種別（通常・
  /// 自動塗り用線画・自動塗り）全てで、不透明度・ブレンドモード・
  /// クリッピングを反映する。[cameraKeyframes]が設定されている
  /// 場合はカメラのXY移動・拡大・回転を、[effectFilters]が設定されている場合は
  /// 演出フィルターを書き出し結果へ反映する。
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
    List<LayerGroup> groups = const [],
    Scene? scene,
    TimelineVideoLayerPixels? videoPixels,
  }) async {
    // In the scene's 重なり順, with its frame mask.
    final stacked = scene == null
        ? (layers: layers, maskGroups: const <LayerMaskGroup>[])
        : stackFrameLayers(scene, frameIndex, layers);
    // The same pipeline the timeline preview draws the frame with.
    return _frameRenderer.renderRgba(
      TimelineFrameRequest(
        tileManager: tileManager,
        layers: stacked.layers,
        keyOf: (l) => resolveTileKey(layerHomes, sceneId, frameIndex, l.id),
        frameIndex: frameIndex,
        drawingWidth: drawingWidth,
        drawingHeight: drawingHeight,
        outputWidth: width,
        outputHeight: height,
        backgroundColor: backgroundColor,
        maskGroups: stacked.maskGroups,
        groups: groups,
        cameraKeyframes: cameraKeyframes,
        effectFilters: effectFilters,
        pixelsOf: videoPixels?.atFrame(frameIndex),
      ),
    );
  }

  // Compositing and effect filters use premultiplied channels. A PNG stores
  // the colour independently of its alpha so reopening does not darken it.
  static void _straightenPngPixels(Uint8List pixels) {
    for (var i = 0; i < pixels.length; i += 4) {
      final alpha = pixels[i + 3];
      if (alpha == 255) continue;
      if (alpha == 0) {
        pixels[i] = pixels[i + 1] = pixels[i + 2] = 0;
        continue;
      }
      for (var channel = 0; channel < 3; channel++) {
        final index = i + channel;
        pixels[index] = ((pixels[index] * 255 + alpha ~/ 2) ~/ alpha).clamp(
          0,
          255,
        );
      }
    }
  }

  /// タイムラインモードで現在選択中のフレーム1枚だけを静止画（PNG/JPEG）
  /// として書き出す。動画書き出し（exportMp4等）と異なり、対象シーンの
  /// うち指定した1フレームだけを合成し、exportsフォルダへ直接保存する
  /// （中間フォルダへの一時ファイル書き出しは不要）。
  Future<String> exportFrameImage({
    String? projectName,
    required List<Scene> scenes,
    required TileManager tileManager,
    required String sceneId,
    required int frameIndex,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    required bool asJpeg,
    int? sourceFps,
    VideoMaterialSnapshot? videoMaterials,
  }) async {
    return _withVideoFrames(
      materials: videoMaterials,
      framesPerSecond: sourceFps,
      drawingWidth: drawingWidth,
      drawingHeight: drawingHeight,
      cancelToken: null,
      body: (video) async {
        final layerHomes = buildLayerHomeIndex(scenes);
        final scene = scenes.firstWhere((s) => s.id == sceneId);
        final frame = scene.frames.firstWhere((f) => f.index == frameIndex);
        final rgba = await renderFrame(
          layers: resolveFrameLayers(
            scenes,
            layerHomes,
            sceneId,
            frameIndex,
            frame.layers,
          ),
          tileManager: tileManager,
          sceneId: sceneId,
          scene: scene,
          frameIndex: frameIndex,
          drawingWidth: drawingWidth,
          drawingHeight: drawingHeight,
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          cameraKeyframes: scene.cameraKeyframes,
          effectFilters: scene.effectFilters,
          layerHomes: layerHomes,
          groups: scene.groups,
          videoPixels: video,
        );
        if (!asJpeg) _straightenPngPixels(rgba);
        final image = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: rgba.buffer,
          bytesOffset: rgba.offsetInBytes,
          numChannels: 4,
        );
        final bytes = asJpeg
            ? img.encodeJpg(image, quality: 92)
            : img.encodePng(image);
        final dir = await ExportEngine.exportsDir();
        final ext = asJpeg ? 'jpg' : 'png';
        final outputPath = _freshOutputPath(
          dir,
          projectName,
          ext,
          frameIndex: frameIndex,
        );
        await _publishImageExport(outputPath, bytes);
        return outputPath;
      },
    );
  }

  /// 無料版のエンドカード（中央にアプリアイコン、下にアプリタイトルロゴ、
  /// 約5秒）のフレーム画像をPNGとして生成する。ロゴ・タイトルロゴとも
  /// SVGをvector_graphicsで直接ui.Pictureへデコードし、Canvas上へ合成する
  /// （ウィジェットツリー外からの描画のため、SvgPictureウィジェットは
  /// 使わずvg.loadPictureを直接呼ぶ）。タイトルロゴは以前まで
  /// ParagraphBuilderで「NIARIM」の文字を仮描画していたが、完成した
  /// アプリタイトルロゴ（assets/logo/title_logo.svg）に差し替えた。
  /// 公式エンドマークの長さ（秒）。書き出しのfpsでこの秒数ぶんのコマを足す。
  static const int officialEndCardSeconds = 5;

  /// 公式エンドマークの1コマ（[width]×[height]のPNG）。作品の書き出しと
  /// メイキング動画の書き出しが同じ絵を使う。
  Future<Uint8List> renderOfficialEndCardPng({
    required int width,
    required int height,
  }) => _renderEndCardPng(width: width, height: height);

  Future<Uint8List> _renderEndCardPng({
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );

    // アイコンバッジ：短辺の40%を目安にした正方形で中央よりやや上に
    // 配置する。以前は単色SVGを白抜きにしただけで背景を持たなかったが、
    // アプリランチャーアイコン・起動画面（tool/gen_app_icon.py・
    // splash_screen.dart）と同じ「テーマ色の角丸正方形の背景＋白抜き
    // モノグラム」の意匠に揃えた。ExportEngineはウィジェットツリー外の
    // 純粋な描画エンジンでTheme/BuildContextへアクセスできないため、
    // 既定テーマ（レッド・ライト）のアクセントカラーを直接使う。既定
    // テーマの配色を変更した場合は、tool/gen_app_icon.py・pubspec.yamlの
    // adaptive_icon_backgroundと合わせてcorner_logo.dartのniarimBadgeColorも
    // 更新すること（GIFの隅のロゴも同じバッジ）。
    final logoInfo = await loadNiarimMonogram();
    final logoSize = width < height ? width * 0.4 : height * 0.4;
    final logoLeft = (width - logoSize) / 2;
    final logoTop = height / 2 - logoSize * 0.65;
    // モノグラムはバッジの内側へ8%相当の余白を空けて配置する
    // （splash_screen.dartのlogoSize*0.08と同じ比率。「スマホアプリ版
    // Claudeのアイコンくらいのバランス」という要望を受けて拡大した）。
    paintNiarimBadge(
      canvas,
      ui.Rect.fromLTWH(logoLeft, logoTop, logoSize, logoSize),
      logoInfo,
    );
    logoInfo.picture.dispose();

    // タイトルロゴ（アプリ名の書き文字）：モノグラムの下に、横幅の55%を
    // 目安にした幅で中央揃えに配置する。SVGの元アスペクト比（幅3470×
    // 高さ690相当）を保つ。単色SVGのため、黒背景で視認できるよう白で描く
    // （GIFの隅のロゴも同じ書き文字、paintNiarimWordmark）。
    final titleInfo = await loadNiarimWordmark();
    final titleWidth = width * 0.55;
    final titleHeight =
        titleWidth * titleInfo.size.height / titleInfo.size.width;
    paintNiarimWordmark(
      canvas,
      ui.Rect.fromLTWH(
        (width - titleWidth) / 2,
        logoTop + logoSize + height * 0.04,
        titleWidth,
        titleHeight,
      ),
      titleInfo,
      const ui.Color(0xFFFFFFFF),
    );
    titleInfo.picture.dispose();

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    uiImage.dispose();
    return encodeFramePng(byteData!.buffer.asUint8List(), width, height);
  }

  // An encoder can hold a name before the file exists on disk.
  static final Set<String> _issuedOutputPaths = {};

  /// 今走っている書き出しのコマのフォルダ。
  static final Set<String> _framesInUse = {};

  /// 書き出しごとに別のコマのフォルダ（`[prefix]_…`）を作る。同じ名前の
  /// フォルダを使い回すと、同時に走る別の書き出しが始めるときに消し、互いの
  /// コマを消したり混ぜたりした。前の書き出しが消せずに残したフォルダ
  /// （今走っていないもの、以前の版の`[prefix]`そのもの）はここで片付ける。
  static Directory _newFramesDir(Directory tmpDir, String prefix) {
    try {
      for (final entity in tmpDir.listSync()) {
        if (entity is! Directory || _framesInUse.contains(entity.path)) {
          continue;
        }
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (name == prefix || name.startsWith('${prefix}_')) {
          _removeFrames(entity);
        }
      }
    } on FileSystemException catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
    final frames = tmpDir.createTempSync('${prefix}_');
    _framesInUse.add(frames.path);
    return frames;
  }

  /// A new file in [dir] for a making video of the work [projectName]
  /// ("作品名 Making 日時"), never an existing one.
  static String freshMakingOutputPath(
    Directory dir,
    String? projectName,
    String extension,
  ) => _freshOutputPath(dir, projectName, extension, making: true);

  static String _freshOutputPath(
    Directory dir,
    String? projectName,
    String extension, {
    int? frameIndex,
    bool making = false,
  }) {
    final stem = exportFilenameStem(
      projectName,
      DateTime.now(),
      frameIndex: frameIndex,
      making: making,
    );
    for (var version = 1; ; version++) {
      final suffix = version == 1 ? '' : ' ($version)';
      final path = '${dir.path}/$stem$suffix.$extension';
      if (FileSystemEntity.typeSync(path, followLinks: false) ==
              FileSystemEntityType.notFound &&
          _issuedOutputPaths.add(path.toLowerCase())) {
        return path;
      }
    }
  }

  /// Remove an export’s temporary frame folder, whether
  /// the export finished, failed or was cancelled. A folder that cannot be
  /// removed is cleared when the next export of the same kind starts; it must
  /// not turn a finished export into a failure.
  static void _removeFrames(Directory frames) {
    _framesInUse.remove(frames.path);
    try {
      if (frames.existsSync()) frames.deleteSync(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// Remove the video an encoder (MediaCodec, FFmpeg) left half written when
  /// the export failed. Left in the exports folder, it was listed in the Works
  /// list as a broken work.
  static Future<void> _discardPartialVideo(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        ExportStorage.invalidate();
      }
    } on FileSystemException catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// MP4書き出し。Android標準のハードウェアH.264エンコーダー
  /// （MediaCodec、android/app側のネイティブ実装）を使う。FFmpeg/libx264
  /// （GPLライセンス）は使わないことで、コピーレフト・H.264特許
  /// ロイヤリティの論点を回避する。[appendEndCard]がtrueの場合、無料版の
  /// エンドカード（約5秒）を本編フレーム列の末尾へ同一エンコード内で
  /// 追加する（動画結合ではなく同一パスの重複指定でエンコーダー側が
  /// 静止フレームとして扱う）。
  /// How many sounds of the last video export could not be put in it (a
  /// missing material, a file that could not be read, a device that could
  /// not encode the sound). The video itself is still written.
  int audioLeftOut = 0;

  /// Runs one export [body] with the frames of the job's video materials:
  /// only the files in [materials] (captured when the job started) are read,
  /// decoded frames are chosen by the timeline's shared rule at
  /// [framesPerSecond], and the decoder, its cache and its scratch folder are
  /// released when the job ends, fails or is cancelled.
  Future<T> _withVideoFrames<T>({
    required VideoMaterialSnapshot? materials,
    required int? framesPerSecond,
    required int drawingWidth,
    required int drawingHeight,
    required ExportCancelToken? cancelToken,
    required Future<T> Function(TimelineVideoLayerPixels? video) body,
  }) async {
    videoLeftOut = 0;
    if (materials == null ||
        materials.sources.isEmpty ||
        framesPerSecond == null ||
        framesPerSecond <= 0) {
      return body(null);
    }
    final workDir = _newFramesDir(
      await getTemporaryDirectory(),
      'export_video_frames',
    );
    final problemLayers = <String>{};
    // Export walks forward through time: each decoder pass gives the next
    // frames too (up to about 48 MB of them), and a few more frames are kept
    // to share a decode between scenes' identical frames and layers.
    final frameBytes = drawingWidth * drawingHeight * 4;
    final readAhead = exportVideoReadAhead(frameBytes);
    final frames = VideoFrameProvider(
      snapshot: materials,
      decoder: videoDecoderFor(workDir),
      cacheBudgetBytes: frameBytes * (readAhead + 3),
      readAhead: readAhead,
    );
    try {
      return await body(
        TimelineVideoLayerPixels(
          frames: frames,
          framesPerSecond: framesPerSecond.toDouble(),
          canvasWidth: drawingWidth,
          canvasHeight: drawingHeight,
          isCancelled: () => cancelToken?.isCancelled == true,
          onProblem: (problem) => problemLayers.add(problem.layerId),
        ),
      );
    } finally {
      videoLeftOut = problemLayers.length;
      frames.dispose();
      _removeFrames(workDir);
    }
  }

  Future<ExportAudioMix> _mixSound(
    ExportAudioPlan audio,
    double totalSeconds,
    Directory workDir,
    ExportCancelToken? cancelToken,
  ) async {
    audioLeftOut = 0;
    if (cancelToken?.isCancelled == true) {
      throw const ExportCancelledException();
    }
    final mix = await mixExportAudio(
      plan: audio,
      totalSeconds: totalSeconds,
      workDir: workDir,
      cancelled: () => cancelToken?.isCancelled == true,
    );
    if (cancelToken?.isCancelled == true) {
      throw const ExportCancelledException();
    }
    audioLeftOut = mix.leftOut;
    return mix;
  }

  /// Runs FFmpeg on the frames ([video] input and [codecs]) with the mixed
  /// [sound] as a second input. If FFmpeg cannot write the sound, the video
  /// is written without it (and the sounds are counted as left out) rather
  /// than not at all.
  Future<void> _encodeWithSound({
    required List<String> video,
    required List<String> codecs,
    required List<String> soundCodec,
    required ExportAudioMix sound,
    required ExportAudioPlan audio,
    required String outputPath,
  }) async {
    Future<FFmpegSession> run(bool withSound) =>
        FFmpegKit.executeWithArguments([
          '-y',
          ...video,
          if (withSound) ...['-i', sound.path!],
          if (withSound) ...['-map', '0:v', '-map', '1:a'],
          ...codecs,
          if (withSound) ...soundCodec,
          outputPath,
        ]);
    var session = await run(sound.path != null);
    if (sound.path != null &&
        !ReturnCode.isSuccess(await session.getReturnCode())) {
      await _discardPartialVideo(outputPath);
      audioLeftOut = audio.sources.length + audio.missing;
      session = await run(false);
    }
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      throw Exception('FFmpeg failed: ${await session.getOutput()}');
    }
  }

  Future<String> exportMp4({
    String? projectName,
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    int? sourceFps,
    int? maxSeconds,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    bool appendEndCard = false,
    ExportAudioPlan audio = ExportAudioPlan.empty,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
    VideoMaterialSnapshot? videoMaterials,
  }) async {
    return _withVideoFrames(
      materials: videoMaterials,
      framesPerSecond: sourceFps ?? fps,
      drawingWidth: drawingWidth,
      drawingHeight: drawingHeight,
      cancelToken: cancelToken,
      body: (video) async {
        final tmpDir = await getTemporaryDirectory();
        // 書き出しごとに別のフォルダ（同時に走る書き出しのコマを消さない）。
        final framesDir = _newFramesDir(tmpDir, 'export_frames');
        String? partialOutput;
        try {
          int globalIndex = 0;
          final timing = ExportTiming(
            sourceFps: sourceFps ?? fps,
            outputFps: fps,
            maxSeconds: maxSeconds,
          );
          final totalFrames = timing.outputFrames(scenes);
          // 共通・タイムライン素材・ウォーターマークレイヤーの表示範囲を反映するため、
          // 書き出しジョブ開始時に一度だけホーム位置インデックスを構築する。
          final layerHomes = buildLayerHomeIndex(scenes);
          final framePaths = <String>[];

          Scene? lastScene;
          Frame? lastFrame;
          Uint8List? lastPng;
          String? lastPath;
          for (final (:scene, :frame) in timing.samples(scenes)) {
            if (cancelToken?.isCancelled == true) {
              throw const ExportCancelledException();
            }
            if (!identical(lastScene, scene) ||
                !identical(lastFrame, frame) ||
                lastPng == null) {
              final rgba = await renderFrame(
                layers: resolveFrameLayers(
                  scenes,
                  layerHomes,
                  scene.id,
                  frame.index,
                  frame.layers,
                ),
                tileManager: tileManager,
                sceneId: scene.id,
                scene: scene,
                frameIndex: frame.index,
                drawingWidth: drawingWidth,
                drawingHeight: drawingHeight,
                width: width,
                height: height,
                backgroundColor: backgroundColor,
                cameraKeyframes: scene.cameraKeyframes,
                effectFilters: scene.effectFilters,
                layerHomes: layerHomes,
                groups: scene.groups,
                videoPixels: video,
              );
              lastPng = encodeFramePng(rgba, width, height);
              lastScene = scene;
              lastFrame = frame;
              final file = File(
                '${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png',
              );
              await file.writeAsBytes(lastPng);
              lastPath = file.path;
            }
            // The encoder reads each path in turn: an output frame repeating
            // the source frame before it reads the same file again.
            framePaths.add(lastPath!);
            onProgress?.call(globalIndex + 1, totalFrames);
            globalIndex++;
          }

          if (appendEndCard) {
            final endCardBytes = await _renderEndCardPng(
              width: width,
              height: height,
            );
            final endCardFile = File('${framesDir.path}/endcard.png');
            await endCardFile.writeAsBytes(endCardBytes);
            for (int i = 0; i < fps * officialEndCardSeconds; i++) {
              framePaths.add(endCardFile.path);
            }
          }

          final sound = await _mixSound(
            audio,
            framePaths.length / fps,
            framesDir,
            cancelToken,
          );
          final exportsDir = await ExportEngine.exportsDir();
          final outputPath = _freshOutputPath(exportsDir, projectName, 'mp4');
          partialOutput = outputPath;
          final audioIncluded = await HardwareVideoEncoder.encodeMp4(
            framePaths: framePaths,
            fps: fps,
            width: width,
            height: height,
            outputPath: outputPath,
            audioPath: sound.path,
          );
          if (sound.path != null && !audioIncluded) {
            // The device could not encode the sound: the video is kept without it.
            audioLeftOut = audio.sources.length + audio.missing;
          }
          // 作品一覧が覚えている一覧を捨て、書き出した作品を次の一覧に入れる。
          ExportStorage.invalidate();
          return outputPath;
        } catch (_) {
          if (partialOutput != null) await _discardPartialVideo(partialOutput);
          rethrow;
        } finally {
          _removeFrames(framesDir);
        }
      },
    );
  }

  Future<String> exportGif({
    String? projectName,
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    int? sourceFps,
    int? maxSeconds,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    bool cornerLogo = false,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
    VideoMaterialSnapshot? videoMaterials,
  }) async {
    return _withVideoFrames(
      materials: videoMaterials,
      framesPerSecond: sourceFps ?? fps,
      drawingWidth: drawingWidth,
      drawingHeight: drawingHeight,
      cancelToken: cancelToken,
      body: (video) async {
        final timing = ExportTiming(
          sourceFps: sourceFps ?? fps,
          outputFps: fps,
          maxSeconds: maxSeconds,
        );
        final totalFrames = timing.outputFrames(scenes);
        if (totalFrames == 0) {
          throw StateError('GIF export needs at least one frame');
        }
        // How much of the user's own watermark falls where the logo would go
        // in each corner, summed over every frame.
        final watermarkOverlap = cornerLogo
            ? {for (final corner in LogoCorner.values) corner: 0.0}
            : null;
        final layerHomes = buildLayerHomeIndex(scenes);
        final tmpDir = await getTemporaryDirectory();
        final framesDir = _newFramesDir(tmpDir, 'gif_export_frames');
        final input = File('${framesDir.path}/frames.rgba');

        try {
          // Stage the frames on disk so long exports do not retain every RGBA
          // frame in memory or copy the full animation to the encoding isolate.
          final frames = await input.open(mode: FileMode.write);
          try {
            int index = 0;
            // Output frames showing the same source frame (an output rate
            // above the source's) write the same bytes and watermark
            // overlap again instead of drawing the frame again, unless the
            // scene has an effect that draws differently each time (noise).
            Scene? lastScene;
            Frame? lastFrame;
            Uint8List? lastRgba;
            Map<LogoCorner, double>? lastOverlap;
            for (final (:scene, :frame) in timing.samples(scenes)) {
              if (cancelToken?.isCancelled == true) {
                throw const ExportCancelledException();
              }
              if (!identical(lastScene, scene) ||
                  !identical(lastFrame, frame) ||
                  lastRgba == null ||
                  _drawsAnewEachTime(scene)) {
                lastRgba = await renderFrame(
                  layers: resolveFrameLayers(
                    scenes,
                    layerHomes,
                    scene.id,
                    frame.index,
                    frame.layers,
                  ),
                  tileManager: tileManager,
                  sceneId: scene.id,
                  scene: scene,
                  frameIndex: frame.index,
                  drawingWidth: drawingWidth,
                  drawingHeight: drawingHeight,
                  width: width,
                  height: height,
                  backgroundColor: backgroundColor,
                  cameraKeyframes: scene.cameraKeyframes,
                  effectFilters: scene.effectFilters,
                  layerHomes: layerHomes,
                  groups: scene.groups,
                  videoPixels: video,
                );
                lastOverlap = watermarkOverlap == null
                    ? null
                    : await _watermarkOverlap(
                        layers: resolveFrameLayers(
                          scenes,
                          layerHomes,
                          scene.id,
                          frame.index,
                          frame.layers,
                        ),
                        tileManager: tileManager,
                        scene: scene,
                        frameIndex: frame.index,
                        drawingWidth: drawingWidth,
                        drawingHeight: drawingHeight,
                        width: width,
                        height: height,
                        layerHomes: layerHomes,
                      );
                lastScene = scene;
                lastFrame = frame;
              }
              await frames.writeFrom(lastRgba);
              if (watermarkOverlap != null && lastOverlap != null) {
                for (final corner in LogoCorner.values) {
                  watermarkOverlap[corner] =
                      watermarkOverlap[corner]! + lastOverlap[corner]!;
                }
              }
              onProgress?.call(++index, totalFrames);
            }
          } finally {
            await frames.close();
          }

          if (cancelToken?.isCancelled == true) {
            throw const ExportCancelledException();
          }
          final logo = watermarkOverlap == null
              ? null
              : await CornerLogoStamp.render(
                  CornerLogoPlacement(
                    width,
                    height,
                    chooseLogoCorner((corner) => watermarkOverlap[corner]!),
                  ),
                );
          final gifBytes = await compute(_encodeGifFrames, (
            path: input.path,
            width: width,
            height: height,
            frameCount: totalFrames,
            timing: timing,
            logo: logo,
          ), debugLabel: 'Encode export GIF');
          final exportsDir = await ExportEngine.exportsDir();
          if (cancelToken?.isCancelled == true) {
            throw const ExportCancelledException();
          }
          final outputPath = _freshOutputPath(exportsDir, projectName, 'gif');
          await _publishImageExport(outputPath, gifBytes);
          return outputPath;
        } finally {
          _removeFrames(framesDir);
        }
      },
    );
  }

  /// Whether [scene] has an effect filter whose result differs each time a
  /// frame is drawn (the noise effect draws fresh noise), so an output frame
  /// repeating a source frame is drawn again rather than copied.
  static bool _drawsAnewEachTime(Scene scene) =>
      scene.effectFilters.any((e) => e.type == EffectFilterType.noise);

  /// How much of the frame's own watermark layers (the premium watermark
  /// feature) is drawn where the GIF logo would go in each corner (null when
  /// the frame has none). The watermark layers are drawn alone, placed as in
  /// the frame.
  Future<Map<LogoCorner, double>?> _watermarkOverlap({
    required List<Layer> layers,
    required TileManager tileManager,
    required Scene scene,
    required int frameIndex,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required Map<String, LayerHome> layerHomes,
  }) async {
    final marks = [
      for (final layer in layers)
        if (layer.type == LayerType.watermark && layer.isVisible) layer,
    ];
    if (marks.isEmpty) return null;
    final rgba = await renderFrame(
      layers: marks,
      tileManager: tileManager,
      sceneId: scene.id,
      scene: scene,
      frameIndex: frameIndex,
      drawingWidth: drawingWidth,
      drawingHeight: drawingHeight,
      width: width,
      height: height,
      backgroundColor: 0x00000000,
      cameraKeyframes: scene.cameraKeyframes,
      layerHomes: layerHomes,
      groups: scene.groups,
    );
    return {
      for (final corner in LogoCorner.values)
        corner: alphaInside(
          rgba,
          width,
          CornerLogoPlacement(width, height, corner).clearArea,
        ),
    };
  }

  Future<void> _publishImageExport(String path, List<int> bytes) async {
    final destination = File(path);
    final staging = await destination.parent.createTemp(
      ExportStorage.imageStagingPrefix,
    );
    try {
      final partial = File('${staging.path}/image.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(path);
      ExportStorage.invalidate();
    } finally {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
  }

  /// WebM書き出し（VP9）。libvpxはBSDライセンスかつVP9自体が
  /// ロイヤリティフリーのため、引き続きFFmpeg（GPLコーデックを含まない
  /// LGPL版のffmpeg_kit_flutter_new_video）で問題ない。[appendEndCard]が
  /// trueの場合、無料版のエンドカードをフレーム列の末尾へ同一シーケンス内で
  /// 追加する（FFmpegのdrawtext/concatフィルターには依存しない。ffmpegの
  /// image2デマルチプレクサは連番ファイルを要求するため、エンドカード画像を
  /// 必要フレーム数ぶん物理的に複製する）。
  Future<String> exportWebm({
    String? projectName,
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    int? sourceFps,
    int? maxSeconds,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    bool appendEndCard = false,
    ExportAudioPlan audio = ExportAudioPlan.empty,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
    VideoMaterialSnapshot? videoMaterials,
  }) async {
    return _withVideoFrames(
      materials: videoMaterials,
      framesPerSecond: sourceFps ?? fps,
      drawingWidth: drawingWidth,
      drawingHeight: drawingHeight,
      cancelToken: cancelToken,
      body: (video) async {
        final tmpDir = await getTemporaryDirectory();
        // 書き出しごとに別のフォルダ（同時に走る書き出しのコマを消さない）。
        final framesDir = _newFramesDir(tmpDir, 'export_webm_frames');
        String? partialOutput;
        try {
          int globalIndex = 0;
          final timing = ExportTiming(
            sourceFps: sourceFps ?? fps,
            outputFps: fps,
            maxSeconds: maxSeconds,
          );
          final totalFrames = timing.outputFrames(scenes);
          final layerHomes = buildLayerHomeIndex(scenes);

          Scene? lastScene;
          Frame? lastFrame;
          Uint8List? lastPng;
          for (final (:scene, :frame) in timing.samples(scenes)) {
            if (cancelToken?.isCancelled == true) {
              throw const ExportCancelledException();
            }
            if (!identical(lastScene, scene) ||
                !identical(lastFrame, frame) ||
                lastPng == null) {
              final rgba = await renderFrame(
                layers: resolveFrameLayers(
                  scenes,
                  layerHomes,
                  scene.id,
                  frame.index,
                  frame.layers,
                ),
                tileManager: tileManager,
                sceneId: scene.id,
                scene: scene,
                frameIndex: frame.index,
                drawingWidth: drawingWidth,
                drawingHeight: drawingHeight,
                width: width,
                height: height,
                backgroundColor: backgroundColor,
                cameraKeyframes: scene.cameraKeyframes,
                effectFilters: scene.effectFilters,
                layerHomes: layerHomes,
                groups: scene.groups,
                videoPixels: video,
              );
              lastPng = encodeFramePng(rgba, width, height);
              lastScene = scene;
              lastFrame = frame;
            }
            final file = File(
              '${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png',
            );
            await file.writeAsBytes(lastPng);
            onProgress?.call(globalIndex + 1, totalFrames);
            globalIndex++;
          }

          if (appendEndCard) {
            final endCardBytes = await _renderEndCardPng(
              width: width,
              height: height,
            );
            for (int i = 0; i < fps * officialEndCardSeconds; i++) {
              final file = File(
                '${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png',
              );
              await file.writeAsBytes(endCardBytes);
              globalIndex++;
            }
          }

          final exportsDir = await ExportEngine.exportsDir();
          final outputPath = _freshOutputPath(exportsDir, projectName, 'webm');
          partialOutput = outputPath;
          final sound = await _mixSound(
            audio,
            globalIndex / fps,
            framesDir,
            cancelToken,
          );
          await _encodeWithSound(
            video: [
              '-framerate',
              fps.toString(),
              '-i',
              '${framesDir.path}/frame_%06d.png',
            ],
            codecs: ['-c:v', 'libvpx-vp9', '-pix_fmt', 'yuva420p'],
            // WebM carries Opus. The app's FFmpeg has no libopus, so its own
            // Opus encoder is used (marked experimental by FFmpeg).
            soundCodec: ['-c:a', 'opus', '-strict', '-2', '-b:a', '128k'],
            sound: sound,
            audio: audio,
            outputPath: outputPath,
          );
          ExportStorage.invalidate();
          return outputPath;
        } catch (_) {
          if (partialOutput != null) await _discardPartialVideo(partialOutput);
          rethrow;
        } finally {
          _removeFrames(framesDir);
        }
      },
    );
  }

  /// AVI書き出し（Motion JPEG）。コーデックにはFFmpeg本体が内蔵する
  /// mjpegエンコーダーを使う（外部GPLライブラリへのリンクを必要とせず、
  /// `ffmpeg_kit_flutter_new_video`のLGPL版に標準で含まれる）。AVIで
  /// 一般的なMPEG-4 Part 2（`mpeg4`コーデック）はMPEG LAの特許プールの
  /// 対象になり得るため避け、古くから広く使われロイヤリティに関する
  /// 訴訟実務上の懸念が実質的に生じていないMotion JPEGを選んだ
  /// （MP4のH.264を避けた際と同じ考え方）。MJPEGは各フレームを独立した
  /// JPEG画像として符号化するためアルファチャンネルは保持できない
  /// （透過が必要な場合は透過WebMを使う）。[appendEndCard]の扱いはMP4と
  /// 同様（無料版のみ、フレーム生成の段階で末尾へ焼き込む）。
  Future<String> exportAvi({
    String? projectName,
    required List<Scene> scenes,
    required TileManager tileManager,
    required int fps,
    int? sourceFps,
    int? maxSeconds,
    required int drawingWidth,
    required int drawingHeight,
    required int width,
    required int height,
    required int backgroundColor,
    bool appendEndCard = false,
    ExportAudioPlan audio = ExportAudioPlan.empty,
    ExportProgressCallback? onProgress,
    ExportCancelToken? cancelToken,
    VideoMaterialSnapshot? videoMaterials,
  }) async {
    return _withVideoFrames(
      materials: videoMaterials,
      framesPerSecond: sourceFps ?? fps,
      drawingWidth: drawingWidth,
      drawingHeight: drawingHeight,
      cancelToken: cancelToken,
      body: (video) async {
        final tmpDir = await getTemporaryDirectory();
        // 書き出しごとに別のフォルダ（同時に走る書き出しのコマを消さない）。
        final framesDir = _newFramesDir(tmpDir, 'export_avi_frames');
        String? partialOutput;
        try {
          int globalIndex = 0;
          final timing = ExportTiming(
            sourceFps: sourceFps ?? fps,
            outputFps: fps,
            maxSeconds: maxSeconds,
          );
          final totalFrames = timing.outputFrames(scenes);
          final layerHomes = buildLayerHomeIndex(scenes);

          Scene? lastScene;
          Frame? lastFrame;
          Uint8List? lastPng;
          for (final (:scene, :frame) in timing.samples(scenes)) {
            if (cancelToken?.isCancelled == true) {
              throw const ExportCancelledException();
            }
            if (!identical(lastScene, scene) ||
                !identical(lastFrame, frame) ||
                lastPng == null) {
              final rgba = await renderFrame(
                layers: resolveFrameLayers(
                  scenes,
                  layerHomes,
                  scene.id,
                  frame.index,
                  frame.layers,
                ),
                tileManager: tileManager,
                sceneId: scene.id,
                scene: scene,
                frameIndex: frame.index,
                drawingWidth: drawingWidth,
                drawingHeight: drawingHeight,
                width: width,
                height: height,
                backgroundColor: backgroundColor,
                cameraKeyframes: scene.cameraKeyframes,
                effectFilters: scene.effectFilters,
                layerHomes: layerHomes,
                groups: scene.groups,
                videoPixels: video,
              );
              lastPng = encodeFramePng(rgba, width, height);
              lastScene = scene;
              lastFrame = frame;
            }
            final file = File(
              '${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png',
            );
            await file.writeAsBytes(lastPng);
            onProgress?.call(globalIndex + 1, totalFrames);
            globalIndex++;
          }

          if (appendEndCard) {
            final endCardBytes = await _renderEndCardPng(
              width: width,
              height: height,
            );
            for (int i = 0; i < fps * officialEndCardSeconds; i++) {
              final file = File(
                '${framesDir.path}/frame_${globalIndex.toString().padLeft(6, '0')}.png',
              );
              await file.writeAsBytes(endCardBytes);
              globalIndex++;
            }
          }

          final exportsDir = await ExportEngine.exportsDir();
          final outputPath = _freshOutputPath(exportsDir, projectName, 'avi');
          partialOutput = outputPath;
          // mjpegはアルファ非対応のため、透過を破棄してbackgroundColorで合成済みの
          // RGBを不透明のyuvj420pへ変換する（yuva420p等は指定しない）。
          final sound = await _mixSound(
            audio,
            globalIndex / fps,
            framesDir,
            cancelToken,
          );
          await _encodeWithSound(
            video: [
              '-framerate',
              fps.toString(),
              '-i',
              '${framesDir.path}/frame_%06d.png',
            ],
            codecs: ['-c:v', 'mjpeg', '-pix_fmt', 'yuvj420p', '-q:v', '3'],
            // Uncompressed PCM: the usual sound of an MJPEG AVI for editing.
            soundCodec: ['-c:a', 'pcm_s16le'],
            sound: sound,
            audio: audio,
            outputPath: outputPath,
          );
          ExportStorage.invalidate();
          return outputPath;
        } catch (_) {
          if (partialOutput != null) await _discardPartialVideo(partialOutput);
          rethrow;
        } finally {
          _removeFrames(framesDir);
        }
      },
    );
  }
}
