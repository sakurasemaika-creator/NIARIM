import '../../widgets/sheet_list_segment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/accent_text_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/downloadable_font.dart';
import '../../services/font_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/scrollable_sheet_body.dart';

/// 「探してDL」タブの中身。Google Fontsの全ファミリー
/// （約2000書体）を検索・カテゴリ絞り込みで探し、ダウンロードボタンで
/// 取得する。ダウンロードしたフォントは「ダウンロード済み」タブへ
/// 自動的に反映される（FontService._fontsへ追加されるため）。
/// Scaffold/AppBarは持たず、FontSettingsScreenのTabBarViewへ直接
/// 差し込んで使う。
class FontCatalogTab extends StatefulWidget {
  const FontCatalogTab({super.key});

  @override
  State<FontCatalogTab> createState() => _FontCatalogTabState();
}

class _FontCatalogTabState extends State<FontCatalogTab>
    with AutomaticKeepAliveClientMixin {
  final _searchKey = GlobalKey();
  String _query = '';
  String? _category; // null = すべて
  final Set<String> _downloadingIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final service = context.watch<FontService>();
    final scheme = Theme.of(context).colorScheme;
    final catalog = service.catalog;
    final l10n = AppLocalizations.of(context)!;

    final filtered = catalog.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_query.isEmpty) return true;
      return e.displayName.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return desktopCentered(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 320;
          final header = Column(
            key: _searchKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  // 画面の色で塗る欄なので、打った字・ヒント・アイコンは本文の
                  // 文字色（テーマの入力欄はメニューの色で塗りメニューの文字色）。
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: compact
                        ? l10n.commonSearch
                        : l10n.fontCatalogSearchHint(catalog.length),
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
                    // 検索欄も面と同じ色・細い縁（面の色は2種類だけ）。
                    fillColor:
                        Theme.of(context).cardTheme.color ??
                        Theme.of(context).colorScheme.surface,
                    isDense: true,
                    contentPadding: compact
                        ? const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          )
                        : null,
                    suffixIcon: compact
                        ? IconButton(
                            tooltip: l10n.fontCatalogCategories,
                            onPressed: () => _showCategories(l10n),
                            icon: Icon(
                              Icons.filter_list,
                              color: _category == null
                                  ? scheme.onSurfaceVariant
                                  : AccentTextTheme.of(context),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color:
                            Theme.of(context).dividerTheme.color ??
                            scheme.outlineVariant.withValues(alpha: .6),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color:
                            Theme.of(context).dividerTheme.color ??
                            scheme.outlineVariant.withValues(alpha: .6),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                // 分類のチップの行。高さはチップに合わせる（36pxに決めていた頃は、
                // 大きな文字でチップの上下が切れた）。
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _categoryChip(null, l10n.fontCatalogAll),
                      for (final category in kFontCategories)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: _categoryChip(
                            category,
                            fontCategoryLabel(l10n, category),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          );
          return CustomScrollView(
            slivers: [
              if (compact)
                SliverToBoxAdapter(child: header)
              else
                PinnedHeaderSliver(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: header,
                  ),
                ),
              if (filtered.isEmpty)
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      // 一覧は1枚の面の行（行ごとのカードにしない）。
                      return SheetListSegment(
                        first: index == 0,
                        last: index == filtered.length - 1,
                        // 行ごとに同じ印を付けない（見分けの役に立たない）。
                        child: ListTile(
                          title: Text(entry.displayName),
                          subtitle: Text(
                            l10n.fontCatalogEntrySubtitle(
                              fontCategoryLabel(l10n, entry.category),
                              entry.license,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: _downloadTrailing(context, service, entry),
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

  Future<void> _showCategories(AppLocalizations l10n) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ScrollableSheetBody(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RadioGroup<String>(
            groupValue: _category ?? '',
            onChanged: (value) => Navigator.pop(sheetContext, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(value: '', title: Text(l10n.fontCatalogAll)),
                for (final category in kFontCategories)
                  RadioListTile(
                    value: category,
                    title: Text(fontCategoryLabel(l10n, category)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _category = selected.isEmpty ? null : selected);
  }

  Widget _categoryChip(String? category, String label) {
    final selected = _category == category;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _category = category),
    );
  }

  Widget _downloadTrailing(
    BuildContext context,
    FontService service,
    DownloadableFontEntry entry,
  ) {
    if (service.isCatalogFontDownloaded(entry)) {
      // 取り込み済みは状態の印（差し色の文字・アイコン色）。
      return Icon(Icons.check_circle, color: AccentTextTheme.of(context));
    }
    if (_downloadingIds.contains(entry.id)) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // 行ごとの取り込みの印は補助の文字色（2000件の行の全部が差し色だと、
    // 取り込み済みの印が目に入らなかった）。
    return IconButton(
      icon: const Icon(Icons.download_outlined),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: AppLocalizations.of(context)!.fontCatalogDownloadTooltip,
      onPressed: () => _downloadCatalogFont(entry),
    );
  }

  Future<void> _downloadCatalogFont(DownloadableFontEntry entry) async {
    setState(() => _downloadingIds.add(entry.id));
    try {
      await context.read<FontService>().downloadCatalogFont(entry);
    } on FontDownloadException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fontDownloadFailureText(AppLocalizations.of(context)!, e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(entry.id));
    }
  }
}

/// The name shown for a catalog [category] (the source's English id).
String fontCategoryLabel(AppLocalizations l10n, String category) =>
    switch (category) {
      'SANS_SERIF' => l10n.fontCategorySansSerif,
      'SERIF' => l10n.fontCategorySerif,
      'DISPLAY' => l10n.fontCategoryDisplay,
      'HANDWRITING' => l10n.fontCategoryHandwriting,
      'MONOSPACE' => l10n.fontCategoryMonospace,
      _ => category,
    };

/// The message for a catalog font that could not be downloaded.
String fontDownloadFailureText(
  AppLocalizations l10n,
  FontDownloadException error,
) => switch (error.failure) {
  FontDownloadFailure.network => l10n.fontDownloadNetworkError,
  FontDownloadFailure.unavailable => l10n.fontDownloadUnavailable,
  FontDownloadFailure.corrupted => l10n.fontDownloadCorrupted,
};
