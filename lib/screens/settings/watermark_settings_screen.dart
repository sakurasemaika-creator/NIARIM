import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/watermark_asset.dart';
import '../../services/watermark_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

/// ウォーターマーク登録・管理画面（プレミアム限定、仕様書01・08・13）。
/// 「設定項目：画像選択 / 文字入力 / …」のうち、画像・文字それぞれの
/// ウォーターマークを複数登録できる。位置・サイズ・透明度・表示範囲は
/// タイムラインへ追加後にレイヤーパネル・変形ツールから調整する。
/// 登録した項目はタイムラインの「＋ウォーターマーク」から選択して追加できる。
class WatermarkSettingsScreen extends StatelessWidget {
  const WatermarkSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WatermarkService>();
    final assets = service.assets;

    return Scaffold(
      appBar: AppBar(title: const Text('ウォーターマーク'), actions: const [HelpButton()]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, service),
        child: const Icon(Icons.add),
      ),
      body: desktopCentered(
        context,
        assets.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.branding_watermark, size: 44, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('登録されたウォーターマークがありません',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('右下の＋から画像または文字を登録してください',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: assets.length,
                itemBuilder: (context, index) => _WatermarkTile(
                  asset: assets[index],
                  onDelete: () => service.removeWatermark(assets[index].id),
                ),
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WatermarkService service) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('画像から追加'),
              onTap: () {
                Navigator.pop(ctx);
                _addImageWatermark(context, service);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('文字を入力'),
              onTap: () {
                Navigator.pop(ctx);
                _showTextWatermarkDialog(context, service);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImageWatermark(BuildContext context, WatermarkService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    await service.addWatermark(result.files.first.path!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ウォーターマークを登録しました')),
    );
  }

  void _showTextWatermarkDialog(BuildContext context, WatermarkService service) {
    final controller = TextEditingController();
    const presetColors = [
      Colors.white, Colors.black, Colors.red, Colors.orange,
      Colors.yellow, Colors.green, Colors.blue, Colors.purple,
    ];
    Color selected = Colors.white;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('文字ウォーターマークを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: '表示する文字', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('文字色', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in presetColors)
                    GestureDetector(
                      onTap: () => setS(() => selected = c),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected == c ? Theme.of(ctx).colorScheme.primary : Colors.grey,
                            width: selected == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                await service.addTextWatermark(text, color: selected.toARGB32());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }
}

class _WatermarkTile extends StatelessWidget {
  final WatermarkAsset asset;
  final VoidCallback onDelete;
  const _WatermarkTile({required this.asset, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final service = context.read<WatermarkService>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: asset.type == WatermarkAssetType.text
                ? Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      asset.text ?? '',
                      style: TextStyle(
                        color: Color(asset.textColor ?? 0xFFFFFFFF),
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  )
                : FutureBuilder<String?>(
                    future: service.pathOf(asset.id),
                    builder: (context, snapshot) {
                      final path = snapshot.data;
                      if (path == null) {
                        return Center(child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant));
                      }
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Image.file(File(path), fit: BoxFit.contain),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(asset.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: '削除',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
