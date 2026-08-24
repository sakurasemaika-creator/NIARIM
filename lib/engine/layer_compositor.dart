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
/// 「減算」はdart:ui標準のBlendModeに直接対応するものが無いため、
/// 視覚的に近い「差の絶対値」で近似する。
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
      return ui.BlendMode.difference; // dart:uiに減算が無いための近似
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
/// クリッピング元もさらにクリッピングされている場合は、非クリッピングの
/// レイヤーが見つかるまで下（配列の後方）を辿る。
/// 「フォルダを跨ぐクリッピングは禁止」のため、同じ
/// parentFolderId（同一フォルダ内、またはどちらもトップレベル）の
/// レイヤーのみを探索対象とし、フォルダ境界に達したら探索を打ち切る。
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
  /// [layers]はレイヤーパネル順（先頭が最前面）。[keyOf]は各レイヤーの
  /// TileManager合成キーを返す（通常レイヤーは`frameLayerKey(sceneId, frameIndex,
  /// layer.id)`。共通・タイムライン素材・ウォーターマークなど表示範囲を持つ
  /// レイヤーは`resolveTileKey`〔layer_range_resolver.dart〕でホーム位置の
  /// キーを解決する必要がある）。
  /// [shouldRender]でfalseを返したレイヤーは描画をスキップするが、他のレイヤーの
  /// クリッピング元としては引き続き参照されうる。
  static Future<ui.Image> composite(
    TileManager tileManager,
    List<Layer> layers,
    String Function(Layer layer) keyOf,
    int width,
    int height, {
    bool Function(Layer layer, int index)? shouldRender,
    // 指定した場合、レイヤーごとの位置・拡大縮小・回転キーフレームを合成時に
    // 適用する（呼び出し側が現在フレームで補間済みの値を渡す。パーツ単位
    // キーフレームアニメーション）。省略時は従来通り無変形。
    LayerKeyframe? Function(Layer layer)? keyframeOf,
    // 指定した場合、レイヤーが所属するグループのキーフレームを合成時に
    // 追加で適用する（グループ＝複数レイヤーをまとめて動かす全体の変形、
    // keyframeOf＝そのレイヤー個別の追加調整、という関係で両方を重ねて
    // 適用する）。省略時は従来通り無変形。
    LayerKeyframe? Function(Layer layer)? groupKeyframeOf,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (int i = layers.length - 1; i >= 0; i--) {
      final layer = layers[i];
      if (!layer.isVisible) continue;
      if (!pixelLayerTypes.contains(layer.type)) continue;
      if (shouldRender != null && !shouldRender(layer, i)) continue;
      await _drawLayer(
          canvas, tileManager, layers, keyOf, layer, i, width, height, keyframeOf, groupKeyframeOf);
    }
    final picture = recorder.endRecording();
    return picture.toImage(width, height);
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
    LayerKeyframe? Function(Layer layer)? groupKeyframeOf,
  ) async {
    final img = await tileManager.compositeLayerToImage(keyOf(layer));
    final opacityByte = (layer.opacity.clamp(0, 100) * 255 / 100).round();
    final layerPaint = ui.Paint()
      ..color = ui.Color.fromARGB(opacityByte, 255, 255, 255)
      ..blendMode = mapLayerBlendMode(layer.blendMode);

    final groupKf = groupKeyframeOf?.call(layer);
    final kf = keyframeOf?.call(layer);
    final hasGroupTransform = groupKf != null && !_layerKeyframeEngine.isIdentity(groupKf);
    final hasLayerTransform = kf != null && !_layerKeyframeEngine.isIdentity(kf);
    final hasTransform = hasGroupTransform || hasLayerTransform;
    if (hasTransform) {
      canvas.save();
      // グループの変形（全体の動き）を先に適用し、そこへレイヤー個別の
      // 変形（その上への微調整）を重ねる。
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
        // クリッピング元はlayers内の別レイヤーなのでkeyOfへ渡すために一旦探す
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
}
