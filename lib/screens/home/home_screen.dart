import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../engine/export_engine.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../services/community_preview_service.dart';
import '../../services/community_service.dart';
import '../../services/font_service.dart';
import '../../services/performance_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/folder_persistence.dart';
import '../../utils/name_collation.dart';
import '../../widgets/moved_to_trash_snack_bar.dart';
import '../../services/share_intent_service.dart';
import '../../services/shortcut_service.dart';
import '../../services/work_folder_service.dart';
import '../community/widgets/community_work_card.dart';
import '../../models/shortcut_binding.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/sort_mode_control.dart';
import '../../widgets/project_trash_dialog.dart';
import 'widgets/exported_work_card.dart';
import 'widgets/exported_work_preview_layout.dart';
import 'widgets/folder_delete_dialog.dart';
import 'widgets/folder_save_feedback.dart';
import 'widgets/work_folder_move_sheet.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/home_drawer.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../community/community_edit_feedback.dart';
import '../../widgets/typing_aware_shortcuts.dart';
import '../community/community_error_text.dart';
import '../../utils/color_contrast.dart';
import '../../utils/duplicate_name.dart';
import '../../widgets/app_tutorial.dart';
import '../canvas/widgets/canvas_icon_button.dart';

/// ホームの一覧の下端に足す余白：画面下の左右に浮くFAB（56）とその下の
/// 余白（16）、さらに端末のナビゲーションバーぶん（FABはその上に置かれる）。
/// 一番下までスクロールすれば最後の行がFABの上へ出る。
double _fabClearance(BuildContext context) =>
    56 + 16 + MediaQuery.paddingOf(context).bottom;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // The menu opens from the right; the launch-screen back arrow sits at the
  // left of the fixed AppBar. The page-level project list has its own scroll.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _projectScrollController = ScrollController();
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
  // false: project/folder name keyword search, true: project tag search.
  // The search bar toggle swaps these modes like a play/pause control.
  bool _searchByTag = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  // 検索を開いたら入力欄へ直接打てるようにする。画面全体のFocus
  // （autofocus）が先にフォーカスを持っているため、TextFieldのautofocus
  // だけでは入力欄にフォーカスが移らなかった。
  final _searchFocusNode = FocusNode();
  // 画面全体のショートカット（全選択・コピー等）を受けるフォーカス。
  // 入力欄からEnterや欄の外のクリックで抜けると、Flutterは画面の
  // フォーカススコープそのものへフォーカスを落とすため（このFocusより
  // 上）、検索を閉じた後もショートカットが効かなくなっていた。抜けるときは
  // ここへ戻す。
  final _homeFocusNode = FocusNode(debugLabel: 'Home');
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
        final wasSearching = _isSearching;
        setState(() {
          _currentTabIndex = _tabController.index;
          // 複数選択・検索・並び替え・表示の大きさはプロジェクトの一覧に
          // だけ効く。別のタブへ移ったら選択と検索を閉じる（選択したまま
          // 他のタブへ移ると、見えていないプロジェクトをゴミ箱へ移せていた）。
          if (_currentTabIndex != 0) {
            _selectedIds.clear();
            _isSelectionMode = false;
            _isSearching = false;
            _searchByTag = false;
            _searchQuery = '';
            _searchController.clear();
          }
        });
        // 検索欄にフォーカスが残ると、隠れた入力欄へ打ち続けられた。
        if (wasSearching && _currentTabIndex != 0) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      }
    });
    // 最後に選んだ表示サイズ・並び順を引き継ぐ。表示サイズを選んだことが
    // 無ければ、低スペック端末では小表示を初期値にする。
    final settings = context.read<SettingsService>();
    final savedView = ProjectViewMode.values.asNameMap()[settings.homeViewMode];
    if (savedView != null) {
      _viewMode = savedView;
    } else if (context.read<PerformanceService>().qualityLevel ==
        QualityLevel.low) {
      _viewMode = ProjectViewMode.small;
    }
    _sortMode =
        ProjectSortMode.values.asNameMap()[settings.homeSortMode] ?? _sortMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
      _initShareIntentHandling();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _homeFocusNode.dispose();
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

  // 初回起動では使い方（図つきの数ページ）を出す。最後まで見ても、
  // スキップしても、戻る操作で閉じても、次からは出さない（ホームのメニュー・
  // ヘルプの「使い方」から見直せる）。
  Future<void> _checkFirstLaunch() async {
    final settings = context.read<SettingsService>();
    if (!settings.isFirstLaunch) return;
    await AppTutorial.show(context);
    await settings.markFirstLaunchDone();
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

  void _setSortMode(ProjectSortMode mode) {
    setState(() => _sortMode = mode);
    context.read<SettingsService>().setHomeSortMode(mode.name);
  }

  void _setSortByName(bool byName) {
    _setSortMode(
      byName
          ? (_sortAscending
                ? ProjectSortMode.nameAsc
                : ProjectSortMode.nameDesc)
          : (_sortAscending
                ? ProjectSortMode.updatedAsc
                : ProjectSortMode.updatedDesc),
    );
  }

  void _toggleSortDirection() {
    _setSortMode(switch (_sortMode) {
      ProjectSortMode.nameAsc => ProjectSortMode.nameDesc,
      ProjectSortMode.nameDesc => ProjectSortMode.nameAsc,
      ProjectSortMode.updatedAsc => ProjectSortMode.updatedDesc,
      ProjectSortMode.updatedDesc => ProjectSortMode.updatedAsc,
    });
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
      _searchByTag = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isSearching) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchByTag = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _homeFocusNode.requestFocus();
  }

  /// 戻る操作（端末の戻るボタン・左上の矢印）で、画面を離れる前に
  /// いま開いている一時的な状態を1段ずつ閉じる。検索→複数選択→
  /// フォルダの順。何も無ければ起動画面へ戻ってよい（true）。
  bool _closeTransientState() {
    if (_isSearching) {
      _closeSearch();
      return false;
    }
    if (_isSelectionMode) {
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      return false;
    }
    if (_currentFolderId != null && _currentTabIndex == 0) {
      final folders = context.read<ProjectService>().folders;
      final current = folders.where((f) => f.id == _currentFolderId);
      setState(
        () => _currentFolderId = current.isEmpty
            ? null
            : current.first.parentFolderId,
      );
      return false;
    }
    return true;
  }

  void _leaveToSplash() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// 引き出し（ドロワー）等、この画面の上に重ねた物が開いていれば閉じる。
  /// [PopScope]で戻る操作を受けていると、Navigatorは重ねた物を自分では
  /// 閉じない（引き出しを開いたまま、裏で選択や検索が解除されていた）。
  bool _closeLocalHistory() {
    final route = ModalRoute.of(context);
    if (route == null || !route.willHandlePopInternally) return false;
    Navigator.of(context).pop();
    return true;
  }

  /// 戻る操作をここで先に受ける。上にダイアログ等が開いているときは
  /// 通常どおり（それを閉じる）。go_routerは戻れる画面が無いと[PopScope]へ
  /// 渡さずアプリを閉じるので、ホームが履歴の最後の1枚（`go('/home')`で
  /// 来た）のときも、引き出し・検索・選択・フォルダを閉じてから起動画面へ
  /// 戻す。
  Future<bool> _handleRootBack() async {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    if (_closeLocalHistory()) return true;
    if (context.canPop()) return false;
    if (_closeTransientState()) context.go('/');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // マウス/キーボード入力・左手デバイス：設定画面「ショートカット設定」
    // で割り当てたキーで、全選択・コピー・切り取り・貼り付けを
    // 行えるようにする。
    // 戻る操作は常にここで受ける。検索・複数選択・フォルダを順に閉じ、
    // 何も開いていなければ起動画面へ戻る。キャンバスや書き出しから
    // `go('/home')`で戻ると履歴はホーム1枚だけになり、そのまま戻すと
    // アプリが閉じてしまう（ホームは再ビルドされないので、`canPop`を
    // build時の履歴から決めると古い値のまま残る）。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_closeLocalHistory()) return;
        if (_closeTransientState()) _leaveToSplash();
      },
      child: BackButtonListener(
        onBackButtonPressed: _handleRootBack,
        child: TypingAwareShortcuts(
          bindings: _buildShortcutBindings(context),
          screenFocus: _homeFocusNode,
          child: Focus(
            focusNode: _homeFocusNode,
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
                // 作品一覧・ブクマ済みのタブでは、そのタブの名前を出す
                // （並び替え・検索はプロジェクトの一覧にだけ効く）。
                title: _currentTabIndex != 0
                    ? Text(
                        _currentTabIndex == 1
                            ? l10n.homeTabWorks
                            : l10n.homeTabBookmarked,
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
                            // マウス・ペンで押すと、欄の外を押したことに
                            // なって入力が画面へ戻るので、欄へ戻して打ち
                            // 続けられるようにする。
                            onPressed: () {
                              setState(() => _searchByTag = !_searchByTag);
                              _searchFocusNode.requestFocus();
                            },
                          ),
                          Expanded(
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): _closeSearch,
                              },
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: _searchByTag
                                      ? l10n.projectDetailTagsQuickAction
                                      : l10n.homeSearchHint,
                                  border: InputBorder.none,
                                ),
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                // Enterで確定したら、入力を終えて画面の
                                // ショートカットへ戻す（検索は開いたまま）。
                                onEditingComplete: _homeFocusNode.requestFocus,
                                // マウス・ペンで欄の外を押したときも同じ。
                                // 指で外を触っただけでは入力を続ける
                                // （Androidの標準の振る舞い）。
                                onTapOutside: (event) {
                                  if (event.kind != PointerDeviceKind.touch &&
                                      _searchFocusNode.hasFocus) {
                                    _homeFocusNode.requestFocus();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(l10n.homeTabProjects),
                actions: [
                  // ヘルプ・設定は左側ハンバーガーメニュー（HomeDrawer）に既に存在するため、
                  // トップ画面右上からは重複表示を削除した。
                  if (_isSearching)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.commonClose,
                      onPressed: _closeSearch,
                    )
                  else if (_currentTabIndex == 0) ...[
                    if (_hasClipboard)
                      IconButton(
                        icon: const Icon(Icons.content_paste),
                        tooltip: l10n.homePasteTooltip(
                          _clipboardProjectIds.length +
                              _clipboardFolderIds.length,
                        ),
                        onPressed: _pasting ? null : _pasteClipboard,
                      ),
                    ProjectViewModeMenu(
                      value: _viewMode,
                      onChanged: (mode) {
                        setState(() => _viewMode = mode);
                        context.read<SettingsService>().setHomeViewMode(
                          mode.name,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: l10n.commonSearch,
                      onPressed: _openSearch,
                    ),
                  ],
                  IconButton(
                    key: const Key('homeMenuButton'),
                    icon: const Icon(Icons.menu),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).openAppDrawerTooltip,
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
                // 標準のTabBarは項目名の文字数に関わらず均等4分割になるため、
                // 「プロジェクト」のように長い項目名が「共有」等の短い項目名と
                // 同じ幅しか確保できず、文字が見切れてしまっていた。各項目名の
                // 実際の描画幅を計測し、その比率でタブ幅を配分する独自実装へ
                // 差し替える（TabControllerは共通のまま、TabBarViewとの
                // スワイプ連動はそのまま維持される）。
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(_homeTabBarHeight),
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
              endDrawer: const HomeDrawer(),
              body: Column(
                children: [
                  if (_isSelectionMode) _buildSelectionBar(l10n),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Column(
                          children: [
                            // 保存先を読めなかったときは、空の一覧に見えて
                            // 作品が消えたと思わないよう知らせ、読み直せる
                            // ようにする。
                            if (context
                                .watch<ProjectService>()
                                .projectsLoadFailed)
                              _ProjectsLoadFailureNotice(
                                onRetry: () => context
                                    .read<ProjectService>()
                                    .retryLoadProjects(),
                              ),
                            Expanded(
                              child: ProjectListWidget(
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
                                                fontFamilyFallback:
                                                    kHeadingFontFallback,
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
                                            onSelected: (v) => setState(
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
                                                onSortByNameChanged:
                                                    _setSortByName,
                                                onToggleDirection:
                                                    _toggleSortDirection,
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
                                // 開いているフォルダ・表示ごとにスクロール位置を
                                // 覚える（入力中の検索語ごとには覚えない）。
                                key: PageStorageKey((
                                  'home-projects',
                                  _viewMode,
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
                                viewMode: _viewMode,
                                bottomPadding: _fabClearance(context),
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
                                onOpenFolder: (id) =>
                                    setState(() => _currentFolderId = id),
                                onClearSearch: _closeSearch,
                                pendingCutIds: _clipboardIsCut
                                    ? {
                                        ..._clipboardProjectIds,
                                        ..._clipboardFolderIds,
                                      }
                                    : const {},
                                onShowAll: () =>
                                    setState(() => _showFavoritesOnly = false),
                              ),
                            ),
                          ],
                        ),
                        const _WorksTab(key: PageStorageKey('home-works')),
                        const _BookmarkedTab(
                          key: PageStorageKey('home-bookmarks'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // プロジェクトタブ：新規プロジェクト／新規フォルダを選べるFAB。
              // 作品一覧タブ：新規プロジェクト作成の導線は不要なため、フォルダの
              // 新規作成のみをワンタップ・選択肢なしで直接行えるFABにする。
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
              floatingActionButton: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentTabIndex == 0)
                      FloatingActionButton(
                        key: const Key('homeScrollToTopFab'),
                        heroTag: 'home-scroll-to-top',
                        mini: MediaQuery.sizeOf(context).height < 400,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        tooltip: l10n.communityScrollToTop,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: const CircleBorder(side: BorderSide.none),
                        elevation: 0,
                        focusElevation: 0,
                        hoverElevation: 0,
                        highlightElevation: 0,
                        disabledElevation: 0,
                        onPressed: () {
                          if (!_projectScrollController.hasClients) return;
                          _projectScrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: const Icon(Icons.arrow_upward),
                      )
                    else
                      const SizedBox(width: 56),
                    if (_currentTabIndex == 0)
                      FloatingActionButton(
                        heroTag: 'home-add-project',
                        mini: MediaQuery.sizeOf(context).height < 400,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        tooltip: l10n.homeAddTooltip,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: const CircleBorder(side: BorderSide.none),
                        elevation: 0,
                        focusElevation: 0,
                        hoverElevation: 0,
                        highlightElevation: 0,
                        disabledElevation: 0,
                        onPressed: () => _showAddChoiceSheet(context),
                        child: const Icon(Icons.add),
                      )
                    else if (_currentTabIndex == 1)
                      FloatingActionButton(
                        heroTag: 'home-add-work-folder',
                        mini: MediaQuery.sizeOf(context).height < 400,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        tooltip: l10n.homeAddSheetNewFolder,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: const CircleBorder(side: BorderSide.none),
                        elevation: 0,
                        focusElevation: 0,
                        hoverElevation: 0,
                        highlightElevation: 0,
                        disabledElevation: 0,
                        onPressed: () => showCreateFolderNameDialog(
                          context,
                          (name) => context
                              .read<WorkFolderService>()
                              .createFolder(name),
                        ),
                        child: const Icon(Icons.create_new_folder_outlined),
                      )
                    else
                      const SizedBox(width: 56),
                  ],
                ),
              ),
            ),
          ),
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

  /// 選択中の操作バー。全選択・全解除・件数の文字の幅を詰め、狭い画面や
  /// 大きな文字でも切り取り・コピー・ゴミ箱を1行のまま出す（省略した文字は
  /// 長押し・ホバーで全文が出る）。お気に入りは一括では付け外ししない
  /// （各項目のメニューから）。
  /// 全選択・全解除の文字が省略されるほど狭いときは、2つともアイコンにする
  /// （仏語の「Tout sélectionner」「Tout désélectionner」がどちらも
  /// 「Tou…」になるように、省略すると見分けられない言語がある）。
  Widget _buildSelectionBar(AppLocalizations l10n) {
    const labelPadding = 4.0;
    final selectAll = l10n.homeSelectionAllSelect;
    final deselectAll = l10n.homeSelectionAllDeselect;
    final count = l10n.homeSelectionCount(_selectedIds.length);
    // 文字のボタンと同じ書式で、[width]に1行で収まるか。
    bool labelFits(BuildContext context, String text, double width) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style:
              Theme.of(
                context,
              ).textButtonTheme.style?.textStyle?.resolve(const {}) ??
              Theme.of(context).textTheme.labelLarge,
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width < 0 ? 0 : width);
      final fits = !painter.didExceedMaxLines;
      painter.dispose();
      return fits;
    }

    // [width]は通常48。文字を2倍にした240px幅のように欄がとても狭いときは
    // 3分の1まで縮める（48のままだと2つで欄からはみ出す）。
    Widget iconLabel(
      IconData icon,
      String text,
      VoidCallback onPressed,
      double width,
    ) => Tooltip(
      message: text,
      child: SizedBox(
        width: width,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(width, 48),
            tapTargetSize: width < 48 ? MaterialTapTargetSize.shrinkWrap : null,
            // 文字ボタンの既定（18）だと点線のアイコンが薄く見える。
            // 隣の切り取り・コピー・ゴミ箱と同じ大きさにする。
            iconSize: 24,
          ),
          onPressed: onPressed,
          // 読み上げではツールチップの文が名前になる（IconButtonと同じ）。
          child: Icon(icon),
        ),
      ),
    );
    Widget label(String text, {VoidCallback? onPressed}) => Expanded(
      child: Tooltip(
        message: text,
        child: onPressed == null
            ? Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              )
            : TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: labelPadding),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onPressed,
                child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 3つの欄は同じ幅。ボタンの文字は左右の余白の内側に入る。
                final cell = constraints.maxWidth / 3 - labelPadding * 2;
                if (labelFits(context, selectAll, cell) &&
                    labelFits(context, deselectAll, cell)) {
                  return Row(
                    children: [
                      label(selectAll, onPressed: _selectAllInCurrentFolder),
                      label(deselectAll, onPressed: _exitSelection),
                      label(count),
                    ],
                  );
                }
                final third = constraints.maxWidth / 3;
                final iconWidth = third < 48 ? third : 48.0;
                return Row(
                  children: [
                    iconLabel(
                      Icons.select_all,
                      selectAll,
                      _selectAllInCurrentFolder,
                      iconWidth,
                    ),
                    iconLabel(
                      Icons.deselect,
                      deselectAll,
                      _exitSelection,
                      iconWidth,
                    ),
                    // アイコンのときは残りの幅の中央ではなく、アイコンの
                    // すぐ右に並べる（中央だと広い画面で離れて浮く）。
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Tooltip(
                          message: count,
                          child: Text(
                            count,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.content_cut),
              onPressed: _cutSelected,
              tooltip: l10n.commonCut,
            ),
            // フォルダは中身（フォルダ・作品）ごと複製する。
            IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: _copySelected,
              tooltip: l10n.commonCopy,
            ),
            IconButton(
              icon: Icon(
                Icons.delete,
                color: ThemeService.activeColorScheme.error,
              ),
              onPressed: _deleteSelected,
              tooltip: l10n.homeMoveToTrash,
            ),
          ],
        ],
      ),
    );
  }

  void _exitSelection() => setState(() {
    _selectedIds.clear();
    _isSelectionMode = false;
  });

  void _deleteSelected() {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final projectIds = service.projects.map((p) => p.id).toSet();
    final targetIds = _selectedIds.where(projectIds.contains).toList();
    // フォルダは中身（下の階層のフォルダ・作品）ごとゴミ箱へ移す。
    final folderIds = [
      for (final f in service.folders)
        if (_selectedIds.contains(f.id)) f.id,
    ];
    Set<String> inside() => {
      for (final id in folderIds) ...service.folderSubtreeIds(id),
    };
    // お気に入りは、選んだ作品でもフォルダの中の作品でも、保護を外すまで
    // ゴミ箱へ移さない。
    bool includesFavorite() {
      final folders = inside();
      return service.projects.any(
        (p) =>
            p.isFavorite &&
            (targetIds.contains(p.id) ||
                (!p.isSharedImport && folders.contains(p.folderId))),
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    if (includesFavorite()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
        );
      return;
    }
    if (targetIds.isEmpty && folderIds.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.homeMoveToTrashNothing)));
      return;
    }
    // まだ移していないもの（途中で失敗したとき、残りだけを出してやり直す）。
    List<String> pendingFolders() => [
      for (final f in service.folders)
        if (folderIds.contains(f.id)) f.name,
    ];
    List<String> pendingProjects() => [
      for (final p in service.projects)
        if (targetIds.contains(p.id)) p.name,
    ];
    final movedFolders = <String>[];
    final movedProjects = <String>[];
    // 件数の文と、フォルダの中身も一緒に移ることの文（中身はまだ移していない
    // フォルダの分だけ）。
    String message() {
      final left = [
        for (final id in folderIds)
          if (!movedFolders.contains(id)) id,
      ];
      final inside = {for (final id in left) ...service.folderSubtreeIds(id)};
      final folders = inside.difference(left.toSet()).length;
      final projects = service.projects
          .where(
            (p) =>
                !p.isSharedImport &&
                inside.contains(p.folderId) &&
                !targetIds.contains(p.id),
          )
          .length;
      return [
        l10n.homeMoveToTrashConfirm(
          pendingFolders().length + pendingProjects().length,
        ),
        if (projects + folders > 0)
          l10n.homeMoveToTrashFolderContents(
            l10n.homeFolderContents(projects, folders),
          ),
      ].join('\n');
    }

    showDialog(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: message(),
        confirmLabel: l10n.commonMove,
        itemNames: const [],
        pendingMessage: message,
        pendingItemNames: () => [...pendingFolders(), ...pendingProjects()],
        onApply: () async {
          // Validate the whole current selection before moving the first item.
          // The service also enforces protection when each queued write runs.
          if (includesFavorite()) throw const FavoriteProjectDeleteException();
          // フォルダを先に移す（選んだ作品がそのフォルダの中なら、フォルダと
          // 一緒にゴミ箱へ入り、フォルダごと戻せる）。
          for (final id in folderIds) {
            if (movedFolders.contains(id)) continue;
            if (await service.moveFolderToTrash(id) != null) {
              movedFolders.add(id);
            }
          }
          for (final id in targetIds) {
            if (!service.projects.any((p) => p.id == id)) continue;
            await service.deleteProject(id);
            movedProjects.add(id);
            if (mounted) {
              setState(() {
                _selectedIds.remove(id);
                _isSelectionMode = _selectedIds.isNotEmpty;
              });
            }
          }
        },
      ),
    ).then((_) {
      if (movedFolders.isEmpty && movedProjects.isEmpty) return;
      if (mounted) _exitSelection();
      showMovedToTrashSnackBar(
        messenger,
        l10n,
        service,
        movedProjects,
        folderIds: movedFolders,
      );
    });
  }

  /// 現在開いているフォルダ直下のプロジェクト・フォルダを両方選択する
  /// （選択モードでなければ自動的に選択モードへ入る）。手動の「全選択」
  /// ボタンとCtrl+Aショートカットの両方から使う共通処理。
  /// 一覧に見えている項目をすべて選ぶ（検索・お気に入りの絞り込みで
  /// 隠れている作品は選ばない）。
  void _selectAllInCurrentFolder() {
    final service = context.read<ProjectService>();
    final visible = ProjectListWidget.visibleEntryIds(
      // 一覧と同じく、「共有」から取り込んだ作品は含めない（含めていたため、
      // 全選択→削除で見えていない共有の作品までゴミ箱へ移っていた）。
      projects: service.projects.where((p) => !p.isSharedImport).toList(),
      folders: service.folders,
      currentFolderId: _currentFolderId,
      searchQuery: _isSearching ? _searchQuery : '',
      searchByTag: _searchByTag,
      showFavoritesOnly: _showFavoritesOnly,
    );
    if (visible.isEmpty) return;
    setState(() {
      _isSelectionMode = true;
      _selectedIds.addAll(visible);
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
    // 全選択・コピー等はプロジェクトの一覧の操作なので、他のタブと検索中は
    // 効かせない。
    if (_currentTabIndex != 0 || _isSearching) return result;
    // Escは引き出しが開いていれば引き出しを閉じ、次に選択を終え、
    // 選択していなければ切り取りをやめる（検索欄のEscは欄の側で検索を
    // 閉じる）。
    if (_isSelectionMode || (_clipboardIsCut && _hasClipboard)) {
      result[const SingleActivator(LogicalKeyboardKey.escape)] = () {
        if (_closeLocalHistory()) return;
        if (_isSelectionMode) {
          _exitSelection();
        } else {
          _cancelCut();
        }
      };
    }
    for (final b in bindings) {
      if (b.isToolAction) continue;
      switch (b.command) {
        case ShortcutCommand.selectAll:
          result[b.activator] = _selectAllInCurrentFolder;
        case ShortcutCommand.copy:
          result[b.activator] = () {
            if (_selectedIds.isEmpty) return;
            _copySelected();
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
  /// 貼り付け時は[moveToFolder]/[moveFolderTo]で移動し、貼り付けた分は
  /// クリップボードから外す。切り取った項目は貼り付けるまで薄く表示する。
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
    _showClipboardHint(cut: true);
  }

  /// 切り取りをやめ、薄く表示していた項目を元に戻す。
  void _cancelCut() => setState(() {
    _clipboardProjectIds.clear();
    _clipboardFolderIds.clear();
    _clipboardIsCut = false;
  });

  /// 選択中のプロジェクト・フォルダを内部クリップボードへコピーする。
  /// フォルダは貼り付けるときに中身（フォルダ・作品）ごと複製する。貼り付けの
  /// たびに複製するため、クリップボードは貼り付け後も保持したままにする。
  void _copySelected() {
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
      _clipboardIsCut = false;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    _showClipboardHint(cut: false);
  }

  // 切り取り・コピーしたことと、次にどこを押せばよいかを伝える（以前は
  // 選択が消えるだけで、何が起きたか・どう貼り付けるかが分からなかった）。
  void _showClipboardHint({required bool cut}) {
    final l10n = AppLocalizations.of(context)!;
    final count = _clipboardProjectIds.length + _clipboardFolderIds.length;
    if (count == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            cut ? l10n.homeCutSnackbar(count) : l10n.homeCopiedSnackbar(count),
          ),
          // 切り取りはその場でやめられる（薄く表示したまま残ると、
          // 使えなくなったように見えた）。Escでもやめられる。
          persist: false,
          duration: const Duration(seconds: 6),
          action: cut
              ? SnackBarAction(
                  label: l10n.homeUndoAction,
                  onPressed: () {
                    if (mounted && _clipboardIsCut) _cancelCut();
                  },
                )
              : null,
        ),
      );
  }

  bool get _hasClipboard =>
      _clipboardProjectIds.isNotEmpty || _clipboardFolderIds.isNotEmpty;

  bool _pasting = false;

  /// クリップボードの内容を現在開いているフォルダ（[_currentFolderId]、
  /// nullはルート直下）へ貼り付ける。切り取りの場合は移動し、移せたものを
  /// クリップボードから外す。コピーの場合は複製し、クリップボードは
  /// 保持したままにする。貼り付けられなかったもの（フォルダを自分自身や
  /// その中へ移す・元の作品がゴミ箱や削除で無くなった）は理由を伝える
  /// （以前は何も起きなくても「貼り付けました」と出し、切り取ったフォルダは
  /// クリップボードから消えていた）。
  Future<void> _pasteClipboard() async {
    // 押し続け・連打で同じ貼り付けを重ねない（貼り付け中はボタンも押せない）。
    if (_pasting) return;
    setState(() => _pasting = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ProjectService>();
    final target = _currentFolderId;
    final isCut = _clipboardIsCut;
    final liveProjects = {for (final p in service.projects) p.id: p};
    final liveFolders = {for (final f in service.folders) f.id};
    var pasted = 0;
    var missing = 0;
    var intoSelf = 0;
    final moved = <String>{};
    Object? failure;
    try {
      for (final id in _clipboardProjectIds.toList()) {
        final project = liveProjects[id];
        if (project == null) {
          missing++;
          moved.add(id);
          continue;
        }
        if (isCut) {
          await service.moveToFolder(id, target);
          moved.add(id);
          pasted++;
        } else if (await service.duplicateProject(
          id,
          targetFolderId: target,
          useTargetFolder: true,
          name: duplicateProjectName(
            l10n,
            project.name,
            folderId: target,
            projects: service.projects,
          ),
        )) {
          pasted++;
        } else {
          missing++;
        }
      }
      for (final id in _clipboardFolderIds.toList()) {
        if (!liveFolders.contains(id)) {
          missing++;
          moved.add(id);
          continue;
        }
        if (isCut) {
          if (target != null && service.isFolderDescendantOf(target, id)) {
            intoSelf++;
            continue;
          }
          await service.moveFolderTo(id, target);
          moved.add(id);
          pasted++;
          continue;
        }
        final folder = service.folders.firstWhere((f) => f.id == id);
        final copy = await service.duplicateFolder(
          id,
          targetParentId: target,
          name: duplicateFolderName(
            l10n,
            folder.name,
            parentId: target,
            folders: service.folders,
          ),
        );
        if (copy == null) {
          missing++;
        } else {
          pasted++;
        }
      }
    } catch (error, stack) {
      // 途中で失敗しても、移せた分はクリップボードから外して結果を伝える。
      AppErrorReporter.record(error, stack);
      failure = error;
    }
    if (!mounted) return;
    setState(() {
      _pasting = false;
      if (isCut) {
        _clipboardProjectIds.removeAll(moved);
        _clipboardFolderIds.removeAll(moved);
      } else {
        _clipboardProjectIds.removeWhere((id) => !liveProjects.containsKey(id));
        _clipboardFolderIds.removeWhere((id) => !liveFolders.contains(id));
      }
    });
    final lines = [
      if (pasted > 0) l10n.homePastedSnackbar(pasted),
      if (intoSelf > 0) l10n.homePasteSkippedIntoSelf(intoSelf),
      if (missing > 0) l10n.homePasteSkippedMissing(missing),
      // フォルダの保存の失敗はフォルダの文言、作品の複製などの失敗は貼り付けの文言。
      if (failure != null)
        failure is FolderSaveException
            ? folderSaveFailureText(l10n, failure)
            : l10n.homePasteFailed,
    ];
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(lines.join('\n'))));
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
        key: const Key('homeBreadcrumb'),
        scrollDirection: Axis.horizontal,
        // 深い階層でも今いるフォルダ（右端）が見えるよう、右端から並べる。
        reverse: true,
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.projectListFolderRootOption,
              onPressed: () => setState(() => _currentFolderId = null),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              visualDensity: VisualDensity.standard,
              icon: const Icon(Icons.home, size: 18),
            ),
            for (final folder in chain) ...[
              const Icon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: () => setState(() => _currentFolderId = folder.id),
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

/// ホームのタブの高さ（指で押しやすい48px）。
const double _homeTabBarHeight = 48;

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
    // 選ばれたタブの下線は差し色、名前はテーマの「アクセントの文字・
    // アイコン色」（未指定なら差し色。ユーザー指定で、読みやすさのために
    // 黒や白へ自動で差し替えない）。下地とほとんど同じ色のときだけ、
    // テーマの色から作った縁取りを付ける。
    final background = opaqueOver(
      Theme.of(context).appBarTheme.backgroundColor ?? scheme.surface,
      opaqueOver(Theme.of(context).scaffoldBackgroundColor, Colors.black),
    );
    final menuScheme = scheme.copyWith(
      surface: background,
      onSurface:
          Theme.of(context).appBarTheme.foregroundColor ?? scheme.onSurface,
    );
    final selectedColor = scheme.primary;
    final selectedTextColor = AccentTextTheme.of(context);
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

    final localizations = MaterialLocalizations.of(context);

    // 標準のTabBarと同じく、選ばれているか・何番目のタブかを読み上げる。
    Widget tabItem(int i) => Semantics(
      key: ValueKey('home_tab_$i'),
      selected: currentIndex == i,
      button: true,
      inMutuallyExclusiveGroup: true,
      hint: localizations.tabLabel(tabIndex: i + 1, tabCount: labels.length),
      child: InkWell(
        onTap: () => controller.animateTo(i),
        child: Container(
          height: _homeTabBarHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: currentIndex == i ? selectedColor : Colors.transparent,
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
        // Keep the screen name independent of translated sorting controls.
        title: Text(l10n.homeTabShared),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        // Keep the screen name independent of translated sorting controls.
        title: Text(l10n.homeTabTrash),
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
  // 名前は1件につき1回だけそろえる。
  final keys = <String, NameSortKey>{};
  NameSortKey key(Project p) => keys[p.id] ??= NameSortKey(p.name);
  switch (mode) {
    case ProjectSortMode.nameAsc:
      list.sort((a, b) => compareNameKeys(key(a), key(b)));
    case ProjectSortMode.nameDesc:
      list.sort((a, b) => compareNameKeys(key(b), key(a)));
    case ProjectSortMode.updatedAsc:
      list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    case ProjectSortMode.updatedDesc:
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return list;
}

/// ゴミ箱のフォルダの並び。名前順は作品と同じ比べ方、日時順はゴミ箱へ
/// 移した日時。
List<TrashedFolder> _sortTrashedFolders(
  List<TrashedFolder> folders,
  ProjectSortMode mode,
) {
  final list = List<TrashedFolder>.from(folders);
  final keys = <String, NameSortKey>{};
  NameSortKey key(TrashedFolder t) =>
      keys[t.folder.id] ??= NameSortKey(t.folder.name);
  switch (mode) {
    case ProjectSortMode.nameAsc:
      list.sort((a, b) => compareNameKeys(key(a), key(b)));
    case ProjectSortMode.nameDesc:
      list.sort((a, b) => compareNameKeys(key(b), key(a)));
    case ProjectSortMode.updatedAsc:
      list.sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
    case ProjectSortMode.updatedDesc:
      list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
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

  const _FolderableList({
    required this.allItems,
    required this.folders,
    required this.folderIdOf,
    required this.onEnterFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.itemBuilder,
    this.emptyState,
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
                  bottom: 88 + MediaQuery.paddingOf(context).bottom,
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
            bottom:
                (constraints.maxHeight - 60).clamp(0.0, 88.0).toDouble() +
                MediaQuery.paddingOf(context).bottom,
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

  static String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  State<_TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<_TrashTab> {
  // 戻している・消している最中の作品・フォルダ（二重に押させない）。
  final _pending = <String>{};
  final _restoring = <String>{};

  Future<void> _run(
    String id,
    Future<void> Function() action, {
    bool restoring = false,
  }) async {
    if (_pending.contains(id)) return;
    setState(() {
      _pending.add(id);
      if (restoring) _restoring.add(id);
    });
    try {
      await runProjectTrashAction(context, action);
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
    final service = context.watch<ProjectService>();
    // フォルダと一緒に移した作品はフォルダの中に出し、1件ずつは出さない
    // （フォルダごとまとめて戻す・消す）。
    final folders = _sortTrashedFolders(
      service.trashedFolders,
      widget.sortMode,
    );
    final trash = _sortProjects(service.looseTrash, widget.sortMode);
    final l10n = AppLocalizations.of(context)!;
    if (trash.isEmpty && folders.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.delete_outline,
        title: l10n.homeTrashEmpty,
      );
    }
    return ListView.builder(
      itemCount: folders.length + trash.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final record = folders[index];
          final id = record.folder.id;
          return _TrashedFolderCard(
            record: record,
            pending: _pending.contains(id),
            restoring: _restoring.contains(id),
            onRestore: () => _run(
              id,
              () => service.restoreTrashedFolder(id),
              restoring: true,
            ),
            onDelete: (dialog) => _run(id, dialog),
          );
        }
        final project = trash[index - folders.length];
        final deletedAt = service.deletedAtOf(project.id);
        final deletedLabel = deletedAt == null
            ? ''
            : l10n.homeTrashDeletedOn(_TrashTab._date(deletedAt));
        final meta = l10n.homeProjectMeta(project.fps, project.durationSeconds);
        return _TrashCard(
          actions: _TrashActions(
            restoreKey: ValueKey('trashedProjectRestore_${project.id}'),
            deleteKey: ValueKey('trashedProjectDelete_${project.id}'),
            pending: _pending.contains(project.id),
            restoring: _restoring.contains(project.id),
            onRestore: () => _run(
              project.id,
              () => service.restoreProject(project.id),
              restoring: true,
            ),
            onDelete: () => _confirmPermanentDelete(project),
          ),
          details: ({Widget? trailing}) => ListTile(
            // ボタンを名前の右に並べるときは、作品とフォルダのカードで同じく
            // 上下の真ん中に置く。
            titleAlignment: ListTileTitleAlignment.center,
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
              deletedLabel.isEmpty ? meta : '$deletedLabel · $meta',
            ),
            trailing: trailing,
          ),
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

/// ゴミ箱のカード。「復元」「完全削除」は、狭い画面・大きな文字では名前の
/// 下の右端に別の行で、広い画面では名前の右に並べる。作品とフォルダの
/// どちらのカードも同じ決まりで置く（置き場所が違うと、並べたときに
/// ずれて見えた。名前の右に詰めると、狭い画面では名前と日付を押しつぶした）。
class _TrashCard extends StatelessWidget {
  const _TrashCard({super.key, required this.details, required this.actions});

  /// 名前と日付の行（広い画面ではボタンを[trailing]に受け取る）。
  final Widget Function({Widget? trailing}) details;
  final _TrashActions actions;

  /// この幅（文字の大きさに合わせて広げる）より狭いと、ボタンを別の行にする。
  static const double _wideWidth = 600;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth <
          _wideWidth * MediaQuery.textScalerOf(context).scale(1);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 1,
        shadowColor: ThemeService.activeColorScheme.shadow.withValues(
          alpha: 0.15,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      children: actions.buttons(context),
                    ),
                  ),
                ],
              )
            : details(
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions.buttons(context),
                ),
              ),
      );
    },
  );
}

/// ゴミ箱のカードの「復元」「完全削除」（押しやすい48px以上）。処理中は
/// どちらも押せず、戻している間は「復元」が処理中の表示になる。
class _TrashActions {
  final Key restoreKey;
  final Key deleteKey;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final bool pending;
  final bool restoring;

  const _TrashActions({
    required this.restoreKey,
    required this.deleteKey,
    required this.onRestore,
    required this.onDelete,
    this.pending = false,
    this.restoring = false,
  });

  List<Widget> buttons(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      TextButton(
        key: restoreKey,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          visualDensity: VisualDensity.standard,
        ),
        onPressed: pending ? null : onRestore,
        child: Text(restoring ? l10n.homeTrashWorking : l10n.commonRestore),
      ),
      TextButton(
        key: deleteKey,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          visualDensity: VisualDensity.standard,
          // 背景の上の差し色の文字（案A）。
          foregroundColor: AccentTextTheme.of(context),
        ),
        onPressed: pending ? null : onDelete,
        child: Text(l10n.homePermanentDelete),
      ),
    ];
  }
}

/// ゴミ箱のフォルダ（中身ごと）。中の作品の名前を並べ、フォルダごと戻す・
/// 完全に削除する。
class _TrashedFolderCard extends StatelessWidget {
  final TrashedFolder record;
  final bool pending;
  final bool restoring;
  final VoidCallback onRestore;

  /// 完全に削除する確認を、処理中の表示を出したまま開く。
  final void Function(Future<void> Function() dialog) onDelete;

  const _TrashedFolderCard({
    required this.record,
    required this.onRestore,
    required this.onDelete,
    this.pending = false,
    this.restoring = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final folder = record.folder;
    final inTrash = {for (final p in service.trash) p.id: p};
    final projects = [for (final id in record.projectIds) ?inTrash[id]];
    final contents = l10n.homeFolderContents(
      projects.length,
      record.subfolders.length,
    );
    final scheme = Theme.of(context).colorScheme;
    return _TrashCard(
      key: ValueKey('trashedFolder_${folder.id}'),
      actions: _TrashActions(
        restoreKey: ValueKey('trashedFolderRestore_${folder.id}'),
        deleteKey: ValueKey('trashedFolderDelete_${folder.id}'),
        pending: pending,
        restoring: restoring,
        onRestore: onRestore,
        onDelete: () => onDelete(
          () => _confirmPermanentDelete(
            context,
            service,
            projects.length,
            record.subfolders.length,
          ),
        ),
      ),
      details: ({Widget? trailing}) => ListTile(
        titleAlignment: ListTileTitleAlignment.center,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.folder,
            size: 40,
            // ホームの一覧と同じ色（フォルダの既定色は差し色の塗り）。
            color: folder.color != null ? Color(folder.color!) : scheme.primary,
          ),
        ),
        title: Text(
          folder.name,
          style: const TextStyle(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
          ),
        ),
        // 中の作品の名前は日付・件数の下に（2行まで）。
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${l10n.homeTrashDeletedOn(_TrashTab._date(record.deletedAt))}'
              ' · $contents',
            ),
            if (projects.isNotEmpty)
              Text(
                projects.map((p) => p.name).join('、'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        isThreeLine: projects.isNotEmpty,
        trailing: trailing,
      ),
    );
  }

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    ProjectService service,
    int projects,
    int folders,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<bool>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homePermanentDeleteConfirmTitle,
        message: [
          l10n.homeTrashFolderPermanentDeleteBody(record.folder.name),
          if (projects + folders > 0)
            l10n.homeTrashFolderPermanentDeleteContents(
              l10n.homeFolderContents(projects, folders),
            ),
        ].join('\n'),
        confirmLabel: l10n.commonDelete,
        itemNames: [record.folder.name],
        onApply: () => service.permanentDeleteTrashedFolder(record.folder.id),
      ),
    );
  }
}

/// 閲覧フィルターとブックマーク日時順を反映する公開作品一覧。
class _BookmarkedTab extends StatelessWidget {
  const _BookmarkedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = opaqueOver(theme.scaffoldBackgroundColor, Colors.black);
    // 作品一覧の空の表示（EmptyStatePlaceholder）と同じテーマの色（ユーザー
    // 指定。差し色を読みやすさのために黒や白へ自動で差し替えない）。ボタンは
    // テーマの既定（差し色）のまま。
    final foreground = scheme.primary;
    final textForeground = scheme.onSurface;
    final bodyForeground = scheme.onSurfaceVariant;
    final service = context.watch<CommunityService>();
    final works = service.bookmarkedWorksForViewer;
    final canReload =
        service.isBackendConnected && service.currentUserId != null;
    final loading = canReload && service.isSocialLoading;
    final error = canReload ? service.socialError : null;
    final needsLoad = canReload && !service.hasLoadedSocial && error == null;
    final hidden = service.bookmarkedIds.isNotEmpty;
    final title = loading
        ? l10n.homeBookmarkedLoading
        : error != null
        ? l10n.homeBookmarkedLoadFailed
        : needsLoad
        ? l10n.homeBookmarkedLoadPrompt
        : hidden
        ? l10n.homeBookmarkedHiddenTitle
        : l10n.homeBookmarkedEmptyTitle;
    final String? body = loading || needsLoad
        ? null
        : error != null
        ? communityErrorText(l10n, error)
        : hidden
        ? l10n.homeBookmarkedHiddenBody
        : service.isBackendConnected && service.currentUserId == null
        ? l10n.homeBookmarkedSignInBody
        : l10n.homeBookmarkedEmptyBody;

    Future<void> reload() async {
      await service.loadSocial();
    }

    final scroll = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: canReload ? const AlwaysScrollableScrollPhysics() : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Padding(
            padding: works.isEmpty
                ? const EdgeInsets.all(24)
                : EdgeInsets.only(bottom: _fabClearance(context)),
            child: Column(
              mainAxisAlignment: works.isEmpty
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (works.isEmpty) ...[
                  if (loading)
                    CircularProgressIndicator(color: foreground)
                  else
                    // 作品一覧・プロジェクトの空の表示（EmptyStatePlaceholder）と
                    // 同じ形と色：差し色の淡い円に、アクセントの文字・アイコン色の
                    // アイコン（ユーザー指定）。
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        error != null
                            ? Icons.cloud_off_outlined
                            : Icons.bookmark_border,
                        size: 40,
                        color: AccentTextTheme.of(context),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      // 文字の大きさも他の空の表示（EmptyStatePlaceholder）と
                      // そろえる（18だと390px幅で最後の1字だけ次の行へ落ちた）。
                      style: TextStyle(
                        color: textForeground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: bodyForeground),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (canReload && !loading)
                        OutlinedButton.icon(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            error != null
                                ? l10n.communityRetry
                                : l10n.communityReloadTooltip,
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/community'),
                        icon: const Icon(Icons.explore_outlined),
                        label: Text(l10n.communityScreenTitle),
                      ),
                    ],
                  ),
                ] else ...[
                  if (loading)
                    LinearProgressIndicator(
                      color: foreground,
                      backgroundColor: Color.alphaBlend(
                        foreground.withValues(alpha: 0.15),
                        background,
                      ),
                      semanticsLabel: l10n.homeBookmarkedLoading,
                    ),
                  if (canReload)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (error != null)
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  l10n.homeBookmarkedLoadFailed,
                                  style: TextStyle(color: textForeground),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          IconButton(
                            onPressed: loading ? null : reload,
                            tooltip: error != null
                                ? l10n.communityRetry
                                : l10n.communityReloadTooltip,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  CommunityWorkGrid(
                    works: works,
                    bookmarkedIds: service.bookmarkedIds,
                    onTapWork: (work) =>
                        context.read<CommunityPreviewService>().show(work),
                    onToggleBookmark: (work) => reportFailedCommunityEdit(
                      context,
                      service,
                      service.toggleBookmark(work.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return canReload
        ? RefreshIndicator(onRefresh: reload, child: scroll)
        : scroll;
  }
}

/// 「作品一覧」タブ：書き出し済みの動画・GIF
/// ファイルをアプリ内保存先（ExportEngine.exportsDir、
/// getApplicationDocumentsDirectory()/exports）から一覧表示する。
/// タップでアプリ内プレビュー、共有ボタンでOSの共有シートから写真アプリ等へ
/// 「開く」ことができる（share_plusは書き出し完了ダイアログで既に使用している
/// 実績のある仕組みのため、新規ネイティブ依存を追加せずに実現できる）。
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
            itemBuilder: (context, file) =>
                _WorkListItem(file: file, onDeleted: _reload),
          ),
        );
      },
    );
  }
}

class _ProjectsLoadFailureNotice extends StatelessWidget {
  const _ProjectsLoadFailureNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('homeProjectsLoadFailed'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            children: [
              Icon(Icons.folder_off_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.homeProjectsLoadFailed)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.communityRetry),
              ),
            ],
          ),
        ),
      ),
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
    final l10n = AppLocalizations.of(context)!;
    return ExportedWorkCard(
      name: file.path.split(RegExp(r'[\\/]')).last,
      metadata: '${_formatDate(stat.modified)} ・ ${_formatSize(stat.size)}',
      icon: _icon,
      moveLabel: l10n.folderMoveToTitle,
      shareLabel: l10n.homeShareOpenWith,
      deleteLabel: l10n.commonDelete,
      onOpen: () => _openPreview(context),
      onMove: () => _showMoveToFolderSheet(context),
      onShare: () =>
          SharePlus.instance.share(ShareParams(files: [XFile(file.path)])),
      onDelete: () => _confirmDelete(context),
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
/// で既に実績のある仕組み）、GIFはFlutter標準のImage/FileImage（アニメーション
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
  FileImage? _gifProvider;
  ImageStream? _gifStream;
  ImageStreamListener? _gifListener;
  double? _gifAspectRatio;
  bool _gifDimensionsResolved = false;

  @override
  void initState() {
    super.initState();
    _isGif = widget.file.path.toLowerCase().endsWith('.gif');
    if (_isGif) {
      _gifProvider = FileImage(widget.file);
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
    if (!_isGif || _gifDimensionsResolved || _gifListener != null) return;
    // Share the Image widget's cached stream and release our first-frame clone.
    _gifStream = _gifProvider!.resolve(createLocalImageConfiguration(context));
    _gifListener = ImageStreamListener(
      (info, synchronousCall) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        _gifDimensionsResolved = true;
        _stopGifSizeListener();
        if (!mounted) return;
        if (synchronousCall) {
          _gifAspectRatio = ratio;
        } else {
          setState(() => _gifAspectRatio = ratio);
        }
      },
      onError: (error, stackTrace) {
        _gifDimensionsResolved = true;
        _stopGifSizeListener();
      },
    );
    _gifStream!.addListener(_gifListener!);
  }

  void _stopGifSizeListener() {
    final stream = _gifStream;
    final listener = _gifListener;
    _gifStream = null;
    _gifListener = null;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  @override
  void dispose() {
    _stopGifSizeListener();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget content;
    if (_isGif) {
      content = Image(
        image: _gifProvider!,
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
      contentAspectRatio: _isGif
          ? _gifAspectRatio ?? 16 / 9
          : _controller?.value.isInitialized == true
          ? _controller!.value.aspectRatio
          : 16 / 9,
      shareLabel: l10n.homeShareOpenWith,
      closeLabel: l10n.commonClose,
      onShare: () => SharePlus.instance.share(
        ShareParams(files: [XFile(widget.file.path)]),
      ),
      onClose: () => Navigator.pop(context),
    );
  }
}

enum ProjectViewMode { large, medium, small, detail }

enum ProjectSortMode { nameAsc, nameDesc, updatedAsc, updatedDesc }
