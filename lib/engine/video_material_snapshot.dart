import '../models/material_asset.dart';

/// Immutable, project-scoped view of video assets for one preview/export job.
///
/// A registered asset remains in the snapshot even when its file is missing;
/// [VideoMaterialSource.path] is then null so callers can report a missing
/// source instead of silently substituting a placeholder frame.
class VideoMaterialSource {
  const VideoMaterialSource({
    required this.materialId,
    required this.path,
    required this.duration,
  });

  final String materialId;
  final String? path;
  final Duration? duration;

  bool get isMissing => path == null;
}

class VideoMaterialSnapshot {
  VideoMaterialSnapshot._(Map<String, VideoMaterialSource> sources)
    : sources = Map.unmodifiable(sources);

  final Map<String, VideoMaterialSource> sources;

  VideoMaterialSource? operator [](String materialId) => sources[materialId];

  bool contains(String materialId) => sources.containsKey(materialId);

  static VideoMaterialSnapshot fromAssets(
    Iterable<MaterialAsset> assets,
    Map<String, String?> paths,
  ) {
    final result = <String, VideoMaterialSource>{};
    for (final asset in assets) {
      if (asset.type != MaterialType.video) continue;
      result[asset.id] = VideoMaterialSource(
        materialId: asset.id,
        path: paths[asset.id],
        duration: asset.duration,
      );
    }
    return VideoMaterialSnapshot._(result);
  }
}
