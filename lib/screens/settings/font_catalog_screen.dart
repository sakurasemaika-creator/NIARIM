import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/downloadable_font.dart';
import '../../services/font_service.dart';
import '../../widgets/responsive.dart';

/// 追加フリーフォント（オンデマンドダウンロード）の一覧・検索・
/// カテゴリ絞り込み画面（仕様書15）。Google Fontsの全ファミリー
/// （約2000書体）を対象とするため、フォント管理画面（インストール済み
/// フォント一覧）とは別画面として分離し、検索・カテゴリチップ・
/// 遅延描画（ListView.builder）で快適に閲覧できるようにする。
class FontCatalogScreen extends StatefulWidget {
  const FontCatalogScreen({super.key});

  @override
  State<FontCatalogScreen> createState() => _FontCatalogScreenState();
}

class _FontCatalogScreenState extends State<FontCatalogScreen> {
  String _query = '';
  String? _category; // null = すべて
  final Set<String> _downloadingIds = {};

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FontService>();
    final scheme = Theme.of(context).colorScheme;
    final catalog = service.catalog;

    final filtered = catalog.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_query.isEmpty) return true;
      return e.displayName.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('追加フリーフォント'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'フォント名で検索...（全${catalog.length}書体）',
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
                    _categoryChip(null, 'すべて'),
                    for (final entry in kFontCategoryLabels.entries)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _categoryChip(entry.key, entry.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: desktopCentered(
        context,
        filtered.isEmpty
            ? Center(
                child: Text('該当するフォントが見つかりません',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return Card(
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
