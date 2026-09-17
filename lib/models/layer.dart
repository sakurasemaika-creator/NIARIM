import 'layer_keyframe.dart';
import 'text_object.dart';

class Layer {
  final String id;
  final String name;
  final LayerType type;
  final int opacity;
  final LayerBlendMode blendMode;
  final bool isVisible;
  final bool isLocked;
  final bool opacityLocked;
  final bool hasClipping;
  final String? parentFolderId;
  final bool needsAutofillUpdate;
  final String? partId;
  final TextObject? textObject;
  final LayerRangeMode rangeMode;
  final int? rangeStart;
  final int? rangeEnd;
  final String? rangeSceneId;
  final bool isExpanded;
  final String? materialId;
  final int? sourceTrimStart;
  final int? sourceTrimEnd;
  final double videoVolume;
  final String? watermarkAssetId;
  final double watermarkAngle;
  final double watermarkScale;
  final int trackRow;
  final List<LayerKeyframe> keyframes;

  const Layer({
    required this.id,
    required this.name,
    required this.type,
    this.opacity = 100,
    this.blendMode = LayerBlendMode.normal,
    this.isVisible = true,
    this.isLocked = false,
    this.opacityLocked = false,
    this.hasClipping = false,
    this.parentFolderId,
    this.needsAutofillUpdate = false,
    this.partId,
    this.textObject,
    this.rangeMode = LayerRangeMode.allFrames,
    this.rangeStart,
    this.rangeEnd,
    this.rangeSceneId,
    this.isExpanded = true,
    this.materialId,
    this.sourceTrimStart,
    this.sourceTrimEnd,
    this.videoVolume = 1.0,
    this.watermarkAssetId,
    this.watermarkAngle = 0,
    this.watermarkScale = 0.25,
    this.trackRow = 0,
    this.keyframes = const [],
  });

  Layer copyWith({
    String? id,
    String? name,
    LayerType? type,
    int? opacity,
    LayerBlendMode? blendMode,
    bool? isVisible,
    bool? isLocked,
    bool? opacityLocked,
    bool? hasClipping,
    Object? parentFolderId = _sentinel,
    bool? needsAutofillUpdate,
    Object? partId = _sentinel,
    TextObject? textObject,
    LayerRangeMode? rangeMode,
    Object? rangeStart = _sentinel,
    Object? rangeEnd = _sentinel,
    Object? rangeSceneId = _sentinel,
    bool? isExpanded,
    Object? materialId = _sentinel,
    Object? sourceTrimStart = _sentinel,
    Object? sourceTrimEnd = _sentinel,
    double? videoVolume,
    Object? watermarkAssetId = _sentinel,
    double? watermarkAngle,
    double? watermarkScale,
    int? trackRow,
    List<LayerKeyframe>? keyframes,
  }) {
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacityLocked: opacityLocked ?? this.opacityLocked,
      hasClipping: hasClipping ?? this.hasClipping,
      parentFolderId: parentFolderId == _sentinel ? this.parentFolderId : parentFolderId as String?,
      needsAutofillUpdate: needsAutofillUpdate ?? this.needsAutofillUpdate,
      partId: partId == _sentinel ? this.partId : partId as String?,
      textObject: textObject ?? this.textObject,
      rangeMode: rangeMode ?? this.rangeMode,
      rangeStart: rangeStart == _sentinel ? this.rangeStart : rangeStart as int?,
      rangeEnd: rangeEnd == _sentinel ? this.rangeEnd : rangeEnd as int?,
      rangeSceneId: rangeSceneId == _sentinel ? this.rangeSceneId : rangeSceneId as String?,
      isExpanded: isExpanded ?? this.isExpanded,
      materialId: materialId == _sentinel ? this.materialId : materialId as String?,
      sourceTrimStart: sourceTrimStart == _sentinel ? this.sourceTrimStart : sourceTrimStart as int?,
      sourceTrimEnd: sourceTrimEnd == _sentinel ? this.sourceTrimEnd : sourceTrimEnd as int?,
      videoVolume: videoVolume ?? this.videoVolume,
      watermarkAssetId: watermarkAssetId == _sentinel ? this.watermarkAssetId : watermarkAssetId as String?,
      watermarkAngle: watermarkAngle ?? this.watermarkAngle,
      watermarkScale: watermarkScale ?? this.watermarkScale,
      trackRow: trackRow ?? this.trackRow,
      keyframes: keyframes ?? this.keyframes,
    );
  }
}

enum LayerRangeMode { allFrames, currentScene, sceneRange, frameRange }

const Object _sentinel = Object();

enum LayerType {
  normal,
  common,
  folder,
  autoFillLineart,
  autoFill,
  text,
  timelineImage,
  timelineVideo,
  watermark,
  selection,
}

bool isRangeLayerType(LayerType type) =>
    type == LayerType.common ||
    type == LayerType.timelineImage ||
    type == LayerType.timelineVideo ||
    type == LayerType.watermark;

({int start, int end})? trimCommonLayerRange({
  required int start,
  required int end,
  required int frameIndex,
  bool? keepBefore,
}) {
  if (start >= end) return null;
  if (frameIndex <= start) return (start: start + 1, end: end);
  if (frameIndex >= end) return (start: start, end: end - 1);
  if (keepBefore == true) return (start: start, end: frameIndex - 1);
  if (keepBefore == false) return (start: frameIndex + 1, end: end);
  return null;
}

enum LayerBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  addition,
  subtract,
  darken,
  lighten,
  colorBurn,
  colorDodge,
  hardLight,
  softLight,
  difference,
  hue,
  saturation,
  color,
  luminosity,
  linearBurn,
  linearDodge,
  vividLight,
  linearLight,
  pinLight,
  hardMix,
  exclusion,
  divide,
}
