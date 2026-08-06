import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../engine/camera_engine.dart';
import '../../engine/filter_engine.dart';
import '../../engine/layer_compositor.dart';
import '../../engine/layer_range_resolver.dart';
import '../../engine/tile_manager.dart';
import '../../engine/undo_manager.dart';
import '../../models/camera_keyframe.dart';
import '../../models/effect_filter_instance.dart';
import '../../models/layer.dart';
import '../../models/material_asset.dart';
import '../../models/scene.dart';
import '../../models/watermark_asset.dart';
import '../../services/advertising_service.dart';
import '../../services/material_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/watermark_service.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/responsive.dart';

// タイムライントラッククリップ
enum _ClipTrackType { audio, video, image }

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

  // カーソル固定方式の移動モード
  bool _isMoveMode = false;
  int _moveCursorPos = 0;

  // トラッククリップ
  final List<_TrackClip> _audioClips = [];
  final List<_TrackClip> _videoClips = [];
  final List<_TrackClip> _imageClips = [];
  int _clipIdCounter = 0;

  // 音声・動画クリップの再生位置連動（仕様書05）
  final Map<String, ap.AudioPlayer> _audioPlayers = {};
  final Map<String, VideoPlayerController> _videoControllers = {};

  // EndCard Track（プレミアム編集項目、仕様書06・13）
  bool _endCardVisible = true;
  int _endCardLengthSeconds = 5;
  String? _endCardCustomPath;

  // フレーム幅（px）
  static const double _frameW = 36.0;
  static const double _frameMargin = 4.0;
  static const double _cellW = _frameW + _frameMargin * 2;

  // 横スクロール連動
  late final ScrollController _frameScrollCtrl;
  late final ScrollController _audioScrollCtrl;
  late final ScrollController _videoScrollCtrl;
  late final ScrollController _imageScrollCtrl;
  late final ScrollController _cameraScrollCtrl;
  bool _syncingScroll = false;

  // シーン複数選択モード（仕様書05：「選択」ボタンで開始）
  bool _isSceneMultiSelect = false;
  final Set<String> _selectedSceneIds = {};

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

    for (final ctrl in _trackScrollCtrls) {
      ctrl.addListener(() => _syncFrom(ctrl));
    }
  }

  List<ScrollController> get _trackScrollCtrls => [
    _frameScrollCtrl,
    _audioScrollCtrl,
    _videoScrollCtrl,
    _imageScrollCtrl,
    _cameraScrollCtrl,
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
    super.dispose();
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildPreview(),
            _buildPlaybackControls(),
            _buildToolbar(),
            _buildSceneTabs(),
            _buildFrameList(),
            _buildClipTrack(
              icon: Icons.image,
              label: '画像',
              clips: _imageClips,
              scrollCtrl: _imageScrollCtrl,
              addColor: Colors.green[700]!,
              onAdd: () => _showAddClipDialog('画像', _imageClips, Colors.green[700]!, _ClipTrackType.image),
            ),
            _buildClipTrack(
              icon: Icons.videocam,
              label: '動画',
              clips: _videoClips,
              scrollCtrl: _videoScrollCtrl,
              addColor: Colors.blue[700]!,
              onAdd: () => _showAddClipDialog('動画', _videoClips, Colors.blue[700]!, _ClipTrackType.video),
            ),
            _buildClipTrack(
              icon: Icons.audiotrack,
              label: '音声',
              clips: _audioClips,
              scrollCtrl: _audioScrollCtrl,
              addColor: Colors.orange[700]!,
              onAdd: () => _showAddClipDialog('音声', _audioClips, Colors.orange[700]!, _ClipTrackType.audio),
            ),
            _buildCameraTrack(),
            _buildEndCardTrack(),
            if (adService.shouldShowAds) const AdBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final projectName = context.watch<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull
        ?.name ??
        'プロジェクト名';
    final undoManager = context.watch<UndoManager>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/canvas/${widget.projectId}')),
          Expanded(child: Text(projectName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: undoManager.canUndo ? undoManager.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: undoManager.canRedo ? undoManager.redo : null,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == 'save' || action == 'project_save') _saveProject();
              if (action == 'autofill') _showAutofillDialog();
              if (action == 'save_tree') context.push('/save-tree/${widget.projectId}');
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'save', child: Text('保存')),
              const PopupMenuItem(value: 'project_save', child: Text('プロジェクト保存')),
              const PopupMenuItem(value: 'autofill', child: Text('自動塗り実行')),
              const PopupMenuItem(value: 'save_tree', child: Text('セーブツリー')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final ps = context.watch<ProjectService>();
    final sceneId = _selectedSceneId;
    final preview = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: sceneId == null
          ? const Center(child: Text('プレビュー', style: TextStyle(color: Colors.grey)))
          : _TimelinePreview(
              tileManager: ps.tileManagerOf(widget.projectId),
              layers: ps.layersOf(widget.projectId, sceneId, _currentFrame),
              sceneId: sceneId,
              frameIndex: _currentFrame,
              cameraKeyframes: ps.cameraKeyframesOf(widget.projectId, sceneId),
              effectFilters: ps.effectFiltersOf(widget.projectId, sceneId),
              layerHomes: ps.layerHomesOf(widget.projectId),
            ),
    );
    return Expanded(
      flex: 3,
      // PC/DeXモード（広い画面）：横幅を制限して中央寄せにし、プレビューが
      // 横に間延びした帯状にならないようにする。
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!isWideScreen(context)) return preview;
          final w = constraints.maxWidth < 640 ? constraints.maxWidth : 640.0;
          return Center(
            child: SizedBox(width: w, height: constraints.maxHeight, child: preview),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => setState(() => _currentFrame = 0)),
          IconButton(icon: const Icon(Icons.fast_rewind), onPressed: () { if (_currentFrame > 0) setState(() => _currentFrame--); }),
          IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow), onPressed: _togglePlay),
          IconButton(icon: const Icon(Icons.fast_forward), onPressed: () { if (_currentFrame < _totalFrames - 1) setState(() => _currentFrame++); }),
          IconButton(icon: const Icon(Icons.skip_next), onPressed: () => setState(() => _currentFrame = _totalFrames - 1)),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final isPremium = context.watch<PremiumService>().isPremium;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.image, size: 18),
            onPressed: () => _showAddClipDialog('画像', _imageClips, Colors.green[700]!, _ClipTrackType.image),
            tooltip: '＋画像',
          ),
          IconButton(
            icon: const Icon(Icons.videocam, size: 18),
            onPressed: () => _showAddClipDialog('動画', _videoClips, Colors.blue[700]!, _ClipTrackType.video),
            tooltip: '＋動画',
          ),
          IconButton(
            icon: const Icon(Icons.audiotrack, size: 18),
            onPressed: () => _showAddClipDialog('音声', _audioClips, Colors.orange[700]!, _ClipTrackType.audio),
            tooltip: '＋音源',
          ),
          // ウォーターマーク：無料会員は🔒付き表示、タップで共通Premiumバナー
          _buildWatermarkButton(isPremium),
          IconButton(icon: const Icon(Icons.movie_filter, size: 18), onPressed: () => _showEffectFilterDialog(), tooltip: '演出フィルター'),
          IconButton(icon: const Icon(Icons.camera, size: 18), onPressed: _addCameraKf, tooltip: 'カメラキーフレーム追加'),
          IconButton(icon: const Icon(Icons.upload_file, size: 18), onPressed: () => context.push('/export/${widget.projectId}'), tooltip: '書き出し'),
        ],
      ),
    );
  }

  Widget _buildWatermarkButton(bool isPremium) {
    if (isPremium) {
      return IconButton(
        icon: const Icon(Icons.branding_watermark, size: 18),
        onPressed: _showWatermarkPicker,
        tooltip: '＋ウォーターマーク',
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
            Icon(Icons.branding_watermark, size: 18, color: Colors.grey[500]),
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
    final watermarkService = context.read<WatermarkService>();
    final assets = watermarkService.assets;
    if (assets.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ウォーターマーク未登録'),
          content: const Text('設定画面の「ウォーターマーク」からあらかじめ画像を登録してください。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/settings/watermark');
              },
              child: const Text('設定を開く'),
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
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('ウォーターマークを選択', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final asset in assets)
              ListTile(
                leading: const Icon(Icons.branding_watermark),
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

  /// 選択したウォーターマーク画像をラスタライズし、LayerType.watermarkの
  /// レイヤーとして現在シーンへ追加する（表示範囲はデフォルトで全フレーム＝
  /// 常時表示。以後の表示範囲・不透明度・差し替えはレイヤーパネルから調整できる）。
  Future<void> _addWatermarkLayer(WatermarkAsset asset) async {
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final watermarkService = context.read<WatermarkService>();
    final path = await watermarkService.pathOf(asset.id);
    if (path == null || !mounted) return;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (!mounted) {
      image.dispose();
      return;
    }

    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    // 右下に控えめなサイズ（キャンバス幅の25%程度）で配置する一般的な
    // ウォーターマーク位置をデフォルトとする。位置・大きさは追加後に
    // 変形ツールで自由に調整できる。
    final targetW = w * 0.25;
    final scale = targetW / image.width;
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    const margin = 16.0;
    final dx = w - drawW - margin;
    final dy = h - drawH - margin;

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
    if (byteData == null || !mounted) return;

    final layer = projectService.addLayer(
      projectId: widget.projectId,
      sceneId: sceneId,
      frameIndex: _currentFrame,
      type: LayerType.watermark,
      name: asset.name,
    );
    tileManager.replaceLayerPixels(
      frameLayerKey(sceneId, _currentFrame, layer.id),
      byteData.buffer.asUint8List(),
    );
    // 既定は「常時表示」（全フレーム）。表示範囲はレイヤーパネルの
    // 「表示範囲変更」からいつでも変更できる（仕様書05：常時表示／
    // エンドカード／任意フレームのみ表示はすべて表示範囲設定で実現する）。
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: sceneId,
      frameIndex: _currentFrame,
      layer: layer.copyWith(rangeMode: LayerRangeMode.allFrames),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ウォーターマークを追加しました（全フレームに表示されます）: ${asset.name}')),
    );
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
            // 先頭サムネイル（実画像は未実装のためグレープレースホルダー）
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.movie, size: 20, color: Colors.white54),
            ),
            // 枚数バッジ（右上）
            if (count > 1)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
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
    final scenes = context.watch<ProjectService>().scenesOf(widget.projectId);
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
                // 移動モード中：「決定」ボタン。複数選択モード中：「移動」「削除」ボタン。通常時：「選択」ボタン
                if (_isMoveMode)
                  TextButton(
                    onPressed: () => _confirmMove(scenes),
                    child: const Text('決定', style: TextStyle(fontSize: 11)),
                  )
                else if (_isSceneMultiSelect) ...[
                  TextButton(
                    onPressed: _selectedSceneIds.isNotEmpty ? () => _startMoveMode(scenes) : null,
                    child: const Text('移動', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: _selectedSceneIds.length < scenes.length
                        ? _showMultiDeleteConfirm
                        : null,
                    child: const Text('削除', style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                ] else
                  TextButton(
                    onPressed: () => setState(() => _isSceneMultiSelect = true),
                    child: const Text('選択', style: TextStyle(fontSize: 11)),
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
                                color: isActive ? Colors.blue : Colors.grey[600],
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
                              label: Text(scene.displayName, style: TextStyle(fontSize: 11, color: isMoving ? Colors.blue : null)),
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
                        return GestureDetector(
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
                          // 長押し：このシーンを選択済みの状態でシーン複数選択モードを開始する
                          onLongPress: () {
                            if (_isSceneMultiSelect) return;
                            setState(() {
                              _isSceneMultiSelect = true;
                              _selectedSceneIds.add(scene.id);
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
                                  Text(scene.displayName, style: const TextStyle(fontSize: 11)),
                                  if (!_isSceneMultiSelect)
                                    GestureDetector(
                                      onTap: () => _showSceneMenu(scene, scenes),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.more_vert, size: 12),
                                      ),
                                    ),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (_) {},
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                // 複数選択モード中：全選択・全解除ボタン
                if (_isSceneMultiSelect && !_isMoveMode) ...[
                  TextButton(
                    onPressed: () => setState(() => _selectedSceneIds.addAll(scenes.map((s) => s.id))),
                    child: const Text('全選択', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: () => setState(() { _selectedSceneIds.clear(); _isSceneMultiSelect = false; }),
                    child: const Text('全解除', style: TextStyle(fontSize: 11)),
                  ),
                ],
                // 移動モード中：キャンセルボタン
                if (_isMoveMode)
                  TextButton(
                    onPressed: () => setState(() => _isMoveMode = false),
                    child: const Text('キャンセル', style: TextStyle(fontSize: 11)),
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

  // 移動モード開始（仕様書05：複数選択モードからのみ起動）
  void _startMoveMode(List<Scene> scenes) {
    if (_selectedSceneIds.isEmpty) return;
    setState(() {
      _isMoveMode = true;
      // 選択中シーンの並び順で最後のシーンの直後にカーソルを初期配置
      final lastIdx = scenes.lastIndexWhere((s) => _selectedSceneIds.contains(s.id));
      _moveCursorPos = lastIdx + 1;
    });
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

  // 三点メニュー（仕様書05：シーン名変更・シーン削除の2項目のみ）
  void _showSceneMenu(Scene scene, List<Scene> scenes) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('シーン名変更'),
              onTap: () { Navigator.pop(ctx); _showRenameSceneDialog(scene); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('シーン削除', style: TextStyle(color: Colors.red)),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${scene.displayName}」を削除しますか？'),
        content: const Text('シーン内の全フレーム・共通レイヤー・動画素材・画像素材・ウォーターマークを含むすべてのデータが削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>().removeScene(widget.projectId, scene.id);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // 複数選択シーン削除の確認ダイアログ（仕様書05）
  void _showMultiDeleteConfirm() {
    final count = _selectedSceneIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('選択中の$count件のシーンを削除しますか？'),
        content: const Text('シーン内の全フレーム・共通レイヤー・動画素材・画像素材・ウォーターマークを含むすべてのデータが削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
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
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showRenameSceneDialog(Scene scene) {
    final controller = TextEditingController(text: scene.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('シーン名変更'),
        content: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<ProjectService>()
                    .renameScene(widget.projectId, scene.id, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Widget _buildFrameList() {
    final total = _totalFrames;
    return Container(
      height: 50,
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Colors.grey[800]!))),
      child: Row(
        children: [
          _buildTrackLabel(Icons.movie_filter, 'フレーム'),
          Expanded(
            child: ListView.builder(
              controller: _frameScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: total,
              itemBuilder: (context, index) {
                final isSelected = index == _currentFrame;
                return GestureDetector(
                  onTap: () => setState(() => _currentFrame = index),
                  child: Container(
                    width: _frameW,
                    margin: const EdgeInsets.symmetric(horizontal: _frameMargin),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withValues(alpha: 0.3) : Colors.grey[850],
                      border: Border.all(color: isSelected ? Colors.blue : Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 9))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackLabel(IconData icon, String label) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 2),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildClipTrack({
    required IconData icon,
    required String label,
    required List<_TrackClip> clips,
    required ScrollController scrollCtrl,
    required Color addColor,
    required VoidCallback onAdd,
  }) {
    final total = _totalFrames;
    return Container(
      height: 32,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          _buildTrackLabel(icon, label),
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
                      border: Border(right: BorderSide(color: Colors.grey[800]!, width: 0.5)),
                    ),
                  ),
                ),
                // クリップ描画
                ...clips.map((clip) => _buildClipWidget(clip, scrollCtrl)),
                // ＋ボタン（右端）
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: onAdd,
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

  Widget _buildClipWidget(_TrackClip clip, ScrollController scrollCtrl) {
    return AnimatedBuilder(
      animation: scrollCtrl,
      builder: (ctx, child) {
        final scrollOffset = scrollCtrl.hasClients ? scrollCtrl.offset : 0.0;
        final left = clip.startFrame * _cellW - scrollOffset;
        final width = clip.lengthFrames * _cellW - _frameMargin * 2;
        if (left + width < 0 || left > MediaQuery.of(context).size.width) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: left.clamp(0.0, double.infinity),
          top: 3,
          width: width.clamp(8.0, double.infinity),
          height: 26,
          child: GestureDetector(
            onTap: () => _showEditClipDialog(clip),
            child: Container(
              decoration: BoxDecoration(
                color: clip.color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.centerLeft,
              child: Text(
                clip.label,
                style: const TextStyle(fontSize: 9, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraTrack() {
    final total = _totalFrames;
    final sceneId = _selectedSceneId;
    final cameraKfs = sceneId == null
        ? const <CameraKeyframe>[]
        : context.watch<ProjectService>().cameraKeyframesOf(widget.projectId, sceneId);
    return Container(
      height: 32,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          _buildTrackLabel(Icons.camera_alt, 'カメラ'),
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
                      border: Border(right: BorderSide(color: Colors.grey[800]!, width: 0.5)),
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
        final cx = kf.frameIndex * _cellW + _cellW / 2 - scrollOffset;
        return Positioned(
          left: cx - 7,
          top: 9,
          child: GestureDetector(
            onTap: () => _showEditCameraKfDialog(kf),
            child: Transform.rotate(
              angle: 0.785, // 45°
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.purple[400],
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// EndCard Track（無料版：ロック状態、プレミアム：編集可能）
  Widget _buildEndCardTrack() {
    return Consumer<PremiumService>(
      builder: (context, premium, _) => Container(
        height: 32,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Icon(Icons.movie, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            const Text('EndCard Track', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(width: 4),
            if (!premium.isPremium)
              GestureDetector(
                onTap: () => showPremiumBanner(context),
                child: const Icon(Icons.lock, size: 14, color: Colors.amber),
              )
            else ...[
              const Spacer(),
              Text(
                _endCardVisible
                    ? '${_endCardCustomPath != null ? '差替済' : 'MIRANIMAロゴ'}・$_endCardLengthSeconds秒'
                    : '非表示',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(_endCardVisible ? Icons.visibility : Icons.visibility_off, size: 14),
                onPressed: () => setState(() => _endCardVisible = !_endCardVisible),
                tooltip: '表示ON/OFF',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.timer, size: 14),
                onPressed: _showEndCardLengthDialog,
                tooltip: '長さ変更',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 14),
                onPressed: _pickEndCardReplacement,
                tooltip: '差し替え',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                onPressed: () => setState(() {
                  _endCardCustomPath = null;
                  _endCardVisible = false;
                }),
                tooltip: '削除',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEndCardLengthDialog() {
    int length = _endCardLengthSeconds;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('エンドカードの長さ'),
          content: Row(
            children: [
              Expanded(
                child: Slider(
                  value: length.toDouble(),
                  min: 1, max: 15, divisions: 14,
                  label: '$length秒',
                  onChanged: (v) => setS(() => length = v.round()),
                ),
              ),
              Text('$length秒'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                setState(() => _endCardLengthSeconds = length);
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEndCardReplacement() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    setState(() {
      _endCardCustomPath = result.files.first.path;
      _endCardVisible = true;
    });
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
          title: Text('$trackNameクリップを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'ラベル', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('開始:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: start.toDouble(),
                      min: 0,
                      max: (_totalFrames - 1).toDouble(),
                      divisions: _totalFrames > 1 ? _totalFrames - 1 : 1,
                      label: 'F${start + 1}',
                      onChanged: (v) => setS(() => start = v.round()),
                    ),
                  ),
                  Text('F${start + 1}', style: const TextStyle(fontSize: 11)),
                ],
              ),
              Row(
                children: [
                  const Text('長さ:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: length.toDouble(),
                      min: 1,
                      max: _totalFrames.toDouble(),
                      divisions: _totalFrames,
                      label: '${length}F',
                      onChanged: (v) => setS(() => length = v.round()),
                    ),
                  ),
                  Text('${length}F', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                setState(() {
                  clips.add(_TrackClip(
                    id: 'clip_${_clipIdCounter++}',
                    label: labelCtrl.text.isEmpty ? trackName : labelCtrl.text,
                    startFrame: start,
                    lengthFrames: length,
                    color: color,
                    trackType: trackType,
                    filePath: pickedPath,
                    materialId: asset.id,
                    useEnd: length - 1,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    ).then((_) => labelCtrl.dispose());
  }

  void _showEditClipDialog(_TrackClip clip) {
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
        },
        onChanged: () => setState(() {}),
      ),
    );
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

  /// 明示的保存（三点メニューの「保存」「プロジェクト保存」共通）。
  Future<void> _saveProject() async {
    await context.read<ProjectService>().saveProject(widget.projectId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プロジェクトを保存しました')),
    );
  }

  void _showAutofillDialog() {
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('自動塗り方法'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('※ プロジェクト内で自動塗りを初回実行する場合はどちらを選んでも問題ありません。', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('※ 自動塗りレイヤーのみ存在する場合は、一から領域を判定して自動塗りします。', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: const Text('塗りなおし'),
                      subtitle: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('誤って自動塗りの形状を変えてしまった場合におすすめ', style: TextStyle(fontSize: 11)),
                          Text('※ 一から領域を判定して塗りなおします。現在の自動塗りレイヤーの形状は破棄されます。', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      value: 0,
                      dense: true,
                    ),
                    RadioListTile<int>(
                      title: const Text('色更新'),
                      subtitle: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('自動塗りの形状を手動で調整した場合におすすめ', style: TextStyle(fontSize: 11)),
                          Text('※ 不透明度ロックをして最新の色で塗りつぶします。現在の自動塗りレイヤーの形状は維持されます。', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      value: 1,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('実行')),
          ],
        ),
      ),
    );
  }
}


// ─── タイムラインプレビューウィジェット ───────────────────────────────────

class _TimelinePreview extends StatefulWidget {
  final TileManager tileManager;
  final List<Layer> layers;
  final String sceneId;
  final int frameIndex;
  final List<CameraKeyframe> cameraKeyframes;
  final List<EffectFilterInstance> effectFilters;
  final Map<String, LayerHome> layerHomes;

  const _TimelinePreview({
    required this.tileManager,
    required this.layers,
    required this.sceneId,
    required this.frameIndex,
    this.cameraKeyframes = const [],
    this.effectFilters = const [],
    this.layerHomes = const {},
  });

  @override
  State<_TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<_TimelinePreview> {
  final CameraEngine _cameraEngine = CameraEngine();
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
        old.effectFilters != widget.effectFilters) {
      _rebuild();
    }
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

  static const _typeLabels = {
    EffectFilterType.fade: 'フェード',
    EffectFilterType.gaussianBlur: 'ガウスぼかし',
    EffectFilterType.lensBlur: 'レンズぼかし',
    EffectFilterType.mosaic: 'モザイク',
    EffectFilterType.chromaticAberration: '色収差',
    EffectFilterType.noise: 'ノイズ',
  };

  static const _typeIcons = {
    EffectFilterType.fade: Icons.gradient,
    EffectFilterType.gaussianBlur: Icons.blur_on,
    EffectFilterType.lensBlur: Icons.lens_blur,
    EffectFilterType.mosaic: Icons.grid_4x4,
    EffectFilterType.chromaticAberration: Icons.color_lens,
    EffectFilterType.noise: Icons.grain,
  };

  @override
  Widget build(BuildContext context) {
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
                const Text('演出フィルター', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('追加'),
                  onPressed: () => _showAddEffectDialog(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: effects.isEmpty
                ? const Center(
                    child: Text('フィルターがありません\n＋追加ボタンで追加してください',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: effects.length,
                    itemBuilder: (ctx, i) => _buildEffectTile(context, effects[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _update(BuildContext context, EffectFilterInstance e) =>
      context.read<ProjectService>().updateEffectFilter(projectId, sceneId, e);

  Widget _buildEffectTile(BuildContext context, EffectFilterInstance e) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(_typeIcons[e.type], size: 20),
        title: Text(_typeLabels[e.type]!, style: const TextStyle(fontSize: 13)),
        subtitle: Text('F${e.startFrame + 1} ～ F${e.endFrame + 1}', style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: e.enabled, onChanged: (v) => _update(context, e.copyWith(enabled: v))),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () =>
                  context.read<ProjectService>().removeEffectFilter(projectId, sceneId, e.id),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rangeRow('開始', e.startFrame, 0, totalFrames - 1,
                    (v) => _update(context, e.copyWith(startFrame: v.clamp(0, e.endFrame)))),
                _rangeRow('終了', e.endFrame, 0, totalFrames - 1,
                    (v) => _update(context, e.copyWith(endFrame: v.clamp(e.startFrame, totalFrames - 1)))),
                if (e.type == EffectFilterType.fade)
                  ..._fadeParams(context, e)
                else
                  ..._strengthParam(context, e),
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
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(), max: max.toDouble(),
            divisions: max > min ? max - min : 1,
            label: 'F${value + 1}',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 36, child: Text('F${value + 1}', style: const TextStyle(fontSize: 11))),
      ],
    );
  }

  List<Widget> _strengthParam(BuildContext context, EffectFilterInstance e) {
    final label = e.type == EffectFilterType.mosaic ? 'サイズ' : '強度';
    final maxVal = e.type == EffectFilterType.mosaic ? 64.0 : 20.0;
    return [
      Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: Slider(
              value: e.param1.clamp(1, maxVal),
              min: 1, max: maxVal,
              divisions: maxVal.round() - 1,
              label: e.param1.round().toString(),
              onChanged: (v) => _update(context, e.copyWith(param1: v)),
            ),
          ),
          SizedBox(width: 36, child: Text(e.param1.round().toString(), style: const TextStyle(fontSize: 11))),
        ],
      ),
    ];
  }

  List<Widget> _fadeParams(BuildContext context, EffectFilterInstance e) {
    return [
      Row(
        children: [
          const SizedBox(width: 36, child: Text('色', style: TextStyle(fontSize: 11))),
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
            e.fadeColor == Colors.black ? '黒' : e.fadeColor == Colors.white ? '白' : 'カスタム',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ];
  }

  void _pickFadeColor(BuildContext context, EffectFilterInstance e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フェードカラー'),
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
    final ps = context.read<ProjectService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フィルターを追加'),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: EffectFilterType.values.map((type) => ListTile(
              leading: Icon(_typeIcons[type]),
              title: Text(_typeLabels[type]!),
              onTap: () {
                ps.addEffectFilter(projectId, sceneId, EffectFilterInstance(
                  id: 'effect_${DateTime.now().microsecondsSinceEpoch}',
                  type: type,
                  startFrame: currentFrame,
                  endFrame: (currentFrame + 11).clamp(0, totalFrames - 1),
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
  final VoidCallback onChanged;
  const _ClipDetailSheet({
    required this.clip,
    required this.totalFrames,
    required this.onDelete,
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
                Expanded(child: Text(_c.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () { Navigator.pop(context); widget.onDelete(); },
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
                  _row('音量', _c.volume, 0, 1, 100, (v) { _c.volume = v; _notify(); }, '${(_c.volume * 100).round()}%'),
                  _row('フェードイン', _c.fadeIn, 0, 5, 50, (v) { _c.fadeIn = v; _notify(); }, '${_c.fadeIn.toStringAsFixed(1)}s'),
                  _row('フェードアウト', _c.fadeOut, 0, 5, 50, (v) { _c.fadeOut = v; _notify(); }, '${_c.fadeOut.toStringAsFixed(1)}s'),
                ],
                if (_c.trackType == _ClipTrackType.video) ...[
                  _row('不透明度', _c.videoOpacity, 0, 1, 100, (v) { _c.videoOpacity = v; _notify(); }, '${(_c.videoOpacity * 100).round()}%'),
                  _row('使用開始F', _c.useStart.toDouble(), 0, (_c.lengthFrames - 1).toDouble(), _c.lengthFrames,
                      (v) { _c.useStart = v.round().clamp(0, _c.useEnd); _notify(); }, 'F${_c.useStart + 1}'),
                  _row('使用終了F', _c.useEnd.toDouble(), 0, (_c.lengthFrames - 1).toDouble(), _c.lengthFrames,
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
      ValueChanged<double> onChanged, String valueText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min, max: max,
              divisions: divisions > 0 ? divisions : 1,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(valueText, style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// ─── カメラKFシート ────────────────────────────────────────────────────────

class _CameraKfSheet extends StatefulWidget {
  final CameraKeyframe kf;
  final int totalFrames;
  final ValueChanged<int> onDelete;
  final void Function(int oldFrameIndex, CameraKeyframe newKf) onSave;
  const _CameraKfSheet({
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
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
                Expanded(child: Text('カメラ KF: F${_kf.frameIndex + 1}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () { Navigator.pop(context); widget.onDelete(_kf.frameIndex); },
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
                _row('X 移動', _kf.x, -1920, 1920, (v) => _update(_kf.copyWith(x: v)), _kf.x.toStringAsFixed(0)),
                _row('Y 移動', _kf.y, -1080, 1080, (v) => _update(_kf.copyWith(y: v)), _kf.y.toStringAsFixed(0)),
                _row('ズーム', _kf.zoom, 0.1, 5.0, (v) => _update(_kf.copyWith(zoom: v)), '×${_kf.zoom.toStringAsFixed(2)}'),
                _row('回転', _kf.rotation, -180, 180, (v) => _update(_kf.copyWith(rotation: v)), '${_kf.rotation.toStringAsFixed(1)}°'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 72, child: Text('フレーム', style: TextStyle(fontSize: 12))),
                      Expanded(
                        child: Slider(
                          value: _kf.frameIndex.toDouble(),
                          min: 0,
                          max: (widget.totalFrames - 1).toDouble(),
                          divisions: widget.totalFrames > 1 ? widget.totalFrames - 1 : 1,
                          onChanged: (v) => _update(_kf.copyWith(frameIndex: v.round())),
                        ),
                      ),
                      SizedBox(width: 48, child: Text('F${_kf.frameIndex + 1}',
                          style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
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
      ValueChanged<double> onChanged, String valueText) {
    final divisions = ((max - min) * 10).round().clamp(1, 1000);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min, max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 56, child: Text(valueText, style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
