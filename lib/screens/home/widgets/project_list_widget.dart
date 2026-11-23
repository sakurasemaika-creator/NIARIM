import 'package:niarim/services/theme_service.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide MaterialType;
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
import '../../../widgets/checked_menu_item.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/korean_words_text.dart';
import '../../../widgets/export_share_feedback.dart';
import '../../../widgets/frame_preview_background.dart';
import '../../../widgets/project_trash_dialog.dart';
import '../../../widgets/moved_to_trash_snack_bar.dart';
import '../../../widgets/project_duplicated_snack_bar.dart';
import '../../../widgets/name_entry_dialog.dart';
import '../../../widgets/collection_action_controls.dart';
import '../../../widgets/collection_card_keys.dart';
import '../../../widgets/collection_tile_layout.dart';
import '../../../widgets/date_line_text.dart';
import '../../../widgets/keep_together_text.dart';
import '../../../widgets/menu_action_label.dart';
import '../../../widgets/secondary_click_menu.dart';
import '../../../utils/app_error_reporter.dart';
import '../../../utils/duplicate_name.dart';
import '../../../utils/responsive_tile_defaults.dart';
import 'folder_save_feedback.dart';
import 'work_folder_move_sheet.dart';
import 'project_folder_edit_dialog.dart';
import 'folder_thumbnail.dart';
import 'project_thumbnail_dialog.dart';
import '../../../utils/folder_persistence.dart';
import '../../../utils/folder_tree.dart';
import '../../../utils/name_collation.dart';
import '../../../utils/file_failure_reason.dart';

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
    // 韓国語の語は途中で行を変えない（普通のTextだと「정리하 / 는」と
    // 切れた）。
    hint: rename
        ? null
        : messageText(
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
/// 一覧の表示のメニュー：表示形式（タイル・詳細）と大きさ（大・中・小）を
/// 別々に選ぶ（PCのファイルの一覧と同じ考え方）。大きさはそれぞれの表示形式の
/// 中で選び、表示形式を切り替えたときはその形式の既定の大きさ（タイルは画面の
/// 幅で決まる大きさ、詳細は中）から始める。
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
    String sizeLabel(CollectionViewSize size) => switch (size) {
      CollectionViewSize.large => l10n.homeViewModeLarge,
      CollectionViewSize.medium => l10n.homeViewModeMedium,
      CollectionViewSize.small => l10n.homeViewModeSmall,
    };
    return PopupMenuButton<ProjectViewMode>(
      icon: const Icon(Icons.view_module),
      tooltip: l10n.homeViewModeTooltip,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        MenuSectionHeading<ProjectViewMode>(l10n.homeViewLayoutHeading),
        checkedMenuItem(
          context,
          value: value.isDetail
              ? ProjectViewMode.of(
                  detail: false,
                  size: defaultTileSizeFor(MediaQuery.sizeOf(context).width),
                )
              : value,
          checked: !value.isDetail,
          label: l10n.homeViewLayoutTiles,
          icon: Icons.grid_view,
        ),
        checkedMenuItem(
          context,
          value: value.isDetail ? value : ProjectViewMode.detail,
          checked: value.isDetail,
          label: l10n.homeViewModeDetail,
          icon: Icons.view_list,
        ),
        const PopupMenuDivider(),
        MenuSectionHeading<ProjectViewMode>(l10n.homeViewSizeHeading),
        for (final size in CollectionViewSize.values)
          checkedMenuItem(
            context,
            value: ProjectViewMode.of(detail: value.isDetail, size: size),
            checked: value.size == size,
            label: sizeLabel(size),
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

  /// Space below the final result so it can scroll past Home's controls.
  final double? bottomClearance;

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
  final VoidCallback? onCreateProject;

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
    this.bottomClearance,
    this.header,
    this.projects,
    this.showFavoritesOnly = false,
    this.searchQuery = '',
    this.searchByTag = false,
    this.onPickProject,
    this.showEmptyCreateHint = true,
    this.onCreateProject,
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

  /// 探す言葉（大文字・小文字、全角・半角、カタカナ・ひらがなの違いを
  /// そろえ、タグで探すときの先頭の`#`を除いたもの）。
  static String _effectiveQuery(String searchQuery, bool searchByTag) {
    final rawQuery = foldName(searchQuery).trim();
    // Accept both `tag` and `#tag` input in tag mode.
    return searchByTag && rawQuery.startsWith('#')
        ? rawQuery.substring(1).trimLeft()
        : rawQuery;
  }

  /// 一覧がフォルダの外も含めて全体から探しているか。入力が空・空白だけ・
  /// タグの印だけのときは、今いるフォルダの中身を出している。
  static bool searchesEverywhere(
    String searchQuery, {
    required bool searchByTag,
  }) => _effectiveQuery(searchQuery, searchByTag).isNotEmpty;

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
    final query = _effectiveQuery(searchQuery, searchByTag);

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
      // 一覧のどこかにお気に入りがあるか（お気に入りだけで空のとき、登録の
      // 仕方を出すのは1つも無いときだけ）。
      final hasFavorites =
          showFavoritesOnly &&
          (source.any((p) => p.isFavorite) ||
              allFolders.any((f) => f.isFavorite));
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
            // 残りの高さを埋めるだけにする（中身の方が高いときだけその分
            // スクロールする）。スクロールする中身として置くと、見出しの
            // 高さの分だけ一覧がスクロールでき、何も無いのに画面いっぱいの
            // つまみが出ていた。丸い印は、自分でスクロールするときと同じく
            // 残りの高さに入る大きさにする（低い画面・大きな文字で、作り方の
            // 案内が浮かぶボタンの下へ押し出されない）。
            EmptyStateSliver(
              builder: (size) => _emptyState(
                l10n,
                hiddenByFavorites: hiddenByFavorites,
                hasFavorites: hasFavorites,
                scrollable: false,
                fitIn: size,
              ),
            ),
          ],
        );
      }
      return _emptyState(
        l10n,
        hiddenByFavorites: hiddenByFavorites,
        hasFavorites: hasFavorites,
      );
    }

    if (viewMode.isDetail) {
      return CollectionDetailSizeScope(
        size: viewMode.size,
        child: _detailList(context, l10n, sorted),
      );
    }

    // カード基準サイズ（大/中/小）を軸に、画面幅に応じて列数が自然に増減する
    // グリッドを使う（PC/DeXモードの広い画面でも余白だらけにならないように）。
    final targetExtent = viewMode.tileExtent;
    // 検索の結果には、入っているフォルダの場所の行を添える。
    final gridDelegate = collectionTileGridDelegate(
      context,
      targetExtent,
      locationRow: searchQuery.trim().isNotEmpty,
      actionBandHeight: onPickProject == null
          ? CollectionActionFrame.targetExtent
          : 0,
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
          // 画面の下の帯の分も空ける（詳細の一覧と同じ）。
          SliverToBoxAdapter(
            child: SizedBox(
              key: const Key('homeProjectListEndClearance'),
              height:
                  bottomClearance ?? 104 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
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
  Widget _emptyState(
    AppLocalizations l10n, {
    bool hiddenByFavorites = false,
    bool hasFavorites = false,
    bool scrollable = true,
    Size? fitIn,
  }) {
    // ホームでは左下・右下に丸いボタンが浮くので、絞り込みを外すボタンや
    // 作り方の案内がその下に入らないよう、下にその分を空ける（選ぶ専用
    // 画面には無い）。空けるのはスクロールする中身の下なので、低い画面でも
    // 見える所は狭くならない（EmptyStatePlaceholder.clearFloatingButtons）。
    final clearFloatingButtons = onPickProject == null;
    final query = searchQuery.trim();
    if (query.isNotEmpty && !hiddenByFavorites) {
      return EmptyStatePlaceholder(
        clearFloatingButtons: clearFloatingButtons,
        scrollable: scrollable,
        fitIn: fitIn,
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
      // お気に入りがほかの場所にあるのに「お気に入りの作品はありません」と
      // 言わない（登録済みの利用者に登録を促していた）。探している言葉に
      // 当たるお気に入りが無い・このフォルダに無い・フォルダの外に無い（どれも
      // フォルダの中にある）のどれかを言う。
      final title = query.isNotEmpty
          ? l10n.projectListNoFavoriteMatchTitle(query)
          : !hasFavorites
          ? l10n.projectListNoFavoritesTitle
          : currentFolderId != null
          ? l10n.projectListNoFavoritesInFolderTitle
          : l10n.projectListNoFavoritesOutsideFoldersTitle;
      return EmptyStatePlaceholder(
        clearFloatingButtons: clearFloatingButtons,
        scrollable: scrollable,
        fitIn: fitIn,
        icon: Icons.star_border,
        title: title,
        // 登録の仕方は、お気に入りが1つも無いときだけ。作品・フォルダの
        // メニューを指すので、カードにメニューの無い選ぶ専用画面
        // （[onPickProject]使用時）では出さない。
        hint: onPickProject == null && !hasFavorites
            ? l10n.projectListNoFavoritesHint
            : null,
        action: onShowAll == null
            ? null
            : OutlinedButton(
                onPressed: onShowAll,
                child: Text(l10n.projectListShowAll),
              ),
      );
    }
    final inFolder = currentFolderId != null;
    final create = inFolder || isSelectionMode || onPickProject != null
        ? null
        : onCreateProject;
    return EmptyStatePlaceholder(
      clearFloatingButtons: clearFloatingButtons,
      scrollable: scrollable,
      fitIn: fitIn,
      icon: inFolder ? Icons.folder_open : Icons.movie_creation_outlined,
      title: inFolder
          ? l10n.projectListEmptyFolderTitle
          : l10n.projectListEmptyTitle,
      hint: create == null && showEmptyCreateHint
          ? l10n.projectListEmptyHint
          : null,
      action: create == null
          ? null
          : FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.note_add_outlined),
              label: Text(
                l10n.homeAddSheetNewProject,
                textAlign: TextAlign.center,
              ),
            ),
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
        // 用紙は作品の色（テーマの色ではない）なので、印も用紙で読める色。
        child: Center(
          child: Icon(
            Icons.image,
            color: paperMarkColor(project.backgroundColor),
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

  /// 詳細（行）の一覧。
  Widget _detailList(
    BuildContext context,
    AppLocalizations l10n,
    List<_Entry> sorted,
  ) {
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
              // 右クリックで行の︙と同じメニューを開く（カードと同じ）。
              SecondaryClickMenu(
                child: _detailTile(context, l10n, sorted[index]),
              ),
            ),
          ),
          // 浮かぶボタンは画面の下の帯（ジェスチャー・3ボタン）の分だけ
          // 上がるので、末尾の余白にも帯の分を足す（足さないと、一番下
          // まで送っても最後の行の名前が＋の下に入った）。
          SliverToBoxAdapter(
            child: SizedBox(
              key: const Key('homeProjectListEndClearance'),
              height:
                  bottomClearance ?? 104 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: sorted.length,
      itemBuilder: (context, index) => _withCutFeedback(
        context,
        sorted[index],
        SecondaryClickMenu(child: _detailTile(context, l10n, sorted[index])),
      ),
    );
  }

  Widget _detailTile(
    BuildContext context,
    AppLocalizations l10n,
    _Entry entry,
  ) {
    if (entry.isFolder) return _folderDetailTile(context, entry.folder!);
    final project = entry.project!;
    final isSelected = selectedIds.contains(project.id);
    // 行の先頭の絵の大きさは詳細の大・中・小と画面の幅で決まる。
    final thumb = collectionDetailThumbExtent(context, 48);
    final actionsBelow = _actionsBelowName(context);
    final date = DateLineText(
      [
        l10n.homeProjectMeta(project.fps, project.durationSeconds),
        l10n.projectListUpdatedOn(project.updatedAt),
        if (_searchLocation(context, project.folderId) case final location?)
          l10n.projectListInFolder(location),
      ].join('\n'),
      when: project.updatedAt,
      localeName: l10n.localeName,
      // 「12fps · 10秒」の数と単位も途中で折り返さない。日時に添える語
      // （「更新」）も字の途中で折り返さない。
      keep: [
        ...numberUnitParts(
          l10n.homeProjectMeta(project.fps, project.durationSeconds),
        ),
        ...dateLabelWords(l10n.projectListUpdatedOn(project.updatedAt)),
      ],
    );
    // 星と︙の押せる所（48×48）が重ならないよう、隙間を分け合う。
    final actions = CollectionActionRow(
      children: [
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
        CollectionActionFrame(child: _projectMenu(context, project)),
      ],
    );
    return ListTile(
      minTileHeight: collectionDetailMinRowHeight(thumb, 48),
      contentPadding: actionsBelow
          ? const EdgeInsets.symmetric(horizontal: 8)
          : null,
      horizontalTitleGap: actionsBelow ? 8 : 16,
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionChanged(project.id),
            )
          : SizedBox(
              width: thumb,
              height: thumb,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _thumbnail(context, project, displayWidth: thumb),
              ),
            ),
      // 韓国語の名前は語の途中で、複製の名前の印（「(コピー 2)」）は印の
      // 途中で行を変えない。折り返した行どうしが重ならない行の高さ。
      title: KoreanWordsText(
        project.name,
        copyMarks: copyMarkParts(project.name),
        keepJapaneseLineStarts: true,
        style: const TextStyle(height: kWrappedNameLineHeight),
      ),
      // 2行目は最後に保存した日時（その言語の日付と時刻の書き方）。検索の
      // 結果には、入っているフォルダを添える。
      subtitle: actionsBelow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                date,
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            )
          : date,
      trailing: (isSelectionMode || onPickProject != null || actionsBelow)
          ? null
          : actions,
      onTap: isSelectionMode
          ? () => onSelectionChanged(project.id)
          : onPickProject != null
          ? () => onPickProject!(project.id)
          : () => context.push('/project/${project.id}'),
      onLongPress: () => onLongPress(project.id),
      // 行の︙の押せる所は行の右の余白へも届く（ListTileは余白の内側に
      // trailingを置き、その外を押しても届かないため）。
    ).withCollectionActionReach().cardKeyboard(
      onSelect: _selectByKey(project.id),
    );
  }

  /// キーボードのSpaceで[id]の項目を選ぶ（長押しと同じ。選んでいる間は
  /// 選ぶ・外すの切り替え）。選ぶ専用画面（[onPickProject]）には選ぶ操作が
  /// 無いので null（SpaceはEnterと同じく開く）。
  VoidCallback? _selectByKey(String id) => onPickProject != null
      ? null
      : () => isSelectionMode ? onSelectionChanged(id) : onLongPress(id);

  /// 狭い画面（幅360以下）・大きな文字（1.5倍以上）の詳細の行は、星・︙を
  /// 名前の横ではなく日時の下へ回す。横に置くと名前の欄が120px前後しか
  /// 残らず、名前が語・数の途中で折れた（「Scene1 / 0」）。
  bool _actionsBelowName(BuildContext context) =>
      !isSelectionMode &&
      onPickProject == null &&
      MediaQuery.sizeOf(context).width <= 360 &&
      MediaQuery.textScalerOf(context).scale(1) >= 1.5;

  Widget _folderDetailTile(BuildContext context, ProjectFolder folder) {
    final isSelected = selectedIds.contains(folder.id);
    final thumb = collectionDetailThumbExtent(context, 48);
    final compactLargeTextLayout = _actionsBelowName(context);
    final folderDate = DateLineText(
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
      // 日時に添える語（中国語の「创建」等）を字の途中で折り返さない。
      keep: dateLabelWords(
        AppLocalizations.of(
          context,
        )!.projectListFolderCreatedOn(folder.createdAt),
      ),
    );
    final folderActions = CollectionActionRow(
      children: [
        CollectionFavoriteButton(
          itemId: folder.id,
          favorite: folder.isFavorite,
          tooltip: folder.isFavorite
              ? AppLocalizations.of(context)!.colorPickerFavoriteRemove
              : AppLocalizations.of(context)!.colorPickerFavoriteAdd,
          onPressed: () => _handleFolderAction(context, 'favorite', folder),
        ),
        CollectionActionFrame(child: _folderMenu(context, folder)),
      ],
    );
    return ListTile(
      minTileHeight: collectionDetailMinRowHeight(thumb, 48),
      contentPadding: compactLargeTextLayout
          ? const EdgeInsets.symmetric(horizontal: 8)
          : null,
      horizontalTitleGap: compactLargeTextLayout ? 8 : 16,
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionChanged(folder.id),
            )
          : SizedBox(
              width: thumb,
              height: thumb,
              child: FolderThumbnail(
                folder: folder,
                choices: _folderCoverChoices(context, folder),
                defaultImagePath: _projectFolderCoverPath(context, folder),
              ),
            ),
      title: KoreanWordsText(
        folder.name,
        copyMarks: copyMarkParts(folder.name),
        keepJapaneseLineStarts: true,
        breakLongLatinWords: true,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          height: kWrappedNameLineHeight,
        ),
      ),
      // フォルダを作った日時（「更新日時」の並びでフォルダに使う日時）。
      // 検索の結果には、入っているフォルダを添える。
      subtitle: compactLargeTextLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                folderDate,
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: folderActions,
                ),
              ],
            )
          : folderDate,
      trailing: (!isSelectionMode && onPickProject == null)
          ? (compactLargeTextLayout ? null : folderActions)
          : null,
      // フォルダは選ぶ専用画面でも通常どおり潜れる（[onPickProject]は
      // 作品タップ時のみに関わる）。
      onTap: isSelectionMode
          ? () => onSelectionChanged(folder.id)
          : () => onOpenFolder(folder.id),
      onLongPress: () => onLongPress(folder.id),
    ).withCollectionActionReach().cardKeyboard(
      onSelect: _selectByKey(folder.id),
    );
  }

  bool get _showsGridActions => !isSelectionMode && onPickProject == null;

  Widget _gridPicture(
    BuildContext context, {
    required Widget cover,
    required bool isFavorite,
    Widget? selectionMarker,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      cover,
      if (!_showsGridActions && isFavorite)
        Positioned(
          left: 4,
          bottom: 4,
          child: Icon(
            Icons.star,
            size: CollectionActionFrame.glyphSize,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ?selectionMarker,
    ],
  );

  Widget _gridCard(BuildContext context, _Entry entry) {
    if (entry.isFolder) return _folderGridCard(context, entry.folder!);
    final project = entry.project!;
    final isSelected = selectedIds.contains(project.id);
    final scheme = Theme.of(context).colorScheme;
    final selectionColor = scheme.secondary;
    final selectionForeground = scheme.onSecondary;
    final open = isSelectionMode
        ? () => onSelectionChanged(project.id)
        : onPickProject != null
        ? () => onPickProject!(project.id)
        : () => context.push('/project/${project.id}');
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (!isSelectionMode && onPickProject == null) {
          _showProjectSecondaryMenu(context, project, details.globalPosition);
        }
      },
      onTap: open,
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
        // menu-surface: n/a — 絵（用紙の色）の上に印を描くカード。名前は自分でメニューの文字色を読む。
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
                child: _gridPicture(
                  context,
                  cover: _thumbnail(context, project),
                  isFavorite: project.isFavorite,
                  selectionMarker: isSelectionMode
                      ? Positioned(
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
                                  color: ThemeService
                                      .activeColorScheme
                                      .onSurface
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
                        )
                      : null,
                ),
              ),
              _gridCaption(context, project.name, project.folderId),
              if (onPickProject == null)
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
            ],
          ),
        ),
      ),
      // カードの本体もTabで止まり、Enterで開き、Spaceで選ぶ（以前は星と︙に
      // しか止まらず、キーボードだけではカードを開けず、選べなかった）。
    ).focusableCard(
      onActivate: open,
      onSelect: _selectByKey(project.id),
      borderRadius: BorderRadius.circular(14),
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
    final open = isSelectionMode
        ? () => onSelectionChanged(folder.id)
        : () => onOpenFolder(folder.id);
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (!isSelectionMode && onPickProject == null) {
          _showFolderSecondaryMenu(context, folder, details.globalPosition);
        }
      },
      onTap: open,
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
        // menu-surface: n/a — 絵（用紙の色）の上に印を描くカード。名前は自分でメニューの文字色を読む。
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
                child: _gridPicture(
                  context,
                  cover: FolderThumbnail(
                    key: ValueKey('projectFolderCover_${folder.id}'),
                    folder: folder,
                    choices: _folderCoverChoices(context, folder),
                    defaultImagePath: _projectFolderCoverPath(context, folder),
                  ),
                  isFavorite: folder.isFavorite,
                  selectionMarker: isSelectionMode
                      ? Positioned(
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
                        )
                      : null,
                ),
              ),
              _gridCaption(context, folder.name, folder.parentFolderId),
              if (onPickProject == null)
                _gridCardActions(
                  context,
                  menu: _folderMenu(context, folder),
                  isFavorite: folder.isFavorite,
                  itemId: folder.id,
                  onFavorite: () =>
                      _handleFolderAction(context, 'favorite', folder),
                ),
            ],
          ),
        ),
      ),
      // 作品のカードと同じく、本体もTabで止まり、Enterで開き、Spaceで選ぶ。
    ).focusableCard(
      onActivate: open,
      onSelect: _selectByKey(folder.id),
      borderRadius: BorderRadius.circular(14),
    );
  }

  Widget _gridCardActions(
    BuildContext context, {
    required Widget menu,
    required bool isFavorite,
    required String itemId,
    required VoidCallback onFavorite,
  }) {
    if (isSelectionMode) return CollectionTileActions.selectionSpace;
    final l10n = AppLocalizations.of(context)!;
    return CollectionTileActions(
      compact: viewMode.size == CollectionViewSize.small,
      children: [
        CollectionFavoriteButton(
          favorite: isFavorite,
          itemId: itemId,
          tooltip: isFavorite
              ? l10n.colorPickerFavoriteRemove
              : l10n.colorPickerFavoriteAdd,
          onPressed: onFavorite,
        ),
        CollectionActionFrame(key: Key('collectionMenu_$itemId'), child: menu),
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
        // メニューの文字色のまま、印のアイコンと文で知らせる。
        child: MenuActionLabel(
          icon: Icons.delete_outline,
          label: l10n.projectDetailTrashMenuItem,
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
      PopupMenuItem(value: 'duplicate', child: Text(l10n.commonDuplicate)),
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
        child: MenuActionLabel(
          icon: Icons.delete_outline,
          label: l10n.homeMoveToTrash,
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
        // プロジェクト詳細の「複製」と同じく、できた複製の名前を知らせる。
        duplicateProjectWithNotice(
          context,
          service,
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
      showTrashRefusedSnackBar(
        ScaffoldMessenger.of(context),
        l10n.commonFavoriteDeleteBlocked,
      );
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
      case 'duplicate':
        final l10n = AppLocalizations.of(context)!;
        await runProjectAction(
          context,
          () => service.duplicateFolder(
            folder.id,
            targetParentId: folder.parentFolderId,
            name: l10n.projectDuplicateName(folder.name),
            namer: (name, taken) => numberedCopyName(l10n, name, taken),
          ),
        );
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
    // 下の階層のお気に入りのフォルダも見る（以前は一番上のフォルダしか
    // 見ず、中のお気に入りのフォルダを確かめずにゴミ箱へ移した）。
    bool includesFavorite() =>
        service.folders.any((f) => subtree.contains(f.id) && f.isFavorite) ||
        service.projects.any(
          (p) => p.isFavorite && subtree.contains(p.folderId),
        );
    // お気に入り登録中は削除できない（中の作品も）。断りの知らせは、出て
    // いる他の機能の知らせ（ゴミ箱へ移した知らせの「元に戻す」等）を閉じず
    // に後へ並べる（作品のメニューの断りと同じ）。
    if (includesFavorite()) {
      // フォルダ自身ではなく中の作品・フォルダがお気に入りなら、それが
      // 理由だと言う（「お気に入り登録中は削除できません」だけでは、どれが
      // お気に入りか分からなかった）。
      final folderIsFavorite = service.folders.any(
        (f) => f.id == folder.id && f.isFavorite,
      );
      showTrashRefusedSnackBar(
        ScaffoldMessenger.of(context),
        folderIsFavorite
            ? l10n.commonFavoriteDeleteBlocked
            : l10n.homeTrashFolderHoldsFavorite,
      );
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
        confirmLabel: l10n.homeMoveToTrash,
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
        return NiaproSerializer.saveShare(
          project: project,
          scenes: service.scenesOf(project.id),
          tileManager: service.tileManagerOf(project.id),
          materialFiles: bundle.files.isEmpty ? null : bundle.files,
          materialsManifest: bundle.manifest,
          fontsManifest: projectFontNamesManifest(
            service,
            fontService,
            project.id,
          ),
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
typedef NiashareIncludeOptions = ({Set<MaterialType> materialTypes});

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
      handles.tell(
        handles.l10n.projectDetailNiashareFailedSnackbar(
          fileFailureReason(handles.l10n, error),
        ),
      );
      return;
    }
    await handles.share(file);
  });
  if (!started) handles.tell(handles.l10n.homeTrashWorking);
}

/// .niashare作成時の同梱選択ダイアログ（画像/動画/音声を
/// 種類ごとに選択できる）。
/// キャンセル時はnullを返す。
Future<NiashareIncludeOptions?> showMaterialIncludeDialog(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context)!;
  final selected = <MaterialType>{
    MaterialType.image,
    MaterialType.video,
    MaterialType.audio,
  };
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.projectListShareFontNamesHint)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (materialTypes: selected)),
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    ),
  );
}

/// 共有ファイルに、作品で使った追加フォントの名前を記録する。
String? projectFontNamesManifest(
  ProjectService projects,
  FontService fonts,
  String projectId,
) {
  final usedFamilies = projects.usedFontFamiliesOf(projectId);
  return NiaproSerializer.encodeFontNames({
    for (final font in fonts.fonts)
      if (usedFamilies.contains(fonts.familyNameOf(font)))
        font.id: font.displayName,
  });
}

/// 個人の設定引き継ぎで使うフォントの実ファイルとマニフェストを作成する。
Future<({Map<String, Uint8List> files, String? manifest})> buildFontShareBundle(
  ProjectService projectService,
  FontService fontService,
  String projectId, {
  bool forSharing = true,
}) async {
  final usedFamilies = projectService.usedFontFamiliesOf(projectId);
  final files = <String, Uint8List>{};
  final manifestList = <Map<String, dynamic>>[];
  for (final font in fontService.fonts) {
    if (!usedFamilies.contains(fontService.familyNameOf(font))) continue;
    final bytes = await fontService.readFontBytes(font);
    if (bytes == null) continue;
    final notice = forSharing
        ? await fontService.licenseNoticeForShare(font, bytes)
        : font.licenseNotice;
    files[font.fileName] = bytes;
    if (notice != null) {
      files['${font.fileName}.license.txt'] = Uint8List.fromList(
        utf8.encode(notice),
      );
    }
    manifestList.add({
      'id': font.id,
      'displayName': font.displayName,
      'fileName': font.fileName,
    });
  }
  if (files.isEmpty) return (files: <String, Uint8List>{}, manifest: null);
  return (files: files, manifest: jsonEncode(manifestList));
}
