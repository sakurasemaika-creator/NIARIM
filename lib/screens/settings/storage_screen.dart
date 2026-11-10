import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/material_service.dart';
import '../../services/project_service.dart';
import '../../services/storage_info_service.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/help_button.dart';
import '../../widgets/responsive.dart';
import '../../widgets/project_trash_dialog.dart';
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
/// アクセント色の**色相と彩度を固定**し、明度だけを均等に上げて
/// 統一感のある濃淡6色を作る。テーマを変えた際も同じ色系統を保つ。
/// `test/storage_chart_colors_test.dart`が組み込み28テーマ全てで検証する。
/// 各カテゴリの明度はテーマの明度から独立した固定値（HSLのL）。
/// 色相と彩度だけを現在のアクセントから取得する。
const storageChartLightnessLevels = <double>[
  0.36,
  0.445,
  0.53,
  0.615,
  0.70,
  0.785,
];

List<Color> sliceColorsOf(ColorScheme scheme) {
  final accent = HSLColor.fromColor(scheme.primary);
  return [
    for (final lightness in storageChartLightnessLevels)
      accent.withLightness(lightness).toColor(),
  ];
}

/// 端末の容量の問い合わせを待つ長さ。過ぎても答えが無ければ、その欄だけ
/// 「取得できませんでした」にして、やり直せるようにする（内訳と操作は
/// 待たせない）。
@visibleForTesting
const storageDeviceSpaceTimeout = Duration(seconds: 4);

/// 画面は「端末の容量」「NIARIMの内訳」「整理する」の3つの欄からなり、
/// 欄ごとに別々に読み込む・失敗する。操作の欄は読み込みを待たずにいつも出す。
/// 以前は1つの読み込み中フラグで本文全体を隠していたので、集計が遅い・
/// 失敗した・端末の容量の問い合わせが返らないと、操作まで使えなかった。
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key, this.service});

  /// 集計の進み方をテストで決めるための差し替え口。
  @visibleForTesting
  final StorageInfoService? service;

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late final StorageInfoService _service =
      widget.service ?? StorageInfoService();

  // ── NIARIMの内訳 ──
  /// 表示している内訳（直近に集計できたもの）。
  StorageBreakdown? _breakdown;
  bool _scanning = false;
  bool _breakdownFailed = false;

  /// 走っている集計。同時に2つは走らせない。
  Future<void>? _scan;

  /// 集計を始めるたびに進める。古い集計の結果は捨てる。
  int _scanGeneration = 0;

  /// 大きさを変える操作の後、新しい集計が終わるまでtrue。その間、
  /// 表示している値は操作の前のものなので、値で決まる操作は止める。
  bool _sizesOutdated = false;

  // ── 端末の容量 ──
  DeviceSpaceInfo? _deviceSpace;
  bool _deviceWaiting = false;
  bool _deviceTimedOut = false;
  int _deviceGeneration = 0;
  Timer? _deviceTimeout;

  /// 確かめるダイアログが開いている間・処理中。どの操作も受け付けない。
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    // 開き直したときは、新しい集計が終わるまで前回の値を出しておく。
    _breakdown = _service.lastBreakdown;
    _deviceSpace = _service.lastDeviceSpace;
    _reload();
  }

  @override
  void dispose() {
    _deviceTimeout?.cancel();
    super.dispose();
  }

  /// 内訳と端末の容量を取り直す。投げず、必ず終わる（引っぱって更新が
  /// これを待つ）。[sizesChanged]は大きさを変える操作の後に渡す：走っている
  /// 集計は操作の前のディスクを見ているので、捨てて始め直す。
  Future<void> _reload({bool sizesChanged = false}) {
    if (sizesChanged) _service.invalidate();
    _loadDeviceSpace();
    return _loadBreakdown(restart: sizesChanged);
  }

  Future<void> _loadBreakdown({bool restart = false}) {
    final running = _scan;
    if (_scanning && running != null && !restart) return running;
    final generation = ++_scanGeneration;
    final trashedIds = context
        .read<ProjectService>()
        .trash
        .map((p) => p.id)
        .toSet();
    setState(() {
      _scanning = true;
      _breakdownFailed = false;
      if (restart) _sizesOutdated = true;
    });
    return _scan = _runScan(generation, trashedIds);
  }

  Future<void> _runScan(int generation, Set<String> trashedIds) async {
    StorageBreakdown? result;
    try {
      result = await _service.computeBreakdown(trashedIds);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
    if (!mounted || generation != _scanGeneration) return;
    setState(() {
      _scanning = false;
      if (result == null || result.isUnreadable) {
        _breakdownFailed = true;
        // 操作の前の内訳はもう合っていないので、残さない。
        if (_sizesOutdated) _breakdown = null;
      } else {
        _breakdown = result;
        _sizesOutdated = false;
      }
    });
  }

  void _loadDeviceSpace() {
    if (_deviceWaiting) return;
    final generation = ++_deviceGeneration;
    _deviceTimeout?.cancel();
    // 待ちの長さは自分のタイマーで計る（`Future.timeout`は止められない
    // タイマーを残し、画面を閉じた後も動く）。
    _deviceTimeout = Timer(storageDeviceSpaceTimeout, () {
      if (!mounted || generation != _deviceGeneration) return;
      setState(() {
        _deviceWaiting = false;
        _deviceTimedOut = true;
      });
    });
    setState(() {
      _deviceWaiting = true;
      _deviceTimedOut = false;
    });
    Future<DeviceSpaceInfo?>.sync(_service.deviceSpace).then<void>(
      (info) => _deviceAnswered(generation, info),
      onError: (Object error, StackTrace stack) {
        AppErrorReporter.record(error, stack);
        _deviceAnswered(generation, null);
      },
    );
  }

  /// 待ちが切れた後に届いた答えも、問い合わせ直していなければ使う。
  /// nullは「この端末では取得できない」で、欄ごと出さない。
  void _deviceAnswered(int generation, DeviceSpaceInfo? info) {
    if (!mounted || generation != _deviceGeneration) return;
    _deviceTimeout?.cancel();
    setState(() {
      _deviceWaiting = false;
      _deviceTimedOut = false;
      _deviceSpace = info;
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
        RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._deviceSection(l10n),
              ..._breakdownSection(l10n),
              _sectionTitle(l10n.storageActionsTitle),
              const SizedBox(height: 8),
              _buildActions(l10n),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 欄 ───────────────────────────────────────────────────────────────

  /// 欄の見出し。[refreshing]は、値を出したまま裏で取り直している印。
  Widget _sectionTitle(String text, {bool refreshing = false}) {
    final title = Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
      ),
    );
    if (!refreshing) return title;
    return Row(
      children: [
        Flexible(child: title),
        const SizedBox(width: 8),
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: AppLocalizations.of(context)!.storageCalculating,
          ),
        ),
      ],
    );
  }

  /// まだ出せる値が無い欄の中身。
  Widget _calculating(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.storageCalculating)),
        ],
      ),
    );
  }

  List<Widget> _deviceSection(AppLocalizations l10n) {
    final device = _deviceSpace;
    final breakdown = _breakdown;
    // グラフはNIARIMの分を内訳の合計から出すので、内訳も要る。
    final Widget? body;
    if (device != null && breakdown != null) {
      body = _buildDeviceChart(l10n, device, breakdown);
    } else if (_deviceWaiting || (device != null && _scanning)) {
      body = _calculating(l10n);
    } else {
      body = null;
    }
    // 取得できない端末（答えがnull）では、これまでどおり欄ごと出さない。
    if (body == null && !_deviceTimedOut) return const [];
    return [
      _sectionTitle(
        l10n.storageDeviceChartTitle,
        refreshing: _deviceWaiting && device != null && breakdown != null,
      ),
      const SizedBox(height: 8),
      ?body,
      if (_deviceTimedOut)
        _StorageNotice(
          message: l10n.storageDeviceSpaceUnavailable,
          retryKey: const ValueKey('storageDeviceRetry'),
          onRetry: _loadDeviceSpace,
        ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _breakdownSection(AppLocalizations l10n) {
    final breakdown = _breakdown;
    const retryKey = ValueKey('storageBreakdownRetry');
    return [
      _sectionTitle(
        l10n.storageBreakdownChartTitle,
        refreshing: _scanning && breakdown != null,
      ),
      const SizedBox(height: 8),
      if (breakdown != null)
        _buildBreakdownChart(l10n, breakdown)
      else if (_scanning)
        _calculating(l10n),
      if (_breakdownFailed)
        _StorageNotice(
          message: l10n.storageBreakdownLoadFailed,
          retryKey: retryKey,
          onRetry: _reload,
        )
      else if (breakdown != null && breakdown.incomplete.isNotEmpty)
        _StorageNotice(
          message: l10n.storageBreakdownIncomplete,
          retryKey: retryKey,
          onRetry: _scanning ? null : _reload,
        ),
      const SizedBox(height: 24),
    ];
  }

  // ─── 円グラフ ─────────────────────────────────────────────────────────

  Widget _buildDeviceChart(
    AppLocalizations l10n,
    DeviceSpaceInfo device,
    StorageBreakdown breakdown,
  ) {
    final niarimBytes = breakdown.totalBytes;
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
    // アクセント色の色相・彩度を変えず、明度だけ6段階にした濃淡を使う。
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
    return _chartWithLegend(slices, showBars: true);
  }

  Widget _chartWithLegend(
    List<_PieSlice> slices, {
    bool showBars = false,
  }) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    final largest = slices.fold<double>(
      0,
      (max, slice) => math.max(max, slice.value),
    );
    final scheme = Theme.of(context).colorScheme;
    // Match the toolbar's ordinary (unselected) icon fill, not its separate
    // contrast outline. ThemeService builds onSurface from the appearance.
    final chartOutline = scheme.onSurface;
    final pie = SizedBox(
      width: 120,
      height: 120,
      child: total <= 0
          ? Center(
              child: Icon(
                Icons.donut_large,
                size: 48,
                color: scheme.outlineVariant,
              ),
            )
          : CustomPaint(
              painter: _PieChartPainter(slices, outlineColor: chartOutline),
            ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in slices)
          if (s.value > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: showBars ? 5 : 2),
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
                    child: showBars
                        ? _storageAmountBar(
                            key: Key('storageBreakdownBar_${s.label}'),
                            color: s.color,
                            ratio: largest > 0 ? s.value / largest : 0,
                            label: s.label,
                            bytes: s.value,
                            scheme: scheme,
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.label,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
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

    // At phone widths, forcing six named values beside a 120px circle leaves
    // too little room for localized labels. Give the in-bar text the full
    // available width without removing the pie. Larger screens stay side-by-side.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (showBars && constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: pie),
              const SizedBox(height: 10),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pie,
            const SizedBox(width: 16),
            Expanded(child: legend),
          ],
        );
      },
    );
  }

  /// One labeled bar per legend row. Its remainder uses the exact same
  /// theme text color as the surrounding border, rather than an arbitrary
  /// gray. The foreground token matches selected (active) controls.
  Widget _storageAmountBar({
    required Key key,
    required Color color,
    required double ratio,
    required String label,
    required double bytes,
    required ColorScheme scheme,
  }) {
    final outline = scheme.onSurface;
    final foreground = scheme.onSecondary;
    final amount = ratio.clamp(0.0, 1.0);
    return SizedBox(
      key: key,
      height: 30,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: amount,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: outline, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    key: Key('storageBreakdownBarLabel_$label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  formatStorageBytes(bytes),
                  key: Key('storageBreakdownBarValue_$label'),
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 操作ボタン ────────────────────────────────────────────────────────

  /// [category]の大きさで決まる操作の、行の下の文と押せるかどうか。
  /// 大きさが分かっていて0より大きいときだけ押せる。集計中は「集計中…」、
  /// 読めなかった分類で0のときは数字を出さない（0Bは分かった値ではない）。
  ({String? subtitle, bool enabled}) _sizedAction(
    AppLocalizations l10n,
    StorageCategory category,
  ) {
    final breakdown = _breakdown;
    if (breakdown == null || _sizesOutdated) {
      return (
        subtitle: _scanning ? l10n.storageCalculating : null,
        enabled: false,
      );
    }
    final bytes = breakdown.bytesOf(category);
    if (bytes <= 0 && breakdown.incomplete.contains(category)) {
      return (subtitle: null, enabled: false);
    }
    return (subtitle: formatStorageBytes(bytes), enabled: bytes > 0);
  }

  Widget _buildActions(AppLocalizations l10n) {
    final cache = _sizedAction(l10n, StorageCategory.cache);
    final trash = _sizedAction(l10n, StorageCategory.trash);
    final idle = !_actionBusy;
    return Column(
      children: [
        _actionTile(
          icon: Icons.cleaning_services_outlined,
          title: l10n.storageClearCacheButton,
          subtitle: cache.subtitle,
          onTap: idle && cache.enabled ? _confirmClearCache : null,
        ),
        _actionTile(
          icon: Icons.image_not_supported_outlined,
          title: l10n.storageRemoveUnusedMaterialsButton,
          onTap: idle ? _confirmRemoveUnusedMaterials : null,
        ),
        _actionTile(
          icon: Icons.delete_sweep_outlined,
          title: l10n.storageEmptyTrashButton,
          subtitle: trash.subtitle,
          onTap: idle && trash.enabled ? _confirmEmptyTrash : null,
        ),
        _actionTile(
          icon: Icons.folder_open_outlined,
          title: l10n.storageOrganizeProjectsButton,
          onTap: idle ? _openProjects : null,
        ),
        Divider(height: 24),
        _actionTile(
          icon: Icons.warning_amber_outlined,
          iconColor: ThemeService.activeColorScheme.error,
          title: l10n.storageEraseAllButton,
          titleColor: ThemeService.activeColorScheme.error,
          onTap: idle ? _confirmEraseAll : null,
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

  /// 操作を1つだけ走らせる。[action]は大きさが変わりうることをしたかを返し、
  /// したなら終わった後に集計し直す。以前は読み込み中に本文ごと隠れることが
  /// 二度押しを防いでいた。本文を出したままにしたので、ここで防ぐ。
  Future<void> _runAction(Future<bool> Function() action) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    // 途中で失敗したときも、どこまで消えたか分からないので集計し直す。
    var sizesChanged = true;
    try {
      sizesChanged = await action();
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
        if (sizesChanged) unawaited(_reload(sizesChanged: true));
      }
    }
  }

  /// 作品を消す・ゴミ箱へ移すための行き先なので、戻ってきたら集計し直す。
  Future<void> _openProjects() => _runAction(() async {
    await context.push('/home');
    return true;
  });

  Future<void> _confirmClearCache() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageCategoryCache,
    );
    if (!ok || !mounted) return false;
    try {
      final freed = await _service.clearCache();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.storageClearCacheDoneSnackbar(formatStorageBytes(freed)),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text(l10n.communityErrorGeneric),
          ),
        ),
      );
    }
    return true;
  });

  Future<void> _confirmRemoveUnusedMaterials() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDelete(
      context,
      itemName: l10n.storageRemoveUnusedMaterialsButton,
    );
    if (!ok || !mounted) return false;
    final ps = context.read<ProjectService>();
    final ms = context.read<MaterialService>();
    int removed = 0;
    for (final project in ps.projects) {
      removed += await ms.removeUnused(
        projectId: project.id,
        isUsed: (materialId) => ps.isMaterialUsed(project.id, materialId),
      );
    }
    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.materialRemovedSnackbar(removed))),
    );
    return true;
  });

  Future<void> _confirmEmptyTrash() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    // ゴミ箱のフォルダ（中の作品ごと）も含めて空にする。
    final targets = ps.trash.map((p) => p.id).toSet();
    final folderTargets = ps.trashedFolders.map((t) => t.folder.id).toSet();
    // 途中で失敗してから閉じた場合も、消せた分だけ大きさは変わっている。
    var attempted = false;
    await showDialog<bool>(
      context: context,
      builder: (_) => ProjectTrashDialog(
        title: l10n.homePermanentDeleteConfirmTitle,
        message: l10n.homePermanentDeleteConfirmBody,
        confirmLabel: l10n.commonDelete,
        itemNames: const [],
        pendingItemNames: () => [
          for (final t in ps.trashedFolders)
            if (folderTargets.contains(t.folder.id)) t.folder.name,
          for (final p in ps.looseTrash)
            if (targets.contains(p.id)) p.name,
        ],
        onApply: () async {
          attempted = true;
          for (final id in folderTargets) {
            await ps.permanentDeleteTrashedFolder(id);
          }
          for (final id in targets) {
            if (ps.trash.any((p) => p.id == id)) {
              await ps.permanentDelete(id);
            }
          }
        },
      ),
    );
    return attempted;
  });

  Future<void> _confirmEraseAll() => _runAction(() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
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
    if (confirmed != true || !mounted) return false;
    // 実際の全データ削除は、他の全Serviceが保持するメモリ上の状態も
    // まとめて破棄する必要があり影響範囲が大きいため、ここでは
    // ディスク上のNIARIMデータ（プロジェクト・素材・書き出し・自作
    // アセット・キャッシュ）のみを削除し、アプリの再起動を促す
    // 案内にとどめる（中途半端な状態のままメモリ上の各Serviceを
    // 使い続けるリスクを避けるため）。
    await _service.eraseAllData();
    if (!mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.storageEraseAllDoneSnackbar)));
    return true;
  });
}

/// 欄の中に出す知らせ（集計できなかった・一部を読めなかった・端末の容量を
/// 取得できなかった）と、やり直しのボタン。失敗を色では表さず、その欄が
/// 載っている面の本文の色のまま、先頭のアイコンで示す。
class _StorageNotice extends StatelessWidget {
  const _StorageNotice({
    required this.message,
    required this.retryKey,
    required this.onRetry,
  });

  final String message;
  final Key retryKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = DefaultTextStyle.of(context).style.color;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: retryKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.communityRetry),
            ),
          ),
        ],
      ),
    );
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
  final Color outlineColor;

  _PieChartPainter(this.slices, {required this.outlineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    // Keep the theme-derived 1.5px outline inside the paint bounds.
    const borderWidth = 1.5;
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = slice.value / total * 2 * math.pi;
      final paint = Paint()..color = slice.color;
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }
    canvas.drawOval(
      rect,
      Paint()
        ..color = outlineColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.outlineColor != outlineColor;
}
