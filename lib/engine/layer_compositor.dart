import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/layer.dart';
import '../models/layer_keyframe.dart';
import 'layer_keyframe_engine.dart';
import 'tile_manager.dart';

final _layerKeyframeEngine = LayerKeyframeEngine();

/// レイヤー種別のうちTileManagerに実ピクセルデータを持つもの
/// （通常・自動塗り用線画・自動塗り・共通・タイムライン画像/動画素材・
/// ウォーターマーク・テキスト。いずれも frameLayerKey 経由でタイルへ
/// ラスタライズ済みのピクセルを持つ。テキストは編集時のみtextObjectを
/// 保持し、表示・書き出し時はラスタライズ済みピクセル（text_render.dart）
/// を使う、ラスター専用方針に沿う）。
/// フォルダ（表示構造のみ）・選択レイヤー（内部専用）は対象外。
const Set<LayerType> pixelLayerTypes = {
  LayerType.normal,
  LayerType.autoFillLineart,
  LayerType.autoFill,
  LayerType.common,
  LayerType.timelineImage,
  LayerType.timelineVideo,
  LayerType.watermark,
  LayerType.text,
};

/// LayerBlendMode（17種）をdart:uiのBlendModeへ変換する。
/// 減算だけはdart:uiに対応BlendModeが存在しないため、[LayerCompositor]
/// 内でRGBAを用いた本来の「backdrop - source（0未満は0）」を実装する。
/// この関数単体でsubtractを要求された場合は、誤ってdifferenceを適用しない
/// ようsrcOverを返す。
ui.BlendMode mapLayerBlendMode(LayerBlendMode mode) {
  switch (mode) {
    case LayerBlendMode.normal:
      return ui.BlendMode.srcOver;
    case LayerBlendMode.multiply:
      return ui.BlendMode.multiply;
    case LayerBlendMode.screen:
      return ui.BlendMode.screen;
    case LayerBlendMode.overlay:
      return ui.BlendMode.overlay;
    case LayerBlendMode.addition:
      return ui.BlendMode.plus;
    case LayerBlendMode.subtract:
      return ui.BlendMode.srcOver;
    case LayerBlendMode.darken:
      return ui.BlendMode.darken;
    case LayerBlendMode.lighten:
      return ui.BlendMode.lighten;
    case LayerBlendMode.colorBurn:
      return ui.BlendMode.colorBurn;
    case LayerBlendMode.colorDodge:
      return ui.BlendMode.colorDodge;
    case LayerBlendMode.hardLight:
      return ui.BlendMode.hardLight;
    case LayerBlendMode.softLight:
      return ui.BlendMode.softLight;
    case LayerBlendMode.difference:
      return ui.BlendMode.difference;
    case LayerBlendMode.hue:
      return ui.BlendMode.hue;
    case LayerBlendMode.saturation:
      return ui.BlendMode.saturation;
    case LayerBlendMode.color:
      return ui.BlendMode.color;
    case LayerBlendMode.luminosity:
      return ui.BlendMode.luminosity;
  }
}

/// [layers]（先頭が最前面／末尾が最背面、レイヤーパネル表示順）の中で、
/// index番目のレイヤーがクリッピングONの場合に参照すべき「一番下の
/// クリッピング元レイヤー」のIDを探す。
String? findClipSourceLayerId(List<Layer> layers, int index) {
  final parentFolderId = layers[index].parentFolderId;
  for (int i = index + 1; i < layers.length; i++) {
    if (layers[i].parentFolderId != parentFolderId) return null;
    if (!layers[i].hasClipping) return layers[i].id;
  }
  return null;
}

/// レイヤー群をタイル方式のピクセルデータから合成し1枚のui.Imageを生成する
/// 共通処理。キャンバス表示・書き出し・オニオンスキン・バケツ参照などで共有する。
class LayerCompositor {
  static Future<ui.Image> composite(
    TileManager tileManager,
    List<Layer> layers,
    String Function(Layer layer) keyOf,
    int width,
    int height, {
    bool Function(Layer layer, int index)? shouldRender,
    LayerKeyframe? Function(Layer layer)? keyframeOf,
    LayerKeyframe? Function(Layer layer)? groupKeyframeOf,
  }) async {
    var recorder = ui.PictureRecorder();
    var canvas = ui.Canvas(recorder);

    for (int i = layers.length - 1; i >= 0; i--) {
      final layer = layers[i];
      if (!layer.isVisible) continue;
      if (!pixelLayerTypes.contains(layer.type)) continue;
      if (shouldRender != null && !shouldRender(layer, i)) continue;

      if (layer.blendMode == LayerBlendMode.subtract) {
        // Skia/dart:uiには「減算」BlendModeが無い。difference（差の絶対値）
        // で代用すると、backdrop < source のチャンネルが本来0になるところ
        // 正の値へ反転してしまうため、ここだけ現在までの合成結果と対象レイヤー
        // をRGBAへ落としてW3Cのalpha合成式で本当の減算を行う。
        final backdropPicture = recorder.endRecording();
        final backdrop = await backdropPicture.toImage(width, height);
        backdropPicture.dispose();

        final source = await _renderLayerIsolated(
          tileManager,
          layers,
          keyOf,
          layer,
          i,
          width,
          height,
          keyframeOf,
          groupKeyframeOf,
        );
        final subtracted = await _subtractImages(backdrop, source, width, height);
        backdrop.dispose();
        source.dispose();

        recorder = ui.PictureRecorder();
        canvas = ui.Canvas(recorder);
        canvas.drawImage(subtracted, ui.Offset.zero, ui.Paint());
        subtracted.dispose();
        continue;
      }

      await _drawLayer(
        canvas,
        tileManager,
        layers,
        keyOf,
        layer,
        i,
        width,
        height,
        keyframeOf,
        groupKeyframeOf,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  /// 減算対象レイヤーを、opacity・クリッピング・位置/回転/拡縮をすべて
  /// 適用した「透明背景上の通常合成画像」として作る。これによりCPU減算側は
  /// レイヤーの見た目を再実装せず、最終RGBAだけを正しく合成すればよい。
  static Future<ui.Image> _renderLayerIsolated(
    TileManager tileManager,
    List<Layer> layers,
    String Function(Layer layer) keyOf,
    Layer layer,
    int index,
    int width,
    int height,
    LayerKeyframe? Function(Layer layer)? keyframeOf,
    LayerKeyframe? Function(Layer layer)? groupKeyframeOf,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    await _drawLayer(
      canvas,
      tileManager,
      layers,
      keyOf,
      layer,
      index,
      width,
      height,
      keyframeOf,
      groupKeyframeOf,
      blendModeOverride: ui.BlendMode.srcOver,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  static Future<void> _drawLayer(
    ui.Canvas canvas,
    TileManager tileManager,
    List<Layer> layers,
    String Function(Layer layer) keyOf,
    Layer layer,
    int index,
    int width,
    int height,
    LayerKeyframe? Function(Layer layer)? keyframeOf,
    LayerKeyframe? Function(Layer layer)? groupKeyframeOf, {
    ui.BlendMode? blendModeOverride,
  }) async {
    final img = await tileManager.compositeLayerToImage(keyOf(layer));
    final opacityByte = (layer.opacity.clamp(0, 100) * 255 / 100).round();
    final layerPaint = ui.Paint()
      ..color = ui.Color.fromARGB(opacityByte, 255, 255, 255)
      ..blendMode = blendModeOverride ?? mapLayerBlendMode(layer.blendMode);

    final groupKf = groupKeyframeOf?.call(layer);
    final kf = keyframeOf?.call(layer);
    final hasGroupTransform = groupKf != null && !_layerKeyframeEngine.isIdentity(groupKf);
    final hasLayerTransform = kf != null && !_layerKeyframeEngine.isIdentity(kf);
    final hasTransform = hasGroupTransform || hasLayerTransform;
    if (hasTransform) {
      canvas.save();
      if (hasGroupTransform) {
        _layerKeyframeEngine.apply(canvas, groupKf, width.toDouble(), height.toDouble());
      }
      if (hasLayerTransform) {
        _layerKeyframeEngine.apply(canvas, kf, width.toDouble(), height.toDouble());
      }
    }

    if (layer.hasClipping) {
      final clipSourceId = findClipSourceLayerId(layers, index);
      if (clipSourceId != null) {
        final clipSourceLayer = layers.firstWhere((l) => l.id == clipSourceId);
        final clipImg = await tileManager.compositeLayerToImage(keyOf(clipSourceLayer));
        final rect = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
        canvas.saveLayer(rect, layerPaint);
        canvas.drawImage(clipImg, ui.Offset.zero, ui.Paint());
        canvas.drawImage(img, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.srcIn);
        canvas.restore();
        if (hasTransform) canvas.restore();
        clipImg.dispose();
        img.dispose();
        return;
      }
    }

    canvas.drawImage(img, ui.Offset.zero, layerPaint);
    if (hasTransform) canvas.restore();
    img.dispose();
  }

  /// backdrop - source を各RGBチャンネルへ適用し、透明度は通常のブレンド
  /// モードと同じsource-over規則で合成する。半透明レイヤー・半透明背景でも
  /// 正しい結果になるよう、W3C Compositing and Blendingの一般式を使う。
  static Future<ui.Image> _subtractImages(
      ui.Image backdrop, ui.Image source, int width, int height) async {
    final backdropData = await backdrop.toByteData(format: ui.ImageByteFormat.rawRgba);
    final sourceData = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (backdropData == null || sourceData == null) {
      // ネイティブ画像の読み出しに失敗した場合だけ、安全側として元の背景を返す。
      return backdrop.clone();
    }

    final b = backdropData.buffer.asUint8List();
    final s = sourceData.buffer.asUint8List();
    final out = Uint8List(width * height * 4);

    for (int i = 0; i < out.length; i += 4) {
      final ab = b[i + 3] / 255.0;
      final as = s[i + 3] / 255.0;
      final ao = as + ab * (1.0 - as);
      if (ao <= 0) continue;

      for (int c = 0; c < 3; c++) {
        final cb = b[i + c] / 255.0;
        final cs = s[i + c] / 255.0;
        final blended = (cb - cs).clamp(0.0, 1.0);
        final premultiplied =
            as * (1.0 - ab) * cs +
            as * ab * blended +
            (1.0 - as) * ab * cb;
        out[i + c] = (premultiplied / ao * 255).round().clamp(0, 255);
      }
      out[i + 3] = (ao * 255).round().clamp(0, 255);
    }

    final codec = await ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(out),
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    ).instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
