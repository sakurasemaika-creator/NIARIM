import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart'
    show
        DragStartBehavior,
        GestureBinding,
        PointerScrollEvent,
        PointerSignalEvent;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../config/accent_text_theme.dart';
import '../../utils/immersive_mode.dart';
import '../../widgets/project_autosave_notice.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/keyframe_preview.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../widgets/pc_workspace.dart';
import '../../widgets/project_duration_limit_dialog.dart';
import '../../services/shortcut_service.dart';
import '../../models/shortcut_binding.dart';
import '../../engine/audio_waveform_service.dart';
import '../../engine/autofill_batch_runner.dart';
import '../../engine/autofill_engine.dart' show AutofillMode;
import '../../engine/camera_engine.dart';
import '../../engine/clip_speed.dart';
import '../../engine/crop_frame.dart';
import '../../engine/export_engine.dart';
import '../../engine/export_audio.dart';
import '../../engine/filter_engine.dart';
import '../../engine/layer_compositor.dart';
import '../../engine/layer_keyframe_engine.dart';
import '../../engine/layer_range_resolver.dart';
import '../../engine/watermark_render.dart';
import '../../engine/tile_manager.dart';
import '../../engine/timeline_material.dart';
import '../../engine/timeline_frame_renderer.dart';
import '../../engine/timeline_video_layer_pixels.dart';
import '../../engine/timeline_video_time.dart';
import '../../engine/video_frame_decoder.dart';
import '../../engine/video_frame_provider.dart';
import '../../engine/video_material_snapshot.dart';
import '../../engine/timeline_stack.dart';
import '../../engine/undo_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_clip.dart';
import '../../models/camera_keyframe.dart';
import '../../models/effect_filter_instance.dart';
import '../../models/filter_def.dart'
    show AuroraHologramPreset, ToneCurvePreset, kPixelArtMaxBlockSize;
import '../../models/layer.dart';
import '../../models/video_track_display.dart';
import '../../models/layer_group.dart';
import '../../models/timeline_marker.dart';
import '../../models/material_asset.dart';
import '../../models/pixel_color_mode.dart';
import '../../models/project.dart';
import '../../models/scene.dart';
import '../../models/timeline_row_kind.dart';
import '../../models/watermark_asset.dart';
import '../../models/custom_automation.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/material_service.dart';
import '../../services/android_tts_service.dart';
import '../../utils/making_strings.dart';
import '../../utils/color_contrast.dart';
import '../../services/premium_service.dart';
import '../../services/custom_automation_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../services/settings_service.dart';
import '../../services/theme_service.dart';
import '../../services/tone_service.dart';
import '../../services/watermark_service.dart';
import '../canvas/widgets/canvas_icon_button.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/layer_range_dialog.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/first_use_tooltip.dart';
import '../../widgets/frame_preview_background.dart';
import '../../widgets/pixel_color_mode_selector.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/progress_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../../utils/duplicate_name.dart';
import '../../utils/reorder_index.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../widgets/custom_automation_manager_sheet.dart';
import '../../widgets/custom_automation_draft_sheet.dart';
import '../../widgets/typing_aware_shortcuts.dart';
import '../../widgets/typing_dialog_inset.dart';
import 'widgets/clip_speed_control.dart';
import 'widgets/keyframe_retime_dialog.dart';
import 'widgets/material_edit_panel.dart';
import 'widgets/video_filmstrip.dart';
import 'widgets/material_gizmo.dart';
import 'widgets/material_region_controller.dart';
import 'widgets/stack_order_panel.dart';
import 'widgets/track_label.dart';
import '../../widgets/icon_notice.dart';
import '../../widgets/menu_surface.dart';

// タイムライントラッククリップ
enum _ClipTrackType { audio, video, image, text }

enum _PcTimelineArea { bin, monitor, inspector, tracks }

enum _TimelineToolbarAction { watermark, readAloud }

enum _TimelineSelection { scenes, frames, clips }

/// The colour of text clips on the timeline (amber, apart from the theme's
/// colours that video, image and audio clips use).
const Color _textClipColor = Color(0xFFE09A2C);

/// The kind of timeline row a clip of [type] sits on.
TimelineRowKind _rowKindOf(_ClipTrackType type) => switch (type) {
  _ClipTrackType.audio => TimelineRowKind.audio,
  _ClipTrackType.video => TimelineRowKind.video,
  _ClipTrackType.image => TimelineRowKind.image,
  _ClipTrackType.text => TimelineRowKind.text,
};

// クリップの長押しドラッグ操作の種別。
enum _ClipDragMode { move, resizeLeft, resizeRight }

class _TrackClip {
  final String id;
  String label;
  int startFrame;
  int lengthFrames;
  final Color color;
  final _ClipTrackType trackType;
  // 実ファイルパス（音声・動画の再生位置連動に使用。プロジェクトの
  // Materials/フォルダ内のコピーを指す。MaterialID方式）
  String? filePath;
  // 参照している素材ID
  final String? materialId;
  // 音声
  double volume; // 0.0〜1.0
  double fadeIn; // フェードイン秒数
  double fadeOut; // フェードアウト秒数
  // 動画
  int useStart; // 使用開始フレーム（素材内）
  int useEnd; // 使用終了フレーム（素材内）
  // The fraction of a source frame after useStart where it starts, and the
  // playback speed (both for audio, read-aloud and video).
  double sourceFraction;
  double playbackRate;

  /// Whether a video's sound plays at [playbackRate] too (otherwise at the
  /// normal speed while only the picture changes speed).
  bool soundFollowsSpeed;
  double videoOpacity; // 0.0〜1.0
  // 素材種別ごとに複数行のタイムライン行を追加できるようにするための、
  // このクリップが属する行番号（0始まり）。編集パネルから別の行へ移せる。
  int trackRow;
  final bool isReadAloud;

  _TrackClip({
    required this.id,
    required this.label,
    required this.startFrame,
    required this.lengthFrames,
    required this.color,
    required this.trackType,
    this.filePath,
    this.materialId,
    this.volume = 1.0,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.useStart = 0,
    this.useEnd = 0,
    this.sourceFraction = 0,
    this.playbackRate = 1.0,
    this.soundFollowsSpeed = true,
    this.videoOpacity = 1.0,
    this.trackRow = 0,
    this.isReadAloud = false,
  });

  /// The speed the clip's sound plays at.
  double get soundRate => soundFollowsSpeed ? playbackRate : 1.0;

  /// For a video: how many frames from its start its sound plays (its used
  /// range at [soundRate]); after that the picture holds the last used frame
  /// and the clip is silent, as in the export.
  double get videoSoundingFrames => TimelineVideoTimeMapper.soundingFrames(
    clipLengthFrames: lengthFrames,
    sourceTrimStartFrame: useStart + sourceFraction,
    sourceTrimEndFrame: useEnd,
    soundRate: soundRate,
  );

  /// The source position (in project frames) [elapsedFrames] into the clip.
  SourcePosition sourceAfter(int elapsedFrames) => sourcePositionAfter(
    startFrame: useStart,
    startFraction: sourceFraction,
    elapsedFrames: elapsedFrames,
    rate: playbackRate,
  );
}

/// 音声クリップの帯に薄く重ねる波形サムネイル。[AudioWaveformService]で
/// 生成・キャッシュされたPNGを非同期に読み込んで表示する。生成が未完了の
/// 間・失敗した場合は何も表示しない（プレーンな色帯のままフォールバック）。
class _AudioWaveformThumb extends StatefulWidget {
  final String filePath;
  final String cacheKey;

  /// The source frames the clip plays (its length × its speed, from its
  /// fractional start), so the waveform lines up with what is heard.
  final double sourceStartFrame;
  final double sourceFrames;
  final int fps;

  const _AudioWaveformThumb({
    super.key,
    required this.filePath,
    required this.cacheKey,
    required this.sourceStartFrame,
    required this.sourceFrames,
    required this.fps,
  });

  @override
  State<_AudioWaveformThumb> createState() => _AudioWaveformThumbState();
}

class _AudioWaveformThumbState extends State<_AudioWaveformThumb> {
  late Future<Uint8List?> _future;

  Future<Uint8List?> _load() => AudioWaveformService.getWaveform(
    filePath: widget.filePath,
    cacheKey: widget.cacheKey,
    sourceStartSeconds: widget.sourceStartFrame / widget.fps,
    durationSeconds: widget.sourceFrames / widget.fps,
  );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _AudioWaveformThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.sourceStartFrame != widget.sourceStartFrame ||
        oldWidget.sourceFrames != widget.sourceFrames ||
        oldWidget.fps != widget.fps) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.shrink();
        return Opacity(
          opacity: 0.5,
          child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
        );
      },
    );
  }
}

/// タイムラインの行の名前のうち、言語で決まっているもの（行の名前の欄の幅を
/// 決めるのに使う。利用者が付けた名前は入らなければ「…」）。
@visibleForTesting
List<String> timelineFixedTrackLabels(AppLocalizations l10n) => [
  l10n.timelineFrameTrackLabel,
  l10n.timelineCameraTrackLabel,
  l10n.timelineEndCardTrackLabel,
  l10n.makingReadAloud,
  for (final kind in [
    l10n.timelineMaterialText,
    l10n.projectListMaterialImage,
    l10n.projectListMaterialVideo,
    l10n.projectListMaterialAudio,
  ])
    l10n.timelineTrackRowName(kind, 1),
  for (final type in EffectFilterType.values)
    _EffectFilterSheet._typeLabel(l10n, type),
];

class TimelineScreen extends StatefulWidget {
  final String projectId;
  final String? initialSceneId;
  final int initialFrame;

  const TimelineScreen({
    super.key,
    required this.projectId,
    this.initialSceneId,
    this.initialFrame = 0,
  });

  /// Makes the decoder the previews use for video materials' frames (the
  /// export uses its own per job). Tests replace it.
  @visibleForTesting
  static VideoFrameDecoder Function(Directory workDirectory) videoDecoderFor =
      FfmpegVideoFrameDecoder.ffmpegKit;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  OverlayEntry? _customAutomationRecordingOverlay;
  // 再生位置。再生タイマーはfps間隔（24fpsなら約41ms）でこれを進めるため、
  // ここをただのフィールドにして`setState`で更新すると、そのたびに
  // タイムライン画面のウィジェットツリー全体（フレーム一覧・各トラック・
  // シーンタブ・ツールバー）が作り直される。実際に再生位置へ追従する
  // 必要があるのはプレビューとシークバーだけなので、ValueNotifierにして
  // その2箇所だけ`ValueListenableBuilder`で購読する。
  //
  // 読み書きは従来どおり`_currentFrame`で行える（getter/setter）。
  // 操作系（コマ送り・タップ移動・シーン切替等）は今までどおり
  // `setState(() => _currentFrame = x)`のままでよい。setStateで画面全体を
  // 作り直しても、離散的な操作なら毎フレームのコストにはならない。
  // 再生タイマーだけがsetStateを使わず、この値の更新だけで済ませる。
  final ValueNotifier<int> _currentFrameNotifier = ValueNotifier<int>(0);
  int _historyPreviewRevision = 0;
  // 画面全体のショートカット（再生・コマ送り・取り消し等）を受ける
  // フォーカス。入力欄から抜けたら（Enter・欄の外の押下）ここへ戻す。
  final FocusNode _screenFocus = FocusNode(debugLabel: 'Timeline');

  int get _currentFrame => _currentFrameNotifier.value;
  set _currentFrame(int value) => _currentFrameNotifier.value = value;
  String? _selectedSceneId;
  bool _isPlaying = false;
  // プレビュー再生をループさせるかどうか。既定はON（従来どおり最終フレーム
  // から先頭へ戻って再生し続ける）。OFFの場合は最終フレームで自動停止する。
  final bool _loopEnabled = true;
  // dispose()内でcontext.read<ProjectService>()を呼ぶと、画面が他の
  // ウィジェットツリーの一括破棄に巻き込まれた際（例：GoRouterの
  // go()によるスタック置き換えで前の画面がまとめて破棄されるケース）に
  // 「破棄済みウィジェットの祖先を参照できない」例外になることがある。
  // initState時点（要素がまだ確実にアクティブ）で取得して保持しておき、
  // dispose()ではこちらを使う。
  late final ProjectService _projectService;
  late final int _workTrackingLease;
  Timer? _playTimer;
  // プレビュー全画面化：確認・仕上がりチェックに
  // 集中できるよう、プレビューのみ＋再生コントロールだけを全画面表示する。
  bool _isPreviewFullscreen = false;
  // プレビュー欄のドラッグハンドルで一時的に変更中の高さ（ドラッグ中のみ
  // 使用し、指を離した時点でSettingsServiceへ確定保存してnullへ戻す）。
  double? _previewHeightDragOverride;

  // タイムラインクリップの分割モード。再生ヘッド位置を適用した時点で
  // そのフレームを境に、現在位置を含む全種類のクリップを分割する。
  bool _isSplitMode = false;

  // カーソル固定方式の移動モード
  bool _isMoveMode = false;
  int _moveCursorPos = 0;
  // 移動・複製時のカーソル吹き出しに表示する先頭サムネイル（
  // 先頭のサムネイルのみ実画像を表示する）。シーン移動・フレーム移動で共用する。
  ui.Image? _moveThumbnail;

  // シーンのコピー・切り取り・貼り付け。クリップボードに内容がある間は
  // シーン一覧の三点メニューやCtrl+Vからいつでも貼り付けを開始できる。
  // 貼り付けは既存の移動モードと同じカーソル固定UIを再利用するため、
  // 専用のカーソル位置は持たず_moveCursorPosを共用する。
  ({List<String> ids, bool isCut})? _sceneClipboard;
  bool _isScenePasteMode = false;
  // シーンのカーソルUI（移動または貼り付け）が表示中かどうか。
  bool get _isSceneCursorActive => _isMoveMode || _isScenePasteMode;

  // トラッククリップ
  final List<_TrackClip> _audioClips = [];
  ScrollController? _readAloudScrollController;
  ScrollController get _readAloudScrollCtrl =>
      _readAloudScrollController ??= ScrollController()
        ..addListener(() => _syncFrom(_readAloudScrollController!));
  final List<_TrackClip> _videoClips = [];
  final List<_TrackClip> _imageClips = [];
  final List<_TrackClip> _textClips = [];

  // 素材（テキスト・画像・動画）の編集中は、タイムラインの各トラックの
  // 代わりにプレビューの下へ編集パネルを出す（プレビューを見ながら
  // スライダーやプレビュー上のドラッグで調整できるようにするため。
  // モーダルのシートだとプレビューが隠れる）。重なり順の編集も同じ場所に出す。
  String? _editingMaterialId;
  ({Layer before, UndoManager undo})? _materialDrag;
  bool _showStackOrder = false;
  // 編集中の素材の描かれている範囲（プレビューの枠の位置合わせ用）。
  // 全画素を走査するので、素材か文字が変わったときだけ求め直す。
  Rect? _editingBounds;
  Object? _editingBoundsKey;

  /// Whether the material panel shows its crop: the preview's handles then
  /// move the crop's edges instead of the material.
  bool _cropEditing = false;

  /// The selection and the part being changed in the material panel's
  /// 範囲選択 section, shared with the preview's handles.
  final MaterialRegionController _regionEdit = MaterialRegionController();

  /// Video materials' picture sizes, read from their frames (the crop is of
  /// the part a video's frames are fitted into). A key with a null value is
  /// being read.
  final Map<String, Size?> _videoDisplaySizes = {};

  // クリップの長押しドラッグ（表示開始位置の移動）・端のハンドルドラッグ
  // （使用範囲の変更）用の一時状態。ジェスチャー中は
  // setState()のたびに_buildClipWidget()が再構築されるため、絶対座標の
  // アンカー（ドラッグ開始時点のグローバルX座標・開始フレーム位置・
  // 開始長さ）をStateフィールドとして保持し、毎回そこからの差分で
  // 目標値を再計算する（差分の累積方式だと再構築のたびにリセットされ
  // 正しく動作しないため）。
  String? _draggingClipId;
  _ClipDragMode? _clipDragMode;
  int _clipDragStartFrame = 0;
  int _clipDragStartLength = 0;
  int _clipDragStartUseStart = 0;
  double _clipDragStartFraction = 0;

  // 素材クリップ（動画・音声）の複数選択モード。クリップの長押しは
  // 既に移動ドラッグに使っているため、専用の「選択」ボタンで切り替える。
  bool _isClipMultiSelect = false;
  final Set<String> _selectedClipIds = {};
  // クリップのクリップボード。貼り付け先は常に選択中シーンの現在地
  // （赤枠がついている_currentFrameの位置）で、コピー元シーンが選択中の
  // シーンと異なる場合は貼り付けを行わない（クリップ一覧はシーンごとに
  // 読み込まれるため）。
  ({String sourceSceneId, List<_TrackClip> clips, bool isCut})? _clipClipboard;

  // カメラキーフレームマーカーの長押し不要ドラッグ用の一時状態。持ち方は
  // クリップドラッグと同じアンカー方式だが、ProjectServiceへの反映は
  // ドラッグ終了時の1回のみに留める（ドラッグ中に毎回notifyListeners()
  // すると、プレビューが持つcameraKeyframesの再合成が連続発生し重くなる
  // ため、ローカルStateだけで暫定位置を表示する）。
  int? _draggingCameraKfOriginalFrame;
  int? _draggingCameraKfLiveFrame;
  int _cameraKfDragStartFrame = 0;

  // 音声・動画クリップの再生位置連動
  final Map<String, ap.AudioPlayer> _audioPlayers = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

  // エンドカードトラック：差し替え不可・アプリが無料会員に
  // フレーム幅（px）。フレーム同士は隙間なく詰めて表示するため
  // 左右マージンは0にしている。ピンチイン・ピンチアウトで
  // _frameWidthScaleが変化し、フレーム一覧・各トラックが連動して
  // 拡大縮小される（保存はせずセッション中のみ有効）。
  static const double _frameWBase = 36.0;
  double _frameWidthScale = 1.0;
  double? _pcUpperHeight;
  bool _pcTracksAbove = false;
  final _pcPaneOrder = [
    _PcTimelineArea.bin,
    _PcTimelineArea.monitor,
    _PcTimelineArea.inspector,
  ];
  double _pcBinWidth = 260;
  double _pcInspectorWidth = 340;
  bool _pcShowBin = true;
  bool _pcShowInspector = true;
  double get _frameW => _frameWBase * _frameWidthScale;
  static const double _frameMargin = 0.0;
  double get _cellW => _frameW + _frameMargin * 2;
  double _trackSidePadding(double viewportWidth) =>
      math.max(0.0, (viewportWidth - _cellW) / 2);

  // ピンチズーム用：現在タイムライン上に乗っているポインター位置。
  final Map<int, Offset> _timelinePinchPointers = {};
  double? _timelinePinchStartDistance;
  double? _timelinePinchStartScale;

  void _onTimelinePinchPointerDown(PointerDownEvent e) {
    _timelinePinchPointers[e.pointer] = e.position;
    if (_timelinePinchPointers.length == 2) {
      final pts = _timelinePinchPointers.values.toList();
      _timelinePinchStartDistance = (pts[0] - pts[1]).distance;
      _timelinePinchStartScale = _frameWidthScale;
    }
  }

  void _onTimelinePinchPointerMove(PointerMoveEvent e) {
    if (_timelineDragStartX != null) return;
    if (!_timelinePinchPointers.containsKey(e.pointer)) return;
    _timelinePinchPointers[e.pointer] = e.position;
    if (_timelinePinchPointers.length != 2) return;
    final startDistance = _timelinePinchStartDistance;
    final startScale = _timelinePinchStartScale;
    if (startDistance == null || startDistance <= 0 || startScale == null) {
      return;
    }
    final pts = _timelinePinchPointers.values.toList();
    final distance = (pts[0] - pts[1]).distance;
    final newScale = (startScale * distance / startDistance).clamp(0.6, 2.5);
    if ((newScale - _frameWidthScale).abs() > 0.01) {
      _zoomTimeline(newScale / _frameWidthScale);
    }
  }

  void _onTimelinePinchPointerUp(PointerEvent e) {
    _timelinePinchPointers.remove(e.pointer);
    if (_timelinePinchPointers.length < 2) {
      _timelinePinchStartDistance = null;
      _timelinePinchStartScale = null;
    }
  }

  void _onTimelinePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _timelineDragStartX != null) return;
    final keyboard = HardwareKeyboard.instance;
    if ((keyboard.isControlPressed || keyboard.isMetaPressed) &&
        event.scrollDelta.dy != 0 &&
        isWideScreen(context, listen: false)) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        _zoomTimeline(event.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1);
      });
    } else if (_isFrameCursorActive) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        final delta = event.scrollDelta.dx == 0
            ? event.scrollDelta.dy
            : event.scrollDelta.dx;
        final next = ((_timelineOffset + delta) / _cellW).round();
        _chooseFramePlacement(next.clamp(0, _totalFrames));
      });
    }
  }

  /// 動画・音源トラック1行の高さ（px）。ワークスペース設定の
  /// 「タイムライン表示」（1〜5段階）から決まる。
  double get _materialTrackHeight => SettingsService.trackHeightForLevel(
    context.watch<SettingsService>().timelineTrackHeightLevel,
  );

  // 横スクロール連動
  late final ScrollController _frameScrollCtrl;
  late final ScrollController _audioScrollCtrl;
  late final ScrollController _videoScrollCtrl;
  late final ScrollController _imageScrollCtrl;
  late final ScrollController _textScrollCtrl;
  late final ScrollController _cameraScrollCtrl;
  late final ScrollController _commonLayerScrollCtrl;
  late final ScrollController _effectFilterScrollCtrl;
  bool _syncingScroll = false;
  bool _jumpingTimeline = false;
  bool _followingTimelineScroll = false;
  Timer? _dragScrollTimer;
  double _dragScrollStep = 0;
  VoidCallback? _onDragScroll;
  double? _timelineDragStartX;
  double _timelineDragStartOffset = 0;
  bool _timelineDragScrolled = false;

  double get _timelineOffset =>
      _frameScrollCtrl.positions.singleOrNull?.pixels ?? 0;

  void _startTimelineDrag(double globalX) {
    _stopTimelineDrag(snap: false);
    if (_isPlaying) _togglePlay();
    _timelineDragStartX = globalX;
    _timelineDragStartOffset = _timelineOffset;
    // Stop earlier scrolling activity before taking the drag anchor.
    if (_frameScrollCtrl.hasClients) {
      _jumpTimelineTo(_timelineDragStartOffset);
    }
  }

  double _timelineDragDistance(double globalX) =>
      globalX -
      (_timelineDragStartX ?? globalX) +
      _timelineOffset -
      _timelineDragStartOffset;

  double _timelineScrollStep(double globalX) {
    // The grab point is neutral. Holding the pointer farther away makes
    // the timeline advance faster, even without another pointer event.
    final distance = globalX - (_timelineDragStartX ?? globalX);
    const deadZone = 12.0;
    const fullSpeedDistance = 180.0;
    final strength =
        ((distance.abs() - deadZone) / (fullSpeedDistance - deadZone)).clamp(
          0.0,
          1.0,
        );
    return distance.sign * strength * 14;
  }

  void _updateTimelineDragScroll(double globalX, {VoidCallback? onScroll}) {
    if (_timelineDragStartX == null) return;
    _dragScrollStep = _timelineScrollStep(globalX);
    _onDragScroll = onScroll;
    if (_dragScrollStep == 0) {
      _dragScrollTimer?.cancel();
      _dragScrollTimer = null;
      return;
    }
    _dragScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (!_scrollTimelineDuringDrag(_timelineOffset + _dragScrollStep)) {
        timer.cancel();
        _dragScrollTimer = null;
        return;
      }
      _onDragScroll?.call();
    });
  }

  bool _scrollTimelineDuringDrag(double target) {
    if (!_frameScrollCtrl.hasClients) return false;
    final offset = target.clamp(0.0, _frameScrollCtrl.position.maxScrollExtent);
    final changed = offset != _timelineOffset;
    if (changed) {
      _jumpTimelineTo(offset);
      _timelineDragScrolled = true;
    }
    _followTimelineScroll(append: target > _cellW * (_totalFrames - 1));
    return changed;
  }

  void _stopTimelineDrag({bool snap = true}) {
    _dragScrollTimer?.cancel();
    _dragScrollTimer = null;
    _onDragScroll = null;
    _timelineDragStartX = null;
    if (snap && _timelineDragScrolled) _centerFrameInList();
    _timelineDragScrolled = false;
  }

  // 素材種別ごとに複数行のタイムライン行を追加できるようにするための、
  // 2行目以降の行専用スクロールコントローラー。1行目は既存の
  // _audioScrollCtrl等をそのまま使う。キー形式は'種別名_行番号'。
  final Map<String, ScrollController> _rowScrollCtrls = {};

  ScrollController _rowScrollCtrl(TimelineRowKind type, int rowIndex) {
    if (rowIndex == 0) {
      return switch (type) {
        TimelineRowKind.image => _imageScrollCtrl,
        TimelineRowKind.video => _videoScrollCtrl,
        TimelineRowKind.audio => _audioScrollCtrl,
        TimelineRowKind.text => _textScrollCtrl,
      };
    }
    final key = '${type.name}_$rowIndex';
    return _rowScrollCtrls.putIfAbsent(key, () {
      final ctrl = ScrollController();
      ctrl.addListener(() => _syncFrom(ctrl));
      return ctrl;
    });
  }

  // 演出フィルタートラックはフィルターごとに1行。ScrollControllerは
  // 1つのスクロールにしか付けられないので、2行目以降は専用のものを
  // 作って他のトラックと同期させる（同じものを付けると、2件目を追加した
  // 時点で「attached to multiple scroll views」になった）。
  ScrollController _effectRowScrollCtrl(int rowIndex) {
    if (rowIndex == 0) return _effectFilterScrollCtrl;
    return _rowScrollCtrls.putIfAbsent('effect_$rowIndex', () {
      final ctrl = ScrollController(
        initialScrollOffset: _effectFilterScrollCtrl.hasClients
            ? _effectFilterScrollCtrl.offset
            : 0,
      );
      ctrl.addListener(() => _syncFrom(ctrl));
      return ctrl;
    });
  }

  ({String layerId, String? sceneId, int start, int end})? _commonDragRange;

  // シーン複数選択モード（「選択」ボタンで開始）
  bool _isSceneMultiSelect = false;
  final Set<String> _selectedSceneIds = {};

  // フレーム複数選択モード（シーンと同じ操作体系。「選択」ボタン、または
  // シーンチップの長押し「シーン内フレームを全選択」から開始）
  bool _isFrameMultiSelect = false;
  final Set<int> _selectedFrameIndices = {};
  bool _isFrameMoveMode = false;
  int _frameMoveCursorPos = 0;

  // フレームのコピー・切り取り・貼り付け。シーンをまたいだ貼り付けに
  // 対応するため、貼り付け先とは別にコピー元のシーンIDを保持する。
  // 貼り付けは既存の移動モードと同じカーソル固定UIを再利用するため、
  // 専用のカーソル位置は持たず_frameMoveCursorPosを共用する。
  ({String sceneId, List<int> indices, bool isCut})? _frameClipboard;
  bool _isFramePasteMode = false;
  // フレームのカーソルUI（移動または貼り付け）が表示中かどうか。
  bool get _isFrameCursorActive => _isFrameMoveMode || _isFramePasteMode;

  // フレーム一覧も画面中央に固定で赤枠を表示し、現在位置のフレームがそこへ
  // 来るよう一覧側をスクロールさせる（キャンバスモードのフレーム一覧と
  // 同じ挙動）。_frameScrollCtrlは他トラックと同期済みのため、
  // ここでのスクロールは共通レイヤー・素材トラック等にも連動する。
  void _onCurrentFrameChanged() {
    if (!mounted || _followingTimelineScroll) return;
    if (_isFrameCursorActive &&
        _currentFrame != math.min(_frameMoveCursorPos, _totalFrames - 1)) {
      _frameMoveCursorPos = _currentFrame;
    }
    // Seeking updates the preview immediately, so move the rows in the same
    // frame. Defer only when the list hasn't finished layout.
    if ((_frameScrollCtrl.positions.singleOrNull?.hasContentDimensions ??
            false) &&
        WidgetsBinding.instance.schedulerPhase !=
            SchedulerPhase.persistentCallbacks) {
      _centerFrameInList();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _timelineDragStartX == null) _centerFrameInList();
      });
    }
  }

  void _centerFrameInList() {
    final position = _frameScrollCtrl.positions.singleOrNull;
    if (position == null || !position.hasContentDimensions) return;
    final target = (_currentFrame * _cellW).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (target != _timelineOffset) _jumpTimelineTo(target);
  }

  void _jumpTimelineTo(double offset) {
    _jumpingTimeline = true;
    try {
      _frameScrollCtrl.jumpTo(offset);
    } finally {
      _jumpingTimeline = false;
    }
  }

  void _followTimelineScroll({bool append = false}) {
    final last = _totalFrames - 1;
    final frame = (_timelineOffset / _cellW).round().clamp(0, last);
    final placement = append ? last + 1 : frame;
    if (_isFrameCursorActive && _frameMoveCursorPos != placement) {
      setState(() => _frameMoveCursorPos = placement);
    }
    _followingTimelineScroll = true;
    _currentFrame = frame;
    _followingTimelineScroll = false;
  }

  bool _handleTrackScrollEnd(ScrollEndNotification notification) {
    if (!_jumpingTimeline &&
        !_syncingScroll &&
        _timelineDragStartX == null &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.horizontal) {
      _centerFrameInList();
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // 再生位置の変化でフレーム一覧を中央へ寄せる。以前は_buildFrameList()
    // の中から呼んでいたが、再生中は画面全体を作り直さなくなったため
    // build任せにできない。そもそもbuildの中で副作用（スクロール）を
    // 起こすのは筋が悪いので、値の変化に紐づける形へ移した。
    _currentFrameNotifier.addListener(_onCurrentFrameChanged);
    // タイムライン編集に作業領域を広く使えるよう、既定でAndroid標準の
    // ナビゲーションバーを最小化する。
    ImmersiveMode.enterWorkspace();

    _frameScrollCtrl = ScrollController(
      onAttach: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _timelineDragStartX == null) _centerFrameInList();
      }),
    );
    _audioScrollCtrl = ScrollController();
    _videoScrollCtrl = ScrollController();
    _imageScrollCtrl = ScrollController();
    _textScrollCtrl = ScrollController();
    _cameraScrollCtrl = ScrollController();
    _commonLayerScrollCtrl = ScrollController();
    _effectFilterScrollCtrl = ScrollController();

    for (final ctrl in _trackScrollCtrls) {
      ctrl.addListener(() => _syncFrom(ctrl));
    }

    // 制作時間カウント（タイムラインモードのみカウント）
    _projectService = context.read<ProjectService>();
    final scenes = _projectService.scenesOf(widget.projectId);
    final initialScene =
        scenes
            .where((scene) => scene.id == widget.initialSceneId)
            .firstOrNull ??
        scenes.firstOrNull;
    if (initialScene != null) {
      _selectedSceneId = initialScene.id;
      if (widget.initialSceneId == null ||
          widget.initialSceneId == initialScene.id) {
        _currentFrame = widget.initialFrame.clamp(
          0,
          math.max(0, initialScene.frames.length - 1),
        );
      }
    }
    context.read<UndoManager>().selectProject(widget.projectId);
    _workTrackingLease = _projectService.beginWorkTracking(widget.projectId);
    _watchPreviewVideoMaterials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showProjectAutosaveNotice(context, widget.projectId);
    });
  }

  List<ScrollController> get _trackScrollCtrls => [
    _frameScrollCtrl,
    _audioScrollCtrl,
    _videoScrollCtrl,
    _imageScrollCtrl,
    _textScrollCtrl,
    _cameraScrollCtrl,
    _commonLayerScrollCtrl,
    _effectFilterScrollCtrl,
    ?_readAloudScrollController,
    ..._rowScrollCtrls.values,
  ];

  void _syncFrom(ScrollController source, {bool updatePlayhead = true}) {
    if (_syncingScroll) return;
    // The old and new workspace can briefly share controllers while the
    // viewport switches between phone and PC layouts.
    final sourcePosition = source.positions.singleOrNull;
    if (sourcePosition == null) return;
    _syncingScroll = true;
    final offset = sourcePosition.pixels;
    for (final ctrl in _trackScrollCtrls) {
      if (ctrl == source) continue;
      final position = ctrl.positions.singleOrNull;
      if (position == null || !position.hasContentDimensions) continue;
      final target = offset.clamp(0.0, position.maxScrollExtent);
      if (target != position.pixels) position.jumpTo(target);
    }
    _syncingScroll = false;
    if (updatePlayhead && !_jumpingTimeline && _frameScrollCtrl.hasClients) {
      if (_isPlaying) _togglePlay();
      _followTimelineScroll();
    }
  }

  @override
  void dispose() {
    _finishMaterialDrag(deferred: true);
    _stopTimelineDrag(snap: false);
    _regionEdit.dispose();
    _screenFocus.dispose();
    ImmersiveMode.exitWorkspace();
    _playTimer?.cancel();
    for (final ctrl in _trackScrollCtrls) {
      ctrl.dispose();
    }
    for (final p in _audioPlayers.values) {
      p.dispose();
    }
    for (final v in _videoControllers.values) {
      v.dispose();
    }
    _releasePreviewVideoFrames();
    _moveThumbnail?.dispose();
    _currentFrameNotifier.removeListener(_onCurrentFrameChanged);
    _currentFrameNotifier.dispose();
    _projectService.endWorkTracking(lease: _workTrackingLease);
    super.dispose();
  }

  /// 移動モードのカーソル吹き出し用に、指定シーン・フレームの先頭サムネイルを
  /// 生成する（先頭のサムネイルのみ実画像を表示する）。
  /// 小さいプレビュー用に縮小したui.Imageを返す。生成できない場合はnull。
  Future<void> _loadMoveThumbnail(String sceneId, {int frameIndex = 0}) async {
    final ps = context.read<ProjectService>();
    final scene = ps
        .scenesOf(widget.projectId)
        .where((s) => s.id == sceneId)
        .firstOrNull;
    if (scene == null || scene.frames.isEmpty) return;
    final frame = scene.frames[frameIndex.clamp(0, scene.frames.length - 1)];
    final tileManager = ps.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;
    if (w <= 0 || h <= 0) return;
    const size = 48;
    final layers = ps.layersOf(widget.projectId, sceneId, frame.index);
    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => ps.tileKeyFor(widget.projectId, sceneId, frame.index, l.id),
      w,
      h,
      paperColor: LayerCompositor.paperForBlendModes(
        layers,
        _projectBackgroundOf(ps, widget.projectId),
      ),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint(),
    );
    fullImage.dispose();
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(size, size);
    picture.dispose();
    if (!mounted) {
      thumb.dispose();
      return;
    }
    final old = _moveThumbnail;
    setState(() => _moveThumbnail = thumb);
    old?.dispose();
  }

  int get _totalFrames {
    final ps = context.read<ProjectService>();
    final sceneId = _selectedSceneId;
    if (sceneId == null) return 1;
    final count = ps.frameCount(widget.projectId, sceneId);
    return count > 0 ? count : 1;
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playTimer?.cancel();
      setState(() => _isPlaying = false);
      _pauseAllMedia();
    } else {
      final ps = context.read<ProjectService>();
      final project = ps.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull;
      final fps = project?.fps ?? 24;
      _playTimer = Timer.periodic(
        Duration(milliseconds: (1000 / fps).round()),
        (timer) {
          final total = _totalFrames;
          if (!_loopEnabled && _currentFrame >= total - 1) {
            // ループOFF：最終フレームに到達したらそこで自動停止する。
            timer.cancel();
            setState(() => _isPlaying = false);
            _pauseAllMedia();
            return;
          }
          // ここはsetStateを使わない。再生位置に追従する必要があるのは
          // プレビューとシークバーだけで、その2つは
          // _currentFrameNotifierをValueListenableBuilderで購読している。
          // setStateにすると、フレーム一覧・各トラック・シーンタブまで
          // 含めた画面全体を毎秒24〜60回作り直すことになる。
          _currentFrame = (_currentFrame + 1) % total;
          _syncMediaPlayback();
        },
      );
      setState(() => _isPlaying = true);
      _syncMediaPlayback();
    }
  }

  void _stepFramePrevious() {
    if (_currentFrame > 0) setState(() => _currentFrame--);
  }

  void _stepFrameNext() {
    if (_currentFrame < _totalFrames - 1) setState(() => _currentFrame++);
  }

  /// シーン複数選択モード中はシーンを全選択、そうでなければフレーム
  /// 複数選択モードへ入りフレームを全選択する（Ctrl+A）。
  void _selectAllFramesOrScenes() {
    if (_isSceneMultiSelect) {
      final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
      setState(() => _selectedSceneIds.addAll(scenes.map((s) => s.id)));
    } else if (_isClipMultiSelect) {
      _selectAllClips();
    } else if (!_isFrameCursorActive && !_isSceneCursorActive) {
      setState(() {
        _setTimelineSelection(_TimelineSelection.frames);
        _selectedFrameIndices.addAll(List.generate(_totalFrames, (i) => i));
      });
    }
  }

  /// シーン複数選択モード中は選択中のシーンを、フレーム複数選択モード中は
  /// 選択中のフレームを、クリップ複数選択モード中は選択中のクリップを
  /// クリップボードへコピーする（Ctrl+C）。3種類のクリップボードは互いに
  /// 排他（いずれか1つをコピーすると他は破棄される）。
  void _copySelectionToClipboard() {
    if (_isSceneMultiSelect && _selectedSceneIds.isNotEmpty) {
      setState(() {
        _sceneClipboard = (ids: _selectedSceneIds.toList(), isCut: false);
        _frameClipboard = null;
        _clipClipboard = null;
      });
    } else if (_isFrameMultiSelect && _selectedFrameIndices.isNotEmpty) {
      final sceneId = _selectedSceneId;
      if (sceneId == null) return;
      setState(() {
        _frameClipboard = (
          sceneId: sceneId,
          indices: _selectedFrameIndices.toList()..sort(),
          isCut: false,
        );
        _sceneClipboard = null;
        _clipClipboard = null;
      });
    } else if (_isClipMultiSelect && _selectedClipIds.isNotEmpty) {
      _copySelectedClips();
      setState(() {
        _sceneClipboard = null;
        _frameClipboard = null;
      });
    }
  }

  /// コピーと同様にクリップボードへ記録するが、貼り付け確定時に元の
  /// シーン・フレーム・クリップを削除する「切り取り」として記録する
  /// （Ctrl+X）。貼り付け前にキャンセルした場合は何も削除されない。
  void _cutSelectionToClipboard() {
    if (_isSceneMultiSelect && _selectedSceneIds.isNotEmpty) {
      setState(() {
        _sceneClipboard = (ids: _selectedSceneIds.toList(), isCut: true);
        _frameClipboard = null;
        _clipClipboard = null;
      });
    } else if (_isFrameMultiSelect && _selectedFrameIndices.isNotEmpty) {
      final sceneId = _selectedSceneId;
      if (sceneId == null) return;
      setState(() {
        _frameClipboard = (
          sceneId: sceneId,
          indices: _selectedFrameIndices.toList()..sort(),
          isCut: true,
        );
        _sceneClipboard = null;
        _clipClipboard = null;
      });
    } else if (_isClipMultiSelect && _selectedClipIds.isNotEmpty) {
      _cutSelectedClips();
      setState(() {
        _sceneClipboard = null;
        _frameClipboard = null;
      });
    }
  }

  /// クリップボードの内容に応じてシーン貼り付けモード・フレーム貼り付け
  /// モード・クリップの貼り付けのいずれかを行う（Ctrl+V）。シーン・
  /// フレームは既存の移動モードと同じカーソル固定UIで貼り付け先を選ぶが、
  /// クリップは常に現在地（_currentFrame）へ即座に貼り付ける。
  void _pasteFromClipboard() {
    if (_isSceneCursorActive || _isFrameCursorActive) return;
    if (_sceneClipboard != null) {
      _startScenePasteMode();
    } else if (_frameClipboard != null) {
      _startFramePasteMode();
    } else if (_clipClipboard != null) {
      _pasteClipsAtCurrentFrame();
    }
  }

  void _applyHistory({required bool redo}) {
    final history = context.read<UndoManager>();
    final id = widget.projectId;
    if (redo ? !history.canRedoFor(id) : !history.canUndoFor(id)) return;
    final target = redo
        ? history.redo(projectId: id)
        : history.undo(projectId: id);
    final projects = context.read<ProjectService>();
    final scenes = projects.scenesOf(id);
    final scene =
        (target == null ? null : projects.sceneOf(id, target.sceneId)) ??
        scenes.where((item) => item.id == _selectedSceneId).firstOrNull ??
        scenes.firstOrNull;
    if (scene == null) return;
    if (target != null) _playTimer?.cancel();
    setState(() {
      if (target != null) _isPlaying = false;
      _historyPreviewRevision++;
      if (scene.id != _selectedSceneId) _selectedFrameIndices.clear();
      _selectedSceneId = scene.id;
      _currentFrame = (target?.frameIndex ?? _currentFrame).clamp(
        0,
        math.max(0, scene.frames.length - 1),
      );
      _clipsLoadedForSceneId = null;
      _selectedFrameIndices.removeWhere(
        (index) => index >= scene.frames.length,
      );
    });
  }

  /// 設定画面「ショートカット設定」の割り当て一覧から、タイムライン
  /// モードで有効なキー割り当てのマップを組み立てる。ツール選択の
  /// 割り当てはキャンバスモード専用の概念のためここでは無視する。
  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
    BuildContext context,
  ) {
    final bindings = context.watch<ShortcutService>().bindings;
    final result = <ShortcutActivator, VoidCallback>{};
    for (final b in bindings) {
      if (b.isToolAction) continue;
      switch (b.command) {
        case ShortcutCommand.undo:
          result[b.activator] = () => _applyHistory(redo: false);
        case ShortcutCommand.redo:
          result[b.activator] = () => _applyHistory(redo: true);
        case ShortcutCommand.playPause:
          result[b.activator] = _togglePlay;
        case ShortcutCommand.previousFrame:
          result[b.activator] = _stepFramePrevious;
        case ShortcutCommand.nextFrame:
          result[b.activator] = _stepFrameNext;
        case ShortcutCommand.selectAll:
          result[b.activator] = _selectAllFramesOrScenes;
        case ShortcutCommand.copy:
          result[b.activator] = _copySelectionToClipboard;
        case ShortcutCommand.cut:
          result[b.activator] = _cutSelectionToClipboard;
        case ShortcutCommand.paste:
          result[b.activator] = _pasteFromClipboard;
        case ShortcutCommand.toggleLayerPanel:
        case ShortcutCommand.canvasFit:
        case ShortcutCommand.canvasActualPixels:
        case ShortcutCommand.canvasZoomIn:
        case ShortcutCommand.canvasZoomOut:
        case ShortcutCommand.canvasRotateLeft:
        case ShortcutCommand.canvasRotateRight:
        case ShortcutCommand.canvasResetRotation:
        case null:
          // 素材クリップ（動画・画像・音声）のコピー・切り取り・貼り付けは
          // タイムラインモードでは未対応。キャンバス専用の操作、または
          // 未割り当ても同様にここでは無視する。
          break;
      }
    }
    return result;
  }

  void _pauseAllMedia() {
    for (final p in _audioPlayers.values) {
      p.pause();
    }
    for (final v in _videoControllers.values) {
      if (v.value.isInitialized && v.value.isPlaying) v.pause();
    }
  }

  /// 現在フレームに応じて音声・動画クリップの再生位置・再生状態を同期する。
  /// 音声＝再生位置変更・フェードイン/アウト・音量変更、動画＝再生位置変更。
  void _syncMediaPlayback() {
    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final fps = (project?.fps ?? 24).toDouble();
    for (final clip in _audioClips) {
      _syncAudioClip(clip, fps);
    }
    for (final clip in _videoClips) {
      _syncVideoClip(clip, fps);
    }
  }

  bool _clipInRange(_TrackClip clip) =>
      _currentFrame >= clip.startFrame &&
      _currentFrame < clip.startFrame + clip.lengthFrames;

  Future<void> _syncAudioClip(_TrackClip clip, double fps) async {
    final path = clip.filePath;
    if (path == null) return;
    final player = _audioPlayers.putIfAbsent(clip.id, () => ap.AudioPlayer());
    if (!_clipInRange(clip) || !_isPlaying) {
      if (player.state == ap.PlayerState.playing) await player.pause();
      return;
    }
    final elapsedFrames = _currentFrame - clip.startFrame;
    // Preview and offline export share the same clip-relative linear
    // fade envelope so the audible gain at a timeline time is consistent.
    final vol = AudioClipEnvelope.gainAt(
      elapsedSeconds: elapsedFrames / fps,
      clipSeconds: clip.lengthFrames / fps,
      volume: clip.volume,
      fadeInSeconds: clip.fadeIn,
      fadeOutSeconds: clip.fadeOut,
    );
    await player.setVolume(vol);
    if (player.state != ap.PlayerState.playing) {
      // The same source position and speed the export reads (the pitch is
      // kept in both).
      final source = clip.sourceAfter(elapsedFrames);
      final targetFrame = source.frame + source.fraction;
      await player.setPlaybackRate(clip.playbackRate);
      await player.play(
        ap.DeviceFileSource(path),
        position: Duration(milliseconds: (targetFrame / fps * 1000).round()),
      );
    }
  }

  Future<void> _syncVideoClip(_TrackClip clip, double fps) async {
    final path = clip.filePath;
    if (path == null) return;
    var controller = _videoControllers[clip.id];
    if (!_clipInRange(clip)) {
      if (controller != null &&
          controller.value.isInitialized &&
          controller.value.isPlaying) {
        await controller.pause();
      }
      return;
    }
    if (controller == null) {
      controller = VideoPlayerController.file(File(path));
      _videoControllers[clip.id] = controller;
      try {
        await controller.initialize();
      } catch (_) {
        return;
      }
      if (mounted) setState(() {});
    }
    if (!controller.value.isInitialized) return;
    // Where the picture holds the last used frame the video is silent (the
    // export stops its sound there too), so the player does not run on into
    // the rest of the file.
    if (_currentFrame - clip.startFrame >= clip.videoSoundingFrames) {
      if (controller.value.isPlaying) await controller.pause();
      return;
    }
    await controller.setVolume(clip.volume.clamp(0.0, 1.0));
    // Keep preview seeking on the same pure timeline-to-source mapping
    // that offline video rendering will consume. Trim end is inclusive.
    final targetPos = TimelineVideoTimeMapper.sourcePositionAt(
      timelineFrame: _currentFrame,
      clipStartFrame: clip.startFrame,
      clipLengthFrames: clip.lengthFrames,
      sourceTrimStartFrame: clip.useStart + clip.sourceFraction,
      sourceTrimEndFrame: clip.useEnd,
      framesPerSecond: fps,
      playbackRate: clip.soundRate,
    );
    if (controller.value.playbackSpeed != clip.soundRate) {
      try {
        await controller.setPlaybackSpeed(clip.soundRate);
      } catch (error, stackTrace) {
        // A speed the device's player cannot play: the frames still follow
        // the speed; only this preview's sound does not.
        AppErrorReporter.record(error, stackTrace);
      }
    }
    if (targetPos == null) return;
    if (!_isPlaying) {
      if (controller.value.isPlaying) await controller.pause();
      await controller.seekTo(targetPos);
      return;
    }
    if (!controller.value.isPlaying) {
      await controller.seekTo(targetPos);
      await controller.play();
    }
  }

  // ─── Decoded video frames for the previews ───────────────
  // The previews composite the frames of video materials through the same
  // VideoFrameProvider rules as the export. The provider reads only the
  // files in a snapshot of the project's video materials, made again when
  // the materials change.
  MaterialService? _previewVideoMaterialService;
  VideoMaterialSnapshot? _previewVideoMaterials;
  VideoFrameProvider? _previewVideoFrames;

  /// The frames the video rows' filmstrips show: a source of their own, so
  /// their small pictures neither push the preview's frames out of the cache
  /// nor wait in line before them.
  VideoFrameProvider? _stripVideoFrames;
  Directory? _previewVideoWorkDir;
  int _previewVideoGeneration = 0;
  TimelineVideoLayerPixels? _previewVideoPixels;

  void _watchPreviewVideoMaterials() {
    final MaterialService materials;
    try {
      materials = context.read<MaterialService>();
    } on ProviderNotFoundException {
      return;
    }
    _previewVideoMaterialService = materials
      ..addListener(_refreshPreviewVideoFrames);
    _refreshPreviewVideoFrames();
  }

  Future<void> _refreshPreviewVideoFrames() async {
    final materials = _previewVideoMaterialService;
    if (materials == null) return;
    final generation = ++_previewVideoGeneration;
    try {
      final snapshot = await materials.videoSnapshotOf(widget.projectId);
      if (!mounted || generation != _previewVideoGeneration) return;
      final current = _previewVideoMaterials;
      if (current != null && current.hasSameSources(snapshot)) return;
      final workDir = _previewVideoWorkDir ??= (await getTemporaryDirectory())
          .createTempSync('timeline_preview_video_frames_');
      if (!mounted || generation != _previewVideoGeneration) return;
      final frames = VideoFrameProvider(
        snapshot: snapshot,
        decoder: TimelineScreen.videoDecoderFor(workDir),
      );
      final strip = VideoFrameProvider(
        snapshot: snapshot,
        decoder: TimelineScreen.videoDecoderFor(workDir),
        cacheBudgetBytes: 16 * 1024 * 1024,
        maxConcurrentDecodes: 1,
      );
      final previous = _previewVideoFrames;
      final previousStrip = _stripVideoFrames;
      setState(() {
        _previewVideoMaterials = snapshot;
        _previewVideoFrames = frames;
        _stripVideoFrames = strip;
        _previewVideoPixels = null;
      });
      // Pictures still being built with the old frames are not shown.
      previous?.dispose();
      previousStrip?.dispose();
    } catch (error, stackTrace) {
      // Without a frame source the previews draw no video frames.
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// The frame source for the previews at the project's current frame rate
  /// and canvas size (a new one when either changes, so the previews redraw).
  TimelineVideoLayerPixels? _previewVideoPixelsFor(ProjectService ps) {
    final frames = _previewVideoFrames;
    if (frames == null) return null;
    final fps = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull
        ?.fps;
    final tiles = ps.tileManagerOf(widget.projectId);
    if (fps == null || fps <= 0) return null;
    final current = _previewVideoPixels;
    if (current != null &&
        identical(current.frames, frames) &&
        current.framesPerSecond == fps &&
        current.canvasWidth == tiles.canvasWidth &&
        current.canvasHeight == tiles.canvasHeight) {
      return current;
    }
    return _previewVideoPixels = TimelineVideoLayerPixels(
      frames: frames,
      framesPerSecond: fps.toDouble(),
      canvasWidth: tiles.canvasWidth,
      canvasHeight: tiles.canvasHeight,
    );
  }

  void _releasePreviewVideoFrames() {
    _previewVideoGeneration++;
    _previewVideoMaterialService?.removeListener(_refreshPreviewVideoFrames);
    _previewVideoMaterialService = null;
    _previewVideoFrames?.dispose();
    _previewVideoFrames = null;
    _stripVideoFrames?.dispose();
    _stripVideoFrames = null;
    _previewVideoPixels = null;
    final workDir = _previewVideoWorkDir;
    _previewVideoWorkDir = null;
    if (workDir != null) {
      unawaited(
        workDir.delete(recursive: true).then<void>((_) {}, onError: (_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _TimelinePreviewVideoFrames(
    videoPixels: _previewVideoPixelsFor(context.watch<ProjectService>()),
    child: _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    // シーンは実プロジェクトデータ（ProjectService）から取得する。
    // 選択中シーンが未設定・削除済みの場合は先頭シーンへ同期する。
    final scenes = context.watch<ProjectService>().scenesOf(widget.projectId);
    if (scenes.isNotEmpty &&
        (_selectedSceneId == null ||
            !scenes.any((s) => s.id == _selectedSceneId))) {
      _selectedSceneId = scenes.first.id;
    }
    // タイムライン素材クリップ（音声・画像・動画）を永続データから復元する。
    // シーンが切り替わった時のみ実行する（毎buildでの再読み込みを避ける）。
    if (_selectedSceneId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureClipsLoaded(_selectedSceneId!);
      });
    }

    // プレビュー全画面化中：確認・仕上がりチェックに集中できるよう、
    // プレビューと再生コントロールのみを全画面表示する。
    // _buildPreview()・_buildPlaybackControls()は通常表示と
    // 完全に同じメソッドをそのまま再利用するため、再生中のフレーム送りや
    // スクラブ操作の挙動に差異は生じない。
    if (_isPreviewFullscreen) {
      final l10n = AppLocalizations.of(context)!;
      final theme = context.watch<ThemeService>().current;
      // 「戻る」は全画面を閉じるだけにする（タイムラインからは出ない）。
      // キャンバスからgo()で来たタイムラインは履歴が1枚だけで、Navigatorは
      // PopScopeを呼ばずにアプリを閉じるので、BackButtonListenerで先に
      // 受ける。PopScope(canPop: false)は、予測型「戻る」でOSが戻る操作を
      // アプリへ渡すようにするため。
      return BackButtonListener(
        onBackButtonPressed: () async => _closePreviewFullscreenByBack(),
        child: PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _closePreviewFullscreenByBack();
          },
          child: Scaffold(
            // 映写モードの背景も固定の黒ではなく、テーマのパネル背景色に連動
            // させる（それでも大抵は暗色系のためチェック目的の集中は保たれる）。
            backgroundColor: theme.panelBgColor,
            body: Listener(
              onPointerDown: (_) =>
                  context.read<ProjectService>().pingWorkActivity(),
              child: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(
                          Icons.fullscreen_exit,
                          color: theme.textColor,
                        ),
                        tooltip: l10n.timelineFullscreenPreviewCloseTooltip,
                        onPressed: () =>
                            setState(() => _isPreviewFullscreen = false),
                      ),
                    ),
                    _buildPreview(),
                    _buildSeekBar(),
                    _buildPlaybackControls(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    // マウス/キーボード入力・左手デバイス：設定画面「ショートカット設定」
    // で割り当てたキーで、Undo/Redo・再生/一時停止・フレーム送りなどの
    // 操作を行えるようにする。
    // 入力欄にフォーカスがある間は画面のショートカットを止め、入力を
    // 終えたら画面のフォーカスへ戻す（TypingAwareShortcuts）。
    return TypingAwareShortcuts(
      bindings: _buildShortcutBindings(context),
      screenFocus: _screenFocus,
      child: Focus(
        focusNode: _screenFocus,
        autofocus: true,
        child: Scaffold(
          body: Listener(
            // 制作時間カウント：操作のたびに無操作タイマーをリセットする
            onPointerDown: (_) =>
                context.read<ProjectService>().pingWorkActivity(),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, outerConstraints) {
                  if (isWideScreen(context) &&
                      outerConstraints.maxWidth >= 760 &&
                      outerConstraints.maxHeight >= 520) {
                    return _buildPcTimelineWorkspace(l10n);
                  }
                  return Column(
                    children: [
                      _buildTopBar(),
                      // 編集パネルを出している間は、プレビューを画面の45%までに
                      // 抑えて残りをすべてパネルへ渡す（プレビューは高さを
                      // 使い切らないFlexibleなので、Flexの配分のままだと余りが
                      // 空白になりパネルが細い帯になった）。
                      if (_isEditPanelOpen)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: outerConstraints.maxHeight * 0.45,
                          ),
                          child: _buildPreviewWithHandle(
                            outerConstraints.maxHeight,
                          ),
                        )
                      else
                        Flexible(
                          flex: 3,
                          fit: FlexFit.loose,
                          child: _buildPreviewWithHandle(
                            outerConstraints.maxHeight,
                          ),
                        ),
                      _buildSeekBar(),
                      _buildPlaybackControls(),
                      if (_isEditPanelOpen)
                        Expanded(child: _buildEditPanel())
                      else ...[
                        _buildToolbar(),
                        _buildSceneTabs(),
                        ..._buildTimelineTracks(l10n),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimelineTracks(AppLocalizations l10n) => [
    if (!_isSceneCursorActive && !_isFrameCursorActive)
      _buildTimestampRow(l10n),
    // ピンチイン・ピンチアウトでフレーム幅（拡大縮小）を
    // 変更できるよう、フレーム一覧から各トラックまでを
    // Listenerで包み2本指の距離変化を監視する。子孫の
    // 横スクロールを妨げないようtranslucentで通過させる。
    Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onTimelinePinchPointerDown,
      onPointerMove: _onTimelinePinchPointerMove,
      onPointerUp: _onTimelinePinchPointerUp,
      onPointerCancel: _onTimelinePinchPointerUp,
      onPointerSignal: _onTimelinePointerSignal,
      child: _buildFrameList(),
    ),
    // 各種タイムライン行：デフォルトではプレビュー・
    // フレーム一覧のみを表示し、それぞれ中身（共通レイヤー・
    // テキスト・画像・動画・音源・カメラキーフレーム・
    // 演出フィルター）が1つでも追加された行だけを
    // 表示する。最後の1件を削除すれば、その行だけ最初と同じく
    // 非表示に戻る。
    // 表示順：フレーム・シーン・共通レイヤー・テキスト・画像・動画・
    // 音源・カメラ・演出フィルター・エンドカードの順。
    // プレビュー欄をドラッグハンドルで縮めた分だけ、この一覧が
    // スクロールで広く見られるようにExpanded+スクロールにしている。
    Expanded(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onTimelinePinchPointerDown,
        onPointerMove: _onTimelinePinchPointerMove,
        onPointerUp: _onTimelinePinchPointerUp,
        onPointerCancel: _onTimelinePinchPointerUp,
        child: SingleChildScrollView(
          child: Listener(
            onPointerSignal: _onTimelinePointerSignal,
            child: Column(
              children: [
                _buildCommonLayerTrack(),
                // 並びは既定の重なり順（テキストが手前、
                // フレームのイラスト、画像、動画）と同じ。
                _buildMaterialTrackGroup(
                  type: TimelineRowKind.text,
                  icon: Icons.text_fields,
                  defaultLabel: l10n.timelineMaterialText,
                  allClips: _textClips,
                  addColor: _textClipColor,
                ),
                _buildMaterialTrackGroup(
                  type: TimelineRowKind.image,
                  icon: Icons.image,
                  defaultLabel: l10n.projectListMaterialImage,
                  allClips: _imageClips,
                  addColor: ThemeService.activeColorScheme.secondary,
                ),
                _buildMaterialTrackGroup(
                  type: TimelineRowKind.video,
                  icon: Icons.videocam,
                  defaultLabel: l10n.projectListMaterialVideo,
                  allClips: _videoClips,
                  addColor: ThemeService.activeColorScheme.primary,
                ),
                _buildMaterialTrackGroup(
                  type: TimelineRowKind.audio,
                  icon: Icons.audiotrack,
                  defaultLabel: l10n.projectListMaterialAudio,
                  allClips: _audioClips.where((c) => !c.isReadAloud).toList(),
                  addColor: ThemeService.activeColorScheme.tertiary,
                ),
                _buildReadAloudTrack(),
                _buildCameraTrack(),
                _buildEffectFilterTrack(),
                _buildEndCardTrack(),
              ],
            ),
          ),
        ),
      ),
    ),
  ];

  // ─── PC/DeXモードの作業画面 ───────────────────────────────────────────

  Widget _pcTimelineGrip(_PcTimelineArea area, String title) {
    final colors = PcWorkspaceColors.of(context);
    return Draggable<_PcTimelineArea>(
      key: ValueKey('pcTimelineGrip.${area.name}'),
      data: area,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: colors.paneHeader,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.accentFill),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(title, style: TextStyle(color: colors.onPane)),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: AppLocalizations.of(context)!.commonMove,
          child: SizedBox(
            width: 24,
            height: PcDockColumn.headerHeight,
            child: Icon(Icons.drag_indicator, size: 18, color: colors.onPane),
          ),
        ),
      ),
    );
  }

  Widget _pcTimelineDropArea(_PcTimelineArea area, Widget child) {
    return DragTarget<_PcTimelineArea>(
      key: ValueKey('pcTimelineDrop.${area.name}'),
      onWillAcceptWithDetails: (details) => details.data != area,
      onAcceptWithDetails: (details) => setState(() {
        if (details.data == _PcTimelineArea.tracks ||
            area == _PcTimelineArea.tracks) {
          _pcTracksAbove = !_pcTracksAbove;
          return;
        }
        final a = _pcPaneOrder.indexOf(area);
        final b = _pcPaneOrder.indexOf(details.data);
        _pcPaneOrder[a] = details.data;
        _pcPaneOrder[b] = area;
      }),
      builder: (context, candidates, _) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (candidates.isNotEmpty)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// PCのパネルは横に交換でき、全幅のタイムラインは上下を入れ替えられる。
  Widget _buildPcTimelineWorkspace(AppLocalizations l10n) {
    return Column(
      children: [
        _buildPcTimelineTopBar(l10n),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const minUpper = 220.0;
              const minTracks = 180.0;
              final maxUpper = math.max(
                minUpper,
                constraints.maxHeight - minTracks - PcDockColumn.splitterHeight,
              );
              final upper = (_pcUpperHeight ?? constraints.maxHeight * 0.55)
                  .clamp(minUpper, maxUpper);
              final panes = _pcPaneOrder
                  .where(
                    (pane) => switch (pane) {
                      _PcTimelineArea.bin => _pcShowBin,
                      _PcTimelineArea.inspector => _pcShowInspector,
                      _ => true,
                    },
                  )
                  .toList();
              final sides =
                  constraints.maxWidth -
                  360 -
                  PcDockSplitter.width * (panes.length - 1);
              final wanted =
                  (_pcShowBin ? _pcBinWidth : 0) +
                  (_pcShowInspector ? _pcInspectorWidth : 0);
              final scale = wanted > sides && wanted > 0
                  ? math.max(0.0, sides) / wanted
                  : 1.0;
              final binWidth = math.max(180.0, _pcBinWidth * scale);
              final inspectorWidth = math.max(240.0, _pcInspectorWidth * scale);
              void adjust(_PcTimelineArea pane, double delta) {
                switch (pane) {
                  case _PcTimelineArea.bin:
                    _pcBinWidth = (binWidth + delta).clamp(180.0, 480.0);
                  case _PcTimelineArea.inspector:
                    _pcInspectorWidth = (inspectorWidth + delta).clamp(
                      240.0,
                      560.0,
                    );
                  case _PcTimelineArea.monitor:
                  case _PcTimelineArea.tracks:
                    break;
                }
              }

              final mainPanes = SizedBox(
                key: const ValueKey('pcTimelineUpperPanes'),
                height: upper,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < panes.length; i++) ...[
                      if (i > 0)
                        PcDockSplitter(
                          key: ValueKey(
                            panes[i - 1] == _PcTimelineArea.bin
                                ? 'pcTimelineBinSplitter'
                                : panes[i] == _PcTimelineArea.inspector
                                ? 'pcTimelineInspectorSplitter'
                                : 'pcTimelineSplitter.$i',
                          ),
                          onDrag: (dx) => setState(() {
                            adjust(panes[i - 1], dx);
                            adjust(panes[i], -dx);
                          }),
                        ),
                      switch (panes[i]) {
                        _PcTimelineArea.bin => SizedBox(
                          key: const ValueKey('pcTimelineBinSlot'),
                          width: binWidth,
                          child: _pcTimelineDropArea(
                            _PcTimelineArea.bin,
                            _buildPcTimelineBin(l10n),
                          ),
                        ),
                        _PcTimelineArea.inspector => SizedBox(
                          key: const ValueKey('pcTimelineInspectorSlot'),
                          width: inspectorWidth,
                          child: _pcTimelineDropArea(
                            _PcTimelineArea.inspector,
                            _buildPcTimelineDetails(l10n),
                          ),
                        ),
                        _ => Expanded(
                          key: const ValueKey('pcTimelineMonitorSlot'),
                          child: _pcTimelineDropArea(
                            _PcTimelineArea.monitor,
                            _buildPcProgramMonitor(l10n),
                          ),
                        ),
                      },
                    ],
                  ],
                ),
              );
              final tracks = Expanded(
                key: const ValueKey('pcTimelineTracksSlot'),
                child: _pcTimelineDropArea(
                  _PcTimelineArea.tracks,
                  Material(
                    key: const ValueKey('pcTimelineTracks'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        if (_isSceneCursorActive || _isFrameCursorActive)
                          _buildTimelinePlacementToolbar(l10n)
                        else if (_timelineSelection case final selection?)
                          _buildSelectionToolbar(l10n, selection),
                        Row(
                          children: [
                            _pcTimelineGrip(
                              _PcTimelineArea.tracks,
                              l10n.helpTimelineTitle,
                            ),
                            Expanded(child: _buildSceneTabs()),
                          ],
                        ),
                        ..._buildTimelineTracks(l10n),
                      ],
                    ),
                  ),
                ),
              );
              return Column(
                children: [
                  if (_pcTracksAbove) tracks else mainPanes,
                  PcRowSplitter(
                    key: const ValueKey('pcTimelineRowSplitter'),
                    onDrag: (dy) => setState(
                      () =>
                          _pcUpperHeight = (upper + (_pcTracksAbove ? -dy : dy))
                              .clamp(minUpper, maxUpper),
                    ),
                  ),
                  if (_pcTracksAbove) mainPanes else tracks,
                ],
              );
            },
          ),
        ),
        _buildPcTimelineStatusBar(l10n),
      ],
    );
  }

  Widget _buildPcTimelineBin(AppLocalizations l10n) => PcDockColumn(
    key: const ValueKey('pcTimelineBin'),
    panes: [
      PcPane(
        id: 'bin',
        fill: true,
        minLayoutHeight: 0,
        leading: _pcTimelineGrip(_PcTimelineArea.bin, l10n.helpSceneTitle),
        tabs: [
          PcPaneTab(
            id: 'scenes',
            title: l10n.helpSceneTitle,
            icon: Icons.movie_outlined,
            child: _buildPcSceneBin(l10n),
          ),
          PcPaneTab(
            id: 'materials',
            title: l10n.storageCategoryMaterials,
            icon: Icons.perm_media_outlined,
            child: _buildPcMaterialBin(l10n),
          ),
        ],
      ),
    ],
  );

  Widget _buildPcTimelineDetails(AppLocalizations l10n) => PcDockColumn(
    key: const ValueKey('pcTimelineInspector'),
    panes: [
      PcPane(
        id: 'inspector',
        fill: true,
        minLayoutHeight: 0,
        leading: _pcTimelineGrip(
          _PcTimelineArea.inspector,
          l10n.pcPaneInspector,
        ),
        tabs: [
          PcPaneTab(
            id: 'inspector',
            title: _showStackOrder
                ? l10n.timelineStackOrderTitle
                : l10n.pcPaneInspector,
            icon: _showStackOrder ? Icons.layers_outlined : Icons.tune,
            child: _buildPcInspector(l10n),
            onClose: _isEditPanelOpen ? _closeEditPanels : null,
          ),
        ],
      ),
    ],
  );

  /// 再生位置の時刻（分:秒:フレーム）。
  static String _timecode(int frame, int fps) {
    final f = fps > 0 ? fps : 24;
    final seconds = frame ~/ f;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(seconds ~/ 60)}:${two(seconds % 60)}:${two(frame % f)}';
  }

  int _projectFps(ProjectService ps) {
    final fps =
        ps.projects.where((p) => p.id == widget.projectId).firstOrNull?.fps ??
        24;
    return fps > 0 ? fps : 24;
  }

  /// プレビュー：見出し（時刻）・プレビュー・シークバー・再生操作。
  Widget _buildPcProgramMonitor(AppLocalizations l10n) {
    final colors = PcWorkspaceColors.of(context);
    final ps = context.watch<ProjectService>();
    final fps = _projectFps(ps);
    return Material(
      key: const ValueKey('pcProgramMonitor'),
      color: colors.pane,
      child: Column(
        children: [
          Container(
            height: PcDockColumn.headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.paneHeader,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                _pcTimelineGrip(_PcTimelineArea.monitor, l10n.pcPaneProgram),
                Icon(Icons.live_tv_outlined, size: 14, color: colors.onPane),
                const SizedBox(width: 5),
                Text(
                  l10n.pcPaneProgram,
                  style: localizedHeadingStyle(
                    context,
                    TextStyle(fontSize: 12, color: colors.onPane),
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: _currentFrameNotifier,
                  builder: (_, frame, _) => Text(
                    '${_timecode(frame, fps)} / '
                    '${_timecode(_totalFrames, fps)}',
                    key: const ValueKey('pcTimecode'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.accentText,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildPreviewBand(
                aspect: _previewAspect(ps),
                inFullscreen: false,
              ),
            ),
          ),
          _buildSeekBar(),
          _buildPlaybackControls(),
        ],
      ),
    );
  }

  /// シーンの一覧（押すとそのシーンをタイムラインに出す）。
  Widget _buildPcSceneBin(AppLocalizations l10n) {
    final colors = PcWorkspaceColors.of(context);
    final ps = context.watch<ProjectService>();
    final scenes = ps.scenesOf(widget.projectId);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final scene in scenes)
          ListTile(
            key: ValueKey('pcSceneBin.${scene.id}'),
            dense: true,
            selected: scene.id == _selectedSceneId,
            selectedColor: colors.accentText,
            selectedTileColor: colors.selectedOn(colors.pane),
            leading: const Icon(Icons.movie_outlined, size: 18),
            title: Text(
              scene.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(l10n.pcBinSceneFrames(scene.frames.length)),
            onTap: () => _selectTimelineScene(scene),
          ),
      ],
    );
  }

  /// このシーンの素材（テキスト・画像・動画・音源）の一覧と追加ボタン。
  /// 押すと右の「詳細」で編集する（音源は詳細のシート）。
  Widget _buildPcMaterialBin(AppLocalizations l10n) {
    final colors = PcWorkspaceColors.of(context);
    final groups = [
      (_ClipTrackType.text, Icons.text_fields, _textClips),
      (_ClipTrackType.image, Icons.image_outlined, _imageClips),
      (_ClipTrackType.video, Icons.videocam_outlined, _videoClips),
      (_ClipTrackType.audio, Icons.audiotrack, _audioClips),
    ];
    final addLabels = {
      _ClipTrackType.text: l10n.timelineAddTextTooltip,
      _ClipTrackType.image: l10n.timelineAddImageTooltip,
      _ClipTrackType.video: l10n.timelineAddVideoTooltip,
      _ClipTrackType.audio: l10n.timelineAddAudioTooltip,
    };
    final empty = groups.every((g) => g.$3.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
          child: Wrap(
            children: [
              for (final (type, icon, _) in groups)
                PcToolButton(
                  key: ValueKey('pcMaterialBinAdd.${type.name}'),
                  icon: icon,
                  tooltip: addLabels[type]!,
                  onPane: true,
                  onPressed: _selectedSceneId == null
                      ? null
                      : () => _addMaterialOfType(type),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.divider),
        Expanded(
          child: empty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.pcBinEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.mutedOnPane),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final (_, icon, clips) in groups)
                      for (final clip in clips)
                        ListTile(
                          key: ValueKey('pcMaterialBin.${clip.id}'),
                          dense: true,
                          selected: clip.id == _editingMaterialId,
                          selectedColor: colors.accentText,
                          selectedTileColor: colors.selectedOn(colors.pane),
                          leading: Icon(icon, size: 18, color: clip.color),
                          title: Text(
                            clip.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'F${clip.startFrame + 1}–'
                            'F${clip.startFrame + clip.lengthFrames}',
                          ),
                          onTap: () => _showEditClipDialog(clip),
                        ),
                  ],
                ),
        ),
      ],
    );
  }

  /// 詳細：素材を編集中ならその編集パネル（重なり順もここ）、
  /// そうでなければ作品の書き出しの設定と、長さ・大きさの変更。
  Widget _buildPcInspector(AppLocalizations l10n) {
    if (_isEditPanelOpen) return _buildEditPanel();
    final colors = PcWorkspaceColors.of(context);
    final ps = context.watch<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final fps = _projectFps(ps);
    final labelStyle = TextStyle(fontSize: 12, color: colors.mutedOnPane);
    final valueStyle = TextStyle(fontSize: 13, color: colors.onPane);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
    Widget action(IconData icon, String label, VoidCallback onPressed) =>
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        );
    return ListView(
      key: const ValueKey('pcInspectorProject'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        Text(
          project?.name ?? l10n.timelineDefaultProjectName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: localizedHeadingStyle(
            context,
            TextStyle(fontSize: 14, color: colors.onPane),
          ),
        ),
        const SizedBox(height: 8),
        if (project != null)
          row(
            l10n.projectDetailInfoExportSize,
            '${project.exportWidth}×${project.exportHeight}',
          ),
        row(l10n.exportFpsLabel, '$fps'),
        row(l10n.projectDetailInfoTotalFrames, '$_totalFrames'),
        row(
          l10n.timelineDurationSecondsLabel,
          '${(_totalFrames / fps).toStringAsFixed(1)}s',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            action(
              Icons.timer_outlined,
              l10n.timelineDurationChangeMenuItem,
              _showDurationChangeDialog,
            ),
            action(
              Icons.aspect_ratio,
              l10n.timelineCanvasSizeChangeMenuItem,
              _showCanvasSizeChangeDialog,
            ),
            action(
              Icons.layers_outlined,
              l10n.timelineStackOrderTitle,
              () => setState(() {
                _editingMaterialId = null;
                _showStackOrder = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(l10n.pcInspectorHint, style: labelStyle),
      ],
    );
  }

  void _zoomTimeline(double factor) {
    if (_timelineDragStartX != null) return;
    final scale = (_frameWidthScale * factor).clamp(0.6, 2.5);
    if (scale == _frameWidthScale) return;
    setState(() => _frameWidthScale = scale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _timelineDragStartX == null) {
        _centerFrameInList();
      }
    });
  }

  /// PC/DeXモードの上部バー。スマホの上部バー（キャンバスへ・作品名・ホーム・
  /// 取り消し・やり直し・三点メニュー・ヘルプ）とツールバー（素材を追加・
  /// 演出フィルター・カメラ・タイムスタンプ・重なり順・書き出し）のボタンを、
  /// 同じ順のまま1段に並べ、PCではタイムラインの拡大・縮小と、左右の区画の
  /// 表示を足す。再生の操作はプレビューの下にある。
  Widget _buildPcTimelineTopBar(AppLocalizations l10n) {
    final colors = PcWorkspaceColors.of(context);
    final undo = context.watch<UndoManager>();
    final hasScene = _selectedSceneId != null;
    final barStyle = pcBarButtonStyle(context);
    final projectName =
        context
            .watch<ProjectService>()
            .projects
            .where((p) => p.id == widget.projectId)
            .firstOrNull
            ?.name ??
        l10n.timelineDefaultProjectName;
    return PcCommandBar(
      key: const ValueKey('pcTopBar'),
      leading: [
        PcToolButton(
          key: const ValueKey('pcCommandBackToCanvas'),
          longPressTooltip: false,
          icon: Icons.arrow_back,
          trailingIcon: Icons.palette_outlined,
          tooltip: l10n.timelineBackToCanvasTooltip,
          onPressed: _saveAndGoToCanvas,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: localizedHeadingStyle(
                context,
                TextStyle(fontSize: 13, color: colors.onChrome),
              ),
            ),
          ),
        ),
        const PcCommandDivider(),
        if (!_isSceneCursorActive &&
            !_isFrameCursorActive &&
            _timelineSelection == null)
          ..._timelineSelectionControls(l10n, showLabels: false),
        _addMaterialMenu(l10n, style: barStyle),
        PcToolButton(
          icon: Icons.movie_filter,
          tooltip: l10n.timelineEffectFilterLabel,
          onPressed: _showEffectFilterDialog,
        ),
        PcToolButton(
          icon: Icons.camera,
          tooltip: l10n.timelineAddCameraKfTooltip,
          onPressed: _addCameraKf,
        ),
        PcToolButton(
          icon: Icons.push_pin_outlined,
          tooltip: l10n.timelineMarkerTrackLabel,
          onPressed: _showAddMarkerDialog,
        ),
        PcToolButton(
          key: const ValueKey('pcCommandStackOrder'),
          icon: Icons.layers_outlined,
          tooltip: l10n.timelineStackOrderTitle,
          selected: _showStackOrder,
          onPressed: hasScene
              ? () => setState(() {
                  _editingMaterialId = null;
                  _showStackOrder = !_showStackOrder;
                })
              : null,
        ),
        const PcCommandDivider(),
        PcToolButton(
          key: const ValueKey('pcCommandTimelineZoomOut'),
          icon: Icons.zoom_out,
          tooltip: l10n.pcTimelineZoomOut,
          onPressed: () => _zoomTimeline(0.8),
        ),
        PcToolButton(
          key: const ValueKey('pcCommandTimelineZoomIn'),
          icon: Icons.zoom_in,
          tooltip: l10n.pcTimelineZoomIn,
          onPressed: () => _zoomTimeline(1.25),
        ),
      ],
      trailing: [
        _buildPcTimelineWindowMenu(l10n),
        PcToolButton(
          key: const ValueKey('pcCommandHome'),
          icon: Icons.home_outlined,
          tooltip: l10n.timelineBackToProjectListTooltip,
          onPressed: _confirmBackToProjectList,
        ),
        PcToolButton(
          key: const ValueKey('pcCommandUndo'),
          longPressTooltip: false,
          icon: Icons.undo,
          tooltip: l10n.commonUndo,
          onPressed: undo.canUndo ? () => _applyHistory(redo: false) : null,
        ),
        PcToolButton(
          key: const ValueKey('pcCommandRedo'),
          icon: Icons.redo,
          tooltip: l10n.commonRedo,
          onPressed: undo.canRedo ? () => _applyHistory(redo: true) : null,
        ),
        _moreMenu(l10n, style: barStyle),
        HelpButton(topic: 'タイムライン', iconColor: colors.onChrome),
        const SizedBox(width: 4),
        FilledButton.icon(
          key: const ValueKey('pcCommandExport'),
          onPressed: () => _runAutomationBlockedAction(
            () => context.push('/export/${widget.projectId}'),
          ),
          icon: const Icon(Icons.upload_file, size: 16),
          label: Text(l10n.transferExport),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  /// 左右の区画（シーン・素材／詳細）の表示。
  Widget _buildPcTimelineWindowMenu(AppLocalizations l10n) {
    final colors = PcWorkspaceColors.of(context);
    return PopupMenuButton<String>(
      key: const ValueKey('pcTimelineWindowMenu'),
      tooltip: l10n.workspaceDockPanelSection,
      icon: Icon(Icons.view_sidebar_outlined, size: 18, color: colors.onChrome),
      style: pcBarButtonStyle(context),
      onSelected: (value) => setState(() {
        if (value == 'bin') _pcShowBin = !_pcShowBin;
        if (value == 'inspector') _pcShowInspector = !_pcShowInspector;
      }),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          key: const ValueKey('pcWindow.bin'),
          value: 'bin',
          checked: _pcShowBin,
          child: Text(
            '${l10n.helpSceneTitle} / ${l10n.storageCategoryMaterials}',
          ),
        ),
        CheckedPopupMenuItem(
          key: const ValueKey('pcWindow.inspector'),
          value: 'inspector',
          checked: _pcShowInspector,
          child: Text(l10n.pcPaneInspector),
        ),
      ],
    );
  }

  /// ステータスバー：シーン・フレーム・時刻・フレームレート・書き出しの大きさ。
  Widget _buildPcTimelineStatusBar(AppLocalizations l10n) {
    final ps = context.watch<ProjectService>();
    final fps = _projectFps(ps);
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final scene = ps
        .scenesOf(widget.projectId)
        .where((s) => s.id == _selectedSceneId)
        .firstOrNull;
    return PcStatusBar(
      key: const ValueKey('pcStatusBar'),
      items: [
        PcStatusItem(
          icon: Icons.movie_outlined,
          text: scene?.displayName ?? '-',
        ),
        ValueListenableBuilder<int>(
          valueListenable: _currentFrameNotifier,
          builder: (_, frame, _) => PcStatusItem(
            key: const ValueKey('pcStatusFrame'),
            icon: Icons.view_week_outlined,
            text: l10n.pcStatusFrame(
              (_totalFrames > 0 ? frame.clamp(0, _totalFrames - 1) : 0) + 1,
              _totalFrames,
            ),
          ),
        ),
      ],
      trailing: [
        PcStatusItem(icon: Icons.speed, text: l10n.pcStatusFps(fps)),
        if (project != null)
          PcStatusItem(
            icon: Icons.aspect_ratio,
            text: '${project.exportWidth}×${project.exportHeight}',
          ),
      ],
    );
  }

  // ─── 素材の編集パネル・重なり順パネル ─────────────────────

  bool get _isEditPanelOpen =>
      _selectedSceneId != null &&
      (_editingMaterialId != null || _showStackOrder);

  /// The material being edited and the frame its layer lives in.
  ({Layer layer, LayerHome home})? _editingMaterial(ProjectService ps) {
    final id = _editingMaterialId;
    if (id == null) return null;
    final home = ps.homeOf(widget.projectId, id);
    if (home == null || home.sceneId != _selectedSceneId) return null;
    final layer = ps
        .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
        .where((l) => l.id == id)
        .firstOrNull;
    if (layer == null) return null;
    return (layer: layer, home: home);
  }

  /// Opens the edit panel for material [layerId], showing a frame where it
  /// is on screen so it can be seen (and dragged) in the preview.
  void _openMaterialEditor(String layerId) {
    _finishMaterialDrag();
    if (_editingMaterialId != layerId) _regionEdit.reset();
    final ps = context.read<ProjectService>();
    final home = ps.homeOf(widget.projectId, layerId);
    final layer = home == null
        ? null
        : ps
              .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
              .where((l) => l.id == layerId)
              .firstOrNull;
    setState(() {
      _editingMaterialId = layerId;
      _showStackOrder = false;
      _isPlaying = false;
      if (layer != null && layer.rangeMode == LayerRangeMode.frameRange) {
        final start = (layer.rangeStart ?? 1) - 1;
        final end = (layer.rangeEnd ?? start + 1) - 1;
        if (_currentFrame < start || _currentFrame > end) {
          _currentFrame = start.clamp(0, _totalFrames - 1);
        }
      }
    });
  }

  void _finishMaterialDrag({bool deferred = false}) {
    final drag = _materialDrag;
    _materialDrag = null;
    if (drag == null) return;
    final projectId = widget.projectId;
    final projects = _projectService;
    void record() => recordTimelineMaterialEdit(
      projects: projects,
      undo: drag.undo,
      projectId: projectId,
      before: drag.before,
    );
    if (deferred) {
      WidgetsBinding.instance.addPostFrameCallback((_) => record());
    } else {
      record();
    }
  }

  void _closeEditPanels() {
    _finishMaterialDrag();
    _regionEdit.reset();
    setState(() {
      _cropEditing = false;
      _editingMaterialId = null;
      _showStackOrder = false;
      _editingBounds = null;
      _editingBoundsKey = null;
    });
  }

  _TrackClip? _clipById(String id) => [
    ..._textClips,
    ..._imageClips,
    ..._videoClips,
  ].where((c) => c.id == id).firstOrNull;

  /// Mirrors an edited material into its clip on the track (its name, and
  /// for a video the opacity, sound and part used that playback follows).
  void _onMaterialLayerChanged(Layer layer) {
    // The panel's last redraw of a text can finish after the timeline has
    // been left.
    if (!mounted) return;
    final clip = _clipById(layer.id);
    if (clip == null) return;
    setState(() {
      clip.label = layer.name;
      clip.videoOpacity = layer.opacity / 100.0;
      if (clip.trackType == _ClipTrackType.video) {
        clip.volume = layer.videoVolume.clamp(0.0, 1.0);
        clip.useStart = layer.sourceTrimStart ?? clip.useStart;
        clip.useEnd = layer.sourceTrimEnd ?? clip.useEnd;
        clip.sourceFraction = layer.sourceTrimStartFraction;
        clip.playbackRate = layer.playbackRate;
        clip.soundFollowsSpeed = layer.videoSoundFollowsSpeed;
      }
    });
    if (clip.trackType == _ClipTrackType.video) _syncMediaPlayback();
  }

  // ─── Speed (長さ調整) ─────────────────────────────────────────

  /// The timeline length [clip] gets at [rate]: the source time it plays
  /// divided by the speed. A video plays its trimmed part; an audio clip
  /// keeps the part of its file it plays now.
  int _speedLength(_TrackClip clip, double rate) {
    final sourceFrames = clip.trackType == _ClipTrackType.video
        ? clip.useEnd + 1 - (clip.useStart + clip.sourceFraction)
        : clip.lengthFrames * clip.playbackRate;
    // A video that starts past its used range only holds its last frame:
    // there is no source time to speed up, so its length stays.
    if (sourceFrames <= 0) return clip.lengthFrames;
    return timelineLengthForSource(sourceFrames, rate);
  }

  int _speedEndFrame(_TrackClip clip, double rate) =>
      clip.startFrame + _speedLength(clip, rate) - 1;

  /// Why [clip] cannot become [length] frames long, or null when it can:
  /// it must stay within the scene and not overlap a clip on its row.
  String? _speedRefusal(_TrackClip clip, int length) {
    final l10n = AppLocalizations.of(context)!;
    final end = clip.startFrame + length;
    if (end > _totalFrames) return l10n.timelineClipSpeedPastSceneEnd;
    final overlaps = _clipsOfType(clip.trackType).any(
      (other) =>
          !identical(other, clip) &&
          other.trackRow == clip.trackRow &&
          other.isReadAloud == clip.isReadAloud &&
          other.startFrame < end &&
          other.startFrame + other.lengthFrames > clip.startFrame,
    );
    return overlaps ? l10n.timelineClipSpeedOverlap : null;
  }

  /// Changes an audio or read-aloud clip's speed (saved with the clip's
  /// other settings when its sheet closes).
  String? _applyAudioSpeed(_TrackClip clip, double rate) {
    if (!isValidPlaybackRate(rate)) {
      return AppLocalizations.of(context)!.timelineClipSpeedInvalid;
    }
    final length = _speedLength(clip, rate);
    final refusal = _speedRefusal(clip, length);
    if (refusal != null) return refusal;
    setState(() {
      clip.playbackRate = rate;
      clip.lengthFrames = length;
      clip.useEnd = clip.sourceAfter(length - 1).frame;
    });
    _syncMediaPlayback();
    return null;
  }

  /// Changes a video's speed: its length, and its keyframes retimed from
  /// the clip's start so the animation stays on the same source moments.
  String? _applyVideoSpeed(_TrackClip clip, double rate) {
    final l10n = AppLocalizations.of(context)!;
    if (!isValidPlaybackRate(rate)) return l10n.timelineClipSpeedInvalid;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return null;
    final length = _speedLength(clip, rate);
    final refusal = _speedRefusal(clip, length);
    if (refusal != null) return refusal;
    final ps = context.read<ProjectService>();
    final home =
        ps.homeOf(widget.projectId, clip.id) ??
        (sceneId: sceneId, frameIndex: _currentFrame);
    final layer = ps
        .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
        .where((l) => l.id == clip.id)
        .firstOrNull;
    if (layer == null) return null;
    final keyframes = layer.keyframes.isEmpty
        ? layer.keyframes
        : retimeKeyframes(
            layer.keyframes,
            anchorFrame: clip.startFrame,
            factor: rate / layer.playbackRate,
          );
    if (keyframes == null) return l10n.timelineClipSpeedKeyframeClash;
    ps.editTimeline(widget.projectId, 'Change clip speed', () {
      ps.updateLayer(
        projectId: widget.projectId,
        sceneId: home.sceneId,
        frameIndex: home.frameIndex,
        layer: layer.copyWith(
          playbackRate: rate,
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: clip.startFrame + 1,
          rangeEnd: clip.startFrame + length,
          keyframes: keyframes,
        ),
      );
    }, changesTiles: false);
    setState(() {
      clip.playbackRate = rate;
      clip.lengthFrames = length;
    });
    _syncMediaPlayback();
    return null;
  }

  Widget _buildEditPanel() {
    final sceneId = _selectedSceneId!;
    if (_showStackOrder) {
      return TimelineStackOrderPanel(
        projectId: widget.projectId,
        sceneId: sceneId,
        currentFrame: _currentFrameNotifier,
        onSeek: (f) => setState(() {
          _isPlaying = false;
          _currentFrame = f;
        }),
        onClose: () {
          // Back to the material being edited, if the order was opened from
          // its panel.
          if (_editingMaterialId != null) {
            setState(() => _showStackOrder = false);
          } else {
            _closeEditPanels();
          }
        },
      );
    }
    final ps = context.watch<ProjectService>();
    final found = _editingMaterial(ps);
    if (found == null) {
      // Deleted (or undone) while open, or on another scene.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editingMaterialId != null) _closeEditPanels();
      });
      return const SizedBox.shrink();
    }
    final clip = _clipById(found.layer.id);
    return TimelineMaterialEditPanel(
      key: ValueKey('material-edit-${found.layer.id}'),
      projectId: widget.projectId,
      layerId: found.layer.id,
      currentFrame: _currentFrameNotifier,
      onLayerChanged: _onMaterialLayerChanged,
      cropFrameOf: (layer) => _materialFrameOf(ps, layer, found.home),
      regionController: _regionEdit,
      onCropEditingChanged: (editing) {
        // Told from the panel's build or disposal: change after this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _cropEditing != editing) {
            setState(() => _cropEditing = editing);
          }
        });
      },
      videoSpeedEndFrameAt:
          clip == null || clip.trackType != _ClipTrackType.video
          ? null
          : (rate) => _speedEndFrame(clip, rate),
      onVideoSpeedChange: clip == null || clip.trackType != _ClipTrackType.video
          ? null
          : (rate) => _applyVideoSpeed(clip, rate),
      onSeek: (f) => setState(() {
        _isPlaying = false;
        _currentFrame = f;
      }),
      onShowStackOrder: () => setState(() => _showStackOrder = true),
      onMoveToRow: (row) => _moveMaterialToRow(found.layer.id, row),
      onClose: _closeEditPanels,
      onDuplicate: clip == null ? () {} : () => _duplicateClip(clip),
      onDelete: () {
        final target = clip;
        _closeEditPanels();
        if (target == null) return;
        setState(() {
          _videoClips.remove(target);
          _imageClips.remove(target);
          _textClips.remove(target);
        });
        _deletePersistedClip(target, sceneId);
      },
    );
  }

  /// Moves material [layerId] to [row] of its kind (one past the last: a new
  /// row), folding away the row it leaves when that is now empty.
  void _moveMaterialToRow(String layerId, int row) {
    final sceneId = _selectedSceneId;
    final clip = _clipById(layerId);
    if (sceneId == null || clip == null) return;
    final ps = context.read<ProjectService>();
    final found = _editingMaterial(ps);
    if (found == null || found.layer.id != layerId) return;
    ps.editTimeline(widget.projectId, 'Move material to row', () {
      final kind = _rowKindOf(clip.trackType);
      final rows = ps.rowNamesOf(widget.projectId, sceneId, kind).length;
      var target = row;
      if (target >= rows) {
        ps.addTrackRow(widget.projectId, sceneId, kind);
        target = rows;
      }
      final oldRow = clip.trackRow;
      ps.updateLayer(
        projectId: widget.projectId,
        sceneId: found.home.sceneId,
        frameIndex: found.home.frameIndex,
        layer: found.layer.copyWith(trackRow: target),
      );
      setState(() => clip.trackRow = target);
      final stillUsed = _clipsOfType(
        clip.trackType,
      ).any((c) => c.trackRow == oldRow);
      if (oldRow > 0 &&
          !stillUsed &&
          ps.removeTrackRow(widget.projectId, sceneId, kind, oldRow)) {
        // The rows after it moved up one.
        _loadClipsFromProject(sceneId);
      }
    }, changesTiles: false);
  }

  /// The drag handles over the preview for the material being edited at
  /// [frameIndex], or a note when it is not on screen at that frame.
  /// The part of [layer]'s picture the material is drawn in (canvas pixels):
  /// the crop is of this part. An image's drawn part comes from its pixels;
  /// a video's frames are fitted, centred, into the canvas by their picture
  /// size (the whole canvas until that size is read).
  Rect _materialFrameOf(ProjectService ps, Layer layer, LayerHome home) {
    final tm = ps.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth.toDouble();
    final h = tm.canvasHeight.toDouble();
    final whole = Rect.fromLTWH(0, 0, w, h);
    if (layer.type == LayerType.timelineVideo) {
      final id = layer.materialId;
      final size = id == null ? null : _videoDisplaySizeOf(id);
      return size == null ? whole : fittedContentRect(size, w, h);
    }
    return tm.contentBounds(
          ps.tileKeyFor(
            widget.projectId,
            home.sceneId,
            home.frameIndex,
            layer.id,
          ),
        ) ??
        whole;
  }

  /// The picture size of video material [materialId], or null while it is
  /// read (the timeline is rebuilt when it is known).
  Size? _videoDisplaySizeOf(String materialId) {
    if (_videoDisplaySizes.containsKey(materialId)) {
      return _videoDisplaySizes[materialId];
    }
    final frames = _previewVideoFrames;
    if (frames == null) return null;
    _videoDisplaySizes[materialId] = null;
    frames.timelineOf(materialId).then((result) {
      if (!mounted || result is! VideoTimelineReady) return;
      final w = result.timeline.displayWidth;
      final h = result.timeline.displayHeight;
      if (w == null || h == null || w <= 0 || h <= 0) return;
      setState(
        () => _videoDisplaySizes[materialId] = Size(w.toDouble(), h.toDouble()),
      );
    }, onError: (Object _) {});
    return null;
  }

  Widget? _buildMaterialGizmo(ProjectService ps, int frameIndex) {
    if (_showStackOrder) return null;
    final found = _editingMaterial(ps);
    if (found == null) return null;
    final layer = found.layer;
    final start = (layer.rangeStart ?? 1) - 1;
    final end = (layer.rangeEnd ?? start + 1) - 1;
    if (layer.rangeMode == LayerRangeMode.frameRange &&
        (frameIndex < start || frameIndex > end)) {
      final l10n = AppLocalizations.of(context)!;
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            l10n.timelineMaterialOutOfRange(start + 1, end + 1),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
        ),
      );
    }
    final tm = ps.tileManagerOf(widget.projectId);
    final boundsKey = (layer.id, identityHashCode(layer.textObject));
    if (_editingBoundsKey != boundsKey) {
      _editingBoundsKey = boundsKey;
      _editingBounds = tm.contentBounds(
        ps.tileKeyFor(
          widget.projectId,
          found.home.sceneId,
          found.home.frameIndex,
          layer.id,
        ),
      );
    }
    final cameraKeyframes = ps.cameraKeyframesOf(
      widget.projectId,
      found.home.sceneId,
    );
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final camera = cameraKeyframes.isEmpty
        ? null
        : CameraEngine().valueAt(cameraKeyframes, frameIndex);
    final isPicture =
        layer.type == LayerType.timelineImage ||
        layer.type == LayerType.timelineVideo;
    if (isPicture) {
      // The panel's 範囲選択 section swaps in its own handles.
      return ListenableBuilder(
        listenable: _regionEdit,
        builder: (context, _) => _regionEdit.editing
            ? _buildRegionGizmo(ps, layer, frameIndex, project, camera)
            : _buildPictureGizmo(ps, found, frameIndex, project, camera),
      );
    }
    return _buildTransformGizmo(ps, layer, frameIndex, camera);
  }

  /// The preview's handles for selecting parts of the image or video being
  /// edited and changing a moved or copied part.
  Widget _buildRegionGizmo(
    ProjectService ps,
    Layer layer,
    int frameIndex,
    Project? project,
    CameraKeyframe? camera,
  ) {
    final tm = ps.tileManagerOf(widget.projectId);
    return MaterialRegionGizmo(
      key: ValueKey('material-region-gizmo-${layer.id}'),
      canvasWidth: tm.canvasWidth,
      canvasHeight: tm.canvasHeight,
      outputWidth: project?.exportWidth,
      outputHeight: project?.exportHeight,
      value: materialTransformAt(layer, frameIndex),
      camera: camera,
      shape: _regionEdit.shape,
      selection: _regionEdit.selection,
      onSelectionChanged: (next) => _regionEdit.selection = next,
      edit: _regionEdit.activeIn(layer.regionEdits),
      onChangeEnd: _finishMaterialDrag,
      onEditChanged: (next) {
        final current = _editingMaterial(ps);
        if (current == null || current.layer.id != layer.id) return;
        final edits = current.layer.regionEdits;
        if (!edits.any((e) => e.id == next.id)) return;
        final undo = context.read<UndoManager?>();
        if (undo != null) {
          _materialDrag ??= (before: current.layer, undo: undo);
        }
        ps.updateLayer(
          projectId: widget.projectId,
          sceneId: current.home.sceneId,
          frameIndex: current.home.frameIndex,
          recordUndo: false,
          layer: current.layer.copyWith(
            regionEdits: [for (final e in edits) e.id == next.id ? next : e],
          ),
        );
      },
    );
  }

  /// The crop's handles while the panel shows the crop, otherwise the
  /// material's own.
  Widget _buildPictureGizmo(
    ProjectService ps,
    ({Layer layer, LayerHome home}) found,
    int frameIndex,
    Project? project,
    CameraKeyframe? camera,
  ) {
    final layer = found.layer;
    final tm = ps.tileManagerOf(widget.projectId);
    if (_cropEditing) {
      return MaterialCropGizmo(
        key: ValueKey('material-crop-gizmo-${layer.id}'),
        canvasWidth: tm.canvasWidth,
        canvasHeight: tm.canvasHeight,
        outputWidth: project?.exportWidth,
        outputHeight: project?.exportHeight,
        value: materialTransformAt(layer, frameIndex),
        frame: _materialFrameOf(ps, layer, found.home),
        crop: layer.crop,
        camera: camera,
        onChangeEnd: _finishMaterialDrag,
        onChanged: (next) {
          final current = _editingMaterial(ps);
          if (current == null || current.layer.id != layer.id) return;
          if (current.layer.crop == next) return;
          final undo = context.read<UndoManager?>();
          if (undo != null) {
            _materialDrag ??= (before: current.layer, undo: undo);
          }
          ps.updateLayer(
            projectId: widget.projectId,
            sceneId: current.home.sceneId,
            frameIndex: current.home.frameIndex,
            recordUndo: false,
            layer: current.layer.copyWith(crop: next),
          );
        },
      );
    }
    return _buildTransformGizmo(ps, layer, frameIndex, camera);
  }

  /// The material's own handles: move, resize and turn it.
  Widget _buildTransformGizmo(
    ProjectService ps,
    Layer layer,
    int frameIndex,
    CameraKeyframe? camera,
  ) {
    final tm = ps.tileManagerOf(widget.projectId);
    return MaterialTransformGizmo(
      key: ValueKey('material-gizmo-${layer.id}'),
      onChangeEnd: _finishMaterialDrag,
      canvasWidth: tm.canvasWidth,
      canvasHeight: tm.canvasHeight,
      outputWidth: ps.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull
          ?.exportWidth,
      outputHeight: ps.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull
          ?.exportHeight,
      contentBounds: _editingBounds,
      value: materialTransformAt(layer, frameIndex),
      camera: camera,
      onChanged: (next) {
        final current = _editingMaterial(ps);
        if (current == null || current.layer.id != layer.id) return;
        final previous = materialTransformAt(current.layer, frameIndex);
        if (previous.x == next.x &&
            previous.y == next.y &&
            previous.scale == next.scale &&
            previous.rotation == next.rotation) {
          return;
        }
        final undo = context.read<UndoManager?>();
        if (undo != null) _materialDrag ??= (before: current.layer, undo: undo);
        ps.updateLayer(
          projectId: widget.projectId,
          sceneId: current.home.sceneId,
          frameIndex: current.home.frameIndex,
          recordUndo: false,
          layer: current.layer.copyWith(
            keyframes: editMaterialTransform(
              current.layer,
              frameIndex,
              (k) => k.copyWith(
                x: next.x,
                y: next.y,
                scale: next.scale,
                rotation: next.rotation,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moreMenu(AppLocalizations l10n, {ButtonStyle? style}) =>
      PopupMenuButton<String>(
        key: const ValueKey('timelineMoreMenu'),
        style: style,
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          if (action == 'autofill') _showAutofillDialog();
          if (action == 'automation') _showCustomAutomationManager();
          if (action == 'save_tree') {
            _runAutomationBlockedAction(
              () =>
                  context.push('/save-tree/${widget.projectId}?entry=timeline'),
            );
          }
          if (action == 'export') {
            _runAutomationBlockedAction(
              () => context.push('/export/${widget.projectId}'),
            );
          }
          if (action == 'export_frame') _exportCurrentFrameImage();
          if (action == 'duration') _showDurationChangeDialog();
          if (action == 'canvas_size') _showCanvasSizeChangeDialog();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'automation',
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  size: 18,
                  color: PopupMenuTheme.of(context).iconColor,
                ),
                const SizedBox(width: 8),
                Text(l10n.customAutomationTitle),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'save_tree',
            child: Text(
              context.read<SaveTreeService>().isTreeMode
                  ? l10n.saveTreeScreenTitleTree
                  : l10n.saveTreeScreenTitleSlot,
            ),
          ),
          PopupMenuItem(
            value: 'autofill',
            child: Text(l10n.layerPanelMenuRunAutofill),
          ),
          PopupMenuItem(
            value: 'duration',
            child: Text(l10n.timelineDurationChangeMenuItem),
          ),
          PopupMenuItem(
            value: 'canvas_size',
            child: Text(l10n.timelineCanvasSizeChangeMenuItem),
          ),
          PopupMenuItem(
            value: 'export',
            child: Text(l10n.timelineExportMenuItem),
          ),
          PopupMenuItem(
            value: 'export_frame',
            child: Text(l10n.timelineExportFrameMenuItem),
          ),
        ],
      );

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context)!;
    final projectName =
        context
            .watch<ProjectService>()
            .projects
            .where((p) => p.id == widget.projectId)
            .firstOrNull
            ?.name ??
        l10n.timelineDefaultProjectName;
    final undoManager = context.watch<UndoManager>();
    final backToCanvas = IconButton(
      icon: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back),
          Icon(Icons.palette_outlined, size: 18),
        ],
      ),
      tooltip: l10n.timelineBackToCanvasTooltip,
      onPressed: _saveAndGoToCanvas,
    );
    final title = Text(
      projectName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: localizedHeadingStyle(
        context,
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
    final home = IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: l10n.timelineBackToProjectListTooltip,
      onPressed: _confirmBackToProjectList,
    );
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.undo),
        tooltip: l10n.commonUndo,
        onPressed: undoManager.canUndo
            ? () => _applyHistory(redo: false)
            : null,
      ),
      IconButton(
        icon: const Icon(Icons.redo),
        tooltip: l10n.commonRedo,
        onPressed: undoManager.canRedo ? () => _applyHistory(redo: true) : null,
      ),
      // 三点メニュー（保存ボタン・プロジェクト保存ボタンはセーブツリー
      // （設定によってはセーブスロット）と役割が被っていた
      // ため削除し、セーブツリー/スロット・自動塗り実行・書き出しの
      // 3項目のみに整理した）。
      _moreMenu(l10n),
      const HelpButton(topic: 'タイムライン'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ボタン（キャンバスへ戻る〔2つの印〕・ホーム・取り消し・やり直し・
          // 三点・ヘルプ）を1行に並べると作品名に残る幅。作品名が数文字しか
          // 出ない幅（360pxで「散…」の1字だった）では2行にし、1行目に
          // 戻る・作品名・ホーム、2行目の左に取り消し・やり直し（キャンバスの
          // 上部バーと同じ側）、右に三点・ヘルプを置く。
          // 素材の編集・重なり順のパネルを開いている間は1行のまま（パネルは
          // タイムラインの場所に出るので、上部バーを2行にするとパネルが
          // 48px低くなる。パネルの見出しが編集している物の名前を出す）。
          const buttons = 58.0 + 5 * kMinInteractiveDimension;
          final titleRoom = constraints.maxWidth - buttons;
          final panelOpen = _editingMaterialId != null || _showStackOrder;
          if (titleRoom < 8 ||
              (!panelOpen &&
                  titleRoom < MediaQuery.textScalerOf(context).scale(112))) {
            return Column(
              children: [
                Row(
                  children: [
                    backToCanvas,
                    Expanded(child: title),
                    home,
                  ],
                ),
                Row(
                  children: [
                    ...actions.take(2),
                    const Spacer(),
                    ...actions.skip(2),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              backToCanvas,
              Expanded(child: title),
              home,
              ...actions,
            ],
          );
        },
      ),
    );
  }

  /// プレビューの絵。フレーム数と全画面操作は画像外ではなく
  /// _buildPreviewBandの端に固定し、絵との重なりを許容する。
  Widget _buildPreviewContent() {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final sceneId = _selectedSceneId;
    return Container(
      // Around the picture, the canvas's surroundings (the canvas's
      // kCanvasOutsideColor); behind it, the project's background (see
      // _TimelinePreview), as on the canvas.
      decoration: BoxDecoration(
        color: ThemeService.activeColorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: sceneId == null
          ? Center(
              child: Text(
                l10n.timelinePreviewPlaceholder,
                style: TextStyle(
                  color: ThemeService.activeColorScheme.onSurfaceVariant,
                ),
              ),
            )
          // 再生位置に追従して作り直すのはこの1枚だけでよい。
          // 再生タイマーはsetStateを呼ばないので、ここを
          // ValueListenableBuilderで包まないとプレビューが止まる。
          : ValueListenableBuilder<int>(
              valueListenable: _currentFrameNotifier,
              builder: (context, frameIndex, _) {
                final stacked = ps.stackedLayersOf(
                  widget.projectId,
                  sceneId,
                  frameIndex,
                );
                final gizmo = _buildMaterialGizmo(ps, frameIndex);
                final picture = _TimelinePreview(
                  historyRevision: _historyPreviewRevision,
                  backgroundColor: _projectBackgroundOf(ps, widget.projectId),
                  tileManager: ps.tileManagerOf(widget.projectId),
                  layers: stacked.layers,
                  maskGroups: stacked.maskGroups,
                  sceneId: sceneId,
                  frameIndex: frameIndex,
                  outputWidth: ps.projects
                      .where((p) => p.id == widget.projectId)
                      .firstOrNull
                      ?.exportWidth,
                  outputHeight: ps.projects
                      .where((p) => p.id == widget.projectId)
                      .firstOrNull
                      ?.exportHeight,
                  cameraKeyframes: ps.cameraKeyframesOf(
                    widget.projectId,
                    sceneId,
                  ),
                  effectFilters: ps.effectFiltersOf(widget.projectId, sceneId),
                  layerHomes: ps.layerHomesOf(widget.projectId),
                  groups: ps.layerGroupsOf(widget.projectId, sceneId),
                );
                if (gizmo == null) return picture;
                return Stack(fit: StackFit.expand, children: [picture, gizmo]);
              },
            ),
    );
  }

  /// プレビュー欄の操作（フレーム数・全画面）の大きさと、欄の端からの距離。
  static const double _previewControlSize = 48;
  static const double _previewControlInset = 8;

  /// プロジェクトの縦横比（書き出しの大きさ。分からなければ16:9）。
  double _previewAspect(ProjectService ps) {
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    return (project != null && project.exportHeight > 0)
        ? project.exportWidth / project.exportHeight
        : 16 / 9;
  }

  /// 全画面ボタンはヘッダー直下の右端、フレーム数はサイズ変更
  /// ハンドル直上の左端へ固定する。両者の位置にキャンバスの画像矩形を
  /// 使用しないので、キャンバスが大きければ重なってよい。
  /// 全画面プレビューでは入口の全画面ボタンを隠す。
  Widget _buildPreviewBand({
    required double aspect,
    required bool inFullscreen,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const edge = _previewControlInset;
    final sceneId = _selectedSceneId;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // Only the available band and project aspect determine picture size.
        // Controls are not safe zones: they can overlap the artwork.
        var pictureWidth = aspect > 0
            ? math.max(0.0, math.min(width, height * aspect))
            : 0.0;
        // PC/DeXの通常の欄では横に間延びしないよう上限を設ける。
        if (!inFullscreen && isWideScreen(context)) {
          pictureWidth = math.min(pictureWidth, 900);
        }
        final pictureHeight = aspect > 0 ? pictureWidth / aspect : 0.0;
        return Stack(
          key: const Key('timelinePreviewArea'),
          children: [
            // 描かれた絵そのもの（timelinePreviewPicture）は、この枠の中に
            // 絵の縦横比で収まる（_TimelinePreview）。
            Center(
              child: SizedBox(
                width: pictureWidth,
                height: pictureHeight,
                child: _buildPreviewContent(),
              ),
            ),
            // 長いフレーム数は、絵との間（操作の大きさ）に収まるよう縮める。
            Positioned(
              left: edge,
              bottom: edge,
              width: _previewControlSize,
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _currentFrameNotifier,
                    builder: (_, frame, _) => Text(
                      '${frame.clamp(0, _totalFrames > 0 ? _totalFrames - 1 : 0) + 1}/$_totalFrames',
                      key: const Key('timelinePreviewFrameCount'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!inFullscreen)
              Positioned(
                right: edge,
                top: edge,
                child: FirstUseTooltip(
                  tooltipKey: 'timeline_preview_fullscreen',
                  message: l10n.timelinePreviewFullscreenTip,
                  child: IconButton(
                    key: const Key('timelinePreviewFullscreenButton'),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.standard,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: Icon(
                      Icons.fullscreen,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: l10n.timelinePreviewFullscreenTooltip,
                    onPressed: sceneId == null
                        ? null
                        : () => setState(() => _isPreviewFullscreen = true),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 全画面表示中の「戻る」：全画面を閉じてタイムラインへ戻る。上に
  /// ダイアログ等が開いているときは、それが「戻る」を受ける（falseを返す）。
  bool _closePreviewFullscreenByBack() {
    if (!mounted || !_isPreviewFullscreen) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    setState(() => _isPreviewFullscreen = false);
    return true;
  }

  /// 全画面プレビュー表示（isPreviewFullscreen）専用。周囲に空きがあれば
  /// 目一杯まで拡大する。
  Widget _buildPreview() => Expanded(
    flex: 3,
    child: _buildPreviewBand(
      aspect: _previewAspect(context.watch<ProjectService>()),
      inFullscreen: true,
    ),
  );

  /// 通常表示のプレビュー欄。底辺のドラッグハンドルで縦方向のサイズを
  /// 変更できるようにする。高さはアプリ全体で共通の割合として
  /// SettingsServiceへ保存され、作業を中断したり別プロジェクトへ移動しても
  /// 最後に設定した位置が引き継がれる。ドラッグ中は指を離すまでローカル
  /// 状態のみを更新し、離した瞬間に確定値を保存する。
  Widget _buildPreviewWithHandle(double maxAvailableHeight) {
    final settings = context.watch<SettingsService>();
    final aspect = _previewAspect(context.watch<ProjectService>());
    final maxH = maxAvailableHeight > 0 ? maxAvailableHeight : 600.0;
    // The drag handle determines the preview band height. The canvas ratio
    // must never force extra control gutters or limit this drag range.
    final maxPreviewHeight = maxH;
    final baseHeight = (maxH * settings.timelinePreviewHeightFraction).clamp(
      0.0,
      maxPreviewHeight,
    );
    final previewHeight = (_previewHeightDragOverride ?? baseHeight).clamp(
      0.0,
      maxPreviewHeight,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final gripHeight = math.min(22.0, constraints.maxHeight);
        final allocatedPreviewHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight - gripHeight
            : maxPreviewHeight;
        final visiblePreviewHeight = math.min(
          previewHeight,
          allocatedPreviewHeight,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ドラッグハンドルで指定した高さぶん、プレビュー画像自体が実際に
            // 拡大縮小されるようにする（以前は外枠の高さだけが変わり、内側の
            // 画像はBoxFit.containの都合で横幅が頭打ちになるとそれ以上大きく
            // ならず、「ハンドルが下のタイムラインにしか効いていないように
            // 見える」問題があった）。AspectRatioでキャンバスの実際の縦横比に
            // 合わせて幅も高さに追従させ、画面幅を超える場合のみ幅が頭打ちに
            // なるようにする。
            SizedBox(
              height: visiblePreviewHeight,
              width: double.infinity,
              child: _buildPreviewBand(aspect: aspect, inFullscreen: false),
            ),
            // ヒット領域はシークバー等の他の操作と混同しないよう、見た目の
            // グリップより広めに取っている（ドラッグ開始位置が少しずれても
            // 確実にリサイズとして認識されるようにするため）。
            // Resize grip only; transport time labels live beside skip buttons.
            SizedBox(
              height: gripHeight,
              child: Center(
                child: GestureDetector(
                  key: const Key('timelinePreviewResizeHandle'),
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onVerticalDragUpdate: (d) {
                    setState(() {
                      final current =
                          (_previewHeightDragOverride ?? baseHeight) +
                          d.delta.dy;
                      _previewHeightDragOverride = current.clamp(
                        0.0,
                        maxPreviewHeight,
                      );
                    });
                  },
                  onVerticalDragEnd: (_) {
                    final h = _previewHeightDragOverride;
                    if (h != null) {
                      context
                          .read<SettingsService>()
                          .setTimelinePreviewHeightFraction(h / maxH);
                    }
                  },
                  child: SizedBox(
                    width: 80,
                    height: 22,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// プレビューと再生バーの間のシークバー。ドラッグで任意のフレームへ
  /// 直接移動できる。
  Widget _buildSeekBar() {
    final maxFrame = (_totalFrames - 1).clamp(0, 1 << 30);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
        // コマ送りボタンは再生ボタンの左右に既にあるため、シークバー自体には
        // ±ボタンを表示しない（役割が重複するため）。
        // つまみの位置も再生位置に追従させる必要があるため、ここだけを
        // 購読する（再生タイマーはsetStateを呼ばない）。
        child: ValueListenableBuilder<int>(
          valueListenable: _currentFrameNotifier,
          builder: (context, frame, _) => SteppedSlider(
            value: frame.clamp(0, maxFrame).toDouble(),
            min: 0,
            max: maxFrame.toDouble(),
            divisions: maxFrame > 0 ? maxFrame : null,
            showSteppers: false,
            onChanged: (v) {
              if (_isPlaying) _togglePlay();
              setState(() => _currentFrame = v.round());
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final projectFps = project?.fps ?? 24;
    final fps = projectFps > 0 ? projectFps : 24;
    final timeColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final timeStyle = TextStyle(fontSize: 12, color: timeColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five transport buttons and two time labels must fit at 320px.
          // Labels scale down only when the actual duration grows too long.
          final buttonWidth = math.min(
            48.0,
            math.max(36.0, constraints.maxWidth / 7.0),
          );
          final buttonConstraints = BoxConstraints.tightFor(
            width: buttonWidth,
            height: buttonWidth,
          );
          Widget transportButton(
            IconData icon,
            String tooltip,
            VoidCallback onPressed,
          ) => IconButton(
            icon: Icon(icon),
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: buttonConstraints,
            onPressed: onPressed,
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentFrameNotifier,
                      builder: (_, frame, _) => Text(
                        '${(frame / fps).toStringAsFixed(1)}s',
                        key: const Key('timelineCurrentSeconds'),
                        style: timeStyle,
                      ),
                    ),
                  ),
                ),
              ),
              transportButton(
                Icons.skip_previous,
                l10n.timelineSkipToStart,
                () => setState(() => _currentFrame = 0),
              ),
              transportButton(
                Icons.fast_rewind,
                l10n.timelineStepBack,
                _stepFramePrevious,
              ),
              transportButton(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                _isPlaying ? l10n.commonPause : l10n.commonPlay,
                _togglePlay,
              ),
              transportButton(
                Icons.fast_forward,
                l10n.timelineStepForward,
                _stepFrameNext,
              ),
              transportButton(
                Icons.skip_next,
                l10n.timelineSkipToEnd,
                () => setState(() => _currentFrame = _totalFrames - 1),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${(_totalFrames / fps).toStringAsFixed(1)}s',
                      key: const Key('timelineTotalSeconds'),
                      style: timeStyle,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _addMaterialMenu(AppLocalizations l10n, {ButtonStyle? style}) {
    final canUseWatermark = context.watch<PremiumService>().isFeatureAvailable(
      PremiumFeature.watermark,
    );
    return PopupMenuButton<Object>(
      key: const Key('timelineAddMaterialMenu'),
      style: style,
      // PCの上部バーでは隣のボタン（PcToolButton）と同じ18px、スマホの
      // ツールバーでは隣のボタンと同じ20px。
      icon: Icon(Icons.add_circle_outline, size: style == null ? 20 : 18),
      tooltip: l10n.timelineAddMaterialTooltip,
      onSelected: (action) {
        if (action is _ClipTrackType) {
          _addMaterialOfType(action);
        } else if (action == _TimelineToolbarAction.readAloud) {
          _showReadAloudDialog();
        } else if (action == _TimelineToolbarAction.watermark) {
          // Recheck at selection, including changes while the menu is open.
          if (context.read<PremiumService>().isFeatureAvailable(
            PremiumFeature.watermark,
          )) {
            _showWatermarkPicker();
          } else {
            showPremiumBanner(context, feature: PremiumFeature.watermark);
          }
        }
      },
      itemBuilder: (_) => [
        for (final (type, icon, label) in [
          (_ClipTrackType.text, Icons.text_fields, l10n.timelineAddTextTooltip),
          (_ClipTrackType.image, Icons.image, l10n.timelineAddImageTooltip),
          (_ClipTrackType.video, Icons.videocam, l10n.timelineAddVideoTooltip),
          (
            _ClipTrackType.audio,
            Icons.audiotrack,
            l10n.timelineAddAudioTooltip,
          ),
        ])
          PopupMenuItem<Object>(
            value: type,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: PopupMenuTheme.of(context).iconColor,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: localizedHeadingStyle(context, const TextStyle()),
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem<Object>(
          key: const Key('timelineReadAloudMenuItem'),
          value: _TimelineToolbarAction.readAloud,
          child: Row(
            children: [
              Icon(
                Icons.record_voice_over_outlined,
                size: 20,
                color: PopupMenuTheme.of(context).iconColor,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  MakingStrings.readAloud(context),
                  style: localizedHeadingStyle(context, const TextStyle()),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          key: const Key('timelineAddWatermarkMenuItem'),
          value: _TimelineToolbarAction.watermark,
          child: Row(
            children: [
              Icon(
                Icons.branding_watermark,
                size: 20,
                color: PopupMenuTheme.of(context).iconColor,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.timelineAddWatermarkTooltip,
                  style: localizedHeadingStyle(context, const TextStyle()),
                ),
              ),
              if (!canUseWatermark) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: PopupMenuTheme.of(context).iconColor,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _timelineSelectionControls(
    AppLocalizations l10n, {
    required bool showLabels,
  }) => [
    PopupMenuButton<_TimelineSelection>(
      key: const Key('timelineSelectionMenu'),
      icon: showLabels ? null : const Icon(Icons.checklist, size: 20),
      tooltip: l10n.toolbarItemSelect,
      onSelected: (target) => setState(() => _setTimelineSelection(target)),
      itemBuilder: (_) => [
        for (final target in _TimelineSelection.values)
          PopupMenuItem(
            value: target,
            enabled: switch (target) {
              _TimelineSelection.scenes =>
                context
                    .read<ProjectService>()
                    .scenesOf(widget.projectId)
                    .isNotEmpty,
              _TimelineSelection.frames => _selectedSceneId != null,
              _TimelineSelection.clips => _allClips.isNotEmpty,
            },
            child: Text(_timelineSelectionLabel(l10n, target)),
          ),
      ],
      child: showLabels
          ? _timelineToolbarLabel(Icons.checklist, l10n.toolbarItemSelect)
          : null,
    ),
    if (_canPasteTimelineSelection)
      if (showLabels)
        Tooltip(
          message: _timelinePasteLabel(l10n),
          child: TextButton.icon(
            key: const Key('timelinePasteButton'),
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste, size: 19),
            label: Text(l10n.commonPaste),
          ),
        )
      else
        IconButton(
          key: const Key('timelinePasteButton'),
          tooltip: _timelinePasteLabel(l10n),
          onPressed: _pasteFromClipboard,
          icon: const Icon(Icons.content_paste, size: 20),
        ),
  ];

  Widget _buildToolbar() {
    final l10n = AppLocalizations.of(context)!;
    if (_isSplitMode) return _buildSplitToolbar(l10n);
    if (_isSceneCursorActive || _isFrameCursorActive) {
      return _buildTimelinePlacementToolbar(l10n);
    }
    final selection = _timelineSelection;
    if (selection != null) return _buildSelectionToolbar(l10n, selection);
    final width = MediaQuery.sizeOf(context).width;
    final showLabels = width >= 600;
    final controls = <Widget>[
      _addMaterialMenu(l10n),
      IconButton(
        key: const Key('timelineSplitModeButton'),
        icon: const Icon(Icons.call_split, size: 20),
        onPressed: () {
          if (_isPlaying) _togglePlay();
          setState(() => _isSplitMode = true);
        },
        tooltip: Localizations.localeOf(context).languageCode == 'ja'
            ? '分割'
            : 'Split',
      ),
      IconButton(
        icon: const Icon(Icons.movie_filter, size: 20),
        onPressed: _showEffectFilterDialog,
        tooltip: l10n.timelineEffectFilterLabel,
      ),
      IconButton(
        icon: const Icon(Icons.camera, size: 20),
        onPressed: _addCameraKf,
        tooltip: l10n.timelineAddCameraKfTooltip,
      ),
      IconButton(
        icon: const Icon(Icons.push_pin_outlined, size: 20),
        onPressed: _showAddMarkerDialog,
        tooltip: l10n.timelineMarkerTrackLabel,
      ),
      IconButton(
        icon: const Icon(Icons.layers_outlined, size: 20),
        onPressed: _selectedSceneId == null
            ? null
            : () => setState(() {
                _editingMaterialId = null;
                _showStackOrder = true;
              }),
        tooltip: l10n.timelineStackOrderTitle,
      ),
    ];
    // 帯は画面の地の色のまま、上下の細い線だけで区切る（以前は灰色の面の
    // 帯で、プレビューとタイムラインの間に別の面がもう1段できていた）。
    final lines = BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: width <= 360 ? 0 : 8),
      decoration: BoxDecoration(
        border: Border(top: lines, bottom: lines),
      ),
      child: Row(
        children: [
          ..._timelineSelectionControls(l10n, showLabels: showLabels),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final control in controls)
                    SizedBox(width: 44, height: 48, child: control),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              key: const Key('timelineExportButton'),
              icon: const Icon(Icons.upload_file, size: 20),
              onPressed: () => context.push('/export/${widget.projectId}'),
              tooltip: l10n.transferExport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitToolbar(AppLocalizations l10n) {
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
    final targets = _allClips.where(
      (clip) =>
          _currentFrame > clip.startFrame &&
          _currentFrame < clip.startFrame + clip.lengthFrames,
    );
    final canApply = targets.isNotEmpty;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isJapanese
                  ? '分割モード：再生ヘッド位置で分割'
                  : 'Split mode: split at the playhead',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: const Key('timelineSplitApplyButton'),
            tooltip: l10n.commonApply,
            onPressed: canApply ? _applySplitAtCurrentFrame : null,
            icon: const Icon(Icons.check),
          ),
          IconButton(
            key: const Key('timelineSplitCancelButton'),
            tooltip: l10n.commonCancel,
            onPressed: () => setState(() => _isSplitMode = false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  /// Adds a material of [type] from the toolbar's 素材を追加 menu.
  void _addMaterialOfType(_ClipTrackType type) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = ThemeService.activeColorScheme;
    switch (type) {
      case _ClipTrackType.text:
        _showAddTextDialog();
      case _ClipTrackType.image:
        _showAddClipDialog(
          l10n.projectListMaterialImage,
          _imageClips,
          scheme.secondary,
          type,
        );
      case _ClipTrackType.video:
        _showAddClipDialog(
          l10n.projectListMaterialVideo,
          _videoClips,
          scheme.primary,
          type,
        );
      case _ClipTrackType.audio:
        _showAddClipDialog(
          l10n.projectListMaterialAudio,
          _audioClips,
          scheme.tertiary,
          type,
        );
    }
  }

  Future<void> _showReadAloudDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final tts = AndroidTtsService.instance;
    List<AndroidTtsVoice> voices;
    try {
      voices = await tts.offlineVoices();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(MakingStrings.noVoices(context))));
      return;
    }
    if (!mounted) return;
    if (voices.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(MakingStrings.readAloud(context)),
          content: Text(MakingStrings.noVoices(context)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonClose),
            ),
            FilledButton.tonal(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await tts.openVoiceSettings();
                } catch (error, stackTrace) {
                  AppErrorReporter.record(error, stackTrace);
                }
              },
              child: Text(MakingStrings.manageVoices(context)),
            ),
          ],
        ),
      );
      return;
    }

    final language = Localizations.localeOf(context).languageCode;
    final preferred = voices
        .where((voice) => voice.locale.startsWith(language))
        .firstOrNull;
    final textController = TextEditingController();
    var selectedVoiceName = (preferred ?? voices.first).name;
    var speechRate = 1.0;
    var pitch = 1.0;
    var startFrame = _currentFrame
        .clamp(0, math.max(0, _totalFrames - 1))
        .toInt();
    var generating = false;
    var failed = false;

    // 打った文の欄は、閉じる動きが終わってからダイアログと一緒に破棄する
    // （showDialogが返った直後に破棄すると、閉じる途中の欄が破棄済みの
    // コントローラーを使う）。
    await showDialog<void>(
      context: context,
      builder: (_) => DisposeOnUnmount(
        controller: textController,
        builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            // 作っている間は閉じない（閉じた後に結果をダイアログへ書けない）。
            canPop: !generating,
            child: AlertDialog(
              insetPadding: typingDialogInsetPadding(
                dialogContext,
                usual: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              ),
              title: Text(MakingStrings.readAloud(context)),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('timelineReadAloudTextField'),
                        controller: textController,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 3500,
                        enabled: !generating,
                        onChanged: (_) => setDialogState(() => failed = false),
                        decoration: InputDecoration(
                          labelText: MakingStrings.speechText(context),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 選ぶ一覧は画面の書式で用紙の上に出すので、欄も
                      // メニューの面のテーマで描く。
                      MenuSurface(
                        child: DropdownButtonFormField<String>(
                          key: const Key('timelineReadAloudVoice'),
                          initialValue: selectedVoiceName,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: MakingStrings.voice(context),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final voice in voices)
                              DropdownMenuItem(
                                value: voice.name,
                                child: Text(
                                  voice.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: generating
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(
                                      () => selectedVoiceName = value,
                                    );
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 8),
                      LabeledSlider(
                        label: MakingStrings.rate(context),
                        value: speechRate,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        step: 0.1,
                        isInt: false,
                        valueText: '${speechRate.toStringAsFixed(2)}×',
                        onChanged: generating
                            ? null
                            : (value) =>
                                  setDialogState(() => speechRate = value),
                      ),
                      LabeledSlider(
                        label: MakingStrings.pitch(context),
                        value: pitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        step: 0.1,
                        isInt: false,
                        valueText: '${pitch.toStringAsFixed(2)}×',
                        onChanged: generating
                            ? null
                            : (value) => setDialogState(() => pitch = value),
                      ),
                      // フレームは表示（F1〜）と同じ1始まりの目盛りで持つ。
                      // 1フレームの作品でもスライダーが成り立つよう幅は2以上。
                      LabeledSlider(
                        label: MakingStrings.startFrame(context),
                        value: (startFrame + 1).toDouble(),
                        min: 1,
                        max: math.max(2, _totalFrames).toDouble(),
                        divisions: math.max(1, _totalFrames - 1),
                        valueText: 'F${startFrame + 1}',
                        onChanged: generating || _totalFrames <= 1
                            ? null
                            : (value) => setDialogState(
                                () => startFrame = (value.round() - 1)
                                    .clamp(0, _totalFrames - 1)
                                    .toInt(),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        MakingStrings.speechNotice(context),
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(
                                dialogContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      // 知らせはダイアログの幕の下に隠れるので、失敗は
                      // ダイアログの中に出す（打った文は残す）。
                      if (failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: IconNotice(
                            MakingStrings.speechFailed(context),
                            liveRegion: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: generating
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          try {
                            await tts.openVoiceSettings();
                          } catch (error, stackTrace) {
                            AppErrorReporter.record(error, stackTrace);
                          }
                        },
                  child: Text(MakingStrings.manageVoices(context)),
                ),
                TextButton(
                  onPressed: generating
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton.icon(
                  key: const Key('timelineReadAloudGenerateButton'),
                  onPressed: generating || textController.text.trim().isEmpty
                      ? null
                      : () async {
                          final sceneId = _selectedSceneId;
                          if (sceneId == null) return;
                          setDialogState(() {
                            generating = true;
                            failed = false;
                          });
                          File? generatedWav;
                          try {
                            final voice = voices.firstWhere(
                              (v) => v.name == selectedVoiceName,
                            );
                            final wav = await tts.synthesizeToFile(
                              text: textController.text,
                              voice: voice,
                              rate: speechRate,
                              pitch: pitch,
                            );
                            generatedWav = wav;
                            if (!mounted) return;
                            final materialService = context
                                .read<MaterialService>();
                            final asset = await materialService.addMaterial(
                              projectId: widget.projectId,
                              sourcePath: wav.path,
                              type: MaterialType.audio,
                            );
                            final savedPath = await materialService.pathOf(
                              widget.projectId,
                              asset.id,
                            );
                            if (!mounted || savedPath == null) {
                              throw StateError(
                                'Generated audio could not be stored.',
                              );
                            }
                            final project = context
                                .read<ProjectService>()
                                .projects
                                .where((p) => p.id == widget.projectId)
                                .firstOrNull;
                            final durationMs =
                                asset.duration?.inMilliseconds ?? 0;
                            final maxLength = math
                                .max(1, _totalFrames - startFrame)
                                .toInt();
                            final lengthFrames =
                                durationMs > 0 && project != null
                                ? (durationMs * project.fps / 1000)
                                      .ceil()
                                      .clamp(1, maxLength)
                                      .toInt()
                                : math.min(24, maxLength).toInt();
                            final label = timelineTextName(
                              textController.text,
                              MakingStrings.readAloud(context),
                            );
                            final clip = await _createPersistedClip(
                              sceneId: sceneId,
                              label: label,
                              startFrame: startFrame,
                              lengthFrames: lengthFrames,
                              color: ThemeService.activeColorScheme.tertiary,
                              trackType: _ClipTrackType.audio,
                              isReadAloud: true,
                              filePath: savedPath,
                              asset: asset,
                            );
                            if (!mounted) return;
                            if (clip == null) {
                              throw StateError(
                                'The speech clip could not be added.',
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            setState(() => _audioClips.add(clip));
                          } catch (error, stackTrace) {
                            AppErrorReporter.record(error, stackTrace);
                            if (!mounted || !dialogContext.mounted) return;
                            setDialogState(() {
                              generating = false;
                              failed = true;
                            });
                          } finally {
                            final temporary = generatedWav;
                            if (temporary != null) {
                              try {
                                if (await temporary.exists()) {
                                  await temporary.delete();
                                }
                              } catch (cleanupError, cleanupStack) {
                                AppErrorReporter.record(
                                  cleanupError,
                                  cleanupStack,
                                );
                              }
                            }
                          }
                        },
                  icon: generating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.record_voice_over_outlined),
                  label: Text(
                    generating
                        ? l10n.newProjectCreating
                        : MakingStrings.generateAndAdd(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 登録済みウォーターマーク一覧から選択して追加する（
  /// ウォーターマークは専用トラックを持たず、画像素材と同じレイヤー機構
  /// 〔LayerType.watermark〕を使ってタイムライン素材として追加する）。
  void _showWatermarkPicker() {
    if (!context.read<PremiumService>().isFeatureAvailable(
      PremiumFeature.watermark,
    )) {
      showPremiumBanner(context, feature: PremiumFeature.watermark);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final watermarkService = context.read<WatermarkService>();
    final assets = watermarkService.assets;
    if (assets.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
          // AlertDialogの`icon:`スロットへ入れると、Flutterが
          // タイトルを強制的に中央寄せにするため（dialog.dartの
          // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
          // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
          title: Row(
            children: [
              Expanded(child: Text(l10n.timelineWatermarkNotRegisteredTitle)),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: Text(l10n.timelineWatermarkNotRegisteredBody),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/settings/watermark');
              },
              child: Text(l10n.timelineOpenSettingsButton),
            ),
          ],
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.timelineWatermarkSelectTitle,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            for (final asset in assets)
              ListTile(
                leading: Icon(
                  asset.type == WatermarkAssetType.text
                      ? Icons.text_fields
                      : Icons.branding_watermark,
                ),
                title: Text(asset.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _addWatermarkLayer(asset);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 選択したウォーターマーク（画像 or 文字入力）をラスタライズし、
  /// LayerType.watermarkのレイヤーとして現在シーンへ追加する（表示範囲は
  /// デフォルトで全フレーム＝常時表示。以後の表示範囲・不透明度・差し替えは
  /// レイヤーパネルから調整できる）。
  Future<void> _addWatermarkLayer(WatermarkAsset asset) async {
    if (!mounted ||
        !context.read<PremiumService>().isFeatureAvailable(
          PremiumFeature.watermark,
        )) {
      if (mounted) {
        showPremiumBanner(context, feature: PremiumFeature.watermark);
      }
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    const defaultAngle = 0.0;
    const defaultScale = 0.25;
    final pixels = await _rasterizeWatermark(
      asset,
      w,
      h,
      angle: defaultAngle,
      scale: defaultScale,
    );
    if (pixels == null || !mounted) return;
    // Rasterization may outlive the server entitlement lease.
    if (!context.read<PremiumService>().isFeatureAvailable(
      PremiumFeature.watermark,
    )) {
      showPremiumBanner(context, feature: PremiumFeature.watermark);
      return;
    }

    projectService.editTimeline(widget.projectId, 'Add watermark', () {
      final layer = projectService.addLayer(
        projectId: widget.projectId,
        sceneId: sceneId,
        frameIndex: _currentFrame,
        type: LayerType.watermark,
        name: asset.name,
      );
      tileManager.replaceLayerPixels(
        frameLayerKey(sceneId, _currentFrame, layer.id),
        pixels,
      );
      // 既定は「常時表示」（全フレーム）。表示範囲・角度・大きさ・不透明度は
      // タイムラインの共通レイヤートラックでウォーターマークをタップすれば
      // いつでも変更できる（常時表示／エンドカード／任意フレーム
      // のみ表示はすべて表示範囲設定で実現する）。
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: sceneId,
        frameIndex: _currentFrame,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.allFrames,
          watermarkAssetId: asset.id,
          watermarkAngle: defaultAngle,
          watermarkScale: defaultScale,
        ),
      );
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.timelineWatermarkAddedSnackbar(asset.name))),
    );
  }

  Future<PlacedWatermarkSource?> _capturePlacedWatermark(
    ProjectService projects,
    Layer layer, {
    required String sceneId,
    required int frameIndex,
  }) async {
    final tiles = projects.tileManagerOf(widget.projectId);
    final key = projects.tileKeyFor(
      widget.projectId,
      sceneId,
      frameIndex,
      layer.id,
    );
    final image = await tiles.compositeLayerToImage(key);
    try {
      return await capturePlacedWatermark(
        image,
        angle: layer.watermarkAngle,
        scale: layer.watermarkScale,
      );
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List?> _rasterizeWatermark(
    WatermarkAsset asset,
    int width,
    int height, {
    required double angle,
    required double scale,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imagePath = asset.type == WatermarkAssetType.image
          ? await context.read<WatermarkService>().pathOf(asset.id)
          : null;
      final pixels = await rasterizeWatermark(
        asset,
        width,
        height,
        imagePath: imagePath,
        angle: angle,
        scale: scale,
      );
      if (pixels != null) return pixels;
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
    if (mounted && messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.watermarkImageImportFailed)),
      );
    }
    return null;
  }

  // 移動・貼り付けモード中の吹き出しプレビュー
  // 先頭サムネイル＋白カード最大3枚、右上に枚数バッジ
  Widget _buildCursorBubble() {
    // 移動モードは_selectedSceneIds、貼り付けモードはクリップボードの件数を使う
    final count = _isScenePasteMode
        ? (_sceneClipboard?.ids.length ?? 0)
        : _selectedSceneIds.length;
    final cardCount = count.clamp(1, 3);
    return Positioned(
      // シーンタブの上に表示
      bottom: 36,
      left: 0,
      right: 0,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 白カード（2枚目以降）を後ろに重ねる
            for (int i = cardCount - 1; i >= 1; i--)
              Positioned(
                left: i * 3.0,
                top: -(i * 3.0),
                child: Transform.rotate(
                  angle: (i.isOdd ? 1 : -1) * 0.025, // 約1.4°
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ThemeService.activeColorScheme.onSurface,
                      border: Border.all(
                        color: ThemeService.activeColorScheme.onSurfaceVariant,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            // 先頭サムネイル（先頭のサムネイルのみ実画像を表示する）
            Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: ThemeService.activeColorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _moveThumbnail != null
                  ? FramePreviewBackground(
                      backgroundColor: _projectBackgroundOf(
                        context.read<ProjectService>(),
                        widget.projectId,
                      ),
                      child: RawImage(image: _moveThumbnail, fit: BoxFit.cover),
                    )
                  : Icon(
                      Icons.movie,
                      size: 20,
                      color: ThemeService.activeColorScheme.onSurface
                          .withValues(alpha: 0.54),
                    ),
            ),
            // 枚数バッジ（右上）
            if (count > 1)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '×$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: ThemeService.activeColorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// シーンタブ（カーソル固定方式で並び替え）
  Widget _buildSceneTabs() {
    final projectService = context.watch<ProjectService>();
    final scenes = projectService.scenesOf(widget.projectId);
    return SizedBox(
      height: _isSceneCursorActive ? 92 : 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    // 移動・貼り付けモード：カーソル位置(n+1) + シーンチップ(n) = 2n+1
                    // 通常モード：シーンチップ(n) + ＋ボタン(1) = n+1
                    itemCount: _isSceneCursorActive
                        ? scenes.length * 2 + 1
                        : scenes.length + 1,
                    itemBuilder: (context, index) {
                      if (_isSceneCursorActive) {
                        if (index.isEven) {
                          final cursorPos = index ~/ 2;
                          final isActive = _moveCursorPos == cursorPos;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _moveCursorPos = cursorPos),
                            child: Container(
                              width: 16,
                              alignment: Alignment.center,
                              child: Container(
                                width: 3,
                                height: 28,
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          );
                        } else {
                          final sceneIndex = index ~/ 2;
                          final scene = scenes[sceneIndex];
                          // 貼り付けモード中はコピー元シーンをこのカーソル一覧上で
                          // ハイライトする対象がないため常にfalseとする。
                          final isMoving =
                              !_isScenePasteMode &&
                              _selectedSceneIds.contains(scene.id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Chip(
                              label: Text(
                                scene.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMoving
                                      ? AccentTextTheme.of(context)
                                      : null,
                                ),
                              ),
                              backgroundColor: isMoving
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                          );
                        }
                      } else {
                        if (index == scenes.length) {
                          return TextButton(
                            onPressed: () => context
                                .read<ProjectService>()
                                .addScene(widget.projectId),
                            child: const Text('＋'),
                          );
                        }
                        final scene = scenes[index];
                        final isSelected = scene.id == _selectedSceneId;
                        // 三点メニューのアイコンはChoiceChip（Material/InkWellで
                        // タップを内部処理する）のlabel内にネストしたGestureDetector
                        // として置くと、外側のGestureDetectorとジェスチャーの
                        // ヒットテスト領域が競合し、タップが外側（改名ダイアログ等）
                        // へ吸われて反応しないことがあった。そのためChipの外側の
                        // 兄弟要素として独立させ、確実にタップを拾えるようにする。
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              // 長押し：シーン内フレームを全選択し、フレーム複数選択モードへ
                              // 移行する（フレーム一覧と操作体系を統一）。
                              // シーン自体の複数選択（移動・削除）は上部の「選択」ボタンから行う。
                              onLongPress: () {
                                if (_isSceneMultiSelect ||
                                    _isFrameMultiSelect) {
                                  return;
                                }
                                _selectTimelineScene(scene);
                                setState(() {
                                  _setTimelineSelection(
                                    _TimelineSelection.frames,
                                  );
                                  _selectedFrameIndices.addAll(
                                    List.generate(
                                      scene.frames.length,
                                      (i) => i,
                                    ),
                                  );
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isSceneMultiSelect)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: Icon(
                                            _selectedSceneIds.contains(scene.id)
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            size: 12,
                                          ),
                                        ),
                                      Text(
                                        scene.displayName,
                                        style: localizedHeadingStyle(
                                          context,
                                          const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      // シーン内に自動塗り未更新のフレームがある場合の警告アイコン
                                      // （更新マークはレイヤー・タイムライン両方に表示）
                                      if (projectService
                                          .sceneHasOutdatedAutofillLayers(
                                            widget.projectId,
                                            scene.id,
                                          ))
                                        GestureDetector(
                                          onTap: () =>
                                              _showAutofillUpdateHelp(context),
                                          child: Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.error,
                                              color: ThemeService
                                                  .activeColorScheme
                                                  .tertiary,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    if (!_isSceneMultiSelect) {
                                      _selectTimelineScene(scene);
                                      return;
                                    }
                                    setState(() {
                                      _selectedSceneIds.remove(scene.id);
                                      if (_selectedSceneIds.isEmpty) {
                                        _isSceneMultiSelect = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                            if (!_isSceneMultiSelect)
                              Tooltip(
                                message: MaterialLocalizations.of(
                                  context,
                                ).showMenuTooltip,
                                child: GestureDetector(
                                  key: ValueKey(
                                    'timelineSceneMenu_${scene.id}',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showSceneMenu(scene, scenes),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Icon(Icons.more_vert, size: 14),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // 移動・貼り付けモード中：吹き出しプレビューをタブの上に表示
          if (_isSceneCursorActive) _buildCursorBubble(),
        ],
      ),
    );
  }

  void _selectTimelineScene(Scene scene) {
    if (_selectedSceneId == scene.id) return;
    _finishMaterialDrag();
    if (_isPlaying) _togglePlay();
    _stopTimelineDrag(snap: false);
    setState(() {
      _selectedSceneId = scene.id;
      _isFrameMoveMode = false;
      _frameMoveCursorPos = 0;
      _draggingClipId = null;
      _clipDragMode = null;
      _draggingCameraKfOriginalFrame = null;
      _draggingCameraKfLiveFrame = null;
      _commonDragRange = null;
      _setTimelineSelection(null);
      _clipsLoadedForSceneId = null;
      _audioClips.clear();
      _videoClips.clear();
      _imageClips.clear();
      _textClips.clear();
      _currentFrame = 0;
    });
    _centerFrameInList();
  }

  String _sceneCopyName(
    AppLocalizations l10n,
    ProjectService ps,
    Scene scene,
  ) => numberedEditorCopyName(l10n, scene.displayName, {
    for (final other in ps.scenesOf(widget.projectId)) other.displayName,
  });

  /// 選択中シーンを複製する（シーンのコピー。素材タイムラインの
  /// 上の大きなボタンから起動する）。並び順（シーン一覧の
  /// 実際の順序）に沿って1件ずつ複製元の直後へ挿入していく。
  void _duplicateSelectedScenes(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final targets = scenes
        .where((s) => _selectedSceneIds.contains(s.id))
        .toList();
    ps.editTimeline(widget.projectId, 'Duplicate scenes', () {
      for (final scene in targets) {
        ps.duplicateScene(
          widget.projectId,
          scene.id,
          name: _sceneCopyName(l10n, ps, scene),
        );
      }
    });
    setState(() {
      _selectedSceneIds.clear();
      _isSceneMultiSelect = false;
    });
  }

  // 移動モード開始（複数選択モードからのみ起動）
  void _startMoveMode(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    setState(() {
      _isMoveMode = true;
      // 選択中シーンの並び順で最後のシーンの直後にカーソルを初期配置
      final lastIdx = scenes.lastIndexWhere(
        (s) => _selectedSceneIds.contains(s.id),
      );
      _moveCursorPos = lastIdx + 1;
    });
    final first = scenes
        .where((s) => _selectedSceneIds.contains(s.id))
        .firstOrNull;
    if (first != null) _loadMoveThumbnail(first.id);
  }

  // カーソル固定方式の移動確定（複数選択モードからのみ起動）
  void _confirmMove(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    // 選択シーンを並び順で抽出
    final moving = scenes
        .where((s) => _selectedSceneIds.contains(s.id))
        .toList();
    final selectedIndices = moving.map((s) => scenes.indexOf(s)).toList();
    final removedBefore = selectedIndices
        .where((i) => i < _moveCursorPos)
        .length;
    final insertPos = (_moveCursorPos - removedBefore).clamp(
      0,
      scenes.length - moving.length,
    );
    final reordered = List<Scene>.from(scenes)
      ..removeWhere((s) => _selectedSceneIds.contains(s.id))
      ..insertAll(insertPos, moving);
    context.read<ProjectService>().reorderScenesByIds(
      widget.projectId,
      reordered.map((s) => s.id).toList(),
    );
    setState(() {
      _isMoveMode = false;
      _isSceneMultiSelect = false;
      _selectedSceneIds.clear();
    });
  }

  // シーン貼り付けモード開始（クリップボードにシーンがある場合のみ起動）
  void _startScenePasteMode() {
    final clip = _sceneClipboard;
    if (clip == null) return;
    final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
    setState(() {
      _isScenePasteMode = true;
      _moveCursorPos = scenes.length;
    });
    final first = scenes.where((s) => clip.ids.contains(s.id)).firstOrNull;
    if (first != null) _loadMoveThumbnail(first.id);
  }

  // カーソル固定方式のシーン貼り付け確定。複製元シーンをカーソル位置の
  // 直前まで順番に複製したうえで、一度のreorderScenesByIdsで最終的な
  // 並び順を確定する（duplicateSceneは常に複製元の直後へ挿入するため、
  // 挿入位置の計算を個別に追う必要がない）。
  void _confirmScenePaste() {
    final clip = _sceneClipboard;
    if (clip == null) return;
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final scenesBefore = ps.scenesOf(widget.projectId);
    final sourceScenes = scenesBefore
        .where((s) => clip.ids.contains(s.id))
        .toList();
    if (sourceScenes.isEmpty) {
      setState(() {
        _isScenePasteMode = false;
        _sceneClipboard = null;
      });
      return;
    }
    final originalOrderIds = scenesBefore.map((s) => s.id).toList();
    final insertPos = _moveCursorPos.clamp(0, originalOrderIds.length);
    ps.editTimeline(widget.projectId, 'Paste scenes', () {
      final newIds = <String>[];
      for (final scene in sourceScenes) {
        final duplicated = ps.duplicateScene(
          widget.projectId,
          scene.id,
          name: _sceneCopyName(l10n, ps, scene),
        );
        if (duplicated != null) newIds.add(duplicated.id);
      }
      final finalOrder = List<String>.from(originalOrderIds)
        ..insertAll(insertPos, newIds);
      ps.reorderScenesByIds(widget.projectId, finalOrder);
      if (clip.isCut) {
        ps.removeScenes(widget.projectId, clip.ids);
      }
    });
    setState(() {
      _isScenePasteMode = false;
      _sceneClipboard = null;
      _isSceneMultiSelect = false;
      _selectedSceneIds.clear();
    });
  }

  void _showCustomAutomationManager() {
    final premium = context.read<PremiumService>();
    if (!premium.isFeatureAvailable(PremiumFeature.customAutomation)) {
      showPremiumBanner(context, feature: PremiumFeature.customAutomation);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationManagerSheet(
        surface: CustomAutomationSurface.timeline,
        onExecute: _executeCustomAutomation,
        onRecordingStarted: _showCustomAutomationRecordingOverlay,
        recordingStartFrame: _currentFrame,
      ),
    );
  }

  void _showCustomAutomationRecordingOverlay() {
    _customAutomationRecordingOverlay?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          CustomAutomationRecordingStopButton(
            onStop: () {
              context.read<CustomAutomationService>().stopRecording();
              entry.remove();
              if (identical(_customAutomationRecordingOverlay, entry)) {
                _customAutomationRecordingOverlay = null;
              }
              _showCustomAutomationDraftReview();
            },
          ),
        ],
      ),
    );
    _customAutomationRecordingOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _showCustomAutomationDraftReview() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationDraftSheet(
        surface: CustomAutomationSurface.timeline,
        onResumeRecording: _showCustomAutomationRecordingOverlay,
      ),
    );
  }

  Future<void> _executeCustomAutomation(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
    List<int>? targetFrames,
  ) async {
    if (!context.read<PremiumService>().isFeatureAvailable(
      PremiumFeature.customAutomation,
    )) {
      showPremiumBanner(context, feature: PremiumFeature.customAutomation);
      return;
    }
    if (targetFrames != null) {
      throw StateError(
        'Timeline automation cannot run with explicit target frames',
      );
    }
    if (scope == CustomAutomationExecutionScope.allFrames) {
      throw StateError('Timeline automation cannot run in all-frame scope');
    }
    for (final step in automation.steps) {
      if (step.surface != CustomAutomationSurface.timeline) {
        throw StateError('Canvas command cannot run from Timeline mode');
      }
      switch (step.command) {
        case 'timeline.selectFrame':
          final frame = (step.args['frame'] as num?)?.round();
          if (frame == null || frame < 0 || frame >= _totalFrames) {
            throw StateError('Frame is outside the current timeline');
          }
          setState(() => _currentFrame = frame);
        case 'timeline.addFrame':
          final sceneId = _selectedSceneId;
          if (sceneId == null) throw StateError('No scene selected');
          if (!_canAddFrames(1)) throw StateError('Frame limit reached');
          context.read<ProjectService>().addFrame(widget.projectId, sceneId);
        default:
          throw StateError(
            'Unsupported Timeline automation command: ${step.command}',
          );
      }
    }
  }

  void _recordTimelineAutomation(
    String command,
    String label, {
    Map<String, Object?> args = const {},
    bool changesFrame = false,
  }) {
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.timeline,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      recordedFrame: _currentFrame,
    );
  }

  Future<void> _runAutomationBlockedAction(VoidCallback action) async {
    final service = context.read<CustomAutomationService>();
    if (!service.isRecording) {
      action();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final stop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationStopConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.customAutomationStopConfirmStop),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.customAutomationStopConfirmContinue),
          ),
        ],
      ),
    );
    if (stop != true || !mounted) return;
    service.cancelDraft();
    _customAutomationRecordingOverlay?.remove();
    _customAutomationRecordingOverlay = null;
    action();
  }

  // 三点メニュー（シーン名変更・複製・削除）
  void _showSceneMenu(Scene scene, List<Scene> scenes) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.timelineSceneRenameTitle),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameSceneDialog(scene);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.themeDuplicateAction),
              onTap: () {
                Navigator.pop(ctx);
                final ps = context.read<ProjectService>();
                ps.duplicateScene(
                  widget.projectId,
                  scene.id,
                  name: _sceneCopyName(l10n, ps, scene),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: Text(l10n.commonCopy),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _sceneClipboard = (ids: [scene.id], isCut: false);
                  _frameClipboard = null;
                  _clipClipboard = null;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: Text(l10n.commonCut),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _sceneClipboard = (ids: [scene.id], isCut: true);
                  _frameClipboard = null;
                  _clipClipboard = null;
                });
              },
            ),
            if (_sceneClipboard != null)
              ListTile(
                leading: const Icon(Icons.content_paste),
                title: Text(l10n.commonPaste),
                onTap: () {
                  Navigator.pop(ctx);
                  _startScenePasteMode();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.timelineSceneDeleteMenuItem),
              // シーンが1件のみの場合は削除不可
              onTap: scenes.length > 1
                  ? () {
                      Navigator.pop(ctx);
                      _showSingleDeleteConfirm(scene);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // 単体シーン削除の確認ダイアログ
  void _showSingleDeleteConfirm(Scene scene) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSceneDeleteConfirmTitle(scene.displayName)),
        content: messageText(l10n.timelineSceneDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>().removeScene(
                widget.projectId,
                scene.id,
              );
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  // 複数選択シーン削除の確認ダイアログ
  void _showMultiDeleteConfirm() {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedSceneIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSceneMultiDeleteConfirmTitle(count)),
        content: messageText(l10n.timelineSceneDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>().removeScenes(
                widget.projectId,
                _selectedSceneIds.toList(),
              );
              setState(() {
                _selectedSceneIds.clear();
                _isSceneMultiSelect = false;
              });
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _showRenameSceneDialog(Scene scene) {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.read<ProjectService>();
    showDialog<void>(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.timelineSceneRenameTitle,
        initialName: scene.displayName,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        onSubmit: (name) async =>
            projects.renameScene(widget.projectId, scene.id, name),
      ),
    );
  }

  // タイムライン側警告アイコンのヘルプ（レイヤーパネル側と同一文言）
  void _showAutofillUpdateHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
        title: Row(
          children: [
            Expanded(child: Text(l10n.layerPanelAutofillUpdateHelpTitle)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Text(l10n.timelineAutofillUpdateHelpBody),
      ),
    );
  }

  /// フレーム一覧（シーンと同じ複数選択・カーソル固定移動の操作体系）。
  Widget _buildFrameList() {
    final l10n = AppLocalizations.of(context)!;
    final total = _totalFrames;
    final projectService = context.watch<ProjectService>();
    final backgroundColor = _projectBackgroundOf(
      projectService,
      widget.projectId,
    );
    final frameListSceneId = _selectedSceneId;
    final timestamps = <int, List<TimelineMarker>>{};
    if (frameListSceneId != null) {
      for (final marker in projectService.timelineMarkersOf(
        widget.projectId,
        frameListSceneId,
      )) {
        (timestamps[marker.frameIndex] ??= []).add(marker);
      }
    }
    final markerHeight = timestamps.isEmpty ? 0.0 : 22.0;

    // 中央寄せは_currentFrameNotifierのリスナー（_onCurrentFrameChanged）で
    // 行う。以前はここで呼んでいたが、buildの中でスクロールという副作用を
    // 起こすのは筋が悪く、再生中に画面全体を作り直さなくなると呼ばれなく
    // なるという問題もあった。
    return SizedBox(
      height: (_isFrameCursorActive ? 92 : 50) + markerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 50 + markerHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildTrackLabel(
                    Icons.movie_filter,
                    l10n.timelineFrameTrackLabel,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 左右に((ビューポート幅-セル幅)/2)の余白を入れることで、
                        // 先頭・末尾のフレームも赤枠（画面中央）まできっちり
                        // スクロールできるようにする。
                        final sidePadding = _trackSidePadding(
                          constraints.maxWidth,
                        );
                        final track = NotificationListener<ScrollEndNotification>(
                          onNotification: _handleTrackScrollEnd,
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _frameScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                itemExtent: _cellW,
                                physics: _isFrameCursorActive
                                    ? const NeverScrollableScrollPhysics()
                                    : const ClampingScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: sidePadding,
                                ),
                                itemCount: total,
                                itemBuilder: (context, index) {
                                  // 現在フレームの強調表示は画面中央固定の赤枠が担うため、
                                  // 通常モードでは枠色を変えない（複数選択のチェック状態のみ
                                  // ここで色分けする）。
                                  final isChecked = _selectedFrameIndices
                                      .contains(index);
                                  // このフレームに自動塗り未更新のレイヤーがある場合の警告アイコン
                                  // （更新マークはレイヤー・タイムライン両方に表示）
                                  final hasOutdatedAutofill =
                                      frameListSceneId != null &&
                                      projectService
                                          .frameHasOutdatedAutofillLayers(
                                            widget.projectId,
                                            frameListSceneId,
                                            index,
                                          );
                                  final frame = GestureDetector(
                                    key: ValueKey('timelineFrameCell$index'),
                                    onTap: () {
                                      if (_isFrameCursorActive) {
                                        _chooseFramePlacement(index);
                                      } else if (_isFrameMultiSelect) {
                                        setState(() {
                                          if (!_selectedFrameIndices.remove(
                                            index,
                                          )) {
                                            _selectedFrameIndices.add(index);
                                          }
                                        });
                                      } else {
                                        setState(() => _currentFrame = index);
                                        _recordTimelineAutomation(
                                          'timeline.selectFrame',
                                          'Frame ${index + 1}',
                                          args: {'frame': index},
                                          changesFrame: true,
                                        );
                                      }
                                    },
                                    // 長押し：このフレームを選択済みの状態でフレーム複数選択モードを開始する
                                    onLongPress:
                                        _isFrameCursorActive ||
                                            _isFrameMultiSelect
                                        ? null
                                        : () {
                                            setState(() {
                                              _setTimelineSelection(
                                                _TimelineSelection.frames,
                                              );
                                              _selectedFrameIndices.add(index);
                                            });
                                          },
                                    child: Container(
                                      width: _frameW,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: _frameMargin,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isChecked
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: Stack(
                                          children: [
                                            // The project's background behind the
                                            // picture, as on the canvas and in
                                            // the playback preview.
                                            Positioned.fill(
                                              child: FramePreviewBackground(
                                                backgroundColor:
                                                    backgroundColor,
                                              ),
                                            ),
                                            // フレームの実プレビュー（ただの四角形では
                                            // なくちゃんとしたプレビューにする）。
                                            if (frameListSceneId != null)
                                              Positioned.fill(
                                                child: _TimelineFrameThumbnail(
                                                  projectId: widget.projectId,
                                                  sceneId: frameListSceneId,
                                                  frameIndex: index,
                                                  tileManager: projectService
                                                      .tileManagerOf(
                                                        widget.projectId,
                                                      ),
                                                  layers: projectService
                                                      .layersOf(
                                                        widget.projectId,
                                                        frameListSceneId,
                                                        index,
                                                      ),
                                                  backgroundColor:
                                                      backgroundColor,
                                                ),
                                              ),
                                            if (isChecked)
                                              Positioned.fill(
                                                child: ColoredBox(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                            Positioned(
                                              // 今のフレームの赤枠（3px）の内側に
                                              // 出す（角に置いていたので、今の
                                              // フレームでは番号が枠に隠れた）。
                                              left: 4,
                                              bottom: 3,
                                              // Outlined, to read over any
                                              // project background colour.
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: ThemeService
                                                      .activeColorScheme
                                                      .onSurface,
                                                  shadows:
                                                      CanvasIconButton.outlineShadows(
                                                        ThemeService
                                                            .activeColorScheme
                                                            .surface,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            if (hasOutdatedAutofill)
                                              Positioned(
                                                left: 1,
                                                top: 1,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showAutofillUpdateHelp(
                                                        context,
                                                      ),
                                                  child: Icon(
                                                    Icons.error,
                                                    color: ThemeService
                                                        .activeColorScheme
                                                        .tertiary,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                            if (_isFrameMultiSelect &&
                                                !_isFrameCursorActive)
                                              Positioned(
                                                right: 1,
                                                top: 1,
                                                child: Icon(
                                                  isChecked
                                                      ? Icons.check_circle
                                                      : Icons
                                                            .radio_button_unchecked,
                                                  size: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  return Column(
                                    children: [
                                      if (markerHeight > 0)
                                        SizedBox(
                                          height: markerHeight + 4,
                                          child: timestamps[index] == null
                                              ? null
                                              : _buildMarkerPin(
                                                  timestamps[index]!,
                                                ),
                                        ),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            top: markerHeight > 0 ? 0 : 4,
                                            bottom: 4,
                                          ),
                                          child: frame,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              _buildFrameEndButton(
                                total,
                                sidePadding,
                                constraints.maxWidth,
                                markerHeight: markerHeight,
                              ),
                              // 画面中央に固定表示する赤枠。フレーム一覧側が
                              // スクロールして現在位置のフレームをここへ合わせる。
                              IgnorePointer(
                                child: Padding(
                                  padding: EdgeInsets.only(top: markerHeight),
                                  child: Center(
                                    child: Container(
                                      key: const Key(
                                        'timelineCurrentFrameOutline',
                                      ),
                                      width: _frameW,
                                      height: 40,
                                      alignment: _frameMoveCursorPos == total
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: ThemeService
                                              .activeColorScheme
                                              .error,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: _isFrameCursorActive
                                          ? Container(
                                              width: 3,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        return _framePlacementDrag(
                          child: track,
                          enabled: _isFrameCursorActive,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 移動・貼り付けモード中：吹き出しプレビューをフレーム一覧の上に表示
          if (_isFrameCursorActive) _buildFrameCursorBubble(markerHeight),
        ],
      ),
    );
  }

  Widget _buildFrameEndButton(
    int total,
    double padding,
    double viewportWidth, {
    required double markerHeight,
  }) {
    final colors = ThemeService.activeColorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _frameScrollCtrl,
      builder: (context, child) {
        final left = padding + total * _cellW - _timelineOffset;
        if (left >= viewportWidth) return const SizedBox.shrink();
        return Positioned(
          left: left,
          top: 4 + markerHeight,
          bottom: 4,
          width: _cellW,
          child: child!,
        );
      },
      child: Tooltip(
        message: _isFrameCursorActive
            ? (_isFramePasteMode ? l10n.commonPaste : l10n.commonMove)
            : l10n.customAutomationStepAddFrame,
        child: GestureDetector(
          onTap: () {
            if (_isFrameCursorActive) {
              _chooseFramePlacement(total);
              return;
            }
            final sceneId = _selectedSceneId;
            if (sceneId == null || !_canAddFrames(1)) return;
            context.read<ProjectService>().addFrame(widget.projectId, sceneId);
            _recordTimelineAutomation('timeline.addFrame', 'Add frame');
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.onSurfaceVariant),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.add, size: 16, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildFrameCursorBubble(double markerHeight) {
    // 移動モードは_selectedFrameIndices、貼り付けモードはクリップボードの件数を使う
    final count = _isFramePasteMode
        ? (_frameClipboard?.indices.length ?? 0)
        : _selectedFrameIndices.length;
    final cardCount = count.clamp(1, 3);
    return Positioned(
      bottom: 50 + markerHeight,
      left: _trackLabelWidth,
      right: 0,
      child: Center(
        child: _framePlacementDrag(
          isHandle: true,
          child: Stack(
            key: const Key('timelineFramePlacementHandle'),
            clipBehavior: Clip.none,
            children: [
              for (int i = cardCount - 1; i >= 1; i--)
                Positioned(
                  left: i * 3.0,
                  top: -(i * 3.0),
                  child: Transform.rotate(
                    angle: (i.isOdd ? 1 : -1) * 0.025,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ThemeService.activeColorScheme.onSurface,
                        border: Border.all(
                          color:
                              ThemeService.activeColorScheme.onSurfaceVariant,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: ThemeService.activeColorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _moveThumbnail != null
                    ? FramePreviewBackground(
                        backgroundColor: _projectBackgroundOf(
                          context.read<ProjectService>(),
                          widget.projectId,
                        ),
                        child: RawImage(
                          image: _moveThumbnail,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.movie_filter,
                        size: 18,
                        color: ThemeService.activeColorScheme.onSurface
                            .withValues(alpha: 0.54),
                      ),
              ),
              if (count > 1)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×$count',
                      style: TextStyle(
                        fontSize: 10,
                        color: ThemeService.activeColorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _framePlacementDrag({
    required Widget child,
    bool isHandle = false,
    bool enabled = true,
  }) {
    void update(DragUpdateDetails details) {
      if (_timelineDragStartX == null) return;
      if (isHandle) {
        _updateTimelineDragScroll(details.globalPosition.dx);
      } else {
        _scrollTimelineDuringDrag(_timelineOffset - details.delta.dx);
      }
    }

    return Listener(
      onPointerCancel: enabled ? (_) => _stopTimelineDrag() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: enabled
            ? (d) => _startTimelineDrag(d.globalPosition.dx)
            : null,
        onHorizontalDragUpdate: enabled ? update : null,
        onHorizontalDragEnd: enabled ? (_) => _stopTimelineDrag() : null,
        onHorizontalDragCancel: enabled ? _stopTimelineDrag : null,
        onLongPressStart: enabled
            ? (d) => _startTimelineDrag(d.globalPosition.dx)
            : null,
        onLongPressMoveUpdate: enabled
            ? (d) => _updateTimelineDragScroll(d.globalPosition.dx)
            : null,
        onLongPressEnd: enabled ? (_) => _stopTimelineDrag() : null,
        child: child,
      ),
    );
  }

  void _chooseFramePlacement(int position) {
    if (_isPlaying) _togglePlay();
    setState(() {
      _frameMoveCursorPos = position;
      _currentFrame = math.min(position, _totalFrames - 1);
    });
    _centerFrameInList();
  }

  /// フレーム追加・複製の前に、無料会員の長さ上限（90秒）を超えないか
  /// チェックする。90秒を超えるようになりそうな場合はフレーム追加や複製
  /// ボタンタップ時に注意文がポップアップ表示され、90秒以上にはならない。
  /// 超える場合は警告ダイアログを表示してfalseを返す（呼び出し元は操作を
  /// 中止する）。プレミアム会員は上限が2時間（7200秒）と大きいため事実上
  /// ブロックされない。
  bool _canAddFrames(int count) {
    final premium = context.read<PremiumService>();
    final hasUnlimitedDuration = premium.isFeatureAvailable(
      PremiumFeature.unlimitedDuration,
    );
    final ps = context.read<ProjectService>();
    final maxSeconds = premium.maxProjectDurationSeconds;
    final projected = ps.projectedDurationSeconds(
      widget.projectId,
      frameDelta: count,
    );
    if (projected <= maxSeconds) return true;
    showProjectDurationLimit(
      context,
      hasUnlimitedDuration: hasUnlimitedDuration,
    );
    return false;
  }

  /// 選択中フレームを複製する（後ろのindexから処理し、複製に伴うindexずれを回避）。
  void _duplicateSelectedFrames() {
    if (_selectedFrameIndices.isEmpty) return;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    if (!_canAddFrames(_selectedFrameIndices.length)) return;
    final ps = context.read<ProjectService>();
    final sorted = _selectedFrameIndices.toList()..sort();
    ps.editTimeline(widget.projectId, 'Duplicate frames', () {
      for (final idx in sorted.reversed) {
        ps.duplicateFrame(widget.projectId, sceneId, idx);
      }
    });
    unawaited(_saveFrameEdit());
    setState(() {
      _selectedFrameIndices.clear();
      _isFrameMultiSelect = false;
    });
  }

  /// 選択中フレームを削除する（後ろのindexから処理し、削除に伴うindexずれを回避）。
  /// 最後の1枚は削除されない（ProjectService.removeFrame側で保証）。
  void _deleteSelectedFrames() {
    if (_selectedFrameIndices.isEmpty) return;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final ps = context.read<ProjectService>();
    final sorted = _selectedFrameIndices.toList()..sort();
    ps.editTimeline(widget.projectId, 'Delete frames', () {
      for (final idx in sorted.reversed) {
        ps.removeFrame(widget.projectId, sceneId, idx);
      }
    });
    unawaited(_saveFrameEdit());
    setState(() {
      _selectedFrameIndices.clear();
      _isFrameMultiSelect = false;
      _currentFrame = _currentFrame.clamp(0, _totalFrames - 1);
    });
  }

  // 移動モード開始（複数選択モードからのみ起動）
  void _startFrameMoveMode() {
    if (_selectedFrameIndices.isEmpty) return;
    final sorted = _selectedFrameIndices.toList()..sort();
    setState(() {
      _isFrameMoveMode = true;
    });
    _chooseFramePlacement(sorted.last + 1);
    final sceneId = _selectedSceneId;
    if (sceneId != null) _loadMoveThumbnail(sceneId, frameIndex: sorted.first);
  }

  // カーソル固定方式の移動確定（複数選択モードからのみ起動）
  void _confirmFrameMove() {
    if (_selectedFrameIndices.isEmpty) return;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    _stopTimelineDrag(snap: false);
    final total = _totalFrames;
    final moving = _selectedFrameIndices.toList()..sort();
    final removedBefore = moving.where((i) => i < _frameMoveCursorPos).length;
    final insertPos = (_frameMoveCursorPos - removedBefore).clamp(
      0,
      total - moving.length,
    );
    final remaining = [
      for (int i = 0; i < total; i++)
        if (!_selectedFrameIndices.contains(i)) i,
    ];
    final newOrder = List<int>.from(remaining)..insertAll(insertPos, moving);
    context.read<ProjectService>().reorderFrames(
      widget.projectId,
      sceneId,
      newOrder,
    );
    setState(() {
      _isFrameMoveMode = false;
      _isFrameMultiSelect = false;
      _selectedFrameIndices.clear();
      _currentFrame = _currentFrame.clamp(0, _totalFrames - 1);
    });
    _centerFrameInList();
  }

  // フレーム貼り付けモード開始（クリップボードにフレームがある場合のみ
  // 起動）。貼り付け先は現在表示中のシーン（コピー元と異なっていてよい）。
  void _startFramePasteMode() {
    final clip = _frameClipboard;
    if (clip == null) return;
    setState(() {
      _isFramePasteMode = true;
    });
    _chooseFramePlacement(_totalFrames);
    _loadMoveThumbnail(clip.sceneId, frameIndex: clip.indices.first);
  }

  // カーソル固定方式のフレーム貼り付け確定。同一シーン内への貼り付けで
  // カーソル位置が複製元より後ろにある場合、挿入するたびに複製元の
  // インデックスがずれていくため、挿入済み件数を加味した実効インデックスを
  // 都度計算しながら1件ずつinsertDuplicatedFrameを呼ぶ。
  void _confirmFramePaste() {
    final clip = _frameClipboard;
    if (clip == null) return;
    final targetSceneId = _selectedSceneId;
    if (targetSceneId == null) return;
    final sortedSourceIndices = List<int>.from(clip.indices)..sort();
    final movingFrames =
        clip.isCut &&
        context.read<ProjectService>().frameCount(
              widget.projectId,
              clip.sceneId,
            ) >
            sortedSourceIndices.length;
    if (!movingFrames && !_canAddFrames(sortedSourceIndices.length)) return;
    _stopTimelineDrag(snap: false);
    final ps = context.read<ProjectService>();
    final insertAt = _frameMoveCursorPos.clamp(0, _totalFrames);
    final sameScene = clip.sceneId == targetSceneId;
    ps.editTimeline(widget.projectId, 'Paste frames', () {
      var insertedSoFar = 0;
      for (final originalIdx in sortedSourceIndices) {
        final effectiveSrcIdx = (sameScene && originalIdx >= insertAt)
            ? originalIdx + insertedSoFar
            : originalIdx;
        ps.insertDuplicatedFrame(
          projectId: widget.projectId,
          sourceSceneId: clip.sceneId,
          sourceFrameIndex: effectiveSrcIdx,
          targetSceneId: targetSceneId,
          insertAt: insertAt + insertedSoFar,
          // When cutting an entire scene into another, the first source
          // frame survives because a scene must keep at least one frame.
          transferFrameAnchors:
              clip.isCut &&
              (sameScene ||
                  movingFrames ||
                  originalIdx != sortedSourceIndices.first),
        );
        insertedSoFar++;
      }
      if (clip.isCut) {
        // 貼り付けによって挿入された分だけ、切り取り元より後ろにあった
        // 元フレームのインデックスが後ろへずれているため、削除前に
        // 実際の位置へ補正し、降順に削除する。
        final m = sortedSourceIndices.length;
        final currentPositions =
            sortedSourceIndices
                .map(
                  (originalIdx) => (sameScene && originalIdx >= insertAt)
                      ? originalIdx + m
                      : originalIdx,
                )
                .toList()
              ..sort();
        for (final idx in currentPositions.reversed) {
          ps.removeFrame(
            widget.projectId,
            clip.sceneId,
            idx,
            recordUndo: false,
          );
        }
      }
    });
    unawaited(_saveFrameEdit());
    setState(() {
      _isFramePasteMode = false;
      _frameClipboard = null;
      _isFrameMultiSelect = false;
      _selectedFrameIndices.clear();
      _currentFrame = _currentFrame.clamp(0, _totalFrames - 1);
    });
    _centerFrameInList();
  }

  /// 行の名前の欄の幅。この言語の決まった行の名前がどれも語の途中で折れず、
  /// 2行までに入る幅（いつもは94dp）。
  double get _trackLabelWidth => TrackLabelMetrics.columnWidth(
    locale: Localizations.maybeLocaleOf(context),
    textScaler: MediaQuery.textScalerOf(context),
    fixedLabels: timelineFixedTrackLabels(AppLocalizations.of(context)!),
  );

  BoxDecoration get _trackRowDivider => BoxDecoration(
    border: Border(
      bottom: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: .75,
      ),
    ),
  );

  Widget _buildTrackLabel(
    IconData icon,
    String label, {
    VoidCallback? onIconTap,
    String? iconTooltip,
    Key? iconKey,
  }) => TrackLabel(
    icon: icon,
    label: label,
    width: _trackLabelWidth,
    onIconTap: onIconTap,
    iconTooltip: iconTooltip,
    iconKey: iconKey,
  );

  /// 素材種別（画像・動画・音源）ごとのタイムライン行グループ。
  /// 行数・行名はシーンごとにProjectServiceで管理する。1行目の右端＋は
  /// 「行の追加」用（素材自体の追加は既に上部ツールバーのボタンで行える
  /// ため、この＋は行追加に転用した）。2行目以降は－で行削除ができる。
  /// 素材種別（動画・音声）のトラック行グループ。1件も素材がなければ
  /// グループごと非表示にし（デフォルトはプレビュー・フレーム
  /// 一覧のみ）、中身のある行だけを表示する。同じタイミングで重ねたい
  /// 素材がある場合のみ、最後尾の行の＋で新しい行を追加できる。
  Widget _buildMaterialTrackGroup({
    required TimelineRowKind type,
    required IconData icon,
    required String defaultLabel,
    required List<_TrackClip> allClips,
    required Color addColor,
  }) {
    if (allClips.isEmpty) return const SizedBox.shrink();
    final sceneId = _selectedSceneId;
    final rowNames = sceneId == null
        ? const <String?>[null]
        : context.watch<ProjectService>().rowNamesOf(
            widget.projectId,
            sceneId,
            type,
          );
    final visibleRows = [
      for (int row = 0; row < rowNames.length; row++)
        if (allClips.any((c) => c.trackRow == row)) row,
    ];
    if (visibleRows.isEmpty) return const SizedBox.shrink();
    final lastRow = visibleRows.last;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in visibleRows)
          _buildClipTrackRow(
            type: type,
            rowIndex: row,
            rowLabel:
                rowNames[row] ??
                AppLocalizations.of(
                  context,
                )!.timelineTrackRowName(defaultLabel, row + 1),
            icon: icon,
            clips: allClips.where((c) => c.trackRow == row).toList(),
            scrollCtrl: _rowScrollCtrl(type, row),
            addColor: addColor,
            showAddButton: row == lastRow,
          ),
      ],
    );
  }

  Widget _buildReadAloudTrack() {
    final clips = _audioClips.where((c) => c.isReadAloud).toList();
    if (clips.isEmpty) return const SizedBox.shrink();
    return _buildClipTrackRow(
      type: TimelineRowKind.audio,
      rowIndex: 0,
      rowLabel: MakingStrings.readAloud(context),
      icon: Icons.record_voice_over_outlined,
      clips: clips,
      scrollCtrl: _readAloudScrollCtrl,
      addColor: ThemeService.activeColorScheme.tertiary,
      showAddButton: false,
      canRename: false,
    );
  }

  Widget _buildTrackGrid(
    ScrollController controller,
    int total,
    double padding,
  ) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: _handleTrackScrollEnd,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _syncFrom(_frameScrollCtrl, updatePlayhead: false);
          return false;
        },
        child: ListView.builder(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: padding),
          itemExtent: _cellW,
          itemCount: total,
          itemBuilder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClipTrackRow({
    required TimelineRowKind type,
    required int rowIndex,
    required String rowLabel,
    required IconData icon,
    required List<_TrackClip> clips,
    required ScrollController scrollCtrl,
    required Color addColor,
    required bool showAddButton,
    bool canRename = true,
  }) {
    final total = _totalFrames;
    final videoRow = type == TimelineRowKind.video && canRename;
    return Container(
      height: _materialTrackHeight,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      foregroundDecoration: _trackRowDivider,
      child: Row(
        children: [
          // 行名タップで名称変更（「タイムライン左側の素材種別名は
          // タップでユーザーがテキスト変更できる」）。種別を示すアイコン自体は
          // 変更不可のまま常時表示する。
          // A video row's icon is its switch between the video's frames and
          // its sound's waveform (the rest of the label renames the row).
          canRename
              ? GestureDetector(
                  onTap: () =>
                      _showRenameTrackRowDialog(type, rowIndex, rowLabel),
                  child: videoRow
                      ? _buildVideoRowLabel(rowIndex, rowLabel)
                      : _buildTrackLabel(icon, rowLabel),
                )
              : _buildTrackLabel(icon, rowLabel),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding = _trackSidePadding(constraints.maxWidth);
                return Stack(
                  children: [
                    _buildTrackGrid(scrollCtrl, total, sidePadding),
                    // クリップ描画
                    for (final clip in clips)
                      _buildClipWidget(clip, scrollCtrl, sidePadding),
                    // 表示中の最後尾の行にのみ＋を出し、同じタイミングで重ねたい
                    // 素材がある時だけ新しい行を追加できるようにする。行の削除は
                    // 個々のクリップを消せば自動で畳まれるため、専用ボタンは持たない。
                    if (showAddButton)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Tooltip(
                          message: AppLocalizations.of(
                            context,
                          )!.timelineAddTrackRowTooltip,
                          child: GestureDetector(
                            onTap: () => _addTrackRow(type),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: addColor.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 14,
                                color: ThemeService.activeColorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addTrackRow(TimelineRowKind type) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    context.read<ProjectService>().addTrackRow(widget.projectId, sceneId, type);
  }

  void _showRenameTrackRowDialog(
    TimelineRowKind type,
    int rowIndex,
    String currentLabel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final ctrl = TextEditingController(text: currentLabel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: typingDialogInsetPadding(ctx),
        title: Text(l10n.timelineTrackRowRenameTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().renameTrackRow(
                widget.projectId,
                sceneId,
                type,
                rowIndex,
                ctrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then(
      (_) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose()),
    );
  }

  Widget _buildClipWidget(
    _TrackClip clip,
    ScrollController scrollCtrl,
    double sidePadding,
  ) {
    return AnimatedBuilder(
      animation: scrollCtrl,
      builder: (ctx, child) {
        final scrollOffset = scrollCtrl.hasClients ? scrollCtrl.offset : 0.0;
        final left = sidePadding + clip.startFrame * _cellW - scrollOffset;
        final width = clip.lengthFrames * _cellW - _frameMargin * 2;
        final isDragging = _draggingClipId == clip.id;
        // ドラッグ中のクリップは画面外カリングの対象から外す。カリングで
        // ウィジェット自体が消えるとポインターを掴んでいたRenderObjectが
        // 失われ、ジェスチャーが途中で切れてしまうため。
        if (!isDragging &&
            (left + width < 0 || left > MediaQuery.sizeOf(context).width)) {
          return const SizedBox.shrink();
        }
        const handleW = 8.0;
        const rowPadding = 3.0;
        final isSelected = _selectedClipIds.contains(clip.id);
        return Positioned(
          left: left,
          top: rowPadding,
          width: width.clamp(handleW * 2 + 4, double.infinity),
          height: _materialTrackHeight - rowPadding * 2,
          child: Listener(
            onPointerCancel: (_) => _endClipDrag(clip, commit: false),
            child: GestureDetector(
              key: ValueKey('timelineClip-${clip.id}'),
              onTap: () {
                if (_isClipMultiSelect) {
                  setState(() {
                    if (isSelected) {
                      _selectedClipIds.remove(clip.id);
                    } else {
                      _selectedClipIds.add(clip.id);
                    }
                  });
                } else {
                  _showEditClipDialog(clip);
                }
              },
              // 長押しドラッグでクリップ本体を移動＝表示開始位置を変更する
              // （「開始フレーム変更：タイムライン上で表示開始
              // 位置を変更」）。複数選択モード中は選択操作と競合するため無効化する。
              onLongPressStart: _isClipMultiSelect
                  ? null
                  : (d) => _beginClipDrag(
                      clip,
                      _ClipDragMode.move,
                      d.globalPosition.dx,
                    ),
              onLongPressMoveUpdate: _isClipMultiSelect
                  ? null
                  : (d) => _updateClipDrag(clip, d.globalPosition.dx),
              onLongPressEnd: _isClipMultiSelect
                  ? null
                  : (_) => _endClipDrag(clip),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: clip.color.withValues(
                          alpha: isDragging ? 1.0 : 0.85,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: isDragging
                            ? Border.all(
                                color: ThemeService.activeColorScheme.onSurface,
                                width: 1.5,
                              )
                            : (isSelected
                                  ? Border.all(
                                      color: ThemeService
                                          .activeColorScheme
                                          .onSurface,
                                      width: 1.5,
                                    )
                                  : null),
                        boxShadow: isDragging
                            ? null
                            : [
                                BoxShadow(
                                  color: ThemeService
                                      .activeColorScheme
                                      .onSurface
                                      .withValues(alpha: 0.25),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (clip.trackType == _ClipTrackType.audio ||
                              _videoRowDisplay(clip.trackRow) ==
                                  VideoTrackDisplay.waveform)
                            ?_clipWaveform(clip)
                          else if (clip.trackType == _ClipTrackType.video &&
                              clip.materialId != null)
                            Opacity(
                              opacity: 0.75,
                              child: VideoFilmstrip(
                                key: ValueKey('filmstrip_${clip.id}'),
                                frames: _stripVideoFrames,
                                materialId: clip.materialId!,
                                timing: (
                                  startFrame: clip.startFrame,
                                  lengthFrames: clip.lengthFrames,
                                  trimStartFrame:
                                      clip.useStart + clip.sourceFraction,
                                  trimEndFrame: clip.useEnd,
                                  playbackRate: clip.playbackRate,
                                ),
                                framesPerSecond: _projectFps(
                                  context.read<ProjectService>(),
                                ).toDouble(),
                              ),
                            ),
                          _buildClipName(clip),
                        ],
                      ),
                    ),
                  ),
                  if (_isClipMultiSelect)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 12,
                        color: ThemeService.activeColorScheme.onSurface,
                      ),
                    ),
                  // 左右端のドラッグハンドル：表示範囲（長さ）を変更する
                  // （「使用範囲変更：タイムライン上でドラッグ
                  // ハンドルにより変更」）。複数選択モード中は選択操作と
                  // 競合するため表示しない。
                  if (!_isClipMultiSelect) ...[
                    _buildClipResizeHandle(clip, handleW, isLeft: true),
                    _buildClipResizeHandle(clip, handleW, isLeft: false),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The waveform of the sound [clip] plays (an audio clip, or a video clip
  /// on a row showing its sound), or null when it has no file.
  Widget? _clipWaveform(_TrackClip clip) {
    final path = clip.filePath;
    if (path == null) return null;
    if (clip.trackType != _ClipTrackType.audio &&
        clip.trackType != _ClipTrackType.video) {
      return null;
    }
    final fps = _projectFps(context.read<ProjectService>());
    final sourceStart = clip.useStart + clip.sourceFraction;
    // A video sounds only over its used range: the waveform covers that part
    // of the clip from its left edge, and nothing where the last frame is
    // held.
    final soundingFrames = clip.trackType == _ClipTrackType.video
        ? clip.videoSoundingFrames
        : clip.lengthFrames.toDouble();
    if (soundingFrames <= 0) return null;
    final sourceFrames = soundingFrames * clip.soundRate;
    final waveform = _AudioWaveformThumb(
      key: ValueKey('wf_${clip.id}'),
      filePath: path,
      // Each clip gets its own cache for its exact source interval.
      cacheKey:
          'wave_v3_${clip.id}_${path}_${sourceStart}_${sourceFrames}_$fps',
      sourceStartFrame: sourceStart,
      sourceFrames: sourceFrames,
      fps: fps,
    );
    if (soundingFrames >= clip.lengthFrames) return waveform;
    return FractionallySizedBox(
      key: ValueKey('wfPart_${clip.id}'),
      alignment: AlignmentDirectional.centerStart,
      widthFactor: soundingFrames / clip.lengthFrames,
      child: waveform,
    );
  }

  /// A video row's label: its icon shows, and switches, what the row's
  /// clips show (the video's frames or its sound's waveform).
  Widget _buildVideoRowLabel(int row, String label) {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    final display = sceneId == null
        ? VideoTrackDisplay.frames
        : context.watch<ProjectService>().videoRowDisplayOf(
            widget.projectId,
            sceneId,
            row,
          );
    final showsFrames = display == VideoTrackDisplay.frames;
    return _buildTrackLabel(
      showsFrames ? Icons.movie_outlined : Icons.graphic_eq,
      label,
      iconKey: ValueKey('videoRowDisplay-$row'),
      iconTooltip: showsFrames
          ? l10n.timelineVideoTrackShowingFrames
          : l10n.timelineVideoTrackShowingWaveform,
      onIconTap: sceneId == null
          ? null
          : () => context.read<ProjectService>().setVideoRowDisplay(
              widget.projectId,
              sceneId,
              row,
              showsFrames
                  ? VideoTrackDisplay.waveform
                  : VideoTrackDisplay.frames,
            ),
    );
  }

  /// What video row [row] of the scene shows in its clips.
  VideoTrackDisplay _videoRowDisplay(int row) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return VideoTrackDisplay.frames;
    return context.read<ProjectService>().videoRowDisplayOf(
      widget.projectId,
      sceneId,
      row,
    );
  }

  /// クリップの名前の左の空き。左端の長さを変えるつまみ（幅8dp、真ん中に
  /// 縦の線）に字が重ならないように、つまみの幅だけ空ける。
  static const double _clipNameInset = 8;

  /// クリップの名前。音声のクリップは波形の上に重ねず、左上の帯（クリップと
  /// 同じ色の不透明な台）に載せる（以前は波形の真ん中に9pxの字で重なり、
  /// 韓国語・中国語の細い明朝ではほとんど読めなかった）。字の色はテーマの
  /// 文字色とパネルの背景色のうち、クリップの色の上で読みやすい方。
  Widget _buildClipName(_TrackClip clip) {
    final scheme = ThemeService.activeColorScheme;
    // クリップの帯と同じ色（帯は不透明度85%で行の面の上に重なる）。
    final fill = opaqueOver(
      clip.color.withValues(alpha: 0.85),
      scheme.surfaceContainerLow,
    );
    final ink =
        contrastRatio(scheme.onSurface, fill) >=
            contrastRatio(scheme.surface, fill)
        ? scheme.onSurface
        : scheme.surface;
    final text = Text(
      clip.label,
      key: ValueKey('timelineClipName-${clip.id}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: localizedHeadingStyle(
        context,
        TextStyle(fontSize: 10, height: 1.2, color: ink),
      ),
    );
    // On a picture (a sound's waveform, or a video row's frames or
    // waveform) the name sits on the band.
    final onWaveform =
        (clip.trackType == _ClipTrackType.audio && clip.filePath != null) ||
        (clip.trackType == _ClipTrackType.video &&
            (clip.materialId != null || clip.filePath != null));
    if (!onWaveform) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _clipNameInset),
        child: Align(alignment: Alignment.centerLeft, child: text),
      );
    }
    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_clipNameInset, 1, 5, 1),
          child: text,
        ),
      ),
    );
  }

  Widget _buildClipResizeHandle(
    _TrackClip clip,
    double handleW, {
    required bool isLeft,
  }) {
    final mode = isLeft ? _ClipDragMode.resizeLeft : _ClipDragMode.resizeRight;
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: handleW,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (d) =>
            _beginClipDrag(clip, mode, d.globalPosition.dx),
        onHorizontalDragUpdate: (d) =>
            _updateClipDrag(clip, d.globalPosition.dx),
        onHorizontalDragEnd: (_) => _endClipDrag(clip),
        onHorizontalDragCancel: () => _endClipDrag(clip, commit: false),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(
            color: ThemeService.activeColorScheme.onSurface.withValues(
              alpha: 0.25,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 2,
              height: 12,
              decoration: BoxDecoration(
                color: ThemeService.activeColorScheme.onSurface.withValues(
                  alpha: 0.85,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _beginClipDrag(_TrackClip clip, _ClipDragMode mode, double globalX) {
    _startTimelineDrag(globalX);
    setState(() {
      _draggingClipId = clip.id;
      _clipDragMode = mode;
      _clipDragStartFrame = clip.startFrame;
      _clipDragStartLength = clip.lengthFrames;
      _clipDragStartUseStart = clip.useStart;
      _clipDragStartFraction = clip.sourceFraction;
    });
  }

  void _updateClipDrag(_TrackClip clip, double globalX) {
    if (_draggingClipId != clip.id) return;
    _applyClipDrag(clip, globalX);
    _updateTimelineDragScroll(
      globalX,
      onScroll: () => _applyClipDrag(clip, globalX),
    );
  }

  void _applyClipDrag(_TrackClip clip, double globalX) {
    if (_draggingClipId != clip.id || _clipDragMode == null) return;
    final deltaFrames = (_timelineDragDistance(globalX) / _cellW).round();
    final total = _totalFrames;
    switch (_clipDragMode!) {
      case _ClipDragMode.move:
        final maxStart = total - _clipDragStartLength;
        final newStart = (_clipDragStartFrame + deltaFrames).clamp(
          0,
          maxStart < 0 ? 0 : maxStart,
        );
        if (newStart != clip.startFrame) {
          setState(() => clip.startFrame = newStart);
        }
      case _ClipDragMode.resizeLeft:
        // 右端（startFrame + lengthFrames）を固定し、左端だけ伸縮する。
        final fixedEnd = _clipDragStartFrame + _clipDragStartLength;
        // Audio clips must keep their source interval aligned with the
        // visible trim: moving the left edge right trims the same number of
        // source frames; extending left is limited by the source's frame 0.
        final minStart = clip.trackType == _ClipTrackType.audio
            ? math.max(
                0,
                _clipDragStartFrame -
                    ((_clipDragStartUseStart + _clipDragStartFraction) /
                            clip.playbackRate)
                        .floor(),
              )
            : 0;
        final newStart = (_clipDragStartFrame + deltaFrames).clamp(
          minStart,
          fixedEnd - 1,
        );
        final newLength = fixedEnd - newStart;
        // At the clip's speed, each timeline frame is playbackRate source
        // frames.
        final newSource = clip.trackType == _ClipTrackType.audio
            ? sourcePositionAfter(
                startFrame: _clipDragStartUseStart,
                startFraction: _clipDragStartFraction,
                elapsedFrames: newStart - _clipDragStartFrame,
                rate: clip.playbackRate,
              )
            : (frame: clip.useStart, fraction: clip.sourceFraction);
        if (newStart != clip.startFrame ||
            newLength != clip.lengthFrames ||
            newSource.frame != clip.useStart ||
            newSource.fraction != clip.sourceFraction) {
          setState(() {
            clip.startFrame = newStart;
            clip.lengthFrames = newLength;
            clip.useStart = newSource.frame;
            clip.sourceFraction = newSource.fraction;
          });
        }
      case _ClipDragMode.resizeRight:
        final maxLength = total - _clipDragStartFrame;
        final newLength = (_clipDragStartLength + deltaFrames).clamp(
          1,
          maxLength < 1 ? 1 : maxLength,
        );
        if (newLength != clip.lengthFrames) {
          setState(() => clip.lengthFrames = newLength);
        }
    }
  }

  void _endClipDrag(_TrackClip clip, {bool commit = true}) {
    if (_draggingClipId != clip.id) return;
    _stopTimelineDrag();
    final moved = _clipDragMode == _ClipDragMode.move;
    setState(() {
      if (!commit) {
        clip.startFrame = _clipDragStartFrame;
        clip.lengthFrames = _clipDragStartLength;
        clip.useStart = _clipDragStartUseStart;
        clip.sourceFraction = _clipDragStartFraction;
      }
      _draggingClipId = null;
      _clipDragMode = null;
    });
    final sceneId = _selectedSceneId;
    if (commit && sceneId != null) {
      _persistClipUpdate(clip, sceneId, moved: moved);
    }
  }

  _TimelineSelection? get _timelineSelection {
    if (_isSceneMultiSelect) return _TimelineSelection.scenes;
    if (_isFrameMultiSelect) return _TimelineSelection.frames;
    if (_isClipMultiSelect) return _TimelineSelection.clips;
    return null;
  }

  void _setTimelineSelection(_TimelineSelection? target) {
    if (target == _timelineSelection) return;
    _isSceneMultiSelect = target == _TimelineSelection.scenes;
    _isFrameMultiSelect = target == _TimelineSelection.frames;
    _isClipMultiSelect = target == _TimelineSelection.clips;
    _selectedSceneIds.clear();
    _selectedFrameIndices.clear();
    _selectedClipIds.clear();
  }

  String _timelineSelectionLabel(
    AppLocalizations l10n,
    _TimelineSelection selection,
  ) => switch (selection) {
    _TimelineSelection.scenes => l10n.timelineSelectionScenes,
    _TimelineSelection.frames => l10n.timelineFrameTrackLabel,
    _TimelineSelection.clips => l10n.timelineSelectionClips,
  };

  Widget _timelineToolbarLabel(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Text(text),
        const Icon(Icons.arrow_drop_down, size: 18),
      ],
    ),
  );

  String _timelinePasteLabel(AppLocalizations l10n) {
    final source = _sceneClipboard != null
        ? _TimelineSelection.scenes
        : _frameClipboard != null
        ? _TimelineSelection.frames
        : _clipClipboard != null
        ? _TimelineSelection.clips
        : null;
    return source == null
        ? l10n.commonPaste
        : '${l10n.commonPaste} · ${_timelineSelectionLabel(l10n, source)}';
  }

  bool get _canPasteTimelineSelection =>
      _sceneClipboard != null ||
      (_frameClipboard != null && _selectedSceneId != null) ||
      (_clipClipboard != null &&
          _clipClipboard!.sourceSceneId == _selectedSceneId);

  Widget _timelineContextBar({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('timelineContextToolbar'),
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: IconTheme(
        data: IconThemeData(color: theme.colorScheme.onSecondaryContainer),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 6, end: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _buildTimelinePlacementToolbar(AppLocalizations l10n) {
    final scene = _isSceneCursorActive;
    final paste = _isScenePasteMode || _isFramePasteMode;
    return _timelineContextBar(
      title: _timelineSelectionLabel(
        l10n,
        scene ? _TimelineSelection.scenes : _TimelineSelection.frames,
      ),
      subtitle: paste ? l10n.commonPaste : l10n.commonMove,
      actions: [
        TextButton(
          onPressed: () {
            if (!scene) _stopTimelineDrag(snap: false);
            setState(() {
              _isMoveMode = false;
              _isScenePasteMode = false;
              _isFrameMoveMode = false;
              _isFramePasteMode = false;
            });
            if (!scene) _centerFrameInList();
          },
          child: Text(l10n.commonCancel),
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: scene
              ? (paste
                    ? _confirmScenePaste
                    : () => _confirmMove(
                        context.read<ProjectService>().scenesOf(
                          widget.projectId,
                        ),
                      ))
              : (paste ? _confirmFramePaste : _confirmFrameMove),
          child: Text(l10n.timelineConfirmButton),
        ),
      ],
    );
  }

  Widget _buildSelectionToolbar(
    AppLocalizations l10n,
    _TimelineSelection selection,
  ) {
    final scenes = context.watch<ProjectService>().scenesOf(widget.projectId);
    final total = _totalFrames;
    final count = switch (selection) {
      _TimelineSelection.scenes => _selectedSceneIds.length,
      _TimelineSelection.frames => _selectedFrameIndices.length,
      _TimelineSelection.clips => _selectedClipIds.length,
    };
    final hasSelection = count > 0;
    final forClips = selection == _TimelineSelection.clips;
    final forScenes = selection == _TimelineSelection.scenes;
    final canDelete =
        hasSelection &&
        (forClips || count < (forScenes ? scenes.length : total));
    final actions = <({String label, IconData icon, VoidCallback? run})>[
      (
        label: l10n.layerPanelSelectAll,
        icon: Icons.select_all,
        run: _selectAllFramesOrScenes,
      ),
      if (!forClips) ...[
        (
          label: l10n.commonMove,
          icon: Icons.swap_horiz,
          run: !hasSelection
              ? null
              : forScenes
              ? () => _startMoveMode(scenes)
              : _startFrameMoveMode,
        ),
        (
          label: l10n.themeDuplicateAction,
          icon: Icons.copy_all_outlined,
          run: !hasSelection
              ? null
              : forScenes
              ? () => _duplicateSelectedScenes(scenes)
              : _duplicateSelectedFrames,
        ),
      ],
      (
        label: l10n.commonDelete,
        icon: Icons.delete_outline,
        run: !canDelete
            ? null
            : forClips
            ? _deleteSelectedClips
            : forScenes
            ? _showMultiDeleteConfirm
            : _deleteSelectedFrames,
      ),
    ];
    return _timelineContextBar(
      title: _timelineSelectionLabel(l10n, selection),
      subtitle: l10n.timelineStackSelectedCount(count),
      actions: [
        IconButton(
          tooltip: l10n.commonCopy,
          onPressed: hasSelection ? _copySelectionToClipboard : null,
          icon: const Icon(Icons.content_copy, size: 19),
        ),
        IconButton(
          tooltip: l10n.commonCut,
          onPressed: hasSelection ? _cutSelectionToClipboard : null,
          icon: const Icon(Icons.content_cut, size: 19),
        ),
        IconButton(
          key: const Key('timelinePasteButton'),
          tooltip: _timelinePasteLabel(l10n),
          onPressed: _canPasteTimelineSelection ? _pasteFromClipboard : null,
          icon: const Icon(Icons.content_paste, size: 19),
        ),
        PopupMenuButton<int>(
          key: const Key('timelineSelectionActions'),
          icon: const Icon(Icons.more_horiz),
          onSelected: (index) => actions[index].run?.call(),
          itemBuilder: (_) => [
            for (final (index, action) in actions.indexed)
              PopupMenuItem(
                value: index,
                enabled: action.run != null,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(action.icon, size: 19),
                  title: Text(action.label),
                  enabled: action.run != null,
                ),
              ),
          ],
        ),
        IconButton(
          key: const Key('timelineSelectionDone'),
          tooltip: l10n.timelineClipSelectDoneButton,
          onPressed: () => setState(() => _setTimelineSelection(null)),
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }

  /// 共通レイヤー専用トラック。共通レイヤーは通常レイヤーとは
  /// 別に表示範囲（rangeMode）を持ち、複数フレーム・複数シーンにまたがって
  /// 同一の描画内容を共有表示する。現在選択中のシーンに表示範囲が適用される
  /// 共通レイヤーのみを1レイヤーにつき1行で表示する。
  Widget _buildCommonLayerTrack() {
    final projectService = context.watch<ProjectService>();
    final sceneId = _selectedSceneId;
    if (sceneId == null) return const SizedBox.shrink();
    final total = _totalFrames;
    final rows = <({Layer layer, LayerHome home, int start, int end})>[];
    for (final entry in projectService.commonLayersOf(widget.projectId)) {
      final layer = entry.layer;
      final home = entry.home;
      int start;
      int end;
      switch (layer.rangeMode) {
        case LayerRangeMode.allFrames:
          start = 0;
          end = total - 1;
          break;
        case LayerRangeMode.currentScene:
          if (home.sceneId != sceneId) continue;
          start = 0;
          end = total - 1;
          break;
        case LayerRangeMode.sceneRange:
          if ((layer.rangeSceneId ?? home.sceneId) != sceneId) continue;
          start = 0;
          end = total - 1;
          break;
        case LayerRangeMode.frameRange:
          if (home.sceneId != sceneId) continue;
          start = ((layer.rangeStart ?? 1) - 1).clamp(0, total - 1);
          end = ((layer.rangeEnd ?? start + 1) - 1).clamp(start, total - 1);
          break;
      }
      rows.add((layer: layer, home: home, start: start, end: end));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              for (final r in rows)
                Container(
                  height: 32,
                  foregroundDecoration: _trackRowDivider,
                  child: _buildTrackLabel(
                    r.layer.type == LayerType.watermark
                        ? Icons.branding_watermark
                        : Icons.link,
                    r.layer.name,
                  ),
                ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return NotificationListener<ScrollEndNotification>(
                  onNotification: _handleTrackScrollEnd,
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      _syncFrom(_frameScrollCtrl, updatePlayhead: false);
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _commonLayerScrollCtrl,
                      padding: EdgeInsets.symmetric(
                        horizontal: _trackSidePadding(constraints.maxWidth),
                      ),
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: total * _cellW,
                        child: Column(
                          children: [
                            for (final r in rows)
                              Container(
                                height: 32,
                                foregroundDecoration: _trackRowDivider,
                                child: Stack(
                                  children: [
                                    Row(
                                      children: [
                                        for (int i = 0; i < total; i++)
                                          Container(
                                            width: _cellW,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: BorderSide(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outlineVariant,
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    _buildCommonLayerBar(
                                      r.layer,
                                      r.home,
                                      r.start,
                                      r.end,
                                      total,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 共通レイヤーの表示範囲バー。シングルタップで表示範囲設定ダイアログを開き、
  /// 左右のドラッグハンドルで開始・終了フレームを直接変更できる（
  /// 「タイムライン上では左右のドラッグハンドルでも表示範囲を変更できる」）。
  Widget _buildCommonLayerBar(
    Layer layer,
    LayerHome home,
    int start,
    int end,
    int total,
  ) {
    final sceneId = _selectedSceneId;
    final draft = _commonDragRange;
    final hasDraft = draft?.layerId == layer.id && draft?.sceneId == sceneId;
    final displayStart = hasDraft ? draft!.start : start;
    final displayEnd = hasDraft ? draft!.end : end;
    final left = displayStart * _cellW + _frameMargin;
    final width = (displayEnd - displayStart + 1) * _cellW - _frameMargin * 2;

    void finishDrag({required bool commit}) {
      final result = _commonDragRange;
      if (result == null ||
          result.layerId != layer.id ||
          result.sceneId != sceneId) {
        return;
      }
      _stopTimelineDrag();
      setState(() => _commonDragRange = null);
      if (!commit || (result.start == start && result.end == end)) return;
      context.read<ProjectService>().updateLayer(
        projectId: widget.projectId,
        sceneId: home.sceneId,
        frameIndex: home.frameIndex,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: result.start + 1,
          rangeEnd: result.end + 1,
          rangeSceneId: null,
        ),
      );
    }

    Widget handle({required bool movesStart}) {
      final color = ThemeService.activeColorScheme.onSurface;
      void updateRange(double globalX) {
        final current = _commonDragRange;
        if (current == null ||
            current.layerId != layer.id ||
            current.sceneId != sceneId) {
          return;
        }
        final delta = (_timelineDragDistance(globalX) / _cellW).truncate();
        final newStart = movesStart
            ? (start + delta).clamp(0, total - 1)
            : start;
        final newEnd = (movesStart ? end : end + delta).clamp(
          newStart,
          total - 1,
        );
        if (newStart == current.start && newEnd == current.end) return;
        setState(() {
          _commonDragRange = (
            layerId: layer.id,
            sceneId: sceneId,
            start: newStart,
            end: newEnd,
          );
        });
      }

      return Positioned(
        left: movesStart ? 0 : null,
        right: movesStart ? null : 0,
        top: 0,
        bottom: 0,
        child: Listener(
          onPointerCancel: (_) => finishDrag(commit: false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (details) {
              _startTimelineDrag(details.globalPosition.dx);
              _commonDragRange = (
                layerId: layer.id,
                sceneId: sceneId,
                start: start,
                end: end,
              );
            },
            onHorizontalDragUpdate: (details) {
              final globalX = details.globalPosition.dx;
              updateRange(globalX);
              _updateTimelineDragScroll(
                globalX,
                onScroll: () => updateRange(globalX),
              );
            },
            onHorizontalDragEnd: (_) => finishDrag(commit: true),
            onHorizontalDragCancel: () => finishDrag(commit: false),
            child: Container(
              width: 8,
              color: color.withValues(alpha: 0.24),
              child: Icon(
                Icons.drag_indicator,
                size: 8,
                color: color.withValues(alpha: 0.70),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: 3,
      width: width.clamp(8.0, double.infinity),
      height: 26,
      child: GestureDetector(
        onTap: () => layer.type == LayerType.watermark
            ? _showWatermarkEditDialog(layer)
            : _showCommonLayerRangeDialog(layer, home),
        child: Container(
          decoration: BoxDecoration(
            color:
                (layer.type == LayerType.watermark
                        ? ThemeService.activeColorScheme.secondary
                        : ThemeService.activeColorScheme.primary)
                    .withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: layer.type == LayerType.watermark
                  ? ThemeService.activeColorScheme.secondary
                  : ThemeService.activeColorScheme.primary,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeService.activeColorScheme.onSurface.withValues(
                  alpha: 0.25,
                ),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    layer.name,
                    style: localizedHeadingStyle(
                      context,
                      TextStyle(
                        fontSize: 9,
                        color: ThemeService.activeColorScheme.onSurface,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              handle(movesStart: true),
              handle(movesStart: false),
            ],
          ),
        ),
      ),
    );
  }

  /// 共通レイヤーの表示範囲をレイヤーパネルと同じダイアログで編集する。
  void _showCommonLayerRangeDialog(Layer layer, LayerHome home) {
    final ps = context.read<ProjectService>();
    showDialog<void>(
      context: context,
      builder: (_) => LayerRangeDialog(
        layer: layer,
        homeSceneId: home.sceneId,
        totalFrames: ps.frameCount(widget.projectId, home.sceneId),
        scenes: ps.scenesOf(widget.projectId),
        onConfirm: (mode, start, end, rangeSceneId) {
          ps.updateLayer(
            projectId: widget.projectId,
            sceneId: home.sceneId,
            frameIndex: home.frameIndex,
            layer: layer.copyWith(
              rangeMode: mode,
              rangeStart: start,
              rangeEnd: end,
              rangeSceneId: rangeSceneId,
            ),
          );
        },
      ),
    );
  }

  /// ウォーターマークの角度・大きさ・不透明度・表示範囲（ループ表示）を
  /// まとめて編集するダイアログ。タイムラインの共通レイヤートラックで
  /// ウォーターマークをタップすると開く。登録時だけでなく実際に
  /// プロジェクト内で使うときにいつでも変更できるようにしている。
  void _showWatermarkEditDialog(Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    double angle = layer.watermarkAngle;
    double scale = layer.watermarkScale;
    double opacity = layer.opacity / 100;
    bool loop = layer.rangeMode == LayerRangeMode.allFrames;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(l10n.timelineWatermarkEditTitle),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledSlider(
                    label: l10n.timelineWatermarkAngleLabel,
                    value: angle,
                    min: -180,
                    max: 180,
                    sliderLabel: '${angle.round()}°',
                    valueText: '${angle.round()}°',
                    onChanged: (v) => setS(() => angle = v),
                  ),
                  // 大きさ・不透明度は％で直接入力するので、スライダーも％の
                  // 目盛り（5〜100・0〜100）で持ち、0〜1の値へ戻して保存する。
                  LabeledSlider(
                    label: l10n.timelineWatermarkSizeLabel,
                    value: scale * 100,
                    min: 5,
                    max: 100,
                    sliderLabel: '${(scale * 100).round()}%',
                    valueText: '${(scale * 100).round()}%',
                    onChanged: (v) => setS(() => scale = v / 100),
                  ),
                  LabeledSlider(
                    label: l10n.timelineWatermarkOpacityLabel,
                    value: opacity * 100,
                    min: 0,
                    max: 100,
                    sliderLabel: '${(opacity * 100).round()}%',
                    valueText: '${(opacity * 100).round()}%',
                    onChanged: (v) => setS(() => opacity = v / 100),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.timelineWatermarkLoopLabel),
                    subtitle: Text(
                      l10n.timelineWatermarkLoopSubtitle,
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: loop,
                    onChanged: (v) => setS(() => loop = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!mounted ||
                    !context.read<PremiumService>().isFeatureAvailable(
                      PremiumFeature.watermark,
                    )) {
                  return;
                }
                final home = ps.homeOf(widget.projectId, layer.id);
                if (home == null) return;
                final current = ps
                    .storedLayersOf(
                      widget.projectId,
                      home.sceneId,
                      home.frameIndex,
                    )
                    .where((item) => item.id == layer.id)
                    .firstOrNull;
                if (current == null) return;
                final updated = current.copyWith(
                  watermarkAngle: angle,
                  watermarkScale: scale,
                  opacity: (opacity * 100).round(),
                  rangeMode: loop
                      ? LayerRangeMode.allFrames
                      : LayerRangeMode.currentScene,
                );
                if (angle == current.watermarkAngle &&
                    scale == current.watermarkScale) {
                  ps.updateLayer(
                    projectId: widget.projectId,
                    sceneId: home.sceneId,
                    frameIndex: home.frameIndex,
                    layer: updated,
                  );
                  return;
                }
                if (!current.watermarkScale.isFinite ||
                    current.watermarkScale <= 0) {
                  return;
                }
                final tiles = ps.tileManagerOf(widget.projectId);
                final source =
                    current.watermarkSource ??
                    await _capturePlacedWatermark(
                      ps,
                      current,
                      sceneId: home.sceneId,
                      frameIndex: home.frameIndex,
                    );
                final pixels = source == null
                    ? null
                    : await renderPlacedWatermark(
                        source,
                        width: tiles.canvasWidth,
                        height: tiles.canvasHeight,
                        angle: angle,
                        scale: scale,
                      );
                if (pixels == null ||
                    !mounted ||
                    !identical(tiles, ps.tileManagerOf(widget.projectId)) ||
                    !context.read<PremiumService>().isFeatureAvailable(
                      PremiumFeature.watermark,
                    ) ||
                    !ps
                        .storedLayersOf(
                          widget.projectId,
                          home.sceneId,
                          home.frameIndex,
                        )
                        .contains(current)) {
                  return;
                }
                ps.replaceLayerPixels(
                  projectId: widget.projectId,
                  sceneId: home.sceneId,
                  frameIndex: home.frameIndex,
                  layerId: layer.id,
                  pixels: pixels,
                  updatedLayer: updated.copyWith(watermarkSource: source),
                );
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraTrack() {
    final l10n = AppLocalizations.of(context)!;
    final total = _totalFrames;
    final sceneId = _selectedSceneId;
    final cameraKfs = sceneId == null
        ? const <CameraKeyframe>[]
        : context.watch<ProjectService>().cameraKeyframesOf(
            widget.projectId,
            sceneId,
          );
    // キーフレームが1件もない間は非表示にする。最初の1件は
    // ツールバーのカメラアイコンから追加できる。
    if (cameraKfs.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 32,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      foregroundDecoration: _trackRowDivider,
      child: Row(
        children: [
          _buildTrackLabel(Icons.camera_alt, l10n.timelineCameraTrackLabel),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final padding = _trackSidePadding(constraints.maxWidth);
                return Stack(
                  children: [
                    _buildTrackGrid(_cameraScrollCtrl, total, padding),
                    // キーフレームマーカー
                    ...cameraKfs.map((kf) => _buildCameraKfMarker(kf, padding)),
                    // ＋ボタン
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Tooltip(
                        message: AppLocalizations.of(
                          context,
                        )!.timelineAddCameraKfTooltip,
                        child: GestureDetector(
                          onTap: () => _addCameraKf(),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: ThemeService.activeColorScheme.secondary
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 14,
                              color: ThemeService.activeColorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The speed of a range of the camera's keys.
                    if (cameraKfs.length >= 2)
                      Positioned(
                        right: 28,
                        top: 4,
                        child: Tooltip(
                          message: l10n.keyframeRetimeTitle,
                          child: GestureDetector(
                            key: const ValueKey('cameraKeyframeRetime'),
                            onTap: _retimeCameraKeyframes,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: ThemeService.activeColorScheme.secondary
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.speed,
                                size: 14,
                                color: ThemeService.activeColorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Plays a chosen range of the camera's keys faster or slower (one Undo
  /// step; the keys' values and easing are kept).
  Future<void> _retimeCameraKeyframes() async {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projects = context.read<ProjectService>();
    final keys = projects.cameraKeyframesOf(widget.projectId, sceneId);
    if (keys.length < 2) return;
    final choice = await showKeyframeRetimeDialog(
      context,
      keyFrames: [for (final k in keys) k.frameIndex],
      lastFrame: _totalFrames - 1,
    );
    if (choice == null || !mounted || _selectedSceneId != sceneId) return;
    final current = projects.cameraKeyframesOf(widget.projectId, sceneId);
    final moves = retimeKeyRange(
      [for (final k in current) k.frameIndex],
      fromFrame: choice.fromFrame,
      toFrame: choice.toFrame,
      rate: choice.rate,
      lastFrame: _totalFrames - 1,
    );
    if (moves == null) return;
    projects.replaceCameraKeyframes(
      widget.projectId,
      sceneId,
      moveKeyframes(
        current,
        moves,
        frameOf: (k) => k.frameIndex,
        withFrame: (k, f) => k.copyWith(frameIndex: f),
      ),
    );
  }

  Widget _buildCameraKfMarker(CameraKeyframe kf, double padding) {
    return AnimatedBuilder(
      animation: _cameraScrollCtrl,
      builder: (ctx, child) {
        final scrollOffset = _cameraScrollCtrl.hasClients
            ? _cameraScrollCtrl.offset
            : 0.0;
        final isDragging = _draggingCameraKfOriginalFrame == kf.frameIndex;
        final displayFrame = isDragging
            ? (_draggingCameraKfLiveFrame ?? kf.frameIndex)
            : kf.frameIndex;
        final cx = padding + displayFrame * _cellW + _cellW / 2 - scrollOffset;
        return Positioned(
          left: cx - 7,
          top: 9,
          child: GestureDetector(
            // 自律テスト（Task#128）が長押し無しでドラッグハンドルを一意に
            // 特定できるようキーを付与。kf.frameIndexはドラッグ中も
            // 元の値のまま変わらない（_beginCameraKfDrag等のドキュメント
            // コメント参照）ため、ドラッグ中にキーが不安定になることはない。
            key: ValueKey('cameraKfMarker_${kf.frameIndex}'),
            onTap: () => _showEditCameraKfDialog(kf),
            // ドラッグでキーフレーム位置（フレーム）を変更する。
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) =>
                _beginCameraKfDrag(kf, d.globalPosition.dx),
            onHorizontalDragUpdate: (d) =>
                _updateCameraKfDrag(d.globalPosition.dx),
            onHorizontalDragEnd: (_) => _endCameraKfDrag(kf),
            onHorizontalDragCancel: () => _endCameraKfDrag(kf, commit: false),
            child: Transform.rotate(
              angle: 0.785, // 45°
              child: Container(
                width: isDragging ? 18 : 14,
                height: isDragging ? 18 : 14,
                decoration: BoxDecoration(
                  color: ThemeService.activeColorScheme.secondary,
                  border: Border.all(
                    color: ThemeService.activeColorScheme.onSurface,
                    width: isDragging ? 2 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeService.activeColorScheme.onSurface
                          .withValues(alpha: 0.3),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _beginCameraKfDrag(CameraKeyframe kf, double globalX) {
    _startTimelineDrag(globalX);
    setState(() {
      _draggingCameraKfOriginalFrame = kf.frameIndex;
      _draggingCameraKfLiveFrame = kf.frameIndex;
      _cameraKfDragStartFrame = kf.frameIndex;
    });
  }

  void _updateCameraKfDrag(double globalX) {
    if (_draggingCameraKfOriginalFrame == null) return;
    _applyCameraKfDrag(globalX);
    _updateTimelineDragScroll(
      globalX,
      onScroll: () => _applyCameraKfDrag(globalX),
    );
  }

  void _applyCameraKfDrag(double globalX) {
    final total = _totalFrames;
    final deltaFrames = (_timelineDragDistance(globalX) / _cellW).round();
    final newFrame = (_cameraKfDragStartFrame + deltaFrames).clamp(
      0,
      total > 0 ? total - 1 : 0,
    );
    if (newFrame != _draggingCameraKfLiveFrame) {
      setState(() => _draggingCameraKfLiveFrame = newFrame);
    }
  }

  void _endCameraKfDrag(CameraKeyframe kf, {bool commit = true}) {
    if (_draggingCameraKfOriginalFrame != kf.frameIndex) return;
    _stopTimelineDrag();
    final originalFrame = _draggingCameraKfOriginalFrame;
    final liveFrame = _draggingCameraKfLiveFrame;
    setState(() {
      _draggingCameraKfOriginalFrame = null;
      _draggingCameraKfLiveFrame = null;
    });
    final sceneId = _selectedSceneId;
    if (!commit ||
        sceneId == null ||
        originalFrame == null ||
        liveFrame == null ||
        liveFrame == originalFrame) {
      return;
    }
    final moved = context.read<ProjectService>().updateCameraKeyframe(
      widget.projectId,
      sceneId,
      originalFrame,
      kf.copyWith(frameIndex: liveFrame),
    );
    if (!moved) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.timelineCameraFrameAlreadyHasKeyframe),
          persist: false,
        ),
      );
    }
  }

  Widget _buildTimestampRow(AppLocalizations l10n) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return const SizedBox.shrink();

    final projects = context.watch<ProjectService>();
    final markers = projects.timelineMarkersOf(widget.projectId, sceneId);
    final fps = _projectFps(projects);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rowHeight = math.max(
      38.0,
      MediaQuery.textScalerOf(context).scale(11) * 1.3 + 14,
    );
    return Container(
      key: const ValueKey('timelineTimestampRow'),
      height: rowHeight,
      foregroundDecoration: _trackRowDivider,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(148, MediaQuery.sizeOf(context).width / 3),
              ),
              child: Text(
                l10n.timelineMarkerTrackLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          Expanded(
            child: markers.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    key: ValueKey(('timelineTimestampNames', sceneId)),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    itemCount: markers.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, index) {
                      final marker = markers[index];
                      final label = marker.comment.trim().isEmpty
                          ? 'F${marker.frameIndex + 1}'
                          : marker.comment.trim();
                      final seconds =
                          '${(marker.frameIndex / fps).toStringAsFixed(2)}s';
                      final color = marker.color == null
                          ? colors.primary
                          : Color(marker.color!);
                      return ValueListenableBuilder<int>(
                        valueListenable: _currentFrameNotifier,
                        builder: (context, frame, _) {
                          final selected = frame == marker.frameIndex;
                          return Semantics(
                            selected: selected,
                            child: Tooltip(
                              message: '$label · $seconds',
                              excludeFromSemantics: true,
                              child: _timestampMenu(
                                [marker],
                                (context, controller, _) => TextButton(
                                  key: ValueKey(
                                    'timelineTimestampName-${marker.id}',
                                  ),
                                  onPressed: () {
                                    final wasOpen = controller.isOpen;
                                    _seekToTimestamp(marker.frameIndex);
                                    if (wasOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: selected
                                        ? colors.primaryContainer
                                        : colors.surfaceContainerLow,
                                    foregroundColor: selected
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                    minimumSize: Size.zero,
                                    maximumSize: const Size.fromWidth(220),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: theme.textTheme.labelSmall,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: color,
                                        size: 16,
                                      ),
                                      Flexible(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(seconds),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _currentFrameNotifier,
            builder: (context, frame, _) => IconButton(
              tooltip: l10n.timelineMarkerAddDialogTitle(frame + 1),
              icon: const Icon(Icons.add, size: 18),
              onPressed: _showAddMarkerDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _seekToTimestamp(int frame) {
    if (_isPlaying) _togglePlay();
    _stopTimelineDrag(snap: false);
    final target = frame.clamp(0, _totalFrames - 1);
    if (target == _currentFrame) {
      _centerFrameInList();
    } else {
      _currentFrame = target;
    }
  }

  String _timestampLabel(TimelineMarker marker) => marker.comment.trim().isEmpty
      ? 'F${marker.frameIndex + 1}'
      : marker.comment.trim();

  Widget _timestampMenu(
    List<TimelineMarker> markers,
    MenuAnchorChildBuilder builder,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sceneId = _selectedSceneId;
    final frame = markers.first.frameIndex;
    return MenuAnchor(
      style: MenuStyle(
        minimumSize: const WidgetStatePropertyAll(Size(100, 0)),
        maximumSize: WidgetStatePropertyAll(
          Size(math.min(320, MediaQuery.sizeOf(context).width - 16), 280),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => _seekToTimestamp(frame),
          child: Text('F${frame + 1}'),
        ),
        for (final marker in markers)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 4, 0),
            child: SizedBox(
              width: math.min(274, MediaQuery.sizeOf(context).width - 54),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_drop_down,
                    color: marker.color == null
                        ? scheme.primary
                        : Color(marker.color!),
                  ),
                  Expanded(
                    child: Text(
                      _timestampLabel(marker),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Use menu items so keyboard navigation and dismissal work
                  // the same way as the frame jump above.
                  MenuItemButton(
                    key: ValueKey('timelineTimestampEdit-${marker.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      maximumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => _showEditMarkerDialog(marker),
                    child: Tooltip(
                      message: l10n.commonEdit,
                      child: Icon(
                        Icons.edit_outlined,
                        semanticLabel: l10n.commonEdit,
                      ),
                    ),
                  ),
                  MenuItemButton(
                    key: ValueKey('timelineTimestampDelete-${marker.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      maximumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: sceneId == null
                        ? null
                        : () => _deleteTimestamp(sceneId, marker),
                    child: Tooltip(
                      message: l10n.commonDelete,
                      child: Icon(
                        Icons.delete_outline,
                        semanticLabel: l10n.commonDelete,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      builder: builder,
    );
  }

  Future<bool> _deleteTimestamp(String sceneId, TimelineMarker marker) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await confirmDelete(
          context,
          message: l10n.layerPanelDeleteConfirmTitle(_timestampLabel(marker)),
        ) ||
        !mounted) {
      return false;
    }
    context.read<ProjectService>().removeTimelineMarker(
      widget.projectId,
      sceneId,
      marker.id,
    );
    return true;
  }

  Widget _buildMarkerPin(List<TimelineMarker> markers) {
    final frame = markers.first.frameIndex;
    final labels = markers.map(_timestampLabel).toList();
    final scheme = Theme.of(context).colorScheme;
    return _timestampMenu(
      markers,
      (context, controller, _) => Semantics(
        button: true,
        label: labels.join('\n'),
        child: GestureDetector(
          key: ValueKey('timelineTimestamp-$frame'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          onLongPress: () => _editMarkerAtFrame(markers, labels),
          onSecondaryTap: () => _editMarkerAtFrame(markers, labels),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final marker in markers.take(3))
                    ClipPath(
                      clipper: const _TimestampTriangle(),
                      child: SizedBox(
                        width: markers.length == 1 ? 24 : 13,
                        height: markers.length == 1 ? 19 : 15,
                        child: ColoredBox(
                          color: marker.color == null
                              ? scheme.primary
                              : Color(marker.color!),
                        ),
                      ),
                    ),
                  if (markers.length > 3)
                    Icon(
                      Icons.more_horiz,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editMarkerAtFrame(
    List<TimelineMarker> markers,
    List<String> labels,
  ) async {
    if (markers.length == 1) {
      _showEditMarkerDialog(markers.single);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final frameIndex = markers.first.frameIndex;
    final selected = await showDialog<TimelineMarker>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.timelineMarkerEditDialogTitle(frameIndex + 1)),
        children: [
          for (var index = 0; index < markers.length; index++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, markers[index]),
              child: Text(labels[index]),
            ),
        ],
      ),
    );
    if (mounted && selected != null) _showEditMarkerDialog(selected);
  }

  void _showAddMarkerDialog() => _showMarkerDialog();

  void _showEditMarkerDialog(TimelineMarker marker) =>
      _showMarkerDialog(marker: marker);

  void _showMarkerDialog({TimelineMarker? marker}) {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projects = context.read<ProjectService>();
    final frame = marker?.frameIndex ?? _currentFrame;
    final ctrl = TextEditingController(text: marker?.comment);
    final scheme = Theme.of(context).colorScheme;
    final colors = <int?>[
      null, // The theme's accent, including after switching themes.
      0xFFDA405F,
      0xFFE39926,
      0xFF408A59,
      0xFF387AC4,
      0xFF8854B2,
    ];
    var color = marker?.color;
    if (!colors.contains(color)) colors.add(color);
    showDialog<void>(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: ctrl,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            insetPadding: typingDialogInsetPadding(ctx),
            scrollable: true,
            title: Text(
              marker == null
                  ? l10n.timelineMarkerAddDialogTitle(frame + 1)
                  : l10n.timelineMarkerEditDialogTitle(frame + 1),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.timelineMarkerCommentHint,
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.timelineColorLabel),
                // 色は1行に並べる（48pxずつ並べていて、4色と2色の2行になった）。
                // 押せる所は38×48（ダイアログは中身の固有の幅で決まるので、
                // LayoutBuilderで幅に合わせることはできない）。
                Wrap(
                  children: [
                    for (final swatch in colors)
                      Semantics(
                        selected: swatch == color,
                        child: IconButton(
                          key: ValueKey('timelineTimestampColor-$swatch'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 38,
                            height: kMinInteractiveDimension,
                          ),
                          // 押せる所を48へ広げない（広げると1行に入らない）。
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          tooltip: swatch == null
                              ? l10n.widgetColorFollowTheme
                              : '#${(swatch & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                          onPressed: () => update(() => color = swatch),
                          icon: CircleAvatar(
                            radius: 13,
                            backgroundColor: swatch == null
                                ? scheme.primary
                                : Color(swatch),
                            foregroundColor:
                                (swatch == null
                                            ? scheme.primary
                                            : Color(swatch))
                                        .computeLuminance() >
                                    .4
                                ? Colors.black
                                : Colors.white,
                            child: swatch == color
                                ? const Icon(Icons.check, size: 16)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              if (marker != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: l10n.commonDelete,
                  onPressed: () async {
                    if (await _deleteTimestamp(sceneId, marker) &&
                        ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  if (marker == null) {
                    projects.addTimelineMarker(
                      widget.projectId,
                      sceneId,
                      frame,
                      ctrl.text,
                      color: color,
                    );
                  } else {
                    projects.updateTimelineMarker(
                      widget.projectId,
                      sceneId,
                      TimelineMarker(
                        id: marker.id,
                        frameIndex: marker.frameIndex,
                        comment: ctrl.text,
                        color: color,
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: Text(marker == null ? l10n.commonAdd : l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 演出フィルタートラック。適用中のフィルターが1件も
  /// なければ非表示にし、フィルターごとに専用の行を自動で表示する
  /// （共通レイヤートラックと同じ考え方：重ね掛けしても行が自動で増える
  /// ため、ユーザーが列を手動管理する必要がない）。タップすると演出
  /// フィルター管理シート（並び替え・詳細編集）を開く。
  Widget _buildEffectFilterTrack() {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    final total = _totalFrames;
    final effects = sceneId == null
        ? const <EffectFilterInstance>[]
        : context.watch<ProjectService>().effectFiltersOf(
            widget.projectId,
            sceneId,
          );
    if (effects.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (row, e) in effects.indexed)
            GestureDetector(
              onTap: _showEffectFilterDialog,
              child: Container(
                height: 32,
                foregroundDecoration: _trackRowDivider,
                child: Row(
                  children: [
                    _buildTrackLabel(
                      Icons.movie_filter,
                      _EffectFilterSheet._displayName(l10n, e),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final padding = _trackSidePadding(
                            constraints.maxWidth,
                          );
                          final controller = _effectRowScrollCtrl(row);
                          return Stack(
                            children: [
                              _buildTrackGrid(controller, total, padding),
                              AnimatedBuilder(
                                animation: controller,
                                builder: (ctx, child) {
                                  final scrollOffset = controller.hasClients
                                      ? controller.offset
                                      : 0.0;
                                  final left =
                                      padding +
                                      e.startFrame * _cellW -
                                      scrollOffset;
                                  final width =
                                      (e.endFrame - e.startFrame + 1) * _cellW;
                                  return Positioned(
                                    left: left,
                                    top: 6,
                                    child: Container(
                                      width: width,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: ThemeService
                                            .activeColorScheme
                                            .secondary
                                            .withValues(
                                              alpha: e.enabled ? 0.8 : 0.3,
                                            ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 作品ごとのエンドマーク表示を切り替えるトラック。
  Widget _buildEndCardTrack() {
    return Consumer2<PremiumService, SettingsService>(
      builder: (context, premium, settings, _) {
        final l10n = AppLocalizations.of(context)!;
        final canEditEndCard = premium.isFeatureAvailable(
          PremiumFeature.endCardEdit,
        );
        final projects = context.watch<ProjectService>();
        final project = projects.projects
            .where((project) => project.id == widget.projectId)
            .firstOrNull;
        final hidden = !premium.shouldAppendOfficialEndCard(
          projectHidden: project?.hideEndCard,
          defaultHidden: settings.endCardDefaultHiddenForPremium,
        );
        return GestureDetector(
          // 無料会員：トラックのどこをタップしてもプレミアム誘導へ（仕様：
          // 「一切操作できずタップした瞬間に有料会員へ誘導される」）。
          onTap: canEditEndCard
              ? null
              : () => showPremiumBanner(
                  context,
                  feature: PremiumFeature.endCardEdit,
                ),
          child: Container(
            height: 32,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundDecoration: _trackRowDivider,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  Icons.movie,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                // OSの文字サイズ設定（textScaler）を大きくすると、この
                // ラベルが高さ32pxの帯の横幅を超えてRenderFlex
                // オーバーフローになるため、Flexibleで可変にする。
                Flexible(
                  child: Text(
                    l10n.timelineEndCardTrackLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                if (!canEditEndCard)
                  Icon(
                    Icons.lock,
                    size: 14,
                    color: ThemeService.activeColorScheme.tertiary,
                  )
                else ...[
                  const Spacer(),
                  Text(
                    hidden
                        ? l10n.timelineEndCardHiddenLabel
                        : l10n.timelineEndCardDefaultLogoLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      hidden ? Icons.visibility : Icons.visibility_off,
                      size: 14,
                    ),
                    onPressed: () {
                      if (!premium.isFeatureAvailable(
                        PremiumFeature.endCardEdit,
                      )) {
                        showPremiumBanner(
                          context,
                          feature: PremiumFeature.endCardEdit,
                        );
                        return;
                      }
                      projects.setProjectEndCardHidden(
                        widget.projectId,
                        !hidden,
                      );
                    },
                    tooltip: hidden
                        ? l10n.timelineShowEndCard
                        : l10n.timelineHideEndCard,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _addCameraKf() {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projects = context.read<ProjectService>();
    final keys = projects.cameraKeyframesOf(widget.projectId, sceneId);
    final existing = keys
        .where((key) => key.frameIndex == _currentFrame)
        .firstOrNull;
    if (existing != null) {
      _showEditCameraKfDialog(existing);
      return;
    }
    final draft = CameraEngine()
        .valueAt(keys, _currentFrame)
        .copyWith(frameIndex: _currentFrame);
    _showEditCameraKfDialog(draft, isNew: true);
  }

  void _showEditCameraKfDialog(CameraKeyframe kf, {bool isNew = false}) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projects = context.read<ProjectService>();
    final totalFrames = _totalFrames;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CameraKfSheet(
        projectId: widget.projectId,
        sceneId: sceneId,
        kf: kf,
        totalFrames: totalFrames,
        onDelete: isNew
            ? null
            : () => projects.removeCameraKeyframe(
                widget.projectId,
                sceneId,
                kf.frameIndex,
              ),
        onSave: (newKf) {
          if (isNew) {
            final exists = projects
                .cameraKeyframesOf(widget.projectId, sceneId)
                .any((key) => key.frameIndex == newKf.frameIndex);
            if (exists) return false;
            projects.addCameraKeyframe(widget.projectId, sceneId, newKf);
            return true;
          }
          return projects.updateCameraKeyframe(
            widget.projectId,
            sceneId,
            kf.frameIndex,
            newKf,
          );
        },
      ),
    );
  }

  /// The first row of [type] where a clip from [start] for [length] frames
  /// overlaps none on it; a new row when every row is taken there (so
  /// texts shown at the same time go on rows of their own).
  int _freeRowFor(_ClipTrackType type, int start, int length) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return 0;
    final ps = context.read<ProjectService>();
    final kind = _rowKindOf(type);
    final clips = switch (type) {
      _ClipTrackType.audio => _audioClips.where((c) => !c.isReadAloud).toList(),
      _ClipTrackType.video => _videoClips,
      _ClipTrackType.image => _imageClips,
      _ClipTrackType.text => _textClips,
    };
    final rows = ps.rowNamesOf(widget.projectId, sceneId, kind).length;
    final end = start + length;
    for (var row = 0; row < rows; row++) {
      final taken = clips.any(
        (c) =>
            c.trackRow == row &&
            c.startFrame < end &&
            start < c.startFrame + c.lengthFrames,
      );
      if (!taken) return row;
    }
    ps.addTrackRow(widget.projectId, sceneId, kind);
    return ps.rowNamesOf(widget.projectId, sceneId, kind).length - 1;
  }

  /// Asks for a text and when it shows, then adds it on a text row and opens
  /// it for editing (its look, place and turn are set there, live).
  void _showAddTextDialog() {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final total = _totalFrames;
    var start = _currentFrame.clamp(0, total - 1);
    var length = (total - start).clamp(1, 24);
    showDialog<void>(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: ctrl,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            insetPadding: typingDialogInsetPadding(
              ctx,
              usual: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            ),
            title: Text(l10n.timelineAddTextDialogTitle),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.canvasTextInputHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setS(() {}),
                    ),
                    const SizedBox(height: 8),
                    LabeledSlider(
                      label: l10n.timelineClipStartLabel,
                      value: (start + 1).toDouble(),
                      min: 1,
                      max: math.max(2, total).toDouble(),
                      divisions: math.max(1, total - 1),
                      valueText: 'F${start + 1}',
                      onChanged: (v) => setS(() {
                        start = (v.round() - 1).clamp(0, total - 1);
                        length = length.clamp(1, total - start);
                      }),
                    ),
                    LabeledSlider(
                      label: l10n.timelineClipLengthLabel,
                      value: length.toDouble(),
                      min: 1,
                      // 残りが1フレームでもスライダーが成り立つよう幅を2以上に取り、
                      // 値は残りのフレーム数までに抑える。
                      max: math.max(2, total - start).toDouble(),
                      divisions: math.max(1, total - start - 1),
                      valueText: '${length}F',
                      onChanged: (v) => setS(
                        () => length = v.round().clamp(1, total - start),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: ctrl.text.trim().isEmpty
                    ? null
                    : () {
                        final text = ctrl.text;
                        Navigator.pop(ctx);
                        _addTextClip(sceneId, text, start, length);
                      },
                child: Text(l10n.commonAdd),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTextClip(
    String sceneId,
    String text,
    int start,
    int length,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final home = _currentFrame;
    final name = timelineTextName(text, l10n.timelineMaterialText);
    final textObject = newTimelineText(
      id: '',
      text: text,
      canvasWidth: tm.canvasWidth,
      canvasHeight: tm.canvasHeight,
    );
    final bytes = await rasterizeTimelineText(
      textObject,
      tm.canvasWidth,
      tm.canvasHeight,
    );
    if (!mounted ||
        _selectedSceneId != sceneId ||
        home >= ps.frameCount(widget.projectId, sceneId)) {
      return;
    }
    late int row;
    final layer = ps.editTimeline(widget.projectId, 'Add text clip', () {
      row = _freeRowFor(_ClipTrackType.text, start, length);
      final layer = ps.addLayer(
        projectId: widget.projectId,
        sceneId: sceneId,
        frameIndex: home,
        type: LayerType.timelineText,
        name: name,
      );
      if (bytes != null) {
        tm.replaceLayerPixels(
          ps.tileKeyFor(widget.projectId, sceneId, home, layer.id),
          bytes,
        );
      }
      ps.updateLayer(
        projectId: widget.projectId,
        sceneId: sceneId,
        frameIndex: home,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: start + 1,
          rangeEnd: start + length,
          textObject: textObject.copyWith(id: layer.id),
          trackRow: row,
        ),
      );
      return layer;
    });
    setState(() {
      _textClips.add(
        _TrackClip(
          id: layer.id,
          label: name,
          startFrame: start,
          lengthFrames: length,
          color: _textClipColor,
          trackType: _ClipTrackType.text,
          trackRow: row,
        ),
      );
    });
    _openMaterialEditor(layer.id);
  }

  Future<void> _showAddClipDialog(
    String trackName,
    List<_TrackClip> clips,
    Color color,
    _ClipTrackType trackType,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final allowedExtensions = trackType == _ClipTrackType.audio
        ? const <String>[
            'mp3',
            'wav',
            'm4a',
            'aac',
            'flac',
            'ogg',
            'opus',
            'aiff',
            'wma',
            'mp4',
            'm4v',
            'mov',
            'mkv',
            'webm',
          ]
        : null;

    final fileType = switch (trackType) {
      _ClipTrackType.audio => FileType.custom,

      _ClipTrackType.video => FileType.video,

      _ClipTrackType.image => FileType.image,

      // Text has no file; it is added with its own dialog.
      _ClipTrackType.text => null,
    };
    if (fileType == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: fileType,

      allowedExtensions: allowedExtensions,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    final pickedSourcePath = result.files.first.path!;
    if (!mounted) return;

    // 素材管理：プロジェクトのMaterials/フォルダへコピーし
    // MaterialIDで管理する。同一内容のファイルは重複保存しない。
    final materialType = switch (trackType) {
      _ClipTrackType.audio => MaterialType.audio,
      _ClipTrackType.video => MaterialType.video,
      _ClipTrackType.image || _ClipTrackType.text => MaterialType.image,
    };
    final asset = await context.read<MaterialService>().addMaterial(
      projectId: widget.projectId,
      sourcePath: pickedSourcePath,
      type: materialType,
    );
    if (!mounted) return;
    final pickedPath = await context.read<MaterialService>().pathOf(
      widget.projectId,
      asset.id,
    );
    if (!mounted) return;
    final labelCtrl = TextEditingController(
      text: asset.originalFileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
    int start = _currentFrame;
    int length = 12;
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: labelCtrl,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            // スライダーを置くので、文字を入れるダイアログと同じく横に広げる
            // （既定の幅280pxではスライダー本体が細すぎた）。
            insetPadding: typingDialogInsetPadding(
              ctx,
              usual: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            ),
            title: Text(l10n.timelineAddClipDialogTitle(trackName)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('timelineAddClipLabelField'),
                      controller: labelCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.timelineClipLabelFieldLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 開始フレームは画面上の表示（F1〜）と同じ1始まりの目盛りで
                    // 持ち、0始まりの添字へ戻して保存する。
                    LabeledSlider(
                      label: l10n.timelineClipStartLabel,
                      value: (start + 1).toDouble(),
                      min: 1,
                      max: _totalFrames.toDouble(),
                      divisions: _totalFrames > 1 ? _totalFrames - 1 : 1,
                      sliderLabel: 'F${start + 1}',
                      valueText: 'F${start + 1}',
                      onChanged: (v) => setS(() => start = v.round() - 1),
                    ),
                    LabeledSlider(
                      label: l10n.timelineClipLengthLabel,
                      value: length.toDouble(),
                      min: 1,
                      max: _totalFrames.toDouble(),
                      divisions: _totalFrames,
                      sliderLabel: '${length}F',
                      valueText: '${length}F',
                      onChanged: (v) => setS(() => length = v.round()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () async {
                  final sceneId = _selectedSceneId;
                  Navigator.pop(ctx);
                  if (sceneId == null) return;
                  final newClip = await _createPersistedClip(
                    sceneId: sceneId,
                    label: labelCtrl.text.isEmpty ? trackName : labelCtrl.text,
                    startFrame: start,
                    lengthFrames: length,
                    color: color,
                    trackType: trackType,
                    filePath: pickedPath,
                    asset: asset,
                  );
                  if (newClip != null && mounted) {
                    setState(() => clips.add(newClip));
                  }
                },
                child: Text(l10n.commonAdd),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── タイムライン素材クリップの永続化 ───────────────
  // 音声はシーンのAudioClipsとして、画像・動画はLayerType.timelineImage/
  // timelineVideoのレイヤー（common・watermarkと同じ表示範囲の仕組み）として
  // 永続化する。従来はこの永続化が一切なく、タイムライン画面を離れる・
  // アプリを再起動するとクリップが全て消える重大なバグがあった。

  /// 新規クリップを作成し、種別に応じてAudioClip／Layerとして永続化する。
  /// 永続化後のIDを_TrackClip.idとして使うことで、以後の更新・削除時に
  /// 迷わず対応する永続データを引けるようにする。
  Future<_TrackClip?> _createPersistedClip({
    required String sceneId,
    required String label,
    required int startFrame,
    required int lengthFrames,
    required Color color,
    required _ClipTrackType trackType,
    required String? filePath,
    required MaterialAsset asset,
    bool isReadAloud = false,
  }) async {
    final projectService = context.read<ProjectService>();
    final home = _currentFrame;

    if (trackType == _ClipTrackType.audio) {
      return projectService.editTimeline(
        widget.projectId,
        'Add audio clip',
        () {
          final row = isReadAloud
              ? 0
              : _freeRowFor(trackType, startFrame, lengthFrames);
          final id = 'audio_${DateTime.now().microsecondsSinceEpoch}';
          projectService.addAudioClip(
            widget.projectId,
            sceneId,
            AudioClip(
              id: id,
              label: label,
              materialId: asset.id,
              startFrame: startFrame,
              lengthFrames: lengthFrames,
              trackRow: row,
              isReadAloud: isReadAloud,
            ),
          );
          return _TrackClip(
            id: id,
            label: label,
            startFrame: startFrame,
            lengthFrames: lengthFrames,
            color: color,
            trackType: trackType,
            filePath: filePath,
            materialId: asset.id,
            useEnd: lengthFrames - 1,
            trackRow: row,
            isReadAloud: isReadAloud,
          );
        },
        changesTiles: false,
      );
    }

    // 画像・動画：LayerType.timelineImage/timelineVideoのレイヤーとして追加する。
    // 静止画はそのままラスタライズ、動画は代表画像（プレースホルダー）を
    // レイヤーのピクセルとして保持し、実際の再生プレビューはVideoPlayer
    // コントローラ（既存の仕組み）で行う。
    final w = projectService.tileManagerOf(widget.projectId).canvasWidth;
    final h = projectService.tileManagerOf(widget.projectId).canvasHeight;
    final bytes = trackType == _ClipTrackType.image && filePath != null
        ? await _rasterizeImageFile(filePath, w, h)
        : await _placeholderVideoFrame(w, h);
    if (bytes == null ||
        !mounted ||
        _selectedSceneId != sceneId ||
        home >= projectService.frameCount(widget.projectId, sceneId)) {
      return null;
    }

    return projectService.editTimeline(
      widget.projectId,
      'Add material clip',
      () {
        final row = _freeRowFor(trackType, startFrame, lengthFrames);
        final layer = projectService.addLayer(
          projectId: widget.projectId,
          sceneId: sceneId,
          frameIndex: home,
          type: trackType == _ClipTrackType.video
              ? LayerType.timelineVideo
              : LayerType.timelineImage,
          name: label,
        );
        final tileManager = projectService.tileManagerOf(widget.projectId);
        tileManager.replaceLayerPixels(
          projectService.tileKeyFor(widget.projectId, sceneId, home, layer.id),
          bytes,
        );
        projectService.updateLayer(
          projectId: widget.projectId,
          sceneId: sceneId,
          frameIndex: home,
          layer: layer.copyWith(
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: startFrame + 1,
            rangeEnd: startFrame + lengthFrames,
            materialId: asset.id,
            trackRow: row,
            sourceTrimStart: trackType == _ClipTrackType.video ? 0 : null,
            sourceTrimEnd: trackType == _ClipTrackType.video
                ? lengthFrames - 1
                : null,
          ),
        );

        return _TrackClip(
          id: layer.id,
          label: label,
          startFrame: startFrame,
          lengthFrames: lengthFrames,
          color: color,
          trackType: trackType,
          filePath: filePath,
          materialId: asset.id,
          useEnd: lengthFrames - 1,
          trackRow: row,
        );
      },
    );
  }

  /// 画像ファイルをキャンバスサイズへラスタライズする（中央配置・アスペクト比維持）。
  Future<Uint8List?> _rasterizeImageFile(String filePath, int w, int h) async {
    final fileBytes = await File(filePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(fileBytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    final scale = (w / image.width < h / image.height)
        ? w / image.width
        : h / image.height;
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    final dx = (w - drawW) / 2;
    final dy = (h - drawH) / 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawW, drawH),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    image.dispose();
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// 動画クリップのレイヤーピクセル代表画像（プレースホルダー）を生成する。
  /// 実際の動画フレームのデコードは行わない（低スペック端末対策・処理の単純化）。
  /// 編集中のライブプレビューはVideoPlayerControllerで別途表示する。
  Future<Uint8List?> _placeholderVideoFrame(int w, int h) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()
        ..color = ThemeService.activeColorScheme.surfaceContainerHighest,
    );
    final iconSize = (w < h ? w : h) * 0.15;
    final cx = w / 2;
    final cy = h / 2;
    final path = ui.Path()
      ..moveTo(cx - iconSize / 2, cy - iconSize / 2)
      ..lineTo(cx - iconSize / 2, cy + iconSize / 2)
      ..lineTo(cx + iconSize / 2, cy)
      ..close();
    canvas.drawPath(
      path,
      ui.Paint()..color = ThemeService.activeColorScheme.onSurfaceVariant,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    return byteData?.buffer.asUint8List();
  }

  void _deletePersistedClip(_TrackClip clip, String sceneId) {
    final projectService = context.read<ProjectService>();
    projectService.editTimeline(widget.projectId, 'Delete clip', () {
      if (clip.trackType == _ClipTrackType.audio) {
        projectService.removeAudioClip(widget.projectId, sceneId, clip.id);
      } else {
        projectService.removeLayer(
          projectId: widget.projectId,
          sceneId: sceneId,
          frameIndex: _currentFrame,
          layerId: clip.id,
        );
      }
      // 使用中の列だけを表示する方針：追加専用の行（2行目以降）が
      // 空になったら自動で畳む（構造ごと削除して行番号を詰め直す）。1行目は
      // 常に存在する既定行なので畳まず、中身がなければ表示だけを省く。
      if (clip.trackRow > 0 && !clip.isReadAloud) {
        final remaining = switch (clip.trackType) {
          _ClipTrackType.audio => _audioClips,
          _ClipTrackType.video => _videoClips,
          _ClipTrackType.image => _imageClips,
          _ClipTrackType.text => _textClips,
        };
        final stillUsed = remaining.any((c) => c.trackRow == clip.trackRow);
        if (!stillUsed &&
            projectService.removeTrackRow(
              widget.projectId,
              sceneId,
              _rowKindOf(clip.trackType),
              clip.trackRow,
            )) {
          // The rows after it moved up one: read the clips' rows again.
          _loadClipsFromProject(sceneId);
        }
      }
    }, changesTiles: false);
  }

  /// 素材クリップ（画像・動画・音声）を複製し、元クリップの直後へ配置する。
  void _duplicateClip(_TrackClip clip) {
    final maxStart = (_totalFrames - clip.lengthFrames).clamp(0, 1 << 30);
    final newStart = (clip.startFrame + clip.lengthFrames).clamp(0, maxStart);
    final projects = context.read<ProjectService>();
    projects.editTimeline(widget.projectId, 'Duplicate clip', () {
      _duplicateClipAt(clip, newStart);
    });
  }

  /// 素材クリップ（画像・動画・音声）を複製し、指定の開始フレーム
  /// （・任意で行番号）へ配置する。複製ボタン（元クリップの直後へ配置）と
  /// クリップの貼り付け（コピー元との相対位置・任意の行を指定）の
  /// 両方から使う共通処理。音声はAudioClipとして、画像・動画は元レイヤーの
  /// ピクセルデータを新規レイヤーへコピーした上で表示範囲を複製先の位置へ
  /// ずらして追加する。
  void _duplicateClipAt(
    _TrackClip clip,
    int newStart, {
    int? overrideTrackRow,
  }) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projectService = context.read<ProjectService>();
    final targetRow = overrideTrackRow ?? clip.trackRow;

    if (clip.trackType == _ClipTrackType.audio) {
      final id = 'audio_${DateTime.now().microsecondsSinceEpoch}';
      projectService.addAudioClip(
        widget.projectId,
        sceneId,
        AudioClip(
          id: id,
          label: clip.label,
          materialId: clip.materialId,
          startFrame: newStart,
          lengthFrames: clip.lengthFrames,
          volume: clip.volume,
          fadeIn: clip.fadeIn,
          fadeOut: clip.fadeOut,
          sourceStartFrame: clip.useStart,
          sourceStartFraction: clip.sourceFraction,
          playbackRate: clip.playbackRate,
          trackRow: targetRow,
          isReadAloud: clip.isReadAloud,
        ),
      );
      if (mounted) {
        setState(
          () => _audioClips.add(
            _TrackClip(
              id: id,
              label: clip.label,
              startFrame: newStart,
              lengthFrames: clip.lengthFrames,
              color: clip.color,
              trackType: clip.trackType,
              filePath: clip.filePath,
              materialId: clip.materialId,
              volume: clip.volume,
              fadeIn: clip.fadeIn,
              fadeOut: clip.fadeOut,
              useStart: clip.useStart,
              useEnd: clip.sourceAfter(clip.lengthFrames - 1).frame,
              sourceFraction: clip.sourceFraction,
              playbackRate: clip.playbackRate,
              soundFollowsSpeed: clip.soundFollowsSpeed,
              trackRow: targetRow,
              isReadAloud: clip.isReadAloud,
            ),
          ),
        );
      }
      return;
    }

    final home =
        projectService.homeOf(widget.projectId, clip.id) ??
        (sceneId: sceneId, frameIndex: _currentFrame);
    final sourceLayer = projectService
        .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
        .where((l) => l.id == clip.id)
        .firstOrNull;
    if (sourceLayer == null) return;

    final newLayer = projectService.addLayer(
      projectId: widget.projectId,
      sceneId: home.sceneId,
      frameIndex: home.frameIndex,
      type: sourceLayer.type,
      name: clip.label,
    );
    projectService
        .tileManagerOf(widget.projectId)
        .copyLayer(
          projectService.tileKeyFor(
            widget.projectId,
            home.sceneId,
            home.frameIndex,
            clip.id,
          ),
          projectService.tileKeyFor(
            widget.projectId,
            home.sceneId,
            home.frameIndex,
            newLayer.id,
          ),
        );
    // 元の素材の設定（文字・配置のキーフレーム・マスク・不透明度・
    // 動画の音量と使用範囲）をそのまま写し、表示範囲と行だけを変える。
    // キーフレームは表示範囲と一緒にずらす。
    final shift = newStart - clip.startFrame;
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: home.sceneId,
      frameIndex: home.frameIndex,
      layer: sourceLayer.copyWith(
        id: newLayer.id,
        name: clip.label,
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: newStart + 1,
        rangeEnd: newStart + clip.lengthFrames,
        trackRow: targetRow,
        textObject: sourceLayer.textObject?.copyWith(id: newLayer.id),
        keyframes: [
          for (final k in sourceLayer.keyframes)
            k.copyWith(frameIndex: k.frameIndex + shift),
        ],
      ),
    );
    if (!mounted) return;
    final newClip = _TrackClip(
      id: newLayer.id,
      label: clip.label,
      startFrame: newStart,
      lengthFrames: clip.lengthFrames,
      color: clip.color,
      trackType: clip.trackType,
      filePath: clip.filePath,
      materialId: clip.materialId,
      useStart: clip.useStart,
      useEnd: clip.useEnd,
      sourceFraction: clip.sourceFraction,
      playbackRate: clip.playbackRate,
      soundFollowsSpeed: clip.soundFollowsSpeed,
      volume: clip.volume,
      videoOpacity: clip.videoOpacity,
      trackRow: targetRow,
    );
    setState(() {
      switch (clip.trackType) {
        case _ClipTrackType.video:
          _videoClips.add(newClip);
        case _ClipTrackType.text:
          _textClips.add(newClip);
        case _ClipTrackType.image || _ClipTrackType.audio:
          _imageClips.add(newClip);
      }
    });
  }

  // ─── クリップの複数選択・コピー・切り取り・貼り付け ─────────

  /// Every material clip of the scene (text, image, video and audio).
  List<_TrackClip> get _allClips => [
    ..._textClips,
    ..._imageClips,
    ..._videoClips,
    ..._audioClips,
  ];

  List<_TrackClip> _clipsOfType(_ClipTrackType type) => switch (type) {
    _ClipTrackType.audio => _audioClips,
    _ClipTrackType.video => _videoClips,
    _ClipTrackType.image => _imageClips,
    _ClipTrackType.text => _textClips,
  };

  void _selectAllClips() {
    setState(() {
      _selectedClipIds
        ..clear()
        ..addAll(_allClips.map((c) => c.id));
    });
  }

  /// 現在の値をそのままコピーした新しい_TrackClipインスタンスを返す
  /// （クリップボードへ保存する時点のスナップショットとして使う。以後の
  /// ドラッグ操作等で元のインスタンスが変化してもクリップボードの内容は
  /// 変わらない）。
  _TrackClip _snapshotClip(_TrackClip c) => _TrackClip(
    id: c.id,
    label: c.label,
    startFrame: c.startFrame,
    lengthFrames: c.lengthFrames,
    color: c.color,
    trackType: c.trackType,
    filePath: c.filePath,
    materialId: c.materialId,
    volume: c.volume,
    fadeIn: c.fadeIn,
    fadeOut: c.fadeOut,
    useStart: c.useStart,
    useEnd: c.useEnd,
    sourceFraction: c.sourceFraction,
    playbackRate: c.playbackRate,
    soundFollowsSpeed: c.soundFollowsSpeed,
    videoOpacity: c.videoOpacity,
    trackRow: c.trackRow,
    isReadAloud: c.isReadAloud,
  );

  void _copySelectedClips() {
    final sceneId = _selectedSceneId;
    if (sceneId == null || _selectedClipIds.isEmpty) return;
    final selected = _allClips
        .where((c) => _selectedClipIds.contains(c.id))
        .map(_snapshotClip)
        .toList();
    if (selected.isEmpty) return;
    setState(() {
      _clipClipboard = (sourceSceneId: sceneId, clips: selected, isCut: false);
    });
  }

  void _cutSelectedClips() {
    final sceneId = _selectedSceneId;
    if (sceneId == null || _selectedClipIds.isEmpty) return;
    final selected = _allClips
        .where((c) => _selectedClipIds.contains(c.id))
        .map(_snapshotClip)
        .toList();
    if (selected.isEmpty) return;
    setState(() {
      _clipClipboard = (sourceSceneId: sceneId, clips: selected, isCut: true);
    });
  }

  void _deleteSelectedClips() {
    final sceneId = _selectedSceneId;
    if (sceneId == null || _selectedClipIds.isEmpty) return;
    final targets = _allClips
        .where((c) => _selectedClipIds.contains(c.id))
        .toList();
    context.read<ProjectService>().editTimeline(
      widget.projectId,
      'Delete clips',
      () {
        for (final clip in targets) {
          setState(() {
            _videoClips.remove(clip);
            _audioClips.remove(clip);
            _imageClips.remove(clip);
            _textClips.remove(clip);
          });
          _deletePersistedClip(clip, sceneId);
        }
      },
      changesTiles: false,
    );
    setState(() {
      _selectedClipIds.clear();
      _isClipMultiSelect = false;
    });
  }

  /// クリップボードの内容を、選択中シーンの現在地（_currentFrame）へ
  /// 貼り付ける。複数クリップをまとめてコピーしていた場合はコピー時の
  /// 相対位置関係を保ったまま貼り付ける。貼り付け先が既存の他のクリップと
  /// 重なる場合は、前に配置・後ろに配置・重ねて配置（行を1つ増やす）の
  /// 3択をユーザーへ確認する。
  Future<void> _pasteClipsAtCurrentFrame() async {
    final clipboard = _clipClipboard;
    final sceneId = _selectedSceneId;
    if (clipboard == null || sceneId == null) return;
    // クリップの一覧はシーンごとにロードされるため、コピー元と異なる
    // シーンを見ている間は貼り付けを行わない（ボタン側でも無効化する）。
    if (clipboard.sourceSceneId != sceneId) return;

    final anchor = clipboard.clips
        .map((c) => c.startFrame)
        .reduce((a, b) => a < b ? a : b);
    final targets = <String, int>{
      for (final c in clipboard.clips)
        c.id: (_currentFrame + (c.startFrame - anchor)).clamp(0, 1 << 30),
    };

    // 貼り付け先が既存クリップと重なっていないか判定する。切り取りの
    // 場合は貼り付け後に削除される元クリップ自身との重なりは無視する。
    final excludeIds = clipboard.isCut
        ? clipboard.clips.map((c) => c.id).toSet()
        : <String>{};
    final conflicts = <({int start, int end})>[];
    final conflictingClipIds = <String>{};
    for (final c in clipboard.clips) {
      final existingOfType = _clipsOfType(c.trackType);
      final start = targets[c.id]!;
      final end = start + c.lengthFrames;
      for (final other in existingOfType) {
        if (excludeIds.contains(other.id)) continue;
        if (other.trackRow != c.trackRow ||
            other.isReadAloud != c.isReadAloud) {
          continue;
        }
        final oStart = other.startFrame;
        final oEnd = other.startFrame + other.lengthFrames;
        if (start < oEnd && oStart < end) {
          conflicts.add((start: oStart, end: oEnd));
          conflictingClipIds.add(c.id);
        }
      }
    }

    String strategy = 'keep';
    if (conflicts.isNotEmpty) {
      final chosen = await _showClipOverlapDialog();
      if (chosen == null || !mounted || _selectedSceneId != sceneId) return;
      strategy = chosen;
    }

    context.read<ProjectService>().editTimeline(
      widget.projectId,
      'Paste clips',
      () {
        int? beforeShift, afterShift;
        final newRowForClipId = <String, int>{};
        if (strategy == 'before') {
          final earliestConflictStart = conflicts
              .map((c) => c.start)
              .reduce((a, b) => a < b ? a : b);
          final batchMaxEnd = clipboard.clips
              .map((c) => targets[c.id]! + c.lengthFrames)
              .reduce((a, b) => a > b ? a : b);
          beforeShift = earliestConflictStart - batchMaxEnd;
        } else if (strategy == 'after') {
          final latestConflictEnd = conflicts
              .map((c) => c.end)
              .reduce((a, b) => a > b ? a : b);
          final batchMinStart = clipboard.clips
              .map((c) => targets[c.id]!)
              .reduce((a, b) => a < b ? a : b);
          afterShift = latestConflictEnd - batchMinStart;
        } else if (strategy == 'newRow') {
          final ps = context.read<ProjectService>();
          final newRowsByType = <_ClipTrackType, int>{};
          for (final clip in clipboard.clips.where(
            (c) => conflictingClipIds.contains(c.id),
          )) {
            // Speech already has a dedicated row. Ordinary audio keeps its
            // own row namespace even when both kinds are pasted together.
            if (clip.isReadAloud) {
              newRowForClipId[clip.id] = 0;
              continue;
            }
            final type = clip.trackType;
            final row = newRowsByType.putIfAbsent(type, () {
              final rowKind = _rowKindOf(type);
              ps.addTrackRow(widget.projectId, sceneId, rowKind);
              return ps.rowNamesOf(widget.projectId, sceneId, rowKind).length -
                  1;
            });
            newRowForClipId[clip.id] = row;
          }
        }

        for (final c in clipboard.clips) {
          var start = targets[c.id]!;
          int? overrideRow;
          if (strategy == 'before' && beforeShift != null) {
            start = (start + beforeShift).clamp(0, 1 << 30);
          } else if (strategy == 'after' && afterShift != null) {
            start = (start + afterShift).clamp(0, 1 << 30);
          } else if (strategy == 'newRow' &&
              conflictingClipIds.contains(c.id)) {
            overrideRow = newRowForClipId[c.id];
          }
          _duplicateClipAt(c, start, overrideTrackRow: overrideRow);
        }

        if (clipboard.isCut) {
          for (final c in clipboard.clips) {
            setState(() {
              _videoClips.removeWhere((x) => x.id == c.id);
              _audioClips.removeWhere((x) => x.id == c.id);
              _imageClips.removeWhere((x) => x.id == c.id);
              _textClips.removeWhere((x) => x.id == c.id);
            });
            _deletePersistedClip(c, sceneId);
          }
          setState(() => _clipClipboard = null);
        }
      },
    );
    setState(() {
      _isClipMultiSelect = false;
      _selectedClipIds.clear();
    });
  }

  /// 貼り付け先が既存クリップと重なる場合の3択ダイアログ。
  /// 選んだ結果を'before'/'after'/'newRow'のいずれかで返す（キャンセルはnull）。
  Future<String?> _showClipOverlapDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineClipOverlapDialogTitle),
        content: Text(l10n.timelineClipOverlapDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'before'),
            child: Text(l10n.timelineClipOverlapPlaceBefore),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'after'),
            child: Text(l10n.timelineClipOverlapPlaceAfter),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'newRow'),
            child: Text(l10n.timelineClipOverlapPlaceNewRow),
          ),
        ],
      ),
    );
  }

  /// 再生ヘッド位置で、そこをまたいでいる全トラックのクリップを分割する。
  /// 音声・読み上げ音声・動画・画像・テキストを同じ操作で扱い、
  /// 素材内の再生位置（sourceTrim/sourceStartFrame）と外側のフェードを保つ。
  /// The inclusive source end of the left half of [clip] (a video) split
  /// after [leftLength] frames.
  static int _videoSplitLeftEnd(_TrackClip clip, int leftLength) {
    final last = clip.sourceAfter(leftLength - 1);
    return math.min(
      last.fraction > 0 ? last.frame + 1 : last.frame,
      clip.useEnd,
    );
  }

  void _applySplitAtCurrentFrame() {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final splitFrame = _currentFrame;
    final targets = _allClips
        .where(
          (clip) =>
              splitFrame > clip.startFrame &&
              splitFrame < clip.startFrame + clip.lengthFrames,
        )
        .toList();
    if (targets.isEmpty) return;

    final projectService = context.read<ProjectService>();
    final rightClips = <_TrackClip>[];
    final processedClips = <_TrackClip>[];
    projectService.editTimeline(widget.projectId, 'Split timeline clips', () {
      for (var index = 0; index < targets.length; index++) {
        final clip = targets[index];
        final leftLength = splitFrame - clip.startFrame;
        final rightLength = clip.lengthFrames - leftLength;
        // Where the right half starts in the source, at the clip's speed
        // (a fraction of a frame is kept so it plays exactly as before).
        final rightSource = clip.sourceAfter(leftLength);
        final rightSourceStart = rightSource.frame;
        // A video's picture: the left half's last frame may sit part-way into
        // a source frame (at a speed other than 1x), so its inclusive end is
        // the next frame (not past the clip's own end) or that frame would be
        // held from its start. A right half that starts past the used range
        // keeps that source start: its picture holds the last used frame and
        // it is silent, as that part of the clip was.
        final videoLeftEnd = _videoSplitLeftEnd(clip, leftLength);
        final videoRightStart = rightSourceStart;
        final videoRightFraction = rightSource.fraction;
        final rightId = clip.trackType == _ClipTrackType.audio
            ? 'audio_split_${DateTime.now().microsecondsSinceEpoch}_$index'
            : 'layer_split_${DateTime.now().microsecondsSinceEpoch}_$index';

        if (clip.trackType == _ClipTrackType.audio) {
          projectService.updateAudioClip(
            widget.projectId,
            sceneId,
            AudioClip(
              id: clip.id,
              label: clip.label,
              materialId: clip.materialId,
              startFrame: clip.startFrame,
              lengthFrames: leftLength,
              volume: clip.volume,
              fadeIn: clip.fadeIn,
              fadeOut: 0,
              sourceStartFrame: clip.useStart,
              sourceStartFraction: clip.sourceFraction,
              playbackRate: clip.playbackRate,
              trackRow: clip.trackRow,
              isReadAloud: clip.isReadAloud,
            ),
          );
          projectService.addAudioClip(
            widget.projectId,
            sceneId,
            AudioClip(
              id: rightId,
              label: clip.label,
              materialId: clip.materialId,
              startFrame: splitFrame,
              lengthFrames: rightLength,
              volume: clip.volume,
              fadeIn: 0,
              fadeOut: clip.fadeOut,
              sourceStartFrame: rightSourceStart,
              sourceStartFraction: rightSource.fraction,
              playbackRate: clip.playbackRate,
              trackRow: clip.trackRow,
              isReadAloud: clip.isReadAloud,
            ),
          );
          processedClips.add(clip);
          rightClips.add(
            _TrackClip(
              id: rightId,
              label: clip.label,
              startFrame: splitFrame,
              lengthFrames: rightLength,
              color: clip.color,
              trackType: clip.trackType,
              filePath: clip.filePath,
              materialId: clip.materialId,
              volume: clip.volume,
              fadeIn: 0,
              fadeOut: clip.fadeOut,
              useStart: rightSourceStart,
              useEnd: clip.useEnd,
              sourceFraction: rightSource.fraction,
              playbackRate: clip.playbackRate,
              soundFollowsSpeed: clip.soundFollowsSpeed,
              trackRow: clip.trackRow,
              isReadAloud: clip.isReadAloud,
            ),
          );
          continue;
        }

        final home =
            projectService.homeOf(widget.projectId, clip.id) ??
            (sceneId: sceneId, frameIndex: splitFrame - 1);
        final sourceLayer = projectService
            .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
            .where((layer) => layer.id == clip.id)
            .firstOrNull;
        if (sourceLayer == null) continue;

        final newLayer = projectService.addLayer(
          projectId: widget.projectId,
          sceneId: home.sceneId,
          frameIndex: home.frameIndex,
          type: sourceLayer.type,
          name: sourceLayer.name,
          id: rightId,
        );
        projectService
            .tileManagerOf(widget.projectId)
            .copyLayer(
              projectService.tileKeyFor(
                widget.projectId,
                home.sceneId,
                home.frameIndex,
                clip.id,
              ),
              projectService.tileKeyFor(
                widget.projectId,
                home.sceneId,
                home.frameIndex,
                newLayer.id,
              ),
            );

        final isVideo = clip.trackType == _ClipTrackType.video;
        projectService.updateLayer(
          projectId: widget.projectId,
          sceneId: home.sceneId,
          frameIndex: home.frameIndex,
          layer: sourceLayer.copyWith(
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: clip.startFrame + 1,
            rangeEnd: splitFrame,
            sourceTrimEnd: isVideo ? videoLeftEnd : null,
          ),
        );
        projectService.updateLayer(
          projectId: widget.projectId,
          sceneId: home.sceneId,
          frameIndex: home.frameIndex,
          layer: sourceLayer.copyWith(
            id: newLayer.id,
            name: sourceLayer.name,
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: splitFrame + 1,
            rangeEnd: clip.startFrame + clip.lengthFrames,
            sourceTrimStart: isVideo ? videoRightStart : null,
            sourceTrimStartFraction: isVideo ? videoRightFraction : null,
            sourceTrimEnd: isVideo ? clip.useEnd : null,
            textObject: sourceLayer.textObject?.copyWith(id: newLayer.id),
          ),
        );
        // The right half moves with the left half's group, as before.
        final group = projectService.groupContainingLayer(
          widget.projectId,
          home.sceneId,
          clip.id,
        );
        if (group != null) {
          projectService.updateLayerGroup(
            widget.projectId,
            home.sceneId,
            group.copyWith(
              memberLayerIds: [...group.memberLayerIds, newLayer.id],
            ),
          );
        }
        processedClips.add(clip);
        rightClips.add(
          _TrackClip(
            id: newLayer.id,
            label: clip.label,
            startFrame: splitFrame,
            lengthFrames: rightLength,
            color: clip.color,
            trackType: clip.trackType,
            filePath: clip.filePath,
            materialId: clip.materialId,
            useStart: isVideo ? videoRightStart : clip.useStart,
            useEnd: clip.useEnd,
            sourceFraction: isVideo ? videoRightFraction : 0,
            playbackRate: clip.playbackRate,
            soundFollowsSpeed: clip.soundFollowsSpeed,
            volume: clip.volume,
            videoOpacity: clip.videoOpacity,
            trackRow: clip.trackRow,
          ),
        );
      }
    });

    if (!mounted) return;
    setState(() {
      for (final clip in processedClips) {
        final leftLength = splitFrame - clip.startFrame;
        clip.lengthFrames = leftLength;
        if (clip.trackType == _ClipTrackType.video) {
          clip.useEnd = _videoSplitLeftEnd(clip, leftLength);
        } else if (clip.trackType == _ClipTrackType.audio) {
          clip.fadeOut = 0;
          clip.useEnd = clip.sourceAfter(leftLength - 1).frame;
        }
      }
      for (final clip in rightClips) {
        _clipsOfType(clip.trackType).add(clip);
      }
      _isSplitMode = false;
      _selectedClipIds.clear();
    });
    _syncMediaPlayback();
  }

  /// クリップ詳細シートを閉じた時点で、編集内容（音量・フェード・不透明度・
  /// 使用範囲）をまとめて永続化する（スライダー操作のたびに保存すると低スペック
  /// 端末で負荷が高いため、シートを閉じた時点でまとめて反映する）。
  ///
  /// [moved]: the clip was moved as a whole, so its keyframes move with it
  /// (resizing an end leaves them where they are).
  void _persistClipUpdate(
    _TrackClip clip,
    String sceneId, {
    bool moved = false,
  }) {
    final stillExists = _allClips.contains(clip);
    if (!stillExists) return; // 削除済みなら何もしない
    final projectService = context.read<ProjectService>();
    if (clip.trackType == _ClipTrackType.audio) {
      final saved = projectService
          .audioClipsOf(widget.projectId, sceneId)
          .where((item) => item.id == clip.id)
          .firstOrNull;
      if (saved == null ||
          saved.label == clip.label &&
              saved.startFrame == clip.startFrame &&
              saved.lengthFrames == clip.lengthFrames &&
              saved.volume == clip.volume &&
              saved.fadeIn == clip.fadeIn &&
              saved.fadeOut == clip.fadeOut &&
              saved.sourceStartFrame == clip.useStart &&
              saved.sourceStartFraction == clip.sourceFraction &&
              saved.playbackRate == clip.playbackRate &&
              saved.trackRow == clip.trackRow) {
        return;
      }
      projectService.updateAudioClip(
        widget.projectId,
        sceneId,
        AudioClip(
          id: clip.id,
          label: clip.label,
          materialId: clip.materialId,
          startFrame: clip.startFrame,
          lengthFrames: clip.lengthFrames,
          volume: clip.volume,
          fadeIn: clip.fadeIn,
          fadeOut: clip.fadeOut,
          sourceStartFrame: clip.useStart,
          sourceStartFraction: clip.sourceFraction,
          playbackRate: clip.playbackRate,
          trackRow: clip.trackRow,
          isReadAloud: clip.isReadAloud,
        ),
      );
    } else {
      // レイヤーの実データが物理的に存在する「ホーム」フレームを使う
      // （表示範囲を持つレイヤーは_currentFrameが範囲外の場合があるため）。
      final home =
          projectService.homeOf(widget.projectId, clip.id) ??
          (sceneId: sceneId, frameIndex: _currentFrame);
      final layer = projectService
          .storedLayersOf(widget.projectId, home.sceneId, home.frameIndex)
          .where((l) => l.id == clip.id)
          .firstOrNull;
      if (layer == null) return;
      // 不透明度・音量・使用範囲・文字・配置は編集パネルがレイヤーへ
      // 直接書き込むので、ここでは表示範囲（タイムライン上のドラッグ移動・
      // ハンドルによるリサイズ）だけを書き戻す（以前はドラッグ操作で
      // 見た目上は移動・リサイズできても永続化されない不具合があった）。
      // 素材ごと動かしたときは、配置のキーフレームも一緒にずらす。
      final oldStart = (layer.rangeStart ?? 1) - 1;
      if (layer.rangeStart == clip.startFrame + 1 &&
          layer.rangeEnd == clip.startFrame + clip.lengthFrames) {
        return;
      }
      final shift = moved ? clip.startFrame - oldStart : 0;
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: home.sceneId,
        frameIndex: home.frameIndex,
        layer: layer.copyWith(
          rangeStart: clip.startFrame + 1,
          rangeEnd: clip.startFrame + clip.lengthFrames,
          keyframes: shift == 0
              ? null
              : [
                  for (final k in layer.keyframes)
                    k.copyWith(frameIndex: k.frameIndex + shift),
                ],
        ),
      );
    }
  }

  /// シーンの永続データ（AudioClips・タイムライン画像/動画レイヤー）から
  /// _audioClips/_videoClips/_imageClipsを再構築する。シーン切替・画面初期化時に
  /// 呼び出す（従来はここが存在せず、画面を開き直すたびにクリップが消えていた）。
  String? _clipsLoadedForSceneId;

  void _ensureClipsLoaded(String sceneId) {
    if (_clipsLoadedForSceneId == sceneId) return;
    _clipsLoadedForSceneId = sceneId;
    _loadClipsFromProject(sceneId);
  }

  Future<void> _loadClipsFromProject(String sceneId) async {
    final projectService = context.read<ProjectService>();
    final materialService = context.read<MaterialService>();
    final scene = projectService.sceneOf(widget.projectId, sceneId);
    if (scene == null) return;

    final audio = <_TrackClip>[];
    for (final a in scene.audioClips) {
      final path = a.materialId == null
          ? null
          : await materialService.pathOf(widget.projectId, a.materialId!);
      audio.add(
        _TrackClip(
          id: a.id,
          label: a.label,
          startFrame: a.startFrame,
          lengthFrames: a.lengthFrames,
          color: ThemeService.activeColorScheme.tertiary,
          trackType: _ClipTrackType.audio,
          filePath: path,
          materialId: a.materialId,
          volume: a.volume,
          fadeIn: a.fadeIn,
          fadeOut: a.fadeOut,
          useStart: a.sourceStartFrame,
          useEnd: sourcePositionAfter(
            startFrame: a.sourceStartFrame,
            startFraction: a.sourceStartFraction,
            elapsedFrames: a.lengthFrames - 1,
            rate: a.playbackRate,
          ).frame,
          sourceFraction: a.sourceStartFraction,
          playbackRate: a.playbackRate,
          trackRow: a.trackRow,
          isReadAloud: a.isReadAloud,
        ),
      );
    }

    final video = <_TrackClip>[];
    final image = <_TrackClip>[];
    final text = <_TrackClip>[];
    for (final frame in scene.frames) {
      for (final layer in frame.layers) {
        if (layer.type == LayerType.timelineText) {
          final start = (layer.rangeStart ?? 1) - 1;
          final end = layer.rangeEnd ?? (start + 1);
          text.add(
            _TrackClip(
              id: layer.id,
              label: layer.name,
              startFrame: start,
              lengthFrames: (end - start).clamp(1, 1 << 30),
              color: _textClipColor,
              trackType: _ClipTrackType.text,
              filePath: null,
              trackRow: layer.trackRow,
            ),
          );
          continue;
        }
        if (layer.type != LayerType.timelineVideo &&
            layer.type != LayerType.timelineImage) {
          continue;
        }
        final start = (layer.rangeStart ?? 1) - 1;
        final end = layer.rangeEnd ?? (start + 1);
        final length = (end - start).clamp(1, 1 << 30);
        final path = layer.materialId == null
            ? null
            : await materialService.pathOf(widget.projectId, layer.materialId!);
        final clip = _TrackClip(
          id: layer.id,
          label: layer.name,
          startFrame: start,
          lengthFrames: length,
          color: layer.type == LayerType.timelineVideo
              ? ThemeService.activeColorScheme.primary
              : ThemeService.activeColorScheme.secondary,
          trackType: layer.type == LayerType.timelineVideo
              ? _ClipTrackType.video
              : _ClipTrackType.image,
          filePath: path,
          materialId: layer.materialId,
          useStart: layer.sourceTrimStart ?? 0,
          useEnd:
              layer.sourceTrimEnd ??
              ((layer.sourceTrimStart ?? 0) + length - 1),
          sourceFraction: layer.sourceTrimStartFraction,
          playbackRate: layer.type == LayerType.timelineVideo
              ? layer.playbackRate
              : 1.0,
          soundFollowsSpeed: layer.videoSoundFollowsSpeed,
          volume: layer.type == LayerType.timelineVideo
              ? layer.videoVolume.clamp(0.0, 1.0)
              : 1.0,
          videoOpacity: layer.opacity / 100.0,
          trackRow: layer.trackRow,
        );
        if (layer.type == LayerType.timelineVideo) {
          video.add(clip);
        } else {
          image.add(clip);
        }
      }
    }

    if (!mounted ||
        _selectedSceneId != sceneId ||
        !identical(projectService.sceneOf(widget.projectId, sceneId), scene)) {
      if (mounted && _clipsLoadedForSceneId == sceneId) {
        setState(() => _clipsLoadedForSceneId = null);
      }
      return;
    }
    setState(() {
      _audioClips
        ..clear()
        ..addAll(audio);
      _videoClips
        ..clear()
        ..addAll(video);
      _imageClips
        ..clear()
        ..addAll(image);
      _textClips
        ..clear()
        ..addAll(text);
    });
  }

  void _showEditClipDialog(_TrackClip clip) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    if (clip.trackType != _ClipTrackType.audio) {
      // テキスト・画像・動画は、プレビューを見ながら調整できる編集パネルで。
      _openMaterialEditor(clip.id);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ClipDetailSheet(
        clip: clip,
        totalFrames: _totalFrames,
        speedEndFrameAt: (rate) => _speedEndFrame(clip, rate),
        onSpeedChange: (rate) => _applyAudioSpeed(clip, rate),
        onDelete: () {
          setState(() {
            _audioClips.remove(clip);
            _videoClips.remove(clip);
            _imageClips.remove(clip);
            _textClips.remove(clip);
          });
          _deletePersistedClip(clip, sceneId);
        },
        onDuplicate: () => _duplicateClip(clip),

        onChanged: () {
          setState(() {});

          _syncMediaPlayback();
        },

        isPlaying: () => _isPlaying,

        onTogglePlay: _togglePlay,
      ),
    ).then((_) => _persistClipUpdate(clip, sceneId));
  }

  void _showEffectFilterDialog() {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EffectFilterSheet(
        projectId: widget.projectId,
        sceneId: sceneId,
        totalFrames: _totalFrames,
        currentFrame: _currentFrame,
      ),
    );
  }

  /// キャンバスモードへ戻る前に、プロジェクト本体（.niaproファイル）を
  /// 明示的に保存する。編集後にプロジェクト一覧へ戻ると手動セーブの
  /// データが消えていた不具合の原因調査により発覚。従来は三点
  /// メニューの「保存」「プロジェクト保存」からしかこの保存処理を呼べず、
  /// それらは他の項目（セーブツリー・自動塗り実行）と役割が被っていた
  /// ため削除し、代わりに画面を離れるタイミングで自動的に保存されるよう
  /// にした。
  Future<void> _saveAndGoToCanvas() async {
    if (_isPlaying) _togglePlay();
    // 保存に失敗した場合は無理に画面遷移せず、保存データを失わないよう
    // その場に留まりエラーを知らせる（失敗時に黙って進むと、セーブされて
    // いないデータが消えたことにユーザーが気づけなくなるため）。
    try {
      await context.read<ProjectService>().saveProject(widget.projectId);
    } catch (e) {
      debugPrint('timeline: saveProject failed before returning to canvas: $e');
      if (mounted) await _showSaveFailedDialog();
      return;
    }
    if (!mounted) return;
    context.go(
      Uri(
        path: '/canvas/${widget.projectId}',
        queryParameters: {
          'scene': ?_selectedSceneId,
          'frame': '$_currentFrame',
        },
      ).toString(),
    );
  }

  Future<void> _saveFrameEdit() async {
    try {
      await context.read<ProjectService>().saveProject(widget.projectId);
    } catch (error) {
      debugPrint('timeline: saving frame changes failed: $error');
      if (mounted) await _showSaveFailedDialog();
    }
  }

  Future<void> _showSaveFailedDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSaveFailedDialogTitle),
        content: Text(l10n.timelineSaveFailedDialogBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  /// プロジェクト一覧へ戻るボタン：タップ時に「保存して
  /// 戻る」か「保存せず戻る」かをポップアップで選べるようにする。
  Future<void> _confirmBackToProjectList() async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        // 狭い画面では左右の空きを縮め、ボタンの語を途中で折らない。
        insetPadding: dialogInsetPadding(ctx),
        // 題・本文・ボタンの韓国語の語は、1行に入れば途中で折らない（普通の
        // Textでは「프로젝트 목록으로 돌아가 / 기」と折れた）。
        title: messageText(l10n.timelineBackToProjectListDialogTitle),
        content: messageText(l10n.timelineBackToProjectListDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: messageText(l10n.timelineBackToProjectListDiscardButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: messageText(l10n.timelineBackToProjectListSaveButton),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'save') {
      // 「保存して戻る」は生データの自動保存ではなく、キャンバス画面の
      // 「保存」ボタンと同じ手動セーブ（セーブツリー）画面を経由させる。
      // 以前はここでProjectService.saveProject()を直接呼ぶだけだったため、
      // セーブノードを作る手動セーブ画面が一切表示されないまま
      // プロジェクト一覧へ戻ってしまっていた。タイムライン内の他の
      // 「保存」導線（三点メニュー等）と同じentry=timelineを指定し、
      // セーブツリー画面から戻ってきたタイミングで、続けてプロジェクト
      // 一覧へ遷移する。
      final saves = context.read<SaveTreeService>();
      final before = saves.latestSaveOf(widget.projectId);
      await context.push('/save-tree/${widget.projectId}?entry=timeline');
      if (!mounted) return;
      // 保存せずに戻った（取り消した・保存に失敗した・保存を消しただけ）
      // ときは一覧へ移らず、タイムラインに残る。
      if (!saves.savedSince(widget.projectId, before)) return;
    }
    if (mounted) context.go('/home');
  }

  /// 現在タイムラインに表示中のフレーム1枚を、静止画（PNG/JPEG）として
  /// exportsフォルダへ書き出す（タイムライン三点メニュー「フレームを
  /// 画像で書き出す」）。動画としての書き出し（export_screen.dart）とは
  /// 別に、コマ単体を1枚絵として取り出したい場合向けの簡易機能。
  Future<void> _exportCurrentFrameImage() async {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;

    final asJpeg = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineExportFrameDialogTitle),
        content: Text(l10n.timelineExportFrameDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.timelineExportFramePngOption),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.timelineExportFrameJpegOption),
          ),
        ],
      ),
    );
    if (asJpeg == null || !mounted) return;

    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null) return;
    final scenes = ps.scenesOf(widget.projectId);
    final tileManager = ps.tileManagerOf(widget.projectId);
    final materials = context.read<MaterialService>();

    try {
      final videoMaterials = await materials.videoSnapshotOf(widget.projectId);
      final engine = ExportEngine();
      final path = await engine.exportFrameImage(
        projectName: project.name,
        scenes: scenes,
        tileManager: tileManager,
        sceneId: sceneId,
        frameIndex: _currentFrame,
        drawingWidth: project.drawingWidth,
        drawingHeight: project.drawingHeight,
        width: project.exportWidth,
        height: project.exportHeight,
        backgroundColor: project.backgroundColor,
        asJpeg: asJpeg,
        sourceFps: project.fps,
        videoMaterials: videoMaterials,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.timelineExportFrameSuccessSnackbar(path.split('/').last),
          ),
        ),
      );
      if (engine.videoLeftOut > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.exportVideosLeftOut(engine.videoLeftOut)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.timelineExportFrameErrorSnackbar)),
      );
    }
  }

  /// 現在のシーンの長さ（フレーム数）を、フレーム数またはそこから換算した
  /// 秒数のどちらからでも一括変更できるダイアログ（タイムライン三点メニュー
  /// 「長さ変更」）。1コマずつの＋／－操作の手間を省く。fps自体は変更しない
  /// （fpsは基本設定・プロジェクト作成時に決めるものとして扱う）。
  void _showDurationChangeDialog() {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final fps = project?.fps ?? 24;
    int frames = ps.frameCount(widget.projectId, sceneId).clamp(1, 1 << 30);
    const maxFrames = 7200 * 60; // プレミアム上限2時間相当を目安にした上限
    final framesController = TextEditingController(text: '$frames');
    final secondsController = TextEditingController(
      text: (frames / fps).toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (_) => DisposeOnUnmount(
        controller: framesController,
        builder: (_) => DisposeOnUnmount(
          controller: secondsController,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
              insetPadding: typingDialogInsetPadding(ctx),
              title: Text(l10n.timelineDurationChangeMenuItem),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SteppedSlider(
                    value: frames.toDouble(),
                    min: 1,
                    max: maxFrames.toDouble(),
                    compact: true,
                    onChanged: (v) => setS(() {
                      frames = v.round();
                      framesController.text = '$frames';
                      secondsController.text = (frames / fps).toStringAsFixed(
                        1,
                      );
                    }),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: framesController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: l10n.timelineDurationFramesLabel,
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed == null) return;
                            setS(() {
                              frames = parsed.clamp(1, maxFrames);
                              secondsController.text = (frames / fps)
                                  .toStringAsFixed(1);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: secondsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: l10n.timelineDurationSecondsLabel,
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed == null) return;
                            setS(() {
                              frames = (parsed * fps).round().clamp(
                                1,
                                maxFrames,
                              );
                              framesController.text = '$frames';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    if (ps.sceneFrameShrinkHasContent(
                      widget.projectId,
                      sceneId,
                      frames,
                    )) {
                      final confirmed = await showDialog<bool>(
                        context: ctx,
                        builder: (dialogCtx) => AlertDialog(
                          title: Text(l10n.timelineDurationShrinkConfirmTitle),
                          content: Text(l10n.timelineDurationShrinkConfirmBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: Text(l10n.commonCancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              child: Text(l10n.commonDelete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }
                    if (!mounted || !ctx.mounted) return;
                    final added =
                        frames - ps.frameCount(widget.projectId, sceneId);
                    if (added > 0 && !_canAddFrames(added)) return;
                    ps.setSceneFrameCount(widget.projectId, sceneId, frames);
                    setState(() {
                      _currentFrame = _currentFrame.clamp(0, frames - 1);
                      _selectedFrameIndices.removeWhere((i) => i >= frames);
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// キャンバスサイズ変更ダイアログ（タイムライン三点メニュー）。
  void _showCanvasSizeChangeDialog() {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null) return;
    showDialog(
      context: context,
      builder: (_) => _CanvasSizeChangeDialog(
        projectId: widget.projectId,
        sceneId: sceneId,
        frameIndex: _currentFrame,
        oldWidth: project.drawingWidth,
        oldHeight: project.drawingHeight,
      ),
    );
  }

  void _showAutofillDialog() {
    final l10n = AppLocalizations.of(context)!;
    int selected = 0;
    // 実行対象は選択フレーム・シーン単位・全フレームから選べる。
    // フレーム一覧に複数選択機能がないため「選択フレーム」は「現在のフレームのみ」で代替する。
    _AutofillScope scope = _AutofillScope.currentFrame;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelAutofillMethodTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.layerPanelAutofillNote1,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.timelineAutofillNote2,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (v) => setS(() => selected = v!),
                  child: Column(
                    children: [
                      RadioListTile<int>(
                        title: Text(l10n.layerPanelAutofillRepaintTitle),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.layerPanelAutofillRepaintHint,
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              l10n.layerPanelAutofillRepaintNote,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        value: 0,
                        dense: true,
                      ),
                      RadioListTile<int>(
                        title: Text(l10n.layerPanelAutofillColorUpdateTitle),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.layerPanelAutofillColorUpdateHint,
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              l10n.layerPanelAutofillColorUpdateNote,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        value: 1,
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.timelineAutofillTargetLabel,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                RadioGroup<_AutofillScope>(
                  groupValue: scope,
                  onChanged: (v) => setS(() => scope = v!),
                  child: Column(
                    children: [
                      RadioListTile<_AutofillScope>(
                        title: Text(l10n.timelineAutofillScopeCurrentFrame),
                        value: _AutofillScope.currentFrame,
                        dense: true,
                      ),
                      RadioListTile<_AutofillScope>(
                        title: Text(l10n.timelineAutofillScopeCurrentScene),
                        value: _AutofillScope.currentScene,
                        dense: true,
                      ),
                      RadioListTile<_AutofillScope>(
                        title: Text(l10n.timelineAutofillScopeAllScenes),
                        value: _AutofillScope.allScenes,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _runBatchAutofill(
                  scope,
                  selected == 0
                      ? AutofillMode.repaint
                      : AutofillMode.colorUpdate,
                );
              },
              child: Text(l10n.layerPanelExecuteButton),
            ),
          ],
        ),
      ),
    );
  }

  /// 自動塗り一括実行（タイムラインモードからの実行、対象は
  /// 現在フレーム／シーン単位／全フレームから選択）。対象範囲内の全フレームを
  /// 走査し、自動塗り用線画レイヤーごとにruleAutofillForLayerを実行する。
  Future<void> _runBatchAutofill(
    _AutofillScope scope,
    AutofillMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final presetService = context.read<AutofillPresetService>();
    final toneService = context.read<ToneService>();
    final scenes = ps.scenesOf(widget.projectId);
    if (scenes.isEmpty) return;

    // 対象(sceneId, frameIndex)一覧を構築
    final targets = <(String, int)>[];
    switch (scope) {
      case _AutofillScope.currentFrame:
        final sceneId = _selectedSceneId ?? scenes.first.id;
        targets.add((sceneId, _currentFrame));
      case _AutofillScope.currentScene:
        final sceneId = _selectedSceneId ?? scenes.first.id;
        final count = ps.frameCount(widget.projectId, sceneId);
        for (int f = 0; f < count; f++) {
          targets.add((sceneId, f));
        }
      case _AutofillScope.allScenes:
        for (final scene in scenes) {
          final count = ps.frameCount(widget.projectId, scene.id);
          for (int f = 0; f < count; f++) {
            targets.add((scene.id, f));
          }
        }
    }

    var progress = 0.0;
    var applied = 0;
    var cancelled = false;
    var batchFailed = false;
    var failedFrames = 0;
    final frameErrors = <String>{};
    StateSetter? updateProgress;
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          updateProgress = (update) {
            if (dialogContext.mounted) setDialogState(update);
          };
          return PopScope(
            canPop: false,
            child: ProgressDialog(
              title: l10n.timelineAutofillProgressTitle,
              progress: progress,
              subtitle: l10n.timelineAutofillProgressSubtitle(targets.length),
              onCancel: () => cancelled = true,
            ),
          );
        },
      ),
    );
    unawaited(navigator.push(route));

    try {
      await ps.runWithGroupedUndo(
        description: l10n.timelineAutofillProgressTitle,
        operation: () async {
          for (var i = 0; i < targets.length && !cancelled && mounted; i++) {
            final (sceneId, frameIndex) = targets[i];
            try {
              final layers = ps.layersOf(widget.projectId, sceneId, frameIndex);
              final lineartLayers = layers.where(
                (l) => l.type == LayerType.autoFillLineart,
              );
              for (final lineartLayer in lineartLayers) {
                if (cancelled || !mounted) break;
                final result = await runAutofillForLayer(
                  projectService: ps,
                  presetService: presetService,
                  toneService: toneService,
                  projectId: widget.projectId,
                  sceneId: sceneId,
                  frameIndex: frameIndex,
                  lineartLayer: lineartLayer,
                  mode: mode,
                );
                if (result == AutofillBatchResult.applied) applied++;
              }
              // 対応する線画レイヤーが存在しない孤立した自動塗りレイヤー（
              // 「線画レイヤーなし・塗りレイヤーあり」の行）は、選択中のモードに
              // 関わらず不透明度ロック＋最新色での塗りつぶしのみを行う。
              final orphanedLayers = layers.where(
                (l) => isOrphanedAutofillLayer(layers, l),
              );
              for (final orphanedLayer in orphanedLayers) {
                if (cancelled || !mounted) break;
                final result = await runAutofillForOrphanedLayer(
                  projectService: ps,
                  presetService: presetService,
                  projectId: widget.projectId,
                  sceneId: sceneId,
                  frameIndex: frameIndex,
                  autofillLayer: orphanedLayer,
                );
                if (result == AutofillBatchResult.applied) applied++;
              }
            } catch (error, stack) {
              failedFrames++;
              frameErrors.add(
                error is FileSystemException
                    ? l10n.timelineAutofillFileError
                    : l10n.timelineAutofillProcessingError,
              );
              AppErrorReporter.record(error, stack);
            }
            progress = (i + 1) / targets.length;
            updateProgress?.call(() {});
          }
        },
      );
    } catch (error, stack) {
      batchFailed = true;
      AppErrorReporter.record(error, stack);
    } finally {
      if (route.isActive) navigator.removeRoute(route);
    }

    if (!mounted) return;
    setState(() {});
    final message = [
      if (batchFailed) l10n.timelineAutofillBatchFailed,
      if (cancelled) l10n.timelineAutofillBatchCancelled,
      if (failedFrames > 0) l10n.timelineAutofillFailedFrames(failedFrames),
      ...frameErrors,
      if (!batchFailed && !cancelled && failedFrames == 0)
        l10n.timelineAutofillCompleteSnackbar(applied),
    ].join(' ');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AutofillScope { currentFrame, currentScene, allScenes }

// ─── キャンバスサイズ変更ダイアログ ───────────────────────────────────────

enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

/// キャンバスサイズ変更ダイアログの本体。現在のフレームのプレビュー上に、
/// 新しいキャンバスサイズに対応する矩形を重ねて表示する。矩形の内側を
/// ドラッグすると位置を、四隅のハンドルをドラッグするとサイズを変更でき、
/// 元のサイズ付近ではスナップする。幅・高さ・角度はスライダーでも指定
/// できる（角度を指定すると、まず画像全体をその角度で回転してから、
/// 幅・高さ・位置で指定した範囲を切り出す）。
class _CanvasSizeChangeDialog extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final int oldWidth;
  final int oldHeight;

  const _CanvasSizeChangeDialog({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.oldWidth,
    required this.oldHeight,
  });

  @override
  State<_CanvasSizeChangeDialog> createState() =>
      _CanvasSizeChangeDialogState();
}

class _CanvasSizeChangeDialogState extends State<_CanvasSizeChangeDialog> {
  static const int _minEdge = 64;
  // 新規プロジェクト作成画面のカスタムサイズ上限（Full HD相当）に揃える。
  static const int _maxEdge = 1920;
  static const double _previewBoxSize = 260.0;
  static const double _handleSize = 22.0;
  // ドラッグでのサイズ・位置変更が、変更前の値からこの範囲内に収まったら
  // ぴったり元の値へスナップする（キャンバス座標単位）。
  static const int _snapPx = 12;

  late int newW = widget.oldWidth;
  late int newH = widget.oldHeight;
  int cropX = 0;
  int cropY = 0;
  double angle = 0;

  /// 回転を適用する場合の外接矩形サイズ（回転なしなら元のキャンバス
  /// サイズそのもの）。切り出し座標（cropX/cropY）はこの矩形の左上を
  /// 基準にする。
  (double, double) get _refSize {
    if (angle == 0) {
      return (widget.oldWidth.toDouble(), widget.oldHeight.toDouble());
    }
    final rad = angle * math.pi / 180;
    final ca = math.cos(rad).abs();
    final sa = math.sin(rad).abs();
    final w = widget.oldWidth * ca + widget.oldHeight * sa;
    final h = widget.oldWidth * sa + widget.oldHeight * ca;
    return (w, h);
  }

  void _dragMove(Offset deltaCanvas) {
    setState(() {
      cropX += deltaCanvas.dx.round();
      cropY += deltaCanvas.dy.round();
      if (cropX.abs() <= _snapPx) cropX = 0;
      if (cropY.abs() <= _snapPx) cropY = 0;
    });
  }

  void _dragCorner(_CropCorner corner, Offset deltaCanvas) {
    final dx = deltaCanvas.dx.round();
    final dy = deltaCanvas.dy.round();
    setState(() {
      switch (corner) {
        case _CropCorner.topLeft:
          final fixedRight = cropX + newW;
          final fixedBottom = cropY + newH;
          var w = fixedRight - (cropX + dx);
          var h = fixedBottom - (cropY + dy);
          if ((w - widget.oldWidth).abs() <= _snapPx) w = widget.oldWidth;
          if ((h - widget.oldHeight).abs() <= _snapPx) h = widget.oldHeight;
          newW = w.clamp(_minEdge, _maxEdge);
          newH = h.clamp(_minEdge, _maxEdge);
          cropX = fixedRight - newW;
          cropY = fixedBottom - newH;
        case _CropCorner.topRight:
          final fixedBottom = cropY + newH;
          var w = newW + dx;
          var h = fixedBottom - (cropY + dy);
          if ((w - widget.oldWidth).abs() <= _snapPx) w = widget.oldWidth;
          if ((h - widget.oldHeight).abs() <= _snapPx) h = widget.oldHeight;
          newW = w.clamp(_minEdge, _maxEdge);
          newH = h.clamp(_minEdge, _maxEdge);
          cropY = fixedBottom - newH;
        case _CropCorner.bottomLeft:
          final fixedRight = cropX + newW;
          var w = fixedRight - (cropX + dx);
          var h = newH + dy;
          if ((w - widget.oldWidth).abs() <= _snapPx) w = widget.oldWidth;
          if ((h - widget.oldHeight).abs() <= _snapPx) h = widget.oldHeight;
          newW = w.clamp(_minEdge, _maxEdge);
          newH = h.clamp(_minEdge, _maxEdge);
          cropX = fixedRight - newW;
        case _CropCorner.bottomRight:
          var w = newW + dx;
          var h = newH + dy;
          if ((w - widget.oldWidth).abs() <= _snapPx) w = widget.oldWidth;
          if ((h - widget.oldHeight).abs() <= _snapPx) h = widget.oldHeight;
          newW = w.clamp(_minEdge, _maxEdge);
          newH = h.clamp(_minEdge, _maxEdge);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final markColor = context.watch<ThemeService>().current.updateMarkColor;
    final scheme = Theme.of(context).colorScheme;

    final (refW, refH) = _refSize;
    // プレビュー全体は「元のキャンバス（回転適用後の外接矩形）」と
    // 「新サイズの枠」の両方を含む範囲を基準にスケールする。これにより
    // 枠を元のキャンバスより外へ広げても、プレビュー内に収まって見える。
    final unionLeft = math.min(0.0, cropX.toDouble());
    final unionTop = math.min(0.0, cropY.toDouble());
    final unionRight = math.max(refW, cropX + newW.toDouble());
    final unionBottom = math.max(refH, cropY + newH.toDouble());
    final unionW = unionRight - unionLeft;
    final unionH = unionBottom - unionTop;
    final scale = _previewBoxSize / math.max(unionW, unionH);
    final boxW = unionW * scale;
    final boxH = unionH * scale;

    final refLeft = (0 - unionLeft) * scale;
    final refTop = (0 - unionTop) * scale;
    final refBoxW = refW * scale;
    final refBoxH = refH * scale;
    final artworkW = widget.oldWidth * scale;
    final artworkH = widget.oldHeight * scale;
    final artworkLeft = refLeft + refBoxW / 2 - artworkW / 2;
    final artworkTop = refTop + refBoxH / 2 - artworkH / 2;

    final cropLeft = (cropX - unionLeft) * scale;
    final cropTop = (cropY - unionTop) * scale;
    final cropW = newW * scale;
    final cropH = newH * scale;
    const handleRadius = _handleSize / 2;

    Widget cornerHandle(_CropCorner corner, double left, double top) =>
        Positioned(
          left: left,
          top: top,
          width: _handleSize,
          height: _handleSize,
          child: GestureDetector(
            // 自律テスト（Task#128）がハンドルを一意に特定できるようキーを
            // 付与。
            key: ValueKey('canvasSizeCorner_${corner.name}'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _dragCorner(corner, d.delta / scale),
            child: Container(
              decoration: BoxDecoration(
                color: markColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ThemeService.activeColorScheme.onSurface,
                  width: 2,
                ),
              ),
            ),
          ),
        );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(l10n.timelineCanvasSizeChangeMenuItem),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.timelineCanvasSizeDragHint,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // The full handles must be inside the Stack's hit-test bounds,
              // including when the crop touches the edge of the artwork.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: boxW + _handleSize,
                  height: boxH + _handleSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 回転前のキャンバスの外接矩形（回転時のみ薄く表示する参考枠）。
                      if (angle != 0)
                        Positioned(
                          left: refLeft + handleRadius,
                          top: refTop + handleRadius,
                          width: refBoxW,
                          height: refBoxH,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: artworkLeft + handleRadius,
                        top: artworkTop + handleRadius,
                        width: artworkW,
                        height: artworkH,
                        child: IgnorePointer(
                          child: Transform.rotate(
                            angle: angle * math.pi / 180,
                            child: _TimelinePreview(
                              backgroundColor: _projectBackgroundOf(
                                ps,
                                widget.projectId,
                              ),
                              tileManager: ps.tileManagerOf(widget.projectId),
                              layers: ps
                                  .stackedLayersOf(
                                    widget.projectId,
                                    widget.sceneId,
                                    widget.frameIndex,
                                  )
                                  .layers,
                              sceneId: widget.sceneId,
                              frameIndex: widget.frameIndex,
                              cameraKeyframes: ps.cameraKeyframesOf(
                                widget.projectId,
                                widget.sceneId,
                              ),
                              effectFilters: ps.effectFiltersOf(
                                widget.projectId,
                                widget.sceneId,
                              ),
                              layerHomes: ps.layerHomesOf(widget.projectId),
                              groups: ps.layerGroupsOf(
                                widget.projectId,
                                widget.sceneId,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 新キャンバスサイズの範囲を示す枠。枠内をドラッグすると位置
                      // （cropX/cropY）を、四隅のハンドルをドラッグするとサイズ
                      // （newW/newH）を変更できる。
                      Positioned(
                        left: cropLeft + handleRadius,
                        top: cropTop + handleRadius,
                        width: cropW,
                        height: cropH,
                        child: GestureDetector(
                          onPanUpdate: (d) => _dragMove(d.delta / scale),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: markColor, width: 2),
                              color: markColor.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                      cornerHandle(_CropCorner.topLeft, cropLeft, cropTop),
                      cornerHandle(
                        _CropCorner.topRight,
                        cropLeft + cropW,
                        cropTop,
                      ),
                      cornerHandle(
                        _CropCorner.bottomLeft,
                        cropLeft,
                        cropTop + cropH,
                      ),
                      cornerHandle(
                        _CropCorner.bottomRight,
                        cropLeft + cropW,
                        cropTop + cropH,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LabeledSlider(
                label: l10n.newProjectWidthShort,
                min: _minEdge.toDouble(),
                max: _maxEdge.toDouble(),
                value: newW.clamp(_minEdge, _maxEdge).toDouble(),
                sliderLabel: '${newW}px',
                onChanged: (v) => setState(() => newW = v.round()),
              ),
              LabeledSlider(
                label: l10n.newProjectHeightShort,
                min: _minEdge.toDouble(),
                max: _maxEdge.toDouble(),
                value: newH.clamp(_minEdge, _maxEdge).toDouble(),
                sliderLabel: '${newH}px',
                onChanged: (v) => setState(() => newH = v.round()),
              ),
              LabeledSlider(
                label: l10n.timelineCanvasSizeAngleLabel,
                min: -180,
                max: 180,
                value: angle,
                sliderLabel: '${angle.round()}°',
                onChanged: (v) => setState(() => angle = v.abs() <= 2 ? 0 : v),
              ),
              Text(
                '$newW × $newH px',
                // 自律テスト（Task#128）がドラッグ後のサイズ変化を読み取れる
                // ようキーを付与。
                key: const ValueKey('canvasSizeDimensionsText'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            await context.read<ProjectService>().resizeCanvas(
              widget.projectId,
              newWidth: newW,
              newHeight: newH,
              cropX: cropX,
              cropY: cropY,
              angleDegrees: angle,
            );
          },
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

// ─── タイムラインプレビューウィジェット ───────────────────────────────────

/// The background colour chosen for the project (when creating or editing
/// it), which the canvas, the export and every preview show.
int _projectBackgroundOf(ProjectService ps, String projectId) =>
    ps.projects.where((p) => p.id == projectId).firstOrNull?.backgroundColor ??
    0xFFFFFFFF;

/// The timeline screen's source of decoded video frames for its previews
/// (null while it is not available, e.g. before the materials are read).
class _TimelinePreviewVideoFrames extends InheritedWidget {
  const _TimelinePreviewVideoFrames({
    required this.videoPixels,
    required super.child,
  });

  final TimelineVideoLayerPixels? videoPixels;

  static TimelineVideoLayerPixels? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_TimelinePreviewVideoFrames>()
      ?.videoPixels;

  @override
  bool updateShouldNotify(_TimelinePreviewVideoFrames oldWidget) =>
      !identical(videoPixels, oldWidget.videoPixels);
}

class _TimelinePreview extends StatefulWidget {
  final TileManager tileManager;

  /// The frame's layers in the scene's 重なり順 (front first) and the runs
  /// of them masked together ([ProjectService.stackedLayersOf]).
  final List<Layer> layers;
  final List<LayerMaskGroup> maskGroups;
  final String sceneId;
  final int frameIndex;
  final int? outputWidth;
  final int? outputHeight;
  final int historyRevision;
  final List<CameraKeyframe> cameraKeyframes;
  final List<EffectFilterInstance> effectFilters;
  final Map<String, LayerHome> layerHomes;
  final List<LayerGroup> groups;

  /// The project's background colour, shown behind the picture.
  final int backgroundColor;

  const _TimelinePreview({
    required this.backgroundColor,
    required this.tileManager,
    required this.layers,
    this.maskGroups = const [],
    required this.sceneId,
    required this.frameIndex,
    this.outputWidth,
    this.outputHeight,
    this.historyRevision = 0,
    this.cameraKeyframes = const [],
    this.effectFilters = const [],
    this.layerHomes = const {},
    this.groups = const [],
  });

  @override
  State<_TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<_TimelinePreview> {
  final TimelineFrameRenderer _renderer = TimelineFrameRenderer();
  ui.Image? _image;
  bool _building = false;
  // A change that came while a picture was being built: build again after
  // (else dragging a slider or a material left the preview a step behind).
  bool _rebuildPending = false;

  /// The decoded frames of video materials, shared by the timeline screen.
  TimelineVideoLayerPixels? _videoPixels;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final videoPixels = _TimelinePreviewVideoFrames.of(context);
    if (_started && identical(videoPixels, _videoPixels)) return;
    _started = true;
    _videoPixels = videoPixels;
    _rebuild();
  }

  @override
  void didUpdateWidget(_TimelinePreview old) {
    super.didUpdateWidget(old);
    final historyChanged = old.historyRevision != widget.historyRevision;
    if (historyChanged) {
      // Never show the old frame during an Undo or Redo. During playback,
      // keep the last image while the next frame is being composed.
      _image?.dispose();
      _image = null;
    }
    if (historyChanged ||
        old.layers != widget.layers ||
        old.maskGroups != widget.maskGroups ||
        old.tileManager != widget.tileManager ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex ||
        old.outputWidth != widget.outputWidth ||
        old.outputHeight != widget.outputHeight ||
        old.cameraKeyframes != widget.cameraKeyframes ||
        old.effectFilters != widget.effectFilters ||
        old.groups != widget.groups ||
        old.backgroundColor != widget.backgroundColor) {
      _rebuild();
    }
  }

  Future<void> _rebuild() async {
    if (_building) {
      _rebuildPending = true;
      return;
    }
    _building = true;
    final request = widget;
    final videoPixels = _videoPixels;
    final tm = request.tileManager;
    // The export draws the frame with this same pipeline, including the
    // decoded frames of video materials (TimelineFrameRenderer).
    final img = await _renderer.renderImage(
      TimelineFrameRequest(
        tileManager: tm,
        layers: request.layers,
        keyOf: (l) => resolveTileKey(
          request.layerHomes,
          request.sceneId,
          request.frameIndex,
          l.id,
        ),
        frameIndex: request.frameIndex,
        drawingWidth: tm.canvasWidth,
        drawingHeight: tm.canvasHeight,
        outputWidth: request.outputWidth ?? tm.canvasWidth,
        outputHeight: request.outputHeight ?? tm.canvasHeight,
        backgroundColor: request.backgroundColor,
        maskGroups: request.maskGroups,
        groups: request.groups,
        cameraKeyframes: request.cameraKeyframes,
        effectFilters: request.effectFilters,
        pixelsOf: videoPixels?.atFrame(request.frameIndex),
      ),
    );

    if (!mounted) {
      img.dispose();
      return;
    }
    _building = false;
    // A picture made with video frames from a source that has since been
    // replaced (materials changed) is not shown; the next one is.
    if (request.historyRevision == widget.historyRevision &&
        identical(videoPixels, _videoPixels)) {
      setState(() {
        _image?.dispose();
        _image = img;
      });
    } else {
      img.dispose();
    }
    if (_rebuildPending) {
      _rebuildPending = false;
      _rebuild();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    // The picture carries no background: show the project's behind it, over
    // the picture's own rectangle only, as the canvas does.
    return FramePreviewBackground(
      backgroundColor: widget.backgroundColor,
      aspectRatio: img.width / img.height,
      checkerSize: 10,
      child: RawImage(
        key: const Key('timelinePreviewPicture'),
        image: img,
        fit: BoxFit.fill,
      ),
    );
  }
}

// ─── 演出フィルターシート ───────────────────────────────────────────────────
// 選択中シーンのProjectService.effectFiltersOf()を直接読み書きする（
// タイムライン非破壊編集。プレビュー再生・書き出し時にFilterEngineが適用する）。

class _EffectFilterSheet extends StatelessWidget {
  final String projectId;
  final String sceneId;
  final int totalFrames;
  final int currentFrame;
  const _EffectFilterSheet({
    required this.projectId,
    required this.sceneId,
    required this.totalFrames,
    required this.currentFrame,
  });

  static String _displayName(AppLocalizations l10n, EffectFilterInstance e) =>
      e.name ?? _typeLabel(l10n, e.type);

  static String _typeLabel(AppLocalizations l10n, EffectFilterType type) =>
      switch (type) {
        EffectFilterType.fade => l10n.timelineEffectTypeFade,
        EffectFilterType.gaussianBlur => l10n.timelineEffectTypeGaussianBlur,
        EffectFilterType.lensBlur => l10n.timelineEffectTypeLensBlur,
        EffectFilterType.mosaic => l10n.timelineEffectTypeMosaic,
        EffectFilterType.chromaticAberration =>
          l10n.timelineEffectTypeChromaticAberration,
        EffectFilterType.noise => l10n.timelineEffectTypeNoise,
        EffectFilterType.sepia => l10n.timelineEffectTypeSepia,
        EffectFilterType.animeStyle => l10n.timelineEffectTypeAnimeStyle,
        EffectFilterType.retroAnime => l10n.timelineEffectTypeRetroAnime,
        EffectFilterType.crt => l10n.timelineEffectTypeCrt,
        EffectFilterType.animatedNoise => l10n.timelineEffectTypeAnimatedNoise,
        EffectFilterType.rain => l10n.timelineEffectTypeRain,
        EffectFilterType.monochrome => l10n.timelineEffectTypeMonochrome,
        EffectFilterType.colorAdjust => l10n.filterNameColorAdjust,
        EffectFilterType.threshold => l10n.filterNameThreshold,
        EffectFilterType.fisheye => l10n.filterNameFisheye,
        EffectFilterType.pixelate => l10n.filterNamePixelate,
        EffectFilterType.auroraHologram => l10n.filterNameAuroraHologram,
        EffectFilterType.inkPool => l10n.filterNameInkPool,
        EffectFilterType.vhsNoise => l10n.timelineEffectTypeVhsNoise,
        EffectFilterType.toneCurve => l10n.filterNameToneCurve,
        EffectFilterType.levels => l10n.filterNameLevels,
        EffectFilterType.sharpen => l10n.filterNameSharpen,
        EffectFilterType.unsharpMask => l10n.filterNameUnsharpMask,
        EffectFilterType.vignette => l10n.filterNameVignette,
        EffectFilterType.watercolorBorder => l10n.filterNameWatercolorBorder,
      };

  static const _typeIcons = {
    EffectFilterType.fade: Icons.gradient,
    EffectFilterType.gaussianBlur: Icons.blur_on,
    EffectFilterType.lensBlur: Icons.lens_blur,
    EffectFilterType.mosaic: Icons.grid_4x4,
    EffectFilterType.chromaticAberration: Icons.color_lens,
    EffectFilterType.noise: Icons.grain,
    EffectFilterType.sepia: Icons.filter_vintage,
    EffectFilterType.animeStyle: Icons.auto_awesome,
    EffectFilterType.retroAnime: Icons.movie_filter,
    EffectFilterType.crt: Icons.tv,
    EffectFilterType.animatedNoise: Icons.blur_on,
    EffectFilterType.rain: Icons.water_drop,
    EffectFilterType.monochrome: Icons.filter_b_and_w,
    EffectFilterType.colorAdjust: Icons.tune,
    EffectFilterType.threshold: Icons.contrast,
    EffectFilterType.fisheye: Icons.panorama_fish_eye,
    EffectFilterType.pixelate: Icons.grid_view,
    EffectFilterType.auroraHologram: Icons.auto_awesome_mosaic,
    EffectFilterType.inkPool: Icons.gesture_rounded,
    EffectFilterType.vhsNoise: Icons.video_settings,
    EffectFilterType.toneCurve: Icons.show_chart,
    EffectFilterType.levels: Icons.equalizer,
    EffectFilterType.sharpen: Icons.deblur,
    EffectFilterType.unsharpMask: Icons.center_focus_strong,
    EffectFilterType.vignette: Icons.vignette,
    EffectFilterType.watercolorBorder: Icons.water_drop_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effects = context.watch<ProjectService>().effectFiltersOf(
      projectId,
      sceneId,
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeService.activeColorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // 見出しと「追加」は入れば横に並べ、入らなければ「追加」を下へ
            // 回す（長い言語・大きな文字で見出しとボタンが重なり、右端が
            // はみ出した。DISC027）。
            child: ActionBesideOrBelow(
              text: Text(
                l10n.timelineEffectFilterLabel,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              action: FilledButton.icon(
                key: const ValueKey('timelineEffectFilterAdd'),
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.commonAdd),
                onPressed: () => _showAddEffectDialog(context),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: effects.isEmpty
                ? Center(
                    child: Text(
                      l10n.timelineEffectFilterEmptyState,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                // ドラッグで並び替え可能（「複数フィルターの適用順」は
                // タイムライン上の並び順に従うため、並び替えが適用順を左右する）
                : ReorderableListView.builder(
                    scrollController: scrollCtrl,
                    // ドラッグハンドルを明示アイコンとして置く（既定のまま
                    // だと行の長押しでしか並べ替えを開始できず、可視の目印が
                    // 無いままだった。他の並べ替え可能な一覧と操作方法を揃える）。
                    buildDefaultDragHandles: false,
                    itemCount: effects.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        context.read<ProjectService>().reorderEffectFilters(
                          projectId,
                          sceneId,
                          oldIndex,
                          preRemovalIndex(oldIndex, newIndex),
                        ),
                    itemBuilder: (ctx, i) => _buildEffectTile(
                      context,
                      effects[i],
                      dragIndex: i,
                      key: ValueKey(effects[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _update(BuildContext context, EffectFilterInstance e) =>
      context.read<ProjectService>().updateEffectFilter(projectId, sceneId, e);

  /// 演出フィルターを複製する（「フィルター操作＞複製」）。
  /// 複製先は元フィルターの直後へ挿入する。
  void _duplicate(
    BuildContext context,
    EffectFilterInstance e,
    List<EffectFilterInstance> effects,
  ) {
    final service = context.read<ProjectService>();
    final l10n = AppLocalizations.of(context)!;
    final copy = e.copyWith(
      id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
      name: e.name == null
          ? null
          : numberedCopyName(l10n, e.name!, {
              for (final effect in effects) _displayName(l10n, effect),
            }),
    );
    service.addEffectFilter(projectId, sceneId, copy);
    final index = effects.indexWhere((f) => f.id == e.id);
    if (index >= 0 && index + 1 < effects.length) {
      service.reorderEffectFilters(
        projectId,
        sceneId,
        effects.length,
        index + 1,
      );
    }
  }

  Widget _buildEffectTile(
    BuildContext context,
    EffectFilterInstance e, {
    int? dragIndex,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final effects = context.read<ProjectService>().effectFiltersOf(
      projectId,
      sceneId,
    );
    return Card(
      key: key,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shadowColor: ThemeService.activeColorScheme.shadow.withValues(
        alpha: 0.15,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        leading: Icon(_typeIcons[e.type], size: 20),
        title: Text(
          _displayName(l10n, e),
          style: localizedHeadingStyle(context, const TextStyle(fontSize: 13)),
        ),
        subtitle: Text(
          [
            if (e.name != null) _typeLabel(l10n, e.type),
            'F${e.startFrame + 1} ～ F${e.endFrame + 1}',
          ].join(' · '),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: e.enabled,
              onChanged: (v) => _update(context, e.copyWith(enabled: v)),
            ),
            IconButton(
              icon: Icon(Icons.copy, size: 18),
              tooltip: l10n.themeDuplicateAction,
              onPressed: () => _duplicate(context, e, effects),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: l10n.commonDelete,
              onPressed: () async {
                if (!await confirmDelete(
                  context,
                  message: l10n.layerPanelDeleteConfirmTitle(
                    _displayName(l10n, e),
                  ),
                )) {
                  return;
                }
                if (!context.mounted) return;
                context.read<ProjectService>().removeEffectFilter(
                  projectId,
                  sceneId,
                  e.id,
                );
              },
            ),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.drag_handle, size: 18),
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rangeRow(
                  l10n.timelineRangeStartLabel,
                  e.startFrame,
                  0,
                  totalFrames - 1,
                  (v) => _update(
                    context,
                    e.copyWith(startFrame: v.clamp(0, e.endFrame)),
                  ),
                ),
                _rangeRow(
                  l10n.timelineRangeEndLabel,
                  e.endFrame,
                  0,
                  totalFrames - 1,
                  (v) => _update(
                    context,
                    e.copyWith(
                      endFrame: v.clamp(e.startFrame, totalFrames - 1),
                    ),
                  ),
                ),
                if (e.type == EffectFilterType.fade)
                  ..._fadeParams(context, l10n, e)
                else if (e.type == EffectFilterType.animatedNoise)
                  ..._animatedNoiseParams(context, l10n, e)
                else if (e.type == EffectFilterType.rain)
                  ..._rainParams(context, l10n, e)
                else if (e.type == EffectFilterType.colorAdjust)
                  ..._colorAdjustParams(context, l10n, e)
                else if (e.type == EffectFilterType.monochrome)
                  ..._monochromeParams(context, l10n, e)
                else if (e.type == EffectFilterType.threshold)
                  ..._thresholdParams(context, l10n, e)
                else if (e.type == EffectFilterType.pixelate)
                  ..._pixelateParams(context, l10n, e)
                else if (e.type == EffectFilterType.auroraHologram)
                  ..._auroraHologramParams(context, l10n, e)
                else if (e.type == EffectFilterType.inkPool)
                  ..._inkPoolParams(context, l10n, e)
                else if (e.type == EffectFilterType.vhsNoise)
                  ..._vhsNoiseParams(context, l10n, e)
                else if (e.type == EffectFilterType.toneCurve)
                  ..._toneCurveParams(context, l10n, e)
                else if (e.type == EffectFilterType.levels)
                  ..._levelsParams(context, l10n, e)
                else if (e.type == EffectFilterType.sharpen)
                  _paramRow(
                    l10n.filterSharpenStrength,
                    e.param1,
                    0,
                    100,
                    100,
                    (v) => _update(context, e.copyWith(param1: v)),
                  )
                else if (e.type == EffectFilterType.unsharpMask)
                  ..._unsharpMaskParams(context, l10n, e)
                else if (e.type == EffectFilterType.vignette)
                  ..._vignetteParams(context, l10n, e)
                else if (e.type == EffectFilterType.watercolorBorder)
                  ..._watercolorBorderParams(context, l10n, e)
                else
                  ..._strengthParam(context, l10n, e),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 開始・終了フレームの行。スライダーは表示（F1〜）と同じ1始まりの
  /// 目盛りで持ち、0始まりの添字へ戻して渡す。
  Widget _rangeRow(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return _effectSlider(
      label: label,
      value: (value + 1).toDouble(),
      min: (min + 1).toDouble(),
      max: (max + 1).toDouble(),
      divisions: max > min ? max - min : 1,
      format: (v) => 'F${v.round()}',
      onCommit: (v) => onChanged(v.round() - 1),
    );
  }

  List<Widget> _strengthParam(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    final label = e.type == EffectFilterType.mosaic
        ? l10n.timelineEffectSizeLabel
        : l10n.timelineEffectStrengthLabel;
    final maxVal = e.type == EffectFilterType.mosaic
        ? kPixelArtMaxBlockSize.toDouble()
        : 20.0;
    return [
      _effectSlider(
        label: label,
        value: e.param1,
        min: 1,
        max: maxVal,
        divisions: maxVal.round() - 1,
        onCommit: (v) => _update(context, e.copyWith(param1: v)),
      ),
    ];
  }

  /// 演出フィルターの汎用パラメータ行（ラベル＋スライダー＋数値入力）。
  Widget _paramRow(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged, {
    String Function(double)? format,
  }) {
    return _effectSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions > 0 ? divisions : null,
      isInt: false,
      format: format,
      onCommit: onChanged,
    );
  }

  Widget _effectSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int? divisions,
    required ValueChanged<double> onCommit,
    bool isInt = true,
    String Function(double)? format,
  }) {
    var preview = value;
    return StatefulBuilder(
      builder: (_, setPreview) {
        final shown = format?.call(preview) ?? preview.round().toString();
        return LabeledSlider(
          label: label,
          value: preview,
          min: min,
          max: max,
          divisions: divisions,
          isInt: isInt,
          sliderLabel: shown,
          valueText: shown,
          onChanged: (next) => setPreview(() => preview = next),
          onChangeEnd: (next) {
            if (next != value) onCommit(next);
          },
        );
      },
    );
  }

  /// 色調調整のパラメータ（彩度・明度・コントラスト、いずれも-100〜100）。
  List<Widget> _colorAdjustParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterColorAdjustSaturationLabel,
        e.param1,
        -100,
        100,
        200,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      _paramRow(
        l10n.filterColorAdjustBrightnessLabel,
        e.param2,
        -100,
        100,
        200,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
      _paramRow(
        l10n.filterColorAdjustContrastLabel,
        e.param3,
        -100,
        100,
        200,
        (v) => _update(context, e.copyWith(param3: v)),
      ),
    ];
  }

  /// 動くノイズのパラメータ（強度・量・粒の大きさ）。
  List<Widget> _animatedNoiseParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.timelineEffectStrengthLabel,
        e.param1,
        1,
        20,
        19,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      _paramRow(
        l10n.timelineEffectAmountLabel,
        e.param2,
        1,
        100,
        99,
        (v) => _update(context, e.copyWith(param2: v)),
        format: (v) => '${v.round()}%',
      ),
      _paramRow(
        l10n.timelineEffectGrainSizeLabel,
        e.param3,
        1,
        8,
        7,
        (v) => _update(context, e.copyWith(param3: v)),
      ),
    ];
  }

  /// 雨のパラメータ（降り方・速さ・粒の大きさ・風向き）。
  List<Widget> _rainParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.timelineEffectRainIntensityLabel,
        e.param1,
        1,
        20,
        19,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      _paramRow(
        l10n.timelineEffectRainSpeedLabel,
        e.param2,
        2,
        40,
        0,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
      _paramRow(
        l10n.timelineEffectRainSizeLabel,
        e.param3,
        1,
        6,
        5,
        (v) => _update(context, e.copyWith(param3: v)),
      ),
      _paramRow(
        l10n.timelineEffectWindAngleLabel,
        e.param4,
        -60,
        60,
        0,
        (v) => _update(context, e.copyWith(param4: v)),
        format: (v) => '${v.round()}°',
      ),
    ];
  }

  List<Widget> _vhsNoiseParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterVhsNoiseStrength,
        e.param1,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      _paramRow(
        l10n.filterVhsScanlineStrength,
        e.param2,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
      _paramRow(
        l10n.filterVhsColorBleed,
        e.param3,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param3: v)),
      ),
      _paramRow(
        l10n.filterVhsTracking,
        e.param4,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param4: v)),
      ),
    ];
  }

  List<Widget> _fadeParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              l10n.timelineColorLabel,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickFadeColor(context, e),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: e.fadeColor,
                border: Border.all(
                  color: ThemeService.activeColorScheme.onSurfaceVariant,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            e.fadeColor == Colors.black
                ? l10n.timelineColorBlack
                : e.fadeColor == Colors.white
                ? l10n.timelineColorWhite
                : l10n.timelineColorCustom,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ];
  }

  /// 単色化のパラメータ（混合量スライダー＋色チップ。チップをタップすると
  /// フルカラーピッカー（ColorPickerPanel）が開く。
  List<Widget> _monochromeParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.timelineEffectStrengthLabel,
        e.param1,
        1,
        20,
        19,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              l10n.filterMonochromeColorLabel,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickMonochromeColor(context, e),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: e.fadeColor,
                border: Border.all(
                  color: ThemeService.activeColorScheme.onSurfaceVariant,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  void _pickMonochromeColor(BuildContext context, EffectFilterInstance e) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: typingDialogInsetPadding(ctx),
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: e.fadeColor,
          onColorChanged: (c) => _update(context, e.copyWith(fadeColor: c)),
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  List<Widget> _inkPoolParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    Widget stepRow(
      String label,
      double value,
      int min,
      int max,
      ValueChanged<double> onChanged,
    ) {
      final v = value.round().clamp(min, max);
      void change(int next) => onChanged(next.clamp(min, max).toDouble());
      return _effectSlider(
        label: label,
        value: v.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        format: (n) => '${n.round()}px',
        onCommit: (n) => change(n.round()),
      );
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(l10n.filterInkPoolColor, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _pickInkPoolEffectColor(context, e),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: e.fadeColor,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
      stepRow(
        l10n.filterInkPoolRange,
        e.param1,
        1,
        80,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      stepRow(
        l10n.filterInkPoolCenterWidth,
        e.param2,
        1,
        60,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
    ];
  }

  /// トーンカーブのプリセット（param1）と強さ（param2、0〜100%）。
  List<Widget> _toneCurveParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    final preset = ToneCurvePreset
        .values[e.param1.round().clamp(0, ToneCurvePreset.values.length - 1)];
    return [
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final p in ToneCurvePreset.values)
            ChoiceChip(
              label: Text(switch (p) {
                ToneCurvePreset.linear => l10n.filterToneCurveLinear,
                ToneCurvePreset.brighten => l10n.filterToneCurveBrighten,
                ToneCurvePreset.darken => l10n.filterToneCurveDarken,
                ToneCurvePreset.highContrast =>
                  l10n.filterToneCurveHighContrast,
                ToneCurvePreset.lowContrast => l10n.filterToneCurveLowContrast,
                ToneCurvePreset.invert => l10n.filterToneCurveInvert,
              }, style: const TextStyle(fontSize: 10)),
              selected: p == preset,
              onSelected: (selected) {
                if (!selected) return;
                _update(context, e.copyWith(param1: p.index.toDouble()));
              },
            ),
        ],
      ),
      _paramRow(
        l10n.timelineEffectStrengthLabel,
        e.param2,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param2: v)),
        format: (v) => '${v.round()}%',
      ),
    ];
  }

  /// レベル補正（入力の黒・白、ガンマ、出力の黒・白）。
  List<Widget> _levelsParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterLevelsInputBlack,
        e.param1,
        0,
        254,
        254,
        (v) => _update(
          context,
          e.copyWith(param1: v.clamp(0, e.param2 - 1).roundToDouble()),
        ),
      ),
      _paramRow(
        l10n.filterLevelsInputWhite,
        e.param2,
        1,
        255,
        254,
        (v) => _update(
          context,
          e.copyWith(param2: v.clamp(e.param1 + 1, 255).roundToDouble()),
        ),
      ),
      _paramRow(
        l10n.filterLevelsGamma,
        e.param3,
        0.1,
        3,
        290,
        (v) => _update(context, e.copyWith(param3: v)),
        format: (v) => v.toStringAsFixed(2),
      ),
      _paramRow(
        l10n.filterLevelsOutputBlack,
        e.param4,
        0,
        255,
        255,
        (v) => _update(context, e.copyWith(param4: v.roundToDouble())),
      ),
      _paramRow(
        l10n.filterLevelsOutputWhite,
        e.param5,
        0,
        255,
        255,
        (v) => _update(context, e.copyWith(param5: v.roundToDouble())),
      ),
    ];
  }

  /// アンシャープマスク（ぼかし半径・量）。
  List<Widget> _unsharpMaskParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterStrengthBlurRadius,
        e.param1,
        1,
        20,
        19,
        (v) => _update(context, e.copyWith(param1: v.roundToDouble())),
      ),
      _paramRow(
        l10n.filterUnsharpAmount,
        e.param2,
        0,
        3,
        300,
        (v) => _update(context, e.copyWith(param2: v)),
        format: (v) => v.toStringAsFixed(2),
      ),
    ];
  }

  /// 周辺減光（色・範囲・濃さ）。
  /// 水彩境界のパラメータ（範囲・縁の濃さ・透明度の影響・ぼかし幅・色の境目）。
  List<Widget> _watercolorBorderParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterWatercolorBorderRange,
        e.param1,
        1,
        50,
        49,
        (v) => _update(context, e.copyWith(param1: v)),
        format: (v) => '${v.round()}px',
      ),
      _paramRow(
        l10n.filterWatercolorBorderDarken,
        e.param2,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
      _paramRow(
        l10n.filterWatercolorBorderOpacity,
        e.param3,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param3: v)),
      ),
      _paramRow(
        l10n.filterWatercolorBorderBlur,
        e.param4,
        0,
        20,
        20,
        (v) => _update(context, e.copyWith(param4: v)),
        format: (v) => '${v.round()}px',
      ),
      SwitchListTile(
        key: const ValueKey('effect-watercolor-border-color-edges'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          l10n.filterWatercolorBorderColorEdges,
          style: const TextStyle(fontSize: 12),
        ),
        value: e.param5 >= 0.5,
        onChanged: (v) => _update(context, e.copyWith(param5: v ? 1 : 0)),
      ),
    ];
  }

  List<Widget> _vignetteParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              l10n.filterVignetteColor,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('effect-vignette-color'),
              onTap: () => _pickInkPoolEffectColor(context, e),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: e.fadeColor,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
      _paramRow(
        l10n.filterVignetteRange,
        e.param1,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param1: v)),
        format: (v) => '${v.round()}%',
      ),
      _paramRow(
        l10n.filterVignetteDensity,
        e.param2,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
      Text(
        l10n.filterVignetteHint,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  void _pickInkPoolEffectColor(BuildContext context, EffectFilterInstance e) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: typingDialogInsetPadding(ctx),
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: e.fadeColor,
          onColorChanged: (c) => _update(context, e.copyWith(fadeColor: c)),
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// 二値化のパラメータ（閾値スライダーのみ。0〜255）。
  List<Widget> _thresholdParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterThresholdLabel,
        e.param1,
        0,
        255,
        255,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
    ];
  }

  /// ドット絵：param1=モザイクブロックサイズ（1〜64px）、param2=色数の指定
  /// （countモード時のみ使用、1〜256）。配色方式自体は
  /// pixelColorMode/pixelExplicitColors（PixelColorModeSelector参照）。
  List<Widget> _pixelateParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    return [
      _paramRow(
        l10n.filterPixelateBlockSize,
        e.param1,
        1,
        kPixelArtMaxBlockSize.toDouble(),
        kPixelArtMaxBlockSize - 1,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      PixelColorModeSelector(
        mode: e.pixelColorMode,
        colorLevels: e.param2.round(),
        explicitColors: e.pixelExplicitColors,
        onModeChanged: (m) => _update(context, e.copyWith(pixelColorMode: m)),
        onColorLevelsChanged: (v) =>
            _update(context, e.copyWith(param2: v.toDouble())),
        onExplicitColorsChanged: (c) =>
            _update(context, e.copyWith(pixelExplicitColors: c)),
      ),
      // Dithering only matters once the colours are limited.
      if (e.pixelColorMode != PixelColorMode.none)
        SwitchListTile.adaptive(
          key: const ValueKey('effect-pixel-art-dither-toggle'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.filterPixelateDither),
          subtitle: Text(l10n.filterPixelateDitherHint),
          value: e.pixelDither,
          onChanged: (v) => _update(context, e.copyWith(pixelDither: v)),
        ),
    ];
  }

  /// オーロラホログラム：param1=フィルター強度（0〜100）、param2=明度・
  /// param3=彩度（いずれも-100〜100）、param4=配色プリセットのインデックス。
  /// 配色パターンはプリセットのみ選択可能（ユーザー個別指定不可）。
  List<Widget> _auroraHologramParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    final presetIndex = e.param4.round().clamp(
      0,
      AuroraHologramPreset.values.length - 1,
    );
    return [
      _paramRow(
        l10n.filterAuroraHologramStrength,
        e.param1,
        0,
        100,
        100,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      _paramRow(
        l10n.filterAuroraHologramBrightness,
        e.param2,
        -100,
        100,
        200,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
      _paramRow(
        l10n.filterAuroraHologramSaturation,
        e.param3,
        -100,
        100,
        200,
        (v) => _update(context, e.copyWith(param3: v)),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: AuroraHologramPreset.values
            .map(
              (p) => ChoiceChip(
                label: Text(
                  _auroraHologramPresetLabel(l10n, p),
                  style: const TextStyle(fontSize: 10),
                ),
                selected: AuroraHologramPreset.values[presetIndex] == p,
                onSelected: (selected) {
                  if (!selected) return;
                  _update(
                    context,
                    e.copyWith(
                      param4: AuroraHologramPreset.values.indexOf(p).toDouble(),
                    ),
                  );
                },
              ),
            )
            .toList(),
      ),
    ];
  }

  String _auroraHologramPresetLabel(
    AppLocalizations l10n,
    AuroraHologramPreset p,
  ) => switch (p) {
    AuroraHologramPreset.silverHologram =>
      l10n.filterAuroraHologramPresetSilverHologram,
    AuroraHologramPreset.sampledGold =>
      l10n.filterAuroraHologramPresetSampledGold,
    AuroraHologramPreset.silverFoil =>
      l10n.filterAuroraHologramPresetSilverFoil,
    AuroraHologramPreset.luminousPearl =>
      l10n.filterAuroraHologramPresetLuminousPearl,
    AuroraHologramPreset.auroraPastel =>
      l10n.filterAuroraHologramPresetAuroraPastel,
    AuroraHologramPreset.darkRainbow =>
      l10n.filterAuroraHologramPresetDarkRainbow,
  };

  void _pickFadeColor(BuildContext context, EffectFilterInstance e) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineFadeColorDialogTitle),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in [
              ThemeService.activeColorScheme.onSurface,
              ThemeService.activeColorScheme.onSurface,
              ThemeService.activeColorScheme.error,
              ThemeService.activeColorScheme.primary,
            ])
              GestureDetector(
                onTap: () {
                  _update(context, e.copyWith(fadeColor: c));
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(
                      color: ThemeService.activeColorScheme.onSurfaceVariant,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddEffectDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineAddFilterDialogTitle),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: EffectFilterType.values
                .map(
                  (type) => ListTile(
                    leading: Icon(_typeIcons[type]),
                    title: Text(_typeLabel(l10n, type)),
                    onTap: () {
                      ps.addEffectFilter(
                        projectId,
                        sceneId,
                        EffectFilterInstance(
                          id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
                          type: type,
                          startFrame: currentFrame,
                          endFrame: (currentFrame + 11).clamp(
                            0,
                            totalFrames - 1,
                          ),
                          // 雨の「速さ」は既定値50だとスライダー上限(40)を超えるため上書きする。
                          // 色調調整は彩度・明度・コントラストとも既定値0（変化なし）から
                          // 始める（他のフィルターと違い既定値5.0/50.0のままだと追加直後に
                          // 見た目が変わってしまうため）。二値化のparam1は閾値（0〜255）
                          // なので既定128（中間）から始める。ドット絵のparam1は
                          // モザイクブロックサイズ（px）なので既定8から始める。
                          param1: switch (type) {
                            EffectFilterType.colorAdjust => 0.0,
                            EffectFilterType.threshold => 128.0,
                            EffectFilterType.pixelate => 8.0,
                            // オーロラホログラムのparam1はフィルター強度
                            // （0〜100）なので、効果がはっきり見える60から始める。
                            EffectFilterType.auroraHologram => 60.0,
                            EffectFilterType.inkPool => 12.0,
                            EffectFilterType.vhsNoise => 35.0,
                            // トーンカーブは「明暗を強く」、レベル補正は
                            // 入力の黒16から、シャープは強さ50、アンシャープ
                            // マスクは半径4、周辺減光は範囲40%から始める。
                            EffectFilterType.toneCurve =>
                              ToneCurvePreset.highContrast.index.toDouble(),
                            EffectFilterType.levels => 16.0,
                            EffectFilterType.sharpen => 50.0,
                            EffectFilterType.unsharpMask => 4.0,
                            EffectFilterType.vignette => 40.0,
                            // 水彩境界は範囲10pxから。
                            EffectFilterType.watercolorBorder => 10.0,
                            _ => 5.0,
                          },
                          // ドット絵のparam2は色数（2〜32）なので既定8から始める。
                          // オーロラホログラムのparam2は明度（-100〜100）なので
                          // 既定0（変化なし）から始める。
                          param2: type == EffectFilterType.rain
                              ? 10.0
                              : type == EffectFilterType.colorAdjust
                              ? 0.0
                              : type == EffectFilterType.pixelate
                              ? 8.0
                              : type == EffectFilterType.auroraHologram
                              ? 0.0
                              : type == EffectFilterType.inkPool
                              ? 6.0
                              : type == EffectFilterType.vhsNoise
                              ? 35.0
                              // トーンカーブの強さ100%、レベル補正の入力の白
                              // 240、アンシャープマスクの量1.0、周辺減光の
                              // 濃さ50。
                              : type == EffectFilterType.toneCurve
                              ? 100.0
                              : type == EffectFilterType.levels
                              ? 240.0
                              : type == EffectFilterType.unsharpMask
                              ? 1.0
                              // 水彩境界の縁の濃さ40。
                              : type == EffectFilterType.watercolorBorder
                              ? 40.0
                              : 50.0,
                          // オーロラホログラムのparam3は彩度（-100〜100）なので
                          // 既定0（変化なし）から始める。
                          param3: type == EffectFilterType.vhsNoise
                              ? 35.0
                              // レベル補正のガンマは1.0（変化なし）から。
                              : type == EffectFilterType.levels
                              ? 1.0
                              : type == EffectFilterType.colorAdjust ||
                                    type == EffectFilterType.auroraHologram
                              ? 0.0
                              // 水彩境界の透明度の影響45。
                              : type == EffectFilterType.watercolorBorder
                              ? 45.0
                              : 2.0,
                          // 水彩境界のぼかし幅2px。
                          param4: type == EffectFilterType.vhsNoise
                              ? 25.0
                              : type == EffectFilterType.watercolorBorder
                              ? 2.0
                              : 0.0,
                          // 単色化の色（fadeColorスロットを流用）：既定は白＝通常の
                          // グレースケール。fadeフィルター自体の既定色は黒のままにする。
                          fadeColor: type == EffectFilterType.monochrome
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF000000),
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ─── クリップ詳細シート ────────────────────────────────────────────────────

class _ClipDetailSheet extends StatefulWidget {
  final _TrackClip clip;
  final int totalFrames;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onChanged;
  final ValueGetter<bool> isPlaying;
  final VoidCallback onTogglePlay;
  final int Function(double rate) speedEndFrameAt;
  final String? Function(double rate) onSpeedChange;
  const _ClipDetailSheet({
    required this.clip,
    required this.totalFrames,
    required this.speedEndFrameAt,
    required this.onSpeedChange,
    required this.onDelete,
    required this.onDuplicate,
    required this.onChanged,
    required this.isPlaying,
    required this.onTogglePlay,
  });
  @override
  State<_ClipDetailSheet> createState() => _ClipDetailSheetState();
}

class _ClipDetailSheetState extends State<_ClipDetailSheet> {
  late _TrackClip _c;
  late double _initialVolume;
  late double _initialFadeIn;
  late double _initialFadeOut;
  late double _initialRate;
  late int _initialLength;
  late int _initialUseEnd;

  @override
  void initState() {
    super.initState();
    _c = widget.clip;
    if (_c.useEnd == 0 && _c.lengthFrames > 1) _c.useEnd = _c.lengthFrames - 1;
    _initialVolume = _c.volume;
    _initialFadeIn = _c.fadeIn;
    _initialFadeOut = _c.fadeOut;
    _initialRate = _c.playbackRate;
    _initialLength = _c.lengthFrames;
    _initialUseEnd = _c.useEnd;
  }

  void _notify() {
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeService.activeColorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _c.trackType == _ClipTrackType.audio
                        ? l10n.helpAudioClipTitle
                        : _c.label,
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_c.trackType == _ClipTrackType.audio ||
                    _c.trackType == _ClipTrackType.video)
                  IconButton(
                    icon: Icon(
                      widget.isPlaying() ? Icons.pause : Icons.play_arrow,
                    ),
                    tooltip: widget.isPlaying()
                        ? l10n.commonPause
                        : l10n.commonPlay,
                    onPressed: () {
                      widget.onTogglePlay();
                      setState(() {});
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: l10n.commonOk,
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonCancel,
                  onPressed: () {
                    _c.volume = _initialVolume;
                    _c.fadeIn = _initialFadeIn;
                    _c.fadeOut = _initialFadeOut;
                    _c.playbackRate = _initialRate;
                    _c.lengthFrames = _initialLength;
                    _c.useEnd = _initialUseEnd;
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          // The sheet was handed duplicate and delete but showed no button
          // for them, so an audio clip could not be duplicated or deleted here
          // (the Tips say it can).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const ValueKey('timelineClipSheetDuplicate'),
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: Text(l10n.commonDuplicate),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDuplicate();
                  },
                ),
                TextButton.icon(
                  key: const ValueKey('timelineClipSheetDelete'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.commonDelete),
                  onPressed: () async {
                    if (!await confirmDelete(context, itemName: _c.label)) {
                      return;
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_c.trackType == _ClipTrackType.audio) ...[
                  ClipSpeedControl(
                    rate: _c.playbackRate,
                    hasSound: true,
                    endFrameAt: widget.speedEndFrameAt,
                    onApply: (rate) {
                      final problem = widget.onSpeedChange(rate);
                      setState(() {});
                      return problem;
                    },
                  ),
                  const SizedBox(height: 8),
                  _row(
                    l10n.timelineClipVolumeLabel,
                    _c.volume,
                    0,
                    1,
                    100,
                    (v) {
                      _c.volume = v;
                      _notify();
                    },
                    '${(_c.volume * 100).round()}%',
                    step: 0.01,
                  ),
                  _row(
                    l10n.timelineClipFadeInLabel,
                    _c.fadeIn,
                    0,
                    5,
                    50,
                    (v) {
                      _c.fadeIn = v;
                      _notify();
                    },
                    '${_c.fadeIn.toStringAsFixed(1)}s',
                    step: 0.1,
                  ),
                  _row(
                    l10n.timelineClipFadeOutLabel,
                    _c.fadeOut,
                    0,
                    5,
                    50,
                    (v) {
                      _c.fadeOut = v;
                      _notify();
                    },
                    '${_c.fadeOut.toStringAsFixed(1)}s',
                    step: 0.1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
    String valueText, {
    double step = 1,
  }) {
    return LabeledSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions > 0 ? divisions : 1,
      step: step,
      isInt: false,
      valueText: valueText,
      onChanged: onChanged,
    );
  }
}

// ─── カメラKFシート ────────────────────────────────────────────────────────

class _CameraKfSheet extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final CameraKeyframe kf;
  final int totalFrames;
  final VoidCallback? onDelete;
  final bool Function(CameraKeyframe newKf) onSave;
  const _CameraKfSheet({
    required this.projectId,
    required this.sceneId,
    required this.kf,
    required this.totalFrames,
    required this.onDelete,
    required this.onSave,
  });
  @override
  State<_CameraKfSheet> createState() => _CameraKfSheetState();
}

class _CameraKfSheetState extends State<_CameraKfSheet> {
  late CameraKeyframe _kf;

  @override
  void initState() {
    super.initState();
    _kf = widget.kf;
  }

  void _update(CameraKeyframe newKf) => setState(() => _kf = newKf);

  late CameraKeyframe _gestureStart = _kf;

  void _transform(Offset delta, double scale, double degrees) {
    final start = _gestureStart;
    final zoom = (start.zoom * scale).clamp(.1, 5.0);
    final rotation = (start.rotation + degrees + 180) % 360 - 180;
    // Moving the picture translates the camera in the opposite direction.
    // Undo the display rotation and zoom to turn that into canvas pixels.
    final theta = -rotation * math.pi / 180;
    final dx = (delta.dx * math.cos(theta) - delta.dy * math.sin(theta)) / zoom;
    final dy = (delta.dx * math.sin(theta) + delta.dy * math.cos(theta)) / zoom;
    _update(
      start.copyWith(
        x: (start.x - dx).clamp(-1920.0, 1920.0),
        y: (start.y - dy).clamp(-1080.0, 1080.0),
        zoom: zoom,
        rotation: rotation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final savedKeys = ps.cameraKeyframesOf(widget.projectId, widget.sceneId);
    final isNew = widget.onDelete == null;
    final occupied =
        (isNew || _kf.frameIndex != widget.kf.frameIndex) &&
        savedKeys.any((keyframe) => keyframe.frameIndex == _kf.frameIndex);
    final changed =
        isNew ||
        _kf.frameIndex != widget.kf.frameIndex ||
        _kf.x != widget.kf.x ||
        _kf.y != widget.kf.y ||
        _kf.zoom != widget.kf.zoom ||
        _kf.rotation != widget.kf.rotation;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.91,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeService.activeColorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.timelineCameraKfTitle(_kf.frameIndex + 1),
                    style: localizedHeadingStyle(
                      context,
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: l10n.commonDelete,
                    onPressed: () async {
                      if (!await confirmDelete(
                        context,
                        message: l10n.layerPanelDeleteConfirmTitle(
                          l10n.timelineCameraKfTitle(widget.kf.frameIndex + 1),
                        ),
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                  ),
                FilledButton(
                  onPressed: changed && !occupied
                      ? () {
                          if (widget.onSave(_kf)) Navigator.pop(context);
                        }
                      : null,
                  child: Text(isNew ? l10n.commonAdd : l10n.commonApply),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KeyframePreview(
                projects: ps,
                projectId: widget.projectId,
                sceneId: widget.sceneId,
                frameIndex: _kf.frameIndex,
                camera: _kf,
                onGestureStart: () => _gestureStart = _kf,
                onTransform: _transform,
              ),
            ),
          ),
          const KeyframePreviewHint(),
          Expanded(
            flex: 4,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _row(
                  l10n.timelineCameraMoveXLabel,
                  _kf.x,
                  -1920,
                  1920,
                  (v) => _update(_kf.copyWith(x: v)),
                  _kf.x.toStringAsFixed(0),
                ),
                _row(
                  l10n.timelineCameraMoveYLabel,
                  _kf.y,
                  -1080,
                  1080,
                  (v) => _update(_kf.copyWith(y: v)),
                  _kf.y.toStringAsFixed(0),
                ),
                _row(
                  l10n.timelineCameraZoomLabel,
                  _kf.zoom,
                  0.1,
                  5.0,
                  (v) => _update(_kf.copyWith(zoom: v)),
                  '×${_kf.zoom.toStringAsFixed(2)}',
                  step: 0.05,
                ),
                _row(
                  l10n.timelineCameraRotationLabel,
                  _kf.rotation,
                  -180,
                  180,
                  (v) => _update(_kf.copyWith(rotation: v)),
                  '${_kf.rotation.toStringAsFixed(1)}°',
                ),
                const SizedBox(height: 8),
                // フレームは表示（F1〜）と同じ1始まりの目盛りで持ち、
                // 0始まりの添字へ戻して保存する。
                LabeledSlider(
                  label: l10n.timelineFrameTrackLabel,
                  value: (_kf.frameIndex + 1).toDouble(),
                  min: 1,
                  max: widget.totalFrames.toDouble(),
                  divisions: widget.totalFrames > 1
                      ? widget.totalFrames - 1
                      : 1,
                  valueText: 'F${_kf.frameIndex + 1}',
                  onChanged: (v) =>
                      _update(_kf.copyWith(frameIndex: v.round() - 1)),
                ),
                if (occupied)
                  IconNotice(
                    l10n.timelineCameraFrameAlreadyHasKeyframe,
                    liveRegion: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String valueText, {
    double step = 1,
  }) {
    final divisions = ((max - min) * 10).round().clamp(1, 1000);
    return LabeledSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      step: step,
      isInt: false,
      valueText: valueText,
      onChanged: onChanged,
    );
  }
}

/// タイムラインのフレーム一覧1コマ分の実プレビュー（ただの
/// 番号付き四角形ではなくちゃんとしたプレビューにする）。キャンバスモードの
/// フレーム一覧（frame_strip_widget.dartの_FrameThumbnail）と同じく、
/// 描画領域全体を合成した上で書き出し範囲（中央）だけを切り出して縮小表示する。
class _TimelineFrameThumbnail extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final List<Layer> layers;
  final TileManager tileManager;

  /// The project's background: blend modes act on it.
  final int backgroundColor;

  const _TimelineFrameThumbnail({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.tileManager,
    required this.layers,
    required this.backgroundColor,
  });

  @override
  State<_TimelineFrameThumbnail> createState() =>
      _TimelineFrameThumbnailState();
}

class _TimelineFrameThumbnailState extends State<_TimelineFrameThumbnail> {
  ui.Image? _image;
  int _renderRequest = 0;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.tileManager.addLayerContentListener(_layerChanged);
    _generate();
  }

  @override
  void didUpdateWidget(covariant _TimelineFrameThumbnail old) {
    super.didUpdateWidget(old);
    if (old.tileManager != widget.tileManager) {
      old.tileManager.removeLayerContentListener(_layerChanged);
      widget.tileManager.addLayerContentListener(_layerChanged);
    }
    if (old.tileManager != widget.tileManager ||
        old.projectId != widget.projectId ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex ||
        old.backgroundColor != widget.backgroundColor ||
        !listEquals(old.layers, widget.layers)) {
      _generate();
    }
  }

  void _layerChanged(String key) {
    if (_refreshScheduled) return;
    final frame = widget;
    final projects = context.read<ProjectService>();
    if (!frame.layers.any(
      (layer) =>
          projects.tileKeyFor(
            frame.projectId,
            frame.sceneId,
            frame.frameIndex,
            layer.id,
          ) ==
          key,
    )) {
      return;
    }
    _refreshScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _generate();
    });
    binding.ensureVisualUpdate();
  }

  Future<void> _generate() async {
    final request = ++_renderRequest;
    final frame = widget;
    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == frame.projectId)
        .firstOrNull;
    final tileManager = frame.tileManager;
    final drawW = tileManager.canvasWidth;
    final drawH = tileManager.canvasHeight;
    if (drawW <= 0 || drawH <= 0) return;
    final exportW = (project?.exportWidth ?? drawW).clamp(1, drawW).toInt();
    final exportH = (project?.exportHeight ?? drawH).clamp(1, drawH).toInt();

    final layers = frame.layers;

    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) =>
          ps.tileKeyFor(frame.projectId, frame.sceneId, frame.frameIndex, l.id),
      drawW,
      drawH,
      keyframeOf: (layer) => layer.keyframes.isEmpty
          ? null
          : materialTransformAt(layer, frame.frameIndex),
      groupKeyframeOf: (l) {
        final group = ps.groupContainingLayer(
          frame.projectId,
          frame.sceneId,
          l.id,
        );
        if (group == null || group.keyframes.isEmpty) return null;
        return LayerKeyframeEngine().valueAt(group.keyframes, frame.frameIndex);
      },
      paperColor: LayerCompositor.paperForBlendModes(
        layers,
        frame.backgroundColor,
      ),
    );

    final offsetX = (drawW - exportW) / 2;
    final offsetY = (drawH - exportH) / 2;
    const thumbW = 64;
    final thumbH = (thumbW * exportH / exportW).round().clamp(1, 200).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(
        offsetX,
        offsetY,
        exportW.toDouble(),
        exportH.toDouble(),
      ),
      ui.Rect.fromLTWH(0, 0, thumbW.toDouble(), thumbH.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    fullImage.dispose();
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(thumbW, thumbH);
    picture.dispose();

    if (!mounted || request != _renderRequest) {
      thumb.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = thumb);
    old?.dispose();
  }

  @override
  void dispose() {
    widget.tileManager.removeLayerContentListener(_layerChanged);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return RawImage(image: image, fit: BoxFit.cover);
  }
}

class _TimestampTriangle extends CustomClipper<Path> {
  const _TimestampTriangle();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(_TimestampTriangle oldClipper) => false;
}
