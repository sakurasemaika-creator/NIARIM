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
import '../../widgets/project_not_found_view.dart';
import '../../widgets/autofill_preset_selection_sheet.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/frame_preview_background.dart';
import '../../widgets/moved_to_trash_snack_bar.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/stepped_slider.dart';
import '../../config/font_fallback.dart';
import '../../utils/duplicate_name.dart';
import '../../utils/folder_tree.dart';
import '../home/widgets/project_list_widget.dart'
    show showMaterialIncludeDialog, buildFontShareBundle;
import '../../config/accent_text_theme.dart';

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
  bool _loopPlayback = true;
  bool _rendering = false;
  // 描いている間に別のフレームが選ばれた（早いシーク・再生）。描き終えてから
  // 最新のフレームを描き直す（そのまま捨てると、止めた所と違う絵が残った）。
  bool _renderAgain = false;
  // この画面が一番上に戻ってきたら（キャンバス・タイムライン等から）、
  // 編集された絵を描き直す。
  bool _wasCurrent = true;
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
    if (flat.isEmpty) return;
    if (_rendering) {
      _renderAgain = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _renderAgain = false;
        // 描いている間にフレームが足された・消された場合も、今の並びで描く。
        final frames = _flatten(ps);
        if (frames.isEmpty) return;
        final entry = frames[_frameIndex.clamp(0, frames.length - 1)];
        final tileManager = ps.tileManagerOf(widget.projectId);
        // 書き出し・タイムラインのプレビューと同じ重なり順とマスク。
        final stacked = ps.stackedLayersOf(
          widget.projectId,
          entry.sceneId,
          entry.frameIndex,
        );
        final img = await LayerCompositor.composite(
          tileManager,
          stacked.layers,
          (l) => ps.tileKeyFor(
            widget.projectId,
            entry.sceneId,
            entry.frameIndex,
            l.id,
          ),
          tileManager.canvasWidth,
          tileManager.canvasHeight,
          paperColor: LayerCompositor.paperForBlendModes(
            stacked.layers,
            ps.projects
                .where((p) => p.id == widget.projectId)
                .firstOrNull
                ?.backgroundColor,
          ),
          maskGroups: stacked.maskGroups,
        );
        if (!mounted) {
          img.dispose();
          return;
        }
        final old = _previewImage;
        setState(() => _previewImage = img);
        old?.dispose();
      } while (_renderAgain);
    } finally {
      _rendering = false;
    }
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
      return const ProjectNotFoundView(
        homeButtonKey: Key('projectDetailNotFoundHome'),
      );
    }

    final flat = _flatten(projectService);
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent && !_wasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _renderFrame(projectService, flat),
      );
    }
    _wasCurrent = isCurrent;
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
                  projectService.duplicateProject(
                    widget.projectId,
                    name: duplicateProjectName(
                      l10n,
                      project.name,
                      folderId: project.folderId,
                      projects: projectService.projects,
                    ),
                  );
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
                    // ホームの一覧と同じく、その場で元に戻せる。
                    final messenger = ScaffoldMessenger.of(context);
                    projectService.deleteProject(widget.projectId);
                    showMovedToTrashSnackBar(messenger, l10n, projectService, [
                      widget.projectId,
                    ]);
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
              _QuickActionsRow(
                key: const Key('projectDetailQuickActions'),
                children: [
                  (
                    icon: Icons.folder_outlined,
                    label: l10n.creativePanelFolderButton,
                    iconColor: null,
                    onTap: () =>
                        _showMoveToFolderDialog(context, projectService),
                  ),
                  (
                    icon: Icons.sell_outlined,
                    label: l10n.projectDetailTagsQuickAction,
                    iconColor: null,
                    onTap: () =>
                        _showTagsDialog(context, projectService, project),
                  ),
                  (
                    icon: project.isFavorite ? Icons.star : Icons.star_border,
                    label: project.isFavorite
                        ? l10n.projectDetailFavoriteRegistered
                        : l10n.projectDetailFavoriteUnregistered,
                    iconColor: project.isFavorite
                        ? AccentTextTheme.of(context)
                        : null,
                    onTap: () =>
                        projectService.toggleFavorite(widget.projectId),
                  ),
                  (
                    icon: Icons.ios_share,
                    label: l10n.projectDetailShareQuickAction,
                    iconColor: null,
                    onTap: () =>
                        _createNiashare(context, projectService, project),
                  ),
                ],
                // Keep the loop control directly beside Share.
                trailing: _buildLoopButton(),
                trailingWidth: _loopButtonWidth,
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
    // 絵の縦横比のまま、絵の範囲にだけ作品の背景色（透明なら市松模様）を
    // 敷く（16:9の枠いっぱいに背景色を塗ると、縦長の絵の左右まで絵の一部に
    // 見え、透明の作品は何も見えなかった）。
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: FramePreviewBackground(
          key: const Key('projectDetailPreviewArtwork'),
          backgroundColor: project.backgroundColor,
          aspectRatio: project.exportHeight > 0
              ? project.exportWidth / project.exportHeight
              : null,
          child: _previewImage != null
              ? RawImage(image: _previewImage, fit: BoxFit.contain)
              : Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 48,
                    color: theme.textColor.withValues(alpha: 0.38),
                  ),
                ),
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

  static const double _loopButtonWidth = 44;

  Widget _buildLoopButton() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      toggled: _loopPlayback,
      child: IconButton(
        key: const Key('projectDetailLoopButton'),
        tooltip: _loopPlayback
            ? l10n.timelineLoopOnTooltip
            : l10n.timelineLoopOffTooltip,
        onPressed: () => setState(() => _loopPlayback = !_loopPlayback),
        icon: Icon(
          Icons.repeat,
          color: _loopPlayback
              ? AccentTextTheme.of(context)
              : scheme.onSurfaceVariant,
          size: 22,
        ),
        constraints: const BoxConstraints.tightFor(
          width: _loopButtonWidth,
          height: 48,
        ),
        visualDensity: VisualDensity.compact,
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

  void _showMoveToFolderDialog(BuildContext context, ProjectService service) {
    final tree = folderTree(service.folders);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: [for (final entry in tree) entry.folder],
        depths: {for (final entry in tree) entry.folder.id: entry.depth},
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
          builder: (ctx, setDialogState) {
            // 欄に打ったまま保存しても、打ったタグを捨てない。
            void addTyped() {
              final t = controller.text.trim();
              if (t.isNotEmpty && !tags.contains(t)) {
                setDialogState(() => tags.add(t));
              }
              controller.clear();
            }

            return AlertDialog(
              scrollable: true,
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
                      // Enterで足した後も欄から抜けず、続けて打てる。
                      onEditingComplete: () {},
                      onSubmitted: (_) => addTyped(),
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
                    addTyped();
                    service.setProjectTags(widget.projectId, tags);
                    Navigator.pop(ctx);
                  },
                  child: Text(l10n.commonSave),
                ),
              ],
            );
          },
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
    final service = context.read<ProjectService>();
    showDialog(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.commonRename,
        initialName: currentName,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        onSubmit: (name) async {
          if (name != currentName) {
            await service.renameProject(widget.projectId, name);
          }
        },
      ),
    );
  }
}

typedef _QuickAction = ({
  IconData icon,
  String label,
  Color? iconColor,
  VoidCallback onTap,
});

/// 詳細画面のフォルダ・タグ・お気に入り・共有。ふだんは4つを1行に並べ、
/// 長い言葉（フランス語の「Étiquettes」等）が大きな文字で欄に収まらない
/// ときは、語の途中で折らずに2列・1列にする。[trailing]（ループ）は最後の
/// 行の右端、つまり共有のすぐ隣に置く。
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    super.key,
    required this.children,
    this.trailing,
    this.trailingWidth = 0,
  });

  final List<_QuickAction> children;
  final Widget? trailing;
  final double trailingWidth;

  static const _labelStyle = TextStyle(fontSize: 12);

  // 漢字・かなは字の間で折ってよいので、それ以外の語の幅だけを測る。
  static final _cjk = RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uf900-\ufaff]');

  double _longestWord(BuildContext context, String label) {
    var widest = 0.0;
    for (final word in label.split(RegExp(r'\s+'))) {
      if (word.isEmpty || _cjk.hasMatch(word)) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: word,
          style: DefaultTextStyle.of(context).style.merge(_labelStyle),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final widest = children
          .map((a) => _longestWord(context, a.label))
          .fold<double>(0, (a, b) => a > b ? a : b);
      // 1欄の中で文字に使える幅（左右の余白ぶんを引く）。ループを最後の行の
      // 右に置くと1列でも語が入らないときだけ、ループを次の行へ下ろして
      // 欄に横幅をすべて使う。
      final besideFits = widest <= constraints.maxWidth - trailingWidth - 8;
      final available =
          constraints.maxWidth - (besideFits ? trailingWidth : 0);
      final columns = [
        4,
        2,
        1,
      ].firstWhere((n) => widest <= available / n - 8, orElse: () => 1);
      final width = (available / columns).floorToDouble();
      Widget cell(_QuickAction action) => SizedBox(
        width: width,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              children: [
                Icon(
                  action.icon,
                  color:
                      action.iconColor ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: _labelStyle,
                ),
              ],
            ),
          ),
        ),
      );
      final rows = [
        for (var i = 0; i < children.length; i += columns)
          children.sublist(
            i,
            i + columns < children.length ? i + columns : children.length,
          ),
      ];
      return Column(
        children: [
          for (final (index, row) in rows.indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final action in row) cell(action),
                const Spacer(),
                if (besideFits && index == rows.length - 1 && trailing != null)
                  trailing!
                else if (besideFits)
                  SizedBox(width: trailingWidth),
              ],
            ),
          if (!besideFits && trailing != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
        ],
      );
    },
  );
}
