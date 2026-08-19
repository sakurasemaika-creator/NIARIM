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
  final String? partId; // 自動塗り用線画レイヤーのパーツID
  final TextObject? textObject; // テキストレイヤーのテキストオブジェクト

  // 共通レイヤー・タイムライン素材レイヤーの表示範囲（仕様書05・16）
  final LayerRangeMode rangeMode;
  final int? rangeStart; // 1始まり・ユーザー表示値
  final int? rangeEnd;
  // rangeMode == sceneRange の場合に対象となるシーンID（仕様書16：「シーン指定」）
  final String? rangeSceneId;
  final bool isExpanded; // フォルダの展開・折りたたみ状態（仕様書16）

  // タイムライン画像・動画素材レイヤーが参照する素材ID（仕様書21：MaterialID方式）。
  // タイムライン画像・動画素材レイヤー（LayerType.timelineImage/timelineVideo）
  // でのみ使用する。
  final String? materialId;
  // 動画素材の使用範囲（素材内でのトリム開始・終了フレーム、仕様書05）。
  // LayerType.timelineVideoでのみ使用する。
  final int? sourceTrimStart;
  final int? sourceTrimEnd;

  // ウォーターマークレイヤー（LayerType.watermark）が参照する登録済み
  // ウォーターマークID・角度・大きさ（仕様書08・13：配置後にタイムライン上で
  // ウォーターマークをタップして角度・大きさ・不透明度・表示範囲＝ループ表示を
  // 再編集できるようにするための、配置ごとの個別設定）。
  // 不透明度はopacity、表示範囲（ループ表示）はrangeModeを流用する。
  final String? watermarkAssetId;
  final double watermarkAngle; // 度数法、0が基準
  final double watermarkScale; // キャンバス幅に対する倍率（既定0.25）

  // タイムライン画像・動画素材レイヤーが表示される行番号（0始まり、仕様書05：
  // 「素材種別ごとに複数行のタイムライン行を追加/削除できるようにする」）。
  // LayerType.timelineImage/timelineVideoでのみ使用する。
  final int trackRow;

  // レイヤー単位の位置・拡大縮小・回転キーフレーム。カメラキーフレームが
  // 画面全体を動かすのに対し、こちらは個々のレイヤーだけを動かす
  // （自動塗りの各パーツもそれぞれ独立したレイヤーとして生成されるため、
  // パーツ単位でのアニメーションにそのまま使える）。空の場合は変形なし。
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
      watermarkAssetId: watermarkAssetId == _sentinel ? this.watermarkAssetId : watermarkAssetId as String?,
      watermarkAngle: watermarkAngle ?? this.watermarkAngle,
      watermarkScale: watermarkScale ?? this.watermarkScale,
      trackRow: trackRow ?? this.trackRow,
      keyframes: keyframes ?? this.keyframes,
    );
  }
}

/// 共通レイヤー・タイムライン素材レイヤーの表示範囲モード（仕様書16）
enum LayerRangeMode { allFrames, currentScene, sceneRange, frameRange }

const Object _sentinel = Object();

enum LayerType {
  normal,
  common,
  folder,
  autoFillLineart, // 自動塗り用線画レイヤー（ユーザー作成可）
  autoFill,        // 自動塗りレイヤー（ユーザー作成可）
  text,            // テキストレイヤー（ユーザー作成可）
  timelineImage,   // タイムライン画像素材レイヤー（タイムラインから追加。表示範囲内のフレームのみレイヤーパレットに表示）
  timelineVideo,   // タイムライン動画素材レイヤー（タイムラインから追加。表示範囲内のフレームのみレイヤーパレットに表示）
  watermark,       // ウォーターマークレイヤー（プレミアム限定。画像素材と同じタイムライン素材として扱う）
  selection,       // 内部専用：選択範囲保持レイヤー。レイヤーパネル非表示・ユーザー操作不可
}

/// 表示範囲（rangeMode/rangeStart/rangeEnd）を持ち、複数フレームにまたがって
/// 同一のピクセルデータを共有表示しうるレイヤー種別（仕様書05・16）。
bool isRangeLayerType(LayerType type) =>
    type == LayerType.common ||
    type == LayerType.timelineImage ||
    type == LayerType.timelineVideo ||
    type == LayerType.watermark;

enum LayerBlendMode {
  normal, multiply, screen, overlay, addition, subtract,
  darken, lighten, colorBurn, colorDodge, hardLight, softLight,
  difference, hue, saturation, color, luminosity,
}
