/// The part of the work to export: one scene, frames [start] to [end]
/// (0-based, inclusive) of it. Null in the exporters: every scene (the
/// owner's choice, 2026-11-27: the scene and frames to export can be chosen).
class ExportWindow {
  const ExportWindow({
    required this.sceneId,
    required this.start,
    required this.end,
  });

  final String sceneId;
  final int start;
  final int end;

  /// Whether frame [frameIndex] (its position in the scene) of [sceneId] is
  /// exported.
  bool covers(String sceneId, int frameIndex) =>
      sceneId == this.sceneId && frameIndex >= start && frameIndex <= end;
}
