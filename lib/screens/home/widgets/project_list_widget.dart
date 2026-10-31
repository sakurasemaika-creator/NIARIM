import 'package:niarim/services/theme_service.dart';

import 'dart:convert';
import 'dart:io';
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
import '../../../config/font_fallback.dart';
import '../../../widgets/empty_state_placeholder.dart';
import '../../../widgets/frame_preview_background.dart';
import '../../../widgets/project_trash_dialog.dart';
import '../../../utils/app_error_reporter.dart';
import 'folder_save_feedback.dart';
import 'folder_delete_dialog.dart';
import 'work_folder_move_sheet.dart';
import 'project_folder_edit_dialog.dart';
import '../../../utils/folder_persistence.dart';

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

/// Preserve the normal thumbnail ratio while making room for the action rail
/// and scaled caption, including the smallest grid tiles.
class _ProjectGridDelegate extends SliverGridDelegateWithMaxCrossAxisExtent {
  const _ProjectGridDelegate({
    required double maxExtent,
    required this.minHeight,
  }) : super(
         maxCrossAxisExtent: maxExtent,
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
    this.scrollController,
    this.header,
    this.projects,
    this.showFavoritesOnly = false,
    this.searchQuery = '',
    this.searchByTag = false,
    this.onPickProject,
    this.showEmptyCreateHint = true,
  });

  List<_Entry> _sorted(List<_Entry> src) {
    final list = List<_Entry>.from(src);
    switch (sortMode) {
      case ProjectSortMode.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case ProjectSortMode.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case ProjectSortMode.updatedAsc:
        list.sort((a, b) => a.sortDate.compareTo(b.sortDate));
      case ProjectSortMode.updatedDesc:
        list.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final source = projects ?? projectService.projects;
    final allFolders = projectService.folders;
    final folderIds = allFolders.map((f) => f.id).toSet();
    final rawQuery = searchQuery.trim().toLowerCase();
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
            .where(
              (p) =>
                  p.tags.any((tag) => tag.trim().toLowerCase().contains(query)),
            )
            .map((p) => _Entry.project(p))
            .toList();
      } else {
        entries = [
          ...allFolders
              .where((f) => f.name.toLowerCase().contains(query))
              .map((f) => _Entry.folder(f)),
          ...source
              .where((p) => p.name.toLowerCase().contains(query))
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
    final sorted = _sorted(entries);

    if (sorted.isEmpty) {
      if (header != null) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: header!),
            SliverFillRemaining(
              // The empty-state layout uses LayoutBuilder, which cannot
              // provide intrinsic heights to the non-scrollable variant.
              hasScrollBody: true,
              child: EmptyStatePlaceholder(
                icon: Icons.movie_creation_outlined,
                title: l10n.projectListEmptyTitle,
                hint: showEmptyCreateHint ? l10n.projectListEmptyHint : null,
              ),
            ),
          ],
        );
      }
      return EmptyStatePlaceholder(
        icon: Icons.movie_creation_outlined,
        title: l10n.projectListEmptyTitle,
        hint: showEmptyCreateHint ? l10n.projectListEmptyHint : null,
      );
    }

    if (viewMode == ProjectViewMode.detail) {
      if (header != null) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: header!),
            SliverList.builder(
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  _detailTile(context, l10n, sorted[index]),
            ),
          ],
        );
      }
      return ListView.builder(
        controller: scrollController,
        itemCount: sorted.length,
        itemBuilder: (context, index) =>
            _detailTile(context, l10n, sorted[index]),
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
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.localeOf(context),
    )..layout();
    final minimumHeight = 80 + caption.height + 8;
    caption.dispose();
    if (header != null) {
      return CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: header!),
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid.builder(
              gridDelegate: _ProjectGridDelegate(
                maxExtent: targetExtent,
                minHeight: minimumHeight,
              ),
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  _gridCard(context, sorted[index]),
            ),
          ),
        ],
      );
    }
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: _ProjectGridDelegate(
        maxExtent: targetExtent,
        minHeight: minimumHeight,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _gridCard(context, sorted[index]),
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

  TextStyle _captionStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    color:
        Theme.of(context).popupMenuTheme.textStyle?.color ??
        Theme.of(context).colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    fontFamily: 'Kuramubon',
    fontFamilyFallback: kHeadingFontFallback,
  );

  Widget _gridCaption(BuildContext context, String name) => ColoredBox(
    color:
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Tooltip(
        message: name,
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _captionStyle(context),
        ),
      ),
    ),
  );

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
      subtitle: Text(
        l10n.homeProjectMeta(project.fps, project.durationSeconds),
      ),
      trailing: (isSelectionMode || onPickProject != null)
          ? null
          : _projectMenu(context, project),
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
    final color = folder.color != null ? Color(folder.color!) : null;
    return ListTile(
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionChanged(folder.id),
            )
          : Icon(Icons.folder, color: color, size: 32),
      title: Text(
        folder.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (folder.isFavorite)
            Builder(
              builder: (themeContext) => Icon(
                Icons.star,
                color: Theme.of(themeContext).colorScheme.primary,
                size: 18,
              ),
            ),
          if (!isSelectionMode && onPickProject == null)
            _folderMenu(context, folder),
        ],
      ),
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
              _gridCaption(context, project.name),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderGridCard(BuildContext context, ProjectFolder folder) {
    final isSelected = selectedIds.contains(folder.id);
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final selectionColor = scheme.secondary;
    final selectionForeground = scheme.onSecondary;
    final color = folder.color != null ? Color(folder.color!) : primary;
    return GestureDetector(
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
                        DecoratedBox(
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
                          child: Center(
                            child: Icon(
                              Icons.folder_rounded,
                              color: color,
                              size: 46,
                            ),
                          ),
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
                  _gridCaption(context, folder.name),
                ],
              ),
              _gridCardActions(
                context,
                menu: _folderMenu(context, folder),
                isFavorite: folder.isFavorite,
              ),
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
  }) {
    final scheme = Theme.of(context).colorScheme;
    final showMenu = !isSelectionMode && onPickProject == null;
    // Menu remains top-right. Favorite is independently anchored to the
    // thumbnail bottom-left, including transparent checkerboard thumbnails.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showMenu)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Theme.of(context).cardTheme.color ?? scheme.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: SizedBox.square(dimension: 48, child: menu),
            ),
          ),
        if (isFavorite)
          Positioned(
            key: const Key('projectGridFavoriteBottomLeft'),
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Builder(
                builder: (themeContext) => Icon(
                  Icons.star,
                  color: Theme.of(themeContext).colorScheme.primary,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _projectMenu(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _handleAction(context, action, project),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
        PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
        PopupMenuItem(
          value: 'duplicate',
          child: Text(l10n.themeDuplicateAction),
        ),
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
      ],
    );
  }

  Widget _folderMenu(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _handleFolderAction(context, action, folder),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
        PopupMenuItem(
          value: 'edit',
          child: Text(l10n.projectListEditFolderAction),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: Text(
            folder.isFavorite
                ? l10n.colorPickerFavoriteRemove
                : l10n.colorPickerFavoriteAdd,
          ),
        ),
        PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            l10n.commonDelete,
            style: TextStyle(color: ThemeService.activeColorScheme.error),
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, String action, Project project) {
    final service = context.read<ProjectService>();
    switch (action) {
      case 'open':
        context.push('/canvas/${project.id}');
      case 'rename':
        _showRenameDialog(context, project);
      case 'duplicate':
        service.duplicateProject(project.id);
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
  Future<void> _deleteProject(
    BuildContext context,
    ProjectService service,
    Project project,
  ) async {
    if (project.isFavorite) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    await runProjectTrashAction(
      context,
      () => service.deleteProject(project.id),
    );
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

  /// フォルダ削除時、中のプロジェクト・子フォルダをルートへ戻す旨を確認する
  /// （フォルダ削除時は中のプロジェクトをルートへ戻すか確認ダイアログを表示する）。
  void _confirmDeleteFolder(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    // お気に入り登録中は削除できない。
    if (folder.isFavorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    final service = context.read<ProjectService>();
    showDialog<void>(
      context: context,
      builder: (_) => FolderDeleteDialog(
        folderName: folder.name,
        body: l10n.projectListDeleteFolderConfirmBody(folder.name),
        onDelete: () => service.deleteFolder(folder.id),
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
    final controller = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().renameProject(
                project.id,
                controller.text,
              );
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
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
    final folders = service.folders
        .where(
          (f) =>
              f.id != excludeFolderId &&
              !service.isFolderDescendantOf(f.id, excludeFolderId),
        )
        .toList();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => WorkFolderMoveSheet(
        folders: folders,
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
