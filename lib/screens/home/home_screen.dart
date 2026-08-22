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
import '../../services/font_service.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
import '../../services/work_folder_service.dart';
import '../../widgets/ad_banner_widget.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/home_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProjectViewMode _viewMode = ProjectViewMode.medium;
  ProjectSortMode _sortMode = ProjectSortMode.updatedDesc;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _showFavoritesOnly = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  StreamSubscription<String>? _sharedFileSub;
  // 現在開いているフォルダ（仕様書19：フォルダは複数階層に対応・
  // パンくずリストで現在位置を表示）。nullはルート直下。
  String? _currentFolderId;
  // 新規追加系のFAB（＋ボタン）はプロジェクトタブでのみ表示する
  // （共有・ゴミ箱タブに新規プロジェクト作成の導線があるのは不自然なため）。
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    // 仕様書19：「低スペック端末では小表示を自動推奨」。ユーザーが表示切替
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

  /// .niashare受信フロー（仕様書06）：OSから共有ファイルを開いた場合の処理。
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
          '${tmpDir.path}/shared_${DateTime.now().millisecondsSinceEpoch}.niashare');
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.commonSave)),
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
      // 同梱フォント（仕様書15：「フォントを含める」選択時）を取り込み登録する。
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
      // 不足フォント検出（仕様書15：「不足フォントがあります。○○」）：
      // プロジェクトが使用するユーザー追加フォントのうち、同梱もされておらず
      // 端末側にも存在しないものを警告する。
      if (!mounted) return;
      final usedFamilies = projectService.usedFontFamiliesOf(project.id);
      final installedFamilies = fontService.fonts.map(fontService.familyNameOf).toSet();
      final missing = usedFamilies.where((f) =>
          f.startsWith('UserFont_') && !installedFamilies.contains(f));
      if (missing.isNotEmpty) {
        final names = missing.map((f) => f.replaceFirst('UserFont_', '')).join('、');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeMissingFontsSnackbar(names))),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeSharedImportedSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeSharedImportFailedSnackbar(e.toString()))),
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

  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdvertisingService>();
    final l10n = AppLocalizations.of(context)!;

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
            // アプリ名（NIARIM）はホーム画面左上にのみ表示される固有のロゴ
            // テキストのため、他画面のAppBarタイトル共通スタイル
            // （AppBarTheme.titleTextStyle：くらむぼん）とは別に、ここだけ
            // 白光明朝を明示指定する。明朝体は線が細く小さいと読みにくいため
            // 太字にし、文字間を少し広げて可読性を上げる。
            : Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontFamily: 'HakkouMincho',
                  fontFamilyFallback: ['NotoSerifJP'],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  height: 1.5,
                ),
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
            PopupMenuButton<ProjectViewMode>(
              icon: const Icon(Icons.view_module),
              onSelected: (mode) => setState(() => _viewMode = mode),
              itemBuilder: (_) => [
                PopupMenuItem(value: ProjectViewMode.large, child: Text(l10n.homeViewModeLarge)),
                PopupMenuItem(value: ProjectViewMode.medium, child: Text(l10n.homeViewModeMedium)),
                PopupMenuItem(value: ProjectViewMode.small, child: Text(l10n.homeViewModeSmall)),
                PopupMenuItem(value: ProjectViewMode.detail, child: Text(l10n.homeViewModeDetail)),
              ],
            ),
            PopupMenuButton<ProjectSortMode>(
              icon: const Icon(Icons.sort),
              onSelected: (mode) => setState(() => _sortMode = mode),
              itemBuilder: (_) => [
                PopupMenuItem(value: ProjectSortMode.nameAsc, child: Text(l10n.homeSortNameAsc)),
                PopupMenuItem(value: ProjectSortMode.nameDesc, child: Text(l10n.homeSortNameDesc)),
                PopupMenuItem(value: ProjectSortMode.updatedAsc, child: Text(l10n.homeSortUpdatedAsc)),
                PopupMenuItem(value: ProjectSortMode.updatedDesc, child: Text(l10n.homeSortUpdatedDesc)),
              ],
            ),
            IconButton(icon: const Icon(Icons.search), tooltip: l10n.commonSearch, onPressed: () => setState(() => _isSearching = true)),
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
              l10n.homeTabShared,
              l10n.homeTabTrash,
              l10n.homeTabWorks,
            ],
          ),
        ),
      ),
      drawer: const HomeDrawer(),
      body: Column(
        children: [
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      // 現在開いているフォルダ直下のプロジェクト・フォルダを両方選択
                      // （仕様書19：「対象：プロジェクト・フォルダ両方」）。
                      final service = context.read<ProjectService>();
                      final projectIds = service.projects
                          .where((p) => p.folderId == _currentFolderId)
                          .map((p) => p.id);
                      final folderIds = service.folders
                          .where((f) => f.parentFolderId == _currentFolderId)
                          .map((f) => f.id);
                      setState(() => _selectedIds..addAll(projectIds)..addAll(folderIds));
                    },
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(l10n.homeFavoritesOnly,
                                style: const TextStyle(fontFamily: 'Kuramubon')),
                            selected: _showFavoritesOnly,
                            onSelected: (v) => setState(() => _showFavoritesOnly = v),
                          ),
                        ],
                      ),
                    ),
                    // フォルダ内移動時のパンくずリスト（仕様書19）。検索中は
                    // 全体から検索するため非表示にする。
                    if (_searchQuery.trim().isEmpty) _buildBreadcrumb(),
                    Expanded(
                      child: ProjectListWidget(
                        viewMode: _viewMode,
                        sortMode: _sortMode,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        onLongPress: () => setState(() => _isSelectionMode = true),
                        onSelectionChanged: (id) => setState(() {
                          if (_selectedIds.contains(id)) {
                            _selectedIds.remove(id);
                          } else {
                            _selectedIds.add(id);
                          }
                        }),
                        showFavoritesOnly: _showFavoritesOnly,
                        searchQuery: _searchQuery,
                        currentFolderId: _currentFolderId,
                        onOpenFolder: (id) => setState(() => _currentFolderId = id),
                      ),
                    ),
                  ],
                ),
                _SharedTab(),
                _TrashTab(),
                const _WorksTab(),
              ],
            ),
          ),
          if (adService.shouldShowAds) const AdBannerWidget(),
        ],
      ),
      // プロジェクトタブ：新規プロジェクト／新規フォルダを選べるFAB。
      // 共有・作品一覧タブ：新規プロジェクト作成の導線は不要なため、
      // フォルダの新規作成のみをワンタップ・選択肢なしで直接行えるFABに
      // する。ゴミ箱タブでは新規作成自体が不要なため
      // 非表示のまま。
      floatingActionButton: switch (_currentTabIndex) {
        0 => FloatingActionButton(
            onPressed: () => _showAddChoiceSheet(context),
            child: const Icon(Icons.add),
          ),
        1 => FloatingActionButton(
            tooltip: AppLocalizations.of(context)!.homeAddSheetNewFolder,
            onPressed: () => showCreateFolderNameDialog(
                context, (name) => context.read<ProjectService>().createSharedFolder(name)),
            child: const Icon(Icons.create_new_folder_outlined),
          ),
        3 => FloatingActionButton(
            tooltip: AppLocalizations.of(context)!.homeAddSheetNewFolder,
            onPressed: () => showCreateFolderNameDialog(
                context, (name) => context.read<WorkFolderService>().createFolder(name)),
            child: const Icon(Icons.create_new_folder_outlined),
          ),
        _ => null,
      },
    );
  }

  /// FABタップ時：新規プロジェクトか新規フォルダかを選ばせる（仕様書19：
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

  void _deleteSelected() {
    // ゴミ箱はプロジェクトのみが対象（仕様書19：ゴミ箱＝「削除したプロジェクト」）。
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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

  /// フォルダ階層のパンくずリスト（仕様書19：「フォルダ内移動時はパンくずリストで
  /// 現在位置を表示する」）。ホームアイコンでルートへ、各フォルダ名でその階層へ移動。
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
                  child: Text(folder.name, style: const TextStyle(fontSize: 13)),
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
    final textStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    // 左右の余白（タップ領域確保）込みで、各タブ名の実際の描画幅を計測する。
    final weights = labels.map((label) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      return (tp.width + 32).round();
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              flex: weights[i],
              child: InkWell(
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
              ),
            ),
        ],
      ),
    );
  }
}

class _SharedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shared = context.watch<ProjectService>().shared;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context)!;
    if (shared.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share_outlined, size: 64, color: muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(l10n.homeSharedEmpty, style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    return _FolderableList<Project>(
      allItems: shared,
      folders: context.watch<ProjectService>().sharedFolders,
      folderIdOf: (p) => p.sharedFolderId,
      onEnterFolder: (folderId, folderName, itemsInFolder) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SharedFolderScreen(folderId: folderId, folderName: folderName),
        ),
      ),
      onRenameFolder: (id, name) => context.read<ProjectService>().renameSharedFolder(id, name),
      onDeleteFolder: (id) => context.read<ProjectService>().deleteSharedFolder(id),
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
          title: Text(project.name, style: const TextStyle(fontFamily: 'Kuramubon')),
          subtitle: Text(l10n.homeProjectMeta(project.fps, project.durationSeconds)),
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
    final items = context.watch<ProjectService>().shared.where((p) => p.sharedFolderId == folderId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: items.isEmpty
          ? Center(
              child: Text(l10n.folderManagementEmpty,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final project = items[index];
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
                    title: Text(project.name, style: const TextStyle(fontFamily: 'Kuramubon')),
                    subtitle: Text(l10n.homeProjectMeta(project.fps, project.durationSeconds)),
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
  final void Function(String folderId, String folderName, List<T> itemsInFolder) onEnterFolder;
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
    return ListView(
      children: [
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: folders.map((f) {
                final count = allItems.where((e) => folderIdOf(e) == f.id).length;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onEnterFolder(
                      f.id, f.name, allItems.where((e) => folderIdOf(e) == f.id).toList()),
                  onLongPress: () => _showFolderMenu(context, f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 18),
                        const SizedBox(width: 6),
                        Text(f.name),
                        const SizedBox(width: 4),
                        Text('($count)',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (folders.isNotEmpty) const Divider(height: 1),
        ...rootItems.map((e) => itemBuilder(context, e)),
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
                    content: TextField(controller: controller, autofocus: true,
                        decoration: const InputDecoration(border: OutlineInputBorder())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx), child: Text(l10n.commonCancel)),
                      FilledButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) onRenameFolder(folder.id, controller.text.trim());
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
              title: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(l10n.projectListDeleteFolderConfirmTitle),
                    content: Text(l10n.projectListDeleteFolderConfirmBody(folder.name)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx), child: Text(l10n.commonCancel)),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
  @override
  Widget build(BuildContext context) {
    final trash = context.watch<ProjectService>().trash;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context)!;
    if (trash.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 64, color: muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(l10n.homeTrashEmpty, style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: trash.length,
      itemBuilder: (context, index) {
        final project = trash[index];
        final deletedAt = context.read<ProjectService>().deletedAtOf(project.id);
        final deletedLabel = deletedAt == null
            ? ''
            : l10n.homeTrashDeletedOn(
                '${deletedAt.year}/${deletedAt.month.toString().padLeft(2, '0')}/${deletedAt.day.toString().padLeft(2, '0')}');
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
            title: Text(project.name, style: const TextStyle(fontFamily: 'Kuramubon')),
            subtitle: Text(deletedLabel.isEmpty ? meta : '$deletedLabel · $meta'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => context.read<ProjectService>().restoreProject(project.id),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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

/// 「作品一覧」タブ（仕様書06・仕様書AI設計書#101）：書き出し済みの動画・GIF
/// ファイルをアプリ内保存先（ExportEngine.exportsDir、
/// getApplicationDocumentsDirectory()/exports）から一覧表示する。
/// タップでアプリ内プレビュー、共有ボタンでOSの共有シートから写真アプリ等へ
/// 「開く」ことができる（share_plusは書き出し完了ダイアログで既に使用している
/// 実績のある仕組みのため、新規ネイティブ依存を追加せずに実現できる）。
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
    setState(() => _future = ExportEngine.listExportedFiles(forceRefresh: true));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_outlined, size: 64, color: muted.withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        Text(l10n.homeWorksEmpty, style: TextStyle(color: muted)),
                        const SizedBox(height: 4),
                        Text(l10n.homeWorksEmptyHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
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
            folderIdOf: (f) => workFolders.folderIdOf(f.path.split(RegExp(r'[\\/]')).last),
            onEnterFolder: (folderId, folderName, itemsInFolder) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _WorksFolderScreen(folderId: folderId, folderName: folderName, onDeleted: _reload),
              ),
            ),
            onRenameFolder: (id, name) => workFolders.renameFolder(id, name),
            onDeleteFolder: (id) => workFolders.deleteFolder(id),
            itemBuilder: (context, file) => _WorkListItem(
              file: file,
              onDeleted: _reload,
            ),
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
  const _WorksFolderScreen({required this.folderId, required this.folderName, required this.onDeleted});

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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!
              .where((f) => workFolders.folderIdOf(f.path.split(RegExp(r'[\\/]')).last) == widget.folderId)
              .toList();
          if (items.isEmpty) {
            return Center(
                child: Text(l10n.folderManagementEmpty,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _WorkListItem(
              file: items[index],
              onDeleted: () {
                setState(() => _future = ExportEngine.listExportedFiles(forceRefresh: true));
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
          style: const TextStyle(fontFamily: 'Kuramubon'),
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
              onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)])),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _controller?.play();
          _controller?.setLooping(true);
        }).catchError((_) {
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
            _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
          }),
          child: VideoPlayer(_controller!),
        ),
      );
    } else {
      content = const Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator()),
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
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(files: [XFile(widget.file.path)])),
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
// 仕様書02・11・19：初回起動時は「手描きアニメーションを制作できます」の
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
            style: const TextStyle(fontFamily: 'Kuramubon', fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
