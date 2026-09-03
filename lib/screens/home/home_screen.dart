import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../engine/export_engine.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../services/advertising_service.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/font_service.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/work_folder_service.dart';
import '../community/widgets/community_work_card.dart';
import '../../models/shortcut_binding.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/sort_mode_control.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/home_drawer.dart';
import '../../config/font_fallback.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // 作品広場画面と同様に、左上から起動画面へ戻れるようにするための
  // Scaffoldキー。ホーム画面はhamburgerメニュー（HomeDrawer）を持つため
  // AppBarのleadingが自動的にメニューアイコンで埋まっており、そのままでは
  // 戻る矢印を追加できない。そのためleadingを「戻る矢印＋メニュー
  // アイコン」の2つ並びに差し替え、メニューアイコン側はこのキー経由で
  // Scaffold.openDrawer()を呼び出す（自動表示に頼らない）。
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  ProjectViewMode _viewMode = ProjectViewMode.medium;
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
  String _searchQuery = '';
  final _searchController = TextEditingController();
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    // 低スペック端末では小表示を自動推奨する。ユーザーが表示切替
    // メニューからいつでも変更できる初期値としてのみ適用する。
    if (context.read<PerformanceService>().qualityLevel == QualityLevel.low) {
      _viewMode = ProjectViewMode.small;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
      _initShareIntentHandling();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
      builder: (ctx) => _FirstLaunchDialog(
        onDone: () {
          Navigator.pop(ctx);
          settings.markFirstLaunchDone();
        },
      ),
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
    final adService = context.watch<AdvertisingService>();
    final l10n = AppLocalizations.of(context)!;

    // マウス/キーボード入力・左手デバイス：設定画面「ショートカット設定」
    // で割り当てたキーで、全選択・コピー・切り取り・貼り付けを
    // 行えるようにする。
    return CallbackShortcuts(
      bindings: _buildShortcutBindings(context),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            // 左上に「起動画面へ戻る」矢印と、ハンバーガーメニュー（設定・
            // ヘルプ等への導線）の2つを並べる。作品広場画面には元々戻る
            // 矢印がある（プッシュ遷移のため自動表示）。ホーム画面も起動
            // 画面からpush()で遷移するが、既にドロワーでleadingが埋まるため、
            // 両方を明示的に並べる形にしている。
            leadingWidth: 96,
            leading: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.homeBackToSplashTooltip,
                  onPressed: () => context.go('/'),
                ),
                IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).openAppDrawerTooltip,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
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
                // アプリ名の代わりに、現在の並び替え基準（名前／更新日時）を
                // 常に表示するプルダウンと、昇順・降順をワンタップで切り替える
                // 矢印ボタンを置く。並び替え状態が常に一目でわかるようにする
                // ための変更。
                : SortModeControl(
                    sortByName: _sortByName,
                    sortAscending: _sortAscending,
                    onSortByNameChanged: _setSortByName,
                    onToggleDirection: _toggleSortDirection,
                  ),
            actions: [
              // ヘルプ・設定は左側ハンバーガーメニュー（HomeDrawer）に既に存在するため、
              // トップ画面右上からは重複表示を削除した。
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
                if (_hasClipboard)
                  IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: l10n.homePasteTooltip(
                      _clipboardProjectIds.length + _clipboardFolderIds.length,
                    ),
                    onPressed: _pasteClipboard,
                  ),
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
                  l10n.homeTabBookmarked,
                ],
              ),
            ),
          ),
          drawer: const HomeDrawer(),
          body: Column(
            children: [
              if (_isSelectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _selectAllInCurrentFolder,
                        child: Text(l10n.homeSelectionAllSelect),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedIds.clear();
                          _isSelectionMode = false;
                        }),
                        child: Text(l10n.homeSelectionAllDeselect),
                      ),
                      const Spacer(),
                      Text(l10n.homeSelectionCount(_selectedIds.length)),
                      if (_selectedIds.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.star, color: Colors.amber),
                          onPressed: () => _bulkSetFavorite(true),
                          tooltip: l10n.homeSelectionAddFavorite,
                        ),
                        IconButton(
                          icon: const Icon(Icons.star_border),
                          onPressed: () => _bulkSetFavorite(false),
                          tooltip: l10n.homeSelectionRemoveFavorite,
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_cut),
                          onPressed: _cutSelected,
                          tooltip: l10n.commonCut,
                        ),
                        // フォルダの複製は未対応のため、選択にフォルダが1つでも
                        // 含まれる場合はコピー操作自体を無効化する。
                        IconButton(
                          icon: const Icon(Icons.content_copy),
                          onPressed:
                              _selectedIds.every(
                                (id) => context
                                    .read<ProjectService>()
                                    .projects
                                    .any((p) => p.id == id),
                              )
                              ? _copySelected
                              : null,
                          tooltip: l10n.commonCopy,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _deleteSelected,
                          tooltip: l10n.homeMoveToTrash,
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Column(
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
                        // フォルダ内移動時のパンくずリスト。検索中は
                        // 全体から検索するため非表示にする。
                        if (_searchQuery.trim().isEmpty) _buildBreadcrumb(),
                        Expanded(
                          child: ProjectListWidget(
                            // 「共有」タブ（.niashareインポート由来）は別枠の
                            // 一覧のため、プロジェクトタブには表示しない。
                            projects: context
                                .watch<ProjectService>()
                                .projects
                                .where((p) => !p.isSharedImport)
                                .toList(),
                            viewMode: _viewMode,
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
                            currentFolderId: _currentFolderId,
                            onOpenFolder: (id) =>
                                setState(() => _currentFolderId = id),
                          ),
                        ),
                      ],
                    ),
                    const _WorksTab(),
                    const _BookmarkedTab(),
                  ],
                ),
              ),
              if (adService.shouldShowAds) const AdBannerWidget(),
            ],
          ),
          // プロジェクトタブ：新規プロジェクト／新規フォルダを選べるFAB。
          // 作品一覧タブ：新規プロジェクト作成の導線は不要なため、フォルダの
          // 新規作成のみをワンタップ・選択肢なしで直接行えるFABにする。
          floatingActionButton: switch (_currentTabIndex) {
            0 => FloatingActionButton(
              onPressed: () => _showAddChoiceSheet(context),
              child: const Icon(Icons.add),
            ),
            1 => FloatingActionButton(
              tooltip: AppLocalizations.of(context)!.homeAddSheetNewFolder,
              onPressed: () => showCreateFolderNameDialog(
                context,
                (name) => context.read<WorkFolderService>().createFolder(name),
              ),
              child: const Icon(Icons.create_new_folder_outlined),
            ),
            _ => null,
          },
        ),
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
      builder: (ctx) => SafeArea(
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

  /// 選択中のプロジェクト・フォルダのお気に入り状態をまとめて[favorite]へ
  /// 揃える（toggleFavorite系は反転のみのため、既に望む状態のものは
  /// スキップする）。
  void _bulkSetFavorite(bool favorite) {
    final service = context.read<ProjectService>();
    for (final id in _selectedIds) {
      final project = service.projects.where((p) => p.id == id).firstOrNull;
      if (project != null) {
        if (project.isFavorite != favorite) service.toggleFavorite(id);
        continue;
      }
      final folder = service.folders.where((f) => f.id == id).firstOrNull;
      if (folder != null && folder.isFavorite != favorite) {
        service.toggleFolderFavorite(id);
      }
    }
  }

  void _deleteSelected() {
    // ゴミ箱はプロジェクトのみが対象（ゴミ箱＝「削除したプロジェクト」）。
    // 選択にフォルダが含まれていても、フォルダ自体はここでは削除しない。
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final projectIds = service.projects.map((p) => p.id).toSet();
    final targetIds = _selectedIds.where(projectIds.contains).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homeMoveToTrash),
        content: Text(l10n.homeMoveToTrashConfirm(targetIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              for (final id in targetIds) {
                service.deleteProject(id);
              }
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonMove),
          ),
        ],
      ),
    );
  }

  /// 現在開いているフォルダ直下のプロジェクト・フォルダを両方選択する
  /// （選択モードでなければ自動的に選択モードへ入る）。手動の「全選択」
  /// ボタンとCtrl+Aショートカットの両方から使う共通処理。
  void _selectAllInCurrentFolder() {
    final service = context.read<ProjectService>();
    final projectIds = service.projects
        .where((p) => p.folderId == _currentFolderId)
        .map((p) => p.id);
    final folderIds = service.folders
        .where((f) => f.parentFolderId == _currentFolderId)
        .map((f) => f.id);
    setState(() {
      _isSelectionMode = true;
      _selectedIds
        ..addAll(projectIds)
        ..addAll(folderIds);
    });
  }

  /// 設定画面「ショートカット設定」の割り当て一覧から、ホーム画面で
  /// 有効なキー割り当てのマップを組み立てる。ツール選択の割り当ては
  /// キャンバスモード専用の概念のためここでは無視する。
  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
    BuildContext context,
  ) {
    final bindings = context.watch<ShortcutService>().bindings;
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
    final projectIds = service.projects.map((p) => p.id).toSet();
    final folderIds = service.folders.map((f) => f.id).toSet();
    setState(() {
      _clipboardProjectIds
        ..clear()
        ..addAll(_selectedIds.where(projectIds.contains));
      _clipboardFolderIds
        ..clear()
        ..addAll(_selectedIds.where(folderIds.contains));
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
    final projectIds = service.projects.map((p) => p.id).toSet();
    setState(() {
      _clipboardProjectIds
        ..clear()
        ..addAll(_selectedIds.where(projectIds.contains));
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
  void _pasteClipboard() {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final isCut = _clipboardIsCut;
    for (final id in _clipboardProjectIds) {
      if (isCut) {
        service.moveToFolder(id, _currentFolderId);
      } else {
        service.duplicateProject(
          id,
          targetFolderId: _currentFolderId,
          useTargetFolder: true,
        );
      }
    }
    if (isCut) {
      for (final id in _clipboardFolderIds) {
        service.moveFolderTo(id, _currentFolderId);
      }
    }
    if (isCut) {
      setState(() {
        _clipboardProjectIds.clear();
        _clipboardFolderIds.clear();
      });
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.homePasteSnackbar)));
  }

  /// フォルダ階層のパンくずリスト。フォルダ内移動時に現在位置を表示する。
  /// ホームアイコンでルートへ、各フォルダ名でその階層へ移動。
  Widget _buildBreadcrumb() {
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
}

/// ホーム画面のタブバー。標準のTabBarと異なり、各タブ名の実際の描画幅を
/// 計測してその比率で幅を配分する（均等4分割だと「プロジェクト」のような
/// 長い項目名が「共有」等より窮屈になり、文字が見切れてしまうため）。
/// TabControllerを共有しているため、TabBarViewとのスワイプ連動・タップでの
/// 切り替えはそのまま機能する。
class _HomeTabBar extends StatelessWidget {
  final TabController controller;
  final int currentIndex;
  final List<String> labels;

  const _HomeTabBar({
    required this.controller,
    required this.currentIndex,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
      )..layout();
      return tp.width + 32;
    }).toList();

    Widget tabItem(int i) => InkWell(
      onTap: () => controller.animateTo(i),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: currentIndex == i ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          labels[i],
          style: textStyle.copyWith(
            color: currentIndex == i ? scheme.primary : scheme.onSurfaceVariant,
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

/// 「共有」一覧画面。ホーム画面のタブからハンバーガーメニューへ移動した
/// ため、独立した画面として起動する（'/shared'ルート）。
class SharedScreen extends StatefulWidget {
  const SharedScreen({super.key});

  @override
  State<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends State<SharedScreen> {
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
      appBar: AppBar(
        title: SortModeControl(
          sortByName: _sortByName,
          sortAscending: _sortAscending,
          onSortByNameChanged: _setSortByName,
          onToggleDirection: _toggleSortDirection,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    l10n.homeFavoritesOnly,
                    style: const TextStyle(fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback),
                  ),
                  selected: _showFavoritesOnly,
                  onSelected: (v) => setState(() => _showFavoritesOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _SharedTab(
              sortMode: _sortMode,
              showFavoritesOnly: _showFavoritesOnly,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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

/// 「ゴミ箱」一覧画面。ホーム画面のタブからハンバーガーメニューへ移動した
/// ため、独立した画面として起動する（'/trash'ルート）。
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: SortModeControl(
          sortByName: _sortByName,
          sortAscending: _sortAscending,
          onSortByNameChanged: _setSortByName,
          onToggleDirection: _toggleSortDirection,
        ),
      ),
      body: _TrashTab(sortMode: _sortMode),
    );
  }
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
    var shared = context.watch<ProjectService>().shared;
    if (showFavoritesOnly) {
      shared = shared.where((p) => p.isFavorite).toList();
    }
    shared = _sortProjects(shared, sortMode);
    final l10n = AppLocalizations.of(context)!;
    if (shared.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.share_outlined,
        title: l10n.homeSharedEmpty,
      );
    }
    return _FolderableList<Project>(
      allItems: shared,
      folders: context.watch<ProjectService>().sharedFolders,
      folderIdOf: (p) => p.sharedFolderId,
      onEnterFolder: (folderId, folderName, itemsInFolder) =>
          Navigator.of(context).push(
            MaterialPageRoute(
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
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
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
            style: const TextStyle(fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback),
          ),
          subtitle: Text(
            l10n.homeProjectMeta(project.fps, project.durationSeconds),
          ),
          onTap: () => context.push('/project/${project.id}'),
          onLongPress: () => _showMoveToSharedFolderSheet(context, project),
        ),
      ),
    );
  }

  void _showMoveToSharedFolderSheet(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(l10n.folderNone),
              onTap: () {
                service.moveToSharedFolder(project.id, null);
                Navigator.pop(ctx);
              },
            ),
            for (final f in service.sharedFolders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.name),
                onTap: () {
                  service.moveToSharedFolder(project.id, f.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
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
          ? Center(
              child: Text(
                l10n.folderManagementEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final project = items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
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
                      style: const TextStyle(fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback),
                    ),
                    subtitle: Text(
                      l10n.homeProjectMeta(
                        project.fps,
                        project.durationSeconds,
                      ),
                    ),
                    onTap: () => context.push('/project/${project.id}'),
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
  final void Function(String id, String name) onRenameFolder;
  final void Function(String id) onDeleteFolder;
  final Widget Function(BuildContext, T) itemBuilder;

  const _FolderableList({
    required this.allItems,
    required this.folders,
    required this.folderIdOf,
    required this.onEnterFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.itemBuilder,
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
    return ListView.builder(
      itemCount: rootItems.length + (hasHeader ? 2 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return _folderChips(context, countByFolder);
        }
        if (hasHeader && index == 1) return const Divider(height: 1);
        return itemBuilder(context, rootItems[index - (hasHeader ? 2 : 0)]);
      },
    );
  }

  Widget _folderChips(BuildContext context, Map<String, int> countByFolder) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: folders.map((f) {
          final count = countByFolder[f.id] ?? 0;
          return InkWell(
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
                  Text(f.name),
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
          );
        }).toList(),
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
                final controller = TextEditingController(text: folder.name);
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(l10n.commonRename),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx),
                        child: Text(l10n.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            onRenameFolder(folder.id, controller.text.trim());
                          }
                          Navigator.pop(dctx);
                        },
                        child: Text(l10n.commonChange),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                l10n.commonDelete,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(l10n.projectListDeleteFolderConfirmTitle),
                    content: Text(
                      l10n.projectListDeleteFolderConfirmBody(folder.name),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx),
                        child: Text(l10n.commonCancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          onDeleteFolder(folder.id);
                          Navigator.pop(dctx);
                        },
                        child: Text(l10n.commonDelete),
                      ),
                    ],
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

class _TrashTab extends StatelessWidget {
  final ProjectSortMode sortMode;

  const _TrashTab({required this.sortMode});

  @override
  Widget build(BuildContext context) {
    final trash = _sortProjects(
      context.watch<ProjectService>().trash,
      sortMode,
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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.15),
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
              style: const TextStyle(fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback),
            ),
            subtitle: Text(
              deletedLabel.isEmpty ? meta : '$deletedLabel · $meta',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () =>
                      context.read<ProjectService>().restoreProject(project.id),
                  child: Text(l10n.commonRestore),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _confirmPermanentDelete(context, project.id),
                  child: Text(l10n.homePermanentDelete),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmPermanentDelete(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homePermanentDeleteConfirmTitle),
        content: Text(l10n.homePermanentDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ProjectService>().permanentDelete(id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

/// 「作品一覧」タブ：書き出し済みの動画・GIF
/// ファイルをアプリ内保存先（ExportEngine.exportsDir、
/// getApplicationDocumentsDirectory()/exports）から一覧表示する。
/// タップでアプリ内プレビュー、共有ボタンでOSの共有シートから写真アプリ等へ
/// 「開く」ことができる（share_plusは書き出し完了ダイアログで既に使用している
/// 実績のある仕組みのため、新規ネイティブ依存を追加せずに実現できる）。
/// 「ブクマ済みの作品」タブ。「作品広場」画面
/// （`CommunityService`）でブックマークした他ユーザーの公開作品を一覧
/// 表示する。ダウンロードはせず、あくまで一覧表示のみ（バックエンド
/// 未実装のため現状はダミーデータ上のブックマーク状態を参照する）。
/// 1件もブックマークしていない場合は従来どおりの案内表示のままにする。
class _BookmarkedTab extends StatelessWidget {
  const _BookmarkedTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final communityService = context.watch<CommunityService>();
    // 新しくブックマークした順に並べる。communityService.worksの並び
    // （ダミーデータの生成順）のままだと、たった今ブックマークした作品が
    // 一覧のどこに現れるか分からず、操作の結果が確認できない。
    final byId = {for (final w in communityService.works) w.id: w};
    final bookmarkedWorks = [
      for (final id in communityService.bookmarkedIdsNewestFirst)
        if (byId[id] != null) byId[id]!,
    ];

    if (bookmarkedWorks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 64,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeBookmarkedComingSoonTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeBookmarkedComingSoonBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: CommunityWorkGrid(
        works: bookmarkedWorks,
        bookmarkedIds: communityService.bookmarkedIds,
        onTapWork: (work) => context.read<CommunityPreviewService>().show(work),
        onToggleBookmark: (work) => communityService.toggleBookmark(work.id),
      ),
    );
  }
}

class _WorksTab extends StatefulWidget {
  const _WorksTab();

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
    setState(
      () => _future = ExportEngine.listExportedFiles(forceRefresh: true),
    );
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<File>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snapshot.data!;
        if (files.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              children: [
                SizedBox(
                  height: 400,
                  child: EmptyStatePlaceholder(
                    icon: Icons.video_library_outlined,
                    title: l10n.homeWorksEmpty,
                    hint: l10n.homeWorksEmptyHint,
                  ),
                ),
              ],
            ),
          );
        }
        final workFolders = context.watch<WorkFolderService>();
        return RefreshIndicator(
          onRefresh: _reload,
          child: _FolderableList<File>(
            allItems: files,
            folders: workFolders.folders,
            folderIdOf: (f) =>
                workFolders.folderIdOf(f.path.split(RegExp(r'[\\/]')).last),
            onEnterFolder: (folderId, folderName, itemsInFolder) =>
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _WorksFolderScreen(
                      folderId: folderId,
                      folderName: folderName,
                      onDeleted: _reload,
                    ),
                  ),
                ),
            onRenameFolder: (id, name) => workFolders.renameFolder(id, name),
            onDeleteFolder: (id) => workFolders.deleteFolder(id),
            itemBuilder: (context, file) =>
                _WorkListItem(file: file, onDeleted: _reload),
          ),
        );
      },
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
            return Center(
              child: Text(
                l10n.folderManagementEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _WorkListItem(
              file: items[index],
              onDeleted: () {
                setState(
                  () => _future = ExportEngine.listExportedFiles(
                    forceRefresh: true,
                  ),
                );
                widget.onDeleted();
              },
            ),
          );
        },
      ),
    );
  }
}

class _WorkListItem extends StatelessWidget {
  final File file;
  final VoidCallback onDeleted;
  const _WorkListItem({required this.file, required this.onDeleted});

  String get _extension => file.path.split('.').last.toLowerCase();

  IconData get _icon {
    switch (_extension) {
      case 'gif':
        return Icons.gif_box_outlined;
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      color: scheme.surfaceContainerLow,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_icon, color: scheme.primary),
        ),
        title: Text(
          file.path.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback),
        ),
        subtitle: Text(
          '${_formatDate(stat.modified)} ・ ${_formatSize(stat.size)}',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        onTap: () => _openPreview(context),
        onLongPress: () => _showMoveToFolderSheet(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 「写真アプリで開く」＝OSの共有シート経由（新規ネイティブ実装不要）。
            IconButton(
              icon: const Icon(Icons.ios_share, size: 20),
              tooltip: l10n.homeShareOpenWith,
              onPressed: () => SharePlus.instance.share(
                ShareParams(files: [XFile(file.path)]),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red,
              ),
              tooltip: l10n.commonDelete,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolderSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<WorkFolderService>();
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(l10n.folderNone),
              onTap: () {
                service.moveFileToFolder(fileName, null);
                Navigator.pop(ctx);
              },
            ),
            for (final f in service.folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.name),
                onTap: () {
                  service.moveFileToFolder(fileName, f.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: _WorkPreview(file: file),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homeWorkDeleteConfirmTitle(file.path.split('/').last)),
        content: Text(l10n.homeWorkDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (file.existsSync()) file.deleteSync();
              Navigator.pop(ctx);
              onDeleted();
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

/// アプリ内プレビュー：MP4/WebMはVideoPlayerController（timeline_screen.dart
/// で既に実績のある仕組み）、GIFはFlutter標準のImage.file（アニメーション
/// GIFを自動再生する）を用いる。いずれも新規ネイティブ依存なし。
class _WorkPreview extends StatefulWidget {
  final File file;
  const _WorkPreview({required this.file});

  @override
  State<_WorkPreview> createState() => _WorkPreviewState();
}

class _WorkPreviewState extends State<_WorkPreview> {
  VideoPlayerController? _controller;
  bool _isGif = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _isGif = widget.file.path.toLowerCase().endsWith('.gif');
    if (!_isGif) {
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
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget content;
    if (_isGif) {
      content = Image.file(widget.file, fit: BoxFit.contain);
    } else if (_failed) {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.homePreviewFailed),
      );
    } else if (_controller != null && _controller!.value.isInitialized) {
      content = AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: GestureDetector(
          onTap: () => setState(() {
            _controller!.value.isPlaying
                ? _controller!.pause()
                : _controller!.play();
          }),
          child: VideoPlayer(_controller!),
        ),
      );
    } else {
      content = const Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: content),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.ios_share, size: 18),
                label: Text(l10n.homeShareOpenWith),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(widget.file.path)]),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonClose),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum ProjectViewMode { large, medium, small, detail }

enum ProjectSortMode { nameAsc, nameDesc, updatedAsc, updatedDesc }

// ─── 初回起動ポップアップ ─────────────────────────────────────────────────
// 初回起動時は「手描きアニメーションを制作できます」の
// ポップアップのみを表示する（複数ページのチュートリアルは表示しない）。

class _FirstLaunchDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _FirstLaunchDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Text(l10n.homeFirstLaunchMessage),
      actions: [
        // 「はじめる」ボタンの文字はくらむぼんを明示指定する
        // （通常のボタン文字は白光明朝のため、ここだけ差し替える）。
        FilledButton(
          onPressed: onDone,
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
    );
  }
}
