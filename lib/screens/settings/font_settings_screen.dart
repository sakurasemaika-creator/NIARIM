import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/downloadable_font.dart';
import '../../models/font_asset.dart';
import '../../services/font_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

/// フォント管理画面（仕様書15：設定 → フォント管理 → ＋追加）。
/// TTF/OTFの追加・一覧表示・検索・削除・名前変更・詳細表示に対応する。
class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({super.key});

  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends State<FontSettingsScreen> {
  bool _showSearch = false;
  String _query = '';
  final Set<String> _downloadingIds = {};

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FontService>();
    final scheme = Theme.of(context).colorScheme;
    final fonts = _query.isEmpty
        ? service.fonts
        : service.fonts.where((f) => f.displayName.contains(_query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'フォント名で検索...', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('フォント管理'),
        actions: [
          const HelpButton(),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() { _showSearch = !_showSearch; _query = ''; }),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (_query.isEmpty) ...[
              _buildDownloadSection(context, service, scheme),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('追加済みフォント',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            ],
            if (fonts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.font_download_outlined, size: 40, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text('フォントがありません', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('＋ボタンからTTF/OTFファイルを追加できます',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              )
            else
              for (final f in fonts)
                Card(
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
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showRenameDialog(f),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _confirmDelete(f),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFont,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// テキストツール用の追加フリーフォントをダウンロードで追加できる一覧
  /// （仕様書15：オンデマンドダウンロード方式）。ダウンロード済みのものは
  /// チェック表示のみとし、フォント本体は下の「追加済みフォント」一覧から
  /// 通常のユーザーフォントと同様に削除・名前変更できる。
  Widget _buildDownloadSection(BuildContext context, FontService service, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text('追加フリーフォント（ダウンロード）',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: scheme.onSurfaceVariant)),
        ),
        for (final entry in kDownloadableFonts)
          Card(
            child: ListTile(
              leading: const Icon(Icons.font_download_outlined),
              title: Text(entry.displayName),
              subtitle: Text('約${entry.approxSizeMB.toStringAsFixed(1)}MB ・ SIL Open Font License',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              trailing: _downloadTrailing(context, service, entry),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('初回のみネット接続が必要です。ダウンロード後はオフラインでも使えます。',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ),
      ],
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _addFont() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final path = result.files.first.path!;
    final name = result.files.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (!mounted) return;
    try {
      final asset = await context.read<FontService>().addFont(path, name);
      if (!mounted) return;
      if (asset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このフォントは読み込めません。')),
        );
      }
    } on FontCorruptedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フォントが破損しています。')),
      );
    }
  }

  void _showRenameDialog(FontAsset font) {
    final controller = TextEditingController(text: font.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('フォント名を変更'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<FontService>().renameFont(font.id, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _confirmDelete(FontAsset font) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${font.displayName}を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<FontService>().removeFont(font.id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
