import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/font_fallback.dart';
import '../../l10n/app_localizations.dart';
import '../../services/frame_thumbnail_renderer.dart';
import '../../services/home_widget_refresh.dart';
import '../../services/home_widget_service.dart';
import '../../services/project_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/sort_mode_control.dart';
import '../../widgets/stepped_slider.dart';
import '../home/home_screen.dart';
import '../home/widgets/project_list_widget.dart';

/// 起動画面ウィジェットに表示するフレームを選ぶフロー（2画面構成）。
///
/// 1. [WidgetArtworkPickerScreen]：作品を一覧から選ぶ（サムネイル＋タイトル）
/// 2. [WidgetArtworkFramePickerScreen]：その作品の中からフレームを選ぶ
///    （シーンが複数あればシーンも選べる。プレビューつき）
///
/// フレームをタップした時点で確定・保存し、両画面を一気に閉じて設定画面
/// （呼び出し元）へ戻る。

/// 手順1：作品を選ぶ一覧画面。
///
/// ホーム画面の「プロジェクト」タブが使っている[ProjectListWidget]を
/// そのまま流用し、並び替え・表示方法（大/中/小/詳細）切り替え・検索・
/// お気に入り絞り込み・フォルダ移動をこの選択画面でも使えるようにしている。
/// タップの意味だけが「詳細画面を開く」から「選んでフレーム選択画面へ進む」
/// に変わる（[ProjectListWidget.onPickProject]参照）。
class WidgetArtworkPickerScreen extends StatefulWidget {
  const WidgetArtworkPickerScreen({super.key});

  @override
  State<WidgetArtworkPickerScreen> createState() =>
      _WidgetArtworkPickerScreenState();
}

class _WidgetArtworkPickerScreenState extends State<WidgetArtworkPickerScreen> {
  // ホーム画面のプロジェクトタブ（_HomeScreenState）と同じ並び替え基準・
  // 表示方法・検索・お気に入り絞り込みの状態を、この選択画面専用に持つ
  // （見た目・操作性を完全に揃えるが、状態そのものはホーム画面と共有しない
  // ＝ここでの並び替えや検索はホーム画面側には影響しない）。
  ProjectViewMode _viewMode = ProjectViewMode.medium;
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  bool _showFavoritesOnly = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String? _currentFolderId;

  bool get _sortByName =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.nameDesc;
  bool get _sortAscending =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.updatedAsc;

  void _setSortByName(bool byName) {
    setState(() {
      _sortMode = byName
          ? (_sortAscending
                ? ProjectSortMode.nameAsc
                : ProjectSortMode.nameDesc)
          : (_sortAscending
                ? ProjectSortMode.updatedAsc
                : ProjectSortMode.updatedDesc);
    });
  }

  void _toggleSortDirection() {
    setState(() {
      _sortMode = switch (_sortMode) {
        ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
        ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
        ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
        ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
      };
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _clearSelection(BuildContext context) async {
    final widgets = context.read<HomeWidgetService>();
    await widgets.selectArtwork();
    if (context.mounted) {
      await refreshHomeWidgets(
        widgets: widgets,
        projects: context.read<ProjectService>(),
        theme: context.read<ThemeService>(),
      );
    }
    if (context.mounted) context.pop();
  }

  /// フォルダ階層のパンくずリスト（home_screen.dartの
  /// `_HomeScreenState._buildBreadcrumb`と同じ方式・見た目）。
  /// ホームアイコンでルートへ、各フォルダ名でその階層へ移動する。
  Widget _buildBreadcrumb(BuildContext context) {
    if (_currentFolderId == null) return const SizedBox.shrink();
    final folders = context.watch<ProjectService>().folders;
    final chain = <ProjectFolder>[];
    String? current = _currentFolderId;
    while (current != null) {
      final folder = folders.where((f) => f.id == current).firstOrNull;
      if (folder == null) break;
      chain.insert(0, folder);
      current = folder.parentFolderId;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () => setState(() => _currentFolderId = null),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.home, size: 18),
              ),
            ),
            for (final folder in chain) ...[
              const Icon(Icons.chevron_right, size: 16),
              InkWell(
                onTap: () => setState(() => _currentFolderId = folder.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = context.watch<HomeWidgetService>();
    final scheme = Theme.of(context).colorScheme;
    final hasAnyProjects = context.watch<ProjectService>().projects.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.homeSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : SortModeControl(
                sortByName: _sortByName,
                sortAscending: _sortAscending,
                onSortByNameChanged: _setSortByName,
                onToggleDirection: _toggleSortDirection,
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClose,
              onPressed: () => setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            )
          else ...[
            PopupMenuButton<ProjectViewMode>(
              icon: const Icon(Icons.view_module),
              onSelected: (mode) => setState(() => _viewMode = mode),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: ProjectViewMode.large,
                  child: Text(l10n.homeViewModeLarge),
                ),
                PopupMenuItem(
                  value: ProjectViewMode.medium,
                  child: Text(l10n.homeViewModeMedium),
                ),
                PopupMenuItem(
                  value: ProjectViewMode.small,
                  child: Text(l10n.homeViewModeSmall),
                ),
                PopupMenuItem(
                  value: ProjectViewMode.detail,
                  child: Text(l10n.homeViewModeDetail),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.commonSearch,
              onPressed: () => setState(() => _isSearching = true),
            ),
          ],
        ],
      ),
      body: desktopCentered(
        context,
        !hasAnyProjects
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.widgetNoProjects,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                children: [
                  // 「選ばない」状態へ戻すための選択肢。並び替え・検索・
                  // フォルダ移動の影響を受けないよう、一覧の外に固定表示する。
                  Card(
                    margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    color: scheme.surfaceContainerHigh,
                    child: ListTile(
                      leading: Icon(
                        Icons.block_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.widgetArtworkNone),
                      selected: widgets.projectId == null,
                      onTap: () => _clearSelection(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text(
                            l10n.homeFavoritesOnly,
                            style: const TextStyle(
                              fontFamily: 'Kuramubon',
                              fontFamilyFallback: kHeadingFontFallback,
                            ),
                          ),
                          selected: _showFavoritesOnly,
                          onSelected: (v) =>
                              setState(() => _showFavoritesOnly = v),
                        ),
                      ],
                    ),
                  ),
                  // フォルダ内移動時のパンくずリスト。検索中は全体から検索
                  // するため非表示にする（home_screen.dartと同じ判断基準）。
                  if (_searchQuery.trim().isEmpty) _buildBreadcrumb(context),
                  Expanded(
                    child: ProjectListWidget(
                      viewMode: _viewMode,
                      sortMode: _sortMode,
                      isSelectionMode: false,
                      selectedIds: const {},
                      onLongPress: (_) {},
                      onSelectionChanged: (_) {},
                      currentFolderId: _currentFolderId,
                      onOpenFolder: (id) =>
                          setState(() => _currentFolderId = id),
                      showFavoritesOnly: _showFavoritesOnly,
                      searchQuery: _searchQuery,
                      showEmptyCreateHint: false,
                      onPickProject: (id) =>
                          context.push('/settings/widget/artwork/$id'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 手順2：作品内のフレームを選ぶ画面。
class WidgetArtworkFramePickerScreen extends StatefulWidget {
  final String projectId;
  const WidgetArtworkFramePickerScreen({super.key, required this.projectId});

  @override
  State<WidgetArtworkFramePickerScreen> createState() =>
      _WidgetArtworkFramePickerScreenState();
}

class _WidgetArtworkFramePickerScreenState
    extends State<WidgetArtworkFramePickerScreen> {
  String? _sceneId;
  int _highlighted = 0;
  final _stripScroll = ScrollController();
  static const _stripItemExtent = 56.0;

  // タイムラインモードの再生バー（_TimelineScreenState._togglePlay等）と
  // 同じ操作感（先頭へ／1フレーム戻る／再生・一時停止／1フレーム進む／
  // 最終へ、およびシークバー）をこの画面にも用意する。タイムライン画面は
  // クリップ・トラックまで含む巨大なStateのため直接は流用できず、
  // このロジック（Timer.periodicでfpsに合わせて1フレームずつ進める）
  // だけを同じ挙動になるよう独立して実装している。
  bool _isPlaying = false;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    // 同じ作品を選び直す場合は、前回選んでいたシーン・フレームを
    // 初期選択にする。
    final widgets = context.read<HomeWidgetService>();
    if (widgets.projectId == widget.projectId) {
      _sceneId = widgets.sceneId;
      _highlighted = widgets.frameIndex ?? 0;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollStripToHighlighted(animate: false),
    );
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _stripScroll.dispose();
    super.dispose();
  }

  void _scrollStripToHighlighted({required bool animate}) {
    if (!_stripScroll.hasClients) return;
    final target = (_highlighted * _stripItemExtent).clamp(
      0.0,
      _stripScroll.position.maxScrollExtent,
    );
    if (animate) {
      _stripScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _stripScroll.jumpTo(target);
    }
  }

  /// 再生中でなければ何もしない、再生中なら止めて位置だけ確定する
  /// （シークバー操作・コマ送り操作・シーン切り替え等、再生を中断すべき
  /// 全ての操作から呼ぶ）。
  void _stopPlaying() {
    if (!_isPlaying) return;
    _playTimer?.cancel();
    _isPlaying = false;
  }

  void _jumpTo(int index, int total) {
    setState(() {
      _stopPlaying();
      _highlighted = index.clamp(0, total - 1);
    });
    _scrollStripToHighlighted(animate: true);
  }

  void _stepFrame(int delta, int total) {
    _jumpTo(_highlighted + delta, total);
  }

  void _togglePlay(int total, int fps) {
    if (_isPlaying) {
      setState(_stopPlaying);
      return;
    }
    if (total <= 1) return; // 1フレームしかない場合は再生の意味が無い
    _playTimer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (
      timer,
    ) {
      setState(() {
        // タイムラインモードの再生と同じく、末尾まで来たら先頭へ
        // ループする（この画面には再生停止のON/OFF設定は無く、
        // 「作りたいフレームを探しながら眺める」プレビュー用途のため
        // 常時ループでよい）。
        _highlighted = (_highlighted + 1) % total;
      });
      _scrollStripToHighlighted(animate: false);
    });
    setState(() => _isPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.watch<ProjectService>();
    final scheme = Theme.of(context).colorScheme;
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final scenes = ps.scenesOf(widget.projectId);
    final sceneId = (_sceneId != null && scenes.any((s) => s.id == _sceneId))
        ? _sceneId!
        : (scenes.isEmpty ? null : scenes.first.id);
    final scene = scenes.where((s) => s.id == sceneId).firstOrNull;
    final total = scene?.frames.length ?? 0;
    final highlighted = total == 0 ? 0 : _highlighted.clamp(0, total - 1);
    final fps = project?.fps ?? 24;

    return Scaffold(
      appBar: AppBar(title: Text(project?.name ?? '')),
      body: desktopCentered(
        context,
        (scene == null || scene.frames.isEmpty)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.widgetArtworkNoFrames,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      l10n.widgetArtworkFramePickerHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (scenes.length > 1) ...[
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: scenes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final s = scenes[i];
                          return ChoiceChip(
                            label: Text(s.displayName),
                            selected: s.id == sceneId,
                            onSelected: (_) => setState(() {
                              _stopPlaying();
                              _sceneId = s.id;
                              _highlighted = 0;
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // タイムラインモードと同じ「大きなプレビュー＋下に
                  // フレーム一覧＋現在地表示」の構成。フレーム一覧の
                  // タップは即確定せず、まずここでプレビューが差し替わる
                  // （実際にタイムラインで動画をスクラブする感覚に揃える）。
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: scheme.surfaceContainerHigh,
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            // keyを付けない：ArtworkFrameThumbnailは
                            // didUpdateWidgetでframeIndexの変化を検知して
                            // 再合成するため、keyで毎回作り直す必要はない。
                            // 再生プレビュー（_togglePlay）でframeIndexが
                            // 高頻度に変わる場面では、keyを付けると
                            // 毎ティックWidget自体を作り直すことになり
                            // 明確に不利（Stateの使い回しができない）。
                            child: ArtworkFrameThumbnail(
                              projectId: widget.projectId,
                              sceneId: scene.id,
                              frameIndex: highlighted,
                              maxSize: 480,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.widgetArtworkFrameNumberLabel(highlighted + 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  // タイムラインモードと同じシークバー＋再生コントロール
                  // （先頭へ／1フレーム戻る／再生・一時停止／1フレーム進む／
                  // 最終へ）。ドラッグ・タップどちらでも任意のフレームへ
                  // 直接移動でき、再生中は選んだ作品の実際のfpsで
                  // パラパラと自動再生してから止めるフレームを選べる。
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: SteppedSlider(
                        value: highlighted.toDouble(),
                        min: 0,
                        max: (total - 1).clamp(0, 1 << 30).toDouble(),
                        divisions: total > 1 ? total - 1 : null,
                        showSteppers: false,
                        onChanged: (v) => _jumpTo(v.round(), total),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: l10n.timelineSkipToStart,
                        onPressed: () => _jumpTo(0, total),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_rewind),
                        tooltip: l10n.timelineStepBack,
                        onPressed: () => _stepFrame(-1, total),
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        tooltip: _isPlaying
                            ? l10n.commonPause
                            : l10n.commonPlay,
                        onPressed: () => _togglePlay(total, fps),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fast_forward),
                        tooltip: l10n.timelineStepForward,
                        onPressed: () => _stepFrame(1, total),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        tooltip: l10n.timelineSkipToEnd,
                        onPressed: () => _jumpTo(total - 1, total),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 現在地（赤枠）表示つきのフレーム一覧。
                  // frame_strip_widget.dartと同じ、ビューポート中央に固定した
                  // 枠へストリップ側をスクロールさせる方式。
                  SizedBox(
                    height: 64,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final sidePadding =
                            ((constraints.maxWidth - _stripItemExtent) / 2)
                                .clamp(0.0, double.infinity);
                        return Stack(
                          children: [
                            ListView.builder(
                              controller: _stripScroll,
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: sidePadding,
                              ),
                              itemCount: total,
                              itemBuilder: (context, index) {
                                final isHighlighted = index == highlighted;
                                return GestureDetector(
                                  // 自動テスト（AIによる操作→キャプチャ→検証）が
                                  // フレームを番号指定でタップできるようにする
                                  // ためのKey。見た目・挙動には影響しない。
                                  key: ValueKey('widgetFrameStripCell$index'),
                                  onTap: () => _jumpTo(index, total),
                                  child: Container(
                                    width: _stripItemExtent - 8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: scheme.surfaceContainerHigh,
                                      // 中央固定の赤枠はスクロール中は現在地の
                                      // セルからずれて見えるため、選択中の
                                      // セル自体にも色を付けて見失わないよう
                                      // にする。
                                      border: Border.all(
                                        color: isHighlighted
                                            ? scheme.primary
                                            : scheme.outlineVariant,
                                        width: isHighlighted ? 2 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ArtworkFrameThumbnail(
                                      projectId: widget.projectId,
                                      sceneId: scene.id,
                                      frameIndex: index,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: _stripItemExtent,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: context
                                          .watch<ThemeService>()
                                          .current
                                          .updateMarkColor,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            _confirm(context, sceneId!, highlighted),
                        icon: const Icon(Icons.check),
                        label: Text(l10n.widgetArtworkFramePickerConfirmButton),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, String sceneId, int index) async {
    final widgets = context.read<HomeWidgetService>();
    await widgets.selectArtwork(
      projectId: widget.projectId,
      sceneId: sceneId,
      frameIndex: index,
    );
    if (context.mounted) {
      await refreshHomeWidgets(
        widgets: widgets,
        projects: context.read<ProjectService>(),
        theme: context.read<ThemeService>(),
      );
    }
    if (context.mounted) {
      // 作品一覧・フレーム選択の2画面ぶん一気に戻り、呼び出し元の
      // 設定画面へ着地する。
      final router = GoRouter.of(context);
      router.pop();
      router.pop();
    }
  }
}

/// フレーム1枚を実際に合成してサムネイル表示するウィジェット。
///
/// ホーム画面ウィジェット設定の要約行（[projectId]のみ指定）と、
/// フレーム選択グリッドの各セル（[sceneId]・[frameIndex]も指定）の
/// 両方で共有する。[compositeFrameThumbnail]と同じ既定（先頭シーン・
/// 先頭フレーム）を使うため、[sceneId]・[frameIndex]は省略できる。
class ArtworkFrameThumbnail extends StatefulWidget {
  final String projectId;
  final String? sceneId;
  final int? frameIndex;
  final int maxSize;

  const ArtworkFrameThumbnail({
    super.key,
    required this.projectId,
    this.sceneId,
    this.frameIndex,
    this.maxSize = 200,
  });

  @override
  State<ArtworkFrameThumbnail> createState() => _ArtworkFrameThumbnailState();
}

class _ArtworkFrameThumbnailState extends State<ArtworkFrameThumbnail> {
  ui.Image? _image;
  // frameIndexが短時間に連続して変わる場面（フレーム選択画面の再生
  // プレビュー等）では、前の合成が終わる前に次の合成が始まりうる。
  // 呼び出しごとに採番し、結果を受け取った時点で最新の要求かどうかを
  // 確認することで、遅れて返ってきた古い合成結果が新しいフレームの
  // 表示を上書きしてしまう競合を防ぐ。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(covariant ArtworkFrameThumbnail old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId ||
        old.sceneId != widget.sceneId ||
        old.frameIndex != widget.frameIndex ||
        old.maxSize != widget.maxSize) {
      _generate();
    }
  }

  Future<void> _generate() async {
    final generation = ++_generation;
    final ps = context.read<ProjectService>();
    final image = await compositeFrameThumbnail(
      ps,
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      maxSize: widget.maxSize,
    );
    if (!mounted || generation != _generation) {
      // mounted=false（画面自体が破棄された）、またはこの呼び出しより後の
      // _generate()が既に走っている（この結果はもう古い）。
      image?.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = image);
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
    if (image == null) {
      return Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return RawImage(image: image, fit: BoxFit.cover);
  }
}
