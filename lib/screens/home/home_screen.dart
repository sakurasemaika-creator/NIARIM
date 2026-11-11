import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../services/local_file_trash_service.dart';
import '../../services/outgoing_share_library.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/storage_info_service.dart';
import '../../services/work_folder_service.dart';
import '../../models/shortcut_binding.dart';
import '../../widgets/export_share_feedback.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/sort_mode_control.dart';
import '../../widgets/project_trash_dialog.dart';
import '../../widgets/collection_action_controls.dart';
import '../../widgets/collection_tile_layout.dart';
import '../../widgets/home_collection_selection_scope.dart';
import '../../widgets/share_project_file_action.dart';
import '../../widgets/mission_completion_dialog.dart';
import '../../widgets/typing_aware_shortcuts.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/folder_thumbnail.dart';
import 'widgets/project_thumbnail_dialog.dart';
import 'widgets/home_selection_toolbar.dart';
import 'widgets/home_drawer.dart';
import 'widgets/exported_work_card.dart';
import 'widgets/exported_work_thumbnail_dialog.dart';
import 'widgets/exported_work_preview_layout.dart';
import 'widgets/folder_delete_dialog.dart';
import 'widgets/folder_save_feedback.dart';
import 'widgets/work_folder_move_sheet.dart';
import 'home_clipboard_policy.dart';
import '../../config/font_fallback.dart';
import '../../utils/line_break.dart';
import '../../widgets/projects_load_failure_notice.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/responsive_tile_defaults.dart';
import '../../utils/tolerant_preferences.dart';

class _ClipboardSourceMissing implements Exception {
  const _ClipboardSourceMissing();
}

String _clipboardMissingMessage(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja'
    ? 'コピー元の作品・フォルダが見つかりません。ゴミ箱から復元するか、'
          'もう一度コピーしてください。'
    : 'The source file or folder is missing. Restore it from Trash '
          'or copy it again.';

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
        final visit = await api.visitLoginBonus();
        if (mounted &&
            (ModalRoute.of(context)?.isCurrent ?? false) &&
            context.read<GoogleAuthService>().account?.id == ownerId) {
          await showServerMissionCompletions(context, visit);
        }
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
  static const _worksViewModeKey = 'home.worksViewMode.v1';
  ProjectViewMode? _userViewMode;
  // Preserve the existing full-height list cover until a view size is chosen.
  ProjectViewMode? _worksViewMode;
  ProjectViewMode? _sharedViewMode;
  static const _sharedViewModeKey = 'home.sharedViewMode.v1';

  ProjectViewMode _defaultCollectionViewMode(BuildContext context) =>
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };
  ProjectViewMode _effectiveWorksViewMode(BuildContext context) =>
      _worksViewMode ?? _defaultCollectionViewMode(context);
  ProjectViewMode _effectiveSharedViewMode(BuildContext context) =>
      _sharedViewMode ?? _defaultCollectionViewMode(context);

  Future<void> _selectSharedViewMode(ProjectViewMode mode) async {
    setState(() => _sharedViewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sharedViewModeKey, mode.name);
    } catch (error) {
      debugPrint('Shared tile preference could not be saved: $error');
    }
  }

  Future<void> _loadSharedViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_sharedViewModeKey);
      if (!mounted || stored == null) return;
      for (final mode in ProjectViewMode.values) {
        if (mode.name == stored) {
          setState(() => _sharedViewMode = mode);
          return;
        }
      }
    } catch (error) {
      debugPrint('Shared tile preference could not be restored: $error');
    }
  }

  Future<void> _selectWorksViewMode(ProjectViewMode mode) async {
    setState(() => _worksViewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_worksViewModeKey, mode.name);
    } catch (error) {
      debugPrint('Works tile preference could not be saved: $error');
    }
  }

  Future<void> _loadWorksViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_worksViewModeKey);
      if (!mounted || stored == null) return;
      for (final mode in ProjectViewMode.values) {
        if (mode.name == stored) {
          setState(() => _worksViewMode = mode);
          return;
        }
      }
    } catch (error) {
      debugPrint('Works tile preference could not be restored: $error');
    }
  }

  ProjectViewMode _effectiveViewMode(BuildContext context) =>
      _userViewMode ??
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };

  // 一覧のスクロール位置を覚える区分に使う表示サイズ。表示サイズを選んで
  // いない間は、最初に決まったもののままにする：窓の幅が境（600px・1000px）を
  // またいで表示サイズが変わるたびに区分まで変えると、一覧が先頭へ戻る。
  ProjectViewMode? _autoViewModeAtOpen;

  ProjectViewMode _scrollMemoryViewMode(BuildContext context) =>
      _userViewMode ?? (_autoViewModeAtOpen ??= _effectiveViewMode(context));

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
  final Set<String> _visibleLibraryIds = {};
  // 複数選択モードの切り取り・コピー・貼り付け。フォルダ間の移動を手軽に
  // するための内部クリップボード（アプリを離れると保持しない、
  // セッション内のみのUI状態）。_clipboardIsCutがtrueなら切り取り（貼り付け
  // で移動し1回でクリップボードを空にする）、falseならコピー（貼り付けは
  // 複製し、繰り返し貼り付け可能）。フォルダは複製の実装を持たないため、
  // コピー時は選択にプロジェクトのみを含める（フォルダが混在していれば
  // コピー操作自体を無効化する）。
  final Set<String> _clipboardProjectIds = {};
  final Set<String> _clipboardFolderIds = {};
  HomePasteArea _clipboardSourceArea = HomePasteArea.projects;
  HomeClipboardEntry? _otherClipboard;
  bool _sharedOutgoing = false;
  bool _clipboardIsCut = false;
  bool _showFavoritesOnly = false;
  bool _isSearching = false;
  // false: project/folder name keyword search, true: project tag search.
  // The search bar toggle swaps these modes like a play/pause control.
  bool _searchByTag = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  // 画面全体のショートカット（全選択・コピー等）を受けるフォーカス。
  // 検索欄から抜けたら（Enter・閉じる・タブの切り替え）ここへ戻す。
  final _homeFocus = FocusNode(debugLabel: 'Home');
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
          _selectedIds.clear();
          _visibleLibraryIds.clear();
          _isSelectionMode = false;
          _resetProjectSearch();
        });
        if (wasSearching && _currentTabIndex != 0) {
          _homeFocus.requestFocus();
        }
      }
    });
    _loadProjectViewMode();
    _loadWorksViewMode();
    _loadSharedViewMode();
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
    _homeFocus.dispose();
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
    _maybeRecordLogin(
      context.watch<GoogleAuthService>().account?.id,
      context.read<CommunityService>().api,
    );

    // マウス/キーボード入力・左手デバイス：設定画面「ショートカット設定」
    // で割り当てたキーで、全選択・コピー・切り取り・貼り付けを
    // 行えるようにする。
    // 入力欄にフォーカスがある間は画面のショートカットを止める
    // （TypingAwareShortcuts）。入力を終えたら画面のフォーカスへ戻す。
    final content = TypingAwareShortcuts(
      bindings: _buildShortcutBindings(context),
      screenFocus: _homeFocus,
      child: Focus(
        focusNode: _homeFocus,
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
            title: _isSearching
                ? Row(
                    children: [
                      if (_currentTabIndex == 0)
                        IconButton(
                          key: const Key('homeSearchTagToggle'),
                          icon: Icon(
                            _searchByTag ? Icons.search : Icons.sell_outlined,
                          ),
                          tooltip: _searchByTag
                              ? l10n.homeSearchHint
                              : l10n.projectDetailTagsQuickAction,
                          onPressed: () {
                            _changeProjectScope(
                              () => _searchByTag = !_searchByTag,
                            );
                            _searchFocus.requestFocus();
                          },
                        ),
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {_escapeOnce: _closeProjectSearch},
                          child: TextField(
                            key: const Key('homeSearchInput'),
                            controller: _searchController,
                            focusNode: _searchFocus,
                            decoration: InputDecoration(
                              hintText: _currentTabIndex == 0 && _searchByTag
                                  ? l10n.projectDetailTagsQuickAction
                                  : l10n.homeSearchHint,
                              border: InputBorder.none,
                            ),
                            onChanged: (v) =>
                                _changeProjectScope(() => _searchQuery = v),
                            onEditingComplete: _homeFocus.requestFocus,
                            onTapOutside: (event) {
                              if (event.kind != PointerDeviceKind.touch &&
                                  _searchFocus.hasFocus) {
                                _homeFocus.requestFocus();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(switch (_currentTabIndex) {
                    1 => l10n.homeTabWorks,
                    2 => l10n.homeTabShared,
                    3 => l10n.homeTabTrash,
                    _ => l10n.homeTabProjects,
                  }),
            actions: [
              if (_isSearching)
                IconButton(
                  key: const Key('homeSearchCloseButton'),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonClose,
                  onPressed: _closeProjectSearch,
                )
              else ...[
                if (_currentTabIndex <= 2)
                  PopupMenuButton<ProjectViewMode>(
                    key: const Key('homeCollectionViewModeMenu'),
                    icon: const Icon(Icons.view_module),
                    tooltip: l10n.homeViewModeTooltip,
                    onSelected: (mode) {
                      switch (_currentTabIndex) {
                        case 0:
                          _selectProjectViewMode(mode);
                        case 1:
                          _selectWorksViewMode(mode);
                        case 2:
                          _selectSharedViewMode(mode);
                      }
                    },
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
                  key: const Key('homeSearchButton'),
                  icon: const Icon(Icons.search),
                  tooltip: l10n.commonSearch,
                  onPressed: _openProjectSearch,
                ),
              ],
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
              preferredSize: const Size.fromHeight(48),
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
          // 引き出しの開閉で画面のショートカットを組み替える
          // （_buildShortcutBindings）。
          onEndDrawerChanged: (_) {
            if (mounted) setState(() {});
          },
          body: Column(
            children: [
              if (!_isSelectionMode && _hasClipboard)
                HomeClipboardToolbar(
                  itemCount: _clipboardProjectIds.length +
                      _clipboardFolderIds.length +
                      (_otherClipboard == null ? 0 : 1),
                  isCut: _clipboardIsCut,
                  isPasting: _pasting,
                  onPaste: _pasteClipboard,
                  onClear: _clearHomeClipboard,
                ),
              if (_isSelectionMode)
                HomeSelectionToolbar(
                  selectedCount: _selectedIds.length,
                  onSelectAll: _currentTabIndex == 0
                      ? _selectAllInCurrentFolder
                      : _selectAllLibrary,
                  onDeselectAll: _endProjectSelection,
                  onCut: _selectedIds.isEmpty
                      ? null
                      : (_currentTabIndex == 0
                            ? _cutSelected
                            : _currentTabIndex == 3 || _selectedIds.length != 1
                            ? null
                            : _cutSelectedLibrary),
                  onCopy: _selectedIds.isEmpty
                      ? null
                      : (_currentTabIndex == 0
                            ? _copySelected
                            : _selectedIds.length != 1
                            ? null
                            : _currentTabIndex == 3
                            ? _copySelectedTrash
                            : _copySelectedLibrary),
                  onTrash: _selectedIds.isEmpty
                      ? null
                      : (_currentTabIndex == 0
                            ? _deleteSelected
                            : _currentTabIndex == 3
                            ? _restoreSelectedTrash
                            : _trashSelectedLibrary),
                  primaryActionLabel: _currentTabIndex == 3
                      ? l10n.commonRestore
                      : null,
                  primaryActionIcon: _currentTabIndex == 3
                      ? Icons.restore
                      : Icons.delete,
                ),
              Expanded(
                child: HomeCollectionSelectionScope(
                  active: _isSelectionMode,
                  selectedIds: Set<String>.of(_selectedIds),
                  onLongPress: _longPressLibraryEntry,
                  onToggle: _toggleLibraryEntry,
                  onVisibleIds: (ids) {
                    // TabBarView may prebuild adjacent off-screen tabs. Only
                    // the active collection can supply the Select All set.
                    final prefix = switch (_currentTabIndex) {
                      1 => 'work_',
                      2 => _sharedOutgoing ? 'outgoing_' : 'shared_',
                      3 => 'trash_',
                      _ => '',
                    };
                    if (prefix.isEmpty ||
                        (ids.isNotEmpty &&
                            ids.any((id) => !id.startsWith(prefix))))
                      return;
                    _visibleLibraryIds
                      ..clear()
                      ..addAll(ids);
                  },
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ProjectListWidget(
                        scrollController: _projectScrollController,
                        header: Column(
                          children: [
                            // 保存先を読めなかったときは、空の一覧に見えて
                            // 作品が消えたと思わないよう知らせ、読み直せる
                            // ようにする。
                            if (context
                                .watch<ProjectService>()
                                .projectsLoadFailed)
                              ProjectsLoadFailureNotice(
                                key: const Key('homeProjectsLoadFailed'),
                                onRetry: () => context
                                    .read<ProjectService>()
                                    .retryLoadProjects(),
                                screenFocus: _homeFocus,
                              ),
                            _HomeCollectionSortHeader(
                              leading: FilterChip(
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
                              sortByName: _sortByName,
                              sortAscending: _sortAscending,
                              onSortByNameChanged: _setSortByName,
                              onToggleDirection: _toggleSortDirection,
                            ),
                            // フォルダ内移動時のパンくずリスト。検索中は
                            // 全体から検索するため非表示にする。
                            if (!_isSearching) _buildBreadcrumb(),
                          ],
                        ),
                        // Keep bounded browsing scopes rather than every typed query.
                        key: PageStorageKey((
                          'home-projects',
                          _scrollMemoryViewMode(context),
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
                        cutIds: _clipboardIsCut
                            ? {..._clipboardProjectIds, ..._clipboardFolderIds}
                            : const {},
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
                      _WorksTab(
                        key: const PageStorageKey('home-works'),
                        viewMode: _effectiveWorksViewMode(context),
                        onViewModeChanged: _selectWorksViewMode,
                        searchQuery: _currentTabIndex == 1 && _isSearching
                            ? _searchQuery
                            : '',
                        onCopyEntry: _copyLibraryEntry,
                      ),
                      SharedScreen(
                        key: const PageStorageKey('home-shared'),
                        embedded: true,
                        screenFocus: _homeFocus,
                        viewMode: _effectiveSharedViewMode(context),
                        onViewModeChanged: _selectSharedViewMode,
                        searchQuery: _currentTabIndex == 2 && _isSearching
                            ? _searchQuery
                            : '',
                        onDirectionChanged: (outgoing) => setState(() {
                          _sharedOutgoing = outgoing;
                          _selectedIds.clear();
                          _visibleLibraryIds.clear();
                          _isSelectionMode = false;
                        }),
                        onCopyEntry: _copyLibraryEntry,
                      ),
                      TrashScreen(
                        key: const PageStorageKey('home-trash'),
                        embedded: true,
                        searchQuery: _currentTabIndex == 3 && _isSearching
                            ? _searchQuery
                            : '',
                        screenFocus: _homeFocus,
                        onCopyEntry: _copyLibraryEntry,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildHomeActions(context, l10n),
        ),
      ),
    );
    // 戻る操作は常にここで受ける（canPop: false）。キャンバス・書き出しから
    // go('/home')で来たホームは履歴が1枚だけで、受けないとAndroid 16以降の
    // 予測型「戻る」ではOSが戻る操作をアプリへ渡さずにアプリを閉じる
    // （BackButtonListenerも呼ばれない）。ホームは作り直されないので、
    // canPopを組み立てたときの履歴から決めると古い値のまま残る。
    return BackButtonListener(
      onBackButtonPressed: () async => _handleLocalBack(),
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || _handleLocalBack()) return;
          // 何も開いていない、ほかの画面から積まれたホーム：前の画面へ戻る。
          if (mounted &&
              (ModalRoute.of(context)?.isCurrent ?? false) &&
              context.canPop()) {
            context.pop();
          }
        },
        child: content,
      ),
    );
  }

  bool get _hasLocalBackScope =>
      _isSearching ||
      (_currentTabIndex == 0 && (_isSelectionMode || _currentFolderId != null));

  bool _handleLocalBack() {
    // A dialog or pushed page owns Back until it closes.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isEndDrawerOpen ?? false) {
      scaffold!.closeEndDrawer();
      return true;
    }
    if (!_hasLocalBackScope) {
      // go('/home')で来たホーム（キャンバス・書き出しの後など）は履歴が
      // 1枚だけで、go_routerは戻れる画面が無いとアプリを閉じる。
      // 起動画面へ戻す。
      if (context.canPop()) return false;
      context.go('/');
      return true;
    }
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

  void _longPressLibraryEntry(String id) => setState(() {
    _isSelectionMode = true;
    _selectedIds.add(id);
  });

  void _toggleLibraryEntry(String id) => setState(() {
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    _isSelectionMode = _selectedIds.isNotEmpty;
  });

  void _selectAllLibrary() => setState(() {
    _selectedIds.addAll(_visibleLibraryIds);
    _isSelectionMode = _selectedIds.isNotEmpty;
  });

  HomeClipboardEntry? _singleLibrarySelection({bool cut = false}) {
    if (_selectedIds.length != 1) return null;
    final id = _selectedIds.first;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    if (id.startsWith('work_file:')) {
      final path = id.substring('work_file:'.length);
      return HomeClipboardEntry(
        source: HomePasteArea.works,
        id: path,
        name: File(path).uri.pathSegments.last,
        isCut: cut,
      );
    }
    if (id.startsWith('work_folder:')) {
      final folderId = id.substring('work_folder:'.length);
      final folder = ws.folders.where((f) => f.id == folderId).firstOrNull;
      if (folder == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.works,
        id: folderId,
        name: folder.name,
        isFolder: true,
        isCut: cut,
      );
    }
    if (id.startsWith('shared_file:')) {
      final projectId = id.substring('shared_file:'.length);
      final project = ps.shared.where((p) => p.id == projectId).firstOrNull;
      if (project == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.received,
        id: projectId,
        name: project.name,
        isCut: cut,
      );
    }
    if (id.startsWith('shared_folder:')) {
      final folderId = id.substring('shared_folder:'.length);
      final folder = ps.sharedFolders
          .where((f) => f.id == folderId)
          .firstOrNull;
      if (folder == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.received,
        id: folderId,
        name: folder.name,
        isFolder: true,
        isCut: cut,
      );
    }
    if (id.startsWith('outgoing_file:')) {
      final path = id.substring('outgoing_file:'.length);
      final entry = ps.outgoingShares.where((e) => e.path == path).firstOrNull;
      if (entry == null) return null;
      return HomeClipboardEntry(
        source: HomePasteArea.outgoing,
        id: path,
        name: entry.name,
        isCut: cut,
      );
    }
    return null;
  }

  void _copySelectedLibrary() {
    final entry = _singleLibrarySelection();
    if (entry == null) return;
    _copyLibraryEntry(entry);
    _endProjectSelection();
  }

  Future<void> _copySelectedTrash() async {
    if (_selectedIds.length != 1) return;
    final id = _selectedIds.first;
    final ps = context.read<ProjectService>();
    HomeClipboardEntry? entry;
    if (id.startsWith('trash_project:')) {
      final projectId = id.substring('trash_project:'.length);
      final project = ps.trash.where((p) => p.id == projectId).firstOrNull;
      if (project != null) {
        entry = HomeClipboardEntry(
          source: HomePasteArea.trash,
          id: projectId,
          name: project.name,
          originalArea: project.isSharedImport
              ? HomePasteArea.received
              : HomePasteArea.projects,
        );
      }
    } else if (id.startsWith('trash_folder:')) {
      final folderId = id.substring('trash_folder:'.length);
      final folder = ps.trashedFolders
          .where((f) => f.folder.id == folderId)
          .firstOrNull;
      if (folder != null) {
        entry = HomeClipboardEntry(
          source: HomePasteArea.trash,
          id: folderId,
          name: folder.folder.name,
          isFolder: true,
          originalArea: folder.isShared
              ? HomePasteArea.received
              : HomePasteArea.projects,
        );
      }
    } else if (id.startsWith('trash_local:')) {
      final localId = id.substring('trash_local:'.length);
      final items = await LocalFileTrashService.list();
      final local = items.where((e) => e.id == localId).firstOrNull;
      if (local != null) {
        entry = HomeClipboardEntry(
          source: HomePasteArea.trash,
          id: local.id,
          name: local.fileName,
          isFolder: local.isFolder,
          originalArea: local.kind == LocalTrashKind.outgoingShare
              ? HomePasteArea.outgoing
              : HomePasteArea.works,
        );
      }
    }
    if (entry == null || !mounted) return;
    _copyLibraryEntry(entry);
    _endProjectSelection();
  }

  void _cutSelectedLibrary() {
    final entry = _singleLibrarySelection(cut: true);
    if (entry == null) return;
    _copyLibraryEntry(entry);
    _endProjectSelection();
  }

  Future<void> _trashSelectedLibrary() async {
    if (_selectedIds.isEmpty) return;
    final selected = _selectedIds.toList(growable: false);
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.homeMoveToTrash),
        content: Text(l10n.homeMoveToTrashConfirm(selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.commonMove),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    try {
      for (final id in selected) {
        if (id.startsWith('work_file:')) {
          final path = id.substring('work_file:'.length);
          await LocalFileTrashService.move(
            File(path),
            LocalTrashKind.exportedWork,
          );
        } else if (id.startsWith('work_folder:')) {
          final folderId = id.substring('work_folder:'.length);
          final folder = ws.folders.where((f) => f.id == folderId).firstOrNull;
          if (folder == null) continue;
          final exports = await ExportEngine.listExportedFiles(
            forceRefresh: true,
          );
          final files = exports
              .where(
                (file) => ws.folderIdOf(file.uri.pathSegments.last) == folderId,
              )
              .toList();
          await LocalFileTrashService.moveWorkFolder(
            folderName: folder.name,
            files: files,
          );
          await ws.deleteFolder(folderId);
        } else if (id.startsWith('shared_file:')) {
          final projectId = id.substring('shared_file:'.length);
          final project = ps.shared.where((p) => p.id == projectId).firstOrNull;
          if (project != null && !project.isFavorite) {
            await ps.deleteProject(projectId);
          }
        } else if (id.startsWith('shared_folder:')) {
          final folderId = id.substring('shared_folder:'.length);
          final folder = ps.sharedFolders
              .where((f) => f.id == folderId)
              .firstOrNull;
          if (folder != null && !folder.isFavorite) {
            await ps.moveFolderToTrash(folderId, shared: true);
          }
        } else if (id.startsWith('outgoing_file:')) {
          await LocalFileTrashService.move(
            File(id.substring('outgoing_file:'.length)),
            LocalTrashKind.outgoingShare,
          );
          await ps.refreshOutgoingShares();
        }
      }
      StorageInfoService().invalidate();
      if (mounted) _endProjectSelection();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
    }
  }

  Future<void> _restoreSelectedTrash() async {
    if (_selectedIds.isEmpty) return;
    final selected = _selectedIds.toList(growable: false);
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.commonRestore),
        content: Text(
          Localizations.localeOf(context).languageCode == 'ja'
              ? '${selected.length}件を復元しますか？'
              : 'Restore ${selected.length} selected items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.commonRestore),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    try {
      final local = await LocalFileTrashService.list();
      for (final id in selected) {
        if (id.startsWith('trash_project:')) {
          await ps.restoreProject(id.substring('trash_project:'.length));
        } else if (id.startsWith('trash_folder:')) {
          await ps.restoreTrashedFolder(id.substring('trash_folder:'.length));
        } else if (id.startsWith('trash_local:')) {
          final key = id.substring('trash_local:'.length);
          final entry = local.where((e) => e.id == key).firstOrNull;
          if (entry == null) continue;
          if (entry.isFolder) {
            await LocalFileTrashService.restoreWorkFolder(entry, ws);
          } else {
            await LocalFileTrashService.restore(entry);
          }
        }
      }
      StorageInfoService().invalidate();
      if (mounted) _endProjectSelection();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
    }
  }

  void _endProjectSelection() => setState(() {
    _selectedIds.clear();
    _isSelectionMode = false;
  });

  Widget _buildHomeAction({
    Key? key,
    required String heroTag,
    required String tooltip,
    required bool compact,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return FloatingActionButton(
      key: key,
      heroTag: heroTag,
      mini: compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      tooltip: tooltip,
      // ThemeService provides the common shape, colors and zero shadow.
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  Widget _buildCreateWorkFolderAction(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) => _buildHomeAction(
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
    if (_isSelectionMode ||
        _currentTabIndex == 3 ||
        (_currentTabIndex == 2 && _sharedOutgoing))
      return null;
    final compact = MediaQuery.sizeOf(context).height < 400;

    // The footer and the scrollable tab body have separate hit regions.
    final projects = _currentTabIndex == 0;
    final shared = _currentTabIndex == 2;
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
              compact: compact,
              heroTag: 'home-add-project',
              tooltip: l10n.commonAdd,
              onPressed: () => _showAddChoiceSheet(context),
              icon: Icons.add,
            ),
          ] else if (shared)
            _buildHomeAction(
              compact: compact,
              heroTag: 'shared-add-folder',
              tooltip: l10n.homeAddSheetNewFolder,
              onPressed: () => showCreateFolderNameDialog(
                context,
                (name) =>
                    context.read<ProjectService>().createSharedFolder(name),
              ),
              icon: Icons.create_new_folder_outlined,
            )
          else
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
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final visibleIds = _visibleProjectIds(service);
    final folderIds = service.folders
        .where((f) => visibleIds.contains(f.id) && _selectedIds.contains(f.id))
        .map((f) => f.id)
        .toSet();
    // Selecting a parent and child must not move the same subtree twice.
    final rootFolderIds = folderIds
        .where(
          (id) => !folderIds.any(
            (ancestor) =>
                id != ancestor && service.isFolderDescendantOf(id, ancestor),
          ),
        )
        .toList();
    final coveredFolderIds = <String>{
      for (final id in rootFolderIds) ...service.folderSubtreeIds(id),
    };
    final directProjectIds = service.projects
        .where(
          (p) =>
              !p.isSharedImport &&
              visibleIds.contains(p.id) &&
              _selectedIds.contains(p.id) &&
              !coveredFolderIds.contains(p.folderId),
        )
        .map((p) => p.id)
        .toList();
    final count = rootFolderIds.length + directProjectIds.length;
    if (count == 0) return;
    bool includesFavorite() =>
        service.folders.any(
          (f) => rootFolderIds.contains(f.id) && f.isFavorite,
        ) ||
        service.projects.any(
          (p) =>
              p.isFavorite &&
              (directProjectIds.contains(p.id) ||
                  coveredFolderIds.contains(p.folderId)),
        );
    if (includesFavorite()) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
      );
      return;
    }
    final projectCountInFolders = rootFolderIds.fold<int>(
      0,
      (count, id) => count + service.folderContentCounts(id).projects,
    );
    final subfolderCount = rootFolderIds.fold<int>(
      0,
      (count, id) => count + service.folderContentCounts(id).folders,
    );
    final names = [
      for (final id in directProjectIds)
        ...service.projects.where((p) => p.id == id).map((p) => p.name),
      for (final id in rootFolderIds)
        ...service.folders.where((f) => f.id == id).map((f) => f.name),
    ];
    final descendantText = projectCountInFolders + subfolderCount == 0
        ? ''
        : Localizations.localeOf(context).languageCode == 'ja'
        ? '\nフォルダの中のプロジェクト$projectCountInFolders件・フォルダ$subfolderCount件も一緒に移動します。'
        : '\nThis also moves $projectCountInFolders projects and $subfolderCount nested folders.';
    showDialog<void>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: l10n.homeMoveToTrashConfirm(count) + descendantText,
        confirmLabel: l10n.commonMove,
        itemNames: names,
        onApply: () async {
          // Recheck protection before changing anything, not just on dialog open.
          if (includesFavorite()) throw const FavoriteProjectDeleteException();
          for (final id in rootFolderIds) {
            await service.moveFolderToTrash(id);
          }
          for (final id in directProjectIds) {
            await service.deleteProject(id);
          }
          if (!mounted) return;
          setState(() {
            _selectedIds.removeAll({...rootFolderIds, ...directProjectIds});
            _isSelectionMode = _selectedIds.isNotEmpty;
          });
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.homeMovedToTrashSnackbar(count)),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: l10n.homeUndoAction,
                onPressed: () async {
                  try {
                    for (final id in rootFolderIds) {
                      await service.restoreTrashedFolder(id);
                    }
                    for (final id in directProjectIds) {
                      await service.restoreProject(id);
                    }
                  } catch (error, stackTrace) {
                    AppErrorReporter.record(error, stackTrace);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.homeTrashOperationFailed)),
                      );
                    }
                  }
                },
              ),
            ),
          );
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
    _homeFocus.requestFocus();
    _changeProjectScope(_resetProjectSearch);
  }

  void _openProjectFolder(String id) {
    if (_isSearching) _homeFocus.requestFocus();
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

  /// 検索・引き出しを閉じるEsc。押し続けたときの繰り返しには反応しない
  /// （引き出しを閉じた後の繰り返しで、検索まで閉じて検索語を消さない）。
  static const _escapeOnce = SingleActivator(
    LogicalKeyboardKey.escape,
    includeRepeats: false,
  );

  /// 設定画面「ショートカット設定」の割り当て一覧から、ホーム画面で
  /// 有効なキー割り当てのマップを組み立てる。ツール選択の割り当ては
  /// キャンバスモード専用の概念のためここでは無視する。
  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
    BuildContext context,
  ) {
    final bindings = context.watch<ShortcutService>().bindings;
    if (_currentTabIndex != 0) return {};
    // 引き出しが開いている間は、その後ろの一覧（押せない）を全選択・
    // 貼り付け等で操作しない。Escは引き出しだけを閉じる。
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      return {_escapeOnce: () => _scaffoldKey.currentState?.closeEndDrawer()};
    }
    // 検索中は全選択・コピー等を効かせない（検索で隠れた作品を操作しない）。
    // Escは検索を閉じる（Enterで入力を終えた後も）。
    if (_isSearching) return {_escapeOnce: _closeProjectSearch};
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
    if (_isSelectionMode) {
      result[_escapeOnce] = _endProjectSelection;
    } else if (_clipboardIsCut) {
      result[_escapeOnce] = _cancelCutClipboard;
    }
    return result;
  }

  /// Clear the in-memory clipboard, including items copied from other tabs.
  /// The toolbar disappears on the same rebuild.
  void _clearHomeClipboard() {
    if (!mounted || _pasting) return;
    setState(() {
      _clipboardProjectIds.clear();
      _clipboardFolderIds.clear();
      _otherClipboard = null;
      _clipboardSourceArea = HomePasteArea.projects;
      _clipboardIsCut = false;
    });
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
  }

  void _cancelCutClipboard() {
    if (!_clipboardIsCut) return;
    _clearHomeClipboard();
  }

  void _showClipboardFeedback(String message, {bool allowUndoCut = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: allowUndoCut
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.homeUndoAction,
                onPressed: _cancelCutClipboard,
              )
            : null,
      ),
    );
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
      _clipboardSourceArea = HomePasteArea.projects;
      _otherClipboard = null;
      _clipboardIsCut = true;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    final count = _clipboardProjectIds.length + _clipboardFolderIds.length;
    if (count > 0 && mounted) {
      _showClipboardFeedback(
        AppLocalizations.of(context)!.homeCutSnackbar(count),
        allowUndoCut: true,
      );
    }
  }

  /// Project and folder copies preserve source references for repeated paste.
  void _copySelected() {
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
      _clipboardSourceArea = HomePasteArea.projects;
      _otherClipboard = null;
      _clipboardIsCut = false;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    final count = _clipboardProjectIds.length + _clipboardFolderIds.length;
    if (count > 0 && mounted) {
      _showClipboardFeedback(
        AppLocalizations.of(context)!.homeCopiedSnackbar(count),
      );
    }
  }

  bool get _hasClipboard =>
      _clipboardProjectIds.isNotEmpty ||
      _clipboardFolderIds.isNotEmpty ||
      _otherClipboard != null;

  void _copyLibraryEntry(HomeClipboardEntry entry) {
    setState(() {
      _clipboardProjectIds.clear();
      _clipboardFolderIds.clear();
      _clipboardSourceArea = entry.source;
      _clipboardIsCut = entry.isCut;
      _otherClipboard = entry;
    });
    if (mounted) {
      _showClipboardFeedback(
        AppLocalizations.of(context)!.homeCopiedSnackbar(1),
      );
    }
  }

  HomePasteArea get _pasteDestination => switch (_currentTabIndex) {
    0 => HomePasteArea.projects,
    1 => HomePasteArea.works,
    2 => _sharedOutgoing ? HomePasteArea.outgoing : HomePasteArea.received,
    _ => HomePasteArea.trash,
  };

  Future<void> _explainPasteRestriction(String ja, String en) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('homePasteRestrictionDialog'),
        title: Text(
          Localizations.localeOf(ctx).languageCode == 'ja'
              ? 'この場所にはペーストできません'
              : 'Cannot paste here',
        ),
        content: Text(
          Localizations.localeOf(ctx).languageCode == 'ja' ? ja : en,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmPasteToTrash(List<String> names) async {
    final days = context.read<SettingsService>().trashAutoDeleteDays;
    final l10n = AppLocalizations.of(context)!;
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            key: const Key('homePasteToTrashDialog'),
            title: Text(l10n.homeMoveToTrash),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ja
                        ? '以下の作品・フォルダをゴミ箱に捨てますか？'
                        : 'Move the following files and folders to Trash?',
                  ),
                  for (final name in names) Text('・$name'),
                  const SizedBox(height: 12),
                  Text(
                    ja
                        ? days > 0
                              ? '※ゴミ箱に移動されたファイルは$days日後に完全削除されます。'
                              : '※ゴミ箱の自動削除はオフです。手動で削除するまで保存されます。'
                        : days > 0
                        ? 'Files in Trash are permanently deleted after $days days.'
                        : 'Automatic deletion is off. Items remain until deleted manually.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                key: const Key('homePasteTrashConfirmButton'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.commonMove),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _pasting = false;
  Future<void> _pasteClipboard() async {
    if (_pasting || !_hasClipboard) return;
    if (_otherClipboard != null) {
      await _pasteLibraryEntry();
      return;
    }
    final service = context.read<ProjectService>();
    final folderIds = _clipboardFolderIds.toList();
    final projectIds = _clipboardProjectIds.toList();
    final target = _pasteDestination;
    final emptyFolders = folderIds.every(
      (id) => service.folderContentCounts(id).projects == 0,
    );
    final decision = HomePastePolicy.check(
      source: _clipboardSourceArea,
      destination: target,
      containsFiles: projectIds.isNotEmpty || !emptyFolders,
      containsFolders: folderIds.isNotEmpty,
    );
    if (decision != HomePasteDecision.allowed) {
      await _explainPasteRestriction(
        'タブやピルボタンをまたいだ形式違いのペーストはできません。'
            '作品・ファイルはコピー元と同じタブ・区分にペーストしてください。'
            '中にファイルのないフォルダのみ例外です。',
        'Files and projects cannot be pasted across incompatible tab or '
            'pill formats. Paste into the original collection. Empty folders '
            'without files are the only exception.',
      );
      return;
    }
    if (target == HomePasteArea.outgoing) {
      await _explainPasteRestriction(
        '共有の「自分が作成したもの」はファイル専用で、'
            'フォルダを保存する機能がないため、ここにはペーストできません。',
        'The outgoing-shares collection does not support folders.',
      );
      return;
    }
    if (target != HomePasteArea.projects &&
        target != HomePasteArea.trash &&
        folderIds.any((id) => service.folderContentCounts(id).folders > 0)) {
      await _explainPasteRestriction(
        'このフォルダには子フォルダがあります。'
            '移動先ではフォルダの入れ子に対応していないため、'
            '中の構造を失わないようペーストを中止しました。',
        'This folder contains nested folders. The destination does not '
            'support nesting, so the paste was cancelled to preserve its structure.',
      );
      return;
    }
    if (target == HomePasteArea.trash) {
      final names = [
        for (final id in projectIds)
          ...service.projects.where((p) => p.id == id).map((p) => p.name),
        for (final id in folderIds)
          ...service.folders.where((f) => f.id == id).map((f) => f.name),
      ];
      if (names.isEmpty || !await _confirmPasteToTrash(names) || !mounted)
        return;
    }
    setState(() => _pasting = true);
    try {
      if (target == HomePasteArea.trash) {
        // Duplicate descendants can appear in the selection. Moving a
        // parent folder takes its descendants; skip already-trashed rows.
        for (final id in folderIds) {
          await service.moveFolderToTrash(id);
          _clipboardFolderIds.remove(id);
        }
        for (final id in projectIds) {
          if (service.projects.any((p) => p.id == id)) {
            await service.deleteProject(id);
          }
          _clipboardProjectIds.remove(id);
        }
      } else if (target == HomePasteArea.projects) {
        for (final id in projectIds) {
          if (_clipboardIsCut) {
            if (!service.projects.any((project) => project.id == id)) {
              throw const _ClipboardSourceMissing();
            }
            await service.moveToFolder(id, _currentFolderId);
            _clipboardProjectIds.remove(id);
          } else {
            if (!await service.duplicateProject(
              id,
              targetFolderId: _currentFolderId,
              useTargetFolder: true,
            )) {
              throw const _ClipboardSourceMissing();
            }
          }
        }
        for (final id in folderIds) {
          if (_clipboardIsCut) {
            if (id == _currentFolderId ||
                service.isFolderDescendantOf(_currentFolderId ?? '', id)) {
              throw StateError('Cannot move folder inside itself');
            }
            if (!service.folders.any((folder) => folder.id == id)) {
              throw const _ClipboardSourceMissing();
            }
            await service.moveFolderTo(id, _currentFolderId);
            _clipboardFolderIds.remove(id);
          } else {
            final source = service.folders.where((f) => f.id == id).firstOrNull;
            if (source == null) throw const _ClipboardSourceMissing();
            final result = await service.duplicateFolder(
              id,
              targetParentId: _currentFolderId,
              name: '${source.name} (コピー)',
            );
            if (result == null) throw const _ClipboardSourceMissing();
          }
        }
      } else {
        // A format-neutral empty folder is created in the destination
        // collection. Removing a cut source occurs ONLY after that succeeds.
        for (final id in folderIds) {
          final folder = service.folders.where((f) => f.id == id).firstOrNull;
          if (folder == null) throw const _ClipboardSourceMissing();
          if (target == HomePasteArea.works) {
            await context.read<WorkFolderService>().createFolder(folder.name);
          } else {
            await service.createSharedFolder(folder.name);
          }
          if (_clipboardIsCut) {
            await service.deleteFolder(id);
            _clipboardFolderIds.remove(id);
          }
        }
      }
      if (mounted) {
        setState(() {});
        _showClipboardFeedback(AppLocalizations.of(context)!.homePasteSnackbar);
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        _showClipboardFeedback(
          error is _ClipboardSourceMissing
              ? _clipboardMissingMessage(context)
              : error is StateError &&
                    error.message == 'Cannot move folder inside itself'
              ? AppLocalizations.of(context)!.homePasteSkippedIntoSelf(1)
              : !_clipboardIsCut &&
                    target == HomePasteArea.projects &&
                    projectIds.isNotEmpty
              ? AppLocalizations.of(context)!.homePasteFailed
              : folderSaveFailureText(AppLocalizations.of(context)!, error),
        );
      }
    } finally {
      if (mounted) setState(() => _pasting = false);
    }
  }

  /// An exported-work folder owns real video/image files, not project rows.
  /// Copy the bytes and only then write each new file's membership.
  Future<void> _copyWorkFolderWithContents(
    String sourceId,
    String sourceName,
    WorkFolderService workFolders,
  ) async {
    if (!workFolders.folders.any((folder) => folder.id == sourceId)) {
      throw StateError('Export folder no longer exists');
    }
    final exported = await ExportEngine.listExportedFiles(forceRefresh: true);
    final members = exported
        .where(
          (file) =>
              workFolders.folderIdOf(file.uri.pathSegments.last) == sourceId,
        )
        .toList();
    final used = workFolders.folders.map((folder) => folder.name).toSet();
    var copyName = '$sourceName (コピー)';
    for (var number = 2; used.contains(copyName); number++) {
      copyName = '$sourceName (コピー $number)';
    }
    final copiedFolder = await workFolders.createFolder(copyName);
    final copies = <File>[];
    try {
      for (final source in members) {
        final filename = source.uri.pathSegments.last;
        final dot = filename.lastIndexOf('.');
        final name = dot > 0 ? filename.substring(0, dot) : filename;
        final ext = dot > 0 ? filename.substring(dot) : '';
        var counter = 1;
        late File destination;
        do {
          destination = File('${source.parent.path}/$name (コピー $counter)$ext');
          counter++;
        } while (await destination.exists());
        final saved = await source.copy(destination.path);
        copies.add(saved);
        if (await saved.length() != await source.length()) {
          throw FileSystemException('Incomplete folder copy', source.path);
        }
        await workFolders.moveFileToFolder(
          saved.uri.pathSegments.last,
          copiedFolder.id,
        );
      }
      LocalFileTrashService.changes.value++;
      StorageInfoService().invalidate();
    } catch (_) {
      // If copying fails, preserve any completed files and folder so no
      // persistent metadata points at deleted data.
      LocalFileTrashService.changes.value++;
      rethrow;
    }
  }

  Future<void> _pasteLibraryEntry() async {
    final entry = _otherClipboard;
    if (entry == null || _pasting) return;
    final ps = context.read<ProjectService>();
    final ws = context.read<WorkFolderService>();
    final dest = _pasteDestination;
    // Persisted folder memberships can outlive an exported file that was
    // removed. The empty-folder exception is based on files that actually
    // exist in the Works list, not stale preference records.
    var workFolderHasFiles = false;
    if (entry.isFolder && entry.source == HomePasteArea.works) {
      try {
        final exports = await ExportEngine.listExportedFiles(
          forceRefresh: true,
        );
        workFolderHasFiles = exports.any(
          (file) => ws.folderIdOf(file.uri.pathSegments.last) == entry.id,
        );
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
        await _explainPasteRestriction(
          'フォルダの中身を確認できませんでした。データを保護するため、'
              'ペーストを中止しました。',
          'Could not inspect folder contents safely. Paste was cancelled.',
        );
        return;
      }
      if (!mounted) return;
    }
    final containsFiles =
        !entry.isFolder ||
        (entry.source == HomePasteArea.works && workFolderHasFiles) ||
        (entry.source == HomePasteArea.received &&
            ps.shared.any((p) => p.sharedFolderId == entry.id));
    final decision = HomePastePolicy.check(
      source: entry.source,
      destination: dest,
      originalArea: entry.originalArea,
      containsFiles: containsFiles,
      containsFolders: entry.isFolder,
    );
    if (decision != HomePasteDecision.allowed) {
      await _explainPasteRestriction(
        'タブやピルボタンをまたいだ形式違いのペーストはできません。'
            '作品やファイルは元の形式の区分にペーストしてください。'
            '中にファイルの無いフォルダのみ例外です。',
        'Files cannot be pasted across tab or pill formats. '
            'Restore files to their original collection. Only empty folders are an exception.',
      );
      return;
    }
    if (entry.isFolder && dest == HomePasteArea.outgoing) {
      await _explainPasteRestriction(
        '共有の「自分が作成したもの」はファイル専用でフォルダは保存できません。',
        'Outgoing shares do not support folders.',
      );
      return;
    }
    if (dest == HomePasteArea.trash) {
      if (entry.isFolder &&
          entry.source != HomePasteArea.works &&
          entry.source != HomePasteArea.received) {
        await _explainPasteRestriction(
          'この形式のフォルダはゴミ箱に保管できません。',
          'This folder format cannot be archived in Trash.',
        );
        return;
      }
      if (!await _confirmPasteToTrash([entry.name]) || !mounted) return;
    }
    if (entry.source == HomePasteArea.trash) {
      final l10n = AppLocalizations.of(context)!;
      final japanese = Localizations.localeOf(context).languageCode == 'ja';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('homePasteRestoreDialog'),
          title: Text(japanese ? 'ゴミ箱から復元' : 'Restore from Trash'),
          content: Text(
            (japanese
                    ? '以下の作品・フォルダをゴミ箱から復元しますか？'
                    : 'Restore this item from Trash?') +
                '\n・${entry.name}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('homePasteRestoreConfirmButton'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonRestore),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _pasting = true);
    try {
      if (entry.source == HomePasteArea.trash) {
        if (entry.isFolder) {
          if (entry.originalArea == HomePasteArea.works) {
            final files = await LocalFileTrashService.list();
            final folder = files
                .where((f) => f.id == entry.id && f.isFolder)
                .firstOrNull;
            if (folder == null) {
              throw FileSystemException(
                'Missing trashed work folder',
                entry.id,
              );
            }
            await LocalFileTrashService.restoreWorkFolder(folder, ws);
            StorageInfoService().invalidate();
          } else {
            await ps.restoreTrashedFolder(entry.id);
          }
        } else if (entry.originalArea == HomePasteArea.projects ||
            entry.originalArea == HomePasteArea.received) {
          await ps.restoreProject(entry.id);
        } else {
          final files = await LocalFileTrashService.list();
          final file = files.where((f) => f.id == entry.id).firstOrNull;
          if (file == null)
            throw FileSystemException('Missing trash entry', entry.id);
          await LocalFileTrashService.restore(file);
          StorageInfoService().invalidate();
          if (entry.originalArea == HomePasteArea.outgoing) {
            await ps.refreshOutgoingShares();
          }
        }
        _otherClipboard = null;
      } else if (dest == HomePasteArea.trash) {
        if (entry.isFolder && entry.source == HomePasteArea.received) {
          final moved = await ps.moveFolderToTrash(entry.id, shared: true);
          if (moved == null) throw StateError('Shared folder not found');
        } else if (entry.isFolder && entry.source == HomePasteArea.works) {
          if (!ws.folders.any((folder) => folder.id == entry.id)) {
            throw StateError('Export folder not found');
          }
          final files = await ExportEngine.listExportedFiles(
            forceRefresh: true,
          );
          final members = files
              .where(
                (file) => ws.folderIdOf(file.uri.pathSegments.last) == entry.id,
              )
              .toList();
          await LocalFileTrashService.moveWorkFolder(
            folderName: entry.name,
            files: members,
          );
          // Delete membership only AFTER the archive is safely stored.
          await ws.deleteFolder(entry.id);
          StorageInfoService().invalidate();
        } else if (entry.source == HomePasteArea.received) {
          await ps.deleteProject(entry.id);
        } else {
          await LocalFileTrashService.move(
            File(entry.id),
            entry.source == HomePasteArea.works
                ? LocalTrashKind.exportedWork
                : LocalTrashKind.outgoingShare,
          );
          StorageInfoService().invalidate();
          if (entry.source == HomePasteArea.outgoing) {
            await ps.refreshOutgoingShares();
          }
        }
        _otherClipboard = null;
      } else if (entry.isFolder) {
        if (dest == HomePasteArea.projects) {
          await ps.createFolder(entry.name, parentFolderId: _currentFolderId);
        } else if (dest == HomePasteArea.works) {
          if (entry.source == HomePasteArea.works) {
            await _copyWorkFolderWithContents(entry.id, entry.name, ws);
          } else {
            await ws.createFolder(entry.name);
          }
        } else if (dest == HomePasteArea.received) {
          if (entry.source == HomePasteArea.received) {
            await ps.duplicateSharedFolderWithContents(entry.id);
          } else {
            await ps.createSharedFolder(entry.name);
          }
        }
        if (entry.isCut) {
          if (entry.source == HomePasteArea.works) {
            await ws.deleteFolder(entry.id);
          } else if (entry.source == HomePasteArea.received) {
            await ps.deleteSharedFolder(entry.id);
          }
          _otherClipboard = null;
        }
      } else if (entry.source == HomePasteArea.received) {
        if (!await ps.duplicateProject(entry.id)) {
          throw const _ClipboardSourceMissing();
        }
      } else {
        final original = File(entry.id);
        if (!await original.exists())
          throw FileSystemException('Missing file', entry.id);
        final fileName = original.uri.pathSegments.last;
        final dot = fileName.lastIndexOf('.');
        final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
        final extension = dot > 0 ? fileName.substring(dot) : '';
        var n = 1;
        late File destFile;
        do {
          destFile = File('${original.parent.path}/$stem (コピー $n)$extension');
          n++;
        } while (await destFile.exists());
        await original.copy(destFile.path);
        if (entry.source == HomePasteArea.outgoing) {
          await ps.refreshOutgoingShares();
        } else {
          final folder = ws.folderIdOf(fileName);
          if (folder != null) {
            await ws.moveFileToFolder(destFile.uri.pathSegments.last, folder);
          }
          LocalFileTrashService.changes.value++;
        }
      }
      if (mounted) {
        setState(() {});
        _showClipboardFeedback(AppLocalizations.of(context)!.homePasteSnackbar);
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        _showClipboardFeedback(
          error is _ClipboardSourceMissing
              ? _clipboardMissingMessage(context)
              : AppLocalizations.of(context)!.homeTrashOperationFailed,
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

/// Responsive four-tab navigation: icons on compact phones and centered
/// icon/label pairs once every translated label fits (same as Works Plaza).
class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({
    required this.controller,
    required this.currentIndex,
    required this.labels,
  });

  final TabController controller;
  final int currentIndex;
  final List<String> labels;

  static const _icons = <IconData>[
    Icons.movie_creation_outlined,
    Icons.video_library_outlined,
    Icons.share_outlined,
    Icons.delete_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = scheme.primary;
    final labelStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context);
        final cellWidth = constraints.maxWidth / labels.length;
        const iconWidth = 24.0;
        const gap = 8.0;
        const breathingRoom = 16.0;
        final showLabels = labels.every((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: textScale,
            locale: Localizations.localeOf(context),
            maxLines: 1,
          )..layout();
          final fits =
              iconWidth + gap + painter.width + breathingRoom <= cellWidth;
          painter.dispose();
          return fits;
        });
        return TabBar(
          controller: controller,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          labelColor: selected,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: labelStyle,
          unselectedLabelStyle: labelStyle,
          indicatorColor: selected,
          tabs: [
            for (var i = 0; i < labels.length; i++)
              Tab(
                height: 48,
                child: Semantics(
                  key: ValueKey('home_tab_$i'),
                  button: true,
                  selected: currentIndex == i,
                  label: labels[i],
                  child: Tooltip(
                    message: labels[i],
                    triggerMode: TooltipTriggerMode.longPress,
                    child: Center(
                      child: showLabels
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_icons[i], size: iconWidth),
                                const SizedBox(width: gap),
                                Flexible(
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ],
                            )
                          : Icon(_icons[i], size: iconWidth),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 共有一覧。ホームタブと'/shared'直リンクで共用する。
class SharedScreen extends StatefulWidget {
  const SharedScreen({
    super.key,
    this.embedded = false,
    this.onDirectionChanged,
    this.onCopyEntry,
    this.screenFocus,
    this.viewMode,
    this.onViewModeChanged,
    this.searchQuery = '',
  });

  final bool embedded;
  final ProjectViewMode? viewMode;
  final ValueChanged<ProjectViewMode>? onViewModeChanged;
  final String searchQuery;
  final ValueChanged<bool>? onDirectionChanged;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  /// ホームの画面のフォーカス（保存先を読めなかった知らせが消えたとき、
  /// フォーカスを戻す先）。
  final FocusNode? screenFocus;

  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen> {
  // Keep the received and locally exported snapshot collections distinct.
  bool _showOutgoing = false;
  ProjectViewMode? _standaloneViewMode;

  ProjectViewMode _effectiveViewMode(BuildContext context) =>
      widget.viewMode ??
      _standaloneViewMode ??
      switch (tileScreenClassForWidth(MediaQuery.sizeOf(context).width)) {
        TileScreenClass.phone => ProjectViewMode.small,
        TileScreenClass.tablet => ProjectViewMode.medium,
        TileScreenClass.desktop => ProjectViewMode.large,
      };

  void _selectViewMode(ProjectViewMode value) {
    if (widget.onViewModeChanged != null) {
      widget.onViewModeChanged!(value);
    } else {
      setState(() => _standaloneViewMode = value);
    }
  }

  @override
  void initState() {
    super.initState();
    LocalFileTrashService.changes.addListener(_refreshSavedShares);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSavedShares();
    });
  }

  @override
  void dispose() {
    LocalFileTrashService.changes.removeListener(_refreshSavedShares);
    super.dispose();
  }

  void _refreshSavedShares() {
    if (mounted) context.read<ProjectService>().refreshOutgoingShares();
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SegmentedButton<bool>(
                  key: const Key('sharedDirectionSegmentedControl'),
                  showSelectedIcon: false,
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.standard,
                    shape: const WidgetStatePropertyAll(StadiumBorder()),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(
                        _shareCollectionText(context, outgoing: false),
                        key: const Key('sharedReceivedFilter'),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(
                        _shareCollectionText(context, outgoing: true),
                        key: const Key('sharedOutgoingFilter'),
                      ),
                    ),
                  ],
                  selected: {_showOutgoing},
                  onSelectionChanged: (selection) {
                    setState(() => _showOutgoing = selection.single);
                    widget.onDirectionChanged?.call(_showOutgoing);
                  },
                ),
              ),
            ),
          ),
          _HomeCollectionSortHeader(
            sortByName: _sortByName,
            sortAscending: _sortAscending,
            onSortByNameChanged: _setSortByName,
            onToggleDirection: _toggleSortDirection,
            leading: FilterChip(
              key: const Key('sharedFavoritesOnlyFilter'),
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
                ? _OutgoingSharesList(
                    onCopyEntry: widget.onCopyEntry,
                    viewMode: _effectiveViewMode(context),
                    sortMode: _sortMode,
                    showFavoritesOnly: _showFavoritesOnly,
                    searchQuery: widget.searchQuery,
                  )
                : _SharedTab(
                    viewMode: _effectiveViewMode(context),
                    onViewModeChanged: _selectViewMode,
                    sortMode: _sortMode,
                    showFavoritesOnly: _showFavoritesOnly,
                    searchQuery: widget.searchQuery,
                    onCopyEntry: widget.onCopyEntry,
                    screenFocus: widget.screenFocus,
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.embedded || _showOutgoing
          ? null
          : FloatingActionButton(
              heroTag: 'shared-add-folder',
              tooltip: l10n.homeAddSheetNewFolder,
              onPressed: () => showCreateFolderNameDialog(
                context,
                (name) =>
                    context.read<ProjectService>().createSharedFolder(name),
              ),
              child: const Icon(Icons.create_new_folder_outlined),
            ),
    );
  }
}

/// Trash supports four independent multi-select type filters.
enum TrashEntryKind {
  createdProject,
  receivedShare,
  createdShare,
  exportedWork,
}

String _trashKindLabel(BuildContext context, TrashEntryKind kind) {
  final lang = Localizations.localeOf(context).languageCode;
  return switch (lang) {
    'ja' => switch (kind) {
      TrashEntryKind.createdProject => '作成したプロジェクト',
      TrashEntryKind.receivedShare => '受け取った共有ファイル',
      TrashEntryKind.createdShare => '自分が作成した共有ファイル',
      TrashEntryKind.exportedWork => '書き出した作品',
    },
    'ko' => switch (kind) {
      TrashEntryKind.createdProject => '내 프로젝트',
      TrashEntryKind.receivedShare => '받은 공유 파일',
      TrashEntryKind.createdShare => '내 공유 파일',
      TrashEntryKind.exportedWork => '내보낸 작품',
    },
    'zh' => switch (kind) {
      TrashEntryKind.createdProject => '创建的项目',
      TrashEntryKind.receivedShare => '收到的共享文件',
      TrashEntryKind.createdShare => '创建的共享文件',
      TrashEntryKind.exportedWork => '导出的作品',
    },
    _ => switch (kind) {
      TrashEntryKind.createdProject => 'Created project',
      TrashEntryKind.receivedShare => 'Received share',
      TrashEntryKind.createdShare => 'Created share',
      TrashEntryKind.exportedWork => 'Exported work',
    },
  };
}

/// ゴミ箱一覧。ホームタブと'/trash'直リンクで共用する。
class TrashScreen extends StatefulWidget {
  const TrashScreen({
    super.key,
    this.embedded = false,
    this.onCopyEntry,
    this.screenFocus,
    this.searchQuery = '',
  });

  final bool embedded;
  final String searchQuery;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  /// ホームの画面のフォーカス（保存先を読めなかった知らせが消えたとき、
  /// フォーカスを戻す先）。
  final FocusNode? screenFocus;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  // 共有一覧・プロジェクトタブと同じ並び替え基準を、同じ見た目・操作性で
  // 提供する（ゴミ箱にお気に入りの概念はないため絞り込みは対象外）。
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  final Set<TrashEntryKind> _selectedKinds = {...TrashEntryKind.values};

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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final kind in TrashEntryKind.values)
                    FilterChip(
                      key: ValueKey('trashKind_${kind.name}'),
                      label: Text(_trashKindLabel(context, kind)),
                      selected: _selectedKinds.contains(kind),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedKinds.add(kind);
                        } else {
                          _selectedKinds.remove(kind);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          _HomeCollectionSortHeader(
            sortByName: _sortByName,
            sortAscending: _sortAscending,
            onSortByNameChanged: _setSortByName,
            onToggleDirection: _toggleSortDirection,
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: LocalFileTrashService.changes,
              builder: (context, version, _) => _TrashTab(
                key: ValueKey('trash-list-version-$version'),
                sortMode: _sortMode,
                selectedKinds: _selectedKinds,
                searchQuery: widget.searchQuery,
                onCopyEntry: widget.onCopyEntry,
                screenFocus: widget.screenFocus,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exact same sorting header geometry in Projects and Works (root/folders).
/// The shared SortModeControl is allowed the whole available trailing width,
/// so normal phones display the selected field label instead of only a clock.
class _HomeCollectionSortHeader extends StatelessWidget {
  const _HomeCollectionSortHeader({
    this.leading,
    required this.sortByName,
    required this.sortAscending,
    required this.onSortByNameChanged,
    required this.onToggleDirection,
  });

  final Widget? leading;
  final bool sortByName;
  final bool sortAscending;
  final ValueChanged<bool> onSortByNameChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('homeCollectionSortHeader'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: SortModeControl(
              sortByName: sortByName,
              sortAscending: sortAscending,
              onSortByNameChanged: onSortByNameChanged,
              onToggleDirection: onToggleDirection,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Library actions can wrap without taking space from the route title.
class _LibraryListControls extends StatelessWidget {
  const _LibraryListControls({required this.sort});

  final Widget sort;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: LayoutBuilder(
      builder: (context, constraints) => OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 8,
        overflowSpacing: 4,
        children: [
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
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final ProjectSortMode sortMode;
  final bool showFavoritesOnly;
  final String searchQuery;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final FocusNode? screenFocus;

  const _SharedTab({
    required this.viewMode,
    required this.onViewModeChanged,
    required this.sortMode,
    required this.showFavoritesOnly,
    required this.searchQuery,
    this.onCopyEntry,
    this.screenFocus,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    final folders = service.sharedFolders;
    var shared = service.shared;
    if (showFavoritesOnly) {
      shared = shared.where((p) => p.isFavorite).toList();
    }
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      shared = shared
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }
    shared = _sortProjects(shared, sortMode);
    final visibleFolders = service.sharedFolders
        .where(
          (folder) =>
              (!showFavoritesOnly ||
                  folder.isFavorite ||
                  shared.any((p) => p.sharedFolderId == folder.id)) &&
              (query.isEmpty ||
                  folder.name.toLowerCase().contains(query) ||
                  shared.any((p) => p.sharedFolderId == folder.id)),
        )
        .toList();
    HomeCollectionSelectionScope.maybeOf(context)?.onVisibleIds({
      for (final folder in visibleFolders) 'shared_folder:${folder.id}',
      for (final project in shared)
        if (project.sharedFolderId == null ||
            !visibleFolders.any((f) => f.id == project.sharedFolderId))
          'shared_file:${project.id}',
    });
    final l10n = AppLocalizations.of(context)!;
    // 受け取ったものは保存先から読む。読めなかったときは知らせ、
    // 「共有プロジェクトがありません」とは言わない。
    final loadFailed = service.projectsLoadFailed;
    return _FolderableList<Project>(
      reserveForFloatingActions: true,
      allItems: shared,
      folders: visibleFolders,
      viewMode: viewMode,
      gridItemBuilder: (context, project) => _receivedShareProjectTile(
        context,
        project,
        onCopyEntry: onCopyEntry,
        grid: true,
      ),
      header: loadFailed
          ? ProjectsLoadFailureNotice(
              key: const Key('sharedProjectsLoadFailed'),
              onRetry: service.retryLoadProjects,
              screenFocus: screenFocus,
            )
          : null,
      emptyState: loadFailed
          ? null
          : EmptyStatePlaceholder(
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
                viewMode: viewMode,
                onViewModeChanged: onViewModeChanged,
                showFavoritesOnly:
                    showFavoritesOnly &&
                    !service.sharedFolders.any(
                      (folder) => folder.id == folderId && folder.isFavorite,
                    ),
                searchQuery: folderName.toLowerCase().contains(query)
                    ? ''
                    : searchQuery,
                onCopyEntry: onCopyEntry,
              ),
            ),
          ),
      onToggleFolderFavorite: (folder) =>
          context.read<ProjectService>().toggleSharedFolderFavorite(folder.id),
      onRenameFolder: (id, name) =>
          context.read<ProjectService>().renameSharedFolder(id, name),
      onDeleteFolder: (id) async {
        await context.read<ProjectService>().moveFolderToTrash(
          id,
          shared: true,
        );
      },
      onSetFolderThumbnail: (id, {required mode, sourceId, imagePath}) =>
          context.read<ProjectService>().setFolderThumbnail(
            id,
            mode: mode,
            sourceId: sourceId,
            imagePath: imagePath,
            shared: true,
          ),
      onCopyFolder: onCopyEntry == null
          ? null
          : (folder) => onCopyEntry!(
              HomeClipboardEntry(
                source: HomePasteArea.received,
                id: folder.id,
                name: folder.name,
                isFolder: true,
              ),
            ),
      itemBuilder: (context, project) => _receivedShareProjectTile(
        context,
        project,
        onCopyEntry: onCopyEntry,
        grid: false,
      ),
    );
  }
}

Widget _receivedShareProjectTile(
  BuildContext context,
  Project project, {
  required bool grid,
  ValueChanged<HomeClipboardEntry>? onCopyEntry,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final selection = HomeCollectionSelectionScope.maybeOf(context);
  final selectionId = 'shared_file:${project.id}';
  final selecting = selection?.active ?? false;
  final selectedTap = selecting
      ? () => selection!.onToggle(selectionId)
      : () => context.push('/project/${project.id}');
  final captionStyle = const TextStyle(
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );
  Widget cover() {
    final thumbnailPath = project.thumbnailPath;
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return ColoredBox(
        color: Color(project.backgroundColor),
        child: const Center(child: Icon(Icons.movie_creation_outlined)),
      );
    }
    return Image.file(
      File(thumbnailPath),
      fit: BoxFit.cover,
      cacheWidth: 320,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: Color(project.backgroundColor),
        child: const Center(child: Icon(Icons.movie_creation_outlined)),
      ),
    );
  }

  void showFolderMove() {
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

  final selectedLongPress = selection == null
      ? showFolderMove
      : () => selection.onLongPress(selectionId);
  if (grid) {
    return HomeCollectionSelectionSurface(
      selectionId: selectionId,
      child: collectionTileShadow(
        context,
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.transparent, width: 2),
          ),
          child: InkWell(
            onTap: selectedTap,
            onLongPress: selectedLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover(),
                      if (!selecting)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _sharedProjectActions(
                            context,
                            project,
                            onCopyEntry: onCopyEntry,
                            showFavorite: false,
                          ),
                        ),
                      if (!selecting)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: _sharedProjectActions(
                            context,
                            project,
                            onCopyEntry: onCopyEntry,
                            showMenu: false,
                          ),
                        ),
                    ],
                  ),
                ),
                collectionTileCaption(context, project.name),
              ],
            ),
          ),
        ),
      ),
    );
  }
  return HomeCollectionSelectionSurface(
    selectionId: selectionId,
    grid: false,
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: SizedBox(width: 56, height: 56, child: cover()),
        title: Text(project.name, style: captionStyle),
        subtitle: Text(
          l10n.homeProjectMeta(project.fps, project.durationSeconds),
        ),
        onTap: selectedTap,
        onLongPress: selectedLongPress,
        trailing: selecting
            ? null
            : _sharedProjectActions(context, project, onCopyEntry: onCopyEntry),
      ),
    ),
  );
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
Widget _sharedProjectActions(
  BuildContext context,
  Project project, {
  ValueChanged<HomeClipboardEntry>? onCopyEntry,
  bool showFavorite = true,
  bool showMenu = true,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showFavorite)
        CollectionFavoriteButton(
          itemId: project.id,
          favorite: project.isFavorite,
          tooltip: project.isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
          onPressed: () => runProjectAction(
            context,
            () => context.read<ProjectService>().toggleFavorite(project.id),
          ),
        ),
      if (showFavorite && showMenu) const SizedBox(width: 4),
      if (showMenu)
        CollectionActionFrame(
          key: Key('collectionMenu_${project.id}'),
          child: _receivedShareMenu(context, project, onCopyEntry: onCopyEntry),
        ),
    ],
  );
}

Widget _receivedShareMenu(
  BuildContext context,
  Project project, {
  ValueChanged<HomeClipboardEntry>? onCopyEntry,
}) {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<ProjectService>();
  return PopupMenuButton<String>(
    key: ValueKey('receivedShareMenu_${project.id}'),
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_vert, size: CollectionActionFrame.glyphSize),
    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
    onSelected: (action) async {
      switch (action) {
        case 'open':
          context.push('/canvas/${project.id}');
        case 'copyToClipboard':
          onCopyEntry?.call(
            HomeClipboardEntry(
              source: HomePasteArea.received,
              id: project.id,
              name: project.name,
            ),
          );
        case 'rename':
          final controller = TextEditingController(text: project.name);
          try {
            final name = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.commonRename),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  onSubmitted: (name) => Navigator.pop(ctx, name),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
            );
            if (name != null && name.trim().isNotEmpty) {
              await service.renameProject(project.id, name.trim());
            }
          } finally {
            // Dialog's exit animation may still be unwinding; the controller
            // belongs to this action rather than a long-lived screen.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.dispose();
            });
          }
        case 'thumbnail':
          if (context.mounted) {
            await showProjectThumbnailDialog(
              context,
              project: project,
              service: service,
            );
          }
        case 'duplicate':
          await service.duplicateProject(project.id);
        case 'share':
          if (context.mounted) {
            await createAndShareProjectNiashare(context, service, project);
          }
        case 'favorite':
          await runProjectAction(
            context,
            () => service.setFavorite(project.id, !project.isFavorite),
          );
        case 'move':
          if (context.mounted) {
            await showModalBottomSheet<void>(
              context: context,
              builder: (_) => WorkFolderMoveSheet(
                folders: service.sharedFolders,
                filename: project.name,
                onMove: (id) => service.moveToSharedFolder(project.id, id),
              ),
            );
          }
        case 'delete':
          if (project.isFavorite) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
              );
            }
            return;
          }
          if (context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (_) => ProjectTrashDialog(
                title: l10n.homeMoveToTrash,
                message: l10n.homeMoveToTrashConfirm(1),
                confirmLabel: l10n.commonMove,
                itemNames: [project.name],
                onApply: () => service.deleteProject(project.id),
              ),
            );
          }
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
      PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
      PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
      PopupMenuItem(
        value: 'thumbnail',
        child: Text(
          Localizations.localeOf(context).languageCode == 'ja'
              ? 'サムネイル変更'
              : 'Change thumbnail',
        ),
      ),
      PopupMenuItem(
        value: 'share',
        // この作品の共有ファイルの作成・共有が終わるまで、二度目は選べない。
        enabled: !ExportShareService.isRunning(niashareKey(project.id)),
        child: Text(l10n.projectListCreateShareAction),
      ),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          project.isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          l10n.projectDetailTrashMenuItem,
          style: TextStyle(color: ThemeService.activeColorScheme.error),
        ),
      ),
    ],
  );
}

/// A saved .niashare is a frozen file, so its file-specific menu
/// intentionally omits canvas editing and folder operations.
Future<void> _outgoingShareAction(
  BuildContext context,
  SavedOutgoingShare entry,
  String action,
) async {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<ProjectService>();
  final file = File(entry.path);
  try {
    switch (action) {
      case 'share':
        await shareSavedNiashare(context, entry.path);
      case 'rename':
        final controller = TextEditingController(text: entry.name);
        String? value;
        try {
          value = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.commonRename),
              content: TextField(
                autofocus: true,
                controller: controller,
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          );
        } finally {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller.dispose(),
          );
        }
        if (value == null || value.trim() == entry.name) return;
        final name = value.trim().replaceAll(RegExp(r'[\\/]'), '_');
        if (name.isEmpty || name == '.' || name == '..') return;
        final target = File('${file.parent.path}/$name.niashare');
        if (await target.exists()) {
          throw FileSystemException(
            'Share filename already exists',
            target.path,
          );
        }
        await file.rename(target.path);
        await service.refreshOutgoingShares();
      case 'duplicate':
        var index = 1;
        File target;
        do {
          target = File('${file.parent.path}/${entry.name} ($index).niashare');
          index++;
        } while (await target.exists());
        await file.copy(target.path);
        await service.refreshOutgoingShares();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.homeMoveToTrash),
            content: Text(l10n.homeMoveToTrashConfirm(1)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.commonMove),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await LocalFileTrashService.move(file, LocalTrashKind.outgoingShare);
        await service.refreshOutgoingShares();
        StorageInfoService().invalidate();
    }
  } catch (error, stackTrace) {
    AppErrorReporter.record(error, stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
    }
  }
}

class _OutgoingSharesList extends StatelessWidget {
  const _OutgoingSharesList({
    this.onCopyEntry,
    required this.viewMode,
    required this.sortMode,
    required this.showFavoritesOnly,
    required this.searchQuery,
  });
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final ProjectViewMode viewMode;
  final ProjectSortMode sortMode;
  final bool showFavoritesOnly;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProjectService>();
    final query = searchQuery.trim().toLowerCase();
    final saved = service.outgoingShares
        .where(
          (entry) =>
              (!showFavoritesOnly ||
                  service.isOutgoingShareFavorite(entry.path)) &&
              (query.isEmpty || entry.name.toLowerCase().contains(query)),
        )
        .toList();
    saved.sort((a, b) {
      final n = switch (sortMode) {
        ProjectSortMode.nameAsc => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        ProjectSortMode.nameDesc => b.name.toLowerCase().compareTo(
          a.name.toLowerCase(),
        ),
        ProjectSortMode.updatedAsc => a.updatedAt.compareTo(b.updatedAt),
        ProjectSortMode.updatedDesc => b.updatedAt.compareTo(a.updatedAt),
      };
      return n == 0 ? a.path.compareTo(b.path) : n;
    });
    HomeCollectionSelectionScope.maybeOf(
      context,
    )?.onVisibleIds({for (final entry in saved) 'outgoing_file:${entry.path}'});
    if (saved.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.file_present_outlined,
        title: _shareCollectionEmptyText(context),
      );
    }
    Widget card(BuildContext context, SavedOutgoingShare entry, bool grid) {
      final l10n = AppLocalizations.of(context)!;
      final scheme = Theme.of(context).colorScheme;
      final isFavorite = service.isOutgoingShareFavorite(entry.path);
      final selection = HomeCollectionSelectionScope.maybeOf(context);
      final selectionId = 'outgoing_file:${entry.path}';
      final selecting = selection?.active ?? false;
      final onTap = selecting
          ? () => selection!.onToggle(selectionId)
          : () => shareSavedNiashare(context, entry.path);
      final onLongPress = selection == null
          ? null
          : () => selection.onLongPress(selectionId);
      final subtitle =
          '${entry.updatedAt.year}/${entry.updatedAt.month.toString().padLeft(2, '0')}/'
          '${entry.updatedAt.day.toString().padLeft(2, '0')}  ·  '
          '${(entry.sizeBytes / 1024).toStringAsFixed(1)} KB';
      final favoriteAction = CollectionFavoriteButton(
        itemId: entry.path,
        favorite: isFavorite,
        tooltip: isFavorite
            ? l10n.colorPickerFavoriteRemove
            : l10n.colorPickerFavoriteAdd,
        onPressed: () => runProjectAction(
          context,
          () => service.toggleOutgoingShareFavorite(entry.path),
        ),
      );
      final menuAction = CollectionActionFrame(
        key: Key('collectionMenu_${entry.path}'),
        child: PopupMenuButton<String>(
          key: ValueKey('outgoingShareMenu_${entry.path}'),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.more_vert,
            size: CollectionActionFrame.glyphSize,
          ),
          onSelected: (action) {
            if (action == 'copyToClipboard') {
              onCopyEntry?.call(
                HomeClipboardEntry(
                  source: HomePasteArea.outgoing,
                  id: entry.path,
                  name: entry.name,
                ),
              );
            } else {
              _outgoingShareAction(context, entry, action);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'share',
              child: Text(l10n.projectDetailShareQuickAction),
            ),
            PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
            PopupMenuItem(
              value: 'duplicate',
              child: Text(l10n.themeDuplicateAction),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                l10n.projectDetailTrashMenuItem,
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        ),
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [favoriteAction, const SizedBox(width: 4), menuAction],
      );
      if (grid) {
        return HomeCollectionSelectionSurface(
          selectionId: selectionId,
          child: collectionTileShadow(
            context,
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.transparent, width: 2),
              ),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(
                                Icons.insert_drive_file_outlined,
                                size: 52,
                              ),
                            ),
                          ),
                          if (!selecting)
                            Positioned(top: 4, right: 4, child: menuAction),
                          if (!selecting)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: favoriteAction,
                            ),
                        ],
                      ),
                    ),
                    collectionTileCaption(context, entry.name),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return HomeCollectionSelectionSurface(
        selectionId: selectionId,
        grid: false,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: scheme.surfaceContainerLow,
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined, size: 36),
            title: Text(
              entry.name,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            subtitle: Text(subtitle),
            onTap: onTap,
            onLongPress: onLongPress,
            trailing: selecting ? null : actions,
          ),
        ),
      );
    }

    if (viewMode != ProjectViewMode.detail) {
      return GridView.builder(
        key: ValueKey(('outgoing-niashares', viewMode)),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
        gridDelegate: _worksGridDelegate(context, viewMode),
        itemCount: saved.length,
        itemBuilder: (context, i) => card(context, saved[i], true),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('outgoing-niashares'),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: saved.length,
      itemBuilder: (context, i) => card(context, saved[i], false),
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
class _SharedFolderScreen extends StatefulWidget {
  final String folderId;
  final String folderName;
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final bool showFavoritesOnly;
  final String searchQuery;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  const _SharedFolderScreen({
    required this.folderId,
    required this.folderName,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.showFavoritesOnly,
    required this.searchQuery,
    this.onCopyEntry,
  });
  @override
  State<_SharedFolderScreen> createState() => _SharedFolderScreenState();
}

class _SharedFolderScreenState extends State<_SharedFolderScreen> {
  late ProjectViewMode _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = widget.searchQuery.trim().toLowerCase();
    final items = context
        .watch<ProjectService>()
        .shared
        .where(
          (p) =>
              p.sharedFolderId == widget.folderId &&
              (!widget.showFavoritesOnly || p.isFavorite) &&
              (query.isEmpty || p.name.toLowerCase().contains(query)),
        )
        .toList();
    Widget card(BuildContext ctx, int i, bool grid) =>
        _receivedShareProjectTile(
          ctx,
          items[i],
          grid: grid,
          onCopyEntry: widget.onCopyEntry,
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<ProjectViewMode>(
            key: const Key('sharedFolderViewModeMenu'),
            icon: const Icon(Icons.view_module),
            tooltip: l10n.homeViewModeTooltip,
            onSelected: (mode) {
              setState(() => _viewMode = mode);
              widget.onViewModeChanged(mode);
            },
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
        ],
      ),
      body: items.isEmpty
          ? EmptyStatePlaceholder(
              icon: Icons.folder_open_outlined,
              title: l10n.homeSharedFolderEmpty,
            )
          : _viewMode != ProjectViewMode.detail
          ? GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: _worksGridDelegate(context, _viewMode),
              itemCount: items.length,
              itemBuilder: (ctx, i) => card(ctx, i, true),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) => card(ctx, i, false),
            ),
    );
  }
}

/// フォルダ一覧＋直下アイテム一覧を表示する共通ウィジェット（共有タブ・
/// 作品一覧タブで共用）。フォルダは常にルート直下の1階層のみ（ネスト非対応）。
class _FolderableList<T> extends StatelessWidget {
  final ValueChanged<ProjectFolder>? onCopyFolder;
  final ValueChanged<ProjectFolder>? onToggleFolderFavorite;
  final List<T> allItems;
  final List<ProjectFolder> folders;
  final String? Function(T) folderIdOf;
  final void Function(String folderId, String folderName, List<T> itemsInFolder)
  onEnterFolder;
  final Future<void> Function(String id, String name) onRenameFolder;
  final Future<void> Function(String id) onDeleteFolder;
  final Future<void> Function(
    String id, {
    required String mode,
    String? sourceId,
    String? imagePath,
  })?
  onSetFolderThumbnail;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext, T)? gridItemBuilder;
  final ProjectViewMode? viewMode;
  final Widget? emptyState;
  final bool reserveForFloatingActions;

  /// 一覧の先頭（フォルダより上）に出し、一覧と一緒にスクロールするもの。
  final Widget? header;

  const _FolderableList({
    super.key,
    required this.allItems,
    required this.folders,
    required this.folderIdOf,
    required this.onEnterFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    this.onSetFolderThumbnail,
    required this.itemBuilder,
    this.gridItemBuilder,
    this.viewMode,
    this.emptyState,
    this.reserveForFloatingActions = false,
    this.onCopyFolder,
    this.onToggleFolderFavorite,
    this.header,
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
    final lead = header == null ? 0 : 1;
    // 作品の行は表示されるぶんだけ作る。ListView(children:)だと、実際に
    // 描画されるのは画面内の行だけでも、全作品ぶんのカード（サムネイルの
    // Image.fileを含む）のウィジェットが毎buildで作られて捨てられる。
    return LayoutBuilder(
      builder: (context, constraints) {
        // A collection is empty only when it has neither root files
        // nor folders. A folder containing no files is still an entry.
        if (rootItems.isEmpty && !hasHeader && emptyState != null) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (header != null) SliverToBoxAdapter(child: header!),
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
        if (gridItemBuilder != null &&
            viewMode != null &&
            viewMode != ProjectViewMode.detail) {
          return CustomScrollView(
            slivers: [
              if (header != null) SliverToBoxAdapter(child: header!),
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid.builder(
                  gridDelegate: _worksGridDelegate(context, viewMode!),
                  itemCount: folders.length + rootItems.length,
                  itemBuilder: (context, index) => index < folders.length
                      ? _folderGridTile(
                          context,
                          folders[index],
                          countByFolder[folders[index].id] ?? 0,
                        )
                      : gridItemBuilder!(
                          context,
                          rootItems[index - folders.length],
                        ),
                ),
              ),
              if (reserveForFloatingActions)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 88 + MediaQuery.paddingOf(context).bottom,
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
          itemCount: lead + rootItems.length + (hasHeader ? 2 : 0),
          itemBuilder: (context, position) {
            if (position < lead) return header!;
            final index = position - lead;
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

  List<FolderThumbnailChoice> _folderCoverChoices(String folderId) {
    final result = <FolderThumbnailChoice>[];
    for (final entry in allItems) {
      if (folderIdOf(entry) != folderId) continue;
      if (entry is Project) {
        final path = entry.thumbnailPath;
        if (path != null && path.isNotEmpty) {
          result.add(
            FolderThumbnailChoice(
              id: entry.id,
              name: entry.name,
              imagePath: path,
              updatedAt: entry.updatedAt,
            ),
          );
        }
      } else if (entry is File) {
        final file = entry;
        final extension = file.path.split('.').last.toLowerCase();
        // Still images display directly. Exported videos get a cached
        // first-frame poster through FolderCoverMedia on Android.
        if (!const {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
          'mp4',
          'mov',
          'webm',
          'mkv',
          'avi',
        }.contains(extension))
          continue;
        try {
          result.add(
            FolderThumbnailChoice(
              id: file.path,
              name: file.uri.pathSegments.last,
              imagePath: file.path,
              updatedAt: file.lastModifiedSync(),
            ),
          );
        } on FileSystemException {
          // A file removed outside the app must not crash the folder list.
        }
      }
    }
    return result;
  }

  Widget _folderActions(
    BuildContext context,
    ProjectFolder folder, {
    bool showFavorite = true,
    bool showMenu = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFavorite && onToggleFolderFavorite != null) ...[
          CollectionFavoriteButton(
            itemId: folder.id,
            favorite: folder.isFavorite,
            tooltip: folder.isFavorite
                ? l10n.colorPickerFavoriteRemove
                : l10n.colorPickerFavoriteAdd,
            onPressed: () => onToggleFolderFavorite!(folder),
          ),
          if (showMenu) const SizedBox(width: 4),
        ],
        if (showMenu)
          CollectionActionFrame(
            child: IconButton(
              key: ValueKey('collectionFolderMenu_${folder.id}'),
              icon: const Icon(
                Icons.more_vert,
                size: CollectionActionFrame.glyphSize,
              ),
              tooltip: Localizations.localeOf(context).languageCode == 'ja'
                  ? 'フォルダのメニュー'
                  : 'Folder menu',
              padding: EdgeInsets.zero,
              onPressed: () => _showFolderMenu(context, folder),
            ),
          ),
      ],
    );
  }

  Widget _folderGridTile(
    BuildContext context,
    ProjectFolder folder,
    int count,
  ) {
    final selection = HomeCollectionSelectionScope.maybeOf(context);
    final selectionId = T == File
        ? 'work_folder:${folder.id}'
        : 'shared_folder:${folder.id}';
    final selecting = selection?.active ?? false;
    return HomeCollectionSelectionSurface(
      selectionId: selectionId,
      child: collectionTileShadow(
        context,
        Card(
          key: ValueKey('collectionFolder_${folder.id}'),
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.transparent, width: 2),
          ),
          child: InkWell(
            onTap: selecting
                ? () => selection!.onToggle(selectionId)
                : () => onEnterFolder(
                    folder.id,
                    folder.name,
                    allItems.where((e) => folderIdOf(e) == folder.id).toList(),
                  ),
            onLongPress: selection == null
                ? () => _showFolderMenu(context, folder)
                : () => selection.onLongPress(selectionId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FolderThumbnail(
                        folder: folder,
                        choices: _folderCoverChoices(folder.id),
                      ),
                      if (!selecting)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _folderActions(
                            context,
                            folder,
                            showFavorite: false,
                          ),
                        ),
                      if (!selecting && onToggleFolderFavorite != null)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: _folderActions(
                            context,
                            folder,
                            showMenu: false,
                          ),
                        ),
                    ],
                  ),
                ),
                collectionTileCaption(context, folder.name),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Folder entries use the same full-width, roughly 80dp ListTile as files,
  /// rather than small 48dp chips. Their cover is drawn inside the folder.
  Widget _folderChips(BuildContext context, Map<String, int> countByFolder) {
    return Column(
      children: [
        for (final folder in folders)
          HomeCollectionSelectionSurface(
            selectionId: T == File
                ? 'work_folder:${folder.id}'
                : 'shared_folder:${folder.id}',
            grid: false,
            child: Card(
              key: ValueKey('collectionFolder_${folder.id}'),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                minVerticalPadding: 8,
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: FolderThumbnail(
                    folder: folder,
                    choices: _folderCoverChoices(folder.id),
                  ),
                ),
                title: Text(folder.name),
                subtitle: Text('${countByFolder[folder.id] ?? 0}'),
                trailing:
                    HomeCollectionSelectionScope.maybeOf(context)?.active ==
                        true
                    ? null
                    : _folderActions(context, folder),
                onTap: () {
                  final selection = HomeCollectionSelectionScope.maybeOf(
                    context,
                  );
                  final id = T == File
                      ? 'work_folder:${folder.id}'
                      : 'shared_folder:${folder.id}';
                  if (selection?.active == true) {
                    selection!.onToggle(id);
                  } else {
                    onEnterFolder(
                      folder.id,
                      folder.name,
                      allItems
                          .where((e) => folderIdOf(e) == folder.id)
                          .toList(),
                    );
                  }
                },
                onLongPress: () {
                  final selection = HomeCollectionSelectionScope.maybeOf(
                    context,
                  );
                  final id = T == File
                      ? 'work_folder:${folder.id}'
                      : 'shared_folder:${folder.id}';
                  if (selection == null)
                    _showFolderMenu(context, folder);
                  else
                    selection.onLongPress(id);
                },
              ),
            ),
          ),
      ],
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
            if (onSetFolderThumbnail != null)
              ListTile(
                key: const Key('collectionFolderThumbnailMenuItem'),
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ja'
                      ? 'サムネイル変更'
                      : 'Change thumbnail',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showFolderThumbnailDialog(
                    context,
                    folder: folder,
                    choices: _folderCoverChoices(folder.id),
                    onSave: ({required mode, sourceId, imagePath}) =>
                        onSetFolderThumbnail!(
                          folder.id,
                          mode: mode,
                          sourceId: sourceId,
                          imagePath: imagePath,
                        ),
                  );
                },
              ),
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
                l10n.homeMoveToTrash,
                style: TextStyle(color: ThemeService.activeColorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => FolderDeleteDialog(
                    folderName: folder.name,
                    title: l10n.homeMoveToTrash,
                    body: l10n.homeMoveToTrashConfirm(1),
                    confirmLabel: l10n.homeMoveToTrash,
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
  const _TrashTab({
    super.key,
    required this.sortMode,
    required this.selectedKinds,
    this.searchQuery = '',
    this.onCopyEntry,
    this.screenFocus,
  });

  final ProjectSortMode sortMode;
  final Set<TrashEntryKind> selectedKinds;
  final String searchQuery;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final FocusNode? screenFocus;

  @override
  State<_TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<_TrashTab> {
  final _pending = <String>{};
  final _restoring = <String>{};
  late Future<List<LocalTrashedFile>> _localFiles;

  @override
  void initState() {
    super.initState();
    _localFiles = LocalFileTrashService.list();
    LocalFileTrashService.changes.addListener(_reloadLocal);
  }

  @override
  void dispose() {
    LocalFileTrashService.changes.removeListener(_reloadLocal);
    super.dispose();
  }

  void _reloadLocal() {
    if (!mounted) return;
    // setState must return void: assignment of a Future in an expression body
    // returns that Future and throws during every file-Trash notification.
    setState(() {
      _localFiles = LocalFileTrashService.list();
    });
  }

  String _deletedLabel(DateTime? deleted, AppLocalizations l10n) {
    if (deleted == null) return '';
    return l10n.homeTrashDeletedOn(
      '${deleted.year}/${deleted.month.toString().padLeft(2, '0')}/'
      '${deleted.day.toString().padLeft(2, '0')}',
    );
  }

  Future<bool> _confirmRestoreFromTrash(String name) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    final japanese = Localizations.localeOf(context).languageCode == 'ja';
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('homeTrashRestoreConfirmation'),
            title: Text(japanese ? 'ゴミ箱から復元' : 'Restore from Trash'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  japanese
                      ? '以下の作品・フォルダをゴミ箱から復元しますか？'
                      : 'Restore the following files or folders from Trash?',
                ),
                const SizedBox(height: 8),
                Text('・$name'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                key: const Key('homeTrashRestoreConfirmButton'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.commonRestore),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _restoreProject(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    final project = service.trash.where((p) => p.id == id).firstOrNull;
    if (project == null ||
        !await _confirmRestoreFromTrash(project.name) ||
        !mounted)
      return;
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

  Future<void> _restoreLocal(LocalTrashedFile entry) async {
    if (_pending.contains(entry.id) ||
        !await _confirmRestoreFromTrash(entry.fileName) ||
        !mounted)
      return;
    setState(() => _pending.add(entry.id));
    try {
      if (entry.isFolder) {
        await LocalFileTrashService.restoreWorkFolder(
          entry,
          context.read<WorkFolderService>(),
        );
      } else {
        await LocalFileTrashService.restore(entry);
      }
      // The exported-work list maintains a cached storage listing.
      StorageInfoService().invalidate();
      if (entry.kind == LocalTrashKind.outgoingShare && mounted) {
        await context.read<ProjectService>().refreshOutgoingShares();
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.homeTrashOperationFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(entry.id));
    }
  }

  Future<void> _restoreFolder(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    final folder = service.trashedFolders
        .where((record) => record.folder.id == id)
        .firstOrNull;
    if (folder == null ||
        !await _confirmRestoreFromTrash(folder.folder.name) ||
        !mounted)
      return;
    setState(() => _pending.add(id));
    try {
      await runProjectTrashAction(
        context,
        () => service.restoreTrashedFolder(id),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Future<void> _permanentDeleteFolder(String id) async {
    if (_pending.contains(id)) return;
    final service = context.read<ProjectService>();
    final record = service.trashedFolders
        .where((item) => item.folder.id == id)
        .firstOrNull;
    if (record == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending.add(id));
    try {
      await showDialog<bool>(
        context: context,
        builder: (_) => ProjectTrashDialog(
          title: l10n.homePermanentDeleteConfirmTitle,
          message: l10n.homePermanentDeleteConfirmBody,
          confirmLabel: l10n.commonDelete,
          itemNames: [record.folder.name],
          onApply: () => service.permanentDeleteTrashedFolder(id),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Widget _folderRow(TrashedFolder record, AppLocalizations l10n) {
    final id = record.folder.id;
    final projectNames = [
      for (final projectId in record.projectIds)
        ...context
            .read<ProjectService>()
            .trash
            .where((project) => project.id == projectId)
            .map((project) => project.name),
    ];
    final subtitle = projectNames.isNotEmpty
        ? projectNames.join('、')
        : l10n.homeFolderContents(0, record.subfolders.length);
    return _trashCard(
      selectionId: 'trash_folder:$id',
      detailsKey: ValueKey('trashedFolder_$id'),
      leading: const Icon(Icons.folder_delete_outlined, size: 36),
      title: record.folder.name,
      subtitle: subtitle,
      actions: [
        if (widget.onCopyEntry != null)
          TextButton(
            key: ValueKey('trashCopyFolder_$id'),
            onPressed: () => widget.onCopyEntry!(
              HomeClipboardEntry(
                source: HomePasteArea.trash,
                id: id,
                name: record.folder.name,
                isFolder: true,
                originalArea: record.isShared
                    ? HomePasteArea.received
                    : HomePasteArea.projects,
              ),
            ),
            child: const Text('コピー'),
          ),
        TextButton(
          key: ValueKey('trashedFolderRestore_$id'),
          onPressed: _pending.contains(id) ? null : () => _restoreFolder(id),
          child: Text(l10n.commonRestore),
        ),
        TextButton(
          key: ValueKey('trashedFolderDelete_$id'),
          onPressed: _pending.contains(id)
              ? null
              : () => _permanentDeleteFolder(id),
          child: Text(
            l10n.homePermanentDelete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLocal(LocalTrashedFile entry) async {
    if (_pending.contains(entry.id)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l10n.homePermanentDeleteConfirmTitle),
        content: Text(l10n.homePermanentDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _pending.add(entry.id));
    try {
      await LocalFileTrashService.deleteForever(entry);
      StorageInfoService().invalidate();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.homeTrashOperationFailed)));
      }
    } finally {
      if (mounted) setState(() => _pending.remove(entry.id));
    }
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

  Widget _projectRow(
    Project project,
    TrashEntryKind kind,
    AppLocalizations l10n,
  ) {
    final deleted = context.read<ProjectService>().deletedAtOf(project.id);
    final meta = l10n.homeProjectMeta(project.fps, project.durationSeconds);
    final deletedLabel = _deletedLabel(deleted, l10n);
    final subtitle = [
      _trashKindLabel(context, kind),
      if (deletedLabel.isNotEmpty) deletedLabel,
      meta,
    ].join(' · ');
    final actions = <Widget>[
      if (widget.onCopyEntry != null)
        TextButton(
          key: ValueKey('trashCopyProject_${project.id}'),
          onPressed: () => widget.onCopyEntry!(
            HomeClipboardEntry(
              source: HomePasteArea.trash,
              id: project.id,
              name: project.name,
              originalArea: project.isSharedImport
                  ? HomePasteArea.received
                  : HomePasteArea.projects,
            ),
          ),
          child: const Text('コピー'),
        ),
      TextButton(
        key: ValueKey('trash-restore-${project.id}'),
        onPressed: _pending.contains(project.id)
            ? null
            : () => _restoreProject(project.id),
        child: Text(
          _restoring.contains(project.id)
              ? l10n.homeTrashWorking
              : l10n.commonRestore,
        ),
      ),
      TextButton(
        key: ValueKey('trash-delete-${project.id}'),
        onPressed: _pending.contains(project.id)
            ? null
            : () => _confirmPermanentDelete(project),
        child: Text(
          l10n.homePermanentDelete,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ];
    return _trashCard(
      selectionId: 'trash_project:${project.id}',
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Color(project.backgroundColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      title: project.name,
      subtitle: subtitle,
      actions: actions,
    );
  }

  Widget _fileRow(
    LocalTrashedFile entry,
    TrashEntryKind kind,
    AppLocalizations l10n,
  ) {
    final actions = <Widget>[
      if (widget.onCopyEntry != null)
        TextButton(
          key: ValueKey('trashCopyLocal_${entry.id}'),
          onPressed: () => widget.onCopyEntry!(
            HomeClipboardEntry(
              source: HomePasteArea.trash,
              id: entry.id,
              name: entry.fileName,
              isFolder: entry.isFolder,
              originalArea: entry.kind == LocalTrashKind.outgoingShare
                  ? HomePasteArea.outgoing
                  : HomePasteArea.works,
            ),
          ),
          child: const Text('コピー'),
        ),
      TextButton(
        key: ValueKey('trash-restore-local-${entry.id}'),
        onPressed: _pending.contains(entry.id)
            ? null
            : () => _restoreLocal(entry),
        child: Text(l10n.commonRestore),
      ),
      TextButton(
        key: ValueKey('trash-delete-local-${entry.id}'),
        onPressed: _pending.contains(entry.id)
            ? null
            : () => _deleteLocal(entry),
        child: Text(
          l10n.homePermanentDelete,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ];
    return _trashCard(
      selectionId: 'trash_local:${entry.id}',
      leading: Icon(
        entry.isFolder
            ? Icons.folder_delete_outlined
            : kind == TrashEntryKind.createdShare
            ? Icons.file_present_outlined
            : Icons.video_library_outlined,
        size: 36,
      ),
      title: entry.fileName,
      subtitle: [
        _trashKindLabel(context, kind),
        _deletedLabel(entry.deletedAt, l10n),
      ].join(' · '),
      actions: actions,
    );
  }

  Widget _trashCard({
    required String selectionId,
    required Widget leading,
    required String title,
    required String subtitle,
    required List<Widget> actions,
    Key? detailsKey,
  }) {
    final selection = HomeCollectionSelectionScope.maybeOf(context);
    final selecting = selection?.active ?? false;
    final details = ListTile(
      key: detailsKey,
      onTap: selecting ? () => selection!.onToggle(selectionId) : null,
      onLongPress: selection == null
          ? null
          : () => selection.onLongPress(selectionId),
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      subtitle: Text(subtitle),
    );
    return HomeCollectionSelectionSurface(
      selectionId: selectionId,
      grid: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth <
              600 * MediaQuery.textScalerOf(context).scale(1);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      details,
                      if (!selecting)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: 8,
                            overflowSpacing: 4,
                            children: actions,
                          ),
                        ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      details,
                      if (!selecting)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 4),
                            child: Wrap(spacing: 8, children: actions),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<ProjectService>();
    return FutureBuilder<List<LocalTrashedFile>>(
      future: _localFiles,
      builder: (context, snapshot) {
        final rows =
            <
              ({
                TrashEntryKind kind,
                Project? project,
                TrashedFolder? folder,
                LocalTrashedFile? local,
                DateTime deletedAt,
                String name,
              })
            >[];
        for (final project in service.trash) {
          // Folder contents are represented by their parent folder row.
          if (service.trashedFolderOf(project.id) != null) continue;
          final kind = project.isSharedImport
              ? TrashEntryKind.receivedShare
              : TrashEntryKind.createdProject;
          if (!widget.selectedKinds.contains(kind)) continue;
          rows.add((
            kind: kind,
            project: project,
            folder: null,
            local: null,
            deletedAt:
                service.deletedAtOf(project.id) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            name: project.name,
          ));
        }
        for (final folder in service.trashedFolders) {
          final kind = folder.isShared
              ? TrashEntryKind.receivedShare
              : TrashEntryKind.createdProject;
          if (!widget.selectedKinds.contains(kind)) continue;
          rows.add((
            kind: kind,
            project: null,
            folder: folder,
            local: null,
            deletedAt: folder.deletedAt,
            name: folder.folder.name,
          ));
        }
        for (final local in snapshot.data ?? <LocalTrashedFile>[]) {
          final kind = local.kind == LocalTrashKind.outgoingShare
              ? TrashEntryKind.createdShare
              : TrashEntryKind.exportedWork;
          if (!widget.selectedKinds.contains(kind)) continue;
          rows.add((
            kind: kind,
            project: null,
            folder: null,
            local: local,
            deletedAt: local.deletedAt,
            name: local.fileName,
          ));
        }
        final query = widget.searchQuery.trim().toLowerCase();
        if (query.isNotEmpty) {
          rows.removeWhere(
            (row) =>
                !row.name.toLowerCase().contains(query) &&
                !_trashKindLabel(
                  context,
                  row.kind,
                ).toLowerCase().contains(query),
          );
        }
        rows.sort(
          (a, b) => switch (widget.sortMode) {
            ProjectSortMode.nameAsc => a.name.compareTo(b.name),
            ProjectSortMode.nameDesc => b.name.compareTo(a.name),
            ProjectSortMode.updatedAsc => a.deletedAt.compareTo(b.deletedAt),
            ProjectSortMode.updatedDesc => b.deletedAt.compareTo(a.deletedAt),
          },
        );
        HomeCollectionSelectionScope.maybeOf(context)?.onVisibleIds({
          for (final row in rows)
            if (row.project != null)
              'trash_project:${row.project!.id}'
            else if (row.folder != null)
              'trash_folder:${row.folder!.folder.id}'
            else
              'trash_local:${row.local!.id}',
        });
        // ゴミ箱の作品は保存先から読む。読めなかったときは知らせを先頭に
        // 出し、「ゴミ箱は空です」とは言わない（作品が消えたように見える）。
        final loadFailed = service.projectsLoadFailed;
        final lead = loadFailed ? 1 : 0;
        if (snapshot.connectionState != ConnectionState.done &&
            rows.isEmpty &&
            !loadFailed) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rows.isEmpty && !loadFailed) {
          return EmptyStatePlaceholder(
            icon: Icons.delete_outline,
            title: l10n.homeTrashEmpty,
          );
        }
        return ListView.builder(
          itemCount: lead + rows.length,
          padding: const EdgeInsets.only(bottom: 100),
          itemBuilder: (context, position) {
            if (position < lead) {
              return ProjectsLoadFailureNotice(
                key: const Key('trashProjectsLoadFailed'),
                onRetry: service.retryLoadProjects,
                screenFocus: widget.screenFocus,
              );
            }
            final row = rows[position - lead];
            if (row.project != null) {
              return _projectRow(row.project!, row.kind, l10n);
            }
            if (row.folder != null) {
              return _folderRow(row.folder!, l10n);
            }
            return _fileRow(row.local!, row.kind, l10n);
          },
        );
      },
    );
  }
}

/// Reuse the Projects collection's four sort modes for exported media.
/// The source files are never renamed or modified by a view preference.
List<File> _sortExportedFiles(List<File> files, ProjectSortMode mode) {
  final sorted = List<File>.of(files);
  int compare(File a, File b) {
    final nameA = a.uri.pathSegments.last.toLowerCase();
    final nameB = b.uri.pathSegments.last.toLowerCase();
    switch (mode) {
      case ProjectSortMode.nameAsc:
        return nameA.compareTo(nameB);
      case ProjectSortMode.nameDesc:
        return nameB.compareTo(nameA);
      case ProjectSortMode.updatedAsc:
        return a.lastModifiedSync().compareTo(b.lastModifiedSync());
      case ProjectSortMode.updatedDesc:
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    }
  }

  sorted.sort((a, b) {
    final order = compare(a, b);
    return order == 0 ? a.path.compareTo(b.path) : order;
  });
  return sorted;
}

/// Sort the exported-work folders within their folder section as well.
/// WorkFolderService has creation dates (no separate update timestamp).
List<ProjectFolder> _sortWorkFolders(
  List<ProjectFolder> folders,
  ProjectSortMode mode,
) {
  final sorted = List<ProjectFolder>.of(folders);
  sorted.sort((a, b) {
    final order = switch (mode) {
      ProjectSortMode.nameAsc => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      ProjectSortMode.nameDesc => b.name.toLowerCase().compareTo(
        a.name.toLowerCase(),
      ),
      ProjectSortMode.updatedAsc => a.createdAt.compareTo(b.createdAt),
      ProjectSortMode.updatedDesc => b.createdAt.compareTo(a.createdAt),
    };
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return sorted;
}

/// Reuse the exact Projects 16:12 grid and minimum caption allowance.
SliverGridDelegate _worksGridDelegate(
  BuildContext context,
  ProjectViewMode mode,
) {
  final extent = switch (mode) {
    ProjectViewMode.small => 130.0,
    ProjectViewMode.medium => 170.0,
    ProjectViewMode.large => 240.0,
    ProjectViewMode.detail => 240.0,
  };
  return collectionTileGridDelegate(context, extent);
}

class _WorksTab extends StatefulWidget {
  const _WorksTab({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    this.searchQuery = '',
    this.onCopyEntry,
  });
  final ProjectViewMode viewMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final String searchQuery;
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;

  @override
  State<_WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<_WorksTab> {
  static const _favoritePathsKey = 'home.works.favoritePaths.v1';
  final Set<String> _favoritePaths = {};
  bool _showFavoritesOnly = false;
  late Future<List<File>> _future;
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;

  Future<void> _loadFavoritePaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_favoritePathsKey) ?? const <String>[];
      if (mounted)
        setState(() {
          _favoritePaths
            ..clear()
            ..addAll(stored);
        });
    } catch (error) {
      debugPrint('Works favorites could not be loaded: $error');
    }
  }

  Future<void> _toggleFavorite(String path) async {
    setState(() {
      if (!_favoritePaths.add(path)) _favoritePaths.remove(path);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _favoritePathsKey,
        _favoritePaths.toList()..sort(),
      );
    } catch (error) {
      debugPrint('Works favorites could not be saved: $error');
    }
  }

  bool get _sortByName =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.nameDesc;
  bool get _sortAscending =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.updatedAsc;

  void _setSortByName(bool byName) => setState(() {
    _sortMode = byName
        ? (_sortAscending ? ProjectSortMode.nameAsc : ProjectSortMode.nameDesc)
        : (_sortAscending
              ? ProjectSortMode.updatedAsc
              : ProjectSortMode.updatedDesc);
  });
  void _toggleSortDirection() => setState(() {
    _sortMode = switch (_sortMode) {
      ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
      ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
      ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
      ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
    };
  });

  @override
  void initState() {
    super.initState();
    _future = ExportEngine.listExportedFiles();
    _loadFavoritePaths();
    LocalFileTrashService.changes.addListener(_onLocalFilesChanged);
  }

  @override
  void dispose() {
    LocalFileTrashService.changes.removeListener(_onLocalFilesChanged);
    super.dispose();
  }

  void _onLocalFilesChanged() {
    if (mounted) _reload();
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
        final query = widget.searchQuery.trim().toLowerCase();
        final files = _sortExportedFiles(
          snapshot.data!
              .where(
                (file) =>
                    (!_showFavoritesOnly ||
                        _favoritePaths.contains(file.path)) &&
                    (query.isEmpty ||
                        file.uri.pathSegments.last.toLowerCase().contains(
                          query,
                        )),
              )
              .toList(),
          _sortMode,
        );
        final workFolders = context.watch<WorkFolderService>();
        final folders = _sortWorkFolders(
          workFolders.folders
              .where(
                (folder) =>
                    (!_showFavoritesOnly ||
                        folder.isFavorite ||
                        files.any(
                          (f) =>
                              workFolders.folderIdOf(f.uri.pathSegments.last) ==
                              folder.id,
                        )) &&
                    (query.isEmpty ||
                        folder.name.toLowerCase().contains(query) ||
                        files.any(
                          (f) =>
                              workFolders.folderIdOf(f.uri.pathSegments.last) ==
                              folder.id,
                        )),
              )
              .toList(),
          _sortMode,
        );
        HomeCollectionSelectionScope.maybeOf(context)?.onVisibleIds({
          for (final folder in folders) 'work_folder:${folder.id}',
          for (final file in files)
            if (workFolders.folderIdOf(file.uri.pathSegments.last) == null)
              'work_file:${file.path}',
        });
        Widget buildWork(BuildContext context, File file, bool grid) =>
            _WorkListItem(
              key: ValueKey(file.path),
              file: file,
              gridTile: grid,
              isFavorite: _favoritePaths.contains(file.path),
              onToggleFavorite: () => _toggleFavorite(file.path),
              onDeleted: _reload,
              onCopy: widget.onCopyEntry == null
                  ? null
                  : () => widget.onCopyEntry!(
                      HomeClipboardEntry(
                        source: HomePasteArea.works,
                        id: file.path,
                        name: file.uri.pathSegments.last,
                      ),
                    ),
            );
        return RefreshIndicator(
          onRefresh: _reload,
          child: _FolderableList<File>(
            key: ValueKey(('works-list', widget.viewMode)),
            header: _HomeCollectionSortHeader(
              leading: FilterChip(
                key: const Key('worksFavoritesOnlyFilter'),
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
                onSelected: (value) =>
                    setState(() => _showFavoritesOnly = value),
              ),
              sortByName: _sortByName,
              sortAscending: _sortAscending,
              onSortByNameChanged: _setSortByName,
              onToggleDirection: _toggleSortDirection,
            ),
            viewMode: widget.viewMode,
            gridItemBuilder: (context, file) => buildWork(context, file, true),
            emptyState: files.isEmpty && folders.isEmpty
                ? EmptyStatePlaceholder(
                    icon: Icons.video_library_outlined,
                    title: l10n.homeWorksEmpty,
                    hint: l10n.homeWorksEmptyHint,
                    scrollable: false,
                  )
                : null,
            allItems: files,
            folders: folders,
            folderIdOf: (f) =>
                workFolders.folderIdOf(f.path.split(RegExp(r'[\\/]')).last),
            onEnterFolder: (folderId, folderName, itemsInFolder) =>
                Navigator.of(context).push(
                  adMockMaterialPageRoute(
                    builder: (_) => _WorksFolderScreen(
                      folderId: folderId,
                      folderName: folderName,
                      viewMode: widget.viewMode,
                      initialSortMode: _sortMode,
                      searchQuery: folderName.toLowerCase().contains(query)
                          ? ''
                          : widget.searchQuery,
                      favoritesOnly:
                          _showFavoritesOnly &&
                          !workFolders.folders.any(
                            (folder) =>
                                folder.id == folderId && folder.isFavorite,
                          ),
                      favoritePaths: _favoritePaths,
                      onToggleFavorite: _toggleFavorite,
                      onViewModeChanged: widget.onViewModeChanged,
                      onDeleted: _reload,
                      onCopyEntry: widget.onCopyEntry,
                    ),
                  ),
                ),
            onToggleFolderFavorite: (folder) =>
                workFolders.toggleFolderFavorite(folder.id),
            onRenameFolder: (id, name) => workFolders.renameFolder(id, name),
            onDeleteFolder: (id) async {
              final folder = workFolders.folders
                  .where((f) => f.id == id)
                  .firstOrNull;
              if (folder == null) return;
              final exports = await ExportEngine.listExportedFiles(
                forceRefresh: true,
              );
              final members = exports
                  .where(
                    (file) =>
                        workFolders.folderIdOf(file.uri.pathSegments.last) ==
                        id,
                  )
                  .toList();
              await LocalFileTrashService.moveWorkFolder(
                folderName: folder.name,
                files: members,
              );
              await workFolders.deleteFolder(id);
              StorageInfoService().invalidate();
            },
            onSetFolderThumbnail: (id, {required mode, sourceId, imagePath}) =>
                workFolders.setFolderThumbnail(
                  id,
                  mode: mode,
                  sourceId: sourceId,
                  imagePath: imagePath,
                ),
            onCopyFolder: widget.onCopyEntry == null
                ? null
                : (folder) => widget.onCopyEntry!(
                    HomeClipboardEntry(
                      source: HomePasteArea.works,
                      id: folder.id,
                      name: folder.name,
                      isFolder: true,
                    ),
                  ),
            reserveForFloatingActions: true,
            itemBuilder: (context, file) => buildWork(context, file, false),
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
  final ValueChanged<HomeClipboardEntry>? onCopyEntry;
  final ProjectViewMode viewMode;
  final ProjectSortMode initialSortMode;
  final ValueChanged<ProjectViewMode> onViewModeChanged;
  final String searchQuery;
  final bool favoritesOnly;
  final Set<String> favoritePaths;
  final ValueChanged<String> onToggleFavorite;
  const _WorksFolderScreen({
    required this.folderId,
    required this.folderName,
    required this.viewMode,
    required this.initialSortMode,
    required this.searchQuery,
    required this.favoritesOnly,
    required this.favoritePaths,
    required this.onToggleFavorite,
    required this.onViewModeChanged,
    required this.onDeleted,
    this.onCopyEntry,
  });

  @override
  State<_WorksFolderScreen> createState() => _WorksFolderScreenState();
}

class _WorksFolderScreenState extends State<_WorksFolderScreen> {
  late Future<List<File>> _future;
  late ProjectViewMode _viewMode;
  late ProjectSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
    _sortMode = widget.initialSortMode;
    _future = ExportEngine.listExportedFiles();
  }

  bool get _sortByName =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.nameDesc;
  bool get _sortAscending =>
      _sortMode == ProjectSortMode.nameAsc ||
      _sortMode == ProjectSortMode.updatedAsc;
  void _setSortByName(bool byName) => setState(() {
    _sortMode = byName
        ? (_sortAscending ? ProjectSortMode.nameAsc : ProjectSortMode.nameDesc)
        : (_sortAscending
              ? ProjectSortMode.updatedAsc
              : ProjectSortMode.updatedDesc);
  });
  void _toggleSortDirection() => setState(() {
    _sortMode = switch (_sortMode) {
      ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
      ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
      ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
      ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
    };
  });

  void _selectViewMode(ProjectViewMode mode) {
    setState(() => _viewMode = mode);
    widget.onViewModeChanged(mode);
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
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workFolders = context.watch<WorkFolderService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<ProjectViewMode>(
            key: const Key('worksFolderViewModeMenu'),
            icon: const Icon(Icons.view_module),
            tooltip: l10n.homeViewModeTooltip,
            onSelected: _selectViewMode,
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
        ],
      ),
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
          Expanded(
            child: FutureBuilder<List<File>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _WorksLoadFailure(onRetry: _reload);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _sortExportedFiles(
                  snapshot.data!
                      .where(
                        (f) =>
                            workFolders.folderIdOf(
                                  f.path.split(RegExp(r'[\\/]')).last,
                                ) ==
                                widget.folderId &&
                            (!widget.favoritesOnly ||
                                widget.favoritePaths.contains(f.path)) &&
                            (widget.searchQuery.trim().isEmpty ||
                                f.uri.pathSegments.last.toLowerCase().contains(
                                  widget.searchQuery.trim().toLowerCase(),
                                )),
                      )
                      .toList(),
                  _sortMode,
                );
                if (items.isEmpty) {
                  return EmptyStatePlaceholder(
                    icon: Icons.folder_open_outlined,
                    title: l10n.homeWorkFolderEmpty,
                  );
                }
                Widget item(BuildContext context, int index, bool grid) {
                  final file = items[index];
                  return _WorkListItem(
                    key: ValueKey(file.path),
                    file: file,
                    gridTile: grid,
                    isFavorite: widget.favoritePaths.contains(file.path),
                    onToggleFavorite: () => widget.onToggleFavorite(file.path),
                    onCopy: widget.onCopyEntry == null
                        ? null
                        : () => widget.onCopyEntry!(
                            HomeClipboardEntry(
                              source: HomePasteArea.works,
                              id: file.path,
                              name: file.uri.pathSegments.last,
                            ),
                          ),
                    onDeleted: _reload,
                  );
                }

                if (_viewMode != ProjectViewMode.detail) {
                  return GridView.builder(
                    key: ValueKey(('works-folder-grid', _viewMode)),
                    padding: const EdgeInsets.all(8),
                    gridDelegate: _worksGridDelegate(context, _viewMode),
                    itemCount: items.length,
                    itemBuilder: (context, index) => item(context, index, true),
                  );
                }
                return ListView.builder(
                  key: const ValueKey('works-folder-detail'),
                  itemCount: items.length,
                  itemBuilder: (context, index) => item(context, index, false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkListItem extends StatefulWidget {
  final File file;
  final VoidCallback onDeleted;
  final VoidCallback? onCopy;
  final bool gridTile;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  const _WorkListItem({
    super.key,
    required this.file,
    required this.onDeleted,
    this.onCopy,
    this.gridTile = false,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<_WorkListItem> createState() => _WorkListItemState();
}

class _WorkListItemState extends State<_WorkListItem> {
  File get file => widget.file;
  bool _sharing = false;
  Object? _shareError;
  Future<Map<String, dynamic>>? _coverSetting;

  @override
  void initState() {
    super.initState();
    _coverSetting = ExportedWorkCoverStore.ensureCached(widget.file);
  }

  @override
  void didUpdateWidget(covariant _WorkListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _coverSetting = ExportedWorkCoverStore.ensureCached(widget.file);
    }
  }

  void _refreshCover() {
    if (mounted)
      setState(() {
        _coverSetting = ExportedWorkCoverStore.ensureCached(widget.file);
      });
  }

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

  bool isOriginalImageFile(File f) => const {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
  }.contains(f.path.split('.').last.toLowerCase());

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
    return FutureBuilder<Map<String, dynamic>>(
      future: _coverSetting,
      builder: (context, cover) {
        final setting = cover.data ?? const <String, dynamic>{};
        final path = setting['imagePath'];
        return ExportedWorkCard(
          gridTile: widget.gridTile,
          selectionId: 'work_file:${file.path}',
          isFavorite: widget.isFavorite,
          onToggleFavorite: widget.onToggleFavorite,
          thumbnailPath: path is String && path.isNotEmpty ? path : null,
          // Avoid decoding the original video twice while its compact cover
          // is generated in the queued cache service.
          originalMediaPath:
              const {
                'mp4',
                'm4v',
                'mov',
                'webm',
                'mkv',
                'avi',
                '3gp',
              }.contains(file.path.split('.').last.toLowerCase())
              ? null
              : file.path,
          thumbnailHidden: setting['mode'] == 'none',
          onChangeThumbnail: () => showExportedWorkThumbnailDialog(
            context,
            file: file,
            onApplied: _refreshCover,
          ),
          name: file.path.split(RegExp(r'[\\/]')).last,
          metadata: '${_formatDate(stat.modified)} ・ ${_formatSize(stat.size)}',
          icon: _icon,
          moveLabel: l10n.folderMoveToTitle,
          shareLabel: l10n.homeShareOpenWith,
          deleteLabel: l10n.homeMoveToTrash,
          onOpen: _sharing ? null : () => _openPreview(context),
          onMove: () => _showMoveToFolderSheet(context),
          onCopy: widget.onCopy,
          onShare: _sharing ? null : _share,
          onDelete: _sharing ? null : () => _confirmDelete(context),
          shareBusy: _sharing,
          shareError: _shareError == null
              ? null
              : exportShareFailureText(l10n, _shareError!),
        );
      },
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
        title: Text(l10n.homeMoveToTrash),
        content: Text(l10n.homeMoveToTrashConfirm(1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeService.activeColorScheme.error,
            ),
            onPressed: () async {
              try {
                await LocalFileTrashService.move(
                  file,
                  LocalTrashKind.exportedWork,
                );
                StorageInfoService().invalidate();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                widget.onDeleted();
              } catch (error, stackTrace) {
                AppErrorReporter.record(error, stackTrace);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(l10n.homeTrashOperationFailed)),
                  );
                }
              }
            },
            child: Text(l10n.commonMove),
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
  // 開いたらキーボードのEnterで「はじめる」を押せるようにする。
  final _startFocus = FocusNode(debugLabel: 'firstLaunchStart');

  @override
  void dispose() {
    _startFocus.dispose();
    super.dispose();
  }

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
        // 保存を待つ間は押せないボタンからフォーカスが外れている。押せる
        // ように戻ってから、Enterでやり直せるようフォーカスを戻す。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startFocus.requestFocus();
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
            // 韓国語は語の途中で折り返さない。描く文にだけ語結合子を入れ、
            // 読み上げには元の文を渡す。
            Text.rich(
              TextSpan(
                text: keepKoreanWordsTogether(l10n.homeFirstLaunchMessage),
                semanticsLabel: l10n.homeFirstLaunchMessage,
              ),
            ),
            if (_saving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              // 色ではなく先頭の印と文で知らせ、読み上げへも伝える
              // （文字の色はダイアログの文字色）。韓国語は語の途中で
              // 折り返さない（押すボタンの名前が2行に割れないように）。
              // 日本語・中国語も、押すボタンの名前は引用符ごと1行に保つ。
              ExportShareNotice(
                message: keepKoreanWordsTogether(
                  keepPhraseTogether(
                    l10n.homeFirstLaunchSaveFailed,
                    l10n.homeFirstLaunchStart,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // 「はじめる」ボタンの文字はくらむぼんを明示指定する
          // （通常のボタン文字は白光明朝のため、ここだけ差し替える）。
          FilledButton(
            focusNode: _startFocus,
            autofocus: true,
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
