import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/font_asset.dart';
import '../../services/font_service.dart';
import '../../services/project_service.dart';
import '../../services/watermark_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../utils/file_size_label.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/first_that_fits.dart';
import '../../widgets/fit_or_icon_tab_bar.dart';
import '../../widgets/help_button.dart';
import 'font_catalog_tab.dart';
import '../../config/font_fallback.dart';
import '../../config/accent_text_theme.dart';

/// フォント管理画面（設定 → フォント管理）。
/// 3つのタブで構成する。
/// - ダウンロード済み：端末に取り込み済みのフォント一覧（お気に入り対応）
/// - 探してDL：Google Fonts全書体からのオンデマンドダウンロード
/// - 読み込み：端末に保存済みのTTF/OTFファイルを選んで取り込む
/// オンデマンドDL・端末読み込みいずれから取り込んだフォントも、
/// 「ダウンロード済み」タブへ自動的に反映される。
class FontSettingsScreen extends StatelessWidget {
  const FontSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          // 入らない幅では画面名を出さない（省略記号で切らない）。
          title: FitOrHideTitle(l10n.settingsFontTitle),
          // ヘルプ項目「フォント管理」はテキストツールの説明へ統合済み。
          actions: const [HelpButton(topic: 'テキストツール')],
          // 名前が全部入らない幅ではアイコンだけ（名前は吹き出しと読み上げ）。
          bottom: FitOrIconTabBar(
            tabs: [
              FitOrIconTab(
                icon: Icons.download_done_outlined,
                label: l10n.fontSettingsTabDownloaded,
              ),
              FitOrIconTab(
                icon: Icons.travel_explore_outlined,
                label: l10n.fontSettingsTabSearch,
              ),
              FitOrIconTab(
                icon: Icons.upload_file_outlined,
                label: l10n.fontSettingsTabImport,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DownloadedFontsTab(), FontCatalogTab(), _ImportFontTab()],
        ),
      ),
    );
  }
}

/// 「ダウンロード済み」タブ：端末に取り込み済みのフォント一覧
/// （オンデマンドDL・端末読み込み・従来の＋追加、いずれの経路で取り込んだ
/// ものも含む）。検索・お気に入り絞り込み・並び替え・削除に対応する。
class _DownloadedFontsTab extends StatefulWidget {
  const _DownloadedFontsTab();

  @override
  State<_DownloadedFontsTab> createState() => _DownloadedFontsTabState();
}

class _DownloadedFontsTabState extends State<_DownloadedFontsTab>
    with AutomaticKeepAliveClientMixin {
  final _searchKey = GlobalKey();
  String _query = '';
  bool _favoritesOnly = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<FontService>();
    final scheme = Theme.of(context).colorScheme;
    var fonts = service.fonts;
    if (fonts.isEmpty) {
      return desktopCentered(
        context,
        EmptyStatePlaceholder(
          icon: Icons.font_download_outlined,
          title: l10n.fontEmptyTitle,
          hint: l10n.fontEmptyHint,
        ),
      );
    }
    if (_favoritesOnly) fonts = fonts.where((f) => f.isFavorite).toList();
    if (_query.isNotEmpty) {
      fonts = fonts.where((f) => f.displayName.contains(_query)).toList();
    }
    // お気に入りを先頭に表示
    final sorted = [...fonts]
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });

    return desktopCentered(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 320;
          final search = Padding(
            key: _searchKey,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            // 「お気に入りのみ」は名前つきのチップが行の4割に入るときだけ
            // 名前を出し、入らなければ星だけにする（判断3：文字は縮めない。
            // 名前は長押し・ホバーの吹き出しと読み上げ）。名前つきのままだと、
            // 大きな文字で検索欄が細くなり、ヒントが語の途中で折れて切れた。
            child: LayoutBuilder(
              builder: (context, box) => Row(
                children: [
                  Expanded(
                    child: TextField(
                      // 画面の色で塗る欄なので、打った字・ヒント・アイコンは本文の
                      // 文字色（テーマの入力欄はメニューの色で塗りメニューの文字色）。
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: compact
                            ? l10n.commonSearch
                            : l10n.fontDownloadedSearchHint,
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        // 入らないヒントは行を増やして全部出す（「…」で切らない）。
                        hintMaxLines: compact ? 1 : 4,
                        prefixIcon: const Icon(Icons.search),
                        prefixIconColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * 0.4),
                    child: FirstThatFits(
                      children: [
                        FilterChip(
                          label: Text(
                            l10n.homeFavoritesOnly,
                            style: localizedHeadingStyle(
                              context,
                              const TextStyle(),
                            ),
                          ),
                          selected: _favoritesOnly,
                          onSelected: (v) => setState(() => _favoritesOnly = v),
                        ),
                        FilterChip(
                          label: Icon(
                            _favoritesOnly ? Icons.star : Icons.star_outline,
                            size: 18,
                            semanticLabel: l10n.homeFavoritesOnly,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                          showCheckmark: false,
                          tooltip: l10n.homeFavoritesOnly,
                          selected: _favoritesOnly,
                          onSelected: (v) => setState(() => _favoritesOnly = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          return CustomScrollView(
            slivers: [
              if (compact)
                SliverToBoxAdapter(child: search)
              else
                PinnedHeaderSliver(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: search,
                  ),
                ),
              if (sorted.isEmpty)
                EmptyStateSliver(
                  builder: (size) => EmptyStatePlaceholder(
                    icon: Icons.search_off_outlined,
                    title: l10n.fontCatalogNoResults,
                    scrollable: false,
                    fitIn: size,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverList.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final f = sorted[index];
                      final subtitleStyle =
                          ListTileTheme.of(context).subtitleTextStyle ??
                          Theme.of(context).textTheme.bodyMedium!;
                      return Card(
                        elevation: 1,
                        shadowColor: ThemeService.activeColorScheme.shadow
                            .withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              f.extension.substring(0, 1),
                              style: TextStyle(
                                fontSize: 11,
                                color: AccentTextTheme.of(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // 狭い一覧では、すべてのカードで名前と操作を
                          // 上下に揃える。短い名前にも同じ幅を確保する。
                          title: ActionBesideOrBelow(
                            minTextWidth: 200,
                            text: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                messageText(
                                  f.displayName,
                                  style: TextStyle(
                                    fontFamily: service.familyNameOf(f),
                                  ),
                                ),
                                // 2行目は、ListTileの2行目と同じ本文の書体。
                                DefaultTextStyle(
                                  style: subtitleStyle,
                                  child: Text(
                                    '${f.extension} ・ ${fileSizeLabel(AppLocalizations.of(context)!, f.sizeBytes)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            action: Wrap(
                              alignment: WrapAlignment.end,
                              children: [
                                // ピクセルモード：ON時は
                                // このフォントで追加するテキストのアンチエイリアスを
                                // 除去する（ドットフォントをにじませずくっきり表示）。
                                IconButton(
                                  icon: Icon(
                                    f.pixelMode
                                        ? Icons.grid_on
                                        : Icons.grid_off,
                                    size: 18,
                                    color: f.pixelMode
                                        ? AccentTextTheme.of(context)
                                        : null,
                                  ),
                                  tooltip: l10n.fontPixelModeTooltip,
                                  onPressed: () =>
                                      service.togglePixelMode(f.id),
                                ),
                                IconButton(
                                  icon: Icon(
                                    f.isFavorite
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 18,
                                    color: f.isFavorite
                                        ? ThemeService
                                              .activeColorScheme
                                              .tertiary
                                        : null,
                                  ),
                                  tooltip: l10n.commonFavoriteToggle,
                                  onPressed: () => service.toggleFavorite(f.id),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  tooltip: l10n.commonRename,
                                  onPressed: () =>
                                      _showRenameDialog(context, f),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  tooltip: l10n.commonDelete,
                                  onPressed: () => _confirmDelete(context, f),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FontAsset font) {
    final l10n = AppLocalizations.of(context)!;
    final fonts = context.read<FontService>();
    showDialog<void>(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.fontRenameDialogTitle,
        initialName: font.displayName,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        onSubmit: (name) => fonts.renameFont(font.id, name),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FontAsset font) async {
    final l10n = AppLocalizations.of(context)!;
    // お気に入り登録中は削除できない。
    if (font.isFavorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    final fonts = context.read<FontService>();
    final family = fonts.familyNameOf(font);
    final projects = context.read<ProjectService?>();
    final projectCount = projects == null
        ? 0
        : [...projects.projects, ...projects.trash]
              .where((p) => projects.usedFontFamiliesOf(p.id).contains(family))
              .length;
    final watermarkCount =
        context
            .read<WatermarkService?>()
            ?.assets
            .where((asset) => asset.fontFamily == family)
            .length ??
        0;
    final message = [
      l10n.confirmDeleteNamedBody(font.displayName),
      if (projectCount + watermarkCount > 0)
        l10n.fontDeleteUsageCounts(projectCount, watermarkCount),
      l10n.fontDeleteSavedUsageWarning,
    ].join('\n\n');
    final confirmed = await confirmDelete(context, message: message);
    if (!confirmed) return;
    if (!context.mounted) return;
    await fonts.removeFont(font.id);
  }
}

/// 「読み込み」タブ：端末に保存済みのTTF/OTFファイルをアプリへ取り込む。
/// 取り込んだフォントは「ダウンロード済み」タブへ自動的に反映される。
class _ImportFontTab extends StatelessWidget {
  const _ImportFontTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return desktopCentered(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight <
              140 + MediaQuery.textScalerOf(context).scale(16) * 3;
          return EmptyStatePlaceholder(
            icon: Icons.upload_file_outlined,
            title: compact ? l10n.fontSettingsTabImport : l10n.fontImportTitle,
            hint: compact
                ? '${l10n.fontImportTitle}\n${l10n.fontImportFormats}'
                : l10n.fontImportFormats,
            action: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.add),
              label: messageText(
                l10n.fontSelectFileButton,
                textAlign: TextAlign.center,
              ),
              onPressed: () => _addFont(context),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addFont(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    final path = result.files.first.path!;
    final name = result.files.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (!context.mounted) return;
    try {
      final asset = await context.read<FontService>().addFont(path, name);
      if (!context.mounted) return;
      if (asset == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.fontUnsupportedSnackbar)));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.fontAddedSnackbar(name))));
      }
    } on FontCorruptedException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fontCorruptedSnackbar)));
    }
  }
}
