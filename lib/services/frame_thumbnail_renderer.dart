import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../engine/layer_compositor.dart';
import 'project_service.dart';

/// プロジェクト内の1フレームを合成し、指定した最大辺までダウンスケールした
/// [ui.Image]を返す。
///
/// [ProjectService.generateAndSaveThumbnail]・
/// `frame_strip_widget.dart`の`_FrameThumbnail`と同じ合成方式（
/// `LayerCompositor.composite`→書き出し範囲でクロップ→縮小）を使う。
///
/// [sceneId]・[frameIndex]を省略すると、それぞれ「先頭シーン」
/// 「先頭フレーム」を表す（ホーム画面ウィジェットの設定が種類ごとの
/// フレーム選択に対応する前のデータからの移行や、シーン・フレームが
/// まだ1つしかない作品を選んだときの既定挙動に使う）。
///
/// プロジェクトが存在しない・シーンやフレームが1枚も無い等の理由で
/// 合成できない場合はnullを返す。
Future<ui.Image?> compositeFrameThumbnail(
  ProjectService projectService, {
  required String projectId,
  String? sceneId,
  int? frameIndex,
  required int maxSize,
}) async {
  final project = projectService.projects
      .where((p) => p.id == projectId)
      .firstOrNull;
  final scenes = projectService.scenesOf(projectId);
  if (scenes.isEmpty) return null;
  final scene =
      (sceneId == null
          ? null
          : scenes.where((s) => s.id == sceneId).firstOrNull) ??
      scenes.first;
  if (scene.frames.isEmpty) return null;
  // layersOf/tileKeyForは「配列上の位置」をframeIndexとして扱う
  // （内部でscene.frames[frameIndex]と添字アクセスする）。Frame.indexという
  // フィールドも別途あるが、位置と食い違う可能性を排除するため、ここでは
  // 常に配列位置そのものを使う（frame_strip_widget.dartの_FrameThumbnailと
  // 同じ流儀）。
  final position = (frameIndex ?? 0).clamp(0, scene.frames.length - 1);

  final tileManager = projectService.tileManagerOf(projectId);
  final drawW = tileManager.canvasWidth;
  final drawH = tileManager.canvasHeight;
  if (drawW <= 0 || drawH <= 0) return null;
  final exportW = (project?.exportWidth ?? drawW).clamp(1, drawW).toInt();
  final exportH = (project?.exportHeight ?? drawH).clamp(1, drawH).toInt();

  final fullImage = await LayerCompositor.composite(
    tileManager,
    projectService.layersOf(projectId, scene.id, position),
    (l) => projectService.tileKeyFor(projectId, scene.id, position, l.id),
    drawW,
    drawH,
  );
  final offsetX = (drawW - exportW) / 2;
  final offsetY = (drawH - exportH) / 2;
  final scale = maxSize / (exportW > exportH ? exportW : exportH);
  final thumbW = (exportW * scale).round().clamp(1, maxSize);
  final thumbH = (exportH * scale).round().clamp(1, maxSize);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    fullImage,
    ui.Rect.fromLTWH(offsetX, offsetY, exportW.toDouble(), exportH.toDouble()),
    ui.Rect.fromLTWH(0, 0, thumbW.toDouble(), thumbH.toDouble()),
    ui.Paint(),
  );
  fullImage.dispose();
  final picture = recorder.endRecording();
  final thumb = await picture.toImage(thumbW, thumbH);
  picture.dispose();
  return thumb;
}

/// [compositeFrameThumbnail]と同じ条件でフレームを合成し、PNGとして
/// キャッシュディレクトリへ保存してパスを返す。
///
/// ホーム画面ウィジェット（ネイティブ側）は`RemoteViews.setImageViewBitmap`
/// にファイルパス経由でビットマップを渡すため、`ui.Image`のままでは
/// 渡せずファイル化が要る。呼び出すたびに同じファイル名へ上書きするため、
/// 古いファイルが際限なく増えることはない。
Future<String?> saveArtworkWidgetThumbnail(
  ProjectService projectService, {
  required String projectId,
  String? sceneId,
  int? frameIndex,
}) async {
  // ホーム画面ウィジェットは端末やランチャーによって数百px四方まで
  // 大きく置かれうるため、設定画面内のリスト用サムネイルより大きめに
  // 焼く（きれいな解像度が要る一方、際限なく大きくする理由もないので
  // 長辺480pxに丸める）。
  const maxSize = 480;
  final image = await compositeFrameThumbnail(
    projectService,
    projectId: projectId,
    sceneId: sceneId,
    frameIndex: frameIndex,
    maxSize: maxSize,
  );
  if (image == null) return null;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final bytes = byteData?.buffer.asUint8List();
  if (bytes == null) return null;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/home_widget_artwork_thumb.png');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
