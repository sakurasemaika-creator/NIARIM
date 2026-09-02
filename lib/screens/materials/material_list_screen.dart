import 'dart:io';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/material_asset.dart';
import '../../services/material_service.dart';
import '../../services/project_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';

/// 素材一覧画面。
/// サムネイル・種類アイコン・ファイル名・容量等を一覧表示し、
/// 使用中でない素材の個別削除・一括削除・不足素材の検出を行う。
class MaterialListScreen extends StatefulWidget {
  final String projectId;
  const MaterialListScreen({super.key, required this.projectId});

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> {
  List<MaterialAsset> _missing = const [];

  /// 素材IDごとの実ファイルパス解決結果。
  ///
  /// build()の中で`pathOf()`を呼ぶと、再ビルドのたびに新しいFutureが作られて
  /// FutureBuilderが待機状態へ戻るため、一覧をスクロールしたり他の状態を
  /// 更新したりするだけでサムネイルが消えて出直す（＋ディスクアクセスも
  /// その都度やり直す）。IDごとに1回だけ解決してこの表に持つ。
  final Map<String, Future<String?>> _pathFutures = {};
  bool _checkedMissing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedMissing) {
      _checkedMissing = true;
      _detectMissing();
    }
  }

  Future<void> _detectMissing() async {
    final missing = await context.read<MaterialService>().detectMissing(widget.projectId);
    if (mounted) setState(() => _missing = missing);
  }

  bool _isUsed(String materialId) =>
      context.read<ProjectService>().isMaterialUsed(widget.projectId, materialId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final materials = context.watch<MaterialService>().materialsOf(widget.projectId);
    final scheme = Theme.of(context).colorScheme;
    final unusedCount = materials.where((m) => !_isUsed(m.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.materialListTitle),
        actions: [
          const HelpButton(topic: '素材一覧'),
          if (unusedCount > 0)
            TextButton(
              onPressed: _confirmRemoveUnused,
              child: Text(l10n.materialRemoveUnused(unusedCount)),
            ),
        ],
      ),
      body: desktopCentered(
        context,
        materials.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.perm_media_outlined, size: 40, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.materialEmptyTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback)),
                    const SizedBox(height: 4),
                    Text(l10n.materialEmptyHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: materials.length,
                itemBuilder: (context, index) {
                  final m = materials[index];
                  final used = _isUsed(m.id);
                  final isMissing = _missing.any((e) => e.id == m.id);
                  return Card(
                    child: ListTile(
                      leading: _thumbnail(m, scheme),
                      title: Text(m.originalFileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          m.id,
                          _formatSize(m.sizeBytes),
                          if (m.width != null && m.height != null) '${m.width}×${m.height}',
                          if (m.duration != null) _formatDuration(m.duration!),
                          _formatDate(m.addedAt),
                          used ? l10n.materialUsedLabel : l10n.materialUnusedLabel,
                          if (isMissing) l10n.materialMissingLabel,
                        ].join(' ・ '),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMissing ? Colors.red : scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: used ? l10n.materialDeleteTooltipUsed : l10n.commonDelete,
                        onPressed: used ? null : () => _confirmRemoveOne(m),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _thumbnail(MaterialAsset m, ColorScheme scheme) {
    final future = _pathFutures.putIfAbsent(
      m.id,
      () => context.read<MaterialService>().pathOf(widget.projectId, m.id),
    );
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        // pathOf()は実ファイルが無ければnullを返すので、ここで
        // existsSync()を重ねて呼ぶ必要は無い（行ごとにUIスレッドで
        // ディスクを叩くことになる）。
        final path = snapshot.data;
        if (m.type == MaterialType.image && path != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              // 素材の元画像は原寸のまま保存されている。48px表示のために
              // 原寸でデコードして画像キャッシュへ載せない。
              cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
            ),
          );
        }
        final icon = switch (m.type) {
          MaterialType.image => Icons.image_outlined,
          MaterialType.video => Icons.videocam_outlined,
          MaterialType.audio => Icons.audiotrack_outlined,
        };
        return Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: scheme.onSurfaceVariant),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // 素材は追加後に編集する手段がないため、追加日時＝最終更新日時として
  // 表示する（「詳細表示」の「最終更新日時」欄に使用）。
  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  void _confirmRemoveOne(MaterialAsset m) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.materialRemoveOneConfirmTitle),
        content: Text(m.originalFileName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<MaterialService>().removeMaterial(
                    projectId: widget.projectId,
                    materialId: m.id,
                    isUsed: _isUsed,
                  );
              _pathFutures.remove(m.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveUnused() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.materialRemoveUnusedConfirmTitle),
        content: Text(l10n.materialRemoveUnusedConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final removed = await context.read<MaterialService>().removeUnused(
                    projectId: widget.projectId,
                    isUsed: _isUsed,
                  );
              _pathFutures.clear();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.materialRemovedSnackbar(removed))),
                );
              }
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
