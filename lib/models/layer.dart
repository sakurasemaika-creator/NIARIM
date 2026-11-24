import 'dart:ui' show Offset;

import 'layer_keyframe.dart';
import 'layer_crop.dart';
import 'layer_mask.dart';
import 'text_object.dart';

class Layer {
  final String id;
  final String name;
  final bool localizedStarterName;
  final LayerType type;
  final int opacity;
  final LayerBlendMode blendMode;
  final bool isVisible;
  final bool isLocked;
  final bool opacityLocked;
  final bool hasClipping;
  final String? parentFolderId;
  final bool needsAutofillUpdate;
  final String? partId; // 自動塗り用線画レイヤーのパーツID
  final TextObject? textObject; // テキストレイヤーのテキストオブジェクト

  final LayerRangeMode rangeMode;
  final int? rangeStart;
  final int? rangeEnd;
  final String? rangeSceneId;
  final bool isExpanded;
  final String? materialId;
  final int? sourceTrimStart;
  final int? sourceTrimEnd;

  /// The fraction of a source frame the video starts after
  /// [sourceTrimStart] (0 ≤ f < 1). A clip split at a fractional source
  /// position (a speed other than 1×) keeps playing exactly where the
  /// unsplit clip would.
  final double sourceTrimStartFraction;

  /// The video's playback speed (1.0 = normal, 2.0 = twice as fast). Its
  /// sound plays at the same speed unless [videoSoundFollowsSpeed] is off.
  final double playbackRate;

  /// Whether the video's sound plays at [playbackRate] too (on), or at the
  /// normal speed from the clip's start while only the picture changes speed.
  final bool videoSoundFollowsSpeed;
  final double videoVolume;
  final String? watermarkAssetId;
  final double watermarkAngle;
  final double watermarkScale;
  final PlacedWatermarkSource? watermarkSource;
  final int trackRow;
  final List<LayerKeyframe> keyframes;

  /// タイムライン素材（テキスト・画像・動画）の見える範囲を限るマスク。
  final LayerMask? mask;

  /// The part of a timeline image or video that shows (null: all of it).
  /// Applied to the material's own picture before its position, scale,
  /// turn and mask.
  final LayerCrop? crop;

  const Layer({
    required this.id,
    required this.name,
    this.localizedStarterName = false,
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
    this.sourceTrimStartFraction = 0,
    this.playbackRate = 1.0,
    this.videoSoundFollowsSpeed = true,
    this.videoVolume = 1.0,
    this.watermarkAssetId,
    this.watermarkAngle = 0,
    this.watermarkScale = 0.25,
    this.watermarkSource,
    this.trackRow = 0,
    this.keyframes = const [],
    this.mask,
    this.crop,
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
    double? sourceTrimStartFraction,
    double? playbackRate,
    bool? videoSoundFollowsSpeed,
    double? videoVolume,
    Object? watermarkAssetId = _sentinel,
    double? watermarkAngle,
    double? watermarkScale,
    Object? watermarkSource = _sentinel,
    int? trackRow,
    List<LayerKeyframe>? keyframes,
    Object? mask = _sentinel,
    Object? crop = _sentinel,
  }) {
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      localizedStarterName: name == null && localizedStarterName,
      type: type ?? this.type,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacityLocked: opacityLocked ?? this.opacityLocked,
      hasClipping: hasClipping ?? this.hasClipping,
      parentFolderId: parentFolderId == _sentinel
          ? this.parentFolderId
          : parentFolderId as String?,
      needsAutofillUpdate: needsAutofillUpdate ?? this.needsAutofillUpdate,
      partId: partId == _sentinel ? this.partId : partId as String?,
      textObject: textObject ?? this.textObject,
      rangeMode: rangeMode ?? this.rangeMode,
      rangeStart: rangeStart == _sentinel
          ? this.rangeStart
          : rangeStart as int?,
      rangeEnd: rangeEnd == _sentinel ? this.rangeEnd : rangeEnd as int?,
      rangeSceneId: rangeSceneId == _sentinel
          ? this.rangeSceneId
          : rangeSceneId as String?,
      isExpanded: isExpanded ?? this.isExpanded,
      materialId: materialId == _sentinel
          ? this.materialId
          : materialId as String?,
      sourceTrimStart: sourceTrimStart == _sentinel
          ? this.sourceTrimStart
          : sourceTrimStart as int?,
      sourceTrimEnd: sourceTrimEnd == _sentinel
          ? this.sourceTrimEnd
          : sourceTrimEnd as int?,
      sourceTrimStartFraction:
          sourceTrimStartFraction ?? this.sourceTrimStartFraction,
      playbackRate: playbackRate ?? this.playbackRate,
      videoSoundFollowsSpeed:
          videoSoundFollowsSpeed ?? this.videoSoundFollowsSpeed,
      videoVolume: videoVolume ?? this.videoVolume,
      watermarkAssetId: watermarkAssetId == _sentinel
          ? this.watermarkAssetId
          : watermarkAssetId as String?,
      watermarkAngle: watermarkAngle ?? this.watermarkAngle,
      watermarkScale: watermarkScale ?? this.watermarkScale,
      watermarkSource: watermarkSource == _sentinel
          ? this.watermarkSource
          : watermarkSource as PlacedWatermarkSource?,
      trackRow: trackRow ?? this.trackRow,
      keyframes: keyframes ?? this.keyframes,
      mask: mask == _sentinel ? this.mask : mask as LayerMask?,
      crop: crop == _sentinel ? this.crop : crop as LayerCrop?,
    );
  }
}

/// The embedded raster before the first size or angle edit. The cropped PNG
/// stays independent of the preset and of the currently visible canvas pixels.
class PlacedWatermarkSource {
  const PlacedWatermarkSource({
    required this.png,
    required this.center,
    required this.angle,
    required this.scale,
  });

  final String png;
  final Offset center;
  final double angle;
  final double scale;

  Map<String, Object> toJson() => {
    'png': png,
    'x': center.dx,
    'y': center.dy,
    'angle': angle,
    'scale': scale,
  };

  static PlacedWatermarkSource? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final png = json['png'];
    final x = json['x'];
    final y = json['y'];
    final angle = json['angle'];
    final scale = json['scale'];
    if (png is! String ||
        png.isEmpty ||
        x is! num ||
        !x.isFinite ||
        y is! num ||
        !y.isFinite ||
        angle is! num ||
        !angle.isFinite ||
        scale is! num ||
        !scale.isFinite ||
        scale <= 0) {
      return null;
    }
    return PlacedWatermarkSource(
      png: png,
      center: Offset(x.toDouble(), y.toDouble()),
      angle: angle.toDouble(),
      scale: scale.toDouble(),
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

  /// タイムラインのテキスト素材（テキストの列に置く。文字はtextObjectから
  /// ラスタライズしてタイルに持つ）。
  timelineText,
}

bool isRangeLayerType(LayerType type) =>
    type == LayerType.common ||
    type == LayerType.timelineImage ||
    type == LayerType.timelineVideo ||
    type == LayerType.timelineText ||
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
