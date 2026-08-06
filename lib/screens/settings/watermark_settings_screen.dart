import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/watermark_asset.dart';
import '../../services/watermark_service.dart';
import '../../widgets/responsive.dart';

/// ウォーターマーク登録・管理画面（プレミアム限定、仕様書08・13）。
/// 登録した画像はタイムラインの「＋ウォーターマーク」から選択して追加できる。
class WatermarkSettingsScreen extends StatelessWidget {
  const WatermarkSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WatermarkService>();
    final assets = service.assets;

    return Scaffold(
      appBar: AppBar(title: const Text('ウォーターマーク')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addWatermark(context, service),
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
                    Text('右下の＋から画像を登録してください',
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

  Future<void> _addWatermark(BuildContext context, WatermarkService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    await service.addWatermark(result.files.first.path!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ウォーターマークを登録しました')),
    );
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
            child: FutureBuilder<String?>(
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
