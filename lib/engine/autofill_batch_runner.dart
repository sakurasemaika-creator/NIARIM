import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import '../models/autofill_preset.dart' show AutofillLineColorMode;
import '../models/layer.dart';
import '../services/autofill_preset_service.dart';
import '../services/project_service.dart';
import '../services/tone_service.dart';
import 'autofill_engine.dart';
import 'procedural_texture.dart';
import 'tile_manager.dart';

/// 自動塗り用線画レイヤー1枚分の自動塗り・線画色再着色を実行し、結果を
/// 対応レイヤーへ書き戻す。layer_panel.dart（描画モード：手動
/// 単体実行）とtimeline_screen.dart（一括実行）の両方が使う共通処理。
///
/// パーツ未設定・対応プリセットが見つからない場合は何もせず[AutofillBatchResult.skipped]
/// を返す（一括実行時に個別ダイアログを出さずスキップして続行するため）。
enum AutofillBatchResult { applied, skipped }

const _toneSize = 64;

Future<AutofillBatchResult> runAutofillForLayer({
  required ProjectService projectService,
  required AutofillPresetService presetService,
  required ToneService toneService,
  required String projectId,
  required String sceneId,
  required int frameIndex,
  required Layer lineartLayer,
  required AutofillMode mode,
}) async {
  final partId = lineartLayer.partId;
  if (partId == null) return AutofillBatchResult.skipped;
  final part = presetService.findPart(partId);
  if (part == null) return AutofillBatchResult.skipped;

  final tileManager = projectService.tileManagerOf(projectId);
  final w = tileManager.canvasWidth;
  final h = tileManager.canvasHeight;
  final lineartKey = frameLayerKey(sceneId, frameIndex, lineartLayer.id);

  final lineartImg = await tileManager.compositeLayerToImage(lineartKey);
  final lineartBytes = (await lineartImg.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  lineartImg.dispose();

  var layers = projectService.layersOf(projectId, sceneId, frameIndex);
  final lineartIdx = layers.indexWhere((l) => l.id == lineartLayer.id);
  Layer? autofillLayer =
      (lineartIdx >= 0 &&
          lineartIdx + 1 < layers.length &&
          layers[lineartIdx + 1].type == LayerType.autoFill)
      ? layers[lineartIdx + 1]
      : null;

  final autofillKey = autofillLayer == null
      ? null
      : frameLayerKey(sceneId, frameIndex, autofillLayer.id);
  final hasExisting = autofillKey != null && tileManager.hasLayer(autofillKey);
  Uint8List? existingBytes;
  if (hasExisting) {
    final img = await tileManager.compositeLayerToImage(autofillKey);
    existingBytes = (await img.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    img.dispose();
  }

  Uint8List? toneTexture;
  if (part.useTone && part.toneId != null) {
    final tone = toneService.tones
        .where((t) => t.id == part.toneId)
        .firstOrNull;
    if (tone != null)
      toneTexture = generateBuiltInToneTexture(tone, size: _toneSize);
  }

  // 新規生成時（対応する自動塗りレイヤーが存在しない場合）は色更新選択時でも必ず一から塗る。
  // フラッドフィルはキャンバス全体を走査する重い処理のため、compute()で
  // バックグラウンドisolate実行しUIスレッドが固まらないようにする。
  final effectiveMode = hasExisting ? mode : AutofillMode.repaint;
  final result = await compute(runAutofillExecuteInIsolate, (
    mode: effectiveMode,
    lineartData: lineartBytes,
    existingData: hasExisting ? existingBytes : null,
    width: w,
    height: h,
    part: part,
    toneTexture: toneTexture,
    toneWidth: _toneSize,
    toneHeight: _toneSize,
  ));
  if (result == null) return AutofillBatchResult.skipped;

  if (autofillLayer == null) {
    final created = projectService.addLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      type: LayerType.autoFill,
      name: '${part.name}（自動塗り）',
    );
    layers = projectService.layersOf(projectId, sceneId, frameIndex);
    final createdIdx = layers.indexWhere((l) => l.id == created.id);
    final targetIdx = layers.indexWhere((l) => l.id == lineartLayer.id) + 1;
    if (createdIdx >= 0 && targetIdx >= 0 && createdIdx != targetIdx) {
      projectService.reorderLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        oldIndex: createdIdx,
        newIndex: targetIdx,
      );
    }
    autofillLayer = created.copyWith(partId: part.id);
  }

  tileManager.replaceLayerPixels(
    frameLayerKey(sceneId, frameIndex, autofillLayer.id),
    result,
  );
  projectService.updateLayer(
    projectId: projectId,
    sceneId: sceneId,
    frameIndex: frameIndex,
    layer: autofillLayer.copyWith(
      partId: part.id,
      needsAutofillUpdate: false,
      opacity: part.opacity,
      blendMode: part.blendMode,
      opacityLocked: effectiveMode == AutofillMode.colorUpdate
          ? true
          : autofillLayer.opacityLocked,
    ),
  );

  // 線画色設定（指定色／塗り色と同じ／色トレス・線画馴染ませ）を線画レイヤーへ
  // 反映する。指定色が既定の黒のままなら変更不要なので処理自体をスキップする。
  final lineartUnchanged =
      part.lineColorMode == AutofillLineColorMode.specified &&
      part.lineColor == 0xFF000000;
  if (!lineartUnchanged) {
    final recoloredLineart = await compute(runRecolorLineartInIsolate, (
      lineartData: lineartBytes,
      width: w,
      height: h,
      part: part,
    ));
    tileManager.replaceLayerPixels(lineartKey, recoloredLineart);
  }
  projectService.updateLayer(
    projectId: projectId,
    sceneId: sceneId,
    frameIndex: frameIndex,
    layer: lineartLayer.copyWith(
      opacity: part.lineOpacity,
      blendMode: part.blendMode,
    ),
  );

  return AutofillBatchResult.applied;
}

/// 対応する自動塗り用線画レイヤーが存在しない自動塗りレイヤー（線画レイヤーを
/// 削除した後に残った状態）を処理する。参照する線画が無いため領域の
/// 再判定はできず、常に不透明度ロック＋最新色での塗りつぶし（色更新と同じ
/// 処理）のみを行う。
Future<AutofillBatchResult> runAutofillForOrphanedLayer({
  required ProjectService projectService,
  required AutofillPresetService presetService,
  required String projectId,
  required String sceneId,
  required int frameIndex,
  required Layer autofillLayer,
}) async {
  final partId = autofillLayer.partId;
  if (partId == null) return AutofillBatchResult.skipped;
  final part = presetService.findPart(partId);
  if (part == null) return AutofillBatchResult.skipped;

  final tileManager = projectService.tileManagerOf(projectId);
  final key = frameLayerKey(sceneId, frameIndex, autofillLayer.id);
  if (!tileManager.hasLayer(key)) return AutofillBatchResult.skipped;

  final w = tileManager.canvasWidth;
  final h = tileManager.canvasHeight;
  final img = await tileManager.compositeLayerToImage(key);
  final existingBytes = (await img.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  img.dispose();

  final result = await compute(runAutofillColorUpdateInIsolate, (
    existingData: existingBytes,
    width: w,
    height: h,
    part: part,
    toneTexture: null,
    toneWidth: _toneSize,
    toneHeight: _toneSize,
  ));

  tileManager.replaceLayerPixels(key, result);
  projectService.updateLayer(
    projectId: projectId,
    sceneId: sceneId,
    frameIndex: frameIndex,
    layer: autofillLayer.copyWith(
      partId: part.id,
      needsAutofillUpdate: false,
      opacityLocked: true,
    ),
  );
  return AutofillBatchResult.applied;
}

/// [layers]内で[autofillLayer]（LayerType.autoFill）が、直上に対応する
/// LayerType.autoFillLineartレイヤーを持たない「孤立した自動塗りレイヤー」
/// かどうかを判定する。自動塗りレイヤーは対応する線画レイヤーの
/// 直下に配置されるという配置ルールに基づく判定。
bool isOrphanedAutofillLayer(List<Layer> layers, Layer autofillLayer) {
  if (autofillLayer.type != LayerType.autoFill) return false;
  final idx = layers.indexWhere((l) => l.id == autofillLayer.id);
  if (idx <= 0) return true;
  return layers[idx - 1].type != LayerType.autoFillLineart;
}
