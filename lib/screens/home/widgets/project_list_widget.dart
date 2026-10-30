import 'package:niarim/services/theme_service.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../engine/niapro_serializer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/material_asset.dart';
import '../../../models/project.dart';
import '../../../services/font_service.dart';
import '../../../services/material_service.dart';
import '../../../services/project_service.dart';
import '../home_screen.dart';
import '../../../config/accent_text_theme.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/duplicate_name.dart';
import '../../../utils/folder_tree.dart';
import '../../../utils/name_collation.dart';
import '../../../widgets/frame_preview_background.dart';
import '../../../widgets/checked_menu_item.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/moved_to_trash_snack_bar.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../utils/app_error_reporter.dart';
import '../../../utils/folder_persistence.dart';
import 'folder_save_feedback.dart';
import 'folder_delete_dialog.dart';
import 'work_folder_move_sheet.dart';
import 'project_folder_edit_dialog.dart';

/// 新規フォルダ作成ダイアログ（フォルダ名入力）。プロジェクト一覧画面の
/// ＋ボタン（新規プロジェクト/新規フォルダ選択）・フォルダ移動ピッカーの
/// 双方から共通で使う（重複実装を避けるためpublicなトップレベル関数として
/// 定義し、home_screen.dartからも呼び出せるようにしている）。
void showCreateFolderNameDialog(
  BuildContext context,
  Future<void> Function(String name) onCreate,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _FolderNameDialog(onSave: onCreate),
  );
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.onSave,
    this.initialName = '',
    this.rename = false,
  });
  final Future<void> Function(String name) onSave;
  final String initialName;
  final bool rename;
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;
  final _errorKey = GlobalKey();
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (_saving || name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(name);
      if (mounted) closeFolderRoute(context);
      // Keep submission disabled through the closing route animation.
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _errorKey.currentContext;
          if (mounted && target != null) Scrollable.ensureVisible(target);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final foreground =
        theme.popupMenuTheme.textStyle?.color ?? theme.colorScheme.onSurface;
    final heading =
        (theme.dialogTheme.titleTextStyle ?? theme.textTheme.headlineSmall)
            ?.copyWith(
              color: foreground,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            );
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                namesRoute: true,
                child: Text(
                  widget.rename
                      ? l10n.commonRename
                      : l10n.projectListNewFolderTitle,
                  style: heading,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                style: TextStyle(color: foreground),
                onChanged: (_) => setState(() {
                  _error = null;
                }),
                // Enterでも作成・変更する（空白だけの名前では何もしない）。
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.folderNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!widget.rename) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.projectListFolderHint,
                  style: TextStyle(fontSize: 11, color: foreground),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  key: _errorKey,
                  liveRegion: true,
                  child: Text(
                    widget.rename ||
                            (_error is FolderSaveException &&
                                (_error as FolderSaveException).partiallySaved)
                        ? folderSaveFailureText(l10n, _error!)
                        : l10n.folderCreateFailed,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      if (ModalRoute.of(context)?.isCurrent ?? false) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(l10n.commonCancel),
                  ),
                  FolderSaveButton(
                    onPressed: _controller.text.trim().isEmpty ? null : _submit,
                    label: widget.rename
                        ? l10n.commonChange
                        : l10n.commonCreate,
                    saving: _saving,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showRenameFolderNameDialog(
  BuildContext context,
  String name,
  Future<void> Function(String name) onRename,
) {
  showDialog<void>(
    context: context,
    builder: (_) =>
        _FolderNameDialog(onSave: onRename, initialName: name, rename: true),
  );
}

/// 一覧の表示サイズ（大・中・小・詳細）を選ぶメニュー。ボタンのアイコンが
/// 今の表示を表し、開くと今の表示にチェックが付いている（以前はどれを
/// 選んでいるか分からなかった）。ボタンを覆わないよう、下に開く。
class ProjectViewModeMenu extends StatelessWidget {
  const ProjectViewModeMenu({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProjectViewMode value;
  final ValueChanged<ProjectViewMode> onChanged;

  static IconData iconFor(ProjectViewMode mode) => switch (mode) {
    ProjectViewMode.large => Icons.grid_view,
    ProjectViewMode.medium => Icons.view_module,
    ProjectViewMode.small => Icons.apps,
    ProjectViewMode.detail => Icons.view_list,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String label(ProjectViewMode mode) => switch (mode) {
      ProjectViewMode.large => l10n.homeViewModeLarge,
      ProjectViewMode.medium => l10n.homeViewModeMedium,
      ProjectViewMode.small => l10n.homeViewModeSmall,
      ProjectViewMode.detail => l10n.homeViewModeDetail,
    };
    return PopupMenuButton<ProjectViewMode>(
      icon: Icon(iconFor(value)),
      tooltip: l10n.homeViewModeTooltip,
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final mode in ProjectViewMode.values)
          checkedMenuItem(
            context,
            value: mode,
            checked: mode == value,
            icon: iconFor(mode),
            label: label(mode),
          ),
      ],
    );
  }
}

/// 表示サイズごとの列数（[ProjectListWidget.gridColumnsFor]）で並べ、
/// ふだんの絵の比率を保ちつつ、名前の帯と右上の操作が入る高さを下回らない
/// ようにする（文字を大きくした小さなカードで帯が絵を押しつぶさない）。
class _ProjectGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const _ProjectGridDelegate({
    required super.crossAxisCount,
    required this.minHeight,
  }) : super(
         crossAxisSpacing: 8,
         mainAxisSpacing: 8,
         childAspectRatio: 16 / 12,
       );
  final double minHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usual = super.getLayout(constraints) as SliverGridRegularTileLayout;
    if (usual.childMainAxisExtent >= minHeight) return usual;
    return SliverGridRegularTileLayout(
      crossAxisCount: usual.crossAxisCount,
      mainAxisStride: minHeight + mainAxisSpacing,
      crossAxisStride: usual.crossAxisStride,
      childMainAxisExtent: minHeight,
      childCrossAxisExtent: usual.childCrossAxisExtent,
      reverseCrossAxis: usual.reverseCrossAxis,
    );
  }

  @override
  bool shouldRelayout(covariant _ProjectGridDelegate oldDelegate) =>
      minHeight != oldDelegate.minHeight || super.shouldRelayout(oldDelegate);
}

/// フォルダ・プロジェクトを同一一覧内で扱うための表示用ラッパー
/// （フォルダとプロジェクトを同一一覧内で並び替え可能にする）。
class _Entry {
  final ProjectFolder? folder;
  final Project? project;
  // フォルダの「更新日時」：作成日時と、中（下の階層を含む）の作品の
  // 最後の更新のうち新しい方。
  final DateTime? _folderDate;
  const _Entry.folder(ProjectFolder f, DateTime date)
    : folder = f,
      project = null,
      _folderDate = date;
  const _Entry.project(Project p)
    : project = p,
      folder = null,
      _folderDate = null;

  bool get isFolder => folder != null;
  String get id => isFolder ? folder!.id : project!.id;
  String get name => isFolder ? folder!.name : project!.name;
  DateTime get sortDate => isFolder ? _folderDate! : project!.updatedAt;
  bool get isFavorite => isFolder ? folder!.isFavorite : project!.isFavorite;
}

class ProjectListWidget extends StatelessWidget {
  final ProjectViewMode viewMode;
  final ProjectSortMode sortMode;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  // 長押しされた項目（プロジェクトまたはフォルダ）のIDを渡す。呼び出し側で
  // 複数選択モードへ入ると同時にその項目を選択状態にできるようにするため。
  final ValueChanged<String> onLongPress;
  final ValueChanged<String> onSelectionChanged;
  final List<Project>? projects; // nullの場合はServiceから取得
  final bool showFavoritesOnly;
  final String searchQuery;
  // When true, searchQuery is matched against project tags instead of names.
  // Folders intentionally do not participate because they have no tags.
  final bool searchByTag;
  // 現在開いているフォルダ（nullはルート直下、フォルダ階層）
  final String? currentFolderId;
  final ValueChanged<String> onOpenFolder;
  // 非nullの場合、作品タップ時の動作が「詳細画面（'/project/:id'）へ遷移」
  // ではなく「選んだ作品IDをこのコールバックへ渡すだけ」に変わる
  // （ホーム画面ウィジェットの作品選択フロー等、一覧を「選ぶ専用画面」として
  // 使う場合に指定する）。[isSelectionMode]（複数選択・チェックボックス表示）
  // とは独立していて、サムネイルは常に通常表示のまま
  // （チェックボックスには置き換わらない）。フォルダへ潜る操作は通常どおり
  // [onOpenFolder]を使うため、このコールバックが呼ばれるのは作品を
  // タップした時のみ。指定時はダブルタップでのキャンバス直接起動・
  // 三点メニュー（リネーム／削除等の編集操作）も無効化する。
  final ValueChanged<String>? onPickProject;
  // 一覧が空のときの「＋ ボタンから新規作成」ヒント文言の表示可否。
  // 選ぶ専用画面（[onPickProject]使用時）には＋ボタンが無いため、
  // 存在しないボタンを指す文言を隠せるようにする。
  final bool showEmptyCreateHint;
  // 検索・お気に入りの絞り込みで何も出ないときの「検索をやめる」
  // 「すべて表示」ボタン。nullならボタンを出さない。
  final VoidCallback? onClearSearch;
  final VoidCallback? onShowAll;
  // 切り取って貼り付け待ちの項目。薄く表示して、どれを移すところか分かる
  // ようにする。
  final Set<String> pendingCutIds;
  // 一覧の下端に足す余白。画面下に浮くボタン（ホームのFAB）が最後の行の
  // 名前やメニューを隠さないよう、一番下までスクロールしたときにその上へ
  // 出せるようにする。
  final double bottomPadding;
  final ScrollController? scrollController;

  /// Optional controls that scroll away with the project list rather than
  /// remaining pinned above its viewport.
  final Widget? header;

  const ProjectListWidget({
    super.key,
    required this.viewMode,
    required this.sortMode,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.currentFolderId,
    required this.onOpenFolder,
    this.projects,
    this.showFavoritesOnly = false,
    this.searchQuery = '',
    this.searchByTag = false,
    this.onPickProject,
    this.showEmptyCreateHint = true,
    this.onClearSearch,
    this.onShowAll,
    this.pendingCutIds = const {},
    this.bottomPadding = 0,
    this.scrollController,
    this.header,
  });

  /// フォルダを作品より前にまとめ、それぞれの中を[sortMode]で並べる。
  /// 名前は人が読む順（数字は数として、大文字・小文字や全角・半角、
  /// カタカナ・ひらがなの違いは区別しない）。
  List<_Entry> _sorted(List<_Entry> src) {
    // 名前は1件につき1回だけそろえる。
    final keys = Map<_Entry, NameSortKey>.identity();
    NameSortKey key(_Entry e) => keys[e] ??= NameSortKey(e.name);
    int byMode(_Entry a, _Entry b) => switch (sortMode) {
      ProjectSortMode.nameAsc => compareNameKeys(key(a), key(b)),
      ProjectSortMode.nameDesc => compareNameKeys(key(b), key(a)),
      ProjectSortMode.updatedAsc => a.sortDate.compareTo(b.sortDate),
      ProjectSortMode.updatedDesc => b.sortDate.compareTo(a.sortDate),
    };
    return List<_Entry>.from(src)..sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      final order = byMode(a, b);
      if (order != 0) return order;
      // 同名・同時刻は、もう一方の基準で決める（並びが毎回変わらないように）。
      return sortMode == ProjectSortMode.nameAsc ||
              sortMode == ProjectSortMode.nameDesc
          ? b.sortDate.compareTo(a.sortDate)
          : compareNameKeys(key(a), key(b));
    });
  }

  /// 一覧に実際に出ている項目のID（検索・お気に入りの絞り込み後）。
  /// 全選択はこれと同じ範囲だけを選ぶ（検索で隠れている作品まで選ばれ、
  /// そのまま削除すると見えていない作品までゴミ箱へ移っていた）。
  static Set<String> visibleEntryIds({
    required List<Project> projects,
    required List<ProjectFolder> folders,
    required String? currentFolderId,
    required String searchQuery,
    required bool searchByTag,
    required bool showFavoritesOnly,
  }) => {
    for (final e in _visibleEntries(
      projects: projects,
      folders: folders,
      currentFolderId: currentFolderId,
      searchQuery: searchQuery,
      searchByTag: searchByTag,
      showFavoritesOnly: showFavoritesOnly,
    ))
      e.id,
  };

  /// フォルダごとの「更新日時」：作成日時と、中（下の階層を含む）の作品の
  /// 最後の更新のうち新しい方。
  static Map<String, DateTime> _folderDates(
    List<Project> projects,
    List<ProjectFolder> folders,
  ) {
    final parentOf = {for (final f in folders) f.id: f.parentFolderId};
    final latest = {for (final f in folders) f.id: f.createdAt};
    for (final p in projects) {
      var id = p.folderId;
      // 壊れたデータで親子が輪になっていても止まるように、たどったフォルダを
      // 覚えておく。
      final seen = <String>{};
      while (id != null && seen.add(id)) {
        final current = latest[id];
        if (current == null) break;
        if (p.updatedAt.isAfter(current)) latest[id] = p.updatedAt;
        id = parentOf[id];
      }
    }
    return latest;
  }

  static List<_Entry> _visibleEntries({
    required List<Project> projects,
    required List<ProjectFolder> folders,
    required String? currentFolderId,
    required String searchQuery,
    required bool searchByTag,
    required bool showFavoritesOnly,
  }) {
    // 大文字・小文字、全角・半角、カタカナ・ひらがなの違いを区別せずに探す。
    final rawQuery = foldName(searchQuery).trim();
    // Accept both `tag` and `#tag` input in tag mode.
    final query = searchByTag && rawQuery.startsWith('#')
        ? rawQuery.substring(1).trimLeft()
        : rawQuery;
    late final latest = _folderDates(projects, folders);
    DateTime folderDate(ProjectFolder f) => latest[f.id] ?? f.createdAt;

    List<_Entry> entries;
    if (query.isNotEmpty) {
      // Search ignores folder hierarchy and scans all projects. Keyword mode
      // keeps the existing project/folder-name behavior; tag mode returns only
      // projects whose saved tags contain the query.
      if (searchByTag) {
        entries = projects
            .where((p) => p.tags.any((tag) => nameMatches(tag.trim(), query)))
            .map((p) => _Entry.project(p))
            .toList();
      } else {
        entries = [
          ...folders
              .where((f) => nameMatches(f.name, query))
              .map((f) => _Entry.folder(f, folderDate(f))),
          ...projects
              .where((p) => nameMatches(p.name, query))
              .map((p) => _Entry.project(p)),
        ];
      }
    } else {
      // 入っていたフォルダが見つからない作品・フォルダは一番上に出す
      // （保存の途中で終わったときなど、どこにも出ずに見失わないように）。
      final folderIds = folders.map((f) => f.id).toSet();
      entries = [
        ...folders
            .where(
              (f) =>
                  (folderIds.contains(f.parentFolderId)
                      ? f.parentFolderId
                      : null) ==
                  currentFolderId,
            )
            .map((f) => _Entry.folder(f, folderDate(f))),
        ...projects
            .where(
              (p) =>
                  (folderIds.contains(p.folderId) ? p.folderId : null) ==
                  currentFolderId,
            )
            .map((p) => _Entry.project(p)),
      ];
    }
    if (showFavoritesOnly) {
      entries = entries.where((e) => e.isFavorite).toList();
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final source = projects ?? projectService.projects;
    final allFolders = projectService.folders;
    final entries = _visibleEntries(
      projects: source,
      folders: allFolders,
      currentFolderId: currentFolderId,
      searchQuery: searchQuery,
      searchByTag: searchByTag,
      showFavoritesOnly: showFavoritesOnly,
    );
    final sorted = _sorted(entries);

    if (sorted.isEmpty) {
      // 検索とお気に入りの絞り込みを両方かけているとき、検索には当たって
      // いてお気に入りで隠れているだけなら、お気に入りの説明を出す。
      final hiddenByFavorites =
          showFavoritesOnly &&
          searchQuery.trim().isNotEmpty &&
          _visibleEntries(
            projects: source,
            folders: allFolders,
            currentFolderId: currentFolderId,
            searchQuery: searchQuery,
            searchByTag: searchByTag,
            showFavoritesOnly: false,
          ).isNotEmpty;
      final empty = _emptyState(l10n, hiddenByFavorites: hiddenByFavorites);
      if (header == null) return empty;
      return CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: header!),
          SliverFillRemaining(
            // The empty-state layout uses LayoutBuilder, which cannot
            // provide intrinsic heights to the non-scrollable variant.
            hasScrollBody: true,
            child: empty,
          ),
        ],
      );
    }

    final searching = searchQuery.trim().isNotEmpty;
    final folderById = {for (final f in allFolders) f.id: f};
    String? locationOf(_Entry e) => searching
        ? _locationOf(
            e.isFolder ? e.folder!.parentFolderId : e.project!.folderId,
            folderById,
          )
        : null;

    // タブを切り替えて戻ったとき・フォルダから戻ったときに、一覧の
    // スクロール位置を元に戻す（TabBarViewは見えないタブの一覧を破棄する
    // ため、キーが無いと毎回先頭へ戻っていた）。フォルダと表示の大きさ
    // ごとに覚える。
    final scrollKey = PageStorageKey<String>(
      'projects/${currentFolderId ?? '-'}/${viewMode.name}',
    );
    // 上に置く絞り込み・パンくず（[header]）は一覧と一緒にスクロールする。
    Widget scrollView(Widget sliver) => CustomScrollView(
      key: scrollKey,
      controller: scrollController,
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header!),
        sliver,
      ],
    );
    if (viewMode == ProjectViewMode.detail) {
      return scrollView(
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          sliver: SliverList.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) => _detailTile(
              context,
              l10n,
              sorted[index],
              locationOf(sorted[index]),
            ),
          ),
        ),
      );
    }

    // 名前の帯（と検索中の場所）と右上の操作が入る高さ。文字の大きさの
    // 設定で帯が高くなっても、カードの絵を押しつぶさない。
    final caption = TextPainter(
      text: TextSpan(
        text: 'Ag国한',
        style: DefaultTextStyle.of(context).style
            .merge(_captionStyle(context))
            .copyWith(
              fontWeight: MediaQuery.boldTextOf(context)
                  ? FontWeight.bold
                  : FontWeight.w600,
            ),
      ),
      textScaler: MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: _captionMaxTextScale),
      textDirection: Directionality.of(context),
      locale: Localizations.localeOf(context),
    )..layout();
    final minimumHeight = 80 + caption.height * (searching ? 2 : 1) + 10;
    caption.dispose();

    // カード基準サイズ（大/中/小）を軸に、画面幅に応じて列数が自然に増減する
    // グリッドを使う（PC/DeXモードの広い画面でも余白だらけにならないように）。
    return LayoutBuilder(
      builder: (context, constraints) => scrollView(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPadding),
          sliver: SliverGrid.builder(
            gridDelegate: _ProjectGridDelegate(
              crossAxisCount: gridColumnsFor(
                viewMode,
                constraints.maxWidth - 16,
              ),
              minHeight: minimumHeight,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) =>
                _gridCard(context, sorted[index], locationOf(sorted[index])),
          ),
        ),
      ),
    );
  }

  // カードの名前の帯の文字は1.5倍までにとどめる（全文は詳細表示で読める）。
  static const double _captionMaxTextScale = 1.5;

  TextStyle _captionStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    color:
        Theme.of(context).popupMenuTheme.textStyle?.color ??
        Theme.of(context).colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );

  /// 表示サイズごとの列数。基準の幅だけで決めると、スマホの幅では大と中
  /// （360px）や中と小（390〜430px）が同じ列数になり、選んでも何も
  /// 変わらなかった。小を基準に、中は小より、大は中より少なくとも1列
  /// 少なくする（広い画面では基準の幅どおりで、もともと差がある）。
  @visibleForTesting
  static int gridColumnsFor(ProjectViewMode mode, double width) {
    int fit(double extent) => math.max(1, (width / (extent + 8)).ceil());
    final small = fit(130);
    final medium = math.max(1, math.min(fit(170), small - 1));
    return switch (mode) {
      ProjectViewMode.small => small,
      ProjectViewMode.medium => medium,
      _ => math.max(1, math.min(fit(240), medium - 1)),
    };
  }

  /// 一覧が空のときの表示。検索・お気に入りの絞り込みで隠れているだけの
  /// ときは「作品がありません」と言わず、絞り込みを外す操作を出す
  /// （以前は検索で見つからないときも「プロジェクトがありません／＋ボタンから
  /// 新規作成」と出ていた）。
  Widget _emptyState(AppLocalizations l10n, {bool hiddenByFavorites = false}) {
    final query = searchQuery.trim();
    if (query.isNotEmpty && !hiddenByFavorites) {
      return EmptyStatePlaceholder(
        icon: Icons.search_off,
        title: l10n.projectListNoMatchTitle(query),
        hint: searchByTag
            ? l10n.projectListNoMatchTagHint
            : l10n.projectListNoMatchNameHint,
        action: onClearSearch == null
            ? null
            : OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close),
                label: Text(l10n.projectListClearSearch),
              ),
      );
    }
    if (showFavoritesOnly) {
      return EmptyStatePlaceholder(
        icon: Icons.star_border,
        title: l10n.projectListNoFavoritesTitle,
        hint: l10n.projectListNoFavoritesHint,
        action: onShowAll == null
            ? null
            : OutlinedButton(
                onPressed: onShowAll,
                child: Text(l10n.projectListShowAll),
              ),
      );
    }
    return EmptyStatePlaceholder(
      icon: currentFolderId == null
          ? Icons.movie_creation_outlined
          : Icons.folder_open,
      title: currentFolderId == null
          ? l10n.projectListEmptyTitle
          : l10n.projectListEmptyFolderTitle,
      hint: showEmptyCreateHint ? l10n.projectListEmptyHint : null,
    );
  }

  /// 作品の絵（一覧のカード・行）。キャンバスと同じく、絵の後ろに作品の
  /// 背景色（透明なら市松模様）を敷き、絵全体を縦横比のまま見せる
  /// （以前は背景を敷かずに切り抜いて出していたため、黒い背景の作品が
  /// 白く見え、縦長の絵は上下が切れていた）。サムネイルが未生成・
  /// 読めないときは背景色の上にアイコンを出す。
  /// [displayWidth]は表示上の論理幅。指定するとその画素数へ落として
  /// デコードする（一覧行の48px表示で、保存されている長辺200pxのまま
  /// 画像キャッシュへ載せないため）。
  Widget _thumbnail(
    BuildContext context,
    Project project, {
    double? displayWidth,
    double checkerSize = 6,
  }) {
    final background = Color(project.backgroundColor);
    final darkPaper = background.a > 0.5 && background.computeLuminance() < 0.3;
    final placeholder = Center(
      child: Icon(
        Icons.image_outlined,
        color: darkPaper
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.38),
      ),
    );
    final path = project.thumbnailPath;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: FramePreviewBackground(
        backgroundColor: project.backgroundColor,
        aspectRatio: project.exportHeight > 0
            ? project.exportWidth / project.exportHeight
            : null,
        checkerSize: checkerSize,
        child: path == null
            ? placeholder
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: displayWidth == null
                    ? null
                    : (displayWidth * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }

  /// 検索の結果は階層をまたぐので、どのフォルダの中にあるかを添える
  /// （同じ名前の作品が別々のフォルダにあると見分けられなかった）。
  static String? _locationOf(
    String? folderId,
    Map<String, ProjectFolder> folders,
  ) {
    final names = <String>[];
    final seen = <String>{};
    var id = folderId;
    while (id != null && seen.add(id)) {
      final folder = folders[id];
      if (folder == null) break;
      names.insert(0, folder.name);
      id = folder.parentFolderId;
    }
    return names.isEmpty ? null : names.join(' / ');
  }

  Widget _detailTile(
    BuildContext context,
    AppLocalizations l10n,
    _Entry entry,
    String? location,
  ) {
    if (entry.isFolder) {
      return _folderDetailTile(context, l10n, entry, location);
    }
    final project = entry.project!;
    final isSelected = selectedIds.contains(project.id);
    // 更新日は別の行に置く（同じ行だと狭い画面で日付が語の途中で折れた）。
    final meta = [
      l10n.homeProjectMeta(project.fps, project.durationSeconds),
      l10n.projectListUpdatedOn(
        MaterialLocalizations.of(context).formatCompactDate(project.updatedAt),
      ),
    ].join('\n');
    return _detailRow(
      context,
      entry,
      ListTile(
        leading: isSelectionMode
            ? _detailLeading(
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionChanged(project.id),
                ),
              )
            : _detailLeading(
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _thumbnail(
                    context,
                    project,
                    displayWidth: _detailArtSize,
                    checkerSize: 4,
                  ),
                ),
              ),
        title: Text(project.name),
        subtitle: Text(
          location == null
              ? meta
              : '$meta\n${l10n.projectListInFolder(location)}',
        ),
        trailing: _detailTrailing(
          entry.isFavorite,
          (isSelectionMode || onPickProject != null)
              ? null
              : _projectMenu(context, project),
        ),
        onTap: isSelectionMode
            ? () => onSelectionChanged(project.id)
            : onPickProject != null
            ? () => onPickProject!(project.id)
            : () => context.push('/project/${project.id}'),
        onLongPress: () => onLongPress(project.id),
      ),
    );
  }

  /// 詳細表示の1行：右クリックでメニュー、切り取り中は薄く。
  Widget _detailRow(BuildContext context, _Entry entry, Widget tile) =>
      GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, entry, details.globalPosition),
        child: _dimIfCut(context, entry.id, tile),
      );

  static const double _detailArtSize = 48;

  // 行の左端。作品の絵・フォルダのアイコン・チェックボックスを同じ幅に
  // そろえ、名前の書き出し位置が行ごとにずれないようにする。
  static Widget _detailLeading(Widget child) => SizedBox.square(
    dimension: _detailArtSize,
    child: Center(child: child),
  );

  // 行の右端。お気に入りの星（作品・フォルダとも）とメニュー。
  static Widget? _detailTrailing(bool favorite, Widget? menu) {
    if (!favorite && menu == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (favorite)
          Builder(
            builder: (themeContext) => Icon(
              Icons.star,
              color: AccentTextTheme.of(themeContext),
              size: 18,
            ),
          ),
        ?menu,
      ],
    );
  }

  Widget _folderDetailTile(
    BuildContext context,
    AppLocalizations l10n,
    _Entry entry,
    String? location,
  ) {
    final folder = entry.folder!;
    final isSelected = selectedIds.contains(folder.id);
    // 色を決めていないフォルダは差し色（大・中・小の表示と同じ塗り）。
    final color = folder.color != null
        ? Color(folder.color!)
        : Theme.of(context).colorScheme.primary;
    return _detailRow(
      context,
      entry,
      ListTile(
        leading: _detailLeading(
          isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionChanged(folder.id),
                )
              : Icon(Icons.folder, color: color, size: 36),
        ),
        title: Text(
          folder.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
          ),
        ),
        subtitle: location == null
            ? null
            : Text(l10n.projectListInFolder(location)),
        trailing: _detailTrailing(
          folder.isFavorite,
          (isSelectionMode || onPickProject != null)
              ? null
              : _folderMenu(context, folder),
        ),
        // フォルダは選ぶ専用画面でも通常どおり潜れる（[onPickProject]は
        // 作品タップ時のみに関わる）。
        onTap: isSelectionMode
            ? () => onSelectionChanged(folder.id)
            : () => onOpenFolder(folder.id),
        onLongPress: () => onLongPress(folder.id),
      ),
    );
  }

  Widget _gridCard(BuildContext context, _Entry entry, String? location) {
    final scheme = Theme.of(context).colorScheme;
    if (entry.isFolder) {
      final folder = entry.folder!;
      final color = folder.color != null
          ? Color(folder.color!)
          : scheme.primary;
      return _card(
        context,
        entry: entry,
        location: location,
        onTap: isSelectionMode
            ? () => onSelectionChanged(folder.id)
            : () => onOpenFolder(folder.id),
        art: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.1),
              ],
            ),
          ),
          // 大表示の1列のカードでは46pxのままだと広い絵の中で小さく浮くので、
          // 絵の短い辺に合わせて大きくする（中・小は46pxのまま）。
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: Icon(
                Icons.folder_rounded,
                color: color,
                size: math.max(46, constraints.biggest.shortestSide * 0.4),
              ),
            ),
          ),
        ),
      );
    }
    final project = entry.project!;
    return _card(
      context,
      entry: entry,
      location: location,
      onTap: isSelectionMode
          ? () => onSelectionChanged(project.id)
          : onPickProject != null
          ? () => onPickProject!(project.id)
          : () => context.push('/project/${project.id}'),
      // 選ぶ専用画面ではダブルタップでのキャンバス直接起動は不要（誤操作の
      // もとになる）ため無効化する。
      onDoubleTap: (isSelectionMode || onPickProject != null)
          ? null
          : () => context.push('/canvas/${project.id}'),
      art: _thumbnail(context, project),
    );
  }

  /// 作品・フォルダ共通のカード。絵の下に名前の帯を置く（以前は作品だけ
  /// 絵の上に名前を重ねていて、黒い絵の上では名前が読めなかった）。
  Widget _card(
    BuildContext context, {
    required _Entry entry,
    required String? location,
    required VoidCallback onTap,
    VoidCallback? onDoubleTap,
    required Widget art,
  }) {
    final isSelected = selectedIds.contains(entry.id);
    final scheme = Theme.of(context).colorScheme;
    // 選択の色はテーマの「選択」の色（secondary）と、その上の文字色。
    final selectionColor = scheme.secondary;
    final selectionForeground = scheme.onSecondary;
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: () => onLongPress(entry.id),
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, entry, details.globalPosition),
      child: _dimIfCut(
        context,
        entry.id,
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color:
                    (isSelected
                            ? selectionColor
                            : ThemeService.activeColorScheme.onSurface)
                        .withValues(alpha: isSelected ? 0.28 : 0.12),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected ? selectionColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          art,
                          if (isSelectionMode)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectionColor
                                      : scheme.surface.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectionColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check : null,
                                  size: 16,
                                  color: selectionForeground,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // カードの高さは決まっているので、名前の帯の文字は1.5倍までに
                    // とどめる（文字を大きくした小さなカードで帯が絵を押しつぶし、
                    // はみ出していた）。全文は詳細表示で大きな文字のまま読める。
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: _captionMaxTextScale,
                      child: Padding(
                        // 小さなカードではお気に入りの星が名前の帯まで届くので、
                        // そのぶん空ける。
                        padding: EdgeInsets.fromLTRB(
                          6,
                          4,
                          entry.isFavorite ? 40 : 6,
                          6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: entry.name,
                              triggerMode: TooltipTriggerMode.manual,
                              excludeFromSemantics: true,
                              child: Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _captionStyle(context),
                              ),
                            ),
                            // 小表示のカードには場所まで入らない（詳細表示で出る）。
                            if (location != null &&
                                viewMode != ProjectViewMode.small)
                              Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // メニュー（選択中・選ぶ画面では出さない）と、その下にお気に入り。
                _gridCardActions(
                  context,
                  menu: entry.isFolder
                      ? _folderMenu(context, entry.folder!)
                      : _projectMenu(context, entry.project!),
                  isFavorite: entry.isFavorite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 切り取って貼り付け待ちの項目を薄く表示する（読み上げでも伝える）。
  Widget _dimIfCut(BuildContext context, String id, Widget child) {
    if (!pendingCutIds.contains(id)) return child;
    return Semantics(
      hint: AppLocalizations.of(context)!.homeCutPendingHint,
      child: Opacity(opacity: 0.45, child: child),
    );
  }

  Widget _gridCardActions(
    BuildContext context, {
    required Widget menu,
    required bool isFavorite,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final showMenu = !isSelectionMode && onPickProject == null;
    return Positioned(
      top: 4,
      right: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMenu)
            Material(
              color: Theme.of(context).cardTheme.color ?? scheme.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: SizedBox.square(dimension: 48, child: menu),
            ),
          if (isFavorite)
            Padding(
              // 選択中はメニューの空き枠を残さず、星をタイル右上へ寄せる。
              padding: EdgeInsets.only(top: showMenu ? 4 : 0),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Builder(
                  // SliverGrid delegates may reuse cached children when the
                  // outer itemBuilder is unchanged. Let the badge itself
                  // depend on the live inherited Theme.
                  builder: (themeContext) => Icon(
                    Icons.star,
                    color: AccentTextTheme.of(themeContext),
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _projectMenu(BuildContext context, Project project) =>
      PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (action) => _handleAction(context, action, project),
        itemBuilder: (_) => _projectMenuItems(context, project),
      );

  List<PopupMenuEntry<String>> _projectMenuItems(
    BuildContext context,
    Project project,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
      PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
      PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
      PopupMenuItem(
        value: 'share',
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
      PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          l10n.projectDetailTrashMenuItem,
          style: TextStyle(color: ThemeService.activeColorScheme.error),
        ),
      ),
    ];
  }

  Widget _folderMenu(BuildContext context, ProjectFolder folder) =>
      PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (action) => _handleFolderAction(context, action, folder),
        itemBuilder: (_) => _folderMenuItems(context, folder),
      );

  List<PopupMenuEntry<String>> _folderMenuItems(
    BuildContext context,
    ProjectFolder folder,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
      PopupMenuItem(
        value: 'edit',
        child: Text(l10n.projectListEditFolderAction),
      ),
      PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          folder.isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
        ),
      ),
      PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
      // 中身ごとゴミ箱へ移す（作品と同じ言葉にする）。
      PopupMenuItem(
        value: 'delete',
        child: Text(
          l10n.projectDetailTrashMenuItem,
          style: TextStyle(color: ThemeService.activeColorScheme.error),
        ),
      ),
    ];
  }

  /// 右クリック（マウス・ペンの副ボタン）で、その作品・フォルダのメニューを
  /// 押した所に開く。カード表示には「︙」のボタンが無いため、PC/DeXでは
  /// 名前の変更・複製・移動等をここから行う（以前は右クリックしても何も
  /// 起きなかった）。
  Future<void> _showContextMenu(
    BuildContext context,
    _Entry entry,
    Offset globalPosition,
  ) async {
    if (isSelectionMode || onPickProject != null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      globalPosition & Size.zero,
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: entry.isFolder
          ? _folderMenuItems(context, entry.folder!)
          : _projectMenuItems(context, entry.project!),
    );
    if (action == null || !context.mounted) return;
    if (entry.isFolder) {
      _handleFolderAction(context, action, entry.folder!);
    } else {
      _handleAction(context, action, entry.project!);
    }
  }

  void _handleAction(BuildContext context, String action, Project project) {
    final service = context.read<ProjectService>();
    switch (action) {
      case 'open':
        context.push('/canvas/${project.id}');
      case 'rename':
        _showRenameDialog(context, project);
      case 'duplicate':
        service.duplicateProject(
          project.id,
          name: duplicateProjectName(
            AppLocalizations.of(context)!,
            project.name,
            folderId: project.folderId,
            projects: service.projects,
          ),
        );
      case 'share':
        _createNiashare(context, project);
      case 'favorite':
        service.toggleFavorite(project.id);
      case 'move':
        _showMoveProjectToFolderDialog(context, project);
      case 'delete':
        _deleteProject(context, service, project);
    }
  }

  /// お気に入り登録中は削除できない。
  void _deleteProject(
    BuildContext context,
    ProjectService service,
    Project project,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (project.isFavorite) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
      );
      return;
    }
    service.deleteProject(project.id);
    // ゴミ箱へ移したことを伝え、その場で戻せるようにする（以前は何も
    // 表示されず、一覧から消えるだけだった）。
    showMovedToTrashSnackBar(messenger, l10n, service, [project.id]);
  }

  Future<void> _handleFolderAction(
    BuildContext context,
    String action,
    ProjectFolder folder,
  ) async {
    final service = context.read<ProjectService>();
    void showFailure(Object error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            folderSaveFailureText(AppLocalizations.of(context)!, error),
          ),
        ),
      );
    }

    switch (action) {
      case 'open':
        onOpenFolder(folder.id);
      case 'edit':
        _showEditFolderDialog(context, folder);
      case 'duplicate':
        // 同じ階層に、中身（フォルダ・作品）ごと複製する。
        try {
          await service.duplicateFolder(
            folder.id,
            targetParentId: folder.parentFolderId,
            name: duplicateFolderName(
              AppLocalizations.of(context)!,
              folder.name,
              parentId: folder.parentFolderId,
              folders: service.folders,
            ),
          );
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
          showFailure(error);
        }
      case 'favorite':
        try {
          await service.toggleFolderFavorite(folder.id);
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
          showFailure(error);
        }
      case 'move':
        _showMoveFolderToFolderDialog(context, folder);
      case 'delete':
        _confirmDeleteFolder(context, folder);
    }
  }

  /// フォルダを中身（下の階層のフォルダ・作品）ごとゴミ箱へ移す前に、移る
  /// 件数を伝えて確かめる。移した後はその場で元に戻せ、ゴミ箱からも
  /// フォルダごと戻せる。
  void _confirmDeleteFolder(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // お気に入り登録中は削除できない。
    if (folder.isFavorite) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)),
      );
      return;
    }
    final service = context.read<ProjectService>();
    final counts = service.folderContentCounts(folder.id);
    showDialog<void>(
      context: context,
      builder: (_) => FolderDeleteDialog(
        folderName: folder.name,
        title: l10n.projectListTrashFolderConfirmTitle,
        // 空のフォルダでは中身の行を出さない。
        body: [
          l10n.projectListTrashFolderConfirmBody(folder.name),
          if (counts.projects + counts.folders > 0)
            l10n.homeMoveToTrashFolderContents(
              l10n.homeFolderContents(counts.projects, counts.folders),
            ),
        ].join('\n\n'),
        confirmLabel: l10n.commonMove,
        onDelete: () async {
          if (await service.moveFolderToTrash(folder.id) != null) {
            showFolderMovedToTrashSnackBar(messenger, l10n, service, folder);
          }
        },
      ),
    );
  }

  /// .niashare（共有用ファイル）を作成し、共有シートを表示する。
  Future<void> _createNiashare(BuildContext context, Project project) async {
    final includeOptions = await showMaterialIncludeDialog(context);
    if (includeOptions == null || !context.mounted) return; // キャンセル
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
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

  void _showRenameDialog(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    showDialog(
      context: context,
      builder: (ctx) => NameEntryDialog(
        title: l10n.commonRename,
        initialName: project.name,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        onSubmit: (name) async {
          if (name != project.name) {
            await service.renameProject(project.id, name);
          }
        },
      ),
    );
  }

  void _showMoveProjectToFolderDialog(BuildContext context, Project project) {
    _showFolderPickerSheet(
      context,
      excludeFolderId: null,
      itemName: project.name,
      onSelect: (folderId) =>
          context.read<ProjectService>().moveToFolder(project.id, folderId),
      onCreateAndSelect: (name) async {
        final service = context.read<ProjectService>();
        final folder = await service.createFolder(name);
        try {
          await service.moveToFolder(project.id, folder.id);
        } catch (error) {
          throw FolderSaveException(partiallySaved: true, cause: error);
        }
      },
    );
  }

  void _showMoveFolderToFolderDialog(
    BuildContext context,
    ProjectFolder folder,
  ) {
    _showFolderPickerSheet(
      context,
      // 自分自身の直下へは移動できない（循環防止はサービス側でも二重にガードする）
      excludeFolderId: folder.id,
      itemName: folder.name,
      onSelect: (folderId) =>
          context.read<ProjectService>().moveFolderTo(folder.id, folderId),
      onCreateAndSelect: (name) async {
        final service = context.read<ProjectService>();
        final newFolder = await service.createFolder(name);
        try {
          await service.moveFolderTo(folder.id, newFolder.id);
        } catch (error) {
          throw FolderSaveException(partiallySaved: true, cause: error);
        }
      },
    );
  }

  void _showFolderPickerSheet(
    BuildContext context, {
    required String? excludeFolderId,
    required String itemName,
    required Future<void> Function(String?) onSelect,
    required Future<void> Function(String name) onCreateAndSelect,
  }) {
    // 親の下に子を字下げして並べ、動かすフォルダとその中は出さない。
    final tree = folderTree(
      context.read<ProjectService>().folders,
      excluding: excludeFolderId,
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: [for (final entry in tree) entry.folder],
        depths: {for (final entry in tree) entry.folder.id: entry.depth},
        filename: itemName,
        rootLabel: AppLocalizations.of(context)!.projectListFolderRootOption,
        onMove: onSelect,
        onEdit: (folder) => _showEditFolderDialog(context, folder),
        onCreate: () => showCreateFolderNameDialog(context, onCreateAndSelect),
      ),
    );
  }

  void _showEditFolderDialog(BuildContext context, ProjectFolder folder) {
    final service = context.read<ProjectService>();
    showDialog<void>(
      context: context,
      builder: (_) => ProjectFolderEditDialog(
        folder: folder,
        onSave: (name, color) =>
            service.editFolder(folder.id, name: name, color: color),
      ),
    );
  }
}

/// .niashare作成時の同梱選択ダイアログ（画像/動画/音声を
/// 種類ごとに選択できる。デフォルトは全種類ON。「フォントを含める」を
/// 選択した場合のみユーザー追加フォントも同梱する）。キャンセル時はnullを返す。
Future<({Set<MaterialType> materialTypes, bool includeFonts})?>
showMaterialIncludeDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final selected = <MaterialType>{
    MaterialType.image,
    MaterialType.video,
    MaterialType.audio,
  };
  bool includeFonts = true;
  return showDialog<({Set<MaterialType> materialTypes, bool includeFonts})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l10n.projectListMaterialIncludeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.projectListMaterialIncludeHint,
              style: const TextStyle(fontSize: 12),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.image),
              title: Text(l10n.projectListMaterialImage),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                () => v == true
                    ? selected.add(MaterialType.image)
                    : selected.remove(MaterialType.image),
              ),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.video),
              title: Text(l10n.projectListMaterialVideo),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                () => v == true
                    ? selected.add(MaterialType.video)
                    : selected.remove(MaterialType.video),
              ),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.audio),
              title: Text(l10n.projectListMaterialAudio),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                () => v == true
                    ? selected.add(MaterialType.audio)
                    : selected.remove(MaterialType.audio),
              ),
            ),
            const Divider(),
            CheckboxListTile(
              value: includeFonts,
              title: Text(l10n.projectListIncludeFontsTitle),
              subtitle: Text(
                l10n.projectListIncludeFontsSubtitle,
                style: const TextStyle(fontSize: 11),
              ),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(() => includeFonts = v ?? true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (
              materialTypes: selected,
              includeFonts: includeFonts,
            )),
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    ),
  );
}

/// プロジェクトで使用中のユーザー追加フォントをまとめ、.niashareへ同梱する
/// ためのファイル群とマニフェストを作成する（プロジェクト共有時の
/// 「フォントを含める」選択時に使用）。使用フォントがアプリ標準フォントのみの場合は空を返す。
Future<({Map<String, Uint8List> files, String? manifest})> buildFontShareBundle(
  ProjectService projectService,
  FontService fontService,
  String projectId,
) async {
  final usedFamilies = projectService.usedFontFamiliesOf(projectId);
  final files = <String, Uint8List>{};
  final manifestList = <Map<String, dynamic>>[];
  for (final font in fontService.fonts) {
    if (!usedFamilies.contains(fontService.familyNameOf(font))) continue;
    final bytes = await fontService.readFontBytes(font);
    if (bytes == null) continue;
    files[font.fileName] = bytes;
    manifestList.add({
      'id': font.id,
      'displayName': font.displayName,
      'fileName': font.fileName,
    });
  }
  if (files.isEmpty) return (files: <String, Uint8List>{}, manifest: null);
  return (files: files, manifest: jsonEncode(manifestList));
}
