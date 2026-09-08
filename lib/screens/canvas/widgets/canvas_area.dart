import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../engine/bucket_fill_engine.dart';
import '../../../engine/drawing_engine.dart';
import '../../../engine/filter_engine.dart' show FilterEngine, quantizeColors;
import '../../../engine/input_handler.dart';
import '../../../engine/lasso_fill_engine.dart';
import '../../../engine/layer_compositor.dart';
import '../../../engine/layer_keyframe_engine.dart';
import '../../../engine/mesh_warp_engine.dart';
import '../../../engine/multi_touch_tap_tracker.dart';
import '../../../engine/onion_skin.dart';
import '../../../engine/procedural_texture.dart';
import '../../../engine/ruler_engine.dart';
import '../../../engine/stamp_engine.dart';
import '../../../engine/tile_manager.dart';
import '../../../engine/tone_engine.dart';
import '../../../engine/undo_manager.dart' as app_undo;
import '../../../models/layer.dart';
import '../../../models/layer_keyframe.dart';
import '../../../models/onion_skin_settings.dart';
import '../../../models/pixel_color_mode.dart';
import '../../../models/project.dart';
import '../../../models/ruler.dart';
import '../../../services/brush_service.dart';
import '../../../services/performance_service.dart';
import '../../../services/project_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/stamp_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/tone_service.dart';
import '../canvas_screen.dart';
import 'pen_sub_tool_panel.dart' show PenSubTool;

/// 選択範囲の変形の内部モード（移動・拡大縮小・回転）。
/// 外部（キャンバス左下のモード切替ボタン）からは[SelectionTransformMode]で
/// 指定され、[_modeOf]でこの内部表現へ変換される。
enum _TransformMode { translate, scale, rotate }

/// キャンバスウィジェット上で、実際にプロジェクトの内容
/// （書き出しサイズ＝プロジェクトのピクセル座標系）が描画される矩形を計算する。
///
/// ウィジェットの実サイズ（[size]）とプロジェクトの書き出しアスペクト比が
/// 一致しない場合は中央揃えでレターボックス表示になる（拡張表示範囲が
/// OFFの場合）。この矩形は`_CanvasPainter.paint()`での実際の描画と、
/// `_CanvasAreaState`側でのポインター座標→プロジェクトピクセル座標への
/// 変換の両方から参照される、単一の計算元（ロジックの二重化・乖離を防ぐ）。
/// キャンバス描画エリアの「枠外」を塗る色（プロジェクトの描画内容の
/// 外側・レターボックス部分）。_CanvasPainterの背景塗りと、
/// canvas_screen.dart側でCanvasAreaの背後に敷く固定背景の両方で使う
/// （ピンチズームでキャンバス内容ごと縮小した際、背後にテーマの
/// 明るい背景色が透けて見えてしまう不具合の修正のため、両者を同じ色に
/// 揃える必要がある）。
Color get kCanvasOutsideColor =>
    ThemeService.activeColorScheme.surfaceContainerHighest;

/// キャンバス表示の縮小下限。等倍表示時の1/5まで縮小できる。
const double kCanvasMinScale = 0.2;

/// キャンバス表示の拡大上限。
const double kCanvasMaxScale = 10.0;

/// A one-project-pixel grid is useful only when a pixel is large enough to be
/// visually distinguishable on screen. Below this threshold the lines would
/// alias into a moire pattern and cost thousands of draw calls without helping
/// pixel placement.
bool shouldPaintPixelGrid(double pixelScreenSize) => pixelScreenSize >= 3.0;

/// 現在倍率へ要求倍率を掛けた結果を表示可能範囲へ正確にクランプする。
/// 境界到達時に操作全体を破棄しないため、最小倍率でも回転は継続できる。
double boundedCanvasScaleFactor(double currentScale, double requestedFactor) {
  if (currentScale <= 0 ||
      !currentScale.isFinite ||
      !requestedFactor.isFinite) {
    return 1.0;
  }
  final target = (currentScale * requestedFactor).clamp(
    kCanvasMinScale,
    kCanvasMaxScale,
  );
  return target / currentScale;
}

/// キャンバスの表示変換を背景（＝CanvasAreaの表示領域）内へ拘束する。
///
/// 回転後の[drawingRect]の外接矩形を使い、縮小時はキャンバス全体が背景内から
/// はみ出さないようにする。拡大時は逆に、片側へ動かしすぎて反対側から背景の
/// 外へ抜けられないようにする。これにより背景の端より先へドラッグできない。
Matrix4 constrainCanvasViewTransform(
  Size viewportSize,
  Rect drawingRect,
  Matrix4 candidate,
) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) return candidate;
  final viewport = Offset.zero & viewportSize;
  final bounds = MatrixUtils.transformRect(candidate, drawingRect);

  double correction(double min, double max, double viewMin, double viewMax) {
    final extent = max - min;
    final viewExtent = viewMax - viewMin;
    if (extent <= viewExtent) {
      if (min < viewMin) return viewMin - min;
      if (max > viewMax) return viewMax - max;
      return 0;
    }
    if (min > viewMin) return viewMin - min;
    if (max < viewMax) return viewMax - max;
    return 0;
  }

  final dx = correction(
    bounds.left,
    bounds.right,
    viewport.left,
    viewport.right,
  );
  final dy = correction(
    bounds.top,
    bounds.bottom,
    viewport.top,
    viewport.bottom,
  );
  if (dx == 0 && dy == 0) return candidate;
  return (Matrix4.identity()..translateByDouble(dx, dy, 0, 1)) * candidate;
}

/// 選択範囲のハンドルの見た目の大きさ（**画面px**での半径）。
///
/// キャンバスの解像度ではなく画面に対して固定にする。キャンバス基準にすると、
/// 高解像度のプロジェクトではハンドルが極端に小さく、低解像度では巨大に
/// 見えてしまう（指の大きさは画面基準なので、掴みやすさも画面基準が正しい）。
const double kSelectionHandleScreenRadius = 7.0;

/// 回転ハンドルだけは他より大きくする（画面pxでの半径）。
/// 四隅の拡大縮小ハンドルと役割が違うことが一目で分かるようにするのと、
/// 角から離して置くぶん指が届きやすいようにするため。
const double kSelectionRotateHandleScreenRadius = 11.0;

/// 回転ハンドルを右上の角からどれだけ離すか（拡大縮小ハンドルの半径の倍数）。
/// 近すぎると角のハンドルと取り違えるので、しっかり離す。
const double kSelectionRotateHandleGap = 4.5;

/// [kSelectionHandleScreenRadius]をキャンバスpxへ換算する。
/// [canvasToScreenScale]はキャンバス1pxが画面何pxにあたるかの比率。
///
/// **位置の計算にも当たり判定にも、必ずこの同じ値を使うこと。** 片方だけ
/// 別の値にすると、回転ハンドルと四隅の拡大縮小ハンドルが当たり判定上
/// 重なり、角を掴んだのに回転してしまう。
double selectionHandleRadiusFor(double canvasToScreenScale) =>
    canvasToScreenScale > 0
    ? kSelectionHandleScreenRadius / canvasToScreenScale
    : kSelectionHandleScreenRadius;

/// 回転ハンドルの半径（キャンバスpx）。
double selectionRotateHandleRadiusFor(double canvasToScreenScale) =>
    canvasToScreenScale > 0
    ? kSelectionRotateHandleScreenRadius / canvasToScreenScale
    : kSelectionRotateHandleScreenRadius;

/// 拡大縮小用のハンドル位置（選択範囲の四隅）。
List<Offset> selectionScaleHandlesOf(Rect bounds) => [
  bounds.topLeft,
  bounds.topRight,
  bounds.bottomLeft,
  bounds.bottomRight,
];

/// 回転用のハンドル位置（選択範囲の右上の**外側**）。
///
/// 全選択のように選択範囲がキャンバス端まで届いている場合でも、必ず選択範囲の
/// 外へ置く（キャンバスの外＝レターボックス側へはみ出してよい）。ただし横方向
/// だけは、はみ出しすぎるとウィジェットの外になって指が届かなくなるため、
/// キャンバス幅の内側へ寄せる。上方向のオフセットは常に残るので、横に寄せても
/// 「選択範囲の外側」であることは変わらない。
Offset selectionRotateHandleOf(
  Rect bounds,
  double handleRadius, {
  double? rotateRadius,
  Rect? reachable,
}) {
  final gap = handleRadius * kSelectionRotateHandleGap;
  // 位置を寄せる際に確保する余白は、四隅のハンドルではなく**回転ハンドル
  // 自身**の半径で測る。四隅ぶん（より小さい）で測ると、寄せきったときに
  // 回転ハンドルの円が差分ぶんだけウィジェットの外へはみ出して欠ける。
  final margin = rotateRadius ?? handleRadius;
  var x = bounds.right + gap;
  var y = bounds.top - gap;
  if (reachable != null) {
    // キャンバスの外へはみ出すのは構わないが、CanvasAreaウィジェットの外へ
    // 出るとポインターイベントが届かず掴めなくなる。はみ出すぶんだけ内側へ
    // 寄せる。アスペクト比フィットの都合で描画エリアの外側に余白が付くのは
    // 縦横どちらか一方だけなので、通常寄せるのも一方だけで済む。
    x = math.min(x, reachable.right - margin);
    y = math.max(y, reachable.top + margin);
    // 縦横とも選択範囲へ食い込んだ場合（キャンバスとウィジェットの縦横比が
    // ぴったり一致していて余白がまったく無いとき）は、縦方向へ出す。
    // 四隅の拡大縮小ハンドルと重なると「角を掴んだのに回転する」状態に
    // なるため、こうなったときだけは掴めなくなるより外へ出す方を選ぶ。
    if (x < bounds.right + margin && y > bounds.top - margin) {
      y = bounds.top - margin;
    }
  }
  return Offset(x, y);
}

/// いま画面に映っている範囲を、ズーム・パン適用前のウィジェット座標へ
/// 戻した矩形。ピンチで縮小していればウィジェットの外側まで広がり、
/// 拡大していれば内側の一部だけになる。
Rect visibleWidgetRectFor(Size size, Matrix4 viewTransform) {
  final inverted = Matrix4.copy(viewTransform);
  if (inverted.invert() == 0) return Offset.zero & size;
  return MatrixUtils.transformRect(inverted, Offset.zero & size);
}

/// 指が届く範囲を、キャンバスpxへ直した矩形。
///
/// アスペクト比フィットで置かれる描画エリア（[canvasDrawingRectFor]）の
/// 外側にはレターボックス／ピラーボックスの余白があり、そこもウィジェットの
/// 内側なのでタップは届く。回転ハンドルを「キャンバスの外だがウィジェットの
/// 内」へ置けるようにするための計算。
///
/// [visibleWidgetRect]には[visibleWidgetRectFor]の結果（＝ピンチズーム・
/// パンを織り込んだ、いま映っている範囲）を渡すこと。ウィジェットの矩形を
/// そのまま渡すと、ピンチで縮小して余白が生まれても寄せたままになる。
Rect reachableCanvasRectFor(
  Rect visibleWidgetRect,
  Rect drawingRect,
  Project? project,
) {
  final canvasPx = canvasPixelSizeOf(project);
  if (drawingRect.width <= 0 || drawingRect.height <= 0) {
    return Offset.zero & canvasPx;
  }
  final sx = canvasPx.width / drawingRect.width;
  final sy = canvasPx.height / drawingRect.height;
  return Rect.fromLTRB(
    (visibleWidgetRect.left - drawingRect.left) * sx,
    (visibleWidgetRect.top - drawingRect.top) * sy,
    (visibleWidgetRect.right - drawingRect.left) * sx,
    (visibleWidgetRect.bottom - drawingRect.top) * sy,
  );
}

/// キャンバスのピクセル寸法。**書き出しサイズではなく描画範囲サイズ**
/// （＝書き出しサイズ×drawingAreaScale）で、TileManagerの実寸・選択マスクの
/// 寸法・ポインター座標系のすべてがこれで揃っている。
///
/// 「キャンバス外にも描画範囲を広げる」モード（drawingAreaScale > 1.0）では
/// この2つが食い違う。書き出しサイズの方を使うと、タップ位置と実際に描かれる
/// 位置がdrawingAreaScale倍ずれる（実際にそうなっていた）。
Size canvasPixelSizeOf(Project? project) => Size(
  (project?.drawingWidth ?? 1920).toDouble(),
  (project?.drawingHeight ?? 1080).toDouble(),
);

/// 描画範囲（[canvasPixelSizeOf]）をウィジェットへアスペクト比フィットさせた
/// 矩形。ポインター座標の変換もハンドルの描画位置もすべてこれを基準にする。
///
/// 拡張描画範囲ONでも同じ扱いにすること。以前はONのときだけウィジェット全体を
/// 返していたが、（1）描画範囲の縦横比とウィジェットの縦横比が違うと画が
/// 引き伸ばされ、（2）座標変換が書き出しサイズ基準のままだったため
/// タップ位置がdrawingAreaScale倍ずれていた。
Rect canvasDrawingRectFor(Size size, Project? project) {
  final canvas = canvasPixelSizeOf(project);
  if (canvas.width <= 0 || canvas.height <= 0) {
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }
  final aspectRatio = canvas.width / canvas.height;
  final double w, h;
  if (size.width / size.height > aspectRatio) {
    h = size.height;
    w = h * aspectRatio;
  } else {
    w = size.width;
    h = w / aspectRatio;
  }
  return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
}

/// 拡張描画範囲ONのとき、実際に書き出される範囲（描画範囲の中央
/// 1/drawingAreaScale）を[drawingRect]の中の矩形として返す。OFFなら
/// [drawingRect]そのもの。
Rect exportWarningRectFor(Rect drawingRect, Project? project) {
  final scale = project?.drawingAreaScale ?? 1.0;
  if (scale <= 1.0) return drawingRect;
  final w = drawingRect.width / scale;
  final h = drawingRect.height / scale;
  return Rect.fromCenter(center: drawingRect.center, width: w, height: h);
}

class CanvasArea extends StatefulWidget {
  final ValueChanged<Offset>? onTapForText;
  final ValueChanged<Color>? onEyedropper;
  final bool filterEyedropperActive;
  final Project? project;
  final CanvasBackground background;
  final String? currentLayerId;
  final bool isEraser;
  final DrawingTool currentTool;
  final PenSubTool currentSubTool;
  final bool lassoFillEnclosedMode;
  final OnionSkinSettings onionSkinSettings;
  final int currentFrame;
  final String sceneId;
  final Ruler? activeRuler;
  // 定規のハンドルドラッグ（移動・回転・サイズ変更・消失点移動）による更新通知
  // ライブ更新・Undo確定の両方でこのコールバックを呼ぶ。
  final ValueChanged<Ruler?>? onRulerChanged;
  final ShapeKind shapeKind;
  // ジェスチャー／ペンボタンによるツール切替の通知先。
  // onGestureToolChange：直接切り替え（スポイト等、押し続けの必要がないもの）
  // onGestureToggleTool：現在のツールとトグル切替（消しゴム切替・ブラシ切替・手のひらツール）
  final ValueChanged<DrawingTool>? onGestureToolChange;
  final ValueChanged<DrawingTool>? onGestureToggleTool;
  final VoidCallback? onNextQuickTool;
  // オニオンスキンON/OFF切替（ジェスチャーに割り当て可能）
  final VoidCallback? onToggleOnionSkin;

  // ─── レイヤー全体の自由変形・メッシュ変形（新機能） ────────────────────
  // 実際の格子点ドラッグ操作はポインター処理を持つこのWidget内で完結させ、
  // 分割数変更・回転・拡大縮小・確定・キャンセルは編集メニューから開く
  // コントロールパネル（canvas_screen.dart側）から、値の変化・トークンの
  // 増加という一方向のプロパティ変化として伝える（RulerPanelと同じく
  // 「操作の主導権は上位Widget、実処理はCanvasArea」という構成だが、
  // 確定処理がTileManagerへの非同期書き込みを伴うためコールバックではなく
  // プロパティ監視（didUpdateWidget）で駆動する）。
  final int meshDensity;
  final double meshRotateDeg;
  final double meshScaleValue;
  final int meshCommitToken;
  final int meshCancelToken;

  // ─── 画面端ダブルタップでのフレーム送り（フレーム一覧の開閉
  // 状態と無関係に常時使える操作） ────────────────────────
  final VoidCallback? onNextFrame;
  final VoidCallback? onPreviousFrame;

  // ─── 選択範囲の反転（canvas_screen.dart側の上部バーに「選択範囲を
  // 反転」ボタンを表示するため、選択中かどうかをこのコールバックで
  // 通知する。反転自体はmeshCommitToken等と同じトークン方式で駆動する
  // （主導権はcanvas_screen.dart側、実処理はCanvasArea側）。 ───────────
  final int invertSelectionToken;
  final int selectAllSelectionToken;
  final int clearSelectionToken;
  final ValueChanged<bool>? onSelectionActiveChanged;

  /// 画面下部のスライダーで指定する、選択範囲の変形量。
  ///
  /// いずれも「いまの状態を0」とした**相対量**で、スライダーを離した時点で
  /// 実画素へ確定し、canvas_screen.dart側が0へ戻す。
  /// [selectionScale]だけは倍率なので1.0が等倍（＝変化なし）。
  final double selectionMoveX;
  final double selectionMoveY;
  final double selectionScale;
  final double selectionRotateDeg;

  /// スライダーから指を離したときに増える。増えたら実画素へ確定する。
  final int selectionTransformCommitToken;

  const CanvasArea({
    super.key,
    this.onTapForText,
    this.onEyedropper,
    this.filterEyedropperActive = false,
    this.project,
    this.background = CanvasBackground.white,
    this.currentLayerId,
    this.isEraser = false,
    this.currentTool = DrawingTool.pen,
    this.currentSubTool = PenSubTool.brush,
    this.lassoFillEnclosedMode = false,
    this.onionSkinSettings = const OnionSkinSettings(),
    this.currentFrame = 0,
    this.sceneId = '',
    this.activeRuler,
    this.onRulerChanged,
    this.shapeKind = ShapeKind.off,
    this.onGestureToolChange,
    this.onGestureToggleTool,
    this.onNextQuickTool,
    this.onToggleOnionSkin,
    this.meshDensity = 1,
    this.meshRotateDeg = 0.0,
    this.meshScaleValue = 1.0,
    this.meshCommitToken = 0,
    this.meshCancelToken = 0,
    this.onNextFrame,
    this.onPreviousFrame,
    this.invertSelectionToken = 0,
    this.selectAllSelectionToken = 0,
    this.clearSelectionToken = 0,
    this.onSelectionActiveChanged,
    this.selectionMoveX = 0,
    this.selectionMoveY = 0,
    this.selectionScale = 1,
    this.selectionRotateDeg = 0,
    this.selectionTransformCommitToken = 0,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  final TransformationController _transformController =
      TransformationController();
  final InputHandler _inputHandler = InputHandler();
  final OnionSkinEngine _onionSkinEngine = OnionSkinEngine();
  final RulerEngine _rulerEngine = RulerEngine();
  final LayerKeyframeEngine _layerKeyframeEngine = LayerKeyframeEngine();

  // 中クリックドラッグでの平行移動（Galaxy DeXモード・マウス入力）。
  // 現在のツールに関係なく、中クリックドラッグ中は常にキャンバスを平行移動する。
  bool _middleClickPanning = false;
  Offset? _middleClickLastScreenPos;
  // トーン・スタンプ・投げ縄塗りの本処理はisolate側で都度インスタンス化するため
  // （runToneStrokeInIsolate等を参照）、ここではエンジンインスタンスを保持しない。

  // ─── キャンバスの平行移動・拡大縮小・回転 ────────────────
  // Flutter標準のInteractiveViewerは回転ジェスチャーに非対応のため、独自の
  // ポインタートラッキングでパン・ピンチズーム・2本指回転を実装する（既知の
  // バグ「二本指回転未対応・ピンチアウトでのキャンバスサイズ超縮小」の修正）。
  // タッチ中のポインターID→現在位置（2本指以上での変形操作の計算に使う）。
  final Map<int, Offset> _activeTouchPositions = {};
  // 一度2本指以上になったら、その後1本に減っても全ての指が離れるまでは
  // 描画ツールへイベントを渡さない（指を離した瞬間に残りの1本で不意に
  // 描画が始まってしまう事故を防ぐ）。
  bool _touchTransformActive = false;
  // 実際に描画ツール側（_onPointerDown等）へ処理を委譲したポインターの集合。
  // 対応するonPointerUpも同じポインターのみ委譲する（変形操作用に握り
  // つぶしたポインターのUpをツール側の「描画終了」として誤処理しない）。
  final Set<int> _toolHandledPointers = {};
  final MultiTouchTapTracker _multiTouchTapTracker = MultiTouchTapTracker();

  // ─── 長押しスポイト（設定画面でON/OFF・保持秒数を設定可能、既定ON） ─────
  // ペン（トーン/スタンプサブツールを除く）・消しゴムで描画中、指を動かさず
  // 一定時間押し続けると、その場でスポイトのように色を拾って現在色へ反映
  // する。誤操作防止のため、指定px以上動く・複数指になる・ツールを切り替える
  // と保留は解除される。保持が成立した時点で、それまでに描かれていた分の
  // ストロークはUndo履歴に残さず直前の状態へ巻き戻す（TileManagerの
  // Undo記録機構をそのまま利用：_beginTileUndo()で取得済みの「変更前」
  // タイルへ書き戻すだけで済むため、ストロークが未確定のまま消える）。
  static const double _holdEyedropperMoveSlop = 8.0;
  Timer? _holdEyedropperTimer;
  int? _holdEyedropperPointerId;
  Offset? _holdEyedropperDownScreenPos;
  Offset? _holdEyedropperLastCanvasPos;
  // 手のひらツールでの1本指（スタイラス・マウスも含む）ドラッグ平行移動。
  Offset? _panToolLastScreenPos;

  // ─── 画面端ダブルタップでのフレーム送り（フレーム一覧の開閉
  // 状態と無関係に常時使える操作） ────────────────────────
  // 画面の左右端の狭い帯（_edgeDoubleTapZoneWidth）は「キャンバス外」の
  // ジェスチャー専用ゾーンとして扱い、通常の描画ツールへは一切渡さない
  // （渡してしまうと、素早い2回タップの1回目で微小な点が描画されてしまう
  // 事故を防げないため）。一定時間内に同じ側へ2回タップされたら前後の
  // フレームへ移動する。ゾーン自体を狭くしてあるため、キャンバスが画面
  // 全体を占める場合でも実際の作画への影響は最小限に留めている。
  static const double _edgeDoubleTapZoneWidth = 32.0;
  static const Duration _edgeDoubleTapWindow = Duration(milliseconds: 350);
  DateTime? _lastEdgeTapTime;
  bool? _lastEdgeTapWasRight;

  /// 2本指以上は明示的なキャンバスジェスチャーとして扱う。
  /// パームリジェクションはスタイラス使用中の単指タッチ描画だけを抑止し、
  /// 2本指パン・ピンチ・回転までは無効化しない。
  bool get _canTouchTransform =>
      // メッシュ変形ツール中は、2本指以上でもキャンバス自体のパン・ズーム・
      // 回転へ渡さず、各指を個別に別々の格子点操作へ渡す。
      widget.currentTool != DrawingTool.meshTransform;

  late TileManager _tileManager;
  late DrawingEngine _drawingEngine;

  ui.Image? _compositeImage;
  ui.Image? _belowImage;
  ui.Image? _aboveImage;
  final Map<int, ui.Image> _onionImages = {};

  /// [_onionImages]をCustomPaintへ渡すための不変ビュー。**中身が変わった
  /// ときだけ**作り直す。
  ///
  /// 以前はbuild()の中で毎回`Map.unmodifiable(_onionImages)`を呼んでいた。
  /// これは毎回新しいオブジェクトを返すため、`_CanvasPainter.shouldRepaint`
  /// の`old.onionImages != onionImages`が常に真になり、他の30項目を
  /// どれだけ丁寧に比較していても**必ず再描画される**状態になっていた
  /// （＝shouldRepaintが実質無効）。ストロークの1点ごとにキャンバス全体が
  /// 描き直されるため、影響が大きい。同一インスタンスを渡すことで、
  /// オニオンスキンが変わっていないときは正しく再描画を省ける。
  Map<int, ui.Image> _onionImagesView = const {};
  bool _isCompositing = false;
  bool _isComposingSurroundings = false;

  // 現在フレームのレイヤー一覧（レイヤーパネル順・先頭が最前面）。
  // ProjectServiceの変更を検知して合成し直すために保持する。
  List<Layer> _layers = const [];

  // ─── 選択レイヤー（LayerType.selection、眼鏡断層フィルター等のマスク
  // 専用レイヤー）のオンスクリーン表示 ────────────────────────────────
  // pixelLayerTypesから除外されているため通常の合成（_belowImage/
  // _compositeImage/_aboveImage）には現れない。塗っている最中も内容が
  // 見えるよう、このレイヤー単体だけを別途合成して保持し、_CanvasPainterで
  // テーマの選択色によるタイント付きオーバーレイとして最前面付近へ描く。
  ui.Image? _selectionLayerOverlayImage;
  bool _isRefreshingSelectionLayerOverlay = false;

  Offset? _selectionStart;
  Offset? _selectionEnd;
  List<Offset> _lassoPoints = [];
  int _touchCount = 0;

  // ─── 選択範囲（矩形選択・投げ縄選択・自動選択で共通利用） ──
  // ドラッグ中は_selectionStart/_selectionEnd・_lassoPointsでプレビューのみ
  // 表示し、確定時に1px=1byteのマスクへ変換して保持する。投げ縄塗り・バケツ
  // 塗りはこのマスクを参照して選択範囲内のみ描画する。
  Uint8List? _selectionMask;
  ui.Image? _selectionOverlayImage;

  // ─── ペンサブツール：トーン自由描画・スタンプ ─────────────────────────
  // ライブ中は軌跡のプレビューのみ表示し、指を離した時点で一括してタイルへ
  // 書き戻す（毎ポインタ移動でキャンバス全体を読み書きすると低スペック端末で
  // 重くなるため）。
  List<Offset> _subToolStrokePoints = [];

  bool _engineInitialized = false;

  // ─── 図形ツール（線・四角形・円） ─────────────────────────────────────
  Offset? _shapeStart;
  Offset? _shapeEnd;

  // ─── 移動ツール ───────────────────────────────────────────────────────
  Offset? _moveStart;
  Offset _moveDelta = Offset.zero;

  // ─── レイヤー全体の自由変形・メッシュ変形（新機能） ────────────────────
  // 格子点は行優先（(rows+1)*(cols+1)点）でキャンバスピクセル座標系。
  // rows=cols=1（4隅のみ）なら「自由変形」、増やすと「メッシュ変形」になる
  // （同じ仕組みの分割数違い）。ペン等と違い、範囲選択なしでレイヤー全体を
  // 対象にする。
  int meshRows = 1;
  int meshCols = 1;
  List<Offset>? meshControlPoints;
  // 変形対象レイヤーの、ツールを開いた時点での合成画像（ワープのソース）。
  ui.Image? meshSourceImage;
  // ポインターID→ドラッグ中の格子点インデックス（複数指で別々の点を同時に
  // つまんで動かせる。2本の角を掴んで引っ張れば、そのまま「2本指での
  // 回転・拡大縮小」相当の操作になる）。
  final Map<int, int> _meshPointerToIndex = {};
  static const double _meshHandleHitRadius = 28.0;
  // 確定処理（TileManagerへの非同期書き込み）が進行中はキャンセル処理を
  // 無効化する（進行中にmeshSourceImageをdisposeしてしまうと、非同期処理が
  // まだ参照しているui.Imageが破棄され例外になるため）。
  bool _meshCommitInFlight = false;

  // ─── 選択ツールの移動・回転・拡大縮小 ─────────────────
  bool _selectionTransformActive = false;
  _TransformMode _selectionTransformMode = _TransformMode.translate;
  Offset? _selectionTransformStart;
  Offset? _selectionTransformCenter;
  Rect? _selectionTransformBounds;
  Matrix4? _selectionTransformLive;
  ui.Image? _floatingSelectionImage;

  bool get _isSelectionTool =>
      widget.currentTool == DrawingTool.selectRect ||
      widget.currentTool == DrawingTool.selectLasso ||
      widget.currentTool == DrawingTool.selectMagicWand;

  // ─── バケツ連続塗り ───────────────────────────────────────────────────
  Uint8List? _bucketRefBuffer;
  Uint8List? _bucketVisitedMask;

  // ─── 指ツール（歪み） ───────────────────────────────────────
  // ストローク中はこのバッファを読み書きの起点にする（ストローク終了時に
  // 破棄）。指でなぞった方向へピクセルを押し流すLiquify系の「押す」効果。
  Uint8List? _warpBuffer;
  Offset? _warpLastPos;

  @override
  void initState() {
    super.initState();
    // かつてはここで addListener(() => setState(() {})) として、変換が
    // 変わるたびにCanvasArea全体（build()は150行超で、ジェスチャー用の
    // Listener・各種クロージャを含む）を作り直していた。パン・ピンチズーム・
    // 回転は指を動かしている間ずっと発火するため、これが最も頻度の高い
    // 無駄になっていた。実際に変換値へ依存しているのはbuild()内のTransform
    // 以下だけなので、そこをAnimatedBuilderで囲って必要な範囲だけを
    // 描き直すようにしてある（下のbuild()参照）。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_engineInitialized) {
      _initEngine();
      _engineInitialized = true;
    }
  }

  void _initEngine() {
    final project = widget.project;
    if (project != null) {
      _tileManager = context.read<ProjectService>().tileManagerOf(project.id);
    } else {
      _tileManager = TileManager(canvasWidth: 1920, canvasHeight: 1080);
    }
    _drawingEngine = DrawingEngine(tileManager: _tileManager)
      ..pointConstraint = _rulerEngine.snapToRuler;
    // 初回マウント時点ですでに定規が選択されている場合も、didUpdateWidget待ちに
    // せずRulerEngineへ同期する。プロジェクト再表示・Widget再生成直後の最初の
    // ストロークだけ定規が効かない状態を防ぐ。
    _rulerEngine.setActiveRuler(widget.activeRuler);
    _scheduleComposite();
    _recomposeSurroundings(force: true);
  }

  @override
  void didUpdateWidget(CanvasArea old) {
    super.didUpdateWidget(old);
    if (old.project?.id != widget.project?.id) {
      _compositeImage?.dispose();
      _compositeImage = null;
      _belowImage?.dispose();
      _belowImage = null;
      _aboveImage?.dispose();
      _aboveImage = null;
      _layers = const [];
      _initEngine();
    }
    _drawingEngine.isEraser = widget.isEraser;
    if (old.activeRuler != widget.activeRuler) {
      _rulerEngine.setActiveRuler(widget.activeRuler);
    }
    if (old.onionSkinSettings != widget.onionSkinSettings ||
        old.currentFrame != widget.currentFrame) {
      _buildOnionImages();
    }
    // フレーム・シーン・現在レイヤーが変わった場合は現在レイヤー画像も
    // 合成し直す（他のレイヤー変更検知は_recomposeSurroundings内で行う）。
    final frameChanged =
        old.currentFrame != widget.currentFrame ||
        old.sceneId != widget.sceneId ||
        old.currentLayerId != widget.currentLayerId;
    if (frameChanged) {
      _scheduleComposite();
      // 選択範囲はフレームごとの一時状態のため、フレーム切替時にクリアする
      _clearSelectionMask();
      // 選択範囲の変形操作中にフレームが切り替わった場合の後始末
      // （通常のUIフローでは起こりにくいが、念のため状態を破棄する）。
      if (_selectionTransformActive) {
        _cancelTileUndoAndRestore();
        _floatingSelectionImage?.dispose();
        _floatingSelectionImage = null;
        _selectionTransformActive = false;
        _selectionTransformStart = null;
        _selectionTransformCenter = null;
        _selectionTransformBounds = null;
        _selectionTransformLive = null;
      }
    }
    _recomposeSurroundings(force: frameChanged);

    // ─── レイヤー全体の自由変形・メッシュ変形（新機能） ──────────────────
    final enteredMeshTransform =
        old.currentTool != DrawingTool.meshTransform &&
        widget.currentTool == DrawingTool.meshTransform;
    final leftMeshTransform =
        old.currentTool == DrawingTool.meshTransform &&
        widget.currentTool != DrawingTool.meshTransform;
    if (enteredMeshTransform) {
      _beginMeshTransform();
    }
    if (widget.currentTool == DrawingTool.meshTransform &&
        old.meshDensity != widget.meshDensity) {
      _applyMeshDensity(widget.meshDensity);
    }
    if (old.meshRotateDeg != widget.meshRotateDeg) {
      _applyMeshRotateDelta(widget.meshRotateDeg - old.meshRotateDeg);
    }
    if (old.meshScaleValue != widget.meshScaleValue &&
        old.meshScaleValue != 0) {
      _applyMeshScaleDelta(widget.meshScaleValue / old.meshScaleValue);
    }
    if (old.meshCommitToken != widget.meshCommitToken) {
      _commitMeshTransform();
    }
    if (old.meshCancelToken != widget.meshCancelToken) {
      _cancelMeshTransform();
    }
    // ツール切替ボタンなど、確定・キャンセルのトークンを経由せずツールが
    // 離脱した場合の保険（本来はcanvas_screen.dart側で必ずどちらかの
    // トークンを増やしてから離脱させる想定だが、念のため）。コミット処理が
    // 進行中の場合は_cancelMeshTransform内のガードにより何もしない。
    if (leftMeshTransform) {
      _cancelMeshTransform();
    }

    // 画面下部のスライダーによる変形。値が動いている間はライブプレビュー、
    // 指を離した時点（確定トークンの増加）で実画素へ焼き込む。
    if (old.selectionMoveX != widget.selectionMoveX ||
        old.selectionMoveY != widget.selectionMoveY ||
        old.selectionScale != widget.selectionScale ||
        old.selectionRotateDeg != widget.selectionRotateDeg) {
      _applySliderTransform();
    }
    if (old.selectionTransformCommitToken !=
        widget.selectionTransformCommitToken) {
      if (_selectionTransformActive) _commitSelectionTransform();
    }

    if (old.invertSelectionToken != widget.invertSelectionToken) {
      _invertSelectionMask();
    }
    if (old.selectAllSelectionToken != widget.selectAllSelectionToken) {
      _selectAllSelectionMask();
    }
    if (old.clearSelectionToken != widget.clearSelectionToken) {
      _clearSelectionMask();
    }
  }

  @override
  void dispose() {
    if (_selectionTransformActive && _undoRecordingLayerKey != null) {
      _tileManager.cancelUndoRecordingAndRestore();
      _undoRecordingLayerKey = null;
    }
    _holdEyedropperTimer?.cancel();
    meshSourceImage?.dispose();
    _transformController.dispose();
    _compositeImage?.dispose();
    _belowImage?.dispose();
    _aboveImage?.dispose();
    _selectionOverlayImage?.dispose();
    _selectionLayerOverlayImage?.dispose();
    _floatingSelectionImage?.dispose();
    for (final img in _onionImages.values) {
      img.dispose();
    }
    super.dispose();
  }

  // ─── 選択範囲マスク（矩形選択・投げ縄選択・自動選択で共通） ──

  void _clearSelectionMask() {
    if (_selectionMask == null && _selectionOverlayImage == null) return;
    _selectionOverlayImage?.dispose();
    _selectionOverlayImage = null;
    setState(() => _selectionMask = null);
    _notifySelectionActive(false);
  }

  /// 選択範囲の有無を親（canvas_screen.dart）へ知らせる。
  ///
  /// 「全選択」「全解除」ボタンはトークンの増加＝[didUpdateWidget]経由で
  /// ここへ来るため、ビルド中に親のsetStateを直接呼ぶと
  /// 「setState() called during build」で例外になり、通知そのものが
  /// 届かない（実際に「全選択」を押しても全解除ボタンとモードボタンが
  /// 出ないバグになっていた）。ビルド中はフレーム後まで遅らせる。
  void _notifySelectionActive(bool active) {
    final callback = widget.onSelectionActiveChanged;
    if (callback == null) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) callback(active);
      });
      return;
    }
    callback(active);
  }

  /// キャンバスの全ピクセルを選択する。UIの「全選択」から呼ばれる。
  void _selectAllSelectionMask() {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    _setSelectionMask(Uint8List(w * h)..fillRange(0, w * h, 0xFF), w, h);
  }

  /// 選択範囲を反転する（選択されていた部分と外側を入れ替える）。
  /// canvas_screen.dart側の「選択範囲を反転」ボタンから、invertSelectionToken
  /// の増加を通じて呼ばれる。選択範囲が無い場合は何もしない。
  void _invertSelectionMask() {
    final current = _selectionMask;
    if (current == null) return;
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final inverted = Uint8List(current.length);
    for (int i = 0; i < current.length; i++) {
      inverted[i] = current[i] == 0 ? 1 : 0;
    }
    _setSelectionMask(inverted, w, h);
  }

  Uint8List _rectSelectionMask(Offset a, Offset b, int w, int h) {
    final mask = Uint8List(w * h);
    final left = a.dx < b.dx ? a.dx : b.dx;
    final right = a.dx < b.dx ? b.dx : a.dx;
    final top = a.dy < b.dy ? a.dy : b.dy;
    final bottom = a.dy < b.dy ? b.dy : a.dy;
    final x0 = left.floor().clamp(0, w);
    final x1 = right.ceil().clamp(0, w);
    final y0 = top.floor().clamp(0, h);
    final y1 = bottom.ceil().clamp(0, h);
    for (int y = y0; y < y1; y++) {
      final rowBase = y * w;
      for (int x = x0; x < x1; x++) {
        mask[rowBase + x] = 1;
      }
    }
    return mask;
  }

  Uint8List _polygonSelectionMask(List<Offset> points, int w, int h) {
    final mask = Uint8List(w * h);
    if (points.length < 3) return mask;
    // 投げ縄塗り(LassoFillEngine)と同じRay Casting法。1回限りの確定処理
    // なので走査コストは許容範囲（毎フレーム再計算はしない）。
    bool inside(double px, double py) {
      int crossings = 0;
      final n = points.length;
      for (int i = 0; i < n; i++) {
        final pa = points[i];
        final pb = points[(i + 1) % n];
        if ((pa.dy <= py && pb.dy > py) || (pb.dy <= py && pa.dy > py)) {
          final t = (py - pa.dy) / (pb.dy - pa.dy);
          if (px < pa.dx + t * (pb.dx - pa.dx)) crossings++;
        }
      }
      return crossings % 2 != 0;
    }

    for (int y = 0; y < h; y++) {
      final rowBase = y * w;
      for (int x = 0; x < w; x++) {
        if (inside(x + 0.5, y + 0.5)) mask[rowBase + x] = 1;
      }
    }
    return mask;
  }

  /// 自動選択（マジックワンド）：タップ位置から表示中の全レイヤー合成色を基準に
  /// フラッドフィルし、選択範囲マスクを生成する。
  Future<void> _magicWandSelectAt(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final x = canvasPos.dx.round();
    final y = canvasPos.dy.round();
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
    final mask = _bucketEngine.selectionMask(
      canvasData: buffer,
      width: w,
      height: h,
      startX: x,
      startY: y,
    );
    _setSelectionMask(mask, w, h);
  }

  /// 選択範囲マスクを確定し、プレビュー用オーバーレイ画像を非同期で生成する。
  void _setSelectionMask(Uint8List mask, int w, int h) {
    _selectionOverlayImage?.dispose();
    _selectionOverlayImage = null;
    _selectionMask = mask;
    setState(() {});
    _notifySelectionActive(true);
    final rgba = Uint8List(w * h * 4);
    for (int i = 0; i < w * h; i++) {
      if (mask[i] == 0) continue;
      final idx = i * 4;
      // 選択範囲を半透明の水色でハイライト表示（キャンバス上のガイド表示、
      // 書き出しには含まれない）。
      rgba[idx] = 0x21;
      rgba[idx + 1] = 0x96;
      rgba[idx + 2] = 0xF3;
      rgba[idx + 3] = 0x55;
    }
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, (img) {
      if (!mounted || !identical(_selectionMask, mask)) {
        img.dispose();
        return;
      }
      setState(() => _selectionOverlayImage = img);
    });
  }

  // ─── 入力 ─────────────────────────────────────────────────────────────

  String get _layerId => widget.currentLayerId ?? 'Layer0001';

  /// レイヤーIDをTileManager用の合成キーへ変換する。通常レイヤーはフレームごとに
  /// 独立したキー（[frameLayerKey]）を使うが、共通・タイムライン素材・
  /// ウォーターマークなど表示範囲を持つレイヤーは、表示中のフレームに関わらず
  /// 常にホーム位置（実データのあるフレーム）のキーを指す（
  /// 複数フレームでの共有表示・共有編集のため）。
  String _tileKeyFor(String layerId, {int? frameIndex}) {
    final project = widget.project;
    if (project != null) {
      return context.read<ProjectService>().tileKeyFor(
        project.id,
        widget.sceneId,
        frameIndex ?? widget.currentFrame,
        layerId,
      );
    }
    return frameLayerKey(
      widget.sceneId,
      frameIndex ?? widget.currentFrame,
      layerId,
    );
  }

  void _syncBrushAndColor() {
    final bs = context.read<BrushService>();
    _drawingEngine.currentBrush = bs.currentBrush;
    final c = bs.currentColor;
    _drawingEngine.currentColor = ui.Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255).round().clamp(0, 255),
      (c.g * 255).round().clamp(0, 255),
      (c.b * 255).round().clamp(0, 255),
    );
  }

  /// 筆圧カーブ（アプリ全体に適用）と、品質設定の「傾き検知」ON/OFF
  /// （低品質・中品質はOFF固定）を反映したStrokePointを生成する。
  StrokePoint _rawToStrokePoint(PointerEvent event) {
    final settings = context.read<SettingsService>();
    final tiltEnabled = context.read<PerformanceService>().tiltEnabled;
    final raw = _inputHandler.toStrokePoint(
      event,
      pressureCurve: settings.applyPressureCurve,
    );
    if (tiltEnabled) return raw;
    return StrokePoint(
      x: raw.x,
      y: raw.y,
      pressure: raw.pressure,
      tiltX: 0,
      tiltY: 0,
      inputType: raw.inputType,
    );
  }

  /// [x]（Listener自身のローカル座標系でのタップ位置）が画面端の
  /// ダブルタップ専用ゾーン内かどうかを判定する。左端なら false（前の
  /// フレーム）、右端なら true（次のフレーム）、それ以外はnull。
  /// 画面幅がゾーン幅の3倍未満（極端に狭い端末・大きくズームされた
  /// ドッキングパネル幅など）の場合は誤操作防止のため無効化する。
  bool? _edgeDoubleTapSide(double x) {
    final size = context.size;
    if (size == null || size.width < _edgeDoubleTapZoneWidth * 3) return null;
    if (x <= _edgeDoubleTapZoneWidth) return false;
    if (x >= size.width - _edgeDoubleTapZoneWidth) return true;
    return null;
  }

  /// 画面端ゾーンでのタップを記録し、一定時間内に同じ側へ2回タップされて
  /// いれば前後のフレームへ移動する。
  void _handleEdgeZoneTap(bool isRight) {
    final now = DateTime.now();
    final last = _lastEdgeTapTime;
    final matched =
        last != null &&
        _lastEdgeTapWasRight == isRight &&
        now.difference(last) <= _edgeDoubleTapWindow;
    if (matched) {
      _lastEdgeTapTime = null;
      _lastEdgeTapWasRight = null;
      if (isRight) {
        widget.onNextFrame?.call();
      } else {
        widget.onPreviousFrame?.call();
      }
    } else {
      _lastEdgeTapTime = now;
      _lastEdgeTapWasRight = isRight;
    }
  }

  Matrix4 _constrainViewMatrix(Matrix4 candidate) {
    final size = context.size;
    if (size == null) return candidate;
    final drawingRect = canvasDrawingRectFor(size, widget.project);
    return constrainCanvasViewTransform(size, drawingRect, candidate);
  }

  /// マウスホイールでのズーム（Galaxy DeXモード・マウス入力）。
  /// カーソル位置を中心に拡大縮小する。
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final requestedFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final scaleFactor = boundedCanvasScaleFactor(currentScale, requestedFactor);
    final focal = event.localPosition;
    final zoomMatrix = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scaleFactor, scaleFactor, scaleFactor, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    // setState()で包まないこと。_transformControllerの値を変えると
    // 下のAnimatedBuilderが変換部分だけを描き直す。setStateを重ねると
    // 画面全体のビルドが余分に1回走る（以前はそうなっていた）。
    _transformController.value = _constrainViewMatrix(
      zoomMatrix * _transformController.value,
    );
  }

  /// 2本指以上でのキャンバス操作（パン・ピンチズーム・回転）。[movedPointer]が
  /// [newPos]へ動いたとき、他の指のうち1本（アンカー）を画面上に固定した
  /// ままの相似変換として計算する（アンカーは動かないため、その指の下の
  /// コンテンツが画面上でずれない）。3本指以上の場合も先頭2本のみを使う。
  void _applyMultiTouchTransform(int movedPointer, Offset newPos) {
    final anchorId = _activeTouchPositions.keys.firstWhere(
      (id) => id != movedPointer,
      orElse: () => -1,
    );
    if (anchorId == -1) return;
    final anchorPos = _activeTouchPositions[anchorId];
    final oldPos = _activeTouchPositions[movedPointer];
    if (anchorPos == null || oldPos == null || oldPos == newPos) return;

    final beforeVec = oldPos - anchorPos;
    final afterVec = newPos - anchorPos;
    final beforeDist = beforeVec.distance;
    final afterDist = afterVec.distance;
    // 指同士が近すぎる間は角度・拡大率の計算が不安定になるため更新しない。
    if (beforeDist < 4 || afterDist < 4) return;

    final requestedScaleFactor = afterDist / beforeDist;
    final rotationDelta = afterVec.direction - beforeVec.direction;
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final scaleFactor = boundedCanvasScaleFactor(
      currentScale,
      requestedScaleFactor,
    );
    final transform =
        Matrix4.translationValues(anchorPos.dx, anchorPos.dy, 0) *
        Matrix4.rotationZ(rotationDelta) *
        Matrix4.diagonal3Values(scaleFactor, scaleFactor, 1) *
        Matrix4.translationValues(-anchorPos.dx, -anchorPos.dy, 0);
    // 倍率だけを境界へクランプし、回転・パン成分は捨てない。
    _transformController.value = _constrainViewMatrix(
      transform * _transformController.value,
    );
  }

  void _onPointerDown(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);
    final canvasPos = _canvasPosition(event.localPosition);
    final settings = context.read<SettingsService>();
    if (_inputHandler.shouldRejectPalmTouch(
      type,
      palmRejectionEnabled: settings.palmRejectionEnabled,
    )) {
      return;
    }

    // フィルターパネルから起動した一時スポイト中は、現在選択中の描画
    // ツールを変更せず、このタップを色取得だけに使う。_pickColor()は
    // 表示中の全レイヤーを合成した見た目色を返す。
    if (widget.filterEyedropperActive) {
      _pickColor(canvasPos);
      return;
    }

    // 制作時間カウント：キャンバスへの操作のたびに無操作タイマーをリセットする
    if (widget.project != null) {
      context.read<ProjectService>().pingWorkActivity();
    }

    // ペンボタン検出（対応端末のみ）。バレルボタン押下時は割り当てられた
    // アクションを実行し、描画は開始しない。
    if (type == InputType.stylus) {
      final settings = context.read<SettingsService>();
      if (event.buttons & kPrimaryStylusButton != 0) {
        _handleGesture(context, settings.penButton1);
        return;
      }
      if (event.buttons & kSecondaryStylusButton != 0) {
        _handleGesture(context, settings.penButton2);
        return;
      }
    }

    // 中クリックドラッグ：現在のツールに関係なくキャンバスを平行移動する
    // （Galaxy DeXモード・マウス入力）。
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons & kMiddleMouseButton != 0) {
      _middleClickPanning = true;
      _middleClickLastScreenPos = event.localPosition;
      return;
    }

    if (widget.currentTool == DrawingTool.pan) {
      // 手のひらツール：描画は行わず、この指（スタイラス・マウスも含む）の
      // ドラッグでキャンバスを平行移動する。
      _panToolLastScreenPos = event.localPosition;
      return;
    }

    if (widget.currentTool == DrawingTool.text && widget.onTapForText != null) {
      widget.onTapForText!(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.eyedropper) {
      _pickColor(canvasPos);
      return;
    }
    if (_isSelectionTool &&
        _selectionMask != null &&
        _beginSelectionTransformIfHit(canvasPos)) {
      // 既存の選択範囲の中・またはハンドルをタップ＝新規選択ではなく
      // 移動・拡大縮小・回転操作として扱う。
      return;
    }
    if (widget.currentTool == DrawingTool.selectRect) {
      _clearSelectionMask();
      setState(() {
        _selectionStart = canvasPos;
        _selectionEnd = canvasPos;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      _clearSelectionMask();
      setState(() {
        _lassoPoints = [canvasPos];
      });
      return;
    }
    if (widget.currentTool == DrawingTool.selectMagicWand) {
      _clearSelectionMask();
      _magicWandSelectAt(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.shape &&
        widget.shapeKind != ShapeKind.off) {
      setState(() {
        _shapeStart = canvasPos;
        _shapeEnd = canvasPos;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.move) {
      setState(() {
        _moveStart = canvasPos;
        _moveDelta = Offset.zero;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.meshTransform) {
      final idx = _hitTestMeshPoint(canvasPos);
      if (idx != null) {
        _meshPointerToIndex[event.pointer] = idx;
      }
      return;
    }
    if (widget.currentTool == DrawingTool.ruler) {
      // 定規のハンドル（移動・回転・サイズ変更・消失点等）付近をタップ
      // した場合はハンドル操作として扱う。ハンドルに当たらなかった
      // 場合は、この下のペンと同じストローク開始処理へフォールスルー
      // させ、定規ガイドに沿ったスナップ描画が行えるようにする
      // （スナップ自体はDrawingEngineのpointConstraintへ
      // _rulerEngine.snapToRulerを差してあるので、ここでは何もしない。
      // 【重大バグ修正】以前はここで無条件にreturnしていたため、定規
      // ツールでハンドル以外の場所をタップしても何も反応しなかった）。
      if (_handleRulerDown(canvasPos)) return;
    }
    if (widget.currentTool == DrawingTool.bucket) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      // タッチのみの端末・スタイラス未使用時はタッチでも通常通り描画できる。
      _syncBrushAndColor();
      _handleBucketDown(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.lasso) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      // タッチのみの端末・スタイラス未使用時はタッチでも通常通り描画できる。
      setState(() {
        _lassoPoints = [canvasPos];
      });
      return;
    }
    if (widget.currentTool == DrawingTool.pen &&
        (widget.currentSubTool == PenSubTool.tone ||
            widget.currentSubTool == PenSubTool.stamp)) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      // タッチのみの端末・スタイラス未使用時はタッチでも通常通り描画できる。
      _syncBrushAndColor();
      setState(() {
        _subToolStrokePoints = [canvasPos];
      });
      return;
    }
    if (widget.currentTool == DrawingTool.finger) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      _handleFingerDown(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.blur ||
        widget.currentTool == DrawingTool.mosaic) {
      _handleBlurMosaicDown(canvasPos);
      return;
    }

    _syncBrushAndColor();
    // 透視定規：新しいストロークの開始点として、消失点スナップの基準をリセットする。
    _rulerEngine.beginStroke();
    // 定規ツール自身も、ハンドル以外をドラッグした場合はガイド沿いに描く。
    // MoveだけでなくDownの最初の点から同じsnap経路へ通し、ストローク先頭に
    // 定規外の点が残らないようにする。透視定規はRulerEngine側で最初の点を
    // anchorとして扱うため、この呼び出しで既存仕様も維持される。
    final point = _toCanvasPoint(_rawToStrokePoint(event));
    _beginTileUndo();
    _drawingEngine.beginStroke(point, _tileKeyFor(_layerId));
    _scheduleComposite();
    _armHoldEyedropperIfEligible(event, canvasPos);
  }

  void _onPointerMove(PointerEvent event) {
    if (_middleClickPanning) {
      final last = _middleClickLastScreenPos;
      if (last != null) {
        final delta = event.localPosition - last;
        final candidate =
            (Matrix4.identity()..translateByDouble(delta.dx, delta.dy, 0, 1)) *
            _transformController.value;
        _transformController.value = _constrainViewMatrix(candidate);
      }
      _middleClickLastScreenPos = event.localPosition;
      return;
    }
    final type = _inputHandler.classifyInput(event);
    final canvasPos = _canvasPosition(event.localPosition);
    if (_inputHandler.shouldRejectPalmTouch(
      type,
      palmRejectionEnabled: context
          .read<SettingsService>()
          .palmRejectionEnabled,
    )) {
      return;
    }

    if (widget.currentTool == DrawingTool.pan) {
      final last = _panToolLastScreenPos;
      if (last != null) {
        final delta = event.localPosition - last;
        final candidate =
            (Matrix4.identity()..translateByDouble(delta.dx, delta.dy, 0, 1)) *
            _transformController.value;
        _transformController.value = _constrainViewMatrix(candidate);
      }
      _panToolLastScreenPos = event.localPosition;
      return;
    }
    if (_isSelectionTool && _selectionTransformActive) {
      _updateSelectionTransform(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.selectRect &&
        _selectionStart != null) {
      setState(() => _selectionEnd = canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      setState(() => _lassoPoints.add(canvasPos));
      return;
    }
    if (widget.currentTool == DrawingTool.shape && _shapeStart != null) {
      setState(
        () => _shapeEnd = _snapShapeEnd(
          _shapeStart!,
          canvasPos,
          widget.shapeKind,
        ),
      );
      return;
    }
    if (widget.currentTool == DrawingTool.move && _moveStart != null) {
      setState(() => _moveDelta = canvasPos - _moveStart!);
      return;
    }
    if (widget.currentTool == DrawingTool.meshTransform) {
      final idx = _meshPointerToIndex[event.pointer];
      final points = meshControlPoints;
      if (idx != null && points != null) {
        final updated = List<Offset>.of(points);
        updated[idx] = canvasPos;
        setState(() => meshControlPoints = updated);
      }
      return;
    }
    if (widget.currentTool == DrawingTool.ruler && _rulerHandleId != null) {
      // ハンドルドラッグ中のみここで処理を終える。ハンドルを掴んでいない
      // （_onPointerDownがガイド沿いのストローク描画へフォールスルーした）
      // 場合は、下の通常のストローク継続処理へ進む。
      _handleRulerMove(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.bucket) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      // タッチのみの端末・スタイラス未使用時はタッチでも通常通り描画できる。
      _handleBucketMove(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.lasso) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      // タッチのみの端末・スタイラス未使用時はタッチでも通常通り描画できる。
      setState(() => _lassoPoints.add(canvasPos));
      return;
    }
    if (widget.currentTool == DrawingTool.pen &&
        (widget.currentSubTool == PenSubTool.tone ||
            widget.currentSubTool == PenSubTool.stamp)) {
      // パームリジェクション：スタイラス使用中（isStylusActive）のみタッチを無視する。
      // タッチのみの端末・スタイラス未使用時はタッチでも通常通り描画できる。
      setState(() => _subToolStrokePoints.add(canvasPos));
      return;
    }
    if (widget.currentTool == DrawingTool.finger) {
      _handleFingerMove(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.blur ||
        widget.currentTool == DrawingTool.mosaic) {
      _handleBlurMosaicMove(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.text ||
        widget.currentTool == DrawingTool.eyedropper) {
      return;
    }
    _updateHoldEyedropper(event, canvasPos);
    final point = _toCanvasPoint(_rawToStrokePoint(event));
    _drawingEngine.continueStroke(point, _tileKeyFor(_layerId));
    _scheduleComposite();
  }

  void _onPointerUp(PointerEvent event) {
    if (_middleClickPanning) {
      _middleClickPanning = false;
      _middleClickLastScreenPos = null;
      return;
    }
    final type = _inputHandler.classifyInput(event);
    if (_inputHandler.shouldRejectPalmTouch(
      type,
      palmRejectionEnabled: context
          .read<SettingsService>()
          .palmRejectionEnabled,
    )) {
      _disarmHoldEyedropper(event.pointer);
      return;
    }

    if (widget.currentTool == DrawingTool.pan) {
      _panToolLastScreenPos = null;
      return;
    }
    if (_isSelectionTool && _selectionTransformActive) {
      _commitSelectionTransform();
      return;
    }
    if (widget.currentTool == DrawingTool.selectRect) {
      final start = _selectionStart;
      final end = _selectionEnd;
      setState(() {
        _selectionStart = null;
        _selectionEnd = null;
      });
      if (start != null && end != null && start != end) {
        final w = _tileManager.canvasWidth;
        final h = _tileManager.canvasHeight;
        _setSelectionMask(_rectSelectionMask(start, end, w, h), w, h);
      }
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      final points = List<Offset>.of(_lassoPoints);
      setState(() => _lassoPoints = []);
      if (points.length >= 3) {
        final w = _tileManager.canvasWidth;
        final h = _tileManager.canvasHeight;
        _setSelectionMask(_polygonSelectionMask(points, w, h), w, h);
      }
      return;
    }
    if (widget.currentTool == DrawingTool.shape) {
      _commitShape();
      return;
    }
    if (widget.currentTool == DrawingTool.move) {
      _commitMove();
      return;
    }
    if (widget.currentTool == DrawingTool.meshTransform) {
      _meshPointerToIndex.remove(event.pointer);
      return;
    }
    if (widget.currentTool == DrawingTool.ruler && _rulerHandleId != null) {
      // ハンドルドラッグ中のみここで処理を終える。ハンドルを掴んでいない
      // （ガイド沿いのストローク描画中だった）場合は、下の通常の
      // ストローク確定処理へ進む。
      _handleRulerUp();
      return;
    }
    if (widget.currentTool == DrawingTool.bucket) {
      _handleBucketUp();
      // スタイラス操作の終了はポインター種別に関わらずここで確定する
      // （スタイラス自体のUpイベントでのみisStylusActiveを確実に解除するため）。
      _inputHandler.onPointerUp(event);
      return;
    }
    if (widget.currentTool == DrawingTool.lasso) {
      _commitLassoFill();
      setState(() => _lassoPoints = []);
      // スタイラス操作の終了はポインター種別に関わらずここで確定する
      // （スタイラス自体のUpイベントでのみisStylusActiveを確実に解除するため）。
      _inputHandler.onPointerUp(event);
      return;
    }
    if (widget.currentTool == DrawingTool.pen &&
        widget.currentSubTool == PenSubTool.tone) {
      _commitToneStroke();
      setState(() => _subToolStrokePoints = []);
      // スタイラス操作の終了はポインター種別に関わらずここで確定する
      // （スタイラス自体のUpイベントでのみisStylusActiveを確実に解除するため）。
      _inputHandler.onPointerUp(event);
      return;
    }
    if (widget.currentTool == DrawingTool.pen &&
        widget.currentSubTool == PenSubTool.stamp) {
      _commitStampStroke();
      setState(() => _subToolStrokePoints = []);
      // スタイラス操作の終了はポインター種別に関わらずここで確定する
      // （スタイラス自体のUpイベントでのみisStylusActiveを確実に解除するため）。
      _inputHandler.onPointerUp(event);
      return;
    }
    if (widget.currentTool == DrawingTool.finger) {
      _handleFingerUp();
      // スタイラス操作の終了はポインター種別に関わらずここで確定する
      // （スタイラス自体のUpイベントでのみisStylusActiveを確実に解除するため）。
      _inputHandler.onPointerUp(event);
      return;
    }
    if (widget.currentTool == DrawingTool.blur ||
        widget.currentTool == DrawingTool.mosaic) {
      // Down/Moveで開始したタイルUndoを、ポインターを離した時点で確定する。
      // ここを通さないと記録中のUndoが残り続け、ぼかし・モザイク操作を
      // Undoできないだけでなく、次の描画操作と同じ履歴へ混ざってしまう。
      _handleBlurMosaicUp();
      _inputHandler.onPointerUp(event);
      return;
    }
    if (widget.currentTool == DrawingTool.text ||
        widget.currentTool == DrawingTool.eyedropper) {
      return;
    }

    _disarmHoldEyedropper(event.pointer);
    _drawingEngine.endStroke();
    _quantizeStrokeIfNeeded();
    _inputHandler.onPointerUp(event);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// 自動塗り用線画レイヤーへ描画があった場合、直下の自動塗りレイヤーへ更新マークを立てる
  /// （needsAutofillUpdate自動セット）。
  void _markLineartDirtyIfNeeded() {
    final project = widget.project;
    if (project == null) return;
    context.read<ProjectService>().markLineartDirty(
      project.id,
      widget.sceneId,
      widget.currentFrame,
      _layerId,
    );
  }

  // ─── Undo/Redo ─────────────────────────────────────────────────────────

  String? _undoRecordingLayerKey;

  /// 描画操作（ストローク・バケツ・投げ縄塗り・トーン・スタンプ・移動・
  /// 変形・図形）の直前に呼び、現在のレイヤーへのタイル変更差分の記録を開始する。
  void _beginTileUndo() {
    _undoRecordingLayerKey = _tileKeyFor(_layerId);
    _tileManager.beginUndoRecording(_undoRecordingLayerKey!);
  }

  /// ブラシのピクセルモードで配色方式（[Brush.pixelColorMode]）が
  /// none以外の場合、ストローク確定直後・Undo記録終了前に今回変更された
  /// タイルだけへ色の後処理を適用する。ブラシは既に1px単位（アンチ
  /// エイリアス無し）で描画済みのため、ドット絵フィルターと異なり
  /// モザイク化は行わず、色の減色・パレットスナップのみを行う
  /// （quantizeColors参照）。この後にendUndoRecording()を呼ぶことで、
  /// 後処理後の状態がそのままUndoの「変更後」として記録される。
  void _quantizeStrokeIfNeeded() {
    final brush = _drawingEngine.currentBrush;
    if (brush == null ||
        !brush.pixelMode ||
        brush.pixelColorMode == PixelColorMode.none) {
      return;
    }
    final touched = _tileManager.recordingTouchedTiles;
    if (touched == null) return;
    for (final key in touched.tileKeys) {
      final parts = key.split(',');
      if (parts.length != 2) continue;
      final tx = int.tryParse(parts[0]);
      final ty = int.tryParse(parts[1]);
      if (tx == null || ty == null) continue;
      final tile = _tileManager.getTile(touched.layerId, tx, ty);
      if (tile == null) continue;
      final quantized = quantizeColors(
        tile,
        colorMode: brush.pixelColorMode,
        colorLevels: brush.pixelColorLevels,
        paletteColors: brush.pixelExplicitColors,
      );
      tile.setAll(0, quantized);
      // getTileのバッファを直接書き換えているため、TileManager側の
      // 無効化フックを通っていない。明示的にこのタイルのキャッシュを捨てる。
      _tileManager.invalidateTile(touched.layerId, tx, ty);
    }
  }

  /// 記録を終了し、実際に変更があった場合のみUndoManagerへ登録する。
  void _finishTileUndo() {
    final snapshot = _tileManager.endUndoRecording();
    final layerKey = _undoRecordingLayerKey;
    _undoRecordingLayerKey = null;
    if (snapshot.before.isEmpty || layerKey == null) return;
    context.read<app_undo.UndoManager>().push(
      app_undo.TileUndoAction(
        tileManager: _tileManager,
        layerId: layerKey,
        before: snapshot.before,
        after: snapshot.after,
        onApply: () {
          if (mounted) _scheduleComposite();
        },
      ),
    );
  }

  /// 開始済みのタイルUndo記録を履歴へ残さずキャンセルし、操作開始前の
  /// タイルへ即時復元する。非同期プレビューの準備前に操作が終了した場合など、
  /// 「途中までの変更」を絶対にレイヤーへ残してはいけない経路で使う。
  void _cancelTileUndoAndRestore() {
    _tileManager.cancelUndoRecordingAndRestore();
    _undoRecordingLayerKey = null;
    if (mounted) _scheduleComposite();
  }

  // ─── 投げ縄塗り（ペンサブツール） ─────────────────────────────

  /// 投げ縄塗りを確定する。囲って塗るモードON/OFF・ベタ/トーン・透明色=消しゴム
  /// の判定は LassoFillEngine 側で行う。
  Future<void> _commitLassoFill() async {
    if (_lassoPoints.length < 3) return;
    _syncBrushAndColor();
    _beginTileUndo();
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) return;
    final canvasData = byteData.buffer.asUint8List();
    final color = _drawingEngine.currentColor;

    Uint8List? toneTexture;
    const toneSize = 64;
    final toneService = context.read<ToneService>();
    if (toneService.lassoUseTone) {
      final tone = toneService.lastLassoTone ?? toneService.currentTone;
      if (tone != null) {
        await ensureToneTextureLoaded(tone, size: toneSize);
        if (!mounted) return;
        toneTexture = generateBuiltInToneTexture(tone, size: toneSize);
      }
    }

    final points = _lassoPoints.map((p) => ui.Offset(p.dx, p.dy)).toList();
    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // 塗りつぶし処理はバックグラウンドisolateで実行する。
    final result = await compute(runLassoFillInIsolate, (
      enclosed: widget.lassoFillEnclosedMode,
      points: points,
      color: color,
      canvasData: canvasData,
      width: w,
      height: h,
      toneTexture: toneTexture,
      toneTextureWidth: toneSize,
      toneTextureHeight: toneSize,
      selectionMask: _selectionMask,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  // ─── ペンサブツール：トーン自由描画・スタンプ ─────────────────────────

  /// トーン自由描画を確定する（現在色で描画・サイズ一定・
  /// 回転なし・密度なし・散布なし）。ドラッグ中はプレビューのみで、
  /// 指を離した時点でまとめてタイルへ反映する。
  Future<void> _commitToneStroke() async {
    if (_subToolStrokePoints.isEmpty) return;
    final toneService = context.read<ToneService>();
    final tone = toneService.currentTone;
    if (tone == null) return;
    final bs = context.read<BrushService>();
    final brushSize = bs.currentBrush?.size ?? 20;
    _beginTileUndo();
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) return;
    final canvasData = byteData.buffer.asUint8List();
    const toneSize = 64;
    await ensureToneTextureLoaded(tone, size: toneSize);
    if (!mounted) return;
    final texture = generateBuiltInToneTexture(tone, size: toneSize);
    final c = bs.currentColor;
    final color = ui.Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255).round().clamp(0, 255),
      (c.g * 255).round().clamp(0, 255),
      (c.b * 255).round().clamp(0, 255),
    );
    final points = _subToolStrokePoints
        .map((p) => ui.Offset(p.dx, p.dy))
        .toList();
    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // 描画処理はバックグラウンドisolateで実行する。
    final result = await compute(runToneStrokeInIsolate, (
      erase: widget.isEraser,
      points: points,
      brushSize: brushSize,
      color: color,
      canvasData: canvasData,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: texture,
      toneWidth: toneSize,
      toneHeight: toneSize,
      opacity: bs.currentBrush?.opacity ?? 100,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// スタンプ描画を確定する（色情報はスタンプ自身が保持・
  /// ブラシサイズ連動・回転／密度／散布対応）。
  Future<void> _commitStampStroke() async {
    if (_subToolStrokePoints.isEmpty) return;
    final stampService = context.read<StampService>();
    final stamp = stampService.currentStamp;
    if (stamp == null) return;
    final bs = context.read<BrushService>();
    final stampSize = bs.currentBrush?.size ?? 40;
    _beginTileUndo();
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) return;
    final canvasData = byteData.buffer.asUint8List();
    const texSize = 128;
    final texture = await generateBuiltInStampTexture(stamp, size: texSize);
    if (!mounted) return;

    // StampEngine側でパス長に沿った再サンプリングを行うため、ここでは
    // 生の入力点を保持する。事前に間引くと短い折れ返し・曲線が失われ、
    // 入力イベント密度によってスタンプ形状が変化してしまう。
    final stampPoints = _subToolStrokePoints
        .map((p) => ui.Offset(p.dx, p.dy))
        .toList(growable: false);

    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // スタンプ合成処理はバックグラウンドisolateで実行する。
    final result = await compute(runStampStrokeInIsolate, (
      canvasData: canvasData,
      width: w,
      height: h,
      texture: texture,
      texSize: texSize,
      points: stampPoints,
      stampSize: stampSize,
      rotation: stamp.rotation,
      scatter: stamp.scatter * stampSize,
      density: stamp.density,
      opacity: stamp.opacity,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// スポイトは表示中の全レイヤーを不透明度・ブレンドモード・クリッピングを
  /// 反映して合成した色をサンプリングする（表示されている見た目の色を拾う）。
  Future<void> _pickColor(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final px = canvasPos.dx.round();
    final py = canvasPos.dy.round();
    if (px < 0 || py < 0 || px >= w || py >= h) return;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
    final idx = (py * w + px) * 4;
    if (idx + 3 >= buffer.length) return;
    widget.onEyedropper?.call(
      Color.fromARGB(
        buffer[idx + 3],
        buffer[idx],
        buffer[idx + 1],
        buffer[idx + 2],
      ),
    );
  }

  // ─── 長押しスポイト（設定画面「ジェスチャー」で調整可能） ─────────────────

  /// ペン（トーン/スタンプサブツールを除く）・消しゴムでのストローク開始
  /// 時にのみ保留タイマーを仕込む。他のツール（バケツ・投げ縄・選択・図形・
  /// 変形等）は元々タイル未確定のままローカル状態のみで完結するか、
  /// バケツのように長押し自体が別の意味（連続塗り）を持つため対象外とする。
  void _armHoldEyedropperIfEligible(PointerEvent event, Offset canvasPos) {
    _holdEyedropperTimer?.cancel();
    _holdEyedropperTimer = null;
    _holdEyedropperPointerId = null;
    final settings = context.read<SettingsService>();
    if (!settings.holdEyedropperEnabled) return;
    final eligible =
        widget.currentTool == DrawingTool.eraser ||
        (widget.currentTool == DrawingTool.pen &&
            widget.currentSubTool != PenSubTool.tone &&
            widget.currentSubTool != PenSubTool.stamp);
    if (!eligible) return;
    _holdEyedropperPointerId = event.pointer;
    _holdEyedropperDownScreenPos = event.localPosition;
    _holdEyedropperLastCanvasPos = canvasPos;
    final ms = (settings.holdEyedropperSeconds * 1000).round().clamp(200, 3000);
    _holdEyedropperTimer = Timer(
      Duration(milliseconds: ms),
      () => _triggerHoldEyedropper(event.pointer),
    );
  }

  /// 保留中のポインターが指定px以上動いたら、通常のストロークとして継続
  /// させるため保留を解除する（誤発動防止）。
  void _updateHoldEyedropper(PointerEvent event, Offset canvasPos) {
    if (_holdEyedropperPointerId != event.pointer) return;
    _holdEyedropperLastCanvasPos = canvasPos;
    final down = _holdEyedropperDownScreenPos;
    if (down != null &&
        (event.localPosition - down).distance > _holdEyedropperMoveSlop) {
      _disarmHoldEyedropper(event.pointer);
    }
  }

  /// [pointer]を指定した場合はそのポインターの保留のみを解除する
  /// （既に別ポインターの保留へ差し替わっている場合に誤って解除しないため）。
  /// 省略した場合は無条件に解除する。
  void _disarmHoldEyedropper([int? pointer]) {
    if (pointer != null && _holdEyedropperPointerId != pointer) return;
    _holdEyedropperTimer?.cancel();
    _holdEyedropperTimer = null;
    _holdEyedropperPointerId = null;
    _holdEyedropperDownScreenPos = null;
    _holdEyedropperLastCanvasPos = null;
  }

  /// 長押しが保留時間まで成立した時点で呼ばれる。それまでに描かれていた
  /// 分のストロークをUndo履歴に残さず巻き戻し（TileManagerが記録している
  /// 「変更前」タイルへ書き戻すだけ）、その位置の色をスポイトのように拾う。
  /// このポインターは以後の描画ツール処理から除外する（残りの
  /// onPointerMove/onPointerUpは無視され、既に離れた状態のまま扱われる）。
  Future<void> _triggerHoldEyedropper(int pointer) async {
    if (_holdEyedropperPointerId != pointer) return;
    final canvasPos = _holdEyedropperLastCanvasPos;
    _holdEyedropperTimer = null;
    _holdEyedropperPointerId = null;
    _holdEyedropperDownScreenPos = null;
    _holdEyedropperLastCanvasPos = null;

    final snapshot = _tileManager.endUndoRecording();
    final layerKey = _undoRecordingLayerKey;
    _undoRecordingLayerKey = null;
    if (layerKey != null && snapshot.before.isNotEmpty) {
      _tileManager.applyTileSnapshot(layerKey, snapshot.before);
    }
    _drawingEngine.endStroke();
    _toolHandledPointers.remove(pointer);
    _scheduleComposite();

    if (canvasPos == null) return;
    await _pickColor(canvasPos);
  }

  // ─── 図形ツール ───────────────────────────────────────────────────────

  /// 四角形・円のドラッグ終点を、縦横比1:1付近で正方形・真円へ自動スナップする。
  Offset _snapShapeEnd(Offset start, Offset end, ShapeKind kind) {
    if (kind != ShapeKind.rect && kind != ShapeKind.circle) return end;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx == 0 || dy == 0) return end;
    final ratio = dx.abs() / dy.abs();
    if (ratio > 0.9 && ratio < 1.1) {
      final side = math.max(dx.abs(), dy.abs());
      return Offset(
        start.dx + side * (dx.isNegative ? -1 : 1),
        start.dy + side * (dy.isNegative ? -1 : 1),
      );
    }
    return end;
  }

  List<Offset> _ellipsePoints(Offset start, Offset end, {int segments = 48}) {
    final cx = (start.dx + end.dx) / 2;
    final cy = (start.dy + end.dy) / 2;
    final rx = (end.dx - start.dx).abs() / 2;
    final ry = (end.dy - start.dy).abs() / 2;
    return List.generate(segments, (i) {
      final t = (i / segments) * 2 * math.pi;
      return Offset(cx + rx * math.cos(t), cy + ry * math.sin(t));
    });
  }

  void _commitShape() {
    final start = _shapeStart;
    final end = _shapeEnd;
    setState(() {
      _shapeStart = null;
      _shapeEnd = null;
    });
    if (start == null || end == null || widget.shapeKind == ShapeKind.off) {
      return;
    }
    if (start == end) return;
    _syncBrushAndColor();
    _beginTileUndo();
    List<Offset> points;
    bool closeLoop;
    switch (widget.shapeKind) {
      case ShapeKind.line:
        points = [start, end];
        closeLoop = false;
      case ShapeKind.rect:
        points = [
          start,
          Offset(end.dx, start.dy),
          end,
          Offset(start.dx, end.dy),
        ];
        closeLoop = true;
      case ShapeKind.circle:
        points = _ellipsePoints(start, end);
        closeLoop = true;
      case ShapeKind.off:
        return;
    }
    // 図形はブラシ・トーンどちらでも描画可能。ペンサブツールが
    // トーンの場合はトーンストロークエンジンで、それ以外はブラシで描画する。
    if (widget.currentSubTool == PenSubTool.tone) {
      _commitShapeWithTone(points, closeLoop);
    } else {
      _drawingEngine.commitShapePath(
        points.map((p) => StrokePoint(x: p.dx, y: p.dy)).toList(),
        _tileKeyFor(_layerId),
        closeLoop: closeLoop,
      );
      _quantizeStrokeIfNeeded();
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    }
  }

  /// 図形をトーンで塗る（ブラシ・トーンどちらでも描画可能）。
  /// トーン自由描画（_commitToneStroke）と同じ仕組みで、図形の輪郭線上に
  /// 一定間隔で補間した密な点列をトーンストロークとして描画する。
  Future<void> _commitShapeWithTone(
    List<Offset> pathPoints,
    bool closeLoop,
  ) async {
    final toneService = context.read<ToneService>();
    final tone = toneService.currentTone;
    if (tone == null) {
      _finishTileUndo();
      return;
    }
    final bs = context.read<BrushService>();
    final brushSize = bs.currentBrush?.size ?? 20;
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) {
      _finishTileUndo();
      return;
    }
    final canvasData = byteData.buffer.asUint8List();
    const toneSize = 64;
    await ensureToneTextureLoaded(tone, size: toneSize);
    if (!mounted) {
      _finishTileUndo();
      return;
    }
    final texture = generateBuiltInToneTexture(tone, size: toneSize);
    final c = bs.currentColor;
    final color = ui.Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255).round().clamp(0, 255),
      (c.g * 255).round().clamp(0, 255),
      (c.b * 255).round().clamp(0, 255),
    );
    final densePoints = _densifyPath(
      pathPoints,
      closeLoop,
      math.max(1.0, brushSize / 3),
    );
    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // 描画処理はバックグラウンドisolateで実行する。
    final result = await compute(runToneStrokeInIsolate, (
      erase: false,
      points: densePoints,
      brushSize: brushSize,
      color: color,
      canvasData: canvasData,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: texture,
      toneWidth: toneSize,
      toneHeight: toneSize,
      opacity: bs.currentBrush?.opacity ?? 100,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// パス（[points]、[closeLoop]なら終点→始点も繋ぐ）を[spacing]間隔で
  /// 補間した密な点列に変換する（トーンストロークは点ごとにスタンプするため、
  /// 図形の頂点間を塗りつぶさずに済むよう補間が必要）。
  List<ui.Offset> _densifyPath(
    List<Offset> points,
    bool closeLoop,
    double spacing,
  ) {
    if (points.isEmpty) return const [];
    final segments = <Offset>[...points];
    if (closeLoop) segments.add(points.first);
    final result = <ui.Offset>[ui.Offset(points.first.dx, points.first.dy)];
    for (int i = 0; i < segments.length - 1; i++) {
      final from = segments[i];
      final to = segments[i + 1];
      final dist = (to - from).distance;
      final steps = math.max(1, (dist / spacing).ceil());
      for (int s = 1; s <= steps; s++) {
        final t = s / steps;
        result.add(
          ui.Offset(
            from.dx + (to.dx - from.dx) * t,
            from.dy + (to.dy - from.dy) * t,
          ),
        );
      }
    }
    return result;
  }

  // ─── 移動ツール ───────────────────────────────────────────────────────

  void _commitMove() {
    final start = _moveStart;
    final delta = _moveDelta;
    setState(() {
      _moveStart = null;
      _moveDelta = Offset.zero;
    });
    if (start == null) return;
    if (delta.dx.abs() < 0.5 && delta.dy.abs() < 0.5) return;
    _beginTileUndo();
    _tileManager.translateLayer(_tileKeyFor(_layerId), delta.dx, delta.dy).then(
      (_) {
        if (!mounted) return;
        _scheduleComposite();
        _markLineartDirtyIfNeeded();
        _finishTileUndo();
      },
    );
  }

  // ─── 選択範囲の変形行列 ───────────────────────────────────────────────

  /// 移動・拡大縮小・回転の行列を計算する。
  static Matrix4 _computeTransformMatrix(
    _TransformMode mode,
    Offset start,
    Offset current,
    Offset center,
  ) {
    switch (mode) {
      case _TransformMode.translate:
        final d = current - start;
        return Matrix4.translationValues(d.dx, d.dy, 0);
      case _TransformMode.scale:
        final startDist = (start - center).distance;
        final curDist = (current - center).distance;
        final s = startDist > 1 ? (curDist / startDist).clamp(0.1, 10.0) : 1.0;
        return Matrix4.translationValues(center.dx, center.dy, 0) *
            Matrix4.diagonal3Values(s, s, 1) *
            Matrix4.translationValues(-center.dx, -center.dy, 0);
      case _TransformMode.rotate:
        final a0 = math.atan2(start.dy - center.dy, start.dx - center.dx);
        final a1 = math.atan2(current.dy - center.dy, current.dx - center.dx);
        return Matrix4.translationValues(center.dx, center.dy, 0) *
            Matrix4.rotationZ(a1 - a0) *
            Matrix4.translationValues(-center.dx, -center.dy, 0);
    }
  }

  // ─── レイヤー全体の自由変形・メッシュ変形（新機能） ────────────────────
  // 範囲選択せずに現在レイヤー全体を対象にする点は変形ツールと同じだが、
  // 4隅（自由変形）または格子状に分割した各点（メッシュ変形）を個別に
  // ドラッグでき、台形・平行四辺形・波打つような自由な歪みを付けられる。
  // 分割数・回転・拡大縮小はcanvas_screen.dart側のコントロールパネルから、
  // プロパティの変化・トークンの増加としてdidUpdateWidget経由で伝わる。

  /// メッシュ変形ツールへ切り替わった直後：現在レイヤーの合成画像を
  /// ワープ元として取得し、既定の分割数（widget.meshDensity）で規則格子を
  /// 初期状態として設定する。
  Future<void> _beginMeshTransform() async {
    final key = _tileKeyFor(_layerId);
    final source = await _tileManager.compositeLayerToImage(key);
    if (!mounted || widget.currentTool != DrawingTool.meshTransform) {
      source.dispose();
      return;
    }
    final rows = widget.meshDensity.clamp(1, 10);
    final bounds = Rect.fromLTWH(
      0,
      0,
      _tileManager.canvasWidth.toDouble(),
      _tileManager.canvasHeight.toDouble(),
    );
    setState(() {
      meshSourceImage?.dispose();
      meshRows = rows;
      meshCols = rows;
      meshSourceImage = source;
      meshControlPoints = MeshWarpEngine.regularGrid(rows, rows, bounds);
      _meshPointerToIndex.clear();
    });
  }

  /// 分割数（1〜10）が変わった：格子点を新しい分割数の規則格子へ作り直す
  /// （仕様上、分割数変更時点までの個別ドラッグ・回転・拡大縮小はリセット
  /// される。単純さを優先した仕様）。
  void _applyMeshDensity(int density) {
    if (meshSourceImage == null) return;
    final rows = density.clamp(1, 10);
    final bounds = Rect.fromLTWH(
      0,
      0,
      _tileManager.canvasWidth.toDouble(),
      _tileManager.canvasHeight.toDouble(),
    );
    setState(() {
      meshRows = rows;
      meshCols = rows;
      meshControlPoints = MeshWarpEngine.regularGrid(rows, rows, bounds);
      _meshPointerToIndex.clear();
    });
  }

  Offset _meshCentroid(List<Offset> points) {
    var sum = Offset.zero;
    for (final p in points) {
      sum += p;
    }
    return sum / points.length.toDouble();
  }

  /// 回転スライダーの値がdeltaDeg（度）分変化した：現在の全格子点を、
  /// それらの重心を中心にdeltaDeg分だけ追加で回転する（スライダー自体は
  /// 絶対値を持つが、格子点側は直前の適用分からの差分だけを毎回加える
  /// ため、個別ドラッグ操作と自然に共存できる）。
  void _applyMeshRotateDelta(double deltaDeg) {
    final points = meshControlPoints;
    if (points == null || deltaDeg == 0) return;
    final center = _meshCentroid(points);
    final rad = deltaDeg * math.pi / 180;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    final rotated = points.map((p) {
      final d = p - center;
      return Offset(d.dx * cosA - d.dy * sinA, d.dx * sinA + d.dy * cosA) +
          center;
    }).toList();
    setState(() => meshControlPoints = rotated);
  }

  /// 拡大縮小スライダーの値がratio倍変化した：現在の全格子点を、それらの
  /// 重心を中心にratio倍だけ追加で拡大縮小する（回転と同様、直前の適用分
  /// からの差分＝比率のみを加える）。
  void _applyMeshScaleDelta(double ratio) {
    final points = meshControlPoints;
    if (points == null || ratio == 0 || !ratio.isFinite) return;
    final center = _meshCentroid(points);
    final scaled = points.map((p) => center + (p - center) * ratio).toList();
    setState(() => meshControlPoints = scaled);
  }

  /// タップ・ドラッグ開始位置(canvasPos)に最も近い格子点を探す（現在の
  /// キャンバス表示倍率に関わらず一定の見た目のヒット半径になるよう、
  /// _meshHandleHitRadius（画面px相当）を表示倍率で割ってキャンバス
  /// ピクセル空間の半径へ変換する）。
  int? _hitTestMeshPoint(Offset canvasPos) {
    final points = meshControlPoints;
    if (points == null) return null;
    final scale = _transformController.value.getMaxScaleOnAxis();
    final radius = _meshHandleHitRadius / (scale > 0 ? scale : 1);
    int? best;
    double bestDist = radius;
    for (int i = 0; i < points.length; i++) {
      final d = (points[i] - canvasPos).distance;
      if (d <= bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// 確定（コントロールパネルの「適用」ボタン）：ワープ後の画像をラスタライズ
  /// してレイヤーのタイルへ書き戻し、Undo履歴へ登録する。
  Future<void> _commitMeshTransform() async {
    final points = meshControlPoints;
    final source = meshSourceImage;
    if (points == null || source == null) return;
    final rows = meshRows;
    final cols = meshCols;
    _meshCommitInFlight = true;
    _beginTileUndo();
    try {
      await _tileManager.meshTransformLayer(
        _tileKeyFor(_layerId),
        rows,
        cols,
        points,
      );
    } finally {
      _meshCommitInFlight = false;
    }
    if (!mounted) return;
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
    setState(() {
      meshControlPoints = null;
      meshSourceImage?.dispose();
      meshSourceImage = null;
      _meshPointerToIndex.clear();
    });
  }

  /// キャンセル（コントロールパネルの「キャンセル」ボタン・閉じるボタン・
  /// ツール離脱時の保険）：ワープ元画像・格子点を破棄してプレビューを消す
  /// だけで、レイヤーへは何も書き戻さない。確定処理が進行中の場合は、
  /// その処理がまだ参照しているui.Imageを誤ってdisposeしないよう何もしない。
  void _cancelMeshTransform() {
    if (_meshCommitInFlight) return;
    if (meshControlPoints == null && meshSourceImage == null) return;
    setState(() {
      meshControlPoints = null;
      meshSourceImage?.dispose();
      meshSourceImage = null;
      _meshPointerToIndex.clear();
    });
  }

  // ─── 選択ツールの移動・回転・拡大縮小 ─────────────────
  // 選択範囲がある状態で選択ツールを使うと、選択範囲の中をタップ＝移動、
  // 右下ハンドル＝拡大縮小、上部ハンドル＝回転として操作できる（変形ツール
  // と同じ操作感）。ドラッグ中は選択範囲の中身を切り取った「浮動画像」を
  // プレビュー表示し、指を離した時点で元レイヤーへ貼り戻す。選択範囲自体も
  // 同じ変形をかけて移動後の位置へ追従させる。

  /// 現在の選択マスクのバウンディングボックス（キャンバスピクセル座標）。
  /// 選択が無い場合はnull。
  Rect? _selectionMaskBounds() {
    final mask = _selectionMask;
    if (mask == null) return null;
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    int minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++) {
      final rowBase = y * w;
      for (int x = 0; x < w; x++) {
        if (mask[rowBase + x] == 0) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX || maxY < minY) return null;
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }

  bool _selectionMaskContains(Offset canvasPos) {
    final mask = _selectionMask;
    if (mask == null) return false;
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final x = canvasPos.dx.floor();
    final y = canvasPos.dy.floor();
    if (x < 0 || x >= w || y < 0 || y >= h) return false;
    return mask[y * w + x] != 0;
  }

  /// いま画面に出ているキャンバス1pxが画面何pxにあたるか
  /// （＝描画エリアの拡大率。ピンチズームぶんも含む）。
  double get _canvasToScreenScale {
    final size = context.size;
    final canvasW = canvasPixelSizeOf(widget.project).width;
    if (size == null || size.width <= 0 || canvasW <= 0) return 1.0;
    final rect = canvasDrawingRectFor(size, widget.project);
    if (rect.width <= 0) return 1.0;
    final zoom = _transformController.value.getMaxScaleOnAxis();
    return (rect.width / canvasW) * (zoom > 0 ? zoom : 1.0);
  }

  /// 選択範囲がある間、常時描くハンドルの半径（キャンバスpx）。
  /// 位置の計算と当たり判定の両方でこの同じ値を使う。
  double get _selectionHandleHitRadius =>
      selectionHandleRadiusFor(_canvasToScreenScale);

  /// 指が届く範囲をキャンバスpxで表した矩形。_CanvasPainter側と同じ計算元
  /// （canvasDrawingRectFor＋いまのズーム・パン）を使い、当たり判定と
  /// 描画位置を一致させる。
  Rect? get _reachableCanvasRect {
    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return null;
    final rect = canvasDrawingRectFor(size, widget.project);
    if (rect.width <= 0 || rect.height <= 0) return null;
    return reachableCanvasRectFor(
      visibleWidgetRectFor(size, _transformController.value),
      rect,
      widget.project,
    );
  }

  /// [canvasPos]が選択範囲のハンドル／内側に該当すれば、掴んだ場所に応じた
  /// モードで変形操作を開始してtrueを返す。該当しなければfalse（＝新規選択へ）。
  ///
  /// モードはボタンではなく**掴んだ場所**で決まる。四隅＝拡大縮小、中央の
  /// 十字矢印＝移動、右上のカーブ矢印＝回転。以前は「掴む前はハンドルが
  /// 描かれない」ために何ができるか分からなかったが、いまは選択範囲がある間
  /// 常にハンドルを描いているので、見たまま掴めばよい。
  bool _beginSelectionTransformIfHit(Offset canvasPos) {
    final bounds = _selectionMaskBounds();
    if (bounds == null) return false;
    final r = _selectionHandleHitRadius;
    final rotateR = selectionRotateHandleRadiusFor(_canvasToScreenScale);
    final reachable = _reachableCanvasRect;
    _TransformMode mode;
    if ((canvasPos -
                selectionRotateHandleOf(
                  bounds,
                  r,
                  rotateRadius: rotateR,
                  reachable: reachable,
                ))
            .distance <
        rotateR) {
      mode = _TransformMode.rotate;
    } else if (selectionScaleHandlesOf(
      bounds,
    ).any((c) => (canvasPos - c).distance < r)) {
      mode = _TransformMode.scale;
    } else if ((canvasPos - bounds.center).distance < r ||
        _selectionMaskContains(canvasPos)) {
      mode = _TransformMode.translate;
    } else {
      return false;
    }
    _beginSelectionTransform(canvasPos, mode, bounds);
    return true;
  }

  void _beginSelectionTransform(
    Offset canvasPos,
    _TransformMode mode,
    Rect bounds,
  ) {
    final mask = _selectionMask;
    if (mask == null) return;
    setState(() {
      _selectionTransformActive = true;
      _selectionTransformMode = mode;
      _selectionTransformStart = canvasPos;
      _selectionTransformCenter = bounds.center;
      _selectionTransformBounds = bounds;
      _selectionTransformLive = Matrix4.identity();
    });
    _beginTileUndo();
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final key = _tileKeyFor(_layerId);
    _tileManager.compositeLayerToImage(key).then((composite) async {
      final byteData = await composite.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      composite.dispose();
      if (!mounted || byteData == null || !identical(_selectionMask, mask)) {
        return;
      }
      final src = byteData.buffer.asUint8List();
      // 選択範囲内のピクセルを切り取った浮動画像を作る（範囲外は透明）。
      final floating = Uint8List(w * h * 4);
      for (int i = 0; i < w * h; i++) {
        if (mask[i] == 0) continue;
        final idx = i * 4;
        floating[idx] = src[idx];
        floating[idx + 1] = src[idx + 1];
        floating[idx + 2] = src[idx + 2];
        floating[idx + 3] = src[idx + 3];
      }
      // 元レイヤーの選択範囲内を透明化する（切り取り＝穴が空いた状態にする）。
      // タップ直後にすぐ指を離す等でコミットが先に完了していた場合は、
      // 浮動画像を貼り戻す先が無いまま切り取りだけが残ってしまう
      // （データ消失）ため、ここで再度アクティブ状態を確認する。
      if (!_selectionTransformActive) return;
      for (int y = 0; y < h; y++) {
        final rowBase = y * w;
        for (int x = 0; x < w; x++) {
          if (mask[rowBase + x] == 0) continue;
          final tx = x ~/ TileManager.tileSize;
          final ty = y ~/ TileManager.tileSize;
          final tile = _tileManager.getOrCreateTile(key, tx, ty);
          final lx = x % TileManager.tileSize;
          final ly = y % TileManager.tileSize;
          _tileManager.setPixel(tile, lx, ly, 0, 0, 0, 0);
          _tileManager.markDirty(key, tx, ty);
        }
      }
      if (!mounted) return;
      _scheduleComposite();
      ui.decodeImageFromPixels(floating, w, h, ui.PixelFormat.rgba8888, (img) {
        if (!mounted || !_selectionTransformActive) {
          img.dispose();
          return;
        }
        setState(() => _floatingSelectionImage = img);
      });
    });
  }

  /// 画面下部のスライダーの値を選択範囲へ反映する（ライブプレビュー）。
  ///
  /// 最初に値が動いた時点で、ドラッグと同じように選択範囲の中身を切り出して
  /// 「浮動画像」にする。以降は行列だけ差し替えるので、スライダーを動かして
  /// いる間は実画素を触らない（確定は[_commitSelectionTransform]）。
  void _applySliderTransform() {
    final bounds = _selectionMaskBounds();
    if (bounds == null) return;
    if (!_selectionTransformActive) {
      // まだ掴んでいない状態からスライダーが動いた：切り出しだけ先に始める。
      _beginSelectionTransform(bounds.center, _TransformMode.translate, bounds);
    }
    final center = bounds.center;
    final scale = widget.selectionScale <= 0 ? 1.0 : widget.selectionScale;
    final radians = widget.selectionRotateDeg * math.pi / 180.0;
    final matrix =
        Matrix4.translationValues(
          widget.selectionMoveX,
          widget.selectionMoveY,
          0,
        ) *
        Matrix4.translationValues(center.dx, center.dy, 0) *
        Matrix4.rotationZ(radians) *
        Matrix4.diagonal3Values(scale, scale, 1) *
        Matrix4.translationValues(-center.dx, -center.dy, 0);
    setState(() => _selectionTransformLive = matrix);
  }

  void _updateSelectionTransform(Offset canvasPos) {
    final start = _selectionTransformStart;
    final center = _selectionTransformCenter;
    if (start == null || center == null) return;
    setState(
      () => _selectionTransformLive = _computeTransformMatrix(
        _selectionTransformMode,
        start,
        canvasPos,
        center,
      ),
    );
  }

  void _commitSelectionTransform() {
    final matrix = _selectionTransformLive ?? Matrix4.identity();
    final floating = _floatingSelectionImage;
    setState(() {
      _selectionTransformActive = false;
      _selectionTransformStart = null;
      _selectionTransformCenter = null;
      _selectionTransformBounds = null;
      _selectionTransformLive = null;
      _floatingSelectionImage = null;
    });
    if (floating == null) {
      // 浮動画像の生成が間に合わないうちに指を離した場合：変形操作は成立
      // していないので、切り取り途中の画素をUndo履歴として残すのではなく、
      // 操作開始直前へ即時ロールバックする。
      _cancelTileUndoAndRestore();
      return;
    }
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    _tileManager.compositeLayerToImage(key).then((base) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(base, Offset.zero, ui.Paint());
      base.dispose();
      canvas.save();
      canvas.transform(matrix.storage);
      canvas.drawImage(floating, Offset.zero, ui.Paint());
      canvas.restore();
      floating.dispose();
      final picture = recorder.endRecording();
      final merged = await picture.toImage(w, h);
      picture.dispose();
      final byteData = await merged.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      merged.dispose();
      if (!mounted) return;
      if (byteData != null) {
        _tileManager.replaceLayerPixels(key, byteData.buffer.asUint8List());
      }
      // 選択範囲も同じ変形をかけ、選択範囲が移動後の位置へ追従するようにする。
      if (!matrix.isIdentity()) _transformSelectionMask(matrix);
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    });
  }

  /// 選択マスクへ[matrix]と同じ変形をかけ、選択範囲を移動後の位置へ更新する。
  void _transformSelectionMask(Matrix4 matrix) {
    final mask = _selectionMask;
    if (mask == null) return;
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final maskRgba = Uint8List(w * h * 4);
    for (int i = 0; i < w * h; i++) {
      if (mask[i] == 0) continue;
      final idx = i * 4;
      maskRgba[idx] = 255;
      maskRgba[idx + 1] = 255;
      maskRgba[idx + 2] = 255;
      maskRgba[idx + 3] = 255;
    }
    ui.decodeImageFromPixels(maskRgba, w, h, ui.PixelFormat.rgba8888, (
      maskImage,
    ) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.transform(matrix.storage);
      canvas.drawImage(maskImage, Offset.zero, ui.Paint());
      maskImage.dispose();
      final picture = recorder.endRecording();
      final transformed = await picture.toImage(w, h);
      picture.dispose();
      final byteData = await transformed.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      transformed.dispose();
      if (!mounted || byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final newMask = Uint8List(w * h);
      for (int i = 0; i < w * h; i++) {
        newMask[i] = bytes[i * 4 + 3] > 32 ? 1 : 0;
      }
      _setSelectionMask(newMask, w, h);
    });
  }

  // ─── バケツ連続塗り ───────────────────────────────────────────────────

  /// バケツ塗りの参照用に、表示中の全レイヤーを不透明度・ブレンドモード・
  /// クリッピングを反映して合成する（バケツは表示中の全レイヤーの線を参照）。
  Future<Uint8List> _flattenVisibleLayers() async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final project = widget.project;
    if (project == null) return Uint8List(w * h * 4);
    final layers = context.read<ProjectService>().layersOf(
      project.id,
      widget.sceneId,
      widget.currentFrame,
    );
    final image = await LayerCompositor.composite(
      _tileManager,
      layers,
      (l) => _tileKeyFor(l.id),
      w,
      h,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List() ?? Uint8List(w * h * 4);
  }

  Future<void> _handleBucketDown(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
    // バケツ塗り中（_bucketFillAt）はポインタ移動のたびに同期呼び出しされる
    // ため、トーン画像は開始時点で事前読み込みしてキャッシュへ入れておく。
    final toneService = context.read<ToneService>();
    final tone = toneService.bucketUseTone
        ? (toneService.lastBucketTone ?? toneService.currentTone)
        : null;
    if (tone != null) {
      await ensureToneTextureLoaded(tone, size: 64);
      if (!mounted) return;
    }
    _beginTileUndo();
    _bucketRefBuffer = buffer;
    _bucketVisitedMask = Uint8List(w * h);
    _bucketFillAt(canvasPos);
  }

  void _handleBucketMove(Offset canvasPos) {
    if (_bucketRefBuffer == null) return;
    _bucketFillAt(canvasPos);
  }

  void _handleBucketUp() {
    if (_bucketVisitedMask != null) _markLineartDirtyIfNeeded();
    _finishTileUndo();
    _bucketRefBuffer = null;
    _bucketVisitedMask = null;
  }

  final BucketFillEngine _bucketEngine = BucketFillEngine();

  /// 開始点からフラッドフィルし、変化したピクセルのみ現在レイヤーへ反映する。
  /// スワイプ中の連続塗り：既に塗った領域（訪問済みマスク）は再計算しない。
  void _bucketFillAt(Offset canvasPos) {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final x = canvasPos.dx.round();
    final y = canvasPos.dy.round();
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final mask = _bucketVisitedMask;
    final reference = _bucketRefBuffer;
    if (mask == null || reference == null) return;
    if (mask[y * w + x] != 0) return;

    final toneService = context.read<ToneService>();
    final tone = toneService.bucketUseTone
        ? (toneService.lastBucketTone ?? toneService.currentTone)
        : null;
    // バケツ塗り詳細設定（設定画面「バケツ塗り」）：許容誤差・拡張px・
    // 線の下まで潜るかを反映する。
    final bucketSettings = context.read<SettingsService>();
    final Uint8List result;
    if (tone != null) {
      const toneSize = 64;
      final texture = generateBuiltInToneTexture(tone, size: toneSize);
      result = _bucketEngine.fillWithTone(
        canvasData: reference,
        width: w,
        height: h,
        startX: x,
        startY: y,
        toneColor: _drawingEngine.currentColor,
        toneTexture: texture,
        toneWidth: toneSize,
        toneHeight: toneSize,
        selectionMask: _selectionMask,
        tolerance: bucketSettings.bucketTolerance,
        expandPx: bucketSettings.bucketExpandPx,
        fillUnderLine: bucketSettings.bucketFillUnderLine,
      );
    } else {
      result = _bucketEngine.fill(
        canvasData: reference,
        width: w,
        height: h,
        startX: x,
        startY: y,
        fillColor: _drawingEngine.currentColor,
        selectionMask: _selectionMask,
        tolerance: bucketSettings.bucketTolerance,
        expandPx: bucketSettings.bucketExpandPx,
        fillUnderLine: bucketSettings.bucketFillUnderLine,
      );
    }

    bool changed = false;
    for (int py = 0; py < h; py++) {
      final rowBase = py * w;
      for (int px = 0; px < w; px++) {
        final idx = (rowBase + px) * 4;
        if (result[idx] != reference[idx] ||
            result[idx + 1] != reference[idx + 1] ||
            result[idx + 2] != reference[idx + 2] ||
            result[idx + 3] != reference[idx + 3]) {
          mask[rowBase + px] = 1;
          final tx = px ~/ TileManager.tileSize;
          final ty = py ~/ TileManager.tileSize;
          final key = _tileKeyFor(_layerId);
          final tile = _tileManager.getOrCreateTile(key, tx, ty);
          final lx = px % TileManager.tileSize;
          final ly = py % TileManager.tileSize;
          _tileManager.blendPixel(
            tile,
            lx,
            ly,
            result[idx],
            result[idx + 1],
            result[idx + 2],
            result[idx + 3],
          );
          _tileManager.markDirty(key, tx, ty);
          changed = true;
        }
      }
    }
    if (changed) _scheduleComposite();
  }

  // ─── 指ツール（歪み） ───────────────────────────────────────
  // 指でなぞった方向にピクセルを押し流す「Liquify」系の歪み効果。
  // ストローク開始時に現在レイヤーの合成画像をバッファへ読み込み、以後の
  // 移動ごとにドラッグ方向・距離に応じて円形の範囲内のピクセルを再配置する
  // （中心付近ほど大きく動き、範囲の外縁でなめらかに0へ収束する）。

  void _handleFingerDown(Offset canvasPos) {
    _beginTileUndo();
    _warpLastPos = canvasPos;
    _tileManager.compositeLayerToImage(_tileKeyFor(_layerId)).then((
      image,
    ) async {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      if (!mounted) return;
      _warpBuffer = byteData?.buffer.asUint8List();
    });
  }

  void _handleFingerMove(Offset canvasPos) {
    final buffer = _warpBuffer;
    final last = _warpLastPos;
    if (buffer == null || last == null) {
      _warpLastPos = canvasPos;
      return;
    }
    final delta = canvasPos - last;
    _warpLastPos = canvasPos;
    // バッファ読み込み完了前（非同期）にごく僅かに動いただけの場合は無視する。
    if (delta.distance < 0.5) return;
    _applyFingerWarp(buffer, canvasPos, delta);
  }

  void _handleFingerUp() {
    _warpBuffer = null;
    _warpLastPos = null;
    if (_undoRecordingLayerKey != null) {
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    }
  }

  // ガウスぼかし・モザイクツール：指でなぞるように円形範囲にフィルターを連続適用する。
  final FilterEngine _filterEngine = FilterEngine();

  void _handleBlurMosaicDown(Offset canvasPos) {
    _beginTileUndo();
    _warpLastPos = canvasPos;
    _applyBlurMosaic(canvasPos);
  }

  void _handleBlurMosaicMove(Offset canvasPos) {
    _warpLastPos = canvasPos;
    _applyBlurMosaic(canvasPos);
  }

  void _handleBlurMosaicUp() {
    _warpLastPos = null;
    if (_undoRecordingLayerKey != null) {
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    }
  }

  void _applyBlurMosaic(Offset center) {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final brushSize = context.read<BrushService>().currentBrush?.size ?? 20;
    final radius = (brushSize * 1.5).round().clamp(4, 300);
    final isMosaic = widget.currentTool == DrawingTool.mosaic;
    final cx = center.dx.round();
    final cy = center.dy.round();
    final minX = (cx - radius).clamp(0, w - 1);
    final maxX = (cx + radius).clamp(0, w - 1);
    final minY = (cy - radius).clamp(0, h - 1);
    final maxY = (cy + radius).clamp(0, h - 1);
    if (minX >= maxX || minY >= maxY) return;
    final regionW = maxX - minX + 1;
    final regionH = maxY - minY + 1;
    final region = Uint8List(regionW * regionH * 4);
    final key = _tileKeyFor(_layerId);
    // 対象範囲のピクセルをタイルから読み出す
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dist = math.sqrt(
          (x - cx) * (x - cx) + (y - cy) * (y - cy).toDouble(),
        );
        if (dist > radius) continue;
        final tx = x ~/ TileManager.tileSize;
        final ty = y ~/ TileManager.tileSize;
        final tile = _tileManager.getOrCreateTile(key, tx, ty);
        final lx = x % TileManager.tileSize;
        final ly = y % TileManager.tileSize;
        final ti = (ly * TileManager.tileSize + lx) * 4;
        final ri = ((y - minY) * regionW + (x - minX)) * 4;
        region[ri] = tile[ti];
        region[ri + 1] = tile[ti + 1];
        region[ri + 2] = tile[ti + 2];
        region[ri + 3] = tile[ti + 3];
      }
    }
    // フィルター適用
    final strength = (brushSize / 10).clamp(1.0, 8.0);
    final processed = isMosaic
        ? _filterEngine.applyMosaic(
            region,
            regionW,
            regionH,
            strength.round().clamp(2, 16),
          )
        : _filterEngine.applyGaussianBlur(region, regionW, regionH, strength);
    // 結果を書き戻す（円形マスク内のみ）
    bool changed = false;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dist = math.sqrt(
          (x - cx) * (x - cx) + (y - cy) * (y - cy).toDouble(),
        );
        if (dist > radius) continue;
        final tx = x ~/ TileManager.tileSize;
        final ty = y ~/ TileManager.tileSize;
        final tile = _tileManager.getOrCreateTile(key, tx, ty);
        final lx = x % TileManager.tileSize;
        final ly = y % TileManager.tileSize;
        final ti = (ly * TileManager.tileSize + lx) * 4;
        final ri = ((y - minY) * regionW + (x - minX)) * 4;
        tile[ti] = processed[ri];
        tile[ti + 1] = processed[ri + 1];
        tile[ti + 2] = processed[ri + 2];
        tile[ti + 3] = processed[ri + 3];
        _tileManager.markDirty(key, tx, ty);
        changed = true;
      }
    }
    if (changed) _scheduleComposite();
  }

  /// [center]を中心とした円形範囲内のピクセルを、[delta]方向へ押し流す。
  /// [buffer]はストローク開始時点のスナップショットを直接書き換えていく
  /// （読み取り元は毎回そのイベント開始前の状態をコピーして使うため、同一
  /// 移動イベント内での自己参照によるにじみは生じない）。
  void _applyFingerWarp(Uint8List buffer, Offset center, Offset delta) {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final brushSize = context.read<BrushService>().currentBrush?.size ?? 20;
    final radius = brushSize * 1.5;
    if (radius < 2) return;
    final minX = (center.dx - radius).floor().clamp(0, w - 1);
    final maxX = (center.dx + radius).ceil().clamp(0, w - 1);
    final minY = (center.dy - radius).floor().clamp(0, h - 1);
    final maxY = (center.dy + radius).ceil().clamp(0, h - 1);
    if (minX > maxX || minY > maxY) return;

    // 読み取り元は今回の移動イベント開始時点のスナップショット（範囲分のみ複製）。
    final srcSnapshot = Uint8List.fromList(buffer);

    bool changed = false;
    final key = _tileKeyFor(_layerId);
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dist = math.sqrt(
          (x - center.dx) * (x - center.dx) + (y - center.dy) * (y - center.dy),
        );
        if (dist > radius) continue;
        final t = 1.0 - (dist / radius);
        final falloff = t * t * (3.0 - 2.0 * t); // smoothstep
        if (falloff <= 0) continue;
        final srcX = x - delta.dx * falloff;
        final srcY = y - delta.dy * falloff;
        final sampled = _sampleBilinear(srcSnapshot, w, h, srcX, srcY);
        final idx = (y * w + x) * 4;
        buffer[idx] = sampled[0];
        buffer[idx + 1] = sampled[1];
        buffer[idx + 2] = sampled[2];
        buffer[idx + 3] = sampled[3];

        final tx = x ~/ TileManager.tileSize;
        final ty = y ~/ TileManager.tileSize;
        final tile = _tileManager.getOrCreateTile(key, tx, ty);
        final lx = x % TileManager.tileSize;
        final ly = y % TileManager.tileSize;
        _tileManager.setPixel(
          tile,
          lx,
          ly,
          sampled[0],
          sampled[1],
          sampled[2],
          sampled[3],
        );
        _tileManager.markDirty(key, tx, ty);
        changed = true;
      }
    }
    if (changed) _scheduleComposite();
  }

  /// (x, y)地点（実数座標）のRGBAをバイリニア補間でサンプリングする。
  /// 範囲外は透明を返す。
  List<int> _sampleBilinear(
    Uint8List buffer,
    int w,
    int h,
    double x,
    double y,
  ) {
    if (x < 0 || y < 0 || x >= w - 1 || y >= h - 1) {
      final ix = x.round().clamp(0, w - 1);
      final iy = y.round().clamp(0, h - 1);
      if (x < -1 || y < -1 || x > w || y > h) return const [0, 0, 0, 0];
      final idx = (iy * w + ix) * 4;
      return [buffer[idx], buffer[idx + 1], buffer[idx + 2], buffer[idx + 3]];
    }
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final fx = x - x0;
    final fy = y - y0;
    List<int> at(int px, int py) {
      final idx = (py * w + px) * 4;
      return [buffer[idx], buffer[idx + 1], buffer[idx + 2], buffer[idx + 3]];
    }

    final c00 = at(x0, y0);
    final c10 = at(x1, y0);
    final c01 = at(x0, y1);
    final c11 = at(x1, y1);
    final result = <int>[];
    for (int i = 0; i < 4; i++) {
      final top = c00[i] * (1 - fx) + c10[i] * fx;
      final bottom = c01[i] * (1 - fx) + c11[i] * fx;
      result.add((top * (1 - fy) + bottom * fy).round().clamp(0, 255));
    }
    return result;
  }

  // ─── 定規の編集（移動・回転・サイズ変更・消失点移動） ───────────
  // 定規ツール選択中はキャンバスタップがハンドル操作として扱われる。
  // ハンドル座標は_paintRulerの描画と同じ座標系（ルーラーの position/
  // vanishingPoint と同じ、export解像度基準）で計算する。

  String? _rulerHandleId;
  Ruler? _rulerDragStartRuler;

  /// ハンドルの当たり判定許容範囲（プロジェクトピクセル単位）。
  /// ハンドル座標・_canvasPositionの戻り値ともプロジェクトピクセル
  /// （export解像度基準）で表されるため、画面上で指28px相当のタップ
  /// 許容範囲になるよう、ズーム倍率だけでなく「ウィジェット表示サイズ÷
  /// プロジェクトの書き出しサイズ」の縮小率も加味して逆算する
  /// （【重大バグ修正】タスク#141。以前はズーム倍率のみで計算していた
  /// ため、書き出し解像度がウィジェットの表示サイズより大幅に大きい
  /// 通常のケースでは、実質的な当たり判定が指では掴めないほど極端に
  /// 小さくなってしまっていた）。
  double get _rulerHitTolerance {
    const screenPixels = 28.0;
    final zoomScale = _transformController.value.getMaxScaleOnAxis();
    final size = context.size;
    final canvasW = canvasPixelSizeOf(widget.project).width;
    if (size == null || size.width <= 0 || size.height <= 0 || canvasW <= 0) {
      return zoomScale > 0 ? screenPixels / zoomScale : screenPixels;
    }
    final rect = canvasDrawingRectFor(size, widget.project);
    if (rect.width <= 0) {
      return zoomScale > 0 ? screenPixels / zoomScale : screenPixels;
    }
    final fitScale = rect.width / canvasW;
    final effectiveScale = zoomScale * fitScale;
    return effectiveScale > 0 ? screenPixels / effectiveScale : screenPixels;
  }

  Offset _rotatePoint(Offset v, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// 現在のルーラーのハンドル一覧（ハンドルID→キャンバス座標）を返す。
  /// _paintRulerが描画するハンドル位置と対応させている。
  Map<String, Offset> _rulerHandlePositions(Ruler r) {
    switch (r.type) {
      case RulerType.line:
        return {
          'move': r.position,
          'rotate': r.position + Offset.fromDirection(r.rotation, 220),
        };
      case RulerType.ellipse:
        final rx = r.settings.radiusX ?? 200;
        final ry = r.settings.radiusY ?? 120;
        return {
          'move': r.position,
          'resizeX': r.position + _rotatePoint(Offset(rx, 0), r.rotation),
          'resizeY': r.position + _rotatePoint(Offset(0, ry), r.rotation),
          'rotate': r.position + _rotatePoint(Offset(rx + 50, 0), r.rotation),
        };
      case RulerType.radial:
        return {
          'move': r.position,
          'rotate': r.position + Offset.fromDirection(r.rotation, 160),
        };
      case RulerType.onePointPerspective:
        return {'vp1': r.settings.vanishingPoint1 ?? r.position};
      case RulerType.twoPointPerspective:
        return {
          'vp1': r.settings.vanishingPoint1 ?? const Offset(200, 540),
          'vp2': r.settings.vanishingPoint2 ?? const Offset(1720, 540),
        };
      case RulerType.threePointPerspective:
        return {
          'vp1': r.settings.vanishingPoint1 ?? const Offset(200, 540),
          'vp2': r.settings.vanishingPoint2 ?? const Offset(1720, 540),
          'vp3': r.settings.vanishingPoint3 ?? const Offset(960, 100),
        };
      case RulerType.circle:
        return {'move': r.position};
    }
  }

  /// ハンドルをドラッグした結果の新しいRulerを計算する。
  Ruler _rulerWithHandleAt(Ruler r, String handleId, Offset canvasPos) {
    switch (handleId) {
      case 'move':
        return r.copyWith(position: canvasPos);
      case 'rotate':
        return r.copyWith(rotation: (canvasPos - r.position).direction);
      case 'resizeX':
      case 'resizeY':
        final local = _rotatePoint(canvasPos - r.position, -r.rotation);
        double newRx = r.settings.radiusX ?? 200;
        double newRy = r.settings.radiusY ?? 120;
        if (handleId == 'resizeX') {
          newRx = local.dx.abs().clamp(10.0, 4000.0);
        } else {
          newRy = local.dy.abs().clamp(10.0, 4000.0);
        }
        // 正円スナップ（横幅≒縦幅になると自動で正円に吸い付く）
        final maxR = math.max(newRx, newRy);
        if (maxR > 0 && (newRx - newRy).abs() / maxR < 0.08) {
          if (handleId == 'resizeX') {
            newRy = newRx;
          } else {
            newRx = newRy;
          }
        }
        return r.copyWith(
          settings: r.settings.copyWith(radiusX: newRx, radiusY: newRy),
        );
      case 'vp1':
        return r.copyWith(
          settings: r.settings.copyWith(vanishingPoint1: canvasPos),
        );
      case 'vp2':
        return r.copyWith(
          settings: r.settings.copyWith(vanishingPoint2: canvasPos),
        );
      case 'vp3':
        return r.copyWith(
          settings: r.settings.copyWith(vanishingPoint3: canvasPos),
        );
      default:
        return r;
    }
  }

  /// 定規のハンドル付近をタップした場合はドラッグ操作を開始しtrueを返す。
  /// ハンドルに当たらなかった場合（定規が無い場合を含む）はfalseを返し、
  /// 呼び出し元がガイド沿いのストローク描画へフォールスルーできるようにする。
  bool _handleRulerDown(Offset canvasPos) {
    final ruler = widget.activeRuler;
    if (ruler == null) return false;
    final handles = _rulerHandlePositions(ruler);
    String? bestId;
    double bestDist = _rulerHitTolerance;
    for (final entry in handles.entries) {
      final d = (entry.value - canvasPos).distance;
      if (d <= bestDist) {
        bestDist = d;
        bestId = entry.key;
      }
    }
    if (bestId == null) return false;
    _rulerHandleId = bestId;
    _rulerDragStartRuler = ruler;
    return true;
  }

  void _handleRulerMove(Offset canvasPos) {
    final handleId = _rulerHandleId;
    final ruler = widget.activeRuler;
    if (handleId == null || ruler == null) return;
    widget.onRulerChanged?.call(_rulerWithHandleAt(ruler, handleId, canvasPos));
  }

  void _handleRulerUp() {
    final handleId = _rulerHandleId;
    final before = _rulerDragStartRuler;
    _rulerHandleId = null;
    _rulerDragStartRuler = null;
    if (handleId == null || before == null) return;
    final after = widget.activeRuler;
    if (after == null || identical(before, after)) return;
    context.read<app_undo.UndoManager>().push(
      app_undo.RulerUndoAction(
        before: before,
        after: after,
        onApply: (ruler) => widget.onRulerChanged?.call(ruler),
      ),
    );
  }

  // ─── 座標変換 ─────────────────────────────────────────────────────────

  /// Listenerローカル座標（ズーム・パン適用前のウィジェット内座標）を、
  /// _CanvasPainterが実際に描画へ使う矩形（canvasDrawingRectFor、
  /// レターボックス時は中央揃え）を通してプロジェクトのピクセル座標
  /// （0..drawingWidth, 0..drawingHeight＝canvasPixelSizeOf）へ変換する。
  ///
  /// 【重大バグ修正】以前はこの矩形変換が欠落しており、ズーム・パン分の
  /// 逆行列適用だけで完結させていたため、ウィジェットの表示サイズが
  /// プロジェクトの書き出しサイズ・アスペクト比と一致しない（ほぼ常に
  /// 一致しない）限り、タップ位置と実際に描画される位置がずれる不具合が
  /// あった（ペン・消しゴム・選択ツール等、_canvasPosition/_toCanvasPointを
  /// 経由する全ツールに影響）。
  Offset _widgetLocalToCanvasPixel(Offset widgetLocal) {
    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return widgetLocal;
    final rect = canvasDrawingRectFor(size, widget.project);
    if (rect.width <= 0 || rect.height <= 0) return widgetLocal;
    final canvasPx = canvasPixelSizeOf(widget.project);
    return Offset(
      (widgetLocal.dx - rect.left) * canvasPx.width / rect.width,
      (widgetLocal.dy - rect.top) * canvasPx.height / rect.height,
    );
  }

  StrokePoint _toCanvasPoint(StrokePoint screen) {
    final inv = Matrix4.inverted(_transformController.value);
    final local = MatrixUtils.transformPoint(inv, Offset(screen.x, screen.y));
    final canvasPos = _widgetLocalToCanvasPixel(local);
    return StrokePoint(
      x: canvasPos.dx,
      y: canvasPos.dy,
      pressure: screen.pressure,
      tiltX: screen.tiltX,
      tiltY: screen.tiltY,
      inputType: screen.inputType,
    );
  }

  Offset _canvasPosition(Offset screenPos) {
    final inv = Matrix4.inverted(_transformController.value);
    final local = MatrixUtils.transformPoint(inv, screenPos);
    return _widgetLocalToCanvasPixel(local);
  }

  // ─── 合成 ─────────────────────────────────────────────────────────────

  /// 現在レイヤーの画像を合成する。クリッピングONの場合はクリッピング元レイヤーの
  /// 形状でマスクした状態まで合成しておく（不透明度・ブレンドモードはpaint時に
  /// 適用するためここでは反映しない）。
  Future<ui.Image> _composeCurrentLayerImage() async {
    final key = _tileKeyFor(_layerId);
    final raw = await _tileManager.compositeLayerToImage(key);
    final idx = _layers.indexWhere((l) => l.id == _layerId);
    if (idx < 0 || !_layers[idx].hasClipping) return raw;
    final clipSourceId = findClipSourceLayerId(_layers, idx);
    if (clipSourceId == null) return raw;
    final clipImg = await _tileManager.compositeLayerToImage(
      _tileKeyFor(clipSourceId),
    );
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    canvas.saveLayer(rect, ui.Paint());
    canvas.drawImage(clipImg, ui.Offset.zero, ui.Paint());
    canvas.drawImage(
      raw,
      ui.Offset.zero,
      ui.Paint()..blendMode = ui.BlendMode.srcIn,
    );
    canvas.restore();
    clipImg.dispose();
    raw.dispose();
    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  void _scheduleComposite() {
    final project = widget.project;
    if (project == null) return;
    if (_isCompositing) {
      setState(() {});
      return;
    }
    _isCompositing = true;
    _composeCurrentLayerImage().then((img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _compositeImage?.dispose();
        _compositeImage = img;
        _isCompositing = false;
      });
      // 現在レイヤーが選択レイヤー自体の場合、たった今描いたストロークを
      // オーバーレイへも反映する（存在しない・別レイヤーの場合はキャッシュ
      // 済みの合成結果を返すだけなので軽量）。
      _refreshSelectionLayerOverlay();
    });
  }

  /// 選択レイヤー（LayerType.selection、pixelLayerTypesから除外されて
  /// いるため通常合成には現れない）が存在する場合、その内容を単体で合成
  /// してオーバーレイ表示用に保持する。TileManager.compositeLayerToImage
  /// 自体がレイヤーごとにキャッシュされているため、対象レイヤーの内容が
  /// 変わっていなければ再デコードは発生しない。
  Future<void> _refreshSelectionLayerOverlay() async {
    final selectionLayer = _layers
        .where((l) => l.type == LayerType.selection)
        .firstOrNull;
    if (selectionLayer == null) {
      if (_selectionLayerOverlayImage != null) {
        final old = _selectionLayerOverlayImage;
        setState(() => _selectionLayerOverlayImage = null);
        old?.dispose();
      }
      return;
    }
    if (_isRefreshingSelectionLayerOverlay) return;
    _isRefreshingSelectionLayerOverlay = true;
    final img = await _tileManager.compositeLayerToImage(
      _tileKeyFor(selectionLayer.id),
    );
    _isRefreshingSelectionLayerOverlay = false;
    if (!mounted) {
      img.dispose();
      return;
    }
    setState(() {
      _selectionLayerOverlayImage?.dispose();
      _selectionLayerOverlayImage = img;
    });
  }

  /// 現在レイヤーより手前（above）／奥（below）にあるレイヤー群を、
  /// 不透明度・ブレンドモード・クリッピングを反映して合成しておく
  /// ドラッグ中の移動・変形プレビューでは現在レイヤーの画像
  /// （_compositeImage）だけを動かせば済むよう、あえて現在レイヤーを含めず
  /// 前後に分けてキャッシュする。
  ///
  /// レイヤーの追加・削除・並び替え・表示切替・不透明度・ブレンドモード変更は
  /// ProjectServiceを経由するため、[force]がfalseの場合は直前に取得した
  /// レイヤー一覧と参照が変わっていない限り再合成をスキップする（低スペック
  /// 端末対策）。
  Future<void> _recomposeSurroundings({bool force = false}) async {
    final project = widget.project;
    if (project == null) return;
    if (_isComposingSurroundings) return;
    final ps = context.read<ProjectService>();
    final layers = ps.layersOf(project.id, widget.sceneId, widget.currentFrame);
    if (!force && _sameLayerList(_layers, layers)) return;
    _layers = layers;
    _isComposingSurroundings = true;

    final idx = layers.indexWhere((l) => l.id == _layerId);
    final above = idx < 0 ? const <Layer>[] : layers.sublist(0, idx);
    final below = idx < 0 ? layers : layers.sublist(idx + 1);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    LayerKeyframe? groupKf(Layer layer) {
      final group = ps.groupContainingLayer(
        project.id,
        widget.sceneId,
        layer.id,
      );
      if (group == null || group.keyframes.isEmpty) return null;
      return _layerKeyframeEngine.valueAt(group.keyframes, widget.currentFrame);
    }

    final belowImg = await LayerCompositor.composite(
      _tileManager,
      below,
      (l) => _tileKeyFor(l.id),
      w,
      h,
      keyframeOf: _keyframeOf,
      groupKeyframeOf: groupKf,
    );
    if (!mounted) {
      belowImg.dispose();
      _isComposingSurroundings = false;
      return;
    }
    final aboveImg = await LayerCompositor.composite(
      _tileManager,
      above,
      (l) => _tileKeyFor(l.id),
      w,
      h,
      keyframeOf: _keyframeOf,
      groupKeyframeOf: groupKf,
    );
    if (!mounted) {
      belowImg.dispose();
      aboveImg.dispose();
      _isComposingSurroundings = false;
      return;
    }
    setState(() {
      _belowImage?.dispose();
      _belowImage = belowImg;
      _aboveImage?.dispose();
      _aboveImage = aboveImg;
      _isComposingSurroundings = false;
    });
    // レイヤー一覧が変わった（追加・削除・並び替え・レイヤー切替）ため、
    // 選択レイヤーのオーバーレイも合わせて確認し直す。
    _refreshSelectionLayerOverlay();
    // 合成中にさらに変更があった場合に備えて再チェック
    final latest = ps.layersOf(project.id, widget.sceneId, widget.currentFrame);
    if (!_sameLayerList(_layers, latest)) _recomposeSurroundings();
  }

  /// レイヤーキーフレーム（パーツ単位アニメーション）を現在フレームで補間する。
  LayerKeyframe? _keyframeOf(Layer layer, [int? frameIndex]) =>
      layer.keyframes.isEmpty
      ? null
      : _layerKeyframeEngine.valueAt(
          layer.keyframes,
          frameIndex ?? widget.currentFrame,
        );

  bool _sameLayerList(List<Layer> a, List<Layer> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// オニオンスキン用の前後フレーム画像を合成する。対象レイヤーは通常レイヤーと
  /// 自動塗り用線画レイヤーのみ（共通・テキスト・自動塗り・タイムライン
  /// 素材レイヤーは対象外）。
  Future<void> _buildOnionImages() async {
    if (!widget.onionSkinSettings.enabled) {
      if (_onionImages.isNotEmpty) {
        setState(() {
          for (final img in _onionImages.values) {
            img.dispose();
          }
          _onionImages.clear();
          _onionImagesView = const {};
        });
      }
      return;
    }
    final project = widget.project;
    if (project == null) return;
    final offsets = _onionSkinEngine.getVisibleFrameOffsets(
      widget.onionSkinSettings,
    );
    final ps = context.read<ProjectService>();
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final newImages = <int, ui.Image>{};
    for (final offset in offsets) {
      final frameIdx = widget.currentFrame + offset;
      if (frameIdx < 0) continue;
      final layers = ps.layersOf(project.id, widget.sceneId, frameIdx);
      if (layers.isEmpty) continue;
      newImages[offset] = await LayerCompositor.composite(
        _tileManager,
        layers,
        (l) => _tileKeyFor(l.id, frameIndex: frameIdx),
        w,
        h,
        shouldRender: (layer, _) =>
            layer.type == LayerType.normal ||
            layer.type == LayerType.autoFillLineart,
        keyframeOf: (layer) => _keyframeOf(layer, frameIdx),
        groupKeyframeOf: (layer) {
          final group = ps.groupContainingLayer(
            project.id,
            widget.sceneId,
            layer.id,
          );
          if (group == null || group.keyframes.isEmpty) return null;
          return _layerKeyframeEngine.valueAt(group.keyframes, frameIdx);
        },
      );
    }
    if (!mounted) {
      for (final img in newImages.values) {
        img.dispose();
      }
      return;
    }
    setState(() {
      for (final img in _onionImages.values) {
        img.dispose();
      }
      _onionImages
        ..clear()
        ..addAll(newImages);
      _onionImagesView = Map.unmodifiable(_onionImages);
    });
  }

  // ─── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final theme = context.watch<ThemeService>().current;
    final currentBrush = context.watch<BrushService>().currentBrush;
    final pixelBrushActive =
        currentBrush?.pixelMode == true &&
        ((widget.currentTool == DrawingTool.pen &&
                widget.currentSubTool == PenSubTool.brush) ||
            widget.currentTool == DrawingTool.eraser ||
            widget.currentTool == DrawingTool.ruler ||
            widget.currentTool == DrawingTool.shape);
    return GestureDetector(
      // 2本指タップ
      onSecondaryTap: () => _handleGesture(context, settings.twoFingerTap),
      child: Listener(
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.touch ||
              e.kind == PointerDeviceKind.stylus) {
            final edgeSide = _edgeDoubleTapSide(e.localPosition.dx);
            // メッシュ変形では操作ハンドル（格子点）自体がキャンバス端に
            // 置かれる。端ダブルタップ専用ゾーンを先に奪うと端の格子点が
            // タッチ不能になるため、このツールではツール側へポインターを
            // 優先して渡す。フレーム送りは他ツールでは従来通り有効。
            final transformNeedsEdge =
                widget.currentTool == DrawingTool.meshTransform;
            if (edgeSide != null && !transformNeedsEdge) {
              _handleEdgeZoneTap(edgeSide);
              return;
            }
          }
          if (e.kind == PointerDeviceKind.touch) {
            _touchCount++;
            _activeTouchPositions[e.pointer] = e.localPosition;
            _multiTouchTapTracker.pointerDown(
              e.pointer,
              e.localPosition,
              DateTime.now(),
            );
            if (_activeTouchPositions.length >= 2 && _canTouchTransform) {
              _touchTransformActive = true;
              // 2本指目が触れた時点で、既存の1本指用の長押しスポイト保留は
              // 変形操作の意図と衝突するため解除する。
              _disarmHoldEyedropper();
            }
            // 2本指以上でのキャンバス操作モード中は、この指を描画ツールへ
            // 渡さない（複数指での誤描画・二重ストローク防止）。
            if (_touchTransformActive) return;
          }
          _toolHandledPointers.add(e.pointer);
          _onPointerDown(e);
        },
        onPointerMove: (e) {
          if (e.kind == PointerDeviceKind.touch &&
              _activeTouchPositions.containsKey(e.pointer)) {
            _multiTouchTapTracker.pointerMove(e.pointer, e.localPosition);
            if (_touchTransformActive) {
              if (_activeTouchPositions.length >= 2 && _canTouchTransform) {
                _applyMultiTouchTransform(e.pointer, e.localPosition);
              }
              _activeTouchPositions[e.pointer] = e.localPosition;
              return;
            }
            _activeTouchPositions[e.pointer] = e.localPosition;
          }
          if (!_toolHandledPointers.contains(e.pointer)) return;
          _onPointerMove(e);
        },
        onPointerUp: (e) {
          MultiTouchTapKind? completedTap;
          if (e.kind == PointerDeviceKind.touch) {
            _touchCount = (_touchCount - 1).clamp(0, 10);
            _activeTouchPositions.remove(e.pointer);
            completedTap = _multiTouchTapTracker.pointerUp(
              e.pointer,
              DateTime.now(),
            );
            // 全ての指が離れて初めて、次のタッチを新規の描画として扱えるように戻す。
            if (_activeTouchPositions.isEmpty) _touchTransformActive = false;
          }
          if (completedTap == MultiTouchTapKind.twoFinger) {
            _handleGesture(context, settings.twoFingerTap);
          } else if (completedTap == MultiTouchTapKind.threeFinger) {
            _handleGesture(context, settings.threeFingerTap);
          }
          if (!_toolHandledPointers.remove(e.pointer)) return;
          _onPointerUp(e);
        },
        onPointerCancel: (e) {
          if (e.kind == PointerDeviceKind.touch) {
            _touchCount = (_touchCount - 1).clamp(0, 10);
            _activeTouchPositions.remove(e.pointer);
            _multiTouchTapTracker.pointerCancel(e.pointer);
            if (_activeTouchPositions.isEmpty) _touchTransformActive = false;
          }
          _disarmHoldEyedropper(e.pointer);
          _toolHandledPointers.remove(e.pointer);
        },
        onPointerSignal: _handlePointerSignal,
        // Flutter標準のInteractiveViewerは回転ジェスチャーに対応していない
        // ため、上のonPointerDown/Move/Upで独自にパン・ピンチズーム・回転を
        // 計算し、_transformControllerの値を直接更新してTransformで反映する
        // （挙動はInteractiveViewer(constrained:true・既定のClip.hardEdge)
        // と同等）。
        child: AnimatedBuilder(
          animation: _transformController,
          builder: (context, _) => ClipRect(
            child: Transform(
              transform: _transformController.value,
              // 低スペック端末対策：キャンバスの再描画を他ウィジェットから分離し、
              // ストローク中の再描画コストを最小限に抑える。
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CanvasPainter(
                    project: widget.project,
                    background: widget.background,
                    transform: _transformController.value,
                    compositeImage: _compositeImage,
                    belowImage: _belowImage,
                    aboveImage: _aboveImage,
                    currentLayerOpacity:
                        _layers
                            .where((l) => l.id == _layerId)
                            .firstOrNull
                            ?.opacity ??
                        100,
                    currentLayerBlendMode:
                        _layers
                            .where((l) => l.id == _layerId)
                            .firstOrNull
                            ?.blendMode ??
                        LayerBlendMode.normal,
                    onionImages: _onionImagesView,
                    onionSettings: widget.onionSkinSettings,
                    onionEngine: _onionSkinEngine,
                    selectionStart: _selectionStart,
                    selectionEnd: _selectionEnd,
                    // 変形操作中は移動前の位置のハイライトが紛らわしいため非表示にする
                    // （ハンドル・浮動画像プレビューの方で現在の状態を示す）。
                    selectionOverlayImage: _selectionTransformActive
                        ? null
                        : _selectionOverlayImage,
                    selectionLayerOverlayImage: _selectionLayerOverlayImage,
                    lassoPoints: _lassoPoints,
                    subToolStrokePoints: _subToolStrokePoints,
                    activeRuler: widget.activeRuler,
                    shapeKind: widget.shapeKind,
                    shapeStart: _shapeStart,
                    shapeEnd: _shapeEnd,
                    moveDelta: widget.currentTool == DrawingTool.move
                        ? _moveDelta
                        : null,
                    floatingSelectionImage: _floatingSelectionImage,
                    selectionTransformLive: _selectionTransformLive,
                    selectionTransformBounds: _selectionTransformBounds,
                    // 選択範囲がある間は、掴む前からハンドルを描いておく
                    // （何ができるか画面に出ていないと使われないため）。
                    // 変形中は上のselectionTransformBoundsの枠を描くので出さない。
                    selectionAffordanceBounds:
                        _isSelectionTool && !_selectionTransformActive
                        ? _selectionMaskBounds()
                        : null,
                    meshRows: meshRows,
                    meshCols: meshCols,
                    meshControlPoints: meshControlPoints,
                    meshSourceImage: meshSourceImage,
                    showMeshHandles:
                        widget.currentTool == DrawingTool.meshTransform,
                    handleColor: theme.selectionColor,
                    handleOutlineColor: theme.menuBgColor,
                    extendedAreaWarningColor: theme.updateMarkColor,
                    viewTransform: _transformController.value,
                  ),
                  foregroundPainter: _PixelGridPainter(
                    project: widget.project,
                    enabled: pixelBrushActive,
                    color: theme.textColor,
                    viewTransform: _transformController.value,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleGesture(BuildContext context, GestureAction action) {
    final undoManager = context.read<app_undo.UndoManager>();
    switch (action) {
      case GestureAction.undo:
        undoManager.undo();
      case GestureAction.redo:
        undoManager.redo();
      case GestureAction.eyedropper:
        // スポイトは次のタップ座標が必要なため、ツールをスポイトへ直接切り替える
        widget.onGestureToolChange?.call(DrawingTool.eyedropper);
      case GestureAction.eraserToggle:
        widget.onGestureToggleTool?.call(DrawingTool.eraser);
      case GestureAction.brushToggle:
        widget.onGestureToggleTool?.call(DrawingTool.pen);
      case GestureAction.panTool:
        widget.onGestureToggleTool?.call(DrawingTool.pan);
      case GestureAction.nextTool:
        widget.onNextQuickTool?.call();
      case GestureAction.onionSkinToggle:
        widget.onToggleOnionSkin?.call();
      case GestureAction.frameMove:
        // 2本指スワイプ専用の連続操作を想定した機能のため、単発ジェスチャー／
        // ペンボタンからの割り当ては未対応
        break;
      case GestureAction.none:
        break;
    }
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────

/// Screen-only one-project-pixel grid for pixel-mode brushes. It is attached
/// as CustomPaint.foregroundPainter, so it never enters tiles, previews,
/// thumbnails, or exports.
class _PixelGridPainter extends CustomPainter {
  final Project? project;
  final bool enabled;
  final Color color;
  final Matrix4 viewTransform;

  const _PixelGridPainter({
    required this.project,
    required this.enabled,
    required this.color,
    required this.viewTransform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final drawingRect = canvasDrawingRectFor(size, project);
    final canvasPx = canvasPixelSizeOf(project);
    if (drawingRect.isEmpty || canvasPx.width <= 0 || canvasPx.height <= 0) {
      return;
    }
    final stepX = drawingRect.width / canvasPx.width;
    final stepY = drawingRect.height / canvasPx.height;
    final zoom = viewTransform.getMaxScaleOnAxis();
    final pixelScreenSize = math.min(stepX, stepY) * zoom;
    if (!shouldPaintPixelGrid(pixelScreenSize)) return;

    final visible = visibleWidgetRectFor(
      size,
      viewTransform,
    ).intersect(drawingRect);
    if (visible.isEmpty) return;
    final startX = math.max(
      0,
      ((visible.left - drawingRect.left) / stepX).floor(),
    );
    final endX = math.min(
      canvasPx.width.round(),
      ((visible.right - drawingRect.left) / stepX).ceil(),
    );
    final startY = math.max(
      0,
      ((visible.top - drawingRect.top) / stepY).floor(),
    );
    final endY = math.min(
      canvasPx.height.round(),
      ((visible.bottom - drawingRect.top) / stepY).ceil(),
    );

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65 / math.max(zoom, 0.001)
      ..isAntiAlias = false;

    canvas.save();
    canvas.clipRect(drawingRect);
    for (int x = startX; x <= endX; x++) {
      final px = drawingRect.left + x * stepX;
      canvas.drawLine(
        Offset(px, drawingRect.top),
        Offset(px, drawingRect.bottom),
        gridPaint,
      );
    }
    for (int y = startY; y <= endY; y++) {
      final py = drawingRect.top + y * stepY;
      canvas.drawLine(
        Offset(drawingRect.left, py),
        Offset(drawingRect.right, py),
        gridPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) =>
      oldDelegate.enabled != enabled ||
      oldDelegate.project != project ||
      oldDelegate.color != color ||
      oldDelegate.viewTransform != viewTransform;
}

class _CanvasPainter extends CustomPainter {
  final Project? project;
  final CanvasBackground background;
  final Matrix4 transform;
  final ui.Image? compositeImage;
  final ui.Image? belowImage;
  final ui.Image? aboveImage;
  final int currentLayerOpacity;
  final LayerBlendMode currentLayerBlendMode;
  final Map<int, ui.Image> onionImages;
  final OnionSkinSettings onionSettings;
  final OnionSkinEngine onionEngine;
  final Offset? selectionStart;
  final Offset? selectionEnd;
  final ui.Image? selectionOverlayImage;
  // 「選択レイヤー」（LayerType.selection、眼鏡断層フィルター等のマスク
  // 専用レイヤー）の内容。通常の合成（LayerCompositor.pixelLayerTypes）
  // からは除外され最終成果物には写り込まないが、除外したままだと塗って
  // いる最中に何も見えず実用にならないため、専用のオーバーレイとして
  // 常に最前面（選択ツールの確定範囲表示より手前）へ、テーマの選択色
  // （handleColorと同じ、色固定を廃止している）でタイントして重ねる。
  final ui.Image? selectionLayerOverlayImage;
  final List<Offset> lassoPoints;
  final List<Offset> subToolStrokePoints;
  final Ruler? activeRuler;
  final ShapeKind shapeKind;
  final Offset? shapeStart;
  final Offset? shapeEnd;
  final Offset? moveDelta;
  // 選択ツールの移動・回転・拡大縮小：ドラッグ中は選択範囲の
  // 中身を切り取った「浮動画像」をコミット前のプレビューとして表示する。
  final ui.Image? floatingSelectionImage;
  final Matrix4? selectionTransformLive;
  final Rect? selectionTransformBounds;

  /// 選択範囲がある間、常時描く操作ハンドルの基準矩形。
  /// 四隅＝拡大縮小、中央＝移動、右上の外側＝回転。
  final Rect? selectionAffordanceBounds;
  // レイヤー全体の自由変形・メッシュ変形（新機能）：ワープ元画像・格子点は
  // ライブプレビューの描画に、showMeshHandlesは格子線・ハンドルの表示要否に使う。
  final int meshRows;
  final int meshCols;
  final List<Offset>? meshControlPoints;
  final ui.Image? meshSourceImage;
  final bool showMeshHandles;
  // 選択範囲・変形ハンドル・定規ハンドルの色（テーマの選択色連動、
  // 色固定を廃止している）。キャンバス内容は任意の絵柄になり得るため、
  // ハンドル自体の縁取りにはテーマのメニュー背景色を使い、内容色に
  // 埋もれないコントラストを確保する。
  final Color handleColor;
  final Color handleOutlineColor;
  // 「書き出し範囲外」の警告枠色（テーマの更新マーク色連動）。
  final Color extendedAreaWarningColor;
  // いまのピンチズーム・パンの行列。回転ハンドルを「指が届く範囲」の内側へ
  // 寄せる計算に使う（縮小すれば余白が増え、拡大すれば減るため）。
  final Matrix4 viewTransform;

  static const double _checkerSize = 16.0;

  const _CanvasPainter({
    required this.background,
    required this.transform,
    required this.onionImages,
    required this.onionSettings,
    required this.onionEngine,
    required this.lassoPoints,
    this.subToolStrokePoints = const [],
    this.project,
    this.compositeImage,
    this.belowImage,
    this.aboveImage,
    this.currentLayerOpacity = 100,
    this.currentLayerBlendMode = LayerBlendMode.normal,
    this.selectionStart,
    this.selectionEnd,
    this.selectionOverlayImage,
    this.selectionLayerOverlayImage,
    this.activeRuler,
    this.shapeKind = ShapeKind.off,
    this.shapeStart,
    this.shapeEnd,
    this.moveDelta,
    this.floatingSelectionImage,
    this.selectionTransformLive,
    this.selectionTransformBounds,
    this.selectionAffordanceBounds,
    this.meshRows = 1,
    this.meshCols = 1,
    this.meshControlPoints,
    this.meshSourceImage,
    this.showMeshHandles = false,
    required this.handleColor,
    required this.handleOutlineColor,
    required this.extendedAreaWarningColor,
    required this.viewTransform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ポインター座標→プロジェクトピクセル座標への変換
    // （_CanvasAreaState._widgetLocalToCanvasPixel）と同じ計算元を使う。
    final drawingRect = canvasDrawingRectFor(size, project);

    // 「枠外」の塗りつぶしは、この描画全体を包む親側（canvas_screen.dart）が
    // 固定背景（kCanvasOutsideColor）として1枚だけ敷いている。ここで
    // 重ねて塗ると背景が二重になり、ピンチズームでキャンバス内容ごと
    // 縮小されるこの塗りの方だけが一緒に縮んで見た目がちぐはぐになるため、
    // ここでは描画内容（drawingRect）だけを塗り、枠外は透明のままにして
    // 親の固定背景をそのまま透過させる。
    _paintBackground(canvas, drawingRect);

    // 現在レイヤーより奥（背面）のレイヤー群
    _drawFrameImage(canvas, drawingRect, belowImage, Paint());

    // オニオンスキン（前フレーム）
    for (final entry in onionImages.entries) {
      if (entry.key >= 0) continue;
      _drawOnionFrame(canvas, drawingRect, entry.value, entry.key);
    }

    // 現在レイヤー（不透明度・ブレンドモードを反映）
    if (meshSourceImage != null && meshControlPoints != null) {
      // レイヤー全体の自由変形・メッシュ変形：ドラッグ中はコミット前の
      // ワーププレビューとして、通常のcompositeImageの代わりにワープ元画像を
      // ui.Vertices（三角形メッシュ・テクスチャ座標付き）で描画する。
      final meshCurrentPaint = Paint()
        ..color = Color.fromARGB(
          (currentLayerOpacity.clamp(0, 100) * 255 / 100).round(),
          255,
          255,
          255,
        )
        ..blendMode = mapLayerBlendMode(currentLayerBlendMode);
      final sx = drawingRect.width / meshSourceImage!.width;
      final sy = drawingRect.height / meshSourceImage!.height;
      canvas.save();
      canvas.translate(drawingRect.left, drawingRect.top);
      canvas.scale(sx, sy);
      final vertices = MeshWarpEngine.buildVertices(
        image: meshSourceImage!,
        rows: meshRows,
        cols: meshCols,
        controlPoints: meshControlPoints!,
      );
      meshCurrentPaint.shader = ui.ImageShader(
        meshSourceImage!,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        MeshWarpEngine.identityMatrix4,
        filterQuality: ui.FilterQuality.low,
      );
      canvas.drawVertices(vertices, BlendMode.srcOver, meshCurrentPaint);
      canvas.restore();
    } else if (compositeImage != null) {
      final currentPaint = Paint()
        ..color = Color.fromARGB(
          (currentLayerOpacity.clamp(0, 100) * 255 / 100).round(),
          255,
          255,
          255,
        )
        ..blendMode = mapLayerBlendMode(currentLayerBlendMode);
      final sx = drawingRect.width / compositeImage!.width;
      final sy = drawingRect.height / compositeImage!.height;
      if (moveDelta != null) {
        // 移動ツール：ドラッグ中はコミット前のプレビューとして表示する
        canvas.save();
        canvas.translate(drawingRect.left, drawingRect.top);
        canvas.scale(sx, sy);
        canvas.translate(moveDelta!.dx, moveDelta!.dy);
        canvas.drawImage(compositeImage!, Offset.zero, currentPaint);
        canvas.restore();
      } else {
        final src = Rect.fromLTWH(
          0,
          0,
          compositeImage!.width.toDouble(),
          compositeImage!.height.toDouble(),
        );
        canvas.drawImageRect(compositeImage!, src, drawingRect, currentPaint);
      }
    }

    // 選択ツールの移動・回転・拡大縮小：ドラッグ中の浮動選択画像プレビュー
    // （元レイヤーは既に選択範囲が透明化された状態で上のcompositeImageに
    // 反映済みのため、その上に変形後の位置で重ねて描く）。
    if (floatingSelectionImage != null) {
      final sx = drawingRect.width / floatingSelectionImage!.width;
      final sy = drawingRect.height / floatingSelectionImage!.height;
      canvas.save();
      canvas.translate(drawingRect.left, drawingRect.top);
      canvas.scale(sx, sy);
      if (selectionTransformLive != null) {
        canvas.transform(selectionTransformLive!.storage);
      }
      canvas.drawImage(floatingSelectionImage!, Offset.zero, Paint());
      canvas.restore();
    }

    // オニオンスキン（後フレーム）
    for (final entry in onionImages.entries) {
      if (entry.key <= 0) continue;
      _drawOnionFrame(canvas, drawingRect, entry.value, entry.key);
    }

    // 現在レイヤーより手前（前面）のレイヤー群
    _drawFrameImage(canvas, drawingRect, aboveImage, Paint());

    // 選択レイヤー（内容そのものは最終成果物に含まれないマスク専用
    // レイヤーのため、通常合成には含めず、常にテーマの選択色で半透明
    // タイントして最前面付近へ重ねる。BlendMode.srcInで画像のアルファ形状
    // はそのまま、色だけをタイント色（透明度50%）へ置き換える）。
    if (selectionLayerOverlayImage != null) {
      final tintPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          handleColor.withValues(alpha: 0.5),
          BlendMode.srcIn,
        );
      _drawFrameImage(
        canvas,
        drawingRect,
        selectionLayerOverlayImage,
        tintPaint,
      );
    }

    // 確定済み選択範囲（矩形選択・投げ縄選択・自動選択で共通）
    if (selectionOverlayImage != null) {
      _drawFrameImage(canvas, drawingRect, selectionOverlayImage, Paint());
    }

    // 矩形選択プレビュー
    if (selectionStart != null && selectionEnd != null) {
      final canvasPx = canvasPixelSizeOf(project);
      final sx = drawingRect.width / canvasPx.width;
      final sy = drawingRect.height / canvasPx.height;
      final r = Rect.fromPoints(
        drawingRect.topLeft +
            Offset(selectionStart!.dx * sx, selectionStart!.dy * sy),
        drawingRect.topLeft +
            Offset(selectionEnd!.dx * sx, selectionEnd!.dy * sy),
      );
      canvas.drawRect(r, Paint()..color = handleColor.withValues(alpha: 0.2));
      canvas.drawRect(
        r,
        Paint()
          ..color = handleColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // 投げ縄選択プレビュー
    if (lassoPoints.length > 1) {
      final canvasPx = canvasPixelSizeOf(project);
      final sx = drawingRect.width / canvasPx.width;
      final sy = drawingRect.height / canvasPx.height;
      final path = Path();
      path.moveTo(
        drawingRect.left + lassoPoints.first.dx * sx,
        drawingRect.top + lassoPoints.first.dy * sy,
      );
      for (final p in lassoPoints.skip(1)) {
        path.lineTo(drawingRect.left + p.dx * sx, drawingRect.top + p.dy * sy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = handleColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // トーン自由描画・スタンプのストロークプレビュー（確定は指を離した時点）
    if (subToolStrokePoints.length > 1) {
      final canvasPx = canvasPixelSizeOf(project);
      final sx = drawingRect.width / canvasPx.width;
      final sy = drawingRect.height / canvasPx.height;
      final path = Path();
      path.moveTo(
        drawingRect.left + subToolStrokePoints.first.dx * sx,
        drawingRect.top + subToolStrokePoints.first.dy * sy,
      );
      for (final p in subToolStrokePoints.skip(1)) {
        path.lineTo(drawingRect.left + p.dx * sx, drawingRect.top + p.dy * sy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = ThemeService.activeColorScheme.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // 図形ツール：ゴムバンドプレビュー（指を離すまで確定しない）
    if (shapeStart != null && shapeEnd != null && shapeKind != ShapeKind.off) {
      final canvasPx = canvasPixelSizeOf(project);
      final sx = drawingRect.width / canvasPx.width;
      final sy = drawingRect.height / canvasPx.height;
      Offset ts(Offset p) => drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
      final shapePaint = Paint()
        ..color = ThemeService.activeColorScheme.onSurface.withValues(
          alpha: 0.87,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      switch (shapeKind) {
        case ShapeKind.line:
          canvas.drawLine(ts(shapeStart!), ts(shapeEnd!), shapePaint);
        case ShapeKind.rect:
          canvas.drawRect(
            Rect.fromPoints(ts(shapeStart!), ts(shapeEnd!)),
            shapePaint,
          );
        case ShapeKind.circle:
          canvas.drawOval(
            Rect.fromPoints(ts(shapeStart!), ts(shapeEnd!)),
            shapePaint,
          );
        case ShapeKind.off:
          break;
      }
    }

    // レイヤー全体の自由変形・メッシュ変形：格子線・各格子点のドラッグハンドル
    if (showMeshHandles &&
        meshControlPoints != null &&
        meshSourceImage != null) {
      final points = meshControlPoints!;
      final gsx = drawingRect.width / meshSourceImage!.width;
      final gsy = drawingRect.height / meshSourceImage!.height;
      Offset gts(Offset p) =>
          drawingRect.topLeft + Offset(p.dx * gsx, p.dy * gsy);
      final gridPaint = Paint()
        ..color = handleColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      int idxAt(int r, int c) => r * (meshCols + 1) + c;
      for (int r = 0; r <= meshRows; r++) {
        for (int c = 0; c <= meshCols; c++) {
          final p = gts(points[idxAt(r, c)]);
          if (c < meshCols) {
            canvas.drawLine(p, gts(points[idxAt(r, c + 1)]), gridPaint);
          }
          if (r < meshRows) {
            canvas.drawLine(p, gts(points[idxAt(r + 1, c)]), gridPaint);
          }
        }
      }
      for (final p in points) {
        final hp = gts(p);
        canvas.drawCircle(
          hp,
          8,
          Paint()..color = handleColor.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          hp,
          8,
          Paint()
            ..color = handleOutlineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // 選択範囲がある間、常時出す操作ハンドル。
    // 四隅＝拡大縮小（四角）、中央＝移動（十字矢印）、右上の外側＝回転
    // （カーブした矢印）。掴む前から見えていないと「何ができるのか」が
    // 分からないため、ドラッグ中でなくても描く。
    if (selectionAffordanceBounds != null) {
      final bounds = selectionAffordanceBounds!;
      final canvasPx = canvasPixelSizeOf(project);
      final sx = drawingRect.width / canvasPx.width;
      final sy = drawingRect.height / canvasPx.height;
      Offset ts(Offset p) => drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
      // ハンドルの大きさは画面px基準で固定。キャンバスpxへは
      // 描画エリアの拡大率で割って戻す（当たり判定側と同じ式）。
      final r = selectionHandleRadiusFor(sx);
      const screenR = kSelectionHandleScreenRadius;

      canvas.drawRect(
        Rect.fromPoints(ts(bounds.topLeft), ts(bounds.bottomRight)),
        Paint()
          ..color = handleColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // 四隅：拡大縮小用の四角いハンドル。
      for (final corner in selectionScaleHandlesOf(bounds)) {
        final rect = Rect.fromCenter(
          center: ts(corner),
          width: screenR * 2,
          height: screenR * 2,
        );
        canvas.drawRect(rect, Paint()..color = handleColor);
        canvas.drawRect(
          rect,
          Paint()
            ..color = handleOutlineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      // 中央：移動用の十字矢印。右上の外側：回転用のカーブした矢印。
      void iconHandle(Offset center, IconData icon, double radius) {
        canvas.drawCircle(center, radius, Paint()..color = handleColor);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = handleOutlineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: radius * 1.5,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: handleOutlineColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          center - Offset(painter.width / 2, painter.height / 2),
        );
      }

      iconHandle(ts(bounds.center), Icons.open_with, screenR + 2);
      iconHandle(
        ts(
          selectionRotateHandleOf(
            bounds,
            r,
            rotateRadius: selectionRotateHandleRadiusFor(sx),
            reachable: reachableCanvasRectFor(
              visibleWidgetRectFor(size, viewTransform),
              drawingRect,
              project,
            ),
          ),
        ),
        Icons.rotate_right,
        kSelectionRotateHandleScreenRadius,
      );
    }

    // 変形中：選択範囲のバウンディングボックス・拡縮ハンドル・回転ハンドル。
    if (selectionTransformBounds != null) {
      final bounds = selectionTransformBounds!;
      final canvasPx = canvasPixelSizeOf(project);
      final sx = drawingRect.width / canvasPx.width;
      final sy = drawingRect.height / canvasPx.height;
      Offset ts(Offset p) => drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
      final boxPaint = Paint()
        ..color = handleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(
        Rect.fromPoints(ts(bounds.topLeft), ts(bounds.bottomRight)),
        boxPaint,
      );
      void handle(Offset p) {
        canvas.drawCircle(
          p,
          8,
          Paint()..color = handleColor.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          p,
          8,
          Paint()
            ..color = handleOutlineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      handle(ts(bounds.bottomRight)); // 拡縮ハンドル
      handle(ts(Offset(bounds.center.dx, bounds.top - 40))); // 回転ハンドル
    }

    // 拡張表示範囲ON時のみ、実際に書き出される範囲（拡張前のアスペクト比
    // フィット矩形）を警告枠として重ねる。
    if (project?.hasExtendedDrawingArea ?? false) {
      final exportRect = exportWarningRectFor(drawingRect, project);
      canvas.drawRect(
        exportRect,
        Paint()
          ..color = extendedAreaWarningColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 定規オーバーレイ
    _paintRuler(canvas, size, drawingRect);
  }

  void _paintRuler(Canvas canvas, Size size, Rect drawingRect) {
    final r = activeRuler;
    if (r == null || !r.isVisible) return;
    final paint = Paint()
      ..color = handleColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final canvasPx = canvasPixelSizeOf(project);
    final cw = canvasPx.width;
    final ch = canvasPx.height;
    final sx = drawingRect.width / cw;
    final sy = drawingRect.height / ch;
    Offset ts(Offset p) => drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
    void handle(Offset p) {
      canvas.drawCircle(
        p,
        6,
        Paint()..color = handleColor.withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        p,
        6,
        Paint()
          ..color = handleOutlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    switch (r.type) {
      case RulerType.line:
        final c = ts(r.position);
        final len = size.longestSide;
        final dir = Offset.fromDirection(r.rotation, len);
        canvas.drawLine(c - dir, c + dir, paint);
        handle(c);
        handle(ts(r.position) + Offset.fromDirection(r.rotation, 220 * sx));
      case RulerType.ellipse:
        final rx = (r.settings.radiusX ?? 200) * sx;
        final ry = (r.settings.radiusY ?? 120) * sy;
        final c = ts(r.position);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(r.rotation);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
          paint,
        );
        canvas.restore();
        handle(c);
        handle(c + _rotateOffset(Offset(rx, 0), r.rotation));
        handle(c + _rotateOffset(Offset(0, ry), r.rotation));
        handle(c + _rotateOffset(Offset(rx + 50 * sx, 0), r.rotation));
      case RulerType.radial:
        final divs = r.settings.divisions ?? 12;
        final c = ts(r.position);
        final len = size.longestSide;
        for (int i = 0; i < divs; i++) {
          final a = (i / divs) * 3.14159265 * 2 + r.rotation;
          canvas.drawLine(c, c + Offset.fromDirection(a, len), paint);
        }
        handle(c);
        handle(c + Offset.fromDirection(r.rotation, 160 * sx));
      case RulerType.onePointPerspective:
        final vp = ts(r.settings.vanishingPoint1 ?? r.position);
        for (int i = 0; i <= 8; i++) {
          final t = i / 8.0;
          canvas.drawLine(
            vp,
            Offset(size.width * t, i.isEven ? 0 : size.height),
            paint,
          );
        }
        handle(vp);
      case RulerType.twoPointPerspective:
        for (final vpp in [
          r.settings.vanishingPoint1 ?? const Offset(200, 540),
          r.settings.vanishingPoint2 ?? const Offset(1720, 540),
        ]) {
          final vp = ts(vpp);
          for (int i = 0; i <= 6; i++) {
            canvas.drawLine(
              vp,
              Offset(size.width * (i / 6.0), i.isEven ? 0 : size.height),
              paint,
            );
          }
          handle(vp);
        }
      case RulerType.threePointPerspective:
        for (final vpp in [
          r.settings.vanishingPoint1 ?? const Offset(200, 540),
          r.settings.vanishingPoint2 ?? const Offset(1720, 540),
          r.settings.vanishingPoint3 ?? const Offset(960, 100),
        ]) {
          final vp = ts(vpp);
          for (int i = 0; i <= 4; i++) {
            canvas.drawLine(
              vp,
              Offset(size.width * (i / 4.0), i.isEven ? 0 : size.height),
              paint,
            );
          }
          handle(vp);
        }
      case RulerType.circle:
        break;
    }
  }

  Offset _rotateOffset(Offset v, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// belowImage/aboveImage（フレーム全体サイズの合成済み画像）を描画領域へ
  /// スケールして描画する。不透明度・ブレンドモードは合成時に既に各レイヤーへ
  /// 適用済みのため、ここではスケーリングのみ行う。
  void _drawFrameImage(
    Canvas canvas,
    Rect drawingRect,
    ui.Image? image,
    Paint paint,
  ) {
    if (image == null) return;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, drawingRect, paint);
  }

  void _drawOnionFrame(
    Canvas canvas,
    Rect drawingRect,
    ui.Image img,
    int offset,
  ) {
    final opacity = onionEngine.getOpacityForFrame(onionSettings, offset);
    final color = onionEngine.getColorForFrame(onionSettings, offset);
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    canvas.drawImageRect(
      img,
      src,
      drawingRect,
      Paint()
        ..colorFilter = ui.ColorFilter.mode(
          color.withValues(alpha: opacity),
          BlendMode.srcATop,
        ),
    );
  }

  void _paintBackground(Canvas canvas, Rect rect) {
    if (background == CanvasBackground.white) {
      // 新規プロジェクト作成画面で選択した背景色（Project.backgroundColor）
      // をキャンバス表示にも反映する（export_screen.dartの書き出し処理も
      // 同じくproject.backgroundColorを参照しており、表示・書き出しの
      // 両方で設定が一致する）。
      final color = project != null
          ? Color(project!.backgroundColor)
          : ThemeService.activeColorScheme.onSurface;
      canvas.drawRect(rect, Paint()..color = color);
    } else {
      _paintChecker(canvas, rect);
    }
  }

  void _paintChecker(Canvas canvas, Rect rect) {
    final rawX = transform.getTranslation().x % _checkerSize;
    final rawY = transform.getTranslation().y % _checkerSize;
    final offsetX = rawX < 0 ? rawX + _checkerSize : rawX;
    final offsetY = rawY < 0 ? rawY + _checkerSize : rawY;
    final modX =
        ((rect.left - offsetX) % _checkerSize + _checkerSize) % _checkerSize;
    final modY =
        ((rect.top - offsetY) % _checkerSize + _checkerSize) % _checkerSize;
    final startX = rect.left - modX;
    final startY = rect.top - modY;
    final cols = ((rect.right - startX) / _checkerSize).ceil() + 1;
    final rows = ((rect.bottom - startY) / _checkerSize).ceil() + 1;
    final gridCol0 = ((startX - offsetX) / _checkerSize).round();
    final gridRow0 = ((startY - offsetY) / _checkerSize).round();
    canvas.save();
    canvas.clipRect(rect);
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            startX + col * _checkerSize,
            startY + row * _checkerSize,
            _checkerSize,
            _checkerSize,
          ),
          Paint()
            ..color = ((gridRow0 + row) + (gridCol0 + col)).isEven
                ? const Color.fromARGB(255, 242, 242, 242)
                : const Color.fromARGB(255, 167, 167, 167),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.compositeImage != compositeImage ||
      old.belowImage != belowImage ||
      old.aboveImage != aboveImage ||
      old.currentLayerOpacity != currentLayerOpacity ||
      old.currentLayerBlendMode != currentLayerBlendMode ||
      old.background != background ||
      // project.backgroundColorの変更がキャンバスへ反映されない不具合の
      // 原因（projectがshouldRepaintの比較対象から漏れていたため、背景色
      // だけが変わっても再描画がスキップされていた）。
      old.project?.backgroundColor != project?.backgroundColor ||
      old.transform != transform ||
      old.onionImages != onionImages ||
      old.selectionStart != selectionStart ||
      old.selectionEnd != selectionEnd ||
      old.selectionOverlayImage != selectionOverlayImage ||
      old.selectionLayerOverlayImage != selectionLayerOverlayImage ||
      old.lassoPoints != lassoPoints ||
      old.subToolStrokePoints != subToolStrokePoints ||
      old.activeRuler != activeRuler ||
      old.shapeKind != shapeKind ||
      old.shapeStart != shapeStart ||
      old.shapeEnd != shapeEnd ||
      old.moveDelta != moveDelta ||
      old.floatingSelectionImage != floatingSelectionImage ||
      old.selectionTransformLive != selectionTransformLive ||
      old.selectionTransformBounds != selectionTransformBounds ||
      old.selectionAffordanceBounds != selectionAffordanceBounds ||
      old.meshRows != meshRows ||
      old.meshCols != meshCols ||
      old.meshControlPoints != meshControlPoints ||
      old.meshSourceImage != meshSourceImage ||
      old.showMeshHandles != showMeshHandles ||
      old.project?.drawingAreaScale != project?.drawingAreaScale ||
      old.viewTransform != viewTransform ||
      old.project?.exportWidth != project?.exportWidth ||
      old.project?.exportHeight != project?.exportHeight ||
      old.project?.drawingAreaScale != project?.drawingAreaScale ||
      old.handleColor != handleColor ||
      old.handleOutlineColor != handleOutlineColor ||
      old.extendedAreaWarningColor != extendedAreaWarningColor;
}
