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
  Layer layer,
  String homeSceneId,
  String targetSceneId,
  int targetFrameIndex,
) {
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
  return scene.frames[home.frameIndex].layers
      .where((l) => l.id == layerId)
      .firstOrNull;
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
  // This frame's own placing of the range layers kept in other frames, and
  // the common layers taken out of this frame only.
  final scene = scenes.where((s) => s.id == sceneId).firstOrNull;
  final frame =
      scene != null && frameIndex >= 0 && frameIndex < scene.frames.length
      ? scene.frames[frameIndex]
      : null;
  final slots = frame?.commonSlots ?? const <String, int>{};
  final hidden = frame?.hiddenCommon ?? const <String>{};
  final visibleOwn = ownLayers.where((layer) {
    if (!isRangeLayerType(layer.type)) return true;
    if (hidden.contains(layer.id)) return false;
    final homeSceneId = homes[layer.id]?.sceneId ?? sceneId;
    return rangeAppliesToFrame(layer, homeSceneId, sceneId, frameIndex);
  }).toList();
  final ownIds = ownLayers.map((l) => l.id).toSet();
  final extra = <Layer>[];
  for (final entry in homes.entries) {
    if (ownIds.contains(entry.key) || hidden.contains(entry.key)) continue;
    final home = entry.value;
    if (home.sceneId == sceneId && home.frameIndex == frameIndex) continue;
    final layer = _layerAtHome(scenes, home, entry.key);
    if (layer == null) continue;
    if (rangeAppliesToFrame(layer, home.sceneId, sceneId, frameIndex)) {
      extra.add(layer);
    }
  }
  if (extra.isEmpty && visibleOwn.length == ownLayers.length) return ownLayers;
  // A range layer with a place goes there (counted from the top, nearest
  // first); one without goes below the frame's own layers, as before.
  final placed = <({int slot, Layer layer})>[];
  final below = <Layer>[];
  for (final layer in extra) {
    final slot = slots[layer.id] ?? layer.commonSlot;
    if (slot == null) {
      below.add(layer);
    } else {
      placed.add((slot: slot, layer: layer));
    }
  }
  if (placed.isEmpty) return [...visibleOwn, ...extra];
  // Stable: two layers at the same place keep their order.
  final ordered =
      [for (var i = 0; i < placed.length; i++) (i: i, entry: placed[i])]
        ..sort((a, b) {
          final bySlot = a.entry.slot.compareTo(b.entry.slot);
          return bySlot != 0 ? bySlot : a.i.compareTo(b.i);
        });
  final result = [...visibleOwn];
  for (final item in ordered) {
    final at = item.entry.slot.clamp(0, result.length);
    result.insert(at, item.entry.layer);
  }
  return [...result, ...below];
}

/// レイヤーのTileManager合成キーを解決する。表示範囲レイヤーは表示中の
/// フレームに関わらずホーム位置のタイルバッファを常に参照する。
String resolveTileKey(
  Map<String, LayerHome> homes,
  String sceneId,
  int frameIndex,
  String layerId,
) {
  final home = homes[layerId];
  if (home != null) {
    return frameLayerKey(home.sceneId, home.frameIndex, layerId);
  }
  return frameLayerKey(sceneId, frameIndex, layerId);
}
