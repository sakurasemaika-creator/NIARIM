import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/downloadable_font.dart';
import '../../services/font_service.dart';

/// 「探してDL」タブの中身（仕様書15）。Google Fontsの全ファミリー
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

class _FontCatalogTabState extends State<FontCatalogTab> with AutomaticKeepAliveClientMixin {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.fontCatalogSearchHint(catalog.length),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _categoryChip(null, l10n.fontCatalogAll),
              for (final entry in kFontCategoryLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _categoryChip(entry.key, entry.value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(l10n.fontCatalogNoResults,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return Card(
                      elevation: 1,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: scheme.surfaceContainerLow,
                      child: ListTile(
                        leading: const Icon(Icons.font_download_outlined),
                        title: Text(entry.displayName),
                        subtitle: Text(
                            '${kFontCategoryLabels[entry.category] ?? entry.category} ・ ${entry.license}',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        trailing: _downloadTrailing(context, service, entry),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _categoryChip(String? category, String label) {
    final selected = _category == category;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _category = category),
    );
  }

  Widget _downloadTrailing(BuildContext context, FontService service, DownloadableFontEntry entry) {
    if (service.isCatalogFontDownloaded(entry)) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (_downloadingIds.contains(entry.id)) {
      return const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download_outlined),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(entry.id));
    }
  }
}
