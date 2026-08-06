import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../engine/mirapro_serializer.dart';
import '../../services/advertising_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../services/share_intent_service.dart';
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
  StreamSubscription<String>? _sharedFileSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
      _initShareIntentHandling();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      await context.read<ProjectService>().importSharedProject(data);
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
        title: const Text('MIRANIMA'),
        actions: [
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
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
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
                      final projects = context.read<ProjectService>().projects;
                      setState(() => _selectedIds.addAll(projects.map((p) => p.id)));
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new-project'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ゴミ箱へ移動'),
        content: Text('${_selectedIds.length}件をゴミ箱へ移動しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final service = context.read<ProjectService>();
              for (final id in _selectedIds) {
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
}

class _SharedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shared = context.watch<ProjectService>().shared;
    if (shared.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('共有プロジェクトがありません', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return const Center(child: Text('共有一覧'));
  }
}

class _TrashTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trash = context.watch<ProjectService>().trash;
    if (trash.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('ゴミ箱は空です', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: trash.length,
      itemBuilder: (context, index) {
        final project = trash[index];
        return ListTile(
          leading: Container(width: 48, height: 48, color: Color(project.backgroundColor)),
          title: Text(project.name),
          subtitle: Text('${project.fps}fps · ${project.durationSeconds}秒'),
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

// ─── 初回起動チュートリアルダイアログ ────────────────────────────────────────

class _FirstLaunchDialog extends StatefulWidget {
  final VoidCallback onDone;
  const _FirstLaunchDialog({required this.onDone});

  @override
  State<_FirstLaunchDialog> createState() => _FirstLaunchDialogState();
}

class _FirstLaunchDialogState extends State<_FirstLaunchDialog> {
  int _page = 0;

  static const _pages = [
    _TutorialPage(
      icon: Icons.movie_creation_outlined,
      title: 'MIRANIMAへようこそ',
      body: '手書きアニメーションを\n簡単に制作できるアプリです。',
    ),
    _TutorialPage(
      icon: Icons.brush,
      title: 'キャンバスで描く',
      body: 'ペン・消しゴム・バケツなど\n豊富なツールで自由に描けます。',
    ),
    _TutorialPage(
      icon: Icons.layers,
      title: 'レイヤーで管理',
      body: '複数のレイヤーを重ねて\n複雑な絵も描けます。',
    ),
    _TutorialPage(
      icon: Icons.movie,
      title: 'タイムラインで動かす',
      body: 'フレームを追加して\nアニメーションを作りましょう。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(page.icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              page.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(page.body, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => Container(
                width: 8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                ),
              )),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        if (_page > 0)
          TextButton(
            onPressed: () => setState(() => _page--),
            child: const Text('戻る'),
          ),
        const Spacer(),
        FilledButton(
          onPressed: isLast ? widget.onDone : () => setState(() => _page++),
          child: Text(isLast ? 'はじめる' : '次へ'),
        ),
      ],
    );
  }
}

class _TutorialPage {
  final IconData icon;
  final String title;
  final String body;
  const _TutorialPage({required this.icon, required this.title, required this.body});
}
