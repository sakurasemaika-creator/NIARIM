import 'package:niarim/services/theme_service.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../engine/niapro_serializer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/material_asset.dart';
import '../../../models/project.dart';
import '../../../services/export_share_service.dart';
import '../../../services/font_service.dart';
import '../../../services/material_service.dart';
import '../../../services/project_service.dart';
import '../home_screen.dart';
import '../../../config/font_fallback.dart';
import '../../../widgets/checked_menu_item.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/export_share_feedback.dart';
import '../../../widgets/frame_preview_background.dart';
import '../../../widgets/project_trash_dialog.dart';
import '../../../widgets/moved_to_trash_snack_bar.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../widgets/collection_action_controls.dart';
import '../../../widgets/collection_tile_layout.dart';
import '../../../widgets/date_line_text.dart';
import '../../../utils/app_error_reporter.dart';
import '../../../utils/duplicate_name.dart';
import 'folder_save_feedback.dart';
import 'work_folder_move_sheet.dart';
import 'project_folder_edit_dialog.dart';
import 'folder_thumbnail.dart';
import 'project_thumbnail_dialog.dart';
import '../../../utils/folder_persistence.dart';
import '../../../utils/folder_tree.dart';
import '../../../utils/name_collation.dart';

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
    builder: (dialogContext) =>
        _folderNameDialog(dialogContext, onSave: onCreate),
  );
}

/// フォルダの名前を入力するダイアログ。[NameEntryDialog]に乗せる（Enterで
/// 確定・二度押しで2つ作らない・空白だけの名前は確定しない・失敗したら
/// 名前を残して開いたまま理由を出す）。以前の専用のダイアログは、Enterを
/// 押しても作成しなかった。
Widget _folderNameDialog(
  BuildContext context, {
  required Future<void> Function(String name) onSave,
  String initialName = '',
  bool rename = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return NameEntryDialog(
    title: rename ? l10n.commonRename : l10n.projectListNewFolderTitle,
    confirmLabel: rename ? l10n.commonChange : l10n.commonCreate,
    cancelLabel: l10n.commonCancel,
    labelText: l10n.folderNameLabel,
    initialName: initialName,
    hint: rename
        ? null
        : Text(
            l10n.projectListFolderHint,
            style: const TextStyle(fontSize: 11),
          ),
    failureText: (error) =>
        rename || (error is FolderSaveException && error.partiallySaved)
        ? folderSaveFailureText(l10n, error)
        : l10n.folderCreateFailed,
    showsProgress: true,
    closableWhileSubmitting: true,
    onSubmit: onSave,
  );
}

void showRenameFolderNameDialog(
  BuildContext context,
  String name,
  Future<void> Function(String name) onRename,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => _folderNameDialog(
      dialogContext,
      onSave: onRename,
      initialName: name,
      rename: true,
    ),
  );
}

/// 一覧の表示サイズ（大・中・小・詳細）を選ぶメニュー。開くと今の表示に
/// チェックが付き（読み上げでも選択中）、ボタンを覆わないよう下に開く
/// （以前はどれを選んでいるか分からず、ボタンの上に重なって開いた）。
/// ホームのタブと、ホーム画面ウィジェットの作品を選ぶ一覧で使う。
class ProjectViewModeMenu extends StatelessWidget {
  const ProjectViewModeMenu({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProjectViewMode value;
  final ValueChanged<ProjectViewMode> onChanged;

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
      icon: const Icon(Icons.view_module),
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
            label: label(mode),
          ),
      ],
    );
  }
}

/// フォルダ・プロジェクトを同一一覧内で扱うための表示用ラッパー
/// （フォルダとプロジェクトを同一一覧内で並び替え可能にする）。
class _Entry {
  final ProjectFolder? folder;
  final Project? project;
  const _Entry.folder(ProjectFolder f) : folder = f, project = null;
  const _Entry.project(Project p) : project = p, folder = null;

  bool get isFolder => folder != null;
  String get id => isFolder ? folder!.id : project!.id;
  String get name => isFolder ? folder!.name : project!.name;
  DateTime get sortDate => isFolder ? folder!.createdAt : project!.updatedAt;
  bool get isFavorite => isFolder ? folder!.isFavorite : project!.isFavorite;
}

class ProjectListWidget extends StatelessWidget {
  final ProjectViewMode viewMode;
  final ProjectSortMode sortMode;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  /// The entries cut to the clipboard remain visible, but are dimmed.
  final Set<String> cutIds;
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
  final ScrollController? scrollController;

  /// Optional controls that scroll away with the project list rather than
  /// remaining pinned above its viewport.
  final Widget? header;
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

  /// 作品を読み込めなかった間（`ProjectService.projectsLoadFailed`）に渡す。
  /// 並べるものが無くても「プロジェクトがありません」と作成の案内を出さず、
  /// [header]（読み込めなかった知らせ）だけを出す（読めなかっただけなのに
  /// 「無い」と読め、新しく作るよう促していた）。
  final bool hideEmptyState;

  /// 検索に当たらないときの「検索をやめる」。nullならボタンを出さない。
  final VoidCallback? onClearSearch;

  /// お気に入りだけを出していて何も無いときの「すべて表示」。nullなら
  /// ボタンを出さない。
  final VoidCallback? onShowAll;

  const ProjectListWidget({
    super.key,
    required this.viewMode,
    required this.sortMode,
    required this.isSelectionMode,
    required this.selectedIds,
    this.cutIds = const {},
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.currentFolderId,
    required this.onOpenFolder,
    this.scrollController,
    this.header,
    this.projects,
    this.showFavoritesOnly = false,
    this.searchQuery = '',
    this.searchByTag = false,
    this.onPickProject,
    this.showEmptyCreateHint = true,
    this.hideEmptyState = false,
    this.onClearSearch,
    this.onShowAll,
  });

  /// IDs come from the same filtering as the rendered list, before sorting.
  static Set<String> visibleIds({
    required List<Project> source,
    required List<ProjectFolder> allFolders,
    required String? currentFolderId,
    required bool showFavoritesOnly,
    required String searchQuery,
    required bool searchByTag,
  }) => _visibleEntries(
    source: source,
    allFolders: allFolders,
    currentFolderId: currentFolderId,
    showFavoritesOnly: showFavoritesOnly,
    searchQuery: searchQuery,
    searchByTag: searchByTag,
  ).map((entry) => entry.id).toSet();

  static List<_Entry> _visibleEntries({
    required List<Project> source,
    required List<ProjectFolder> allFolders,
    required String? currentFolderId,
    required bool showFavoritesOnly,
    required String searchQuery,
    required bool searchByTag,
  }) {
    final folderIds = allFolders.map((f) => f.id).toSet();
    // 大文字・小文字、全角・半角、カタカナ・ひらがなの違いを区別せずに探す。
    final rawQuery = foldName(searchQuery).trim();
    // Accept both `tag` and `#tag` input in tag mode.
    final query = searchByTag && rawQuery.startsWith('#')
        ? rawQuery.substring(1).trimLeft()
        : rawQuery;

    List<_Entry> entries;
    if (query.isNotEmpty) {
      // Search ignores folder hierarchy and scans all projects. Keyword mode
      // keeps the existing project/folder-name behavior; tag mode returns only
      // projects whose saved tags contain the query.
      if (searchByTag) {
        entries = source
            .where((p) => p.tags.any((tag) => nameMatches(tag.trim(), query)))
            .map((p) => _Entry.project(p))
            .toList();
      } else {
        entries = [
          ...allFolders
              .where((f) => nameMatches(f.name, query))
              .map((f) => _Entry.folder(f)),
          ...source
              .where((p) => nameMatches(p.name, query))
              .map((p) => _Entry.project(p)),
        ];
      }
    } else {
      entries = [
        ...allFolders
            .where(
              (f) =>
                  (folderIds.contains(f.parentFolderId)
                      ? f.parentFolderId
                      : null) ==
                  currentFolderId,
            )
            .map((f) => _Entry.folder(f)),
        ...source
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

  /// [sortMode]で並べる。名前は人が読む順（数字は数として、大文字・
  /// 小文字や全角・半角、カタカナ・ひらがなの違いは区別しない）。同じ名前・
  /// 同じ日時の項目は、もう一方の基準で決める（並びが毎回変わらないように）。
  List<_Entry> _sorted(List<_Entry> src) {
    // 名前は1件につき1回だけそろえる。
    final keys = Map<_Entry, NameSortKey>.identity();
    NameSortKey key(_Entry e) => keys[e] ??= NameSortKey(e.name);
    int byName(_Entry a, _Entry b) => compareNameKeys(key(a), key(b));
    final byNameFirst =
        sortMode == ProjectSortMode.nameAsc ||
        sortMode == ProjectSortMode.nameDesc;
    return List<_Entry>.from(src)..sort((a, b) {
      final order = switch (sortMode) {
        ProjectSortMode.nameAsc => byName(a, b),
        ProjectSortMode.nameDesc => byName(b, a),
        ProjectSortMode.updatedAsc => a.sortDate.compareTo(b.sortDate),
        ProjectSortMode.updatedDesc => b.sortDate.compareTo(a.sortDate),
      };
      if (order != 0) return order;
      final tie = byNameFirst ? b.sortDate.compareTo(a.sortDate) : byName(a, b);
      return tie != 0 ? tie : a.id.compareTo(b.id);
    });
  }

  Widget _withCutFeedback(BuildContext context, _Entry entry, Widget child) {
    if (!cutIds.contains(entry.id)) return child;
    return Semantics(
      hint: AppLocalizations.of(context)!.homeCutPendingHint,
      child: Opacity(opacity: 0.45, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final source = projects ?? projectService.projects;
    final allFolders = projectService.folders;
    final entries = _visibleEntries(
      source: source,
      allFolders: allFolders,
      currentFolderId: currentFolderId,
      showFavoritesOnly: showFavoritesOnly,
      searchQuery: searchQuery,
      searchByTag: searchByTag,
    );
    final sorted = _sorted(entries);

    if (sorted.isEmpty) {
      // 検索とお気に入りの絞り込みを両方かけているとき、検索には当たって
      // いてお気に入りで隠れているだけなら、お気に入りの説明を出す。
      final hiddenByFavorites =
          showFavoritesOnly &&
          searchQuery.trim().isNotEmpty &&
          _visibleEntries(
            source: source,
            allFolders: allFolders,
            currentFolderId: currentFolderId,
            showFavoritesOnly: false,
            searchQuery: searchQuery,
            searchByTag: searchByTag,
          ).isNotEmpty;
      if (hideEmptyState) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [if (header != null) SliverToBoxAdapter(child: header!)],
        );
      }
      if (header != null) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: header!),
            SliverFillRemaining(
              // The empty-state layout uses LayoutBuilder, which cannot
              // provide intrinsic heights to the non-scrollable variant.
              hasScrollBody: true,
              child: _emptyState(l10n, hiddenByFavorites: hiddenByFavorites),
            ),
          ],
        );
      }
      return _emptyState(l10n, hiddenByFavorites: hiddenByFavorites);
    }

    if (viewMode == ProjectViewMode.detail) {
      if (header != null) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: header!),
            SliverList.builder(
              itemCount: sorted.length,
              itemBuilder: (context, index) => _withCutFeedback(
                context,
                sorted[index],
                _detailTile(context, l10n, sorted[index]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 104)),
          ],
        );
      }
      return ListView.builder(
        controller: scrollController,
        itemCount: sorted.length,
        itemBuilder: (context, index) => _withCutFeedback(
          context,
          sorted[index],
          _detailTile(context, l10n, sorted[index]),
        ),
      );
    }

    // カード基準サイズ（大/中/小）を軸に、画面幅に応じて列数が自然に増減する
    // グリッドを使う（PC/DeXモードの広い画面でも余白だらけにならないように）。
    final targetExtent = switch (viewMode) {
      ProjectViewMode.large => 240.0,
      ProjectViewMode.medium => 170.0,
      ProjectViewMode.small => 130.0,
      ProjectViewMode.detail => double.infinity,
    };
    // 検索の結果には、入っているフォルダの場所の行を添える。
    final gridDelegate = collectionTileGridDelegate(
      context,
      targetExtent,
      locationRow: searchQuery.trim().isNotEmpty,
    );
    if (header != null) {
      return CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: header!),
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid.builder(
              gridDelegate: gridDelegate,
              itemCount: sorted.length,
              itemBuilder: (context, index) => _withCutFeedback(
                context,
                sorted[index],
                _gridCard(context, sorted[index]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      );
    }
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: gridDelegate,
      itemCount: sorted.length,
      itemBuilder: (context, index) => _withCutFeedback(
        context,
        sorted[index],
        _gridCard(context, sorted[index]),
      ),
    );
  }

  /// 一覧が空のときの表示。検索・お気に入りの絞り込みで隠れているだけの
  /// ときは「プロジェクトがありません」と言わず、絞り込みを外すボタンを
  /// 出す。フォルダの中が空のときはそう言う。
  Widget _emptyState(AppLocalizations l10n, {bool hiddenByFavorites = false}) {
    // ホームでは左下・右下に丸いボタンが浮くので、絞り込みを外すボタンが
    // その下に入らないよう、下にその分の余白を取る（選ぶ専用画面には無い）。
    Widget clearOfFloatingButtons(Widget child) => Padding(
      padding: EdgeInsets.only(bottom: onPickProject == null ? 88 : 0),
      child: child,
    );
    final query = searchQuery.trim();
    if (query.isNotEmpty && !hiddenByFavorites) {
      return clearOfFloatingButtons(
        EmptyStatePlaceholder(
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
        ),
      );
    }
    if (showFavoritesOnly) {
      return clearOfFloatingButtons(
        EmptyStatePlaceholder(
          icon: Icons.star_border,
          title: l10n.projectListNoFavoritesTitle,
          // 説明は作品・フォルダのメニューを指すので、カードにメニューの無い
          // 選ぶ専用画面（[onPickProject]使用時）では出さない。
          hint: onPickProject == null ? l10n.projectListNoFavoritesHint : null,
          action: onShowAll == null
              ? null
              : OutlinedButton(
                  onPressed: onShowAll,
                  child: Text(l10n.projectListShowAll),
                ),
        ),
      );
    }
    final inFolder = currentFolderId != null;
    return EmptyStatePlaceholder(
      icon: inFolder ? Icons.folder_open : Icons.movie_creation_outlined,
      title: inFolder
          ? l10n.projectListEmptyFolderTitle
          : l10n.projectListEmptyTitle,
      hint: showEmptyCreateHint ? l10n.projectListEmptyHint : null,
    );
  }

  /// プロジェクトカードのサムネイル。生成済みのPNGがあればそれを表示し、
  /// 未生成・読み込み失敗の場合は背景色のプレースホルダーへフォールバックする。
  /// [displayWidth]は表示上の論理幅。指定するとその画素数へ落として
  /// デコードする（一覧行の48px表示で、保存されている長辺200pxのまま
  /// 画像キャッシュへ載せないため）。カード表示のように表示側の方が
  /// 大きくなる場合は指定しない。
  Widget _thumbnail(
    BuildContext context,
    Project project, {
    double? displayWidth,
  }) {
    final placeholder = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: FramePreviewBackground(
        backgroundColor: project.backgroundColor,
        checkerSize: 8,
        child: Center(
          child: Icon(
            Icons.image,
            color: ThemeService.activeColorScheme.onSurface.withValues(
              alpha: 0.38,
            ),
          ),
        ),
      ),
    );
    final path = project.thumbnailPath;
    if (path == null) return placeholder;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: FramePreviewBackground(
        backgroundColor: project.backgroundColor,
        checkerSize: 8,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: displayWidth == null
              ? null
              : (displayWidth * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }

  Widget _gridCaption(BuildContext context, String name, String? parentId) =>
      collectionTileCaption(
        context,
        name,
        location: _searchLocation(context, parentId),
        locationRow: searchQuery.trim().isNotEmpty,
      );

  /// 検索の結果は階層をまたぐので、どのフォルダの中にあるかを添える
  /// （同じ名前の作品が別々のフォルダにあると見分けられなかった）。
  /// [parentId]のフォルダの場所（上の階層から「 / 」でつなぐ）。探して
  /// いないとき・一番上にあるときはnull。
  String? _searchLocation(BuildContext context, String? parentId) {
    if (searchQuery.trim().isEmpty) return null;
    final folders = {
      for (final folder in context.read<ProjectService>().folders)
        folder.id: folder,
    };
    final names = <String>[];
    final seen = <String>{};
    var id = parentId;
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
  ) {
    if (entry.isFolder) return _folderDetailTile(context, entry.folder!);
    final project = entry.project!;
    final isSelected = selectedIds.contains(project.id);
    return ListTile(
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionChanged(project.id),
            )
          : SizedBox(
              width: 48,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _thumbnail(context, project, displayWidth: 48),
              ),
            ),
      title: Text(project.name),
      // 2行目は最後に保存した日時（その言語の日付と時刻の書き方）。検索の
      // 結果には、入っているフォルダを添える。
      subtitle: DateLineText(
        [
          l10n.homeProjectMeta(project.fps, project.durationSeconds),
          l10n.projectListUpdatedOn(project.updatedAt),
          if (_searchLocation(context, project.folderId) case final location?)
            l10n.projectListInFolder(location),
        ].join('\n'),
        when: project.updatedAt,
        localeName: l10n.localeName,
      ),
      trailing: (isSelectionMode || onPickProject != null)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CollectionFavoriteButton(
                  itemId: project.id,
                  favorite: project.isFavorite,
                  tooltip: project.isFavorite
                      ? l10n.colorPickerFavoriteRemove
                      : l10n.colorPickerFavoriteAdd,
                  onPressed: () => runProjectAction(
                    context,
                    () => context.read<ProjectService>().toggleFavorite(
                      project.id,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CollectionActionFrame(child: _projectMenu(context, project)),
              ],
            ),
      onTap: isSelectionMode
          ? () => onSelectionChanged(project.id)
          : onPickProject != null
          ? () => onPickProject!(project.id)
          : () => context.push('/project/${project.id}'),
      onLongPress: () => onLongPress(project.id),
    );
  }

  Widget _folderDetailTile(BuildContext context, ProjectFolder folder) {
    final isSelected = selectedIds.contains(folder.id);
    return ListTile(
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionChanged(folder.id),
            )
          : SizedBox(
              width: 48,
              height: 48,
              child: FolderThumbnail(
                folder: folder,
                choices: _folderCoverChoices(context, folder),
                defaultImagePath: _projectFolderCoverPath(context, folder),
              ),
            ),
      title: Text(
        folder.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      // フォルダを作った日時（「更新日時」の並びでフォルダに使う日時）。
      // 検索の結果には、入っているフォルダを添える。
      subtitle: DateLineText(
        [
          AppLocalizations.of(
            context,
          )!.projectListFolderCreatedOn(folder.createdAt),
          if (_searchLocation(context, folder.parentFolderId)
              case final location?)
            AppLocalizations.of(context)!.projectListInFolder(location),
        ].join('\n'),
        when: folder.createdAt,
        localeName: AppLocalizations.of(context)!.localeName,
      ),
      trailing: (!isSelectionMode && onPickProject == null)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CollectionFavoriteButton(
                  itemId: folder.id,
                  favorite: folder.isFavorite,
                  tooltip: folder.isFavorite
                      ? AppLocalizations.of(context)!.colorPickerFavoriteRemove
                      : AppLocalizations.of(context)!.colorPickerFavoriteAdd,
                  onPressed: () =>
                      _handleFolderAction(context, 'favorite', folder),
                ),
                const SizedBox(width: 4),
                CollectionActionFrame(child: _folderMenu(context, folder)),
              ],
            )
          : null,
      // フォルダは選ぶ専用画面でも通常どおり潜れる（[onPickProject]は
      // 作品タップ時のみに関わる）。
      onTap: isSelectionMode
          ? () => onSelectionChanged(folder.id)
          : () => onOpenFolder(folder.id),
      onLongPress: () => onLongPress(folder.id),
    );
  }

  Widget _gridCard(BuildContext context, _Entry entry) {
    if (entry.isFolder) return _folderGridCard(context, entry.folder!);
    final project = entry.project!;
    final isSelected = selectedIds.contains(project.id);
    final scheme = Theme.of(context).colorScheme;
    final selectionColor = scheme.secondary;
    final selectionForeground = scheme.onSecondary;
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (!isSelectionMode && onPickProject == null) {
          _showProjectSecondaryMenu(context, project, details.globalPosition);
        }
      },
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
      onLongPress: () => onLongPress(project.id),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumbnail(context, project),
                    _gridCardActions(
                      context,
                      menu: _projectMenu(context, project),
                      isFavorite: project.isFavorite,
                      itemId: project.id,
                      onFavorite: () => runProjectAction(
                        context,
                        () => context.read<ProjectService>().toggleFavorite(
                          project.id,
                        ),
                      ),
                    ),
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
                            boxShadow: [
                              BoxShadow(
                                color: ThemeService.activeColorScheme.onSurface
                                    .withValues(alpha: 0.2),
                                blurRadius: 3,
                              ),
                            ],
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
              _gridCaption(context, project.name, project.folderId),
            ],
          ),
        ),
      ),
    );
  }

  String? _projectFolderCoverPath(BuildContext context, ProjectFolder folder) {
    final service = context.read<ProjectService>();
    return projectFolderEffectiveCover(
      folder.id,
      service.folders,
      service.projects,
    );
  }

  List<FolderThumbnailChoice> _folderCoverChoices(
    BuildContext context,
    ProjectFolder folder,
  ) {
    final service = context.read<ProjectService>();
    return projectFolderThumbnailChoices(
      service.folders,
      service.projects,
      folder.id,
    );
  }

  void _changeFolderThumbnail(BuildContext context, ProjectFolder folder) {
    showFolderThumbnailDialog(
      context,
      folder: folder,
      choices: _folderCoverChoices(context, folder),
      onSave: ({required mode, sourceId, imagePath}) =>
          context.read<ProjectService>().setFolderThumbnail(
            folder.id,
            mode: mode,
            sourceId: sourceId,
            imagePath: imagePath,
          ),
    );
  }

  Widget _folderGridCard(BuildContext context, ProjectFolder folder) {
    final isSelected = selectedIds.contains(folder.id);
    final scheme = Theme.of(context).colorScheme;
    final selectionColor = scheme.secondary;
    final selectionForeground = scheme.onSecondary;
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (!isSelectionMode && onPickProject == null) {
          _showFolderSecondaryMenu(context, folder, details.globalPosition);
        }
      },
      onTap: isSelectionMode
          ? () => onSelectionChanged(folder.id)
          : () => onOpenFolder(folder.id),
      onLongPress: () => onLongPress(folder.id),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FolderThumbnail(
                      key: ValueKey('projectFolderCover_${folder.id}'),
                      folder: folder,
                      choices: _folderCoverChoices(context, folder),
                      defaultImagePath: _projectFolderCoverPath(
                        context,
                        folder,
                      ),
                    ),
                    _gridCardActions(
                      context,
                      menu: _folderMenu(context, folder),
                      isFavorite: folder.isFavorite,
                      itemId: folder.id,
                      onFavorite: () =>
                          _handleFolderAction(context, 'favorite', folder),
                    ),
                    if (isSelectionMode)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
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
              _gridCaption(context, folder.name, folder.parentFolderId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridCardActions(
    BuildContext context, {
    required Widget menu,
    required bool isFavorite,
    required String itemId,
    required VoidCallback onFavorite,
  }) {
    final showActions = !isSelectionMode && onPickProject == null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Selection-mode favorite markers are visual only; tapping still
        // selects the card, as before. Normal mode has real outlined buttons.
        if (!showActions && isFavorite)
          Positioned(
            left: 4,
            bottom: 4,
            child: Icon(
              Icons.star,
              size: CollectionActionFrame.glyphSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (showActions)
          Positioned(
            top: 4,
            right: 4,
            child: CollectionActionFrame(
              key: Key('collectionMenu_$itemId'),
              child: menu,
            ),
          ),
        if (showActions)
          Positioned(
            key: const Key('projectGridFavoriteBottomLeft'),
            left: 4,
            bottom: 4,
            child: CollectionFavoriteButton(
              favorite: isFavorite,
              itemId: itemId,
              tooltip: isFavorite
                  ? AppLocalizations.of(context)!.colorPickerFavoriteRemove
                  : AppLocalizations.of(context)!.colorPickerFavoriteAdd,
              onPressed: onFavorite,
            ),
          ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _projectMenuEntries(
    BuildContext context,
    Project project,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
      PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
      PopupMenuItem(
        value: 'thumbnail',
        child: Text(l10n.thumbnailChangeAction),
      ),
      PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
      PopupMenuItem(
        value: 'share',
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
    ];
  }

  List<PopupMenuEntry<String>> _folderMenuEntries(
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
      PopupMenuItem(
        value: 'thumbnail',
        child: Text(l10n.thumbnailChangeAction),
      ),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          folder.isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          l10n.homeMoveToTrash,
          style: TextStyle(color: ThemeService.activeColorScheme.error),
        ),
      ),
    ];
  }

  Future<void> _showEntryContextMenu(
    BuildContext context,
    Offset globalPosition,
    List<PopupMenuEntry<String>> entries,
    ValueChanged<String> onSelected,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final local = overlay.globalToLocal(globalPosition);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        local.dx,
        local.dy,
        overlay.size.width - local.dx,
        overlay.size.height - local.dy,
      ),
      items: entries,
    );
    if (context.mounted && result != null) onSelected(result);
  }

  void _showProjectSecondaryMenu(
    BuildContext context,
    Project project,
    Offset position,
  ) {
    if (context.read<ProjectService>().isFavoriteSaving(project.id)) return;
    _showEntryContextMenu(
      context,
      position,
      _projectMenuEntries(context, project),
      (action) => _handleAction(context, action, project),
    );
  }

  void _showFolderSecondaryMenu(
    BuildContext context,
    ProjectFolder folder,
    Offset position,
  ) {
    _showEntryContextMenu(
      context,
      position,
      _folderMenuEntries(context, folder),
      (action) => _handleFolderAction(context, action, folder),
    );
  }

  Widget _projectMenu(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    final saving = context.read<ProjectService>().isFavoriteSaving(project.id);
    return PopupMenuButton<String>(
      enabled: !saving,
      tooltip: saving ? l10n.homeTrashWorking : null,
      padding: EdgeInsets.zero,
      icon: saving
          ? SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
                semanticsLabel: l10n.homeTrashWorking,
              ),
            )
          : const Icon(Icons.more_vert, size: CollectionActionFrame.glyphSize),
      onSelected: (action) => _handleAction(context, action, project),
      itemBuilder: (_) => _projectMenuEntries(context, project),
    );
  }

  Widget _folderMenu(BuildContext context, ProjectFolder folder) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: CollectionActionFrame.glyphSize),
      onSelected: (action) => _handleFolderAction(context, action, folder),
      itemBuilder: (_) => _folderMenuEntries(context, folder),
    );
  }

  void _handleAction(BuildContext context, String action, Project project) {
    final service = context.read<ProjectService>();
    switch (action) {
      case 'open':
        context.push('/canvas/${project.id}');
      case 'rename':
        _showRenameDialog(context, project);
      case 'thumbnail':
        showProjectThumbnailDialog(context, project: project, service: service);
      case 'duplicate':
        final l10n = AppLocalizations.of(context)!;
        service.duplicateProject(
          project.id,
          namer: (name, taken) => numberedCopyName(l10n, name, taken),
        );
      case 'share':
        _createNiashare(context, project);
      case 'favorite':
        runProjectAction(context, () => service.toggleFavorite(project.id));
      case 'move':
        _showMoveProjectToFolderDialog(context, project);
      case 'delete':
        _deleteProject(context, service, project);
    }
  }

  /// お気に入り登録中は削除できない。
  /// Move to Trash and provide the same short-lived undo affordance as bulk move.
  Future<void> _deleteProject(
    BuildContext context,
    ProjectService service,
    Project project,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (project.isFavorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    if (!await runProjectTrashAction(
      context,
      () => service.deleteProject(project.id),
    )) {
      return;
    }
    if (!context.mounted) return;
    // 「元に戻す」はこの一覧の部品を通さない。最後の1件を移すと一覧は空の
    // 表示に替わり、消えた部品を通す「元に戻す」は何もせずに閉じていた。
    // 知らせは時間で消える（操作ボタン付きのSnackBarは既定では消えない）。
    showMovedToTrashSnackBar(ScaffoldMessenger.of(context), l10n, service, [
      project.id,
    ]);
  }

  Future<void> _handleFolderAction(
    BuildContext context,
    String action,
    ProjectFolder folder,
  ) async {
    final service = context.read<ProjectService>();
    switch (action) {
      case 'open':
        onOpenFolder(folder.id);
      case 'edit':
        _showEditFolderDialog(context, folder);
      case 'thumbnail':
        _changeFolderThumbnail(context, folder);
      case 'favorite':
        try {
          await service.toggleFolderFavorite(folder.id);
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  folderSaveFailureText(AppLocalizations.of(context)!, error),
                ),
              ),
            );
          }
        }
      case 'move':
        _showMoveFolderToFolderDialog(context, folder);
      case 'delete':
        _confirmDeleteFolder(context, folder);
    }
  }

  /// フォルダのメニューの「ゴミ箱へ移動」。選んでゴミ箱へ移すとき（ホームの
  /// 選択の帯）と同じく、中身（下の階層のフォルダ・作品）ごとゴミ箱へ移す：
  /// 同じ文で中身の件数を確かめ、お気に入りのフォルダ・作品が中にあれば
  /// 移さず、移した後は「元に戻す」で中身ごと戻せる（所有者の判断2。以前は
  /// 件数の確認も「元に戻す」も無かった）。
  void _confirmDeleteFolder(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final subtree = service.folderSubtreeIds(folder.id);
    bool includesFavorite() =>
        service.folders.any((f) => f.id == folder.id && f.isFavorite) ||
        service.projects.any(
          (p) => p.isFavorite && subtree.contains(p.folderId),
        );
    // お気に入り登録中は削除できない（中の作品も）。断りの知らせは、出て
    // いる他の機能の知らせ（ゴミ箱へ移した知らせの「元に戻す」等）を閉じず
    // に後へ並べる（作品のメニューの断りと同じ）。
    if (includesFavorite()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    final counts = service.folderContentCounts(folder.id);
    final descendantText = counts.projects + counts.folders == 0
        ? ''
        : '\n${l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(counts.projects, counts.folders))}';
    // 読めていない作品は、どのフォルダの作品か分からず数えられない。
    // ゴミ箱の外にあるものはこのフォルダの作品かもしれない（選んで移す
    // ときと同じ）。
    final unreadText = service.mayHoldUnreadWorksOutsideTrash
        ? '\n${l10n.homeMoveToTrashUnreadNote}'
        : '';
    // 移した後はフォルダのカード（この部品）が一覧から消えるので、知らせの
    // 出し先は先に取っておく。
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homeMoveToTrash,
        message: l10n.homeMoveToTrashConfirm(1) + descendantText + unreadText,
        confirmLabel: l10n.commonMove,
        itemNames: [folder.name],
        onApply: () async {
          // 開いた後にお気に入りにした場合も、何も変える前に断る。
          if (includesFavorite()) throw const FavoriteProjectDeleteException();
          if (await service.moveFolderToTrash(folder.id) == null) return;
          showMovedToTrashSnackBar(
            messenger,
            l10n,
            service,
            const [],
            folderIds: [folder.id],
          );
        },
      ),
    );
  }

  /// .niashare（共有用ファイル）を作成し、共有シートを表示する。
  Future<void> _createNiashare(BuildContext context, Project project) {
    final service = context.read<ProjectService>();
    final materialService = context.read<MaterialService>();
    final fontService = context.read<FontService>();
    return runNiashareFlow(
      context,
      project,
      build: (options) async {
        final bundle = await materialService.buildShareBundle(
          project.id,
          options.materialTypes,
        );
        final fontBundle = options.includeFonts
            ? await buildFontShareBundle(service, fontService, project.id)
            : (files: <String, Uint8List>{}, manifest: null);
        return NiaproSerializer.saveShare(
          project: project,
          scenes: service.scenesOf(project.id),
          tileManager: service.tileManagerOf(project.id),
          materialFiles: bundle.files.isEmpty ? null : bundle.files,
          materialsManifest: bundle.manifest,
          fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
          fontsManifest: fontBundle.manifest,
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.commonRename,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        initialName: project.name,
        onSubmit: (name) =>
            context.read<ProjectService>().renameProject(project.id, name),
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
    final service = context.read<ProjectService>();
    // Keep each child immediately below its parent, with visible indentation.
    // The shared folderTree utility also excludes an attempted move into self.
    final folders = folderTree(service.folders, excluding: excludeFolderId);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: [for (final row in folders) row.folder],
        depths: {for (final row in folders) row.folder.id: row.depth},
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

/// 作品の.niashareの作成・共有を止め合う名前（[runNiashareFlow]が
/// `ExportShareService.runExclusive`へ渡す）。作成・共有の間は
/// `ExportShareService.isRunning(niashareKey(id))`が真になる。
String niashareKey(String projectId) => 'niashare:$projectId';

/// .niashare作成時の同梱の選択。
typedef NiashareIncludeOptions = ({
  Set<MaterialType> materialTypes,
  bool includeFonts,
});

/// 同梱の確認→共有ファイルの作成（[build]）→共有を、作品ごとに一度に1つだけ
/// 走らせる（ホームの一覧のメニュー・プロジェクト詳細・受け取った作品の
/// メニューで共通）。
///
/// 作成・共有の間は[niashareKey]の名前が走っていて、`ExportShareService.
/// running`が知らせる。作成は始めた画面より長く続くことがあるので、どの画面の
/// ボタン・メニューも自分の印ではなくそれを見て、進行中の見た目（押せない・
/// 進行中の印）にすること。始めた画面が途中で無くなっても、先に取っておいた
/// 通知先から、作成の失敗・共有できないことを知らせ、共有シートを開く
/// （黙って止めると、押せそうに見えて何も起きない時間ができる）。
/// 作成の失敗と、共有できない端末・共有の失敗は別のことなので、別の文で
/// 知らせる。
Future<void> runNiashareFlow(
  BuildContext context,
  Project project, {
  required Future<File> Function(NiashareIncludeOptions options) build,
}) async {
  final key = niashareKey(project.id);
  final handles = ExportShareHandles.of(context);
  if (ExportShareService.isRunning(key)) {
    // 進行中は入口を止めてあるが、届いた操作を黙って捨てない。
    handles.tell(handles.l10n.homeTrashWorking);
    return;
  }
  NiashareIncludeOptions? chosen;
  // 確認は一度に1つ（同じフレームの二度押しで2つ開かない）。
  await ExportShareService.runExclusive('$key:confirm', () async {
    chosen = await showMaterialIncludeDialog(context);
  });
  final options = chosen;
  if (options == null) return; // 取り消した（または、確認がもう開いている）
  final started = await ExportShareService.runExclusive(key, () async {
    final File file;
    try {
      file = await build(options);
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      handles.tell(handles.l10n.projectDetailNiashareFailedSnackbar('$error'));
      return;
    }
    await handles.share(file);
  });
  if (!started) handles.tell(handles.l10n.homeTrashWorking);
}

/// .niashare作成時の同梱選択ダイアログ（画像/動画/音声を
/// 種類ごとに選択できる。デフォルトは全種類ON。「フォントを含める」を
/// 選択した場合のみユーザー追加フォントも同梱する）。キャンセル時はnullを返す。
Future<NiashareIncludeOptions?> showMaterialIncludeDialog(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context)!;
  final selected = <MaterialType>{
    MaterialType.image,
    MaterialType.video,
    MaterialType.audio,
  };
  bool includeFonts = true;
  return showDialog<NiashareIncludeOptions>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        // 横向きのスマホ・低い画面・大きな文字では選択肢が入りきらないので、
        // 題名と選択肢をスクロールさせ、ボタンは下に残す。
        scrollable: true,
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
