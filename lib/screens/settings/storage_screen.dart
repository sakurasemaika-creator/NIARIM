import 'package:niarim/services/theme_service.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/material_service.dart';
import '../../services/project_service.dart';
import '../../services/storage_info_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import '../../config/font_fallback.dart';

/// 容量削減画面（ホーム画面ハンバーガーメニューから遷移）。
/// 端末容量に対するNIARIMの使用量・NIARIM内部のデータ内訳を2つの円
/// グラフで可視化し、キャッシュ削除・未使用素材の一括削除（全プロジェクト
/// 横断）・ゴミ箱を空にする・プロジェクト整理（作品一覧への案内）・
/// 全データ削除（初期化）の各操作を提供する。
/// テーマから、6分類ぶんの**互いに区別できる**色を作る。
///
/// 以前は`Theme.of(context).colorScheme`と`ThemeService.activeColorScheme`
/// の両方から色を取っていたが、この2つは同じインスタンス（`themeData`の
/// getterが代入している）なので、6色のうち2組が**まったく同じ色**に
/// なっていた。実際に「プロジェクトデータ」と「キャッシュ」が同じ色で
/// 描かれ、円グラフも凡例もどちらがどちらか分からなかった
/// （`build/all-route-screenshots/32_storage.png`で発覚）。
///
/// さらにこのアプリのテーマは**primaryとsecondaryが同じ色**で、
/// `ColorScheme`の役割をそのまま並べても区別できる6色にはならない。
/// そこでアクセント色を起点に、色相を少しずつずらしつつ明度を等間隔に
/// 振って作る。同系色のまま必ず見分けが付き、テーマを変えても
/// 配色から浮かない。区別できることは
/// `test/storage_chart_colors_test.dart`が組み込み28テーマ全てで検証する。
List<Color> sliceColorsOf(ColorScheme scheme) {
  final base = HSLColor.fromColor(scheme.primary);
  const hueOffsets = <double>[0, 18, -18, 36, -36, 54];
  return [
    for (var i = 0; i < hueOffsets.length; i++)
      base
          .withHue((base.hue + hueOffsets[i] + 360) % 360)
          // 明るい段ほど彩度を落とす。明度だけ上げて彩度を残すと、
          // 淡いテーマの中に蛍光色のような1枚が混ざって浮く。
          .withSaturation((base.saturation * (1.0 - 0.11 * i)).clamp(0.0, 1.0))
          // 明度は0.085刻み。1段ぶんでRGBが20以上動くので、色相・彩度が
          // 近いテーマでも必ず区別できる。
          .withLightness(0.36 + 0.085 * i)
          .toColor(),
  ];
}

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final _service = StorageInfoService();
  bool _loading = true;
  StorageBreakdown? _breakdown;
  DeviceSpaceInfo? _deviceSpace;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final trashedIds = context
        .read<ProjectService>()
        .trash
        .map((p) => p.id)
        .toSet();
    final breakdown = await _service.computeBreakdown(trashedIds);
    final deviceSpace = await _service.deviceSpace();
    if (!mounted) return;
    setState(() {
      _breakdown = breakdown;
      _deviceSpace = deviceSpace;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageScreenTitle),
        actions: const [HelpButton(topic: '容量削減')],
      ),
      body: desktopCentered(
        context,
        _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_deviceSpace != null) ...[
                      Text(
                        l10n.storageDeviceChartTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDeviceChart(l10n, _deviceSpace!),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      l10n.storageBreakdownChartTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBreakdownChart(l10n, _breakdown!),
                    const SizedBox(height: 24),
                    Text(
                      l10n.storageActionsTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActions(l10n),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── 円グラフ ─────────────────────────────────────────────────────────

  Widget _buildDeviceChart(AppLocalizations l10n, DeviceSpaceInfo device) {
    final niarimBytes = _breakdown!.totalBytes;
    final others = (device.usedByOthersBytes - niarimBytes).clamp(
      0,
      device.totalBytes,
    );
    final free = device.freeBytes;
    final scheme = Theme.of(context).colorScheme;
    final slices = [
      _PieSlice(
        niarimBytes.toDouble(),
        scheme.primary,
        l10n.storageCategoryNiarimTotal,
      ),
      _PieSlice(
        others.toDouble(),
        scheme.tertiary,
        l10n.storageCategoryOtherApps,
      ),
      _PieSlice(
        free.toDouble(),
        scheme.surfaceContainerHighest,
        l10n.storageCategoryFree,
      ),
    ];
    return _chartWithLegend(slices);
  }

  Widget _buildBreakdownChart(
    AppLocalizations l10n,
    StorageBreakdown breakdown,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // 6分類ぶんの**必ず違う色**を作る。
    // 以前は5番目・6番目に`ThemeService.activeColorScheme`の
    // secondary/primaryを使っていたが、これは`Theme.of(context)
    // .colorScheme`と同一のインスタンス（`themeData`が代入している）
    // なので、2番目・1番目と**まったく同じ色**になっていた。
    // 実際に「プロジェクトデータ」と「キャッシュ」が同じ色で描かれ、
    // 円グラフも凡例もどちらがどちらか分からない状態だった
    // （build/all-route-screenshots/32_storage.png）。
    // 5番目以降は基本4色の色相を回して作る。
    final colors = sliceColorsOf(scheme);
    final entries = [
      (StorageCategory.materials, l10n.storageCategoryMaterials),
      (StorageCategory.projectData, l10n.storageCategoryProjectData),
      (StorageCategory.exports, l10n.storageCategoryExports),
      (StorageCategory.customAssets, l10n.storageCategoryCustomAssets),
      (StorageCategory.cache, l10n.storageCategoryCache),
      (StorageCategory.trash, l10n.storageCategoryTrash),
    ];
    final slices = [
      for (int i = 0; i < entries.length; i++)
        _PieSlice(
          breakdown.bytesOf(entries[i].$1).toDouble(),
          colors[i % colors.length],
          entries[i].$2,
        ),
    ];
    return _chartWithLegend(slices);
  }

  Widget _chartWithLegend(List<_PieSlice> slices) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: total <= 0
              ? Center(
                  child: Icon(
                    Icons.donut_large,
                    size: 48,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                )
              : CustomPaint(painter: _PieChartPainter(slices)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                if (s.value > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          formatStorageBytes(s.value),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 操作ボタン ────────────────────────────────────────────────────────

  Widget _buildActions(AppLocalizations l10n) {
    final trashBytes = _breakdown?.bytesOf(StorageCategory.trash) ?? 0;
    final cacheBytes = _breakdown?.bytesOf(StorageCategory.cache) ?? 0;
    return Column(
      children: [
        _actionTile(
          icon: Icons.cleaning_services_outlined,
          title: l10n.storageClearCacheButton,
          subtitle: formatStorageBytes(cacheBytes),
          onTap: cacheBytes <= 0 ? null : _confirmClearCache,
        ),
        _actionTile(
          icon: Icons.image_not_supported_outlined,
          title: l10n.storageRemoveUnusedMaterialsButton,
          onTap: _confirmRemoveUnusedMaterials,
        ),
        _actionTile(
          icon: Icons.delete_sweep_outlined,
          title: l10n.storageEmptyTrashButton,
          subtitle: formatStorageBytes(trashBytes),
          onTap: trashBytes <= 0 ? null : _confirmEmptyTrash,
        ),
        _actionTile(
          icon: Icons.folder_open_outlined,
          title: l10n.storageOrganizeProjectsButton,
          onTap: () => context.push('/home'),
        ),
        Divider(height: 24),
        _actionTile(
          icon: Icons.warning_amber_outlined,
          iconColor: ThemeService.activeColorScheme.error,
          title: l10n.storageEraseAllButton,
          titleColor: ThemeService.activeColorScheme.error,
          onTap: _confirmEraseAll,
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }

  // ─── 各操作の確認ダイアログ・実処理 ──────────────────────────────────

  Future<void> _confirmClearCache() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageCategoryCache,
    );
    if (!ok || !mounted) return;
    final freed = await _service.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.storageClearCacheDoneSnackbar(formatStorageBytes(freed)),
        ),
      ),
    );
    await _reload();
  }

  Future<void> _confirmRemoveUnusedMaterials() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageRemoveUnusedMaterialsButton,
    );
    if (!ok || !mounted) return;
    final ps = context.read<ProjectService>();
    final ms = context.read<MaterialService>();
    int removed = 0;
    for (final project in ps.projects) {
      removed += await ms.removeUnused(
        projectId: project.id,
        isUsed: (materialId) => ps.isMaterialUsed(project.id, materialId),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.materialRemovedSnackbar(removed))),
    );
    await _reload();
  }

  Future<void> _confirmEmptyTrash() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageCategoryTrash,
    );
    if (!ok || !mounted) return;
    final ps = context.read<ProjectService>();
    for (final project in List.of(ps.trash)) {
      await ps.permanentDelete(project.id);
    }
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmEraseAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storageEraseAllConfirmTitle),
        content: Text(l10n.storageEraseAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeService.activeColorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.storageEraseAllButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // 実際の全データ削除は、他の全Serviceが保持するメモリ上の状態も
    // まとめて破棄する必要があり影響範囲が大きいため、ここでは
    // ディスク上のNIARIMデータ（プロジェクト・素材・書き出し・自作
    // アセット・キャッシュ）のみを削除し、アプリの再起動を促す
    // 案内にとどめる（中途半端な状態のままメモリ上の各Serviceを
    // 使い続けるリスクを避けるため）。
    await _service.eraseAllData();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.storageEraseAllDoneSnackbar)));
    await _reload();
  }
}

class _PieSlice {
  final double value;
  final Color color;
  final String label;

  const _PieSlice(this.value, this.color, this.label);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> slices;

  _PieChartPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = slice.value / total * 2 * math.pi;
      final paint = Paint()..color = slice.color;
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
