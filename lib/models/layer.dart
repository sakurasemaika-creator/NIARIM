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

  // 共通レイヤー・タイムライン素材レイヤーの表示範囲
  final LayerRangeMode rangeMode;
  final int? rangeStart; // 1始まり・ユーザー表示値
  final int? rangeEnd;
  // rangeMode == sceneRange の場合に対象となるシーンID（「シーン指定」）
  final String? rangeSceneId;
  final bool isExpanded; // フォルダの展開・折りたたみ状態

  // タイムライン画像・動画素材レイヤーが参照する素材ID。
  // タイムライン画像・動画素材レイヤー（LayerType.timelineImage/timelineVideo）
  // でのみ使用する。
  final String? materialId;
  // 動画素材の使用範囲（素材内でのトリム開始・終了フレーム）。
  // LayerType.timelineVideoでのみ使用する。
  final int? sourceTrimStart;
  final int? sourceTrimEnd;
  // 動画素材の音量（0.0〜1.0）。不透明度とは独立して保持する。
  // LayerType.timelineVideoでのみ使用する。
  final double videoVolume;

  // ウォーターマークレイヤー（LayerType.watermark）が参照する登録済み
  // ウォーターマークID・角度・大きさ（配置後にタイムライン上でウォーター
  // マークをタップして角度・大きさ・不透明度・表示範囲＝ループ表示を
  // 再編集できるようにするための、配置ごとの個別設定）。
  // 不透明度はopacity、表示範囲（ループ表示）はrangeModeを流用する。
  final String? watermarkAssetId;
  final double watermarkAngle; // 度数法、0が基準
  final double watermarkScale; // キャンバス幅に対する倍率（既定0.25）

  // タイムライン画像・動画素材レイヤーが表示される行番号（0始まり）。
  // 素材種別ごとに複数行のタイムライン行を追加/削除できる。
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
      videoVolume: videoVolume ?? this.videoVolume,
      watermarkAssetId: watermarkAssetId == _sentinel
          ? this.watermarkAssetId
          : watermarkAssetId as String?,
      watermarkAngle: watermarkAngle ?? this.watermarkAngle,
      watermarkScale: watermarkScale ?? this.watermarkScale,
      trackRow: trackRow ?? this.trackRow,
      keyframes: keyframes ?? this.keyframes,
    );
  }
}

/// 共通レイヤー・タイムライン素材レイヤーの表示範囲モード
enum LayerRangeMode { allFrames, currentScene, sceneRange, frameRange }

const Object _sentinel = Object();

enum LayerType {
  normal,
  common,
  folder,
  autoFillLineart, // 自動塗り用線画レイヤー（ユーザー作成可）
  autoFill, // 自動塗りレイヤー（ユーザー作成可）
  text, // テキストレイヤー（ユーザー作成可）
  timelineImage, // タイムライン画像素材レイヤー（タイムラインから追加。表示範囲内のフレームのみレイヤーパレットに表示）
  timelineVideo, // タイムライン動画素材レイヤー（タイムラインから追加。表示範囲内のフレームのみレイヤーパレットに表示）
  watermark, // ウォーターマークレイヤー（プレミアム限定。画像素材と同じタイムライン素材として扱う）
  selection, // 選択レイヤー（マスク専用、ユーザー作成可）。眼鏡断層フィルター等、
  // 範囲指定フィルターの対象範囲を通常の描画ツールで塗って指定する用途。
  // pixelLayerTypes（layer_compositor.dart）からは除外されるため
  // 通常の合成結果・書き出しには写り込まないが、テーマの選択色による
  // 半透明タイントでキャンバス上に常時オーバーレイ表示される
  // （canvas_area.dartの_selectionLayerOverlayImage）。
}

/// 表示範囲（rangeMode/rangeStart/rangeEnd）を持ち、複数フレームにまたがって
/// 同一のピクセルデータを共有表示しうるレイヤー種別。
bool isRangeLayerType(LayerType type) =>
    type == LayerType.common ||
    type == LayerType.timelineImage ||
    type == LayerType.timelineVideo ||
    type == LayerType.watermark;

/// タスク#148：共通レイヤーの「このフレームだけ削除」で使う、
/// 表示範囲（0始まりのstart/end）からframeIndexを含む1フレーム分を
/// 除いた後の新しい範囲を計算する純粋関数（layer_panel.dartのUI操作から
/// 分離してユニットテストできるようにしている）。
///
/// - 範囲が1フレームのみの場合はnullを返す（=レイヤー自体を削除すべき）。
/// - frameIndexが範囲の先頭・末尾なら、その1フレーム分だけ縮めた範囲を
///   一意に返す。
/// - frameIndexが範囲の途中の場合、連続区間を保てないため[keepBefore]で
///   どちらを残すか指定する必要がある（nullのまま呼ぶとnullを返す＝
///   呼び出し側でユーザーに選ばせる必要があることを示す）。
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
}
