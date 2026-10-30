import '../home/widgets/work_folder_move_sheet.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../engine/layer_compositor.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../services/font_service.dart';
import '../../services/material_service.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/autofill_preset_selection_sheet.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/stepped_slider.dart';
import '../../config/font_fallback.dart';
import '../home/widgets/project_list_widget.dart'
    show showMaterialIncludeDialog, buildFontShareBundle;

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

/// シーンをまたいだ絶対フレーム位置（プレビュー再生用）。
typedef _FlatFrame = ({String sceneId, int frameIndex});

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  int _frameIndex = 0;
  bool _isPlaying = false;
  bool _loopPlayback = false;
  bool _rendering = false;
  Timer? _timer;
  ui.Image? _previewImage;
  // プレビュー全画面化：確認・仕上がりチェックに集中できるよう、
  // プレビューと再生コントロールのみを全画面表示する
  // （タイムラインモードのプレビュー全画面化と同等の機能）。
  bool _isPreviewFullscreen = false;
  final _fullscreenPageScroll = ScrollController();

  @override
  void dispose() {
    _timer?.cancel();
    _fullscreenPageScroll.dispose();
    _previewImage?.dispose();
    super.dispose();
  }

  List<_FlatFrame> _flatten(ProjectService ps) {
    final result = <_FlatFrame>[];
    for (final scene in ps.scenesOf(widget.projectId)) {
      for (int i = 0; i < scene.frames.length; i++) {
        result.add((sceneId: scene.id, frameIndex: i));
      }
    }
    return result;
  }

  Future<void> _renderFrame(ProjectService ps, List<_FlatFrame> flat) async {
    if (_rendering || flat.isEmpty) return;
    _rendering = true;
    final entry = flat[_frameIndex.clamp(0, flat.length - 1)];
    final tileManager = ps.tileManagerOf(widget.projectId);
    final layers = ps.layersOf(
      widget.projectId,
      entry.sceneId,
      entry.frameIndex,
    );
    final img = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => ps.tileKeyFor(
        widget.projectId,
        entry.sceneId,
        entry.frameIndex,
        l.id,
      ),
      tileManager.canvasWidth,
      tileManager.canvasHeight,
      paperColor: LayerCompositor.paperForBlendModes(
        layers,
        ps.projects
            .where((p) => p.id == widget.projectId)
            .firstOrNull
            ?.backgroundColor,
      ),
    );
    _rendering = false;
    if (!mounted) {
      img.dispose();
      return;
    }
    final old = _previewImage;
    setState(() => _previewImage = img);
    old?.dispose();
  }

  void _seekTo(ProjectService ps, List<_FlatFrame> flat, int index) {
    if (flat.isEmpty) return;
    setState(() => _frameIndex = index.clamp(0, flat.length - 1));
    _renderFrame(ps, flat);
  }

  void _togglePlay(ProjectService ps, List<_FlatFrame> flat, int fps) {
    if (flat.isEmpty) return;
    if (_isPlaying) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    // ループOFFで最終フレームから再生を押した場合は先頭から再開する。
    if (!_loopPlayback && _frameIndex >= flat.length - 1) {
      _seekTo(ps, flat, 0);
    }
    setState(() => _isPlaying = true);
    final safeFps = fps > 0 ? fps : 24;
    final interval = Duration(
      milliseconds: (1000 / safeFps).round().clamp(16, 1000),
    );
    _timer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_loopPlayback && _frameIndex >= flat.length - 1) {
        timer.cancel();
        setState(() => _isPlaying = false);
        return;
      }
      setState(() => _frameIndex = (_frameIndex + 1) % flat.length);
      _renderFrame(ps, flat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final project = projectService.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.projectDetailNotFoundTitle)),
        body: Center(child: Text(l10n.projectDetailNotFoundBody)),
      );
    }

    final flat = _flatten(projectService);
    if (_previewImage == null && !_rendering) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _renderFrame(projectService, flat),
      );
    }

    // プレビュー全画面化中：プレビューと再生コントロールのみを全画面表示する
    // （タイムラインモードのプレビュー全画面化と同等）。
    if (_isPreviewFullscreen) {
      final theme = context.watch<ThemeService>().current;
      void exitFullscreen() => setState(() => _isPreviewFullscreen = false);
      Widget exitButton() => IconButton(
        key: const Key('projectDetailFullscreenExit'),
        autofocus: true,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        visualDensity: VisualDensity.standard,
        icon: Icon(Icons.fullscreen_exit, color: theme.textColor),
        tooltip: l10n.projectDetailFullscreenCloseTooltip,
        onPressed: exitFullscreen,
      );
      Widget preview() => KeyedSubtree(
        key: const Key('projectDetailFullscreenImage'),
        child: _buildPreviewImage(project, totalFrames: flat.length, showOverlayButtons: false),
      );
      Widget transport() => SizedBox(
        key: const Key('projectDetailFullscreenTransport'),
        height: 48,
        child: _buildPlaybackBar(projectService, flat, project),
      );
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) exitFullscreen();
        },
        child: Scaffold(
          backgroundColor: theme.panelBgColor,
          body: SafeArea(
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  exitFullscreen();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 208) {
                    return SingleChildScrollView(
                      controller: _fullscreenPageScroll,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [exitButton(), _buildLoopButton()],
                          ),
                          SizedBox(height: 64, child: preview()),
                          _buildSeekBar(flat),
                          transport(),
                        ],
                      ),
                    );
                  }
                  // The frame counter lives on the image; there is no
                  // second status row consuming preview height.
                  return Column(
                    children: [
                      Expanded(child: preview()),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            exitButton(),
                            _buildLoopButton(),
                            Expanded(child: _buildSeekBar(flat)),
                          ],
                        ),
                      ),
                      transport(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          const HelpButton(topic: 'プロジェクト詳細画面'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case 'rename':
                  _showRenameDialog(context, project.name);
                case 'duplicate':
                  projectService.duplicateProject(widget.projectId);
                case 'move':
                  _showMoveToFolderDialog(context, projectService);
                case 'materials':
                  context.push('/materials/${widget.projectId}');
                case 'delete':
                  // お気に入り登録中は削除できない。
                  if (project.isFavorite) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
                    );
                  } else {
                    projectService.deleteProject(widget.projectId);
                    context.pop();
                  }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
              PopupMenuItem(
                value: 'duplicate',
                child: Text(l10n.themeDuplicateAction),
              ),
              PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
              PopupMenuItem(
                value: 'materials',
                child: Text(l10n.materialListTitle),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l10n.projectDetailTrashMenuItem,
                  style: TextStyle(color: ThemeService.activeColorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildPreviewImage(project, totalFrames: flat.length),
              ),
              _buildSeekBar(flat),
              // メディアプレイヤー風：中央の再生ボタンをテーマカラーの円で強調する
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: _buildPlaybackBar(projectService, flat, project),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/canvas/${widget.projectId}'),
                icon: const Icon(Icons.edit),
                label: Text(l10n.projectDetailStartEditButton),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),
              // フォルダ・タグ・お気に入り・共有のクイックアクセス
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _quickAction(
                      icon: Icons.folder_outlined,
                      label: l10n.creativePanelFolderButton,
                      onTap: () =>
                          _showMoveToFolderDialog(context, projectService),
                    ),
                  ),
                  Expanded(
                    child: _quickAction(
                      icon: Icons.sell_outlined,
                      label: l10n.projectDetailTagsQuickAction,
                      onTap: () =>
                          _showTagsDialog(context, projectService, project),
                    ),
                  ),
                  Expanded(
                    child: _quickAction(
                      icon: project.isFavorite ? Icons.star : Icons.star_border,
                      label: project.isFavorite
                          ? l10n.projectDetailFavoriteRegistered
                          : l10n.projectDetailFavoriteUnregistered,
                      iconColor: project.isFavorite
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      onTap: () =>
                          projectService.toggleFavorite(widget.projectId),
                    ),
                  ),
                  Expanded(
                    child: _quickAction(
                      icon: Icons.ios_share,
                      label: l10n.projectDetailShareQuickAction,
                      onTap: () =>
                          _createNiashare(context, projectService, project),
                    ),
                  ),
                  // Keep the loop control directly beside Share.
                  Expanded(child: _buildLoopButton()),
                ],
              ),
              if (project.tags.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    l10n.projectDetailTagsQuickAction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: project.tags
                      .map(
                        (tag) => Chip(
                          avatar: const Icon(Icons.sell_outlined, size: 16),
                          label: Text('#$tag'),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  l10n.projectDetailInfoSectionTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('FPS', '${project.fps}'),
                      _infoRow(
                        l10n.projectDetailInfoExportSize,
                        '${project.exportWidth}×${project.exportHeight}',
                      ),
                      if (project.hasExtendedDrawingArea)
                        _infoRow(
                          l10n.projectDetailInfoDrawingArea,
                          l10n.projectDetailInfoDrawingAreaValue(
                            '${project.drawingWidth}×${project.drawingHeight}',
                            l10n.newProjectScaleValue(
                              project.drawingAreaScale.toStringAsFixed(1),
                            ),
                          ),
                        ),
                      _infoRow(
                        l10n.projectDetailInfoTotalFrames,
                        '${project.totalFrames}',
                      ),
                      _infoRow(
                        l10n.projectDetailInfoWorkTime,
                        l10n.newProjectDurationHm(
                          project.totalWorkSeconds ~/ 3600,
                          (project.totalWorkSeconds % 3600) ~/ 60,
                        ),
                      ),
                      _infoRow(
                        l10n.projectDetailInfoLastSaved,
                        _formatDateTime(project.updatedAt),
                      ),
                      _infoRow(
                        l10n.projectDetailInfoSize,
                        _formatSize(project.sizeBytes),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ボタンの文言は、パフォーマンス設定で選んでいるセーブ方式
              // （セーブツリー／セーブスロット）に合わせて切り替える。押した先の
              // 画面（SaveTreeScreen）のタイトルと表示内容が一致しない
              // （「セーブツリー」ボタンなのにスロット画面が開く）不具合の対策。
              Builder(
                builder: (context) {
                  final isTreeMode = context
                      .watch<SaveTreeService>()
                      .isTreeMode;
                  return OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/save-tree/${widget.projectId}?entry=projectDetail',
                    ),
                    icon: Icon(
                      isTreeMode ? Icons.account_tree : Icons.save_outlined,
                    ),
                    label: Text(
                      isTreeMode
                          ? l10n.saveTreeScreenTitleTree
                          : l10n.saveTreeScreenTitleSlot,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // このプロジェクトで使う自動塗りプリセットの選択。
              // プリセットは増えていくため、プロジェクト設定内でも選び直せる
              // ようにする。
              OutlinedButton.icon(
                onPressed: () =>
                    _showPresetSelection(context, projectService, project),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text(
                  project.enabledAutofillPresetIds == null
                      ? l10n.autofillPresetSelectionButton
                      : l10n.autofillPresetSelectionCountLabel(
                          project.enabledAutofillPresetIds!.length,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preview with the current frame counter inside its bottom-left corner.
  /// This overlay is visible in both embedded and fullscreen modes.
  Widget _buildPreviewImage(
    Project project, {
    required int totalFrames,
    bool showOverlayButtons = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.watch<ThemeService>().current;
    final image = Container(
      decoration: BoxDecoration(
        color: Color(project.backgroundColor),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: _previewImage != null
          ? RawImage(image: _previewImage, fit: BoxFit.contain)
          : Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 48,
                color: theme.textColor.withValues(alpha: 0.38),
              ),
            ),
    );
    final currentFrame = totalFrames == 0
        ? 0
        : _frameIndex.clamp(0, totalFrames - 1) + 1;
    return Stack(
      key: const Key('projectDetailPreviewArea'),
      children: [
        Positioned.fill(child: image),
        Positioned(
          left: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.menuBgColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '$currentFrame/$totalFrames',
                key: const Key('projectDetailFrameCounter'),
                style: TextStyle(
                  color: theme.menuTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (showOverlayButtons)
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: theme.menuBgColor.withValues(alpha: 0.7),
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('projectDetailFullscreenButton'),
                icon: Icon(
                  Icons.fullscreen,
                  color: theme.menuTextColor,
                  size: 20,
                ),
                tooltip: l10n.projectDetailFullscreenTooltip,
                onPressed: () => setState(() => _isPreviewFullscreen = true),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoopButton() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // The loop is the fifth quick action: neutral when off, accent when on.
    final label = l10n.timelineLoopOffTooltip
        .split(RegExp(r'[:：]')).first.trim();
    final foreground = _loopPlayback ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      toggled: _loopPlayback,
      button: true,
      label: label,
      child: InkWell(
        key: const Key('projectDetailLoopButton'),
        onTap: () => setState(() => _loopPlayback = !_loopPlayback),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, size: 24, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'HakkouMincho',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// プレビューと再生バーの間のシークバー。ドラッグで任意のフレームへ
  /// 直接移動できる（タイムラインモードのプレビューと同等の機能）。
  Widget _buildSeekBar(List<_FlatFrame> flat) {
    final maxFrame = (flat.length - 1).clamp(0, 1 << 30);
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
          value: _frameIndex.clamp(0, maxFrame).toDouble(),
          min: 0,
          max: maxFrame.toDouble(),
          divisions: maxFrame > 0 ? maxFrame : null,
          showSteppers: false,
          onChanged: flat.isEmpty
              ? null
              : (v) {
                  _timer?.cancel();
                  setState(() => _isPlaying = false);
                  _seekTo(context.read<ProjectService>(), flat, v.round());
                },
        ),
      ),
    );
  }

  Widget _buildPlaybackBar(
    ProjectService projectService,
    List<_FlatFrame> flat,
    Project project,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fps = project.fps > 0 ? project.fps : 24;
    final currentSeconds = flat.isEmpty
        ? 0.0
        : _frameIndex.clamp(0, flat.length - 1) / fps;
    final currentLabel = '${currentSeconds.toStringAsFixed(1)}s';
    final totalLabel = '${(flat.length / fps).toStringAsFixed(1)}s';
    final timeStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    );

    // Seven *equal-width cells*: elapsed time, five transport controls,
    // total time. Padding keeps the time labels away from the outer edges.
    Widget cell(Widget child) => Expanded(child: Center(child: child));
    Widget timeLabel(String label, Key key) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, key: key, maxLines: 1, style: timeStyle),
    );
    Widget control({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
      Color? iconColor,
    }) => IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 23, color: iconColor),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          cell(timeLabel(currentLabel, const Key('projectDetailCurrentSeconds'))),
          cell(control(
            icon: Icons.skip_previous,
            tooltip: l10n.projectDetailFirstFrameTooltip,
            onPressed: flat.isEmpty
                ? null
                : () => _seekTo(projectService, flat, 0),
          )),
          cell(control(
            icon: Icons.fast_rewind,
            tooltip: l10n.projectDetailPrevFrameTooltip,
            onPressed: flat.isEmpty
                ? null
                : () => _seekTo(projectService, flat, _frameIndex - 1),
          )),
          cell(Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: control(
              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
              iconColor: Theme.of(context).colorScheme.onPrimary,
              tooltip: _isPlaying
                  ? l10n.projectDetailPauseTooltip
                  : l10n.projectDetailPlayTooltip,
              onPressed: flat.isEmpty
                  ? null
                  : () => _togglePlay(projectService, flat, project.fps),
            ),
          )),
          cell(control(
            icon: Icons.fast_forward,
            tooltip: l10n.projectDetailNextFrameTooltip,
            onPressed: flat.isEmpty
                ? null
                : () => _seekTo(projectService, flat, _frameIndex + 1),
          )),
          cell(control(
            icon: Icons.skip_next,
            tooltip: l10n.projectDetailLastFrameTooltip,
            onPressed: flat.isEmpty
                ? null
                : () => _seekTo(projectService, flat, flat.length - 1),
          )),
          cell(timeLabel(totalLabel, const Key('projectDetailTotalSeconds'))),
        ],
      ),
    );
  }

  Future<void> _showPresetSelection(
    BuildContext context,
    ProjectService projectService,
    Project project,
  ) async {
    final allPresets = context.read<AutofillPresetService>().presets;
    final result = await showAutofillPresetSelectionSheet(
      context,
      allPresets: allPresets,
      initiallyEnabledIds: project.enabledAutofillPresetIds?.toSet(),
    );
    if (result.cancelled) return;
    await projectService.setEnabledAutofillPresetIds(
      widget.projectId,
      result.ids,
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, ProjectService service) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: service.folders,
        filename: service.projects
            .where((p) => p.id == widget.projectId)
            .first
            .name,
        onMove: (id) => service.moveToFolder(widget.projectId, id),
      ),
    );
  }

  void _showTagsDialog(
    BuildContext context,
    ProjectService service,
    Project project,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final tags = List<String>.from(project.tags);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.projectDetailTagsQuickAction),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            onDeleted: () =>
                                setDialogState(() => tags.remove(tag)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.projectDetailAddTagHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      final t = value.trim();
                      if (t.isNotEmpty && !tags.contains(t)) {
                        setDialogState(() => tags.add(t));
                      }
                      controller.clear();
                    },
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
                  service.setProjectTags(widget.projectId, tags);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// .niashare（共有用ファイル）を作成し、共有シートを表示する。
  Future<void> _createNiashare(
    BuildContext context,
    ProjectService service,
    Project project,
  ) async {
    final includeOptions = await showMaterialIncludeDialog(context);
    if (includeOptions == null || !context.mounted) return; // キャンセル
    final l10n = AppLocalizations.of(context)!;
    final materialService = context.read<MaterialService>();
    final fontService = context.read<FontService>();
    final scenes = service.scenesOf(project.id);
    final tileManager = service.tileManagerOf(project.id);
    try {
      final bundle = await materialService.buildShareBundle(
        project.id,
        includeOptions.materialTypes,
      );
      final fontBundle = includeOptions.includeFonts
          ? await buildFontShareBundle(service, fontService, project.id)
          : (files: <String, Uint8List>{}, manifest: null);
      final file = await NiaproSerializer.saveShare(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        materialFiles: bundle.files.isEmpty ? null : bundle.files,
        materialsManifest: bundle.manifest,
        fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
        fontsManifest: fontBundle.manifest,
      );
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.projectDetailNiashareFailedSnackbar('$e'))),
      );
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // ラベル・値とも、OSの文字サイズ設定（textScaler）を大きくすると
      // 行幅を超えてRenderFlexオーバーフローになっていたため、両方を
      // Flexibleにして折り返し・省略できるようにする。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  void _showRenameDialog(BuildContext context, String currentName) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.commonRename),
          content: TextField(
            controller: controller,
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
                context.read<ProjectService>().renameProject(
                  widget.projectId,
                  controller.text,
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonChange),
            ),
          ],
        ),
      ),
    );
  }
}
