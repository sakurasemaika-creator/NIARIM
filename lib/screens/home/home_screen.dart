import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../engine/mirapro_serializer.dart';
import '../../services/advertising_service.dart';
import '../../services/font_service.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
import '../../widgets/ad_banner_widget.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/home_drawer.dart';
import '../../widgets/help_button.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

  /// .mirashare受信フロー（仕様書06）：OSから共有ファイルを開いた場合の処理。
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
          '${tmpDir.path}/shared_${DateTime.now().millisecondsSinceEpoch}.mirashare');
      await file.writeAsBytes(bytes);
      localPath = file.path;
    }
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('共有ファイル'),
        content: const Text('この共有ファイルを複製して通常プロジェクトとして保存しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (proceed != true) return;
    try {
      final data = await MiraproSerializer.loadShare(localPath);
      if (!mounted) return;
      final projectService = context.read<ProjectService>();
      final project = await projectService.importSharedProject(data);
      if (!mounted) return;
      // 同梱フォント（仕様書15：「フォントを含める」選択時）を取り込み登録する。
      final fontService = context.read<FontService>();
      final bundledFonts = MiraproSerializer.bundledFonts(data);
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
          SnackBar(content: Text('不足フォントがあります。$names')),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロジェクトタブへ追加しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('共有ファイルの読み込みに失敗しました: $e')),
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

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'プロジェクト名で検索',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('MIRANIMA'),
        actions: [
          const HelpButton(),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
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
                const PopupMenuItem(value: ProjectViewMode.large, child: Text('大')),
                const PopupMenuItem(value: ProjectViewMode.medium, child: Text('中')),
                const PopupMenuItem(value: ProjectViewMode.small, child: Text('小')),
                const PopupMenuItem(value: ProjectViewMode.detail, child: Text('詳細')),
              ],
            ),
            PopupMenuButton<ProjectSortMode>(
              icon: const Icon(Icons.sort),
              onSelected: (mode) => setState(() => _sortMode = mode),
              itemBuilder: (_) => [
                const PopupMenuItem(value: ProjectSortMode.nameAsc, child: Text('名前 ↑')),
                const PopupMenuItem(value: ProjectSortMode.nameDesc, child: Text('名前 ↓')),
                const PopupMenuItem(value: ProjectSortMode.updatedAsc, child: Text('更新日時 ↑')),
                const PopupMenuItem(value: ProjectSortMode.updatedDesc, child: Text('更新日時 ↓')),
              ],
            ),
            IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _isSearching = true)),
            IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'プロジェクト'),
            Tab(text: '共有'),
            Tab(text: 'ゴミ箱'),
          ],
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
                    child: const Text('全選択'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIds.clear();
                      _isSelectionMode = false;
                    }),
                    child: const Text('全解除'),
                  ),
                  const Spacer(),
                  Text('${_selectedIds.length}件選択中'),
                  if (_selectedIds.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteSelected,
                      tooltip: 'ゴミ箱へ移動',
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
                            label: const Text('お気に入り'),
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
              ],
            ),
          ),
          if (adService.shouldShowAds) const AdBannerWidget(),
        ],
      ),
      // プロジェクトタブでのみ表示。共有・ゴミ箱タブでは新規作成の
      // 導線自体が不要なため非表示にする。
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showAddChoiceSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// FABタップ時：新規プロジェクトか新規フォルダかを選ばせる（仕様書19：
  /// フォルダとプロジェクトを同一一覧内で扱う設計のため、どちらも一覧の
  /// ＋ボタンから作成できる必要がある）。
  void _showAddChoiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('新規プロジェクト'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-project');
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新規フォルダ'),
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
    final service = context.read<ProjectService>();
    final projectIds = service.projects.map((p) => p.id).toSet();
    final targetIds = _selectedIds.where(projectIds.contains).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ゴミ箱へ移動'),
        content: Text('${targetIds.length}件をゴミ箱へ移動しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
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
            child: const Text('移動'),
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

class _SharedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shared = context.watch<ProjectService>().shared;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (shared.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share_outlined, size: 64, color: muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('共有プロジェクトがありません', style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: shared.length,
      itemBuilder: (context, index) {
        final project = shared[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(project.backgroundColor),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          title: Text(project.name),
          subtitle: Text('${project.fps}fps · ${project.durationSeconds}秒'),
          onTap: () => context.push('/project/${project.id}'),
        );
      },
    );
  }
}

class _TrashTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trash = context.watch<ProjectService>().trash;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (trash.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 64, color: muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('ゴミ箱は空です', style: TextStyle(color: muted)),
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
            : '${deletedAt.year}/${deletedAt.month.toString().padLeft(2, '0')}/${deletedAt.day.toString().padLeft(2, '0')} 削除';
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(project.backgroundColor),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          title: Text(project.name),
          subtitle: Text(deletedLabel.isEmpty
              ? '${project.fps}fps · ${project.durationSeconds}秒'
              : '$deletedLabel · ${project.fps}fps · ${project.durationSeconds}秒'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => context.read<ProjectService>().restoreProject(project.id),
                child: const Text('復元'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _confirmPermanentDelete(context, project.id),
                child: const Text('完全削除'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmPermanentDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完全に削除しますか？'),
        content: const Text('元に戻すことはできません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ProjectService>().permanentDelete(id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

enum ProjectViewMode { large, medium, small, detail }
enum ProjectSortMode { nameAsc, nameDesc, updatedAsc, updatedDesc }

// ─── 初回起動ポップアップ ─────────────────────────────────────────────────
// 仕様書02・11・19：初回起動時は「手書きアニメーションを制作できます」の
// ポップアップのみを表示する（複数ページのチュートリアルは表示しない）。

class _FirstLaunchDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _FirstLaunchDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Text('手書きアニメーションを制作できます'),
      actions: [
        FilledButton(onPressed: onDone, child: const Text('はじめる')),
      ],
    );
  }
}
