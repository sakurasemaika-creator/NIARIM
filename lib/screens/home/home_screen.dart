import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../engine/export_engine.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/api/community_api.dart';
import '../../services/font_service.dart';
import '../../services/export_share_service.dart';
import '../../services/project_service.dart';
import '../../services/outgoing_share_library.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/work_folder_service.dart';
import '../../models/shortcut_binding.dart';
import '../../widgets/export_share_feedback.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/sort_mode_control.dart';
import '../../widgets/project_trash_dialog.dart';
import '../../widgets/share_project_file_action.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/home_selection_toolbar.dart';
import 'widgets/home_drawer.dart';
import 'widgets/exported_work_card.dart';
import 'widgets/exported_work_preview_layout.dart';
import 'widgets/folder_delete_dialog.dart';
import 'widgets/folder_save_feedback.dart';
import 'widgets/work_folder_move_sheet.dart';
import '../../config/font_fallback.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/color_contrast.dart';
import '../../utils/responsive_tile_defaults.dart';
import '../../utils/tolerant_preferences.dart';
import '../canvas/widgets/canvas_icon_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // The menu opens from the right; the launch-screen back arrow sits at the
  // left of the fixed AppBar. The page-level project list has its own scroll.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _missionDrawerRefreshToken = 0;
  String? _lastVisitRequest;
  void _maybeRecordLogin(String? ownerId, CommunityApi? api) {
    if (ownerId == null || api == null) return;
    // Local date merely suppresses redundant traffic. The server determines
    // the actual JST day and checks the visit transaction atomically.
    final day = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 9))
        .toIso8601String()
        .substring(0, 10);
    final requestKey = '$ownerId/$day';
    if (_lastVisitRequest == requestKey) return;
    _lastVisitRequest = requestKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          context.read<GoogleAuthService>().account?.id != ownerId ||
          !identical(context.read<CommunityService>().api, api)) {
        return;
      }
      try {
        await api.visitLoginBonus();
      } catch (error) {
        debugPrint('Cumulative login visit could not be saved: $error');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _maybeRecordLogin(
        context.read<GoogleAuthService>().account?.id,
        context.read<CommunityService>().api,
      );
    }
  }

  final _projectScrollController = ScrollController();
  late TabController _tabController;
  static const _projectViewModeKey = 'home.projectViewMode.v1';
  ProjectViewMode? _userViewMode;

  ProjectViewMode _effectiveViewMode(BuildContext context) =>
      _userViewMode ??
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };

  Future<void> _loadProjectViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.readString(_projectViewModeKey);
      if (!mounted || saved == null) return;
      for (final mode in ProjectViewMode.values) {
        if (mode.name == saved) {
          setState(() => _userViewMode = mode);
          return;
        }
      }
    } catch (error) {
      debugPrint('Project tile preference could not be restored: $error');
    }
  }

  Future<void> _selectProjectViewMode(ProjectViewMode mode) async {
    setState(() => _userViewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_projectViewModeKey, mode.name);
    } catch (error) {
      debugPrint('Project tile preference could not be saved: $error');
    }
  }

  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  // 複数選択モードの切り取り・コピー・貼り付け。フォルダ間の移動を手軽に
  // するための内部クリップボード（アプリを離れると保持しない、
  // セッション内のみのUI状態）。_clipboardIsCutがtrueなら切り取り（貼り付け
  // で移動し1回でクリップボードを空にする）、falseならコピー（貼り付けは
  // 複製し、繰り返し貼り付け可能）。フォルダは複製の実装を持たないため、
  // コピー時は選択にプロジェクトのみを含める（フォルダが混在していれば
  // コピー操作自体を無効化する）。
  final Set<String> _clipboardProjectIds = {};
  final Set<String> _clipboardFolderIds = {};
  bool _clipboardIsCut = false;
  bool _showFavoritesOnly = false;
  bool _isSearching = false;
  // false: project/folder name keyword search, true: project tag search.
  // The search bar toggle swaps these modes like a play/pause control.
  bool _searchByTag = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  StreamSubscription<String>? _sharedFileSub;
  // 現在開いているフォルダ（フォルダは複数階層に対応・
  // パンくずリストで現在位置を表示）。nullはルート直下。
  String? _currentFolderId;
  // 新規追加系のFAB（＋ボタン）はプロジェクトタブ・作品一覧タブでのみ
  // 表示する（ブクマ済みタブに新規作成の導線があるのは不自然なため）。
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        final wasSearching = _isSearching;
        setState(() {
          _currentTabIndex = _tabController.index;
          if (_currentTabIndex != 0) {
            _selectedIds.clear();
            _isSelectionMode = false;
            _resetProjectSearch();
          }
        });
        if (wasSearching && _currentTabIndex != 0) {
          _searchFocus.unfocus();
        }
      }
    });
    _loadProjectViewMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
      _initShareIntentHandling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _projectScrollController.dispose();
    _sharedFileSub?.cancel();
    super.dispose();
  }

  /// .niashare受信フロー：OSから共有ファイルを開いた場合の処理。
  void _initShareIntentHandling() {
    final service = context.read<ShareIntentService>();
    final initialUri = service.pendingInitialUri;
    if (initialUri != null) {
      service.pendingInitialUri = null;
      _handleSharedUri(initialUri);
    }
    _sharedFileSub = service.onFileReceived.listen(_handleSharedUri);
  }

  Future<void> _handleSharedUri(String uri) async {
    String localPath;
    if (uri.startsWith('file://')) {
      localPath = Uri.parse(uri).toFilePath();
    } else {
      final bytes = await context.read<ShareIntentService>().readUriBytes(uri);
      if (bytes == null) return;
      final tmpDir = await getTemporaryDirectory();
      final file = File(
        '${tmpDir.path}/shared_${DateTime.now().millisecondsSinceEpoch}.niashare',
      );
      await file.writeAsBytes(bytes);
      localPath = file.path;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homeShareFileDialogTitle),
        content: Text(l10n.homeShareFileDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    try {
      final data = await NiaproSerializer.loadShare(localPath);
      if (!mounted) return;
      final projectService = context.read<ProjectService>();
      final project = await projectService.importSharedProject(data);
      if (!mounted) return;
      // 同梱フォント（「フォントを含める」選択時）を取り込み登録する。
      final fontService = context.read<FontService>();
      final bundledFonts = NiaproSerializer.bundledFonts(data);
      for (final font in bundledFonts) {
        await fontService.importBundledFont(
          id: font.id,
          displayName: font.displayName,
          fileName: font.fileName,
          bytes: font.bytes,
        );
      }
      // 不足フォント検出（「不足フォントがあります。○○」を表示）：
      // プロジェクトが使用するユーザー追加フォントのうち、同梱もされておらず
      // 端末側にも存在しないものを警告する。
      if (!mounted) return;
      final usedFamilies = projectService.usedFontFamiliesOf(project.id);
      final installedFamilies = fontService.fonts
          .map(fontService.familyNameOf)
          .toSet();
      final missing = usedFamilies.where(
        (f) => f.startsWith('UserFont_') && !installedFamilies.contains(f),
      );
      if (missing.isNotEmpty) {
        final names = missing
            .map((f) => f.replaceFirst('UserFont_', ''))
            .join('、');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeMissingFontsSnackbar(names))),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeSharedImportedSnackbar)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.homeSharedImportFailedSnackbar(e.toString())),
        ),
      );
    }
  }

  void _checkFirstLaunch() {
    final settings = context.read<SettingsService>();
    if (!settings.isFirstLaunch) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _FirstLaunchDialog(onDone: settings.markFirstLaunchDone),
    );
  }

  // 現在の並び替えが名前基準かどうか（項目自体はProjectSortMode
  // ［名前昇順/降順・更新日時昇順/降順］の4値のままだが、UI上は
  // 「項目（名前／更新日時）」と「昇順/降順」を別々の操作にする）。
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final windowHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewPaddingOf(context).vertical;
    // A header action keeps the saved works body tall enough for large text.
    final workActionInHeader = _currentTabIndex == 1 && windowHeight < 320;
    _maybeRecordLogin(
      context.watch<GoogleAuthService>().account?.id,
      context.read<CommunityService>().api,
    );

    // マウス/キーボード入力・左手デバイス：設定画面「ショートカット設定」
    // で割り当てたキーで、全選択・コピー・切り取り・貼り付けを
    // 行えるようにする。
    final content = CallbackShortcuts(
      bindings: _buildShortcutBindings(context),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              key: const Key('homeBackToSplashButton'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.homeBackToSplashTooltip,
              onPressed: () => context.go('/'),
            ),
            title: _currentTabIndex != 0
                ? Text(
                    switch (_currentTabIndex) {
                      1 => l10n.homeTabWorks,
                      2 => l10n.homeTabShared,
                      3 => l10n.homeTabTrash,
                      _ => l10n.homeTabProjects,
                    },
                  )
                : _isSearching
                ? Row(
                    children: [
                      // The icon always represents the mode we can switch TO:
                      // keyword mode -> tag icon, tag mode -> search icon.
                      IconButton(
                        icon: Icon(
                          _searchByTag ? Icons.search : Icons.sell_outlined,
                        ),
                        tooltip: _searchByTag
                            ? l10n.homeSearchHint
                            : l10n.projectDetailTagsQuickAction,
                        onPressed: () => _changeProjectScope(
                          () => _searchByTag = !_searchByTag,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: _searchByTag
                                ? l10n.projectDetailTagsQuickAction
                                : l10n.homeSearchHint,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) =>
                              _changeProjectScope(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  )
                : Text(l10n.homeTabProjects),
            actions: [
              if (_currentTabIndex == 0) ...[
                // ヘルプ・設定は左側ハンバーガーメニュー（HomeDrawer）に既に存在するため、
                // トップ画面右上からは重複表示を削除した。
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.commonClose,
                    onPressed: _closeProjectSearch,
                  )
                else ...[
                  if (_hasClipboard)
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: l10n.homePasteTooltip(
                        _clipboardProjectIds.length +
                            _clipboardFolderIds.length,
                      ),
                      onPressed: _pasting ? null : _pasteClipboard,
                    ),
                  PopupMenuButton<ProjectViewMode>(
                    icon: const Icon(Icons.view_module),
                    onSelected: _selectProjectViewMode,
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
                    onPressed: _openProjectSearch,
                  ),
                ],
              ],
              if (workActionInHeader)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _buildCreateWorkFolderAction(
                    context,
                    l10n,
                    compact: true,
                  ),
                ),
              IconButton(
                key: const Key('homeMenuButton'),
                icon: const Icon(Icons.menu),
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: () {
                  // Refresh server-owned mission status only when the drawer
                  // is opened, never with an endless polling timer.
                  setState(() => _missionDrawerRefreshToken++);
                  _scaffoldKey.currentState?.openEndDrawer();
                },
              ),
            ],
            // 標準のTabBarは項目名の文字数に関わらず均等4分割になるため、
            // 「プロジェクト」のように長い項目名が「共有」等の短い項目名と
            // 同じ幅しか確保できず、文字が見切れてしまっていた。各項目名の
            // 実際の描画幅を計測し、その比率でタブ幅を配分する独自実装へ
            // 差し替える（TabControllerは共通のまま、TabBarViewとの
            // スワイプ連動はそのまま維持される）。
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: _HomeTabBar(
                controller: _tabController,
                currentIndex: _currentTabIndex,
                labels: [
                  l10n.homeTabProjects,
                  l10n.homeTabWorks,
                  l10n.homeTabShared,
                  l10n.homeTabTrash,
                ],
              ),
            ),
          ),
          endDrawer: HomeDrawer(refreshToken: _missionDrawerRefreshToken),
          body: Column(
            children: [
              if (_isSelectionMode)
                HomeSelectionToolbar(
                  selectedCount: _selectedIds.length,
                  onSelectAll: _selectAllInCurrentFolder,
                  onDeselectAll: _endProjectSelection,
                  onCut: _selectedIds.isEmpty ? null : _cutSelected,
                  onCopy:
                      _selectedIds.isNotEmpty &&
                          _selectedIds.every(
                            (id) => context.read<ProjectService>().projects.any(
                              (p) => p.id == id,
                            ),
                          )
                      ? _copySelected
                      : null,
                  onTrash: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ProjectListWidget(
                      scrollController: _projectScrollController,
                      header: Column(
                        children: [
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
                                    style: TextStyle(
                                      fontFamily: 'Kuramubon',
                                      fontFamilyFallback: kHeadingFontFallback,
                                      color: _showFavoritesOnly
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : null,
                                    ),
                                  ),
                                  selectedColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  checkmarkColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  selected: _showFavoritesOnly,
                                  onSelected: (v) => _changeProjectScope(
                                    () => _showFavoritesOnly = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: SortModeControl(
                                      sortByName: _sortByName,
                                      sortAscending: _sortAscending,
                                      onSortByNameChanged: _setSortByName,
                                      onToggleDirection: _toggleSortDirection,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // フォルダ内移動時のパンくずリスト。検索中は
                          // 全体から検索するため非表示にする。
                          if (!_isSearching) _buildBreadcrumb(),
                        ],
                      ),
                      // Keep bounded browsing scopes rather than every typed query.
                      key: PageStorageKey((
                        'home-projects',
                        _effectiveViewMode(context),
                        _currentFolderId,
                        _showFavoritesOnly,
                        _isSearching,
                        _searchByTag,
                      )),
                      // 「共有」タブ（.niashareインポート由来）は別枠の
                      // 一覧のため、プロジェクトタブには表示しない。
                      projects: context
                          .watch<ProjectService>()
                          .projects
                          .where((p) => !p.isSharedImport)
                          .toList(),
                      viewMode: _effectiveViewMode(context),
                      sortMode: _sortMode,
                      isSelectionMode: _isSelectionMode,
                      selectedIds: _selectedIds,
                      // 長押しモードへ入ると同時に、長押しした項目自体も
                      // 選択状態にする（複数選択モードに入っただけで
                      // 何も選ばれていない状態を避ける）。
                      onLongPress: (id) => setState(() {
                        _isSelectionMode = true;
                        _selectedIds.add(id);
                      }),
                      onSelectionChanged: (id) => setState(() {
                        if (_selectedIds.contains(id)) {
                          _selectedIds.remove(id);
                        } else {
                          _selectedIds.add(id);
                        }
                        // 手動でのタップ操作によって選択が0件になった場合も、
                        // 「全解除」ボタンを押した時と同様に複数選択モードを
                        // 自動終了する。
                        if (_selectedIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      }),
                      showFavoritesOnly: _showFavoritesOnly,
                      searchQuery: _searchQuery,
                      searchByTag: _searchByTag,
                      currentFolderId: _currentFolderId,
                      onOpenFolder: _openProjectFolder,
                    ),
                    const _WorksTab(key: PageStorageKey('home-works')),
                    const SharedScreen(
                      key: PageStorageKey('home-shared'),
                      embedded: true,
                    ),
                    const TrashScreen(
                      key: PageStorageKey('home-trash'),
                      embedded: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: workActionInHeader || _currentTabIndex >= 2
              ? null
              : _buildHomeActions(context, l10n),
        ),
      ),
    );
    return BackButtonListener(
      onBackButtonPressed: () async => _handleLocalBack(),
      child: PopScope<Object?>(
        canPop: !_hasLocalBackScope,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleLocalBack();
        },
        child: content,
      ),
    );
  }

  bool get _hasLocalBackScope =>
      _currentTabIndex == 0 &&
      (_isSelectionMode || _isSearching || _currentFolderId != null);

  bool _handleLocalBack() {
    // A dialog or pushed page owns Back until it closes.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isEndDrawerOpen ?? false) {
      scaffold!.closeEndDrawer();
      return true;
    }
    if (!_hasLocalBackScope) return false;
    if (_isSelectionMode) {
      _endProjectSelection();
    } else if (_isSearching) {
      _closeProjectSearch();
    } else {
      final parent = context
          .read<ProjectService>()
          .folders
          .where((folder) => folder.id == _currentFolderId)
          .firstOrNull
          ?.parentFolderId;
      _changeProjectScope(() => _currentFolderId = parent);
    }
    return true;
  }

  void _endProjectSelection() => setState(() {
    _selectedIds.clear();
    _isSelectionMode = false;
  });

  Widget _buildHomeAction(
    BuildContext context, {
    Key? key,
    required String heroTag,
    required String tooltip,
    required bool compact,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      key: key,
      heroTag: heroTag,
      mini: compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      tooltip: tooltip,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const CircleBorder(side: BorderSide.none),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  Widget _buildCreateWorkFolderAction(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) => _buildHomeAction(
    context,
    heroTag: 'home-add-work-folder',
    tooltip: l10n.homeAddSheetNewFolder,
    compact: compact,
    onPressed: () => showCreateFolderNameDialog(
      context,
      (name) => context.read<WorkFolderService>().createFolder(name),
    ),
    icon: Icons.create_new_folder_outlined,
  );

  Widget? _buildHomeActions(BuildContext context, AppLocalizations l10n) {
    if (_isSelectionMode || _currentTabIndex >= 2) return null;
    final compact = MediaQuery.sizeOf(context).height < 400;

    // The footer and the scrollable tab body have separate hit regions.
    final projects = _currentTabIndex == 0;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16, 0, 16, compact ? 8 : 16),
      child: Row(
        mainAxisAlignment: projects
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.end,
        children: [
          if (projects) ...[
            _buildHomeAction(
              context,
              compact: compact,
              key: const Key('homeScrollToTopFab'),
              heroTag: 'home-scroll-to-top',
              tooltip: l10n.communityScrollToTop,
              onPressed: () {
                if (!_projectScrollController.hasClients) return;
                _projectScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              icon: Icons.arrow_upward,
            ),
            _buildHomeAction(
              context,
              compact: compact,
              heroTag: 'home-add-project',
              tooltip: l10n.commonAdd,
              onPressed: () => _showAddChoiceSheet(context),
              icon: Icons.add,
            ),
          ] else
            _buildCreateWorkFolderAction(context, l10n, compact: compact),
        ],
      ),
    );
  }

  /// FABタップ時：新規プロジェクトか新規フォルダかを選ばせる（
  /// フォルダとプロジェクトを同一一覧内で扱う設計のため、どちらも一覧の
  /// ＋ボタンから作成できる必要がある）。
  void _showAddChoiceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.homeAddSheetNewProject),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-project');
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.homeAddSheetNewFolder),
              onTap: () {
                Navigator.pop(ctx);
                // 現在開いているフォルダの直下に作成する（ルートに固定しない）。
                showCreateFolderNameDialog(context, (name) async {
                  await context.read<ProjectService>().createFolder(
                    name,
                    parentFolderId: _currentFolderId,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSelected() {
    // ゴミ箱はプロジェクトのみが対象（ゴミ箱＝「削除したプロジェクト」）。
    // 選択にフォルダが含まれていても、フォルダ自体はここでは削除しない。
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final projectIds = service.projects.map((p) => p.id).toSet();
    final visibleIds = _visibleProjectIds(service);
    final targetIds = _selectedIds
        .where((id) => projectIds.contains(id) && visibleIds.contains(id))
        .toList();
    bool includesFavorite() => service.projects.any(
      (project) => targetIds.contains(project.id) && project.isFavorite,
    );
    if (includesFavorite()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
        );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: l10n.homeMoveToTrashConfirm(targetIds.length),
        confirmLabel: l10n.commonMove,
        itemNames: const [],
        pendingMessage: () => l10n.homeMoveToTrashConfirm(
          service.projects.where((p) => targetIds.contains(p.id)).length,
        ),
        pendingItemNames: () => service.projects
            .where((p) => targetIds.contains(p.id))
            .map((p) => p.name)
            .toList(),
        onApply: () async {
          // Validate the whole current selection before moving the first item.
          // The service also enforces protection when each queued write runs.
          if (includesFavorite()) throw const FavoriteProjectDeleteException();
          for (final id in targetIds) {
            await service.deleteProject(id);
            if (mounted) {
              setState(() {
                _selectedIds.remove(id);
                _isSelectionMode = _selectedIds.isNotEmpty;
              });
            }
          }
        },
      ),
    );
  }

  void _changeProjectScope(VoidCallback change) {
    setState(() {
      change();
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _resetProjectSearch() {
    _isSearching = false;
    _searchByTag = false;
    _searchQuery = '';
    _searchController.clear();
  }

  void _openProjectSearch() {
    _changeProjectScope(() => _isSearching = true);
    _searchFocus.requestFocus();
  }

  void _closeProjectSearch() {
    _searchFocus.unfocus();
    _changeProjectScope(_resetProjectSearch);
  }

  void _openProjectFolder(String id) {
    if (_isSearching) _searchFocus.unfocus();
    _changeProjectScope(() {
      _currentFolderId = id;
      // A search is global; close it to display the selected folder's contents.
      if (_isSearching) _resetProjectSearch();
    });
  }

  Set<String> _visibleProjectIds(ProjectService service) =>
      ProjectListWidget.visibleIds(
        source: service.projects.where((p) => !p.isSharedImport).toList(),
        allFolders: service.folders,
        currentFolderId: _currentFolderId,
        showFavoritesOnly: _showFavoritesOnly,
        searchQuery: _searchQuery,
        searchByTag: _searchByTag,
      );

  /// Select exactly the current list, including its query and favorite filter.
  /// Shared imports belong to their separate list. Ctrl+A uses the same scope.
  void _selectAllInCurrentFolder() {
    final ids = _visibleProjectIds(context.read<ProjectService>());
    setState(() {
      _isSelectionMode = ids.isNotEmpty;
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  /// 設定画面「ショートカット設定」の割り当て一覧から、ホーム画面で
  /// 有効なキー割り当てのマップを組み立てる。ツール選択の割り当ては
  /// キャンバスモード専用の概念のためここでは無視する。
  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
    BuildContext context,
  ) {
    final bindings = context.watch<ShortcutService>().bindings;
    if (_currentTabIndex != 0 || _isSearching) return {};
    final result = <ShortcutActivator, VoidCallback>{};
    for (final b in bindings) {
      if (b.isToolAction) continue;
      switch (b.command) {
        case ShortcutCommand.selectAll:
          result[b.activator] = _selectAllInCurrentFolder;
        case ShortcutCommand.copy:
          result[b.activator] = () {
            if (_selectedIds.isNotEmpty) _copySelected();
          };
        case ShortcutCommand.cut:
          result[b.activator] = () {
            if (_selectedIds.isNotEmpty) _cutSelected();
          };
        case ShortcutCommand.paste:
          result[b.activator] = () {
            if (_hasClipboard) _pasteClipboard();
          };
        case ShortcutCommand.undo:
        case ShortcutCommand.redo:
        case ShortcutCommand.toggleLayerPanel:
        case ShortcutCommand.playPause:
        case ShortcutCommand.previousFrame:
        case ShortcutCommand.nextFrame:
        case null:
          // キャンバス・タイムライン専用の操作、または未割り当て。
          break;
      }
    }
    return result;
  }

  /// 選択中のプロジェクト・フォルダを切り取り、内部クリップボードへ保持する。
  /// 貼り付け時は[moveToFolder]/[moveFolderTo]で移動し、1回貼り付けると
  /// クリップボードは空になる。
  void _cutSelected() {
    final service = context.read<ProjectService>();
    final visibleIds = _visibleProjectIds(service);
    final projectIds = service.projects.map((p) => p.id).toSet();
    final folderIds = service.folders.map((f) => f.id).toSet();
    setState(() {
      _clipboardProjectIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => projectIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardFolderIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => folderIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardIsCut = true;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  /// 選択中のプロジェクトを内部クリップボードへコピーする。フォルダの
  /// 複製は未対応のため、選択にフォルダが含まれる場合はプロジェクトのみを
  /// 対象にする。貼り付けのたびに複製するため、クリップボードは
  /// 貼り付け後も保持したままにする。
  void _copySelected() {
    final service = context.read<ProjectService>();
    final visibleIds = _visibleProjectIds(service);
    final projectIds = service.projects.map((p) => p.id).toSet();
    setState(() {
      _clipboardProjectIds
        ..clear()
        ..addAll(
          _selectedIds.where(
            (id) => projectIds.contains(id) && visibleIds.contains(id),
          ),
        );
      _clipboardFolderIds.clear();
      _clipboardIsCut = false;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  bool get _hasClipboard =>
      _clipboardProjectIds.isNotEmpty || _clipboardFolderIds.isNotEmpty;

  /// クリップボードの内容を現在開いているフォルダ（[_currentFolderId]、
  /// nullはルート直下）へ貼り付ける。切り取りの場合は移動して
  /// クリップボードを空にし、コピーの場合は複製してクリップボードは
  /// 保持したままにする。
  bool _pasting = false;
  Future<void> _pasteClipboard() async {
    if (_pasting) return;
    setState(() => _pasting = true);
    final service = context.read<ProjectService>();
    final isCut = _clipboardIsCut;
    try {
      for (final id in _clipboardProjectIds.toList()) {
        if (isCut) {
          await service.moveToFolder(id, _currentFolderId);
          _clipboardProjectIds.remove(id);
        } else {
          await service.duplicateProject(
            id,
            targetFolderId: _currentFolderId,
            useTargetFolder: true,
          );
        }
      }
      if (isCut) {
        for (final id in _clipboardFolderIds.toList()) {
          await service.moveFolderTo(id, _currentFolderId);
          _clipboardFolderIds.remove(id);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.homePasteSnackbar),
          ),
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              folderSaveFailureText(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pasting = false);
    }
  }

  /// フォルダ階層のパンくずリスト。フォルダ内移動時に現在位置を表示する。
  /// ホームアイコンでルートへ、各フォルダ名でその階層へ移動。
  Widget _buildBreadcrumb() {
    if (_currentFolderId == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final foreground = Theme.of(context).colorScheme.onSurface;
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
            IconButton(
              tooltip: l10n.projectListFolderRootOption,
              onPressed: () =>
                  _changeProjectScope(() => _currentFolderId = null),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              visualDensity: VisualDensity.standard,
              icon: const Icon(Icons.home, size: 18),
            ),
            for (final folder in chain) ...[
              const Icon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: () =>
                    _changeProjectScope(() => _currentFolderId = folder.id),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(48, 48),
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ホーム画面のタブバー。標準のTabBarと異なり、各タブ名の実際の描画幅を
/// 計測してその比率で幅を配分する（均等4分割だと「プロジェクト」のような
/// 長い項目名が「共有」等より窮屈になり、文字が見切れてしまうため）。
/// TabControllerを共有しているため、TabBarViewとのスワイプ連動・タップでの
/// 切り替えはそのまま機能する。
class _HomeTabBar extends StatefulWidget {
  final TabController controller;
  final int currentIndex;
  final List<String> labels;

  const _HomeTabBar({
    required this.controller,
    required this.currentIndex,
    required this.labels,
  });

  @override
  State<_HomeTabBar> createState() => _HomeTabBarState();
}

class _HomeTabBarState extends State<_HomeTabBar> {
  final _scrollController = ScrollController();
  Object? _lastLayout;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final currentIndex = widget.currentIndex;
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    // Preserve the selected accent as the indicator itself (red stays red),
    // and retain the exact configured foreground with a theme-derived outline.
    final background = opaqueOver(
      Theme.of(context).appBarTheme.backgroundColor ?? scheme.surface,
      opaqueOver(Theme.of(context).scaffoldBackgroundColor, Colors.black),
    );
    final menuScheme = scheme.copyWith(
      surface: background,
      onSurface:
          Theme.of(context).appBarTheme.foregroundColor ?? scheme.onSurface,
    );
    final selectedTextColor = scheme.primary;
    final selectedIndicatorColor = scheme.primary;
    final textStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );
    // 左右の余白（タップ領域確保）込みで、各タブ名の実際の描画幅を計測する。
    final naturalWidths = labels.map((label) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
        maxLines: 1,
      )..layout();
      final width = tp.width + 32;
      tp.dispose();
      return width;
    }).toList();

    Widget tabItem(int i) => Semantics(
      key: ValueKey('home_tab_$i'),
      selected: currentIndex == i,
      button: true,
      child: InkWell(
        onTap: () => controller.animateTo(i),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: currentIndex == i
                    ? selectedIndicatorColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            labels[i],
            maxLines: 1,
            softWrap: false,
            style: textStyle.copyWith(
              color: currentIndex == i
                  ? selectedTextColor
                  : scheme.onSurfaceVariant,
              shadows: currentIndex == i
                  ? CanvasIconButton.actionShadows(
                      selectedTextColor,
                      background,
                      menuScheme,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      // タブ名の実測幅の合計が画面幅に収まる場合は、これまで通り画面幅
      // いっぱいに比率配分して表示する。収まらない場合（タブ数が多い・
      // 画面が狭い場合）は、各タブを実測幅ぶんの固定幅で並べ、横スクロール
      // で残りのタブを表示できるようにする（タブ名を省略・縮小しない）。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalNatural = naturalWidths.fold<double>(0, (a, b) => a + b);
          final layout = (
            constraints.maxWidth,
            currentIndex,
            labels.join('\u0000'),
            totalNatural,
          );
          if (_lastLayout != layout) {
            _lastLayout = layout;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  _lastLayout != layout ||
                  !_scrollController.hasClients) {
                return;
              }
              final before = naturalWidths
                  .take(currentIndex)
                  .fold<double>(0, (a, b) => a + b);
              final target =
                  (before +
                          naturalWidths[currentIndex] / 2 -
                          constraints.maxWidth / 2)
                      .clamp(0.0, _scrollController.position.maxScrollExtent);
              _scrollController.jumpTo(target);
            });
          }
          if (totalNatural <= constraints.maxWidth) {
            final weights = naturalWidths.map((w) => w.round()).toList();
            return Row(
              children: [
                for (int i = 0; i < labels.length; i++)
                  Expanded(flex: weights[i], child: tabItem(i)),
              ],
            );
          }
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < labels.length; i++)
                  SizedBox(width: naturalWidths[i], child: tabItem(i)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 共有一覧。ホームタブと'/shared'直リンクで共用する。
class SharedScreen extends StatefulWidget {
  const SharedScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen> {
  // Keep the received and locally exported snapshot collections distinct.
  bool _showOutgoing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProjectService>().refreshOutgoingShares();
    });
  }

  // プロジェクトタブと同じ並び替え基準・お気に入り絞り込みを、共有一覧にも
  // 同じ見た目・操作性で提供する。
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  bool _showFavoritesOnly = false;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(l10n.homeTabShared)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const Key('sharedReceivedFilter'),
                  label: Text(_shareCollectionText(context, outgoing: false)),
                  selected: !_showOutgoing,
                  onSelected: (_) => setState(() => _showOutgoing = false),
                ),
                ChoiceChip(
                  key: const Key('sharedOutgoingFilter'),
                  label: Text(_shareCollectionText(context, outgoing: true)),
                  selected: _showOutgoing,
                  onSelected: (_) => setState(() => _showOutgoing = true),
                ),
              ],
            ),
          ),
          if (!_showOutgoing)
            _LibraryListControls(
            sort: SortModeControl(
              sortByName: _sortByName,
              sortAscending: _sortAscending,
              onSortByNameChanged: _setSortByName,
              onToggleDirection: _toggleSortDirection,
            ),
            leading: FilterChip(
              label: Text(
                l10n.homeFavoritesOnly,
                style: TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                  color: _showFavoritesOnly
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                ),
              ),
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Theme.of(context).colorScheme.onPrimary,
              selected: _showFavoritesOnly,
              onSelected: (v) => setState(() => _showFavoritesOnly = v),
            ),
          ),
          Expanded(
            child: _showOutgoing
                ? const _OutgoingSharesList()
                : _SharedTab(
                    sortMode: _sortMode,
                    showFavoritesOnly: _showFavoritesOnly,
                  ),
          ),
        ],
      ),
      floatingActionButton: _showOutgoing
          ? null
          : FloatingActionButton(
        tooltip: l10n.homeAddSheetNewFolder,
        onPressed: () => showCreateFolderNameDialog(
          context,
          (name) => context.read<ProjectService>().createSharedFolder(name),
        ),
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }
}

/// ゴミ箱一覧。ホームタブと'/trash'直リンクで共用する。
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  // 共有一覧・プロジェクトタブと同じ並び替え基準を、同じ見た目・操作性で
  // 提供する（ゴミ箱にお気に入りの概念はないため絞り込みは対象外）。
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(l10n.homeTabTrash)),
      body: Column(
        children: [
          _LibraryListControls(
            sort: SortModeControl(
              sortByName: _sortByName,
              sortAscending: _sortAscending,
              onSortByNameChanged: _setSortByName,
              onToggleDirection: _toggleSortDirection,
            ),
          ),
          Expanded(child: _TrashTab(sortMode: _sortMode)),
        ],
      ),
    );
  }
}

/// Library actions can wrap without taking space from the route title.
class _LibraryListControls extends StatelessWidget {
  const _LibraryListControls({required this.sort, this.leading});

  final Widget sort;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: LayoutBuilder(
      builder: (context, constraints) => OverflowBar(
        alignment: leading == null
            ? MainAxisAlignment.end
            : MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 8,
        overflowSpacing: 4,
        children: [
          ?leading,
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth < 400 ? 96 : constraints.maxWidth,
            ),
            child: sort,
          ),
        ],
      ),
    ),
  );
}

/// [ProjectSortMode]に従って並び替えたリストを返す。共有一覧・ゴミ箱一覧
/// ・プロジェクト一覧のいずれでも同じ基準（名前／更新日時）で並び替える。
List<Project> _sortProjects(List<Project> projects, ProjectSortMode mode) {
  final list = List<Project>.from(projects);
  switch (mode) {
    case ProjectSortMode.nameAsc:
      list.sort((a, b) => a.name.compareTo(b.name));
    case ProjectSortMode.nameDesc:
      list.sort((a, b) => b.name.compareTo(a.name));
    case ProjectSortMode.updatedAsc:
      list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    case ProjectSortMode.updatedDesc:
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return list;
}

class _SharedTab extends StatelessWidget {
  final ProjectSortMode sortMode;
  final bool showFavoritesOnly;

  const _SharedTab({required this.sortMode, required this.showFavoritesOnly});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    final folders = service.sharedFolders;
    var shared = service.shared;
    if (showFavoritesOnly) {
      shared = shared.where((p) => p.isFavorite).toList();
    }
    shared = _sortProjects(shared, sortMode);
    final l10n = AppLocalizations.of(context)!;
    return _FolderableList<Project>(
      reserveForFloatingActions: true,
      allItems: shared,
      folders: folders,
      emptyState: EmptyStatePlaceholder(
        icon: Icons.share_outlined,
        title: l10n.homeSharedEmpty,
        scrollable: false,
      ),
      folderIdOf: (p) => folders.any((f) => f.id == p.sharedFolderId)
          ? p.sharedFolderId
          : null,
      onEnterFolder: (folderId, folderName, itemsInFolder) =>
          Navigator.of(context).push(
            adMockMaterialPageRoute(
              builder: (_) => _SharedFolderScreen(
                folderId: folderId,
                folderName: folderName,
              ),
            ),
          ),
      onRenameFolder: (id, name) =>
          context.read<ProjectService>().renameSharedFolder(id, name),
      onDeleteFolder: (id) =>
          context.read<ProjectService>().deleteSharedFolder(id),
      itemBuilder: (context, project) => Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 1,
        shadowColor: ThemeService.activeColorScheme.shadow.withValues(
          alpha: 0.15,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(project.backgroundColor),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          title: Text(
            project.name,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          subtitle: Text(
            l10n.homeProjectMeta(project.fps, project.durationSeconds),
          ),
          onTap: () => context.push('/project/${project.id}'),
          trailing: _receivedShareMenu(context, project),
          onLongPress: () => _showMoveToSharedFolderSheet(context, project),
        ),
      ),
    );
  }

  void _showMoveToSharedFolderSheet(BuildContext context, Project project) {
    final service = context.read<ProjectService>();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: service.sharedFolders,
        filename: project.name,
        onMove: (id) => service.moveToSharedFolder(project.id, id),
      ),
    );
  }
}


String _shareCollectionText(BuildContext context, {required bool outgoing}) {
  final locale = Localizations.localeOf(context).languageCode;
  final names = switch (locale) {
    'ja' => ('受け取ったもの', '自分が作成したもの'),
    'ko' => ('받은 파일', '내가 만든 파일'),
    'zh' => ('收到的文件', '我创建的文件'),
    'fr' => ('Reçus', 'Créés par moi'),
    'es' => ('Recibidos', 'Creados por mí'),
    _ => ('Received', 'Created by me'),
  };
  return outgoing ? names.$2 : names.$1;
}

/// Received projects remain editable. Sharing one explicitly creates a new
/// saved .niashare snapshot, whereas outbound snapshots reuse existing bytes.
Widget _receivedShareMenu(BuildContext context, Project project) {
  final l10n = AppLocalizations.of(context)!;
  return PopupMenuButton<String>(
    key: ValueKey('receivedShareMenu_${project.id}'),
    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
    onSelected: (action) {
      if (action == 'share') {
        createAndShareProjectNiashare(
          context,
          context.read<ProjectService>(),
          project,
        );
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        value: 'share',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ios_share_outlined),
            const SizedBox(width: 8),
            Text(l10n.projectDetailShareQuickAction),
          ],
        ),
      ),
    ],
  );
}

class _OutgoingSharesList extends StatelessWidget {
  const _OutgoingSharesList();

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<ProjectService>().outgoingShares;
    final l10n = AppLocalizations.of(context)!;
    if (saved.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.file_present_outlined,
        title: _shareCollectionEmptyText(context),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('outgoing-niashares'),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: saved.length,
      itemBuilder: (context, index) {
        final entry = saved[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined, size: 36),
            title: Text(
              entry.name,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            subtitle: Text(
              '${entry.updatedAt.year}/${entry.updatedAt.month.toString().padLeft(2, '0')}/${entry.updatedAt.day.toString().padLeft(2, '0')}  ·  ${(entry.sizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
            onTap: () => shareSavedNiashare(context, entry.path),
            trailing: PopupMenuButton<String>(
              key: ValueKey('outgoingShareMenu_${entry.path}'),
              onSelected: (action) {
                if (action == 'share') {
                  shareSavedNiashare(context, entry.path);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ios_share_outlined),
                      const SizedBox(width: 8),
                      Text(l10n.projectDetailShareQuickAction),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _shareCollectionEmptyText(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ja' => '作成した共有ファイルはまだありません',
    'ko' => '생성한 공유 파일이 없습니다',
    'zh' => '还没有创建的共享文件',
    'fr' => 'Aucun fichier partagé créé',
    'es' => 'Todavía no hay archivos compartidos creados',
    _ => 'No created share files yet',
  };
}

/// 共有タブのフォルダ内表示（共有タブへのフォルダ新規追加機能）。
class _SharedFolderScreen extends StatelessWidget {
  final String folderId;
  final String folderName;
  const _SharedFolderScreen({required this.folderId, required this.folderName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = context
        .watch<ProjectService>()
        .shared
        .where((p) => p.sharedFolderId == folderId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: items.isEmpty
          ? EmptyStatePlaceholder(
              icon: Icons.folder_open_outlined,
              title: l10n.homeSharedFolderEmpty,
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final project = items[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 1,
                  shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                    alpha: 0.15,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(project.backgroundColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    title: Text(
                      project.name,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    subtitle: Text(
                      l10n.homeProjectMeta(
                        project.fps,
                        project.durationSeconds,
                      ),
                    ),
                    onTap: () => context.push('/project/${project.id}'),
                    trailing: _receivedShareMenu(context, project),
                  ),
                );
              },
            ),
    );
  }
}

/// フォルダ一覧＋直下アイテム一覧を表示する共通ウィジェット（共有タブ・
/// 作品一覧タブで共用）。フォルダは常にルート直下の1階層のみ（ネスト非対応）。
class _FolderableList<T> extends StatelessWidget {
  final List<T> allItems;
  final List<ProjectFolder> folders;
  final String? Function(T) folderIdOf;
  final void Function(String folderId, String folderName, List<T> itemsInFolder)
  onEnterFolder;
  final Future<void> Function(String id, String name) onRenameFolder;
  final Future<void> Function(String id) onDeleteFolder;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? emptyState;
  final bool reserveForFloatingActions;

  const _FolderableList({
    required this.allItems,
    required this.folders,
    required this.folderIdOf,
    required this.onEnterFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.itemBuilder,
    this.emptyState,
    this.reserveForFloatingActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final rootItems = allItems.where((e) => folderIdOf(e) == null).toList();
    // フォルダごとの件数を1回の走査で数える。フォルダの数だけallItemsを
    // whereで舐め直すと、作品数×フォルダ数の走査が毎buildで走っていた。
    final countByFolder = <String, int>{};
    for (final e in allItems) {
      final id = folderIdOf(e);
      if (id != null) countByFolder[id] = (countByFolder[id] ?? 0) + 1;
    }
    final hasHeader = folders.isNotEmpty;
    // 作品の行は表示されるぶんだけ作る。ListView(children:)だと、実際に
    // 描画されるのは画面内の行だけでも、全作品ぶんのカード（サムネイルの
    // Image.fileを含む）のウィジェットが毎buildで作られて捨てられる。
    return LayoutBuilder(
      builder: (context, constraints) {
        if (rootItems.isEmpty && emptyState != null) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (hasHeader) ...[
                SliverToBoxAdapter(child: _folderChips(context, countByFolder)),
                const SliverToBoxAdapter(child: Divider(height: 1)),
              ],
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: reserveForFloatingActions
                      ? 88 + MediaQuery.paddingOf(context).bottom
                      : 0,
                ),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: emptyState!,
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          // Leave 48px for the action, 8px inner padding and 4px card margin.
          padding: EdgeInsets.only(
            bottom: reserveForFloatingActions
                ? (constraints.maxHeight - 60).clamp(0.0, 88.0).toDouble() +
                      MediaQuery.paddingOf(context).bottom
                : 0,
          ),
          itemCount: rootItems.length + (hasHeader ? 2 : 0),
          itemBuilder: (context, index) {
            if (hasHeader && index == 0) {
              return _folderChips(context, countByFolder);
            }
            if (hasHeader && index == 1) return const Divider(height: 1);
            return itemBuilder(context, rootItems[index - (hasHeader ? 2 : 0)]);
          },
        );
      },
    );
  }

  Widget _folderChips(BuildContext context, Map<String, int> countByFolder) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: folders.map((f) {
            final count = countByFolder[f.id] ?? 0;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - 24).clamp(
                  0.0,
                  double.infinity,
                ),
                minHeight: 48,
              ),
              child: Semantics(
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onEnterFolder(
                    f.id,
                    f.name,
                    allItems.where((e) => folderIdOf(e) == f.id).toList(),
                  ),
                  onLongPress: () => _showFolderMenu(context, f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 18),
                        const SizedBox(width: 6),
                        Flexible(child: Text(f.name)),
                        const SizedBox(width: 4),
                        Text(
                          '($count)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFolderMenu(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.commonRename),
              onTap: () {
                Navigator.pop(ctx);
                showRenameFolderNameDialog(
                  context,
                  folder.name,
                  (name) => onRenameFolder(folder.id, name),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: ThemeService.activeColorScheme.error,
              ),
              title: Text(
                l10n.commonDelete,
                style: TextStyle(color: ThemeService.activeColorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => FolderDeleteDialog(
                    folderName: folder.name,
                    onDelete: () => onDeleteFolder(folder.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashTab extends StatefulWidget {
  final ProjectSortMode sortMode;

  const _TrashTab({required this.sortMode});

  @override
  State<_TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<_TrashTab> {
  final _pending = <String>{};
  final _restoring = <String>{};

  Future<void> _restore(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    setState(() {
      _pending.add(id);
      _restoring.add(id);
    });
    try {
      await runProjectTrashAction(context, () => service.restoreProject(id));
    } finally {
      if (mounted) {
        setState(() {
          _pending.remove(id);
          _restoring.remove(id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trash = _sortProjects(
      context.watch<ProjectService>().trash,
      widget.sortMode,
    );
    final l10n = AppLocalizations.of(context)!;
    if (trash.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.delete_outline,
        title: l10n.homeTrashEmpty,
      );
    }
    return ListView.builder(
      itemCount: trash.length,
      itemBuilder: (context, index) {
        final project = trash[index];
        final deletedAt = context.read<ProjectService>().deletedAtOf(
          project.id,
        );
        final deletedLabel = deletedAt == null
            ? ''
            : l10n.homeTrashDeletedOn(
                '${deletedAt.year}/${deletedAt.month.toString().padLeft(2, '0')}/${deletedAt.day.toString().padLeft(2, '0')}',
              );
        final meta = l10n.homeProjectMeta(project.fps, project.durationSeconds);
        final actions = [
          TextButton(
            key: ValueKey('trash-restore-${project.id}'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
            ),
            onPressed: _pending.contains(project.id)
                ? null
                : () => _restore(project.id),
            child: _restoring.contains(project.id)
                ? Text(l10n.homeTrashWorking)
                : Text(l10n.commonRestore),
          ),
          TextButton(
            key: ValueKey('trash-delete-${project.id}'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _pending.contains(project.id)
                ? null
                : () => _confirmPermanentDelete(project),
            child: Text(l10n.homePermanentDelete),
          ),
        ];
        Widget details({Widget? trailing}) => ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(project.backgroundColor),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          title: Text(
            project.name,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          subtitle: Text(deletedLabel.isEmpty ? meta : '$deletedLabel · $meta'),
          trailing: trailing,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth <
                600 * MediaQuery.textScalerOf(context).scale(1);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        details(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: OverflowBar(
                            alignment: MainAxisAlignment.end,
                            overflowAlignment: OverflowBarAlignment.end,
                            spacing: 8,
                            overflowSpacing: 4,
                            children: actions,
                          ),
                        ),
                      ],
                    )
                  : details(
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmPermanentDelete(Project project) async {
    if (_pending.contains(project.id)) return;
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    setState(() => _pending.add(project.id));
    try {
      await showDialog<bool>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homePermanentDeleteConfirmTitle,
          message: l10n.homePermanentDeleteConfirmBody,
          confirmLabel: l10n.commonDelete,
          itemNames: [project.name],
          onApply: () => service.permanentDelete(project.id),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(project.id));
    }
  }
}

class _WorksTab extends StatefulWidget {
  const _WorksTab({super.key});

  @override
  State<_WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<_WorksTab> {
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _future = ExportEngine.listExportedFiles();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ExportEngine.listExportedFiles(forceRefresh: true);
    });
    try {
      await _future;
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<File>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _WorksLoadFailure(onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snapshot.data!;
        final workFolders = context.watch<WorkFolderService>();
        return RefreshIndicator(
          onRefresh: _reload,
          child: _FolderableList<File>(
            emptyState: files.isEmpty
                ? EmptyStatePlaceholder(
                    icon: Icons.video_library_outlined,
                    title: l10n.homeWorksEmpty,
                    hint: l10n.homeWorksEmptyHint,
                    scrollable: false,
                  )
                : null,
            allItems: files,
            folders: workFolders.folders,
            folderIdOf: (f) =>
                workFolders.folderIdOf(f.path.split(RegExp(r'[\\/]')).last),
            onEnterFolder: (folderId, folderName, itemsInFolder) =>
                Navigator.of(context).push(
                  adMockMaterialPageRoute(
                    builder: (_) => _WorksFolderScreen(
                      folderId: folderId,
                      folderName: folderName,
                      onDeleted: _reload,
                    ),
                  ),
                ),
            onRenameFolder: (id, name) => workFolders.renameFolder(id, name),
            onDeleteFolder: (id) => workFolders.deleteFolder(id),
            itemBuilder: (context, file) => _WorkListItem(
              key: ValueKey(file.path),
              file: file,
              onDeleted: _reload,
            ),
          ),
        );
      },
    );
  }
}

class _WorksLoadFailure extends StatelessWidget {
  const _WorksLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.homeWorksLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.communityRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// 作品一覧タブのフォルダ内表示。
class _WorksFolderScreen extends StatefulWidget {
  final String folderId;
  final String folderName;
  final VoidCallback onDeleted;
  const _WorksFolderScreen({
    required this.folderId,
    required this.folderName,
    required this.onDeleted,
  });

  @override
  State<_WorksFolderScreen> createState() => _WorksFolderScreenState();
}

class _WorksFolderScreenState extends State<_WorksFolderScreen> {
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _future = ExportEngine.listExportedFiles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workFolders = context.watch<WorkFolderService>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      body: FutureBuilder<List<File>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _WorksLoadFailure(
              onRetry: () => setState(() {
                _future = ExportEngine.listExportedFiles(forceRefresh: true);
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!
              .where(
                (f) =>
                    workFolders.folderIdOf(
                      f.path.split(RegExp(r'[\\/]')).last,
                    ) ==
                    widget.folderId,
              )
              .toList();
          if (items.isEmpty) {
            return EmptyStatePlaceholder(
              icon: Icons.folder_open_outlined,
              title: l10n.homeWorkFolderEmpty,
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _WorkListItem(
              key: ValueKey(items[index].path),
              file: items[index],
              onDeleted: () {
                setState(() {
                  _future = ExportEngine.listExportedFiles(forceRefresh: true);
                });
                widget.onDeleted();
              },
            ),
          );
        },
      ),
    );
  }
}

class _WorkListItem extends StatefulWidget {
  final File file;
  final VoidCallback onDeleted;
  const _WorkListItem({super.key, required this.file, required this.onDeleted});

  @override
  State<_WorkListItem> createState() => _WorkListItemState();
}

class _WorkListItemState extends State<_WorkListItem> {
  File get file => widget.file;
  bool _sharing = false;
  Object? _shareError;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await ExportShareService.share(file, origin: exportShareOrigin(context));
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) setState(() => _shareError = error);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String get _extension => file.path.split('.').last.toLowerCase();

  IconData get _icon {
    switch (_extension) {
      case 'gif':
        return Icons.gif_box_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      case 'webm':
        return Icons.movie_filter_outlined;
      default:
        return Icons.movie_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final stat = file.statSync();
    final l10n = AppLocalizations.of(context)!;
    return ExportedWorkCard(
      name: file.path.split(RegExp(r'[\\/]')).last,
      metadata: '${_formatDate(stat.modified)} ・ ${_formatSize(stat.size)}',
      icon: _icon,
      moveLabel: l10n.folderMoveToTitle,
      shareLabel: l10n.homeShareOpenWith,
      deleteLabel: l10n.commonDelete,
      onOpen: _sharing ? null : () => _openPreview(context),
      onMove: () => _showMoveToFolderSheet(context),
      onShare: _sharing ? null : _share,
      onDelete: _sharing ? null : () => _confirmDelete(context),
      shareBusy: _sharing,
      shareError: _shareError == null
          ? null
          : exportShareFailureText(l10n, _shareError!),
    );
  }

  void _showMoveToFolderSheet(BuildContext context) {
    final service = context.read<WorkFolderService>();
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    showModalBottomSheet(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        filename: fileName,
        folders: service.folders,
        onMove: (folderId) => service.moveFileToFolder(fileName, folderId),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 720),
        child: _WorkPreview(file: file),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(16),
        title: Text(l10n.homeWorkDeleteConfirmTitle(file.path.split('/').last)),
        content: Text(l10n.homeWorkDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeService.activeColorScheme.error,
            ),
            onPressed: () {
              if (file.existsSync()) file.deleteSync();
              Navigator.pop(ctx);
              widget.onDeleted();
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

/// アプリ内プレビュー：MP4/WebMはVideoPlayerController（timeline_screen.dart
/// で既に実績のある仕組み）、GIF/PNG/JPEGはFlutter標準のImage/FileImage（アニメーション
/// GIFを自動再生する）を用いる。いずれも新規ネイティブ依存なし。
class _WorkPreview extends StatefulWidget {
  final File file;
  const _WorkPreview({required this.file});

  @override
  State<_WorkPreview> createState() => _WorkPreviewState();
}

class _WorkPreviewState extends State<_WorkPreview> {
  VideoPlayerController? _controller;
  bool _isImage = false;
  bool _failed = false;
  bool _sharing = false;
  Object? _shareError;
  FileImage? _imageProvider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double? _imageAspectRatio;
  bool _imageDimensionsResolved = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await ExportShareService.share(
        widget.file,
        origin: exportShareOrigin(context),
      );
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) setState(() => _shareError = error);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final path = widget.file.path.toLowerCase();
    _isImage = ['.gif', '.png', '.jpg', '.jpeg'].any(path.endsWith);
    if (_isImage) {
      _imageProvider = FileImage(widget.file);
    } else {
      _controller = VideoPlayerController.file(widget.file)
        ..initialize()
            .then((_) {
              if (!mounted) return;
              setState(() {});
              _controller?.play();
              _controller?.setLooping(true);
            })
            .catchError((_) {
              if (mounted) setState(() => _failed = true);
            });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isImage || _imageDimensionsResolved || _imageListener != null) return;
    // Share the Image widget's cached stream and release our first-frame clone.
    _imageStream = _imageProvider!.resolve(
      createLocalImageConfiguration(context),
    );
    _imageListener = ImageStreamListener(
      (info, synchronousCall) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        _imageDimensionsResolved = true;
        _stopImageSizeListener();
        if (!mounted) return;
        if (synchronousCall) {
          _imageAspectRatio = ratio;
        } else {
          setState(() => _imageAspectRatio = ratio);
        }
      },
      onError: (error, stackTrace) {
        _imageDimensionsResolved = true;
        _stopImageSizeListener();
      },
    );
    _imageStream!.addListener(_imageListener!);
  }

  void _stopImageSizeListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    _imageStream = null;
    _imageListener = null;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  @override
  void dispose() {
    _stopImageSizeListener();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget content;
    if (_isImage) {
      content = Image(
        image: _imageProvider!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(l10n.homePreviewFailed, textAlign: TextAlign.center),
        ),
      );
    } else if (_failed) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.homePreviewFailed, textAlign: TextAlign.center),
        ),
      );
    } else if (_controller != null && _controller!.value.isInitialized) {
      content = Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() {
              _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play();
            }),
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    } else {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return ExportedWorkPreviewLayout(
      content: content,
      contentAspectRatio: _isImage
          ? _imageAspectRatio ?? 16 / 9
          : _controller?.value.isInitialized == true
          ? _controller!.value.aspectRatio
          : 16 / 9,
      shareLabel: l10n.homeShareOpenWith,
      closeLabel: l10n.commonClose,
      onShare: _sharing ? null : _share,
      shareBusy: _sharing,
      shareError: _shareError == null
          ? null
          : exportShareFailureText(l10n, _shareError!),
      onClose: () => Navigator.pop(context),
    );
  }
}

enum ProjectViewMode { large, medium, small, detail }

enum ProjectSortMode { nameAsc, nameDesc, updatedAsc, updatedDesc }

// ─── 初回起動ポップアップ ─────────────────────────────────────────────────
// 初回起動時は「手描きアニメーションを制作できます」の
// ポップアップのみを表示する（複数ページのチュートリアルは表示しない）。

class _FirstLaunchDialog extends StatefulWidget {
  final Future<void> Function() onDone;
  const _FirstLaunchDialog({required this.onDone});

  @override
  State<_FirstLaunchDialog> createState() => _FirstLaunchDialogState();
}

class _FirstLaunchDialogState extends State<_FirstLaunchDialog> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _complete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope<Object?>(
      canPop: false,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeFirstLaunchMessage),
            if (_saving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.communityErrorGeneric,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // 「はじめる」ボタンの文字はくらむぼんを明示指定する
          // （通常のボタン文字は白光明朝のため、ここだけ差し替える）。
          FilledButton(
            onPressed: _saving ? null : _complete,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              l10n.homeFirstLaunchStart,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
