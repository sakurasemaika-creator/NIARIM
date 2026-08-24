import '../models/layer.dart';
import '../models/scene.dart';
import 'tile_manager.dart';

/// レイヤーのホーム位置（実データが物理的に存在するシーン・フレーム）。
typedef LayerHome = ({String sceneId, int frameIndex});

/// [scenes]全体を走査し、表示範囲レイヤー（共通・タイムライン素材・
/// ウォーターマーク）のホーム位置インデックスを構築する。ExportEngineなど
/// ProjectServiceを介さずシーンデータを直接扱う箇所で使う。
Map<String, LayerHome> buildLayerHomeIndex(List<Scene> scenes) {
  final homes = <String, LayerHome>{};
  for (final scene in scenes) {
    for (int fi = 0; fi < scene.frames.length; fi++) {
      for (final layer in scene.frames[fi].layers) {
        if (isRangeLayerType(layer.type)) {
          homes[layer.id] = (sceneId: scene.id, frameIndex: fi);
        }
      }
    }
  }
  return homes;
}

/// [layer]（ホームが[homeSceneId]）が、[targetSceneId]の[targetFrameIndex]
/// フレームに表示範囲として適用されるかを判定する。
bool rangeAppliesToFrame(
    Layer layer, String homeSceneId, String targetSceneId, int targetFrameIndex) {
  switch (layer.rangeMode) {
    case LayerRangeMode.allFrames:
      return true;
    case LayerRangeMode.currentScene:
      return homeSceneId == targetSceneId;
    case LayerRangeMode.sceneRange:
      // 対象シーンが未指定の場合はホームのシーンをそのまま対象とする
      return (layer.rangeSceneId ?? homeSceneId) == targetSceneId;
    case LayerRangeMode.frameRange:
      if (homeSceneId != targetSceneId) return false;
      final start = (layer.rangeStart ?? 1) - 1;
      final end = (layer.rangeEnd ?? start + 1) - 1;
      return targetFrameIndex >= start && targetFrameIndex <= end;
  }
}

Layer? _layerAtHome(List<Scene> scenes, LayerHome home, String layerId) {
  final scene = scenes.where((s) => s.id == home.sceneId).firstOrNull;
  if (scene == null || home.frameIndex >= scene.frames.length) return null;
  return scene.frames[home.frameIndex].layers.where((l) => l.id == layerId).firstOrNull;
}

/// [sceneId]の[frameIndex]フレームで実際に表示すべきレイヤー一覧を返す
/// （[ownLayers]＝そのフレームに物理的に存在するレイヤーに、[homes]から
/// 該当する表示範囲レイヤーを動的に合成する）。
List<Layer> resolveFrameLayers(
  List<Scene> scenes,
  Map<String, LayerHome> homes,
  String sceneId,
  int frameIndex,
  List<Layer> ownLayers,
) {
  if (homes.isEmpty) return ownLayers;
  final ownIds = ownLayers.map((l) => l.id).toSet();
  final extra = <Layer>[];
  for (final entry in homes.entries) {
    if (ownIds.contains(entry.key)) continue;
    final home = entry.value;
    if (home.sceneId == sceneId && home.frameIndex == frameIndex) continue;
    final layer = _layerAtHome(scenes, home, entry.key);
    if (layer == null) continue;
    if (rangeAppliesToFrame(layer, home.sceneId, sceneId, frameIndex)) {
      extra.add(layer);
    }
  }
  if (extra.isEmpty) return ownLayers;
  return [...ownLayers, ...extra];
}

/// レイヤーのTileManager合成キーを解決する。表示範囲レイヤーは表示中の
/// フレームに関わらずホーム位置のタイルバッファを常に参照する。
String resolveTileKey(
    Map<String, LayerHome> homes, String sceneId, int frameIndex, String layerId) {
  final home = homes[layerId];
  if (home != null) return frameLayerKey(home.sceneId, home.frameIndex, layerId);
  return frameLayerKey(sceneId, frameIndex, layerId);
}
