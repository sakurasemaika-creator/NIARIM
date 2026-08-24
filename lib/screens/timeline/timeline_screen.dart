import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../engine/autofill_batch_runner.dart';
import '../../engine/autofill_engine.dart' show AutofillMode;
import '../../engine/camera_engine.dart';
import '../../engine/filter_engine.dart';
import '../../engine/layer_compositor.dart';
import '../../engine/layer_keyframe_engine.dart';
import '../../engine/layer_range_resolver.dart';
import '../../engine/text_render.dart';
import '../../engine/tile_manager.dart';
import '../../engine/undo_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_clip.dart';
import '../../models/camera_keyframe.dart';
import '../../models/effect_filter_instance.dart';
import '../../models/layer.dart';
import '../../models/layer_group.dart';
import '../../models/layer_keyframe.dart';
import '../../models/timeline_marker.dart';
import '../../models/material_asset.dart';
import '../../models/scene.dart';
import '../../models/text_object.dart';
import '../../models/watermark_asset.dart';
import '../../services/advertising_service.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/material_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../services/settings_service.dart';
import '../../services/theme_service.dart';
import '../../services/tone_service.dart';
import '../../services/watermark_service.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/first_use_tooltip.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/progress_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

// タイムライントラッククリップ
enum _ClipTrackType { audio, video, image }

// クリップの長押しドラッグ操作の種別（仕様書05・タスク#99）。
enum _ClipDragMode { move, resizeLeft, resizeRight }

class _TrackClip {
  final String id;
  String label;
  int startFrame;
  int lengthFrames;
  final Color color;
  final _ClipTrackType trackType;
  // 実ファイルパス（音声・動画の再生位置連動に使用。プロジェクトの
  // Materials/フォルダ内のコピーを指す。仕様書21：MaterialID方式）
  String? filePath;
  // 参照している素材ID（仕様書21）
  final String? materialId;
  // 音声
  double volume;       // 0.0〜1.0
  double fadeIn;       // フェードイン秒数
  double fadeOut;      // フェードアウト秒数
  // 動画
  int useStart;        // 使用開始フレーム（素材内）
  int useEnd;          // 使用終了フレーム（素材内）
  double videoOpacity; // 0.0〜1.0
  // 素材種別ごとに複数行のタイムライン行を追加できるようにするための、
  // このクリップが属する行番号（0始まり、仕様書05）。
  final int trackRow;

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
    this.videoOpacity = 1.0,
    this.trackRow = 0,
  });
}


class TimelineScreen extends StatefulWidget {
  final String projectId;
  const TimelineScreen({super.key, required this.projectId});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  int _currentFrame = 0;
  String? _selectedSceneId;
  bool _isPlaying = false;
  Timer? _playTimer;
  // プレビュー全画面化（仕様書02・タスク#98）：確認・仕上がりチェックに
  // 集中できるよう、プレビューのみ＋再生コントロールだけを全画面表示する。
  bool _isPreviewFullscreen = false;
  // プレビュー欄のドラッグハンドルで一時的に変更中の高さ（ドラッグ中のみ
  // 使用し、指を離した時点でSettingsServiceへ確定保存してnullへ戻す）。
  double? _previewHeightDragOverride;

  // カーソル固定方式の移動モード
  bool _isMoveMode = false;
  int _moveCursorPos = 0;
  // 移動・複製時のカーソル吹き出しに表示する先頭サムネイル（仕様書05：
  // 「先頭のサムネイルのみ実画像を表示」）。シーン移動・フレーム移動で共用する。
  ui.Image? _moveThumbnail;

  // トラッククリップ
  final List<_TrackClip> _audioClips = [];
  final List<_TrackClip> _videoClips = [];
  final List<_TrackClip> _imageClips = [];

  // クリップの長押しドラッグ（表示開始位置の移動）・端のハンドルドラッグ
  // （使用範囲の変更）用の一時状態（仕様書05・タスク#99）。ジェスチャー中は
  // setState()のたびに_buildClipWidget()が再構築されるため、絶対座標の
  // アンカー（ドラッグ開始時点のグローバルX座標・開始フレーム位置・
  // 開始長さ）をStateフィールドとして保持し、毎回そこからの差分で
  // 目標値を再計算する（差分の累積方式だと再構築のたびにリセットされ
  // 正しく動作しないため）。
  String? _draggingClipId;
  _ClipDragMode? _clipDragMode;
  double _clipDragStartX = 0;
  int _clipDragStartFrame = 0;
  int _clipDragStartLength = 0;

  // カメラキーフレームマーカーの長押し不要ドラッグ用の一時状態（仕様書05
  // 「カメラ：XY移動・拡大・回転・キーフレーム」・タスク#100）。持ち方は
  // クリップドラッグと同じアンカー方式だが、ProjectServiceへの反映は
  // ドラッグ終了時の1回のみに留める（ドラッグ中に毎回notifyListeners()
  // すると、プレビューが持つcameraKeyframesの再合成が連続発生し重くなる
  // ため、ローカルStateだけで暫定位置を表示する）。
  int? _draggingCameraKfOriginalFrame;
  int? _draggingCameraKfLiveFrame;
  double _cameraKfDragStartX = 0;
  int _cameraKfDragStartFrame = 0;

  // 音声・動画クリップの再生位置連動（仕様書05）
  final Map<String, ap.AudioPlayer> _audioPlayers = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

  // エンドカードトラック（仕様書06・13）：差し替え不可・アプリが無料会員に
  // 強制表示するロゴ。プレミアム会員が削除（非表示）した場合のみtrue。
  // セッション中のみの状態で、次回プロジェクトを開くと「プレミアム会員は
  // デフォルトで削除する」設定（SettingsService）に従い直す。
  bool _endCardManuallyDeleted = false;

  // フレーム幅（px）。フレーム同士は隙間なく詰めて表示するため
  // 左右マージンは0にしている。
  static const double _frameW = 36.0;
  static const double _frameMargin = 0.0;
  static const double _cellW = _frameW + _frameMargin * 2;

  // 横スクロール連動
  late final ScrollController _frameScrollCtrl;
  late final ScrollController _audioScrollCtrl;
  late final ScrollController _videoScrollCtrl;
  late final ScrollController _imageScrollCtrl;
  late final ScrollController _cameraScrollCtrl;
  late final ScrollController _markerScrollCtrl;
  late final ScrollController _commonLayerScrollCtrl;
  late final ScrollController _effectFilterScrollCtrl;
  bool _syncingScroll = false;

  // 素材種別ごとに複数行のタイムライン行を追加できるようにするための、
  // 2行目以降の行専用スクロールコントローラー（仕様書05）。1行目は既存の
  // _audioScrollCtrl等をそのまま使う。キー形式は'種別名_行番号'。
  final Map<String, ScrollController> _rowScrollCtrls = {};

  ScrollController _rowScrollCtrl(MaterialType type, int rowIndex) {
    if (rowIndex == 0) {
      return switch (type) {
        MaterialType.image => _imageScrollCtrl,
        MaterialType.video => _videoScrollCtrl,
        MaterialType.audio => _audioScrollCtrl,
      };
    }
    final key = '${type.name}_$rowIndex';
    return _rowScrollCtrls.putIfAbsent(key, () {
      final ctrl = ScrollController();
      ctrl.addListener(() => _syncFrom(ctrl));
      return ctrl;
    });
  }

  // 共通レイヤートラックのドラッグハンドル操作用の累積ピクセル（仕様書16：
  // タイムライン上では左右のドラッグハンドルでも表示範囲を変更できる）
  double _commonDragAccumPx = 0;

  // シーン複数選択モード（仕様書05：「選択」ボタンで開始）
  bool _isSceneMultiSelect = false;
  final Set<String> _selectedSceneIds = {};

  // フレーム複数選択モード（仕様書05：シーンと同じ操作体系。「選択」ボタン、または
  // シーンチップの長押し「シーン内フレームを全選択」から開始）
  bool _isFrameMultiSelect = false;
  final Set<int> _selectedFrameIndices = {};
  bool _isFrameMoveMode = false;
  int _frameMoveCursorPos = 0;

  // フレーム一覧も画面中央に固定で赤枠を表示し、現在位置のフレームがそこへ
  // 来るよう一覧側をスクロールさせる（キャンバスモードのフレーム一覧と
  // 同じ挙動）。_frameScrollCtrlは他トラックと同期済みのため、
  // ここでのスクロールは共通レイヤー・素材トラック等にも連動する。
  int? _lastCenteredFrame;

  void _maybeCenterCurrentFrame() {
    if (_isFrameMoveMode) return; // 移動モード中はレイアウトが異なるため対象外
    if (_lastCenteredFrame == _currentFrame) return;
    final hadPrevious = _lastCenteredFrame != null;
    _lastCenteredFrame = _currentFrame;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerFrameInList(animate: hadPrevious));
  }

  // フレーム一覧の左右には((ビューポート幅-セル幅)/2)の余白（_buildFrameList
  // 参照）を入れてあるため、先頭・末尾のフレームも赤枠（画面中央）まで
  // きっちりスクロールできる。
  void _centerFrameInList({required bool animate}) {
    if (!_frameScrollCtrl.hasClients) return;
    final target = (_currentFrame * _cellW).clamp(0.0, _frameScrollCtrl.position.maxScrollExtent);
    if (animate) {
      _frameScrollCtrl.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _frameScrollCtrl.jumpTo(target);
    }
  }

  /// スワイプ・ドラッグを手放した位置が中途半端でも、赤枠に一番近い
  /// フレームへ自動的にスナップさせる（キャンバスモードのフレーム一覧と
  /// 同じ挙動）。
  bool _handleFrameListScrollEnd(ScrollEndNotification notification) {
    if (notification.dragDetails == null) return false;
    if (_isFrameMoveMode || _isFrameMultiSelect) return false;
    final total = _totalFrames;
    if (total <= 0 || !_frameScrollCtrl.hasClients) return false;
    final nearest = (_frameScrollCtrl.offset / _cellW).round().clamp(0, total - 1);
    if (nearest != _currentFrame) {
      setState(() => _currentFrame = nearest);
    } else {
      _centerFrameInList(animate: true);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // _selectedSceneIdはbuild()内で実データ（ProjectService.scenesOf）が
    // 取得でき次第、先頭シーンへ同期する。

    _frameScrollCtrl = ScrollController();
    _audioScrollCtrl = ScrollController();
    _videoScrollCtrl = ScrollController();
    _imageScrollCtrl = ScrollController();
    _cameraScrollCtrl = ScrollController();
    _markerScrollCtrl = ScrollController();
    _commonLayerScrollCtrl = ScrollController();
    _effectFilterScrollCtrl = ScrollController();

    for (final ctrl in _trackScrollCtrls) {
      ctrl.addListener(() => _syncFrom(ctrl));
    }

    // 制作時間カウント（仕様書19：タイムラインモードのみカウント）
    context.read<ProjectService>().beginWorkTracking(widget.projectId);
  }

  List<ScrollController> get _trackScrollCtrls => [
    _frameScrollCtrl,
    _audioScrollCtrl,
    _videoScrollCtrl,
    _imageScrollCtrl,
    _cameraScrollCtrl,
    _markerScrollCtrl,
    _commonLayerScrollCtrl,
    _effectFilterScrollCtrl,
    ..._rowScrollCtrls.values,
  ];

  void _syncFrom(ScrollController source) {
    if (_syncingScroll) return;
    if (!source.hasClients) return;
    _syncingScroll = true;
    final offset = source.offset;
    for (final ctrl in _trackScrollCtrls) {
      if (ctrl != source && ctrl.hasClients) {
        ctrl.jumpTo(offset.clamp(0.0, ctrl.position.maxScrollExtent));
      }
    }
    _syncingScroll = false;
  }

  @override
  void dispose() {
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
    _moveThumbnail?.dispose();
    context.read<ProjectService>().endWorkTracking();
    super.dispose();
  }

  /// 移動モードのカーソル吹き出し用に、指定シーン・フレームの先頭サムネイルを
  /// 生成する（仕様書05：「先頭のサムネイルのみ実画像を表示」）。
  /// 小さいプレビュー用に縮小したui.Imageを返す。生成できない場合はnull。
  Future<void> _loadMoveThumbnail(String sceneId, {int frameIndex = 0}) async {
    final ps = context.read<ProjectService>();
    final scene = ps.scenesOf(widget.projectId).where((s) => s.id == sceneId).firstOrNull;
    if (scene == null || scene.frames.isEmpty) return;
    final frame = scene.frames[frameIndex.clamp(0, scene.frames.length - 1)];
    final tileManager = ps.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;
    if (w <= 0 || h <= 0) return;
    const size = 48;
    final fullImage = await LayerCompositor.composite(
      tileManager,
      ps.layersOf(widget.projectId, sceneId, frame.index),
      (l) => ps.tileKeyFor(widget.projectId, sceneId, frame.index, l.id),
      w,
      h,
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
      final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
      final fps = project?.fps ?? 24;
      _playTimer = Timer.periodic(
        Duration(milliseconds: (1000 / fps).round()),
        (_) {
          final total = _totalFrames;
          setState(() {
            _currentFrame = (_currentFrame + 1) % total;
          });
          _syncMediaPlayback();
        },
      );
      setState(() => _isPlaying = true);
      _syncMediaPlayback();
    }
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
  /// 仕様書05：音声＝再生位置変更・フェードイン/アウト・音量変更、動画＝再生位置変更。
  void _syncMediaPlayback() {
    final ps = context.read<ProjectService>();
    final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
    final fps = (project?.fps ?? 24).toDouble();
    for (final clip in _audioClips) {
      _syncAudioClip(clip, fps);
    }
    for (final clip in _videoClips) {
      _syncVideoClip(clip, fps);
    }
  }

  bool _clipInRange(_TrackClip clip) =>
      _currentFrame >= clip.startFrame && _currentFrame < clip.startFrame + clip.lengthFrames;

  Future<void> _syncAudioClip(_TrackClip clip, double fps) async {
    final path = clip.filePath;
    if (path == null) return;
    final player = _audioPlayers.putIfAbsent(clip.id, () => ap.AudioPlayer());
    if (!_clipInRange(clip) || !_isPlaying) {
      if (player.state == ap.PlayerState.playing) await player.pause();
      return;
    }
    final elapsedFrames = _currentFrame - clip.startFrame;
    // フェードイン・フェードアウトを音量へ反映
    double vol = clip.volume;
    final elapsedSec = elapsedFrames / fps;
    final remainingSec = (clip.lengthFrames - elapsedFrames) / fps;
    if (clip.fadeIn > 0 && elapsedSec < clip.fadeIn) {
      vol *= (elapsedSec / clip.fadeIn).clamp(0.0, 1.0);
    }
    if (clip.fadeOut > 0 && remainingSec < clip.fadeOut) {
      vol *= (remainingSec / clip.fadeOut).clamp(0.0, 1.0);
    }
    await player.setVolume(vol.clamp(0.0, 1.0));
    if (player.state != ap.PlayerState.playing) {
      final targetFrame = clip.useStart + elapsedFrames;
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
      if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
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
    await controller.setVolume(clip.videoOpacity.clamp(0.0, 1.0));
    final elapsedFrames = _currentFrame - clip.startFrame;
    final targetFrame = clip.useStart + elapsedFrames;
    final targetPos = Duration(milliseconds: (targetFrame / fps * 1000).round());
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

  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdvertisingService>();

    // シーンは実プロジェクトデータ（ProjectService）から取得する。
    // 選択中シーンが未設定・削除済みの場合は先頭シーンへ同期する。
    final scenes = context.watch<ProjectService>().scenesOf(widget.projectId);
    if (scenes.isNotEmpty &&
        (_selectedSceneId == null || !scenes.any((s) => s.id == _selectedSceneId))) {
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
    // プレビューと再生コントロールのみを全画面表示する（仕様書02・
    // タスク#98）。_buildPreview()・_buildPlaybackControls()は通常表示と
    // 完全に同じメソッドをそのまま再利用するため、再生中のフレーム送りや
    // スクラブ操作の挙動に差異は生じない。
    if (_isPreviewFullscreen) {
      final l10n = AppLocalizations.of(context)!;
      final theme = context.watch<ThemeService>().current;
      return Scaffold(
        // 映写モードの背景も固定の黒ではなく、テーマのパネル背景色に連動
        // させる（それでも大抵は暗色系のためチェック目的の集中は保たれる）。
        backgroundColor: theme.panelBgColor,
        body: Listener(
          onPointerDown: (_) => context.read<ProjectService>().pingWorkActivity(),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.fullscreen_exit, color: theme.textColor),
                    tooltip: l10n.timelineFullscreenPreviewCloseTooltip,
                    onPressed: () => setState(() => _isPreviewFullscreen = false),
                  ),
                ),
                _buildPreview(),
                _buildSeekBar(),
                _buildPlaybackControls(),
              ],
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Listener(
        // 制作時間カウント（仕様書19）：操作のたびに無操作タイマーをリセットする
        onPointerDown: (_) => context.read<ProjectService>().pingWorkActivity(),
        child: SafeArea(
        child: LayoutBuilder(
          builder: (context, outerConstraints) {
            return Column(
              children: [
                _buildTopBar(),
                _buildPreviewWithHandle(outerConstraints.maxHeight),
                _buildSeekBar(),
                _buildPlaybackControls(),
                _buildToolbar(),
                _buildSceneTabs(),
                _buildFrameList(),
                // 各種タイムライン行（仕様書05）：デフォルトではプレビュー・
                // フレーム一覧のみを表示し、それぞれ中身（共通レイヤー・動画・
                // 音源・カメラキーフレーム・タイムスタンプ・演出フィルター）が
                // 1つでも追加された行だけを表示する。最後の1件を削除すれば、
                // その行だけ最初と同じく非表示に戻る（画像素材は共通レイヤー
                // 機能とキャンバスモードの画像読み込みで代替できるため廃止）。
                // 表示順：フレーム・シーン・共通レイヤー・動画・音源・カメラ・
                // タイムスタンプ・演出フィルター・エンドカードの順。
                // プレビュー欄をドラッグハンドルで縮めた分だけ、この一覧が
                // スクロールで広く見られるようにExpanded+スクロールにしている。
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCommonLayerTrack(),
                        // シーン・フレームの複数選択モード中の一括操作バー
                        // （小さいボタンではなく素材タイムラインの上に大きな
                        // 3分割ボタンで表示）
                        _buildMultiSelectActionBar(),
                        _buildMaterialTrackGroup(
                          type: MaterialType.video,
                          icon: Icons.videocam,
                          defaultLabel: l10n.projectListMaterialVideo,
                          allClips: _videoClips,
                          addColor: Colors.blue[700]!,
                        ),
                        _buildMaterialTrackGroup(
                          type: MaterialType.audio,
                          icon: Icons.audiotrack,
                          defaultLabel: l10n.projectListMaterialAudio,
                          allClips: _audioClips,
                          addColor: Colors.orange[700]!,
                        ),
                        _buildCameraTrack(),
                        _buildMarkerTrack(),
                        _buildEffectFilterTrack(),
                        _buildEndCardTrack(),
                        if (adService.shouldShowAds) const AdBannerWidget(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context)!;
    final projectName = context.watch<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull
        ?.name ??
        l10n.timelineDefaultProjectName;
    final undoManager = context.watch<UndoManager>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // キャンバスモードへ戻るボタン：矢印＋パレットアイコンの組み合わせで
          // 「戻る」と「戻り先はキャンバス（描画）モード」の両方を一目で
          // 表せるようにする。プロジェクト名の直前（左側）に置く。
          IconButton(
            icon: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.arrow_back), Icon(Icons.palette_outlined, size: 18)],
            ),
            tooltip: l10n.timelineBackToCanvasTooltip,
            onPressed: _saveAndGoToCanvas,
          ),
          Expanded(child: Text(projectName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Kuramubon'))),
          // プロジェクト一覧へ戻るボタン。上記のキャンバスへ戻るボタンと
          // 位置を入れ替え、家アイコンにしてプロジェクト一覧＝ホームである
          // ことをわかりやすくしている。
          IconButton(icon: const Icon(Icons.home_outlined), tooltip: l10n.timelineBackToProjectListTooltip, onPressed: _confirmBackToProjectList),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: l10n.commonUndo,
            onPressed: undoManager.canUndo ? undoManager.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: l10n.commonRedo,
            onPressed: undoManager.canRedo ? undoManager.redo : null,
          ),
          // 三点メニュー（保存ボタン・プロジェクト保存ボタンはセーブツリー
          // （設定によってはセーブスロット）と役割が被っていた
          // ため削除し、セーブツリー/スロット・自動塗り実行・書き出しの
          // 3項目のみに整理した）。
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == 'autofill') _showAutofillDialog();
              if (action == 'save_tree') context.push('/save-tree/${widget.projectId}?entry=timeline');
              if (action == 'export') context.push('/export/${widget.projectId}');
              if (action == 'duration') _showDurationChangeDialog();
              if (action == 'canvas_size') _showCanvasSizeChangeDialog();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'save_tree',
                child: Text(context.read<SaveTreeService>().isTreeMode
                    ? l10n.saveTreeScreenTitleTree
                    : l10n.saveTreeScreenTitleSlot),
              ),
              PopupMenuItem(value: 'autofill', child: Text(l10n.layerPanelMenuRunAutofill)),
              PopupMenuItem(value: 'duration', child: Text(l10n.timelineDurationChangeMenuItem)),
              PopupMenuItem(value: 'canvas_size', child: Text(l10n.timelineCanvasSizeChangeMenuItem)),
              PopupMenuItem(value: 'export', child: Text(l10n.timelineExportMenuItem)),
            ],
          ),
          const HelpButton(topic: 'タイムライン'),
        ],
      ),
    );
  }

  /// プレビュー本体（プレビュー画像＋全画面化ボタン）。PC/DeXモードでは
  /// 横幅を制限して中央寄せにし、横に間延びした帯状にならないようにする。
  Widget _buildPreviewContent() {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final sceneId = _selectedSceneId;
    final preview = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      // プレビュー画像自体は透明部分を含むため、背景は実際のキャンバス背景
      // （既定は白）に合わせる必要がある（濃色にすると透明部分の見え方が
      // 実際のキャンバス画面と一致しなくなるため、ここは色固定のままにする
      // ——テーマ連動にはしない、意図的な例外）。
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Stack(
        children: [
          Positioned.fill(
            child: sceneId == null
                ? Center(child: Text(l10n.timelinePreviewPlaceholder, style: const TextStyle(color: Colors.grey)))
                : _TimelinePreview(
                    tileManager: ps.tileManagerOf(widget.projectId),
                    layers: ps.layersOf(widget.projectId, sceneId, _currentFrame),
                    sceneId: sceneId,
                    frameIndex: _currentFrame,
                    cameraKeyframes: ps.cameraKeyframesOf(widget.projectId, sceneId),
                    effectFilters: ps.effectFiltersOf(widget.projectId, sceneId),
                    layerHomes: ps.layerHomesOf(widget.projectId),
                    groups: ps.layerGroupsOf(widget.projectId, sceneId),
                  ),
          ),
          // プレビュー全画面化ボタン（仕様書02・タスク#98：確認・仕上がり
          // チェックに集中できるよう、プレビューのみを拡大表示する導線）。
          // 全画面表示中は_buildPreviewContent()自体が呼ばれないため、ここには
          // 「開く」方向のボタンのみを置けばよい。
          Positioned(
            right: 4,
            top: 4,
            child: FirstUseTooltip(
              tooltipKey: 'timeline_preview_fullscreen',
              message: l10n.timelinePreviewFullscreenTip,
              child: Material(
                color: context.watch<ThemeService>().current.menuBgColor.withValues(alpha: 0.7),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.fullscreen, color: context.watch<ThemeService>().current.textColor, size: 20),
                  tooltip: l10n.timelinePreviewFullscreenTooltip,
                  onPressed: sceneId == null
                      ? null
                      : () => setState(() => _isPreviewFullscreen = true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // 幅の制限は呼び出し元（_buildPreviewWithHandle）のAspectRatioが
    // 実際のキャンバス比率に応じて行うため、ここでは横に間延びしない
    // よう最低限の上限（PC/DeXモードのみ）だけを設けておく。
    if (!isWideScreen(context)) return preview;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: preview,
    );
  }

  /// 全画面プレビュー表示（isPreviewFullscreen）専用。周囲に空きがあれば
  /// 目一杯まで拡大する。
  Widget _buildPreview() => Expanded(flex: 3, child: _buildPreviewContent());

  /// 通常表示のプレビュー欄。底辺のドラッグハンドルで縦方向のサイズを
  /// 変更できるようにする（仕様書05）。高さはアプリ全体で共通の割合として
  /// SettingsServiceへ保存され、作業を中断したり別プロジェクトへ移動しても
  /// 最後に設定した位置が引き継がれる。ドラッグ中は指を離すまでローカル
  /// 状態のみを更新し、離した瞬間に確定値を保存する。
  Widget _buildPreviewWithHandle(double maxAvailableHeight) {
    final settings = context.watch<SettingsService>();
    final ps = context.watch<ProjectService>();
    final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
    final aspect = (project != null && project.exportHeight > 0)
        ? project.exportWidth / project.exportHeight
        : 16 / 9;
    final maxH = maxAvailableHeight > 0 ? maxAvailableHeight : 600.0;
    final baseHeight = (maxH * settings.timelinePreviewHeightFraction).clamp(120.0, maxH * 0.75);
    final previewHeight = _previewHeightDragOverride ?? baseHeight;
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
          height: previewHeight,
          width: double.infinity,
          child: Center(
            child: AspectRatio(aspectRatio: aspect, child: _buildPreviewContent()),
          ),
        ),
        // ヒット領域はシークバー等の他の操作と混同しないよう、見た目の
        // グリップより広めに取っている（ドラッグ開始位置が少しずれても
        // 確実にリサイズとして認識されるようにするため）。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onVerticalDragUpdate: (d) {
            setState(() {
              final current = (_previewHeightDragOverride ?? baseHeight) + d.delta.dy;
              _previewHeightDragOverride = current.clamp(120.0, maxH * 0.75);
            });
          },
          onVerticalDragEnd: (_) {
            final h = _previewHeightDragOverride;
            if (h != null) {
              context.read<SettingsService>().setTimelinePreviewHeightFraction(h / maxH);
            }
          },
          child: Container(
            color: Colors.transparent,
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
      ],
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
        child: SteppedSlider(
          value: _currentFrame.clamp(0, maxFrame).toDouble(),
          min: 0,
          max: maxFrame.toDouble(),
          divisions: maxFrame > 0 ? maxFrame : null,
          showSteppers: false,
          onChanged: (v) => setState(() {
            _currentFrame = v.round();
            _isPlaying = false;
          }),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.skip_previous), tooltip: l10n.timelineSkipToStart, onPressed: () => setState(() => _currentFrame = 0)),
          IconButton(icon: const Icon(Icons.fast_rewind), tooltip: l10n.timelineStepBack, onPressed: () { if (_currentFrame > 0) setState(() => _currentFrame--); }),
          IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow), tooltip: _isPlaying ? l10n.commonPause : l10n.commonPlay, onPressed: _togglePlay),
          IconButton(icon: const Icon(Icons.fast_forward), tooltip: l10n.timelineStepForward, onPressed: () { if (_currentFrame < _totalFrames - 1) setState(() => _currentFrame++); }),
          IconButton(icon: const Icon(Icons.skip_next), tooltip: l10n.timelineSkipToEnd, onPressed: () => setState(() => _currentFrame = _totalFrames - 1)),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = context.watch<PremiumService>().isPremium;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.videocam, size: 18),
            onPressed: () => _showAddClipDialog(l10n.projectListMaterialVideo, _videoClips, Colors.blue[700]!, _ClipTrackType.video),
            tooltip: l10n.timelineAddVideoTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.audiotrack, size: 18),
            onPressed: () => _showAddClipDialog(l10n.projectListMaterialAudio, _audioClips, Colors.orange[700]!, _ClipTrackType.audio),
            tooltip: l10n.timelineAddAudioTooltip,
          ),
          // ウォーターマーク：無料会員は🔒付き表示、タップで共通Premiumバナー
          _buildWatermarkButton(isPremium),
          IconButton(icon: const Icon(Icons.movie_filter, size: 18), onPressed: () => _showEffectFilterDialog(), tooltip: l10n.timelineEffectFilterLabel),
          IconButton(icon: const Icon(Icons.camera, size: 18), onPressed: _addCameraKf, tooltip: l10n.timelineAddCameraKfTooltip),
          IconButton(icon: const Icon(Icons.push_pin_outlined, size: 18), onPressed: _showAddMarkerDialog, tooltip: l10n.timelineMarkerTrackLabel),
          IconButton(icon: const Icon(Icons.upload_file, size: 18), onPressed: () => context.push('/export/${widget.projectId}'), tooltip: l10n.transferExport),
        ],
      ),
    );
  }

  Widget _buildWatermarkButton(bool isPremium) {
    final l10n = AppLocalizations.of(context)!;
    if (isPremium) {
      return IconButton(
        icon: const Icon(Icons.branding_watermark, size: 18),
        onPressed: _showWatermarkPicker,
        tooltip: l10n.timelineAddWatermarkTooltip,
      );
    }
    // 無料会員：🔒アイコン付きで表示、タップで共通Premiumバナー
    return GestureDetector(
      onTap: () => showPremiumBanner(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.branding_watermark, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 2),
            const Icon(Icons.lock, size: 12, color: Colors.amber),
          ],
        ),
      ),
    );
  }

  /// 登録済みウォーターマーク一覧から選択して追加する（仕様書05・13：
  /// ウォーターマークは専用トラックを持たず、画像素材と同じレイヤー機構
  /// 〔LayerType.watermark〕を使ってタイムライン素材として追加する）。
  void _showWatermarkPicker() {
    final l10n = AppLocalizations.of(context)!;
    final watermarkService = context.read<WatermarkService>();
    final assets = watermarkService.assets;
    if (assets.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.timelineWatermarkNotRegisteredTitle),
          content: Text(l10n.timelineWatermarkNotRegisteredBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n.timelineWatermarkSelectTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final asset in assets)
              ListTile(
                leading: Icon(asset.type == WatermarkAssetType.text ? Icons.text_fields : Icons.branding_watermark),
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

  /// 選択したウォーターマーク（画像 or 文字入力、仕様書01・13）をラスタライズし、
  /// LayerType.watermarkのレイヤーとして現在シーンへ追加する（表示範囲は
  /// デフォルトで全フレーム＝常時表示。以後の表示範囲・不透明度・差し替えは
  /// レイヤーパネルから調整できる）。
  Future<void> _addWatermarkLayer(WatermarkAsset asset) async {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    const defaultAngle = 0.0;
    const defaultScale = 0.25;
    final pixels = asset.type == WatermarkAssetType.text
        ? await _rasterizeTextWatermark(asset, w, h, angle: defaultAngle, scale: defaultScale)
        : await _rasterizeImageWatermark(asset, w, h, angle: defaultAngle, scale: defaultScale);
    if (pixels == null || !mounted) return;

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
    // いつでも変更できる（仕様書05：常時表示／エンドカード／任意フレーム
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.timelineWatermarkAddedSnackbar(asset.name))),
    );
  }

  /// [layer]の角度・大きさ・不透明度の変更をピクセルへ反映し直す
  /// （タイムラインでウォーターマークをタップして編集した際に呼ばれる）。
  Future<void> _reRasterizeWatermark(Layer layer, LayerHome home, {
    required double angle,
    required double scale,
  }) async {
    final watermarkService = context.read<WatermarkService>();
    final asset = watermarkService.assets.where((a) => a.id == layer.watermarkAssetId).firstOrNull;
    if (asset == null || !mounted) return;
    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;
    var pixels = asset.type == WatermarkAssetType.text
        ? await _rasterizeTextWatermark(asset, w, h, angle: angle, scale: scale)
        : await _rasterizeImageWatermark(asset, w, h, angle: angle, scale: scale);
    if (pixels == null || !mounted) return;
    pixels = _applyWatermarkEffects(pixels, w, h, asset);
    tileManager.replaceLayerPixels(
      projectService.tileKeyFor(widget.projectId, home.sceneId, home.frameIndex, layer.id),
      pixels,
    );
  }

  /// ウォーターマークのドロップシャドウ・縁取りを適用する。ウォーターマーク
  /// 設定画面で予め設定できるようにしたドロップシャドウ・縁取りを、実際に
  /// タイムラインへ配置する際のラスタライズ結果へ反映する。
  /// 縁取りはFilterEngine.applyOutline（元の描画内容を保持したまま外周へ
  /// リング状に描く）をそのまま使い、ドロップシャドウは元画像のシルエット
  /// （アルファそのまま・RGBを影色に置換）をオフセット＋ガウスぼかしした
  /// ものを下に敷いてから元画像を重ねて作る。
  Uint8List _applyWatermarkEffects(Uint8List pixels, int w, int h, WatermarkAsset asset) {
    var result = pixels;
    if (asset.outlineEnabled) {
      result = FilterEngine().applyOutline(result, w, h,
          color: asset.outlineColor, widthPx: asset.outlineWidth);
    }
    if (asset.shadowEnabled) {
      final silhouette = Uint8List(result.length);
      final sa = (asset.shadowColor >> 24) & 0xFF;
      final sr = (asset.shadowColor >> 16) & 0xFF;
      final sg = (asset.shadowColor >> 8) & 0xFF;
      final sb = asset.shadowColor & 0xFF;
      final offX = asset.shadowOffsetX.round();
      final offY = asset.shadowOffsetY.round();
      for (int y = 0; y < h; y++) {
        final sy = y - offY;
        if (sy < 0 || sy >= h) continue;
        for (int x = 0; x < w; x++) {
          final sx = x - offX;
          if (sx < 0 || sx >= w) continue;
          final srcA = result[(sy * w + sx) * 4 + 3];
          if (srcA == 0) continue;
          final idx = (y * w + x) * 4;
          silhouette[idx] = sr;
          silhouette[idx + 1] = sg;
          silhouette[idx + 2] = sb;
          silhouette[idx + 3] = ((srcA * sa) / 255).round();
        }
      }
      final blurred = asset.shadowBlur > 0
          ? FilterEngine().applyGaussianBlur(silhouette, w, h, asset.shadowBlur)
          : silhouette;
      // 影の上に元画像（縁取り適用済みの場合はそれも含む）を重ねて合成する。
      final composited = Uint8List.fromList(blurred);
      for (int i = 0; i < composited.length; i += 4) {
        final srcA = result[i + 3];
        if (srcA == 0) continue;
        if (srcA >= 255) {
          composited[i] = result[i];
          composited[i + 1] = result[i + 1];
          composited[i + 2] = result[i + 2];
          composited[i + 3] = 255;
        } else {
          // アルファブレンド（src over dst）
          final invA = 255 - srcA;
          composited[i] = ((result[i] * srcA + composited[i] * invA) / 255).round();
          composited[i + 1] = ((result[i + 1] * srcA + composited[i + 1] * invA) / 255).round();
          composited[i + 2] = ((result[i + 2] * srcA + composited[i + 2] * invA) / 255).round();
          composited[i + 3] = (srcA + (composited[i + 3] * invA / 255)).round().clamp(0, 255);
        }
      }
      result = composited;
    }
    return result;
  }

  /// 画像ウォーターマークをキャンバス全体サイズのRGBAピクセルへラスタライズする。
  /// 右下に配置する一般的なウォーターマーク位置をデフォルトとする。
  /// [angle]は度数法での回転角、[scale]はキャンバス幅に対する大きさの倍率
  /// （タイムラインでウォーターマークをタップすればいつでも変更できる）。
  Future<Uint8List?> _rasterizeImageWatermark(WatermarkAsset asset, int w, int h,
      {double angle = 0, double scale = 0.25}) async {
    final watermarkService = context.read<WatermarkService>();
    final path = await watermarkService.pathOf(asset.id);
    if (path == null || !mounted) return null;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (!mounted) {
      image.dispose();
      return null;
    }

    final targetW = w * scale;
    final imgScale = targetW / image.width;
    final drawW = image.width * imgScale;
    final drawH = image.height * imgScale;
    const margin = 16.0;
    final dx = w - drawW - margin;
    final dy = h - drawH - margin;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.save();
    canvas.translate(dx + drawW / 2, dy + drawH / 2);
    canvas.rotate(angle * 3.1415926535 / 180);
    canvas.translate(-(dx + drawW / 2), -(dy + drawH / 2));
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawW, drawH),
      ui.Paint(),
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    image.dispose();
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// 文字入力ウォーターマークをキャンバス全体サイズのRGBAピクセルへ
  /// ラスタライズする（仕様書01・13：「設定項目：画像選択 / 文字入力」）。
  /// 既存のテキストレイヤー描画エンジン（text_render.dart）を再利用し、
  /// 画像ウォーターマークと同様に右下へ配置する。フォント・[angle]（回転角）・
  /// [scale]（大きさ倍率）はいずれもタイムラインでウォーターマークをタップ
  /// すればいつでも変更できる。
  Future<Uint8List?> _rasterizeTextWatermark(WatermarkAsset asset, int w, int h,
      {double angle = 0, double scale = 0.25}) async {
    final text = asset.text ?? '';
    if (text.isEmpty) return null;
    final fontSize = h * 0.18 * scale;
    final color = ui.Color(asset.textColor ?? 0xFFFFFFFF);
    final textObject = TextObject(
      id: asset.id,
      text: text,
      fontSize: fontSize,
      color: color,
      fontFamily: asset.fontFamily ?? 'Roboto',
      align: TextAlign.right,
      rotation: angle,
      position: Offset(w * 0.1, h - fontSize * 1.6 - h * 0.02),
    );
    return rasterizeTextObject(textObject, w, h);
  }

  // 移動モード中の吹き出しプレビュー（仕様書05）
  // 先頭サムネイル＋白カード最大3枚、右上に枚数バッジ
  Widget _buildCursorBubble() {
    // 移動は複数選択モードからのみ起動するため常に_selectedSceneIds.lengthを使用
    final count = _selectedSceneIds.length;
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
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            // 先頭サムネイル（仕様書05：「先頭のサムネイルのみ実画像を表示」）
            Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: _moveThumbnail != null
                  ? RawImage(image: _moveThumbnail, fit: BoxFit.cover)
                  : const Icon(Icons.movie, size: 20, color: Colors.white54),
            ),
            // 枚数バッジ（右上）
            if (count > 1)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('×$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// シーンタブ（仕様書05：カーソル固定方式で並び替え）
  Widget _buildSceneTabs() {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final scenes = projectService.scenesOf(widget.projectId);
    return SizedBox(
      height: _isMoveMode ? 92 : 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0, right: 0,
            bottom: 0,
            height: 36,
            child: Row(
              children: [
                // 移動モード中：「決定」ボタン。通常時：「選択」ボタン。複数選択モード中の
                // 移動・複製・削除・全選択・全解除は、素材タイムラインの上に大きな専用
                // ボタンとして表示する（_buildMultiSelectActionBar参照）。
                if (_isMoveMode)
                  TextButton(
                    onPressed: () => _confirmMove(scenes),
                    child: Text(l10n.timelineConfirmButton, style: const TextStyle(fontSize: 11)),
                  )
                else if (!_isSceneMultiSelect)
                  TextButton(
                    onPressed: () => setState(() => _isSceneMultiSelect = true),
                    child: Text(l10n.toolbarItemSelect, style: const TextStyle(fontSize: 11)),
                  ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    // 移動モード：カーソル位置(n+1) + シーンチップ(n) = 2n+1
                    // 通常モード：シーンチップ(n) + ＋ボタン(1) = n+1
                    itemCount: _isMoveMode ? scenes.length * 2 + 1 : scenes.length + 1,
                    itemBuilder: (context, index) {
                      if (_isMoveMode) {
                        if (index.isEven) {
                          final cursorPos = index ~/ 2;
                          final isActive = _moveCursorPos == cursorPos;
                          return GestureDetector(
                            onTap: () => setState(() => _moveCursorPos = cursorPos),
                            child: Container(
                              width: 16,
                              alignment: Alignment.center,
                              child: Container(
                                width: 3,
                                height: 28,
                                color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          );
                        } else {
                          final sceneIndex = index ~/ 2;
                          final scene = scenes[sceneIndex];
                          final isMoving = _selectedSceneIds.contains(scene.id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Chip(
                              label: Text(scene.displayName,
                                  style: TextStyle(fontSize: 11,
                                      color: isMoving ? Theme.of(context).colorScheme.primary : null)),
                              backgroundColor: isMoving ? Theme.of(context).colorScheme.primaryContainer : null,
                            ),
                          );
                        }
                      } else {
                        if (index == scenes.length) {
                          return TextButton(
                            onPressed: () =>
                                context.read<ProjectService>().addScene(widget.projectId),
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
                              onTap: () {
                                if (_isSceneMultiSelect) {
                                  if (_selectedSceneIds.contains(scene.id)) {
                                    setState(() {
                                      _selectedSceneIds.remove(scene.id);
                                      if (_selectedSceneIds.isEmpty) _isSceneMultiSelect = false;
                                    });
                                  }
                                  // 未選択シーンは何もしない（仕様書05）
                                } else {
                                  _showRenameSceneDialog(scene);
                                }
                              },
                              onDoubleTap: _isSceneMultiSelect ? null : () => setState(() => _selectedSceneId = scene.id),
                              // 長押し：シーン内フレームを全選択し、フレーム複数選択モードへ
                              // 移行する（仕様書05：フレーム一覧と操作体系を統一）。
                              // シーン自体の複数選択（移動・削除）は上部の「選択」ボタンから行う。
                              onLongPress: () {
                                if (_isSceneMultiSelect || _isFrameMultiSelect) return;
                                final frameCount =
                                    context.read<ProjectService>().frameCount(widget.projectId, scene.id);
                                setState(() {
                                  _selectedSceneId = scene.id;
                                  _isFrameMultiSelect = true;
                                  _selectedFrameIndices
                                    ..clear()
                                    ..addAll(List.generate(frameCount, (i) => i));
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isSceneMultiSelect)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Icon(
                                            _selectedSceneIds.contains(scene.id)
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            size: 12,
                                          ),
                                        ),
                                      Text(scene.displayName, style: const TextStyle(fontSize: 11, fontFamily: 'Kuramubon')),
                                      // シーン内に自動塗り未更新のフレームがある場合の❗マーク
                                      // （仕様書04：更新マークはレイヤー・タイムライン両方に表示）
                                      if (projectService.sceneHasOutdatedAutofillLayers(widget.projectId, scene.id))
                                        GestureDetector(
                                          onTap: () => _showAutofillUpdateHelp(context),
                                          child: const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.error, color: Colors.orange, size: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) {},
                                ),
                              ),
                            ),
                            if (!_isSceneMultiSelect)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showSceneMenu(scene, scenes),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                  child: Icon(Icons.more_vert, size: 14),
                                ),
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                // 移動モード中：キャンセルボタン
                if (_isMoveMode)
                  TextButton(
                    onPressed: () => setState(() => _isMoveMode = false),
                    child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
          // 移動モード中：吹き出しプレビューをタブの上に表示
          if (_isMoveMode) _buildCursorBubble(),
        ],
      ),
    );
  }

  /// 選択中シーンを複製する（仕様書05：シーンのコピー。素材タイムラインの
  /// 上の大きなボタンから起動する）。並び順（シーン一覧の
  /// 実際の順序）に沿って1件ずつ複製元の直後へ挿入していく。
  void _duplicateSelectedScenes(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final targets = scenes.where((s) => _selectedSceneIds.contains(s.id)).toList();
    for (final scene in targets) {
      ps.duplicateScene(widget.projectId, scene.id, name: l10n.layerPanelCopySuffix(scene.displayName));
    }
    setState(() {
      _selectedSceneIds.clear();
      _isSceneMultiSelect = false;
    });
  }

  // 移動モード開始（仕様書05：複数選択モードからのみ起動）
  void _startMoveMode(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    setState(() {
      _isMoveMode = true;
      // 選択中シーンの並び順で最後のシーンの直後にカーソルを初期配置
      final lastIdx = scenes.lastIndexWhere((s) => _selectedSceneIds.contains(s.id));
      _moveCursorPos = lastIdx + 1;
    });
    final first = scenes.where((s) => _selectedSceneIds.contains(s.id)).firstOrNull;
    if (first != null) _loadMoveThumbnail(first.id);
  }

  // カーソル固定方式の移動確定（仕様書05：複数選択モードからのみ起動）
  void _confirmMove(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    // 選択シーンを並び順で抽出
    final moving = scenes.where((s) => _selectedSceneIds.contains(s.id)).toList();
    final selectedIndices = moving.map((s) => scenes.indexOf(s)).toList();
    final removedBefore = selectedIndices.where((i) => i < _moveCursorPos).length;
    final insertPos = (_moveCursorPos - removedBefore).clamp(0, scenes.length - moving.length);
    final reordered = List<Scene>.from(scenes)
      ..removeWhere((s) => _selectedSceneIds.contains(s.id))
      ..insertAll(insertPos, moving);
    context.read<ProjectService>().reorderScenesByIds(
        widget.projectId, reordered.map((s) => s.id).toList());
    setState(() {
      _isMoveMode = false;
      _isSceneMultiSelect = false;
      _selectedSceneIds.clear();
    });
  }

  // 三点メニュー（仕様書05：シーン名変更・複製・削除）
  void _showSceneMenu(Scene scene, List<Scene> scenes) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.timelineSceneRenameTitle),
              onTap: () { Navigator.pop(ctx); _showRenameSceneDialog(scene); },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.themeDuplicateAction),
              onTap: () {
                Navigator.pop(ctx);
                context.read<ProjectService>().duplicateScene(
                    widget.projectId, scene.id,
                    name: l10n.layerPanelCopySuffix(scene.displayName));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.timelineSceneDeleteMenuItem, style: const TextStyle(color: Colors.red)),
              // シーンが1件のみの場合は削除不可
              onTap: scenes.length > 1
                  ? () { Navigator.pop(ctx); _showSingleDeleteConfirm(scene); }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // 単体シーン削除の確認ダイアログ（仕様書05）
  void _showSingleDeleteConfirm(Scene scene) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSceneDeleteConfirmTitle(scene.displayName)),
        content: Text(l10n.timelineSceneDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>().removeScene(widget.projectId, scene.id);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  // 複数選択シーン削除の確認ダイアログ（仕様書05）
  void _showMultiDeleteConfirm() {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedSceneIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSceneMultiDeleteConfirmTitle(count)),
        content: Text(l10n.timelineSceneDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>()
                  .removeScenes(widget.projectId, _selectedSceneIds.toList());
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
    final controller = TextEditingController(text: scene.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSceneRenameTitle),
        content: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<ProjectService>()
                    .renameScene(widget.projectId, scene.id, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  // タイムライン側❗マークのヘルプ（仕様書04：レイヤーパネル側と同一文言）
  void _showAutofillUpdateHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelAutofillUpdateHelpTitle),
        content: Text(l10n.timelineAutofillUpdateHelpBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  /// フレーム一覧（仕様書05：シーンと同じ複数選択・カーソル固定移動の操作体系）。
  Widget _buildFrameList() {
    final l10n = AppLocalizations.of(context)!;
    final total = _totalFrames;
    final projectService = context.watch<ProjectService>();
    final frameListSceneId = _selectedSceneId;
    _maybeCenterCurrentFrame();
    return SizedBox(
      height: _isFrameMoveMode ? 92 : 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0, right: 0, bottom: 0, height: 50,
            child: Container(
              decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
              child: Row(
                children: [
                  _buildTrackLabel(Icons.movie_filter, l10n.timelineFrameTrackLabel),
                  // 移動モード中：「決定」。通常時：「選択」。複数選択モード中の移動・複製・
                  // 削除・全選択・全解除は素材タイムラインの上の大きなボタンへ移動した
                  // （_buildMultiSelectActionBar参照）。
                  if (_isFrameMoveMode)
                    TextButton(
                      onPressed: _confirmFrameMove,
                      child: Text(l10n.timelineConfirmButton, style: const TextStyle(fontSize: 11)),
                    )
                  else if (!_isFrameMultiSelect)
                    TextButton(
                      onPressed: () => setState(() => _isFrameMultiSelect = true),
                      child: Text(l10n.toolbarItemSelect, style: const TextStyle(fontSize: 11)),
                    ),
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      // 左右に((ビューポート幅-セル幅)/2)の余白を入れることで、
                      // 先頭・末尾のフレームも赤枠（画面中央）まできっちり
                      // スクロールできるようにする。
                      final sidePadding = ((constraints.maxWidth - _cellW) / 2).clamp(0.0, double.infinity);
                      return NotificationListener<ScrollEndNotification>(
                        onNotification: _handleFrameListScrollEnd,
                        child: Stack(
                      children: [
                        ListView.builder(
                      controller: _frameScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: sidePadding),
                      // 移動モード：カーソル位置(n+1) + フレームチップ(n) = 2n+1
                      // 通常モード：フレームチップ(n) + ＋ボタン(1) = n+1
                      itemCount: _isFrameMoveMode ? total * 2 + 1 : total + 1,
                      itemBuilder: (context, index) {
                        if (_isFrameMoveMode) {
                          if (index.isEven) {
                            final cursorPos = index ~/ 2;
                            final isActive = _frameMoveCursorPos == cursorPos;
                            return GestureDetector(
                              onTap: () => setState(() => _frameMoveCursorPos = cursorPos),
                              child: Container(
                                width: 12,
                                alignment: Alignment.center,
                                child: Container(
                                  width: 3, height: 28,
                                  color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            );
                          } else {
                            final frameIndex = index ~/ 2;
                            final isMoving = _selectedFrameIndices.contains(frameIndex);
                            return Container(
                              width: _frameW,
                              margin: const EdgeInsets.symmetric(horizontal: _frameMargin),
                              decoration: BoxDecoration(
                                color: isMoving ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[850],
                                border: Border.all(color: Colors.grey[700]!),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Center(child: Text('${frameIndex + 1}',
                                  style: TextStyle(fontSize: 9,
                                      color: isMoving ? Theme.of(context).colorScheme.primary : null))),
                            );
                          }
                        }
                        if (index == total) {
                          return GestureDetector(
                            onTap: () {
                              final sceneId = _selectedSceneId;
                              if (sceneId == null) return;
                              if (!_canAddFrames(1)) return;
                              context.read<ProjectService>().addFrame(widget.projectId, sceneId);
                            },
                            child: Container(
                              width: _frameW,
                              margin: const EdgeInsets.symmetric(horizontal: _frameMargin),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[600]!),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Center(child: Icon(Icons.add, size: 16, color: Colors.grey)),
                            ),
                          );
                        }
                        // 現在フレームの強調表示は画面中央固定の赤枠が担うため、
                        // 通常モードでは枠色を変えない（複数選択のチェック状態のみ
                        // ここで色分けする）。
                        final isChecked = _selectedFrameIndices.contains(index);
                        // このフレームに自動塗り未更新のレイヤーがある場合の❗マーク
                        // （仕様書04：更新マークはレイヤー・タイムライン両方に表示）
                        final hasOutdatedAutofill = frameListSceneId != null &&
                            projectService.frameHasOutdatedAutofillLayers(
                                widget.projectId, frameListSceneId, index);
                        return GestureDetector(
                          onTap: () {
                            if (_isFrameMultiSelect) {
                              if (isChecked) {
                                setState(() {
                                  _selectedFrameIndices.remove(index);
                                  if (_selectedFrameIndices.isEmpty) _isFrameMultiSelect = false;
                                });
                              }
                              // 未選択フレームは何もしない（シーンと同じ操作体系、仕様書05）
                            } else {
                              setState(() => _currentFrame = index);
                            }
                          },
                          // 長押し：このフレームを選択済みの状態でフレーム複数選択モードを開始する
                          onLongPress: () {
                            if (_isFrameMultiSelect) return;
                            setState(() {
                              _isFrameMultiSelect = true;
                              _selectedFrameIndices.add(index);
                            });
                          },
                          child: Container(
                            width: _frameW,
                            margin: const EdgeInsets.symmetric(horizontal: _frameMargin),
                            decoration: BoxDecoration(
                              // サムネイル画像自体は透明部分を含むため、セルの
                              // 背景は実際のキャンバス背景（既定は白）に合わせる。
                              // 濃いグレーのままだと透明部分の見え方が実際の
                              // キャンバス画面と一致しなかったため修正。
                              color: isChecked ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                              border: Border.all(
                                  color: isChecked
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Stack(
                              children: [
                                // フレームの実プレビュー（ただの四角形では
                                // なくちゃんとしたプレビューにする）。
                                if (frameListSceneId != null)
                                  Positioned.fill(
                                    child: _TimelineFrameThumbnail(
                                      projectId: widget.projectId,
                                      sceneId: frameListSceneId,
                                      frameIndex: index,
                                    ),
                                  ),
                                Positioned(
                                  left: 1, bottom: 1,
                                  child: Text('${index + 1}',
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
                                ),
                                if (hasOutdatedAutofill)
                                  Positioned(
                                    left: 1, top: 1,
                                    child: GestureDetector(
                                      onTap: () => _showAutofillUpdateHelp(context),
                                      child: const Icon(Icons.error, color: Colors.orange, size: 10),
                                    ),
                                  ),
                                if (_isFrameMultiSelect)
                                  Positioned(
                                    right: 1, top: 1,
                                    child: Icon(
                                      isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                                      size: 10,
                                    ),
                                  ),
                              ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // 画面中央に固定表示する赤枠。フレーム一覧側が
                    // スクロールして現在位置のフレームをここへ合わせる。
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: _frameW,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                      );
                    }),
                  ),
                  // 移動モード中：キャンセルボタン
                  if (_isFrameMoveMode)
                    TextButton(
                      onPressed: () => setState(() => _isFrameMoveMode = false),
                      child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),
          // 移動モード中：吹き出しプレビューをフレーム一覧の上に表示
          if (_isFrameMoveMode) _buildFrameCursorBubble(),
        ],
      ),
    );
  }

  Widget _buildFrameCursorBubble() {
    final count = _selectedFrameIndices.length;
    final cardCount = count.clamp(1, 3);
    return Positioned(
      bottom: 50, left: 0, right: 0,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = cardCount - 1; i >= 1; i--)
              Positioned(
                left: i * 3.0, top: -(i * 3.0),
                child: Transform.rotate(
                  angle: (i.isOdd ? 1 : -1) * 0.025,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            Container(
              width: 40, height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: _moveThumbnail != null
                  ? RawImage(image: _moveThumbnail, fit: BoxFit.cover)
                  : const Icon(Icons.movie_filter, size: 18, color: Colors.white54),
            ),
            if (count > 1)
              Positioned(
                right: -8, top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('×$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// フレーム追加・複製の前に、無料会員の長さ上限（90秒）を超えないか
  /// チェックする。90秒を超えるようになりそうな場合はフレーム追加や複製
  /// ボタンタップ時に注意文がポップアップ表示され、90秒以上にはならない。
  /// 超える場合は警告ダイアログを表示してfalseを返す（呼び出し元は操作を
  /// 中止する）。プレミアム会員は上限が2時間（7200秒）と大きいため事実上
  /// ブロックされない。
  bool _canAddFrames(int count) {
    final isPremium = context.read<PremiumService>().isPremium;
    final ps = context.read<ProjectService>();
    final maxSeconds = isPremium ? 7200 : 90;
    final projected = ps.projectedDurationSeconds(widget.projectId, frameDelta: count);
    if (projected <= maxSeconds) return true;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineDurationLimitTitle),
        content: Text(isPremium
            ? l10n.timelineDurationLimitBodyPremium
            : l10n.timelineDurationLimitBodyFree),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
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
    for (final idx in sorted.reversed) {
      ps.duplicateFrame(widget.projectId, sceneId, idx);
    }
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
    for (final idx in sorted.reversed) {
      ps.removeFrame(widget.projectId, sceneId, idx);
    }
    setState(() {
      _selectedFrameIndices.clear();
      _isFrameMultiSelect = false;
      _currentFrame = _currentFrame.clamp(0, _totalFrames - 1);
    });
  }

  // 移動モード開始（仕様書05：複数選択モードからのみ起動）
  void _startFrameMoveMode() {
    if (_selectedFrameIndices.isEmpty) return;
    final sorted = _selectedFrameIndices.toList()..sort();
    setState(() {
      _isFrameMoveMode = true;
      _frameMoveCursorPos = sorted.last + 1;
    });
    final sceneId = _selectedSceneId;
    if (sceneId != null) _loadMoveThumbnail(sceneId, frameIndex: sorted.first);
  }

  // カーソル固定方式の移動確定（仕様書05：複数選択モードからのみ起動）
  void _confirmFrameMove() {
    if (_selectedFrameIndices.isEmpty) return;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final total = _totalFrames;
    final moving = _selectedFrameIndices.toList()..sort();
    final removedBefore = moving.where((i) => i < _frameMoveCursorPos).length;
    final insertPos = (_frameMoveCursorPos - removedBefore).clamp(0, total - moving.length);
    final remaining = [for (int i = 0; i < total; i++) if (!_selectedFrameIndices.contains(i)) i];
    final newOrder = List<int>.from(remaining)..insertAll(insertPos, moving);
    context.read<ProjectService>().reorderFrames(widget.projectId, sceneId, newOrder);
    setState(() {
      _isFrameMoveMode = false;
      _isFrameMultiSelect = false;
      _selectedFrameIndices.clear();
      _currentFrame = _currentFrame.clamp(0, _totalFrames - 1);
    });
  }

  Widget _buildTrackLabel(IconData icon, String label) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Flexible(child: Text(label,
              style: TextStyle(fontSize: 9, fontFamily: 'Kuramubon', color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// 素材種別（画像・動画・音源）ごとのタイムライン行グループ（仕様書05）。
  /// 行数・行名はシーンごとにProjectServiceで管理する。1行目の右端＋は
  /// 「行の追加」用（素材自体の追加は既に上部ツールバーのボタンで行える
  /// ため、この＋は行追加に転用した）。2行目以降は－で行削除ができる。
  /// 素材種別（動画・音声）のトラック行グループ。1件も素材がなければ
  /// グループごと非表示にし（仕様書05：デフォルトはプレビュー・フレーム
  /// 一覧のみ）、中身のある行だけを表示する。同じタイミングで重ねたい
  /// 素材がある場合のみ、最後尾の行の＋で新しい行を追加できる。
  Widget _buildMaterialTrackGroup({
    required MaterialType type,
    required IconData icon,
    required String defaultLabel,
    required List<_TrackClip> allClips,
    required Color addColor,
  }) {
    if (allClips.isEmpty) return const SizedBox.shrink();
    final sceneId = _selectedSceneId;
    final rowNames = sceneId == null
        ? const <String?>[null]
        : context.watch<ProjectService>().rowNamesOf(widget.projectId, sceneId, type);
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
            rowLabel: rowNames[row] ?? '$defaultLabel${row + 1}',
            icon: icon,
            clips: allClips.where((c) => c.trackRow == row).toList(),
            scrollCtrl: _rowScrollCtrl(type, row),
            addColor: addColor,
            showAddButton: row == lastRow,
          ),
      ],
    );
  }

  Widget _buildClipTrackRow({
    required MaterialType type,
    required int rowIndex,
    required String rowLabel,
    required IconData icon,
    required List<_TrackClip> clips,
    required ScrollController scrollCtrl,
    required Color addColor,
    required bool showAddButton,
  }) {
    final total = _totalFrames;
    return Container(
      height: 32,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          // 行名タップで名称変更（仕様書05：「タイムライン左側の素材種別名は
          // タップでユーザーがテキスト変更できる」）。種別を示すアイコン自体は
          // 変更不可のまま常時表示する。
          GestureDetector(
            onTap: () => _showRenameTrackRowDialog(type, rowIndex, rowLabel),
            child: _buildTrackLabel(icon, rowLabel),
          ),
          Expanded(
            child: Stack(
              children: [
                // 背景グリッド（フレーム幅に合わせた縦線）
                ListView.builder(
                  controller: scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: total,
                  itemBuilder: (_, i) => Container(
                    width: _cellW,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
                    ),
                  ),
                ),
                // クリップ描画
                ...clips.map((clip) => _buildClipWidget(clip, scrollCtrl)),
                // 表示中の最後尾の行にのみ＋を出し、同じタイミングで重ねたい
                // 素材がある時だけ新しい行を追加できるようにする。行の削除は
                // 個々のクリップを消せば自動で畳まれるため、専用ボタンは持たない。
                if (showAddButton)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: GestureDetector(
                      onTap: () => _addTrackRow(type),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: addColor.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addTrackRow(MaterialType type) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    context.read<ProjectService>().addTrackRow(widget.projectId, sceneId, type);
  }

  void _showRenameTrackRowDialog(MaterialType type, int rowIndex, String currentLabel) {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final ctrl = TextEditingController(text: currentLabel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineTrackRowRenameTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>()
                  .renameTrackRow(widget.projectId, sceneId, type, rowIndex, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then((_) => WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose()));
  }

  Widget _buildClipWidget(_TrackClip clip, ScrollController scrollCtrl) {
    return AnimatedBuilder(
      animation: scrollCtrl,
      builder: (ctx, child) {
        final scrollOffset = scrollCtrl.hasClients ? scrollCtrl.offset : 0.0;
        final left = clip.startFrame * _cellW - scrollOffset;
        final width = clip.lengthFrames * _cellW - _frameMargin * 2;
        final isDragging = _draggingClipId == clip.id;
        // ドラッグ中のクリップは画面外カリングの対象から外す。カリングで
        // ウィジェット自体が消えるとポインターを掴んでいたRenderObjectが
        // 失われ、ジェスチャーが途中で切れてしまうため。
        if (!isDragging &&
            (left + width < 0 || left > MediaQuery.of(context).size.width)) {
          return const SizedBox.shrink();
        }
        const handleW = 8.0;
        return Positioned(
          left: left.clamp(0.0, double.infinity),
          top: 3,
          width: width.clamp(handleW * 2 + 4, double.infinity),
          height: 26,
          child: GestureDetector(
            onTap: () => _showEditClipDialog(clip),
            // 長押しドラッグでクリップ本体を移動＝表示開始位置を変更する
            // （仕様書05：「開始フレーム変更：タイムライン上で表示開始
            // 位置を変更」、タスク#99）。
            onLongPressStart: (d) => _beginClipDrag(clip, _ClipDragMode.move, d.globalPosition.dx),
            onLongPressMoveUpdate: (d) => _updateClipDrag(clip, d.globalPosition.dx),
            onLongPressEnd: (_) => _endClipDrag(clip),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: clip.color.withValues(alpha: isDragging ? 1.0 : 0.85),
                      borderRadius: BorderRadius.circular(3),
                      border: isDragging ? Border.all(color: Colors.white, width: 1.5) : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      clip.label,
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontFamily: 'Kuramubon'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 左右端のドラッグハンドル：表示範囲（長さ）を変更する
                // （仕様書05：「使用範囲変更：タイムライン上でドラッグ
                // ハンドルにより変更」、タスク#99）。
                _buildClipResizeHandle(clip, handleW, isLeft: true),
                _buildClipResizeHandle(clip, handleW, isLeft: false),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClipResizeHandle(_TrackClip clip, double handleW, {required bool isLeft}) {
    final mode = isLeft ? _ClipDragMode.resizeLeft : _ClipDragMode.resizeRight;
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: handleW,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _beginClipDrag(clip, mode, d.globalPosition.dx),
        onHorizontalDragUpdate: (d) => _updateClipDrag(clip, d.globalPosition.dx),
        onHorizontalDragEnd: (_) => _endClipDrag(clip),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
    );
  }

  void _beginClipDrag(_TrackClip clip, _ClipDragMode mode, double globalX) {
    setState(() {
      _draggingClipId = clip.id;
      _clipDragMode = mode;
      _clipDragStartX = globalX;
      _clipDragStartFrame = clip.startFrame;
      _clipDragStartLength = clip.lengthFrames;
    });
  }

  void _updateClipDrag(_TrackClip clip, double globalX) {
    if (_draggingClipId != clip.id || _clipDragMode == null) return;
    final deltaFrames = ((globalX - _clipDragStartX) / _cellW).round();
    final total = _totalFrames;
    switch (_clipDragMode!) {
      case _ClipDragMode.move:
        final maxStart = total - _clipDragStartLength;
        final newStart = (_clipDragStartFrame + deltaFrames).clamp(0, maxStart < 0 ? 0 : maxStart);
        if (newStart != clip.startFrame) setState(() => clip.startFrame = newStart);
      case _ClipDragMode.resizeLeft:
        // 右端（startFrame + lengthFrames）を固定し、左端だけ伸縮する。
        final fixedEnd = _clipDragStartFrame + _clipDragStartLength;
        final newStart = (_clipDragStartFrame + deltaFrames).clamp(0, fixedEnd - 1);
        final newLength = fixedEnd - newStart;
        if (newStart != clip.startFrame || newLength != clip.lengthFrames) {
          setState(() {
            clip.startFrame = newStart;
            clip.lengthFrames = newLength;
          });
        }
      case _ClipDragMode.resizeRight:
        final maxLength = total - _clipDragStartFrame;
        final newLength = (_clipDragStartLength + deltaFrames).clamp(1, maxLength < 1 ? 1 : maxLength);
        if (newLength != clip.lengthFrames) setState(() => clip.lengthFrames = newLength);
    }
  }

  void _endClipDrag(_TrackClip clip) {
    if (_draggingClipId != clip.id) return;
    setState(() {
      _draggingClipId = null;
      _clipDragMode = null;
    });
    final sceneId = _selectedSceneId;
    if (sceneId != null) _persistClipUpdate(clip, sceneId);
  }

  /// シーン・フレームの複数選択モード中の一括操作バー（仕様書05）。
  /// 素材タイムラインの上に大きな3分割ボタン（移動・複製・削除）＋
  /// 次の段に全選択・全解除を表示する。移動モード中は専用のカーソルUIが
  /// 別途表示されるためここでは非表示にする。
  Widget _buildMultiSelectActionBar() {
    if (!_isSceneMultiSelect && !_isFrameMultiSelect) return const SizedBox.shrink();
    if (_isMoveMode || _isFrameMoveMode) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final isScene = _isSceneMultiSelect;
    final projectService = context.watch<ProjectService>();
    final scenes = projectService.scenesOf(widget.projectId);
    final total = _totalFrames;

    final selectedCount = isScene ? _selectedSceneIds.length : _selectedFrameIndices.length;
    final canMove = selectedCount > 0;
    final canDuplicate = selectedCount > 0;
    final canDelete = isScene
        ? (selectedCount > 0 && selectedCount < scenes.length)
        : (selectedCount > 0 && selectedCount < total);

    void onMove() => isScene ? _startMoveMode(scenes) : _startFrameMoveMode();
    void onDuplicate() => isScene ? _duplicateSelectedScenes(scenes) : _duplicateSelectedFrames();
    void onDelete() => isScene ? _showMultiDeleteConfirm() : _deleteSelectedFrames();
    void onSelectAll() => setState(() {
          if (isScene) {
            _selectedSceneIds.addAll(scenes.map((s) => s.id));
          } else {
            _selectedFrameIndices.addAll(List.generate(total, (i) => i));
          }
        });
    void onDeselectAll() => setState(() {
          if (isScene) {
            _selectedSceneIds.clear();
            _isSceneMultiSelect = false;
          } else {
            _selectedFrameIndices.clear();
            _isFrameMultiSelect = false;
          }
        });

    Widget bigButton(String label, VoidCallback? onTap, {Color? color}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              foregroundColor: color,
            ),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border.symmetric(horizontal: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              bigButton(l10n.commonMove, canMove ? onMove : null),
              bigButton(l10n.themeDuplicateAction, canDuplicate ? onDuplicate : null),
              bigButton(l10n.commonDelete, canDelete ? onDelete : null, color: Colors.red),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              bigButton(l10n.layerPanelSelectAll, onSelectAll),
              bigButton(l10n.layerPanelDeselectAll, onDeselectAll),
            ],
          ),
        ],
      ),
    );
  }

  /// 共通レイヤー専用トラック（仕様書05・16）。共通レイヤーは通常レイヤーとは
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
                SizedBox(
                  height: 32,
                  child: _buildTrackLabel(
                    r.layer.type == LayerType.watermark ? Icons.branding_watermark : Icons.link,
                    r.layer.name,
                  ),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _commonLayerScrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: total * _cellW,
                child: Column(
                  children: [
                    for (final r in rows)
                      SizedBox(
                        height: 32,
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                for (int i = 0; i < total; i++)
                                  Container(
                                    width: _cellW,
                                    decoration: BoxDecoration(
                                      border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
                                    ),
                                  ),
                              ],
                            ),
                            _buildCommonLayerBar(r.layer, r.home, r.start, r.end, total),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 共通レイヤーの表示範囲バー。シングルタップで表示範囲設定ダイアログを開き、
  /// 左右のドラッグハンドルで開始・終了フレームを直接変更できる（仕様書16：
  /// 「タイムライン上では左右のドラッグハンドルでも表示範囲を変更できる」）。
  Widget _buildCommonLayerBar(Layer layer, LayerHome home, int start, int end, int total) {
    final left = start * _cellW + _frameMargin;
    final width = (end - start + 1) * _cellW - _frameMargin * 2;

    void applyDrag(int newStart, int newEnd) {
      newStart = newStart.clamp(0, total - 1);
      newEnd = newEnd.clamp(newStart, total - 1);
      context.read<ProjectService>().updateLayer(
            projectId: widget.projectId,
            sceneId: home.sceneId,
            frameIndex: home.frameIndex,
            layer: layer.copyWith(
              rangeMode: LayerRangeMode.frameRange,
              rangeStart: newStart + 1,
              rangeEnd: newEnd + 1,
              rangeSceneId: null,
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
            ? _showWatermarkEditDialog(layer, home)
            : _showCommonLayerRangeDialog(layer, home),
        child: Container(
          decoration: BoxDecoration(
            color: (layer.type == LayerType.watermark ? Colors.pink : Colors.blue).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: layer.type == LayerType.watermark ? Colors.pink[200]! : Colors.blue[200]!,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    layer.name,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontFamily: 'Kuramubon'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // 左ドラッグハンドル：開始フレームを変更
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _commonDragAccumPx = 0,
                  onHorizontalDragUpdate: (details) {
                    _commonDragAccumPx += details.delta.dx;
                    final frameDelta = (_commonDragAccumPx / _cellW).truncate();
                    if (frameDelta == 0) return;
                    _commonDragAccumPx -= frameDelta * _cellW;
                    applyDrag(start + frameDelta, end);
                  },
                  child: Container(width: 8, color: Colors.white24,
                      child: const Icon(Icons.drag_indicator, size: 8, color: Colors.white70)),
                ),
              ),
              // 右ドラッグハンドル：終了フレームを変更
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _commonDragAccumPx = 0,
                  onHorizontalDragUpdate: (details) {
                    _commonDragAccumPx += details.delta.dx;
                    final frameDelta = (_commonDragAccumPx / _cellW).truncate();
                    if (frameDelta == 0) return;
                    _commonDragAccumPx -= frameDelta * _cellW;
                    applyDrag(start, end + frameDelta);
                  },
                  child: Container(width: 8, color: Colors.white24,
                      child: const Icon(Icons.drag_indicator, size: 8, color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 共通レイヤーの表示範囲設定ダイアログ（仕様書16「三点メニュー（共通レイヤー専用）」
  /// の「表示フレーム範囲変更」と同一内容。レイヤーパネル側の同名ダイアログとUIを揃える）。
  void _showCommonLayerRangeDialog(Layer layer, LayerHome home) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final totalFrames = ps.frameCount(widget.projectId, home.sceneId);
    final scenes = ps.scenesOf(widget.projectId);
    final startCtrl = TextEditingController(text: (layer.rangeStart ?? 1).toString());
    final endCtrl = TextEditingController(
        text: (layer.rangeEnd ?? (totalFrames > 0 ? totalFrames : 1)).toString());
    LayerRangeMode mode = layer.rangeMode;
    String? rangeSceneId = layer.rangeSceneId ?? home.sceneId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelRangeDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.layerPanelRangeStartFrameLabel, border: const OutlineInputBorder()),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(l10n.layerPanelRangeTilde)),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.layerPanelRangeEndFrameLabel, border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                RadioListTile<LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeAllFrames),
                  value: LayerRangeMode.allFrames,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                RadioListTile<LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeCurrentScene),
                  value: LayerRangeMode.currentScene,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                RadioListTile<LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.timelineRangeSceneFixed),
                  value: LayerRangeMode.sceneRange,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                if (mode == LayerRangeMode.sceneRange)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: scenes.any((s) => s.id == rangeSceneId) ? rangeSceneId : scenes.firstOrNull?.id,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.layerPanelRangeTargetSceneLabel, isDense: true),
                      items: scenes
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                          .toList(),
                      onChanged: (v) => setS(() => rangeSceneId = v),
                    ),
                  ),
                RadioListTile<LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeFrameRangeLabel),
                  value: LayerRangeMode.frameRange,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                final start = int.tryParse(startCtrl.text) ?? 1;
                final end = int.tryParse(endCtrl.text) ?? start;
                final resolvedSceneId = mode == LayerRangeMode.sceneRange ? rangeSceneId : null;
                ps.updateLayer(
                  projectId: widget.projectId,
                  sceneId: home.sceneId,
                  frameIndex: home.frameIndex,
                  layer: layer.copyWith(
                    rangeMode: mode,
                    rangeStart: start,
                    rangeEnd: end,
                    rangeSceneId: resolvedSceneId,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    ).then((_) {
      startCtrl.dispose();
      endCtrl.dispose();
    });
  }

  /// ウォーターマークの角度・大きさ・不透明度・表示範囲（ループ表示）を
  /// まとめて編集するダイアログ。タイムラインの共通レイヤートラックで
  /// ウォーターマークをタップすると開く。登録時だけでなく実際に
  /// プロジェクト内で使うときにいつでも変更できるようにしている。
  void _showWatermarkEditDialog(Layer layer, LayerHome home) {
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
          title: Text(l10n.timelineWatermarkEditTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.timelineWatermarkAngleLabel, style: const TextStyle(fontSize: 12)),
                Row(
                  children: [
                    Expanded(
                      child: SteppedSlider(
                        value: angle,
                        min: -180, max: 180,
                        label: '${angle.round()}°',
                        onChanged: (v) => setS(() => angle = v),
                      ),
                    ),
                    EditableSliderValue(
                      text: '${angle.round()}°',
                      style: const TextStyle(fontSize: 12),
                      value: angle, min: -180, max: 180,
                      onChanged: (v) => setS(() => angle = v.toDouble()),
                    ),
                  ],
                ),
                Text(l10n.timelineWatermarkSizeLabel, style: const TextStyle(fontSize: 12)),
                Row(
                  children: [
                    Expanded(
                      child: SteppedSlider(
                        value: scale,
                        min: 0.05, max: 1.0, step: 0.01,
                        label: '${(scale * 100).round()}%',
                        onChanged: (v) => setS(() => scale = v),
                      ),
                    ),
                    EditableSliderValue(
                      text: '${(scale * 100).round()}%',
                      style: const TextStyle(fontSize: 12),
                      value: (scale * 100).round(), min: 5, max: 100,
                      onChanged: (v) => setS(() => scale = v / 100),
                    ),
                  ],
                ),
                Text(l10n.timelineWatermarkOpacityLabel, style: const TextStyle(fontSize: 12)),
                Row(
                  children: [
                    Expanded(
                      child: SteppedSlider(
                        value: opacity,
                        min: 0, max: 1.0, step: 0.01,
                        label: '${(opacity * 100).round()}%',
                        onChanged: (v) => setS(() => opacity = v),
                      ),
                    ),
                    EditableSliderValue(
                      text: '${(opacity * 100).round()}%',
                      style: const TextStyle(fontSize: 12),
                      value: (opacity * 100).round(), min: 0, max: 100,
                      onChanged: (v) => setS(() => opacity = v / 100),
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.timelineWatermarkLoopLabel),
                  subtitle: Text(l10n.timelineWatermarkLoopSubtitle, style: const TextStyle(fontSize: 11)),
                  value: loop,
                  onChanged: (v) => setS(() => loop = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _reRasterizeWatermark(layer, home, angle: angle, scale: scale);
                if (!mounted) return;
                ps.updateLayer(
                  projectId: widget.projectId,
                  sceneId: home.sceneId,
                  frameIndex: home.frameIndex,
                  layer: layer.copyWith(
                    watermarkAngle: angle,
                    watermarkScale: scale,
                    opacity: (opacity * 100).round(),
                    rangeMode: loop ? LayerRangeMode.allFrames : LayerRangeMode.currentScene,
                  ),
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
        : context.watch<ProjectService>().cameraKeyframesOf(widget.projectId, sceneId);
    // キーフレームが1件もない間は非表示にする（仕様書05）。最初の1件は
    // ツールバーのカメラアイコンから追加できる。
    if (cameraKfs.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 32,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          _buildTrackLabel(Icons.camera_alt, l10n.timelineCameraTrackLabel),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _cameraScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: total,
                  itemBuilder: (_, i) => Container(
                    width: _cellW,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
                    ),
                  ),
                ),
                // キーフレームマーカー
                ...cameraKfs.map((kf) => _buildCameraKfMarker(kf)),
                // ＋ボタン
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => _addCameraKf(),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.purple[700]!.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraKfMarker(CameraKeyframe kf) {
    return AnimatedBuilder(
      animation: _cameraScrollCtrl,
      builder: (ctx, child) {
        final scrollOffset = _cameraScrollCtrl.hasClients ? _cameraScrollCtrl.offset : 0.0;
        final isDragging = _draggingCameraKfOriginalFrame == kf.frameIndex;
        final displayFrame = isDragging ? (_draggingCameraKfLiveFrame ?? kf.frameIndex) : kf.frameIndex;
        final cx = displayFrame * _cellW + _cellW / 2 - scrollOffset;
        return Positioned(
          left: cx - 7,
          top: 9,
          child: GestureDetector(
            onTap: () => _showEditCameraKfDialog(kf),
            // ドラッグでキーフレーム位置（フレーム）を変更する（仕様書05：
            // 「カメラ：XY移動・拡大・回転・キーフレーム」、タスク#100）。
            onHorizontalDragStart: (d) => _beginCameraKfDrag(kf, d.globalPosition.dx),
            onHorizontalDragUpdate: (d) => _updateCameraKfDrag(d.globalPosition.dx),
            onHorizontalDragEnd: (_) => _endCameraKfDrag(kf),
            child: Transform.rotate(
              angle: 0.785, // 45°
              child: Container(
                width: isDragging ? 18 : 14,
                height: isDragging ? 18 : 14,
                decoration: BoxDecoration(
                  color: Colors.purple[400],
                  border: Border.all(color: Colors.white, width: isDragging ? 2 : 1.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _beginCameraKfDrag(CameraKeyframe kf, double globalX) {
    setState(() {
      _draggingCameraKfOriginalFrame = kf.frameIndex;
      _draggingCameraKfLiveFrame = kf.frameIndex;
      _cameraKfDragStartX = globalX;
      _cameraKfDragStartFrame = kf.frameIndex;
    });
  }

  void _updateCameraKfDrag(double globalX) {
    if (_draggingCameraKfOriginalFrame == null) return;
    final total = _totalFrames;
    final deltaFrames = ((globalX - _cameraKfDragStartX) / _cellW).round();
    final newFrame = (_cameraKfDragStartFrame + deltaFrames).clamp(0, total > 0 ? total - 1 : 0);
    if (newFrame != _draggingCameraKfLiveFrame) {
      setState(() => _draggingCameraKfLiveFrame = newFrame);
    }
  }

  void _endCameraKfDrag(CameraKeyframe kf) {
    final originalFrame = _draggingCameraKfOriginalFrame;
    final liveFrame = _draggingCameraKfLiveFrame;
    setState(() {
      _draggingCameraKfOriginalFrame = null;
      _draggingCameraKfLiveFrame = null;
    });
    final sceneId = _selectedSceneId;
    if (sceneId == null || originalFrame == null || liveFrame == null || liveFrame == originalFrame) {
      return;
    }
    context.read<ProjectService>().updateCameraKeyframe(
          widget.projectId,
          sceneId,
          originalFrame,
          kf.copyWith(frameIndex: liveFrame),
        );
  }

  /// タイムスタンプ用トラック（特定フレームへワンタップで移動できるマーカー
  /// ＋コメント）。カメラキーフレームのトラックと見た目・スクロール連動の
  /// 仕組みは共通だが、役割が異なる：カメラキーフレームは「値の補間」用、
  /// こちらは「その瞬間の記録・移動」用のため、タップの意味も
  /// （カメラ＝編集ダイアログを開く、こちら＝その場へジャンプする）で
  /// あえて分けている。編集・削除は長押しから行う。
  Widget _buildMarkerTrack() {
    final l10n = AppLocalizations.of(context)!;
    final total = _totalFrames;
    final sceneId = _selectedSceneId;
    final markers = sceneId == null
        ? const <TimelineMarker>[]
        : context.watch<ProjectService>().timelineMarkersOf(widget.projectId, sceneId);
    // タイムスタンプが1件もない間は非表示にする（仕様書05）。最初の1件は
    // ツールバーのタイムスタンプアイコンから追加できる。
    if (markers.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 32,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          _buildTrackLabel(Icons.push_pin_outlined, l10n.timelineMarkerTrackLabel),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _markerScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: total,
                  itemBuilder: (_, i) => Container(
                    width: _cellW,
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
                    ),
                  ),
                ),
                ...markers.map((m) => _buildMarkerPin(m)),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => _showAddMarkerDialog(),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.teal[700]!.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerPin(TimelineMarker m) {
    return AnimatedBuilder(
      animation: _markerScrollCtrl,
      builder: (ctx, child) {
        final scrollOffset = _markerScrollCtrl.hasClients ? _markerScrollCtrl.offset : 0.0;
        final cx = m.frameIndex * _cellW + _cellW / 2 - scrollOffset;
        return Positioned(
          left: cx - 7,
          top: 9,
          child: GestureDetector(
            // タップ一発でその場所へジャンプする（タイムスタンプの主目的）。
            onTap: () => setState(() => _currentFrame = m.frameIndex),
            onLongPress: () => _showEditMarkerDialog(m),
            child: Tooltip(
              message: m.comment.isEmpty ? 'F${m.frameIndex + 1}' : m.comment,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.teal[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddMarkerDialog() {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineMarkerAddDialogTitle(_currentFrame + 1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.timelineMarkerCommentHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().addTimelineMarker(widget.projectId, sceneId, _currentFrame, ctrl.text);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showEditMarkerDialog(TimelineMarker m) {
    final l10n = AppLocalizations.of(context)!;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final ctrl = TextEditingController(text: m.comment);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineMarkerEditDialogTitle(m.frameIndex + 1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.timelineMarkerCommentHint),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: l10n.commonDelete,
            onPressed: () async {
              if (!await confirmDelete(context)) return;
              if (!mounted) return;
              context.read<ProjectService>().removeTimelineMarker(widget.projectId, sceneId, m.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().updateTimelineMarker(widget.projectId, sceneId, m.copyWith(comment: ctrl.text));
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  /// 演出フィルタートラック（仕様書05・18）。適用中のフィルターが1件も
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
        : context.watch<ProjectService>().effectFiltersOf(widget.projectId, sceneId);
    if (effects.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in effects)
            GestureDetector(
              onTap: _showEffectFilterDialog,
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    _buildTrackLabel(Icons.movie_filter, _EffectFilterSheet._typeLabel(l10n, e.type)),
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _effectFilterScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            itemCount: total,
                            itemBuilder: (_, i) => Container(
                              width: _cellW,
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _effectFilterScrollCtrl,
                            builder: (ctx, child) {
                              final scrollOffset =
                                  _effectFilterScrollCtrl.hasClients ? _effectFilterScrollCtrl.offset : 0.0;
                              final left = e.startFrame * _cellW - scrollOffset;
                              final width = (e.endFrame - e.startFrame + 1) * _cellW;
                              return Positioned(
                                left: left,
                                top: 6,
                                child: Container(
                                  width: width,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.pink[400]!.withValues(alpha: e.enabled ? 0.8 : 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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

  /// エンドカードトラック。エンドカードは差し替え不可・アプリが無料会員に
  /// 強制表示するロゴで、無料会員はタップした瞬間にプレミアム誘導のみ
  /// （それ以外の操作は一切できない）。プレミアム会員は削除（非表示）
  /// できるだけで、差し替えや長さ変更はできない。「プレミアム会員は
  /// デフォルトで削除する」設定（設定画面）がONの場合、この画面を開いた
  /// 時点で最初から非表示になる。
  Widget _buildEndCardTrack() {
    return Consumer2<PremiumService, SettingsService>(
      builder: (context, premium, settings, _) {
        final l10n = AppLocalizations.of(context)!;
        final defaultHidden = premium.isPremium && settings.endCardDefaultHiddenForPremium;
        final hidden = _endCardManuallyDeleted || defaultHidden;
        return GestureDetector(
          // 無料会員：トラックのどこをタップしてもプレミアム誘導へ（仕様：
          // 「一切操作できずタップした瞬間に有料会員へ誘導される」）。
          onTap: premium.isPremium ? null : () => showPremiumBanner(context),
          child: Container(
            height: 32,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.movie, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(l10n.timelineEndCardTrackLabel, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                if (!premium.isPremium)
                  const Icon(Icons.lock, size: 14, color: Colors.amber)
                else ...[
                  const Spacer(),
                  Text(
                    hidden ? l10n.timelineEndCardHiddenLabel : l10n.timelineEndCardDefaultLogoLabel,
                    style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  if (!hidden)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                      onPressed: () async {
                        if (!await confirmDelete(context)) return;
                        setState(() => _endCardManuallyDeleted = true);
                      },
                      tooltip: l10n.commonDelete,
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
    final ps = context.read<ProjectService>();
    final existing = ps.cameraKeyframesOf(widget.projectId, sceneId);
    if (existing.any((k) => k.frameIndex == _currentFrame)) return;
    ps.addCameraKeyframe(widget.projectId, sceneId, CameraKeyframe(frameIndex: _currentFrame));
  }

  void _showEditCameraKfDialog(CameraKeyframe kf) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CameraKfSheet(
        projectId: widget.projectId,
        sceneId: sceneId,
        kf: kf,
        totalFrames: _totalFrames,
        onDelete: (currentFrameIndex) => context
            .read<ProjectService>()
            .removeCameraKeyframe(widget.projectId, sceneId, currentFrameIndex),
        onSave: (oldFrameIndex, newKf) => context
            .read<ProjectService>()
            .updateCameraKeyframe(widget.projectId, sceneId, oldFrameIndex, newKf),
      ),
    );
  }

  Future<void> _showAddClipDialog(String trackName, List<_TrackClip> clips, Color color, _ClipTrackType trackType) async {
    final l10n = AppLocalizations.of(context)!;
    final fileType = switch (trackType) {
      _ClipTrackType.audio => FileType.audio,
      _ClipTrackType.video => FileType.video,
      _ClipTrackType.image => FileType.image,
    };
    final result = await FilePicker.platform.pickFiles(type: fileType);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final pickedSourcePath = result.files.first.path!;
    if (!mounted) return;

    // 素材管理（仕様書21）：プロジェクトのMaterials/フォルダへコピーし
    // MaterialIDで管理する。同一内容のファイルは重複保存しない。
    final materialType = switch (trackType) {
      _ClipTrackType.audio => MaterialType.audio,
      _ClipTrackType.video => MaterialType.video,
      _ClipTrackType.image => MaterialType.image,
    };
    final asset = await context.read<MaterialService>().addMaterial(
          projectId: widget.projectId,
          sourcePath: pickedSourcePath,
          type: materialType,
        );
    if (!mounted) return;
    final pickedPath = await context.read<MaterialService>().pathOf(widget.projectId, asset.id);
    final labelCtrl = TextEditingController(
      text: asset.originalFileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
    int start = _currentFrame;
    int length = 12;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.timelineAddClipDialogTitle(trackName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(labelText: l10n.timelineClipLabelFieldLabel, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l10n.timelineClipStartLabel, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SteppedSlider(
                      value: start.toDouble(),
                      min: 0,
                      max: (_totalFrames - 1).toDouble(),
                      divisions: _totalFrames > 1 ? _totalFrames - 1 : 1,
                      label: 'F${start + 1}',
                      onChanged: (v) => setS(() => start = v.round()),
                    ),
                  ),
                  EditableSliderValue(
                    text: 'F${start + 1}',
                    style: const TextStyle(fontSize: 11),
                    value: start + 1, min: 1, max: _totalFrames,
                    onChanged: (v) => setS(() => start = v.round() - 1),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(l10n.timelineClipLengthLabel, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SteppedSlider(
                      value: length.toDouble(),
                      min: 1,
                      max: _totalFrames.toDouble(),
                      divisions: _totalFrames,
                      label: '${length}F',
                      onChanged: (v) => setS(() => length = v.round()),
                    ),
                  ),
                  EditableSliderValue(
                    text: '${length}F',
                    style: const TextStyle(fontSize: 11),
                    value: length, min: 1, max: _totalFrames,
                    onChanged: (v) => setS(() => length = v.round()),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
    ).then((_) => labelCtrl.dispose());
  }

  // ─── タイムライン素材クリップの永続化（仕様書05・16・21） ───────────────
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
  }) async {
    final projectService = context.read<ProjectService>();

    if (trackType == _ClipTrackType.audio) {
      final id = 'audio_${DateTime.now().microsecondsSinceEpoch}';
      projectService.addAudioClip(widget.projectId, sceneId, AudioClip(
        id: id,
        label: label,
        materialId: asset.id,
        startFrame: startFrame,
        lengthFrames: lengthFrames,
      ));
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
    if (bytes == null || !mounted) return null;

    final layer = projectService.addLayer(
      projectId: widget.projectId,
      sceneId: sceneId,
      frameIndex: _currentFrame,
      type: trackType == _ClipTrackType.video ? LayerType.timelineVideo : LayerType.timelineImage,
      name: label,
    );
    final tileManager = projectService.tileManagerOf(widget.projectId);
    tileManager.replaceLayerPixels(
      projectService.tileKeyFor(widget.projectId, sceneId, _currentFrame, layer.id),
      bytes,
    );
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: sceneId,
      frameIndex: _currentFrame,
      layer: layer.copyWith(
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: startFrame + 1,
        rangeEnd: startFrame + lengthFrames,
        materialId: asset.id,
        sourceTrimStart: trackType == _ClipTrackType.video ? 0 : null,
        sourceTrimEnd: trackType == _ClipTrackType.video ? lengthFrames - 1 : null,
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
    );
  }

  /// 画像ファイルをキャンバスサイズへラスタライズする（中央配置・アスペクト比維持）。
  Future<Uint8List?> _rasterizeImageFile(String filePath, int w, int h) async {
    final fileBytes = await File(filePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(fileBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final scale = (w / image.width < h / image.height) ? w / image.width : h / image.height;
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
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// 動画クリップのレイヤーピクセル代表画像（プレースホルダー）を生成する。
  /// 実際の動画フレームのデコードは行わない（低スペック端末対策・処理の単純化）。
  /// 編集中のライブプレビューはVideoPlayerControllerで別途表示する。
  Future<Uint8List?> _placeholderVideoFrame(int w, int h) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF1A1A1A));
    final iconSize = (w < h ? w : h) * 0.15;
    final cx = w / 2;
    final cy = h / 2;
    final path = ui.Path()
      ..moveTo(cx - iconSize / 2, cy - iconSize / 2)
      ..lineTo(cx - iconSize / 2, cy + iconSize / 2)
      ..lineTo(cx + iconSize / 2, cy)
      ..close();
    canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFF666666));
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    return byteData?.buffer.asUint8List();
  }

  void _deletePersistedClip(_TrackClip clip, String sceneId) {
    final projectService = context.read<ProjectService>();
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
    // 使用中の列だけを表示する方針（仕様書05）：追加専用の行（2行目以降）が
    // 空になったら自動で畳む（構造ごと削除して行番号を詰め直す）。1行目は
    // 常に存在する既定行なので畳まず、中身がなければ表示だけを省く。
    if (clip.trackRow > 0) {
      final remaining = switch (clip.trackType) {
        _ClipTrackType.audio => _audioClips,
        _ClipTrackType.video => _videoClips,
        _ClipTrackType.image => _imageClips,
      };
      final stillUsed = remaining.any((c) => c.trackRow == clip.trackRow);
      if (!stillUsed) {
        final materialType = switch (clip.trackType) {
          _ClipTrackType.audio => MaterialType.audio,
          _ClipTrackType.video => MaterialType.video,
          _ClipTrackType.image => MaterialType.image,
        };
        projectService.removeTrackRow(widget.projectId, sceneId, materialType, clip.trackRow);
      }
    }
  }

  /// 素材クリップ（画像・動画・音声）を複製し、元クリップの直後へ配置する。
  /// 音声はAudioClipとして、画像・動画は元レイヤーのピクセルデータを
  /// 新規レイヤーへコピーした上で表示範囲を複製先の位置へずらして追加する。
  Future<void> _duplicateClip(_TrackClip clip) async {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final projectService = context.read<ProjectService>();
    final maxStart = (_totalFrames - clip.lengthFrames).clamp(0, 1 << 30);
    final newStart = (clip.startFrame + clip.lengthFrames).clamp(0, maxStart);

    if (clip.trackType == _ClipTrackType.audio) {
      final id = 'audio_${DateTime.now().microsecondsSinceEpoch}';
      projectService.addAudioClip(widget.projectId, sceneId, AudioClip(
        id: id,
        label: clip.label,
        materialId: clip.materialId,
        startFrame: newStart,
        lengthFrames: clip.lengthFrames,
        volume: clip.volume,
        fadeIn: clip.fadeIn,
        fadeOut: clip.fadeOut,
        trackRow: clip.trackRow,
      ));
      if (mounted) {
        setState(() => _audioClips.add(_TrackClip(
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
          useEnd: clip.lengthFrames - 1,
          trackRow: clip.trackRow,
        )));
      }
      return;
    }

    final home = projectService.homeOf(widget.projectId, clip.id) ??
        (sceneId: sceneId, frameIndex: _currentFrame);
    final sourceLayer = projectService
        .layersOf(widget.projectId, home.sceneId, home.frameIndex)
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
    projectService.tileManagerOf(widget.projectId).copyLayer(
      projectService.tileKeyFor(widget.projectId, home.sceneId, home.frameIndex, clip.id),
      projectService.tileKeyFor(widget.projectId, home.sceneId, home.frameIndex, newLayer.id),
    );
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: home.sceneId,
      frameIndex: home.frameIndex,
      layer: newLayer.copyWith(
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: newStart + 1,
        rangeEnd: newStart + clip.lengthFrames,
        materialId: clip.materialId,
        opacity: (clip.videoOpacity * 100).round(),
        sourceTrimStart: clip.trackType == _ClipTrackType.video ? clip.useStart : null,
        sourceTrimEnd: clip.trackType == _ClipTrackType.video ? clip.useEnd : null,
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
      videoOpacity: clip.videoOpacity,
      trackRow: clip.trackRow,
    );
    setState(() {
      if (clip.trackType == _ClipTrackType.video) {
        _videoClips.add(newClip);
      } else {
        _imageClips.add(newClip);
      }
    });
  }

  /// クリップ詳細シートを閉じた時点で、編集内容（音量・フェード・不透明度・
  /// 使用範囲）をまとめて永続化する（スライダー操作のたびに保存すると低スペック
  /// 端末で負荷が高いため、シートを閉じた時点でまとめて反映する）。
  void _persistClipUpdate(_TrackClip clip, String sceneId) {
    final stillExists = _audioClips.contains(clip) ||
        _videoClips.contains(clip) ||
        _imageClips.contains(clip);
    if (!stillExists) return; // 削除済みなら何もしない
    final projectService = context.read<ProjectService>();
    if (clip.trackType == _ClipTrackType.audio) {
      projectService.updateAudioClip(widget.projectId, sceneId, AudioClip(
        id: clip.id,
        label: clip.label,
        materialId: clip.materialId,
        startFrame: clip.startFrame,
        lengthFrames: clip.lengthFrames,
        volume: clip.volume,
        fadeIn: clip.fadeIn,
        fadeOut: clip.fadeOut,
      ));
    } else {
      // レイヤーの実データが物理的に存在する「ホーム」フレームを使う
      // （表示範囲を持つレイヤーは_currentFrameが範囲外の場合があるため）。
      final home = projectService.homeOf(widget.projectId, clip.id) ??
          (sceneId: sceneId, frameIndex: _currentFrame);
      final layer = projectService
          .layersOf(widget.projectId, home.sceneId, home.frameIndex)
          .where((l) => l.id == clip.id)
          .firstOrNull;
      if (layer == null) return;
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: home.sceneId,
        frameIndex: home.frameIndex,
        layer: layer.copyWith(
          opacity: (clip.videoOpacity * 100).round(),
          sourceTrimStart: clip.useStart,
          sourceTrimEnd: clip.useEnd,
          // 表示開始位置・使用範囲（タイムライン上のドラッグ移動・
          // ハンドルによるリサイズ、タスク#99）。従来はここが抜けており、
          // ドラッグ操作で見た目上は移動・リサイズできても実際には
          // 永続化されない不具合があった。
          rangeStart: clip.startFrame + 1,
          rangeEnd: clip.startFrame + clip.lengthFrames,
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
      audio.add(_TrackClip(
        id: a.id,
        label: a.label,
        startFrame: a.startFrame,
        lengthFrames: a.lengthFrames,
        color: Colors.orange[700]!,
        trackType: _ClipTrackType.audio,
        filePath: path,
        materialId: a.materialId,
        volume: a.volume,
        fadeIn: a.fadeIn,
        fadeOut: a.fadeOut,
        useEnd: a.lengthFrames - 1,
        trackRow: a.trackRow,
      ));
    }

    final video = <_TrackClip>[];
    final image = <_TrackClip>[];
    for (final frame in scene.frames) {
      for (final layer in frame.layers) {
        if (layer.type != LayerType.timelineVideo && layer.type != LayerType.timelineImage) continue;
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
          color: layer.type == LayerType.timelineVideo ? Colors.blue[700]! : Colors.green[700]!,
          trackType: layer.type == LayerType.timelineVideo ? _ClipTrackType.video : _ClipTrackType.image,
          filePath: path,
          materialId: layer.materialId,
          useStart: layer.sourceTrimStart ?? 0,
          useEnd: layer.sourceTrimEnd ?? (length - 1),
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

    if (!mounted) return;
    setState(() {
      _audioClips..clear()..addAll(audio);
      _videoClips..clear()..addAll(video);
      _imageClips..clear()..addAll(image);
    });
  }

  void _showEditClipDialog(_TrackClip clip) {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ClipDetailSheet(
        clip: clip,
        totalFrames: _totalFrames,
        onDelete: () {
          setState(() {
            _audioClips.remove(clip);
            _videoClips.remove(clip);
            _imageClips.remove(clip);
          });
          _deletePersistedClip(clip, sceneId);
        },
        onDuplicate: () => _duplicateClip(clip),
        onChanged: () => setState(() {}),
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
    if (mounted) context.go('/canvas/${widget.projectId}');
  }

  Future<void> _showSaveFailedDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineSaveFailedDialogTitle),
        content: Text(l10n.timelineSaveFailedDialogBody),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonOk)),
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
        title: Text(l10n.timelineBackToProjectListDialogTitle),
        content: Text(l10n.timelineBackToProjectListDialogBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(l10n.timelineBackToProjectListDiscardButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l10n.timelineBackToProjectListSaveButton),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'save') {
      // 保存に失敗した場合は一覧へ戻らず、その場でエラーを知らせる
      // （セーブされていないデータが気づかれないまま消えるのを防ぐ）。
      try {
        await context.read<ProjectService>().saveProject(widget.projectId);
      } catch (e) {
        debugPrint('timeline: saveProject failed before returning to project list: $e');
        if (mounted) await _showSaveFailedDialog();
        return;
      }
    }
    if (mounted) context.go('/home');
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
    final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
    final fps = project?.fps ?? 24;
    int frames = ps.frameCount(widget.projectId, sceneId).clamp(1, 1 << 30);
    const maxFrames = 7200 * 60; // プレミアム上限2時間相当を目安にした上限
    final framesController = TextEditingController(text: '$frames');
    final secondsController =
        TextEditingController(text: (frames / fps).toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.timelineDurationChangeMenuItem),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SteppedSlider(
                value: frames.toDouble(),
                min: 1,
                max: maxFrames.toDouble(),
                onChanged: (v) => setS(() {
                  frames = v.round();
                  framesController.text = '$frames';
                  secondsController.text = (frames / fps).toStringAsFixed(1);
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: framesController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(isDense: true, labelText: l10n.timelineDurationFramesLabel),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed == null) return;
                        setS(() {
                          frames = parsed.clamp(1, maxFrames);
                          secondsController.text = (frames / fps).toStringAsFixed(1);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: secondsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(isDense: true, labelText: l10n.timelineDurationSecondsLabel),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed == null) return;
                        setS(() {
                          frames = (parsed * fps).round().clamp(1, maxFrames);
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                ps.setSceneFrameCount(widget.projectId, sceneId, frames);
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    ).then((_) {
      framesController.dispose();
      secondsController.dispose();
    });
  }

  /// キャンバスサイズ変更ダイアログ（タイムライン三点メニュー）。現在の
  /// フレームのプレビュー上に、新しいキャンバスサイズに対応する矩形を
  /// 重ねて表示し、指でドラッグして切り出し位置を直感的に調整できる
  /// ようにする（幅・高さ自体は下のスライダー・数値入力で指定する）。
  void _showCanvasSizeChangeDialog() {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
    if (project == null) return;
    final oldW = project.drawingWidth;
    final oldH = project.drawingHeight;
    int newW = oldW;
    int newH = oldH;
    // 既定は中央寄せ（サイズを変えなければcropX/Y=0で全域そのまま）。
    int cropX = 0;
    int cropY = 0;
    const maxEdge = 4096;
    const previewBoxSize = 260.0;

    void clampCrop() {
      cropX = cropX.clamp(0, (oldW - newW).clamp(0, 1 << 30));
      cropY = cropY.clamp(0, (oldH - newH).clamp(0, 1 << 30));
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final scale = previewBoxSize / (oldW > oldH ? oldW : oldH);
          final boxW = oldW * scale;
          final boxH = oldH * scale;
          return AlertDialog(
            title: Text(l10n.timelineCanvasSizeChangeMenuItem),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.timelineCanvasSizeDragHint,
                      style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  // プレビュー：実際のフレーム内容の上に、新サイズの範囲を
                  // 示す枠を重ねてドラッグで移動できるようにする。
                  SizedBox(
                    width: boxW,
                    height: boxH,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _TimelinePreview(
                            tileManager: ps.tileManagerOf(widget.projectId),
                            layers: ps.layersOf(widget.projectId, sceneId, _currentFrame),
                            sceneId: sceneId,
                            frameIndex: _currentFrame,
                            cameraKeyframes: ps.cameraKeyframesOf(widget.projectId, sceneId),
                            effectFilters: ps.effectFiltersOf(widget.projectId, sceneId),
                            layerHomes: ps.layerHomesOf(widget.projectId),
                            groups: ps.layerGroupsOf(widget.projectId, sceneId),
                          ),
                        ),
                        Positioned(
                          left: cropX * scale,
                          top: cropY * scale,
                          width: newW * scale,
                          height: newH * scale,
                          child: GestureDetector(
                            onPanUpdate: (d) => setS(() {
                              cropX += (d.delta.dx / scale).round();
                              cropY += (d.delta.dy / scale).round();
                              clampCrop();
                            }),
                            child: Builder(builder: (context) {
                              // 色固定にせず、更新マーク（❗）やフレーム現在地の
                              // 赤枠と同じ「目立たせる」役割の色（テーマの
                              // updateMarkColor）に揃える。
                              final markColor = context.watch<ThemeService>().current.updateMarkColor;
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: markColor, width: 2),
                                  color: markColor.withValues(alpha: 0.15),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.newProjectWidthShort),
                  SteppedSlider(
                    min: 64,
                    max: maxEdge.toDouble(),
                    value: newW.clamp(64, maxEdge).toDouble(),
                    label: '${newW}px',
                    onChanged: (v) => setS(() {
                      newW = v.round();
                      clampCrop();
                    }),
                  ),
                  Text(l10n.newProjectHeightShort),
                  SteppedSlider(
                    min: 64,
                    max: maxEdge.toDouble(),
                    value: newH.clamp(64, maxEdge).toDouble(),
                    label: '${newH}px',
                    onChanged: (v) => setS(() {
                      newH = v.round();
                      clampCrop();
                    }),
                  ),
                  Text('$newW × $newH px', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ps.resizeCanvas(
                    widget.projectId,
                    newWidth: newW,
                    newHeight: newH,
                    cropX: cropX,
                    cropY: cropY,
                  );
                },
                child: Text(l10n.commonOk),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAutofillDialog() {
    final l10n = AppLocalizations.of(context)!;
    int selected = 0;
    // 実行対象は選択フレーム・シーン単位・全フレームから選べる（仕様書04）。
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
                Text(l10n.layerPanelAutofillNote1,
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(l10n.timelineAutofillNote2,
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
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
                            Text(l10n.layerPanelAutofillRepaintHint, style: const TextStyle(fontSize: 11)),
                            Text(l10n.layerPanelAutofillRepaintNote, style: const TextStyle(fontSize: 11)),
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
                            Text(l10n.layerPanelAutofillColorUpdateHint, style: const TextStyle(fontSize: 11)),
                            Text(l10n.layerPanelAutofillColorUpdateNote, style: const TextStyle(fontSize: 11)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(l10n.timelineAutofillTargetLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _runBatchAutofill(
                  scope,
                  selected == 0 ? AutofillMode.repaint : AutofillMode.colorUpdate,
                );
              },
              child: Text(l10n.layerPanelExecuteButton),
            ),
          ],
        ),
      ),
    );
  }

  /// 自動塗り一括実行（仕様書04：タイムラインモードからの実行、対象は
  /// 現在フレーム／シーン単位／全フレームから選択）。対象範囲内の全フレームを
  /// 走査し、自動塗り用線画レイヤーごとにruleAutofillForLayerを実行する。
  Future<void> _runBatchAutofill(_AutofillScope scope, AutofillMode mode) async {
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

    double progress = 0;
    int applied = 0;
    void Function(void Function())? setDialogState;
    if (!mounted) return;
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          setDialogState = setS;
          return ProgressDialog(
            title: l10n.timelineAutofillProgressTitle,
            progress: progress,
            subtitle: l10n.timelineAutofillProgressSubtitle(targets.length),
          );
        },
      ),
    ));
    await Future.delayed(const Duration(milliseconds: 16));

    for (int i = 0; i < targets.length; i++) {
      final (sceneId, frameIndex) = targets[i];
      final layers = ps.layersOf(widget.projectId, sceneId, frameIndex);
      final lineartLayers = layers.where((l) => l.type == LayerType.autoFillLineart);
      for (final lineartLayer in lineartLayers) {
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
      // 対応する線画レイヤーが存在しない孤立した自動塗りレイヤー（仕様書04：
      // 「線画レイヤーなし・塗りレイヤーあり」の行）は、選択中のモードに
      // 関わらず不透明度ロック＋最新色での塗りつぶしのみを行う。
      final orphanedLayers = layers.where((l) => isOrphanedAutofillLayer(layers, l));
      for (final orphanedLayer in orphanedLayers) {
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
      progress = (i + 1) / targets.length;
      setDialogState?.call(() {});
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.timelineAutofillCompleteSnackbar(applied))),
    );
  }
}

enum _AutofillScope { currentFrame, currentScene, allScenes }


// ─── タイムラインプレビューウィジェット ───────────────────────────────────

class _TimelinePreview extends StatefulWidget {
  final TileManager tileManager;
  final List<Layer> layers;
  final String sceneId;
  final int frameIndex;
  final List<CameraKeyframe> cameraKeyframes;
  final List<EffectFilterInstance> effectFilters;
  final Map<String, LayerHome> layerHomes;
  final List<LayerGroup> groups;

  const _TimelinePreview({
    required this.tileManager,
    required this.layers,
    required this.sceneId,
    required this.frameIndex,
    this.cameraKeyframes = const [],
    this.effectFilters = const [],
    this.layerHomes = const {},
    this.groups = const [],
  });

  @override
  State<_TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<_TimelinePreview> {
  final CameraEngine _cameraEngine = CameraEngine();
  final LayerKeyframeEngine _layerKeyframeEngine = LayerKeyframeEngine();
  final FilterEngine _filterEngine = FilterEngine();
  ui.Image? _image;
  bool _building = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(_TimelinePreview old) {
    super.didUpdateWidget(old);
    if (old.layers != widget.layers ||
        old.tileManager != widget.tileManager ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex ||
        old.cameraKeyframes != widget.cameraKeyframes ||
        old.effectFilters != widget.effectFilters ||
        old.groups != widget.groups) {
      _rebuild();
    }
  }

  LayerKeyframe? _groupKeyframeOf(Layer layer) {
    for (final g in widget.groups) {
      if (g.memberLayerIds.contains(layer.id)) {
        return g.keyframes.isEmpty ? null : _layerKeyframeEngine.valueAt(g.keyframes, widget.frameIndex);
      }
    }
    return null;
  }

  Future<void> _rebuild() async {
    if (_building) return;
    _building = true;
    final tm = widget.tileManager;
    final layered = await LayerCompositor.composite(
      tm,
      widget.layers,
      (l) => resolveTileKey(widget.layerHomes, widget.sceneId, widget.frameIndex, l.id),
      tm.canvasWidth,
      tm.canvasHeight,
      keyframeOf: (l) => l.keyframes.isEmpty ? null : _layerKeyframeEngine.valueAt(l.keyframes, widget.frameIndex),
      groupKeyframeOf: _groupKeyframeOf,
    );

    // カメラ変換を適用する（仕様書05：カメラは表示のみを変更する）
    final kf = _cameraEngine.valueAt(widget.cameraKeyframes, widget.frameIndex);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.save();
    _cameraEngine.apply(canvas, kf, tm.canvasWidth.toDouble(), tm.canvasHeight.toDouble());
    canvas.drawImage(layered, ui.Offset.zero, ui.Paint());
    canvas.restore();
    layered.dispose();
    final picture = recorder.endRecording();
    var img = await picture.toImage(tm.canvasWidth, tm.canvasHeight);

    // 演出フィルター（仕様書18）：合成・カメラ適用後の映像へ非破壊で適用する
    if (widget.effectFilters.isNotEmpty) {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        final filtered = _filterEngine.applyEffectFilters(
          byteData.buffer.asUint8List(),
          tm.canvasWidth,
          tm.canvasHeight,
          widget.effectFilters,
          widget.frameIndex,
        );
        final composed = img;
        img = await _decodeRgba(filtered, tm.canvasWidth, tm.canvasHeight);
        composed.dispose();
      }
    }

    if (!mounted) { img.dispose(); _building = false; return; }
    setState(() {
      _image?.dispose();
      _image = img;
      _building = false;
    });
  }

  Future<ui.Image> _decodeRgba(Uint8List bytes, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return RawImage(image: img, fit: BoxFit.contain);
  }
}



// ─── 演出フィルターシート ───────────────────────────────────────────────────
// 選択中シーンのProjectService.effectFiltersOf()を直接読み書きする（仕様書18：
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

  static String _typeLabel(AppLocalizations l10n, EffectFilterType type) => switch (type) {
    EffectFilterType.fade => l10n.timelineEffectTypeFade,
    EffectFilterType.gaussianBlur => l10n.timelineEffectTypeGaussianBlur,
    EffectFilterType.lensBlur => l10n.timelineEffectTypeLensBlur,
    EffectFilterType.mosaic => l10n.timelineEffectTypeMosaic,
    EffectFilterType.chromaticAberration => l10n.timelineEffectTypeChromaticAberration,
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
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effects = context.watch<ProjectService>().effectFiltersOf(projectId, sceneId);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(l10n.timelineEffectFilterLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.commonAdd),
                  onPressed: () => _showAddEffectDialog(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: effects.isEmpty
                ? Center(
                    child: Text(l10n.timelineEffectFilterEmptyState,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                // ドラッグで並び替え可能（仕様書18：「複数フィルターの適用順」は
                // タイムライン上の並び順に従うため、並び替えが適用順を左右する）
                : ReorderableListView.builder(
                    scrollController: scrollCtrl,
                    // ドラッグハンドルを明示アイコンとして置く（既定のまま
                    // だと行の長押しでしか並べ替えを開始できず、可視の目印が
                    // 無いままだった。他の並べ替え可能な一覧と操作方法を揃える）。
                    buildDefaultDragHandles: false,
                    itemCount: effects.length,
                    onReorder: (oldIndex, newIndex) => context
                        .read<ProjectService>()
                        .reorderEffectFilters(projectId, sceneId, oldIndex, newIndex),
                    itemBuilder: (ctx, i) =>
                        _buildEffectTile(context, effects[i], dragIndex: i, key: ValueKey(effects[i].id)),
                  ),
          ),
        ],
      ),
    );
  }

  void _update(BuildContext context, EffectFilterInstance e) =>
      context.read<ProjectService>().updateEffectFilter(projectId, sceneId, e);

  /// 演出フィルターを複製する（仕様書18「フィルター操作＞複製」）。
  /// 複製先は元フィルターの直後へ挿入する。
  void _duplicate(BuildContext context, EffectFilterInstance e, List<EffectFilterInstance> effects) {
    final service = context.read<ProjectService>();
    final copy = EffectFilterInstance(
      id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
      type: e.type,
      startFrame: e.startFrame,
      endFrame: e.endFrame,
      enabled: e.enabled,
      param1: e.param1,
      param2: e.param2,
      param3: e.param3,
      param4: e.param4,
      fadeColor: e.fadeColor,
    );
    service.addEffectFilter(projectId, sceneId, copy);
    final index = effects.indexWhere((f) => f.id == e.id);
    if (index >= 0 && index + 1 < effects.length) {
      service.reorderEffectFilters(projectId, sceneId, effects.length, index + 1);
    }
  }

  Widget _buildEffectTile(BuildContext context, EffectFilterInstance e, {int? dragIndex, Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    final effects = context.read<ProjectService>().effectFiltersOf(projectId, sceneId);
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        leading: Icon(_typeIcons[e.type], size: 20),
        title: Text(_typeLabel(l10n, e.type), style: const TextStyle(fontSize: 13)),
        subtitle: Text('F${e.startFrame + 1} ～ F${e.endFrame + 1}', style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: e.enabled, onChanged: (v) => _update(context, e.copyWith(enabled: v))),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: l10n.themeDuplicateAction,
              onPressed: () => _duplicate(context, e, effects),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              tooltip: l10n.commonDelete,
              onPressed: () async {
                if (!await confirmDelete(context, itemName: _typeLabel(l10n, e.type))) return;
                if (!context.mounted) return;
                context.read<ProjectService>().removeEffectFilter(projectId, sceneId, e.id);
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
                _rangeRow(l10n.timelineRangeStartLabel, e.startFrame, 0, totalFrames - 1,
                    (v) => _update(context, e.copyWith(startFrame: v.clamp(0, e.endFrame)))),
                _rangeRow(l10n.timelineRangeEndLabel, e.endFrame, 0, totalFrames - 1,
                    (v) => _update(context, e.copyWith(endFrame: v.clamp(e.startFrame, totalFrames - 1)))),
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
                else
                  ..._strengthParam(context, l10n, e),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeRow(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 36, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: SteppedSlider(
            value: value.toDouble(),
            min: min.toDouble(), max: max.toDouble(),
            divisions: max > min ? max - min : 1,
            label: 'F${value + 1}',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: EditableSliderValue(
            text: 'F${value + 1}',
            style: const TextStyle(fontSize: 11),
            value: value + 1, min: min + 1, max: max + 1,
            onChanged: (v) => onChanged(v.round() - 1),
          ),
        ),
      ],
    );
  }

  List<Widget> _strengthParam(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    final label = e.type == EffectFilterType.mosaic ? l10n.timelineEffectSizeLabel : l10n.timelineEffectStrengthLabel;
    final maxVal = e.type == EffectFilterType.mosaic ? 64.0 : 20.0;
    return [
      Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: SteppedSlider(
              value: e.param1.clamp(1, maxVal),
              min: 1, max: maxVal,
              divisions: maxVal.round() - 1,
              label: e.param1.round().toString(),
              onChanged: (v) => _update(context, e.copyWith(param1: v)),
            ),
          ),
          SizedBox(
            width: 36,
            child: EditableSliderValue(
              text: e.param1.round().toString(),
              style: const TextStyle(fontSize: 11),
              value: e.param1, min: 1, max: maxVal,
              onChanged: (v) => _update(context, e.copyWith(param1: v.toDouble())),
            ),
          ),
        ],
      ),
    ];
  }

  /// 演出フィルターの汎用パラメータ行（ラベル＋スライダー＋数値入力）。
  Widget _paramRow(String label, double value, double min, double max, int divisions,
      ValueChanged<double> onChanged, {String? valueText}) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: SteppedSlider(
            value: value.clamp(min, max),
            min: min, max: max,
            divisions: divisions > 0 ? divisions : null,
            label: valueText ?? value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: EditableSliderValue(
            text: valueText ?? value.round().toString(),
            style: const TextStyle(fontSize: 11),
            value: value, min: min, max: max, isInt: false,
            onChanged: (v) => onChanged(v.toDouble()),
          ),
        ),
      ],
    );
  }

  /// 色調調整のパラメータ（彩度・明度・コントラスト、いずれも-100〜100）。
  List<Widget> _colorAdjustParams(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    return [
      _paramRow(l10n.filterColorAdjustSaturationLabel, e.param1, -100, 100, 200,
          (v) => _update(context, e.copyWith(param1: v))),
      _paramRow(l10n.filterColorAdjustBrightnessLabel, e.param2, -100, 100, 200,
          (v) => _update(context, e.copyWith(param2: v))),
      _paramRow(l10n.filterColorAdjustContrastLabel, e.param3, -100, 100, 200,
          (v) => _update(context, e.copyWith(param3: v))),
    ];
  }

  /// 動くノイズのパラメータ（強度・量・粒の大きさ）。
  List<Widget> _animatedNoiseParams(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    return [
      _paramRow(l10n.timelineEffectStrengthLabel, e.param1, 1, 20, 19,
          (v) => _update(context, e.copyWith(param1: v))),
      _paramRow(l10n.timelineEffectAmountLabel, e.param2, 1, 100, 99,
          (v) => _update(context, e.copyWith(param2: v)), valueText: '${e.param2.round()}%'),
      _paramRow(l10n.timelineEffectGrainSizeLabel, e.param3, 1, 8, 7,
          (v) => _update(context, e.copyWith(param3: v))),
    ];
  }

  /// 雨のパラメータ（降り方・速さ・粒の大きさ・風向き）。
  List<Widget> _rainParams(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    return [
      _paramRow(l10n.timelineEffectRainIntensityLabel, e.param1, 1, 20, 19,
          (v) => _update(context, e.copyWith(param1: v))),
      _paramRow(l10n.timelineEffectRainSpeedLabel, e.param2, 2, 40, 0,
          (v) => _update(context, e.copyWith(param2: v))),
      _paramRow(l10n.timelineEffectRainSizeLabel, e.param3, 1, 6, 5,
          (v) => _update(context, e.copyWith(param3: v))),
      _paramRow(l10n.timelineEffectWindAngleLabel, e.param4, -60, 60, 0,
          (v) => _update(context, e.copyWith(param4: v)), valueText: '${e.param4.round()}°'),
    ];
  }

  List<Widget> _fadeParams(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    return [
      Row(
        children: [
          SizedBox(width: 36, child: Text(l10n.timelineColorLabel, style: const TextStyle(fontSize: 11))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickFadeColor(context, e),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: e.fadeColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            e.fadeColor == Colors.black ? l10n.timelineColorBlack : e.fadeColor == Colors.white ? l10n.timelineColorWhite : l10n.timelineColorCustom,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ];
  }

  /// 単色化のパラメータ（混合量スライダー＋色チップ。チップをタップすると
  /// フルカラーピッカー（ColorPickerPanel）が開く。仕様書28）。
  List<Widget> _monochromeParams(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    return [
      _paramRow(l10n.timelineEffectStrengthLabel, e.param1, 1, 20, 19,
          (v) => _update(context, e.copyWith(param1: v))),
      const SizedBox(height: 4),
      Row(
        children: [
          SizedBox(width: 56, child: Text(l10n.filterMonochromeColorLabel, style: const TextStyle(fontSize: 11))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _pickMonochromeColor(context, e),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: e.fadeColor,
                border: Border.all(color: Colors.grey),
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
  List<Widget> _thresholdParams(BuildContext context, AppLocalizations l10n, EffectFilterInstance e) {
    return [
      _paramRow(l10n.filterThresholdLabel, e.param1, 0, 255, 255,
          (v) => _update(context, e.copyWith(param1: v))),
    ];
  }

  void _pickFadeColor(BuildContext context, EffectFilterInstance e) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineFadeColorDialogTitle),
        content: Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            for (final c in [Colors.black, Colors.white, Colors.red, Colors.blue])
              GestureDetector(
                onTap: () { _update(context, e.copyWith(fadeColor: c)); Navigator.pop(ctx); },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: Colors.grey),
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
            children: EffectFilterType.values.map((type) => ListTile(
              leading: Icon(_typeIcons[type]),
              title: Text(_typeLabel(l10n, type)),
              onTap: () {
                ps.addEffectFilter(projectId, sceneId, EffectFilterInstance(
                  id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
                  type: type,
                  startFrame: currentFrame,
                  endFrame: (currentFrame + 11).clamp(0, totalFrames - 1),
                  // 雨の「速さ」は既定値50だとスライダー上限(40)を超えるため上書きする。
                  // 色調調整は彩度・明度・コントラストとも既定値0（変化なし）から
                  // 始める（他のフィルターと違い既定値5.0/50.0のままだと追加直後に
                  // 見た目が変わってしまうため）。二値化のparam1は閾値（0〜255）
                  // なので既定128（中間）から始める。
                  param1: switch (type) {
                    EffectFilterType.colorAdjust => 0.0,
                    EffectFilterType.threshold => 128.0,
                    _ => 5.0,
                  },
                  param2: type == EffectFilterType.rain
                      ? 10.0
                      : type == EffectFilterType.colorAdjust
                          ? 0.0
                          : 50.0,
                  param3: type == EffectFilterType.colorAdjust ? 0.0 : 2.0,
                  // 単色化の色（fadeColorスロットを流用）：既定は白＝通常の
                  // グレースケール。fadeフィルター自体の既定色は黒のままにする。
                  fadeColor:
                      type == EffectFilterType.monochrome ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                ));
                Navigator.pop(ctx);
              },
            )).toList(),
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
  const _ClipDetailSheet({
    required this.clip,
    required this.totalFrames,
    required this.onDelete,
    required this.onDuplicate,
    required this.onChanged,
  });
  @override
  State<_ClipDetailSheet> createState() => _ClipDetailSheetState();
}

class _ClipDetailSheetState extends State<_ClipDetailSheet> {
  late _TrackClip _c;

  @override
  void initState() {
    super.initState();
    _c = widget.clip;
    if (_c.useEnd == 0 && _c.lengthFrames > 1) _c.useEnd = _c.lengthFrames - 1;
  }

  void _notify() { widget.onChanged(); setState(() {}); }

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
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(_c.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon'))),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: l10n.themeDuplicateAction,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDuplicate();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: l10n.commonDelete,
                  onPressed: () async {
                    if (!await confirmDelete(context, itemName: _c.label)) return;
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
                  _row(l10n.timelineClipVolumeLabel, _c.volume, 0, 1, 100, (v) { _c.volume = v; _notify(); }, '${(_c.volume * 100).round()}%', step: 0.01),
                  _row(l10n.timelineClipFadeInLabel, _c.fadeIn, 0, 5, 50, (v) { _c.fadeIn = v; _notify(); }, '${_c.fadeIn.toStringAsFixed(1)}s', step: 0.1),
                  _row(l10n.timelineClipFadeOutLabel, _c.fadeOut, 0, 5, 50, (v) { _c.fadeOut = v; _notify(); }, '${_c.fadeOut.toStringAsFixed(1)}s', step: 0.1),
                ],
                if (_c.trackType == _ClipTrackType.video) ...[
                  _row(l10n.layerPanelOpacityLabel, _c.videoOpacity, 0, 1, 100, (v) { _c.videoOpacity = v; _notify(); }, '${(_c.videoOpacity * 100).round()}%', step: 0.01),
                  _row(l10n.timelineClipUseStartLabel, _c.useStart.toDouble(), 0, (_c.lengthFrames - 1).toDouble(), _c.lengthFrames,
                      (v) { _c.useStart = v.round().clamp(0, _c.useEnd); _notify(); }, 'F${_c.useStart + 1}'),
                  _row(l10n.timelineClipUseEndLabel, _c.useEnd.toDouble(), 0, (_c.lengthFrames - 1).toDouble(), _c.lengthFrames,
                      (v) { _c.useEnd = v.round().clamp(_c.useStart, _c.lengthFrames - 1); _notify(); }, 'F${_c.useEnd + 1}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, double min, double max, int divisions,
      ValueChanged<double> onChanged, String valueText, {double step = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: SteppedSlider(
              value: value.clamp(min, max),
              min: min, max: max,
              divisions: divisions > 0 ? divisions : 1,
              step: step,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: EditableSliderValue(
              text: valueText,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
              value: value, min: min, max: max, isInt: false,
              onChanged: (v) => onChanged(v.toDouble()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── カメラKFシート ────────────────────────────────────────────────────────

class _CameraKfSheet extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final CameraKeyframe kf;
  final int totalFrames;
  final ValueChanged<int> onDelete;
  final void Function(int oldFrameIndex, CameraKeyframe newKf) onSave;
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
  void initState() { super.initState(); _kf = widget.kf; }

  void _update(CameraKeyframe newKf) {
    widget.onSave(_kf.frameIndex, newKf);
    setState(() => _kf = newKf);
  }

  /// カメラ操作の見え方をスライダー操作だけに頼らず確認できるようにする
  /// プレビュー（仕様書05）。現在編集中のキーフレーム位置における実際の
  /// 見え方（カメラ変換適用後の
  /// フレーム）をその場でプレビュー表示し、スライダー操作と同時に確認できる
  /// ようにする。カメラキーフレーム一覧はwatchで購読し、スライダー変更の
  /// たびに即時反映されるようにする。
  Widget _buildLivePreview(BuildContext context) {
    final ps = context.watch<ProjectService>();
    final tileManager = ps.tileManagerOf(widget.projectId);
    final layers = ps.layersOf(widget.projectId, widget.sceneId, _kf.frameIndex);
    final cameraKeyframes = ps.cameraKeyframesOf(widget.projectId, widget.sceneId);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      height: 140,
      // _TimelinePreviewは透明部分を含む合成結果をそのまま描画するため、
      // 背景はテーマ色ではなく実際のキャンバス背景色に合わせる必要がある
      // （上の_buildPreviewContent()と同じ理由で、ここは意図的に色固定）。
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: _TimelinePreview(
        tileManager: tileManager,
        layers: layers,
        sceneId: widget.sceneId,
        frameIndex: _kf.frameIndex,
        cameraKeyframes: cameraKeyframes,
        layerHomes: ps.layerHomesOf(widget.projectId),
        groups: ps.layerGroupsOf(widget.projectId, widget.sceneId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(l10n.timelineCameraKfTitle(_kf.frameIndex + 1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: l10n.commonDelete,
                  onPressed: () async {
                    if (!await confirmDelete(context)) return;
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    widget.onDelete(_kf.frameIndex);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildLivePreview(context),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _row(l10n.timelineCameraMoveXLabel, _kf.x, -1920, 1920, (v) => _update(_kf.copyWith(x: v)), _kf.x.toStringAsFixed(0)),
                _row(l10n.timelineCameraMoveYLabel, _kf.y, -1080, 1080, (v) => _update(_kf.copyWith(y: v)), _kf.y.toStringAsFixed(0)),
                _row(l10n.timelineCameraZoomLabel, _kf.zoom, 0.1, 5.0, (v) => _update(_kf.copyWith(zoom: v)), '×${_kf.zoom.toStringAsFixed(2)}', step: 0.05),
                _row(l10n.timelineCameraRotationLabel, _kf.rotation, -180, 180, (v) => _update(_kf.copyWith(rotation: v)), '${_kf.rotation.toStringAsFixed(1)}°'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 72, child: Text(l10n.timelineFrameTrackLabel, style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: SteppedSlider(
                          value: _kf.frameIndex.toDouble(),
                          min: 0,
                          max: (widget.totalFrames - 1).toDouble(),
                          divisions: widget.totalFrames > 1 ? widget.totalFrames - 1 : 1,
                          onChanged: (v) => _update(_kf.copyWith(frameIndex: v.round())),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: EditableSliderValue(
                          text: 'F${_kf.frameIndex + 1}',
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                          value: _kf.frameIndex + 1, min: 1, max: widget.totalFrames,
                          onChanged: (v) => _update(_kf.copyWith(frameIndex: v.round() - 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String valueText, {double step = 1}) {
    final divisions = ((max - min) * 10).round().clamp(1, 1000);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: SteppedSlider(
              value: value.clamp(min, max),
              min: min, max: max,
              divisions: divisions,
              step: step,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: EditableSliderValue(
              text: valueText,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
              value: value, min: min, max: max, isInt: false,
              onChanged: (v) => onChanged(v.toDouble()),
            ),
          ),
        ],
      ),
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

  const _TimelineFrameThumbnail({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
  });

  @override
  State<_TimelineFrameThumbnail> createState() => _TimelineFrameThumbnailState();
}

class _TimelineFrameThumbnailState extends State<_TimelineFrameThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(covariant _TimelineFrameThumbnail old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex) {
      _generate();
    }
  }

  Future<void> _generate() async {
    final ps = context.read<ProjectService>();
    final project = ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
    final tileManager = ps.tileManagerOf(widget.projectId);
    final drawW = tileManager.canvasWidth;
    final drawH = tileManager.canvasHeight;
    if (drawW <= 0 || drawH <= 0) return;
    final exportW = (project?.exportWidth ?? drawW).clamp(1, drawW).toInt();
    final exportH = (project?.exportHeight ?? drawH).clamp(1, drawH).toInt();

    final layers = ps.layersOf(widget.projectId, widget.sceneId, widget.frameIndex);

    final fullImage = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => ps.tileKeyFor(widget.projectId, widget.sceneId, widget.frameIndex, l.id),
      drawW,
      drawH,
      keyframeOf: (l) => l.keyframes.isEmpty
          ? null
          : LayerKeyframeEngine().valueAt(l.keyframes, widget.frameIndex),
      groupKeyframeOf: (l) {
        final group = ps.groupContainingLayer(widget.projectId, widget.sceneId, l.id);
        if (group == null || group.keyframes.isEmpty) return null;
        return LayerKeyframeEngine().valueAt(group.keyframes, widget.frameIndex);
      },
    );

    final offsetX = (drawW - exportW) / 2;
    final offsetY = (drawH - exportH) / 2;
    const thumbW = 64;
    final thumbH = (thumbW * exportH / exportW).round().clamp(1, 200).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(offsetX, offsetY, exportW.toDouble(), exportH.toDouble()),
      ui.Rect.fromLTWH(0, 0, thumbW.toDouble(), thumbH.toDouble()),
      ui.Paint(),
    );
    fullImage.dispose();
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(thumbW, thumbH);
    picture.dispose();

    if (!mounted) {
      thumb.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = thumb);
    old?.dispose();
  }

  @override
  void dispose() {
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
