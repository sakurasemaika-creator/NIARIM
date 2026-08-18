import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/font_asset.dart';
import '../../services/font_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import 'font_catalog_tab.dart';

/// フォント管理画面（仕様書15：設定 → フォント管理）。
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
          title: Text(l10n.settingsFontTitle),
          actions: const [HelpButton(topic: 'フォント管理')],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.fontSettingsTabDownloaded),
              Tab(text: l10n.fontSettingsTabSearch),
              Tab(text: l10n.fontSettingsTabImport),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DownloadedFontsTab(),
            FontCatalogTab(),
            _ImportFontTab(),
          ],
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

class _DownloadedFontsTabState extends State<_DownloadedFontsTab> with AutomaticKeepAliveClientMixin {
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
    if (_favoritesOnly) fonts = fonts.where((f) => f.isFavorite).toList();
    if (_query.isNotEmpty) fonts = fonts.where((f) => f.displayName.contains(_query)).toList();
    // お気に入りを先頭に表示
    final sorted = [...fonts]..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.fontDownloadedSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l10n.fontFavoritesOnly),
                selected: _favoritesOnly,
                onSelected: (v) => setState(() => _favoritesOnly = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: desktopCentered(
            context,
            sorted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                          child: Icon(Icons.font_download_outlined, size: 40, color: scheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.fontEmptyTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(l10n.fontEmptyHint,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final f = sorted[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Text(f.extension.substring(0, 1),
                                style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(f.displayName, style: TextStyle(fontFamily: service.familyNameOf(f))),
                          subtitle: Text('${f.extension} ・ ${_formatSize(f.sizeBytes)}',
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ピクセルモード（ユーザー指示により新規追加）：ON時は
                              // このフォントで追加するテキストのアンチエイリアスを
                              // 除去する（ドットフォントをにじませずくっきり表示）。
                              IconButton(
                                icon: Icon(f.pixelMode ? Icons.grid_on : Icons.grid_off,
                                    size: 18, color: f.pixelMode ? scheme.primary : null),
                                tooltip: l10n.fontPixelModeTooltip,
                                onPressed: () => service.togglePixelMode(f.id),
                              ),
                              IconButton(
                                icon: Icon(f.isFavorite ? Icons.star : Icons.star_border,
                                    size: 18, color: f.isFavorite ? Colors.amber : null),
                                tooltip: l10n.commonFavoriteToggle,
                                onPressed: () => service.toggleFavorite(f.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: l10n.commonRename,
                                onPressed: () => _showRenameDialog(context, f),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: l10n.commonDelete,
                                onPressed: () => _confirmDelete(context, f),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _showRenameDialog(BuildContext context, FontAsset font) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: font.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fontRenameDialogTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<FontService>().renameFont(font.id, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _confirmDelete(BuildContext context, FontAsset font) {
    final l10n = AppLocalizations.of(context)!;
    // お気に入り登録中は削除できない（ユーザー指示により新規追加）。
    if (font.isFavorite) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fontDeleteConfirmTitle(font.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<FontService>().removeFont(font.id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

/// 「読み込み」タブ：端末に保存済みのTTF/OTFファイルをアプリへ取り込む。
/// 取り込んだフォントは「ダウンロード済み」タブへ自動的に反映される。
class _ImportFontTab extends StatelessWidget {
  const _ImportFontTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return desktopCentered(
      context,
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.upload_file_outlined, size: 40, color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(l10n.fontImportTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.fontImportFormats,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.fontSelectFileButton),
                onPressed: () => _addFont(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFont(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final path = result.files.first.path!;
    final name = result.files.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (!context.mounted) return;
    try {
      final asset = await context.read<FontService>().addFont(path, name);
      if (!context.mounted) return;
      if (asset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fontUnsupportedSnackbar)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fontAddedSnackbar(name))),
        );
      }
    } on FontCorruptedException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fontCorruptedSnackbar)),
      );
    }
  }
}
