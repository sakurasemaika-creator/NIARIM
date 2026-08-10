import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/undo_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumService>().isPremium;
    final l10n = AppLocalizations.of(context)!;
    // 仕様書08：「設定内検索バーあり（項目が増えても検索で到達可能）」。
    // 各項目にタイトル・サブタイトルに加えて検索キーワードを持たせ、
    // 部分一致でカテゴリ一覧を絞り込む。
    final entries = [
      (
        icon: Icons.settings, title: l10n.settingsBasicTitle, subtitle: l10n.settingsBasicSubtitle,
        keywords: 'fps 背景色 言語 描画領域初期値', onTap: _showBasicSettings, accent: const Color(0xFFFF5C7A),
      ),
      (
        icon: Icons.tune, title: '詳細', subtitle: 'Undo回数・自動保存・ゴミ箱',
        keywords: 'undo 自動保存 ゴミ箱 削除', onTap: _showDetailSettings, accent: const Color(0xFF3AA6FF),
      ),
      (
        icon: Icons.speed, title: 'パフォーマンス', subtitle: '品質設定・タイルキャッシュ',
        keywords: '品質 タイルキャッシュ 低品質 中品質 高品質 カスタム オニオンスキン 傾き検知',
        onTap: () => context.push('/settings/performance'), accent: const Color(0xFF3DDC97),
      ),
      (
        icon: Icons.touch_app, title: 'ジェスチャー', subtitle: '2本指タップ・長押し',
        keywords: 'タップ スワイプ 長押し ペンボタン', onTap: () => context.push('/settings/gestures'), accent: const Color(0xFFFFB020),
      ),
      (
        icon: Icons.edit, title: 'ペン入力', subtitle: '筆圧・傾き・ペンボタン',
        keywords: '筆圧 傾き ペンボタン 筆圧カーブ', onTap: () => context.push('/settings/pen'), accent: const Color(0xFFB15CFF),
      ),
      (
        icon: Icons.desktop_windows, title: 'ワークスペース', subtitle: 'ツールバー編集・パネル配置',
        keywords: 'ツールバー パネル配置 右利き 左利き dex デックス', onTap: () => context.push('/settings/workspace'), accent: const Color(0xFF3AA6FF),
      ),
      (
        icon: Icons.palette, title: 'UI・テーマ', subtitle: 'テーマ設定・ワークスペース',
        keywords: 'テーマ 配色 ベースカラー アクセントカラー', onTap: () => context.push('/settings/theme'), accent: const Color(0xFFFF5C7A),
      ),
      // 無料会員のみ🔒マーク付きで表示（仕様書08）
      (
        icon: Icons.water, title: isPremium ? 'ウォーターマーク' : 'ウォーターマーク 🔒',
        subtitle: 'ユーザーウォーターマーク（Premium）', keywords: 'ウォーターマーク premium プレミアム',
        onTap: _showWatermarkSetting, accent: const Color(0xFFB15CFF),
      ),
      (
        icon: Icons.import_export, title: '引き継ぎ', subtitle: '設定・素材・ブラシを他端末へ書き出し/読み込み',
        keywords: '引き継ぎ エクスポート インポート 他端末 miratra', onTap: () => context.push('/settings/transfer'), accent: const Color(0xFF3DDC97),
      ),
      (
        icon: Icons.font_download_outlined, title: 'フォント管理', subtitle: 'TTF/OTFの追加・検索・削除',
        keywords: 'フォント ttf otf', onTap: () => context.push('/settings/fonts'), accent: const Color(0xFFFFB020),
      ),
    ];
    final filtered = _query.isEmpty
        ? entries
        : entries.where((e) =>
            e.title.toLowerCase().contains(_query) ||
            e.subtitle.toLowerCase().contains(_query) ||
            e.keywords.toLowerCase().contains(_query)).toList();
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(controller: _searchController, autofocus: true, decoration: const InputDecoration(hintText: '設定を検索...', border: InputBorder.none))
            : Text(l10n.settingsScreenTitle),
        actions: [
          const HelpButton(),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) _searchController.clear(); }),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        filtered.isEmpty
            ? const Center(child: Text('該当する設定項目が見つかりません', style: TextStyle(color: Colors.grey)))
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final e in filtered) _item(e.icon, e.title, e.subtitle, e.onTap, e.accent),
                  if (_query.isEmpty) ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextButton(
                        onPressed: () => context.push('/settings/license'),
                        child: Text('利用規約・ライセンス',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap, Color accent) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showWatermarkSetting() {
    if (!context.read<PremiumService>().isPremium) {
      showPremiumBanner(context);
      return;
    }
    context.push('/settings/watermark');
  }

  void _showBasicSettings() {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsService>();
    var enabled = settings.defaultDrawingAreaEnabled;
    var scale = settings.defaultDrawingAreaScale;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.settingsBasicSheetTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(l10n.settingsDefaultFps),
                  subtitle: Text(l10n.settingsDefaultFpsSubtitle),
                  trailing: Text('${settings.defaultFps} fps', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    // 新規プロジェクト作成画面のFPS選択肢と統一（8/12/24のみ）。
                    final selected = await showDialog<int>(
                      context: ctx,
                      builder: (dctx) => SimpleDialog(
                        title: Text(l10n.settingsDefaultFps),
                        children: [8, 12, 24].map((fps) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(dctx, fps),
                          child: Text('$fps fps',
                              style: TextStyle(
                                  fontWeight: settings.defaultFps == fps ? FontWeight.bold : FontWeight.normal)),
                        )).toList(),
                      ),
                    );
                    if (selected != null) {
                      await settings.setDefaultFps(selected);
                      setS(() {});
                    }
                  },
                ),
                ListTile(
                  title: Text(l10n.settingsLanguage),
                  trailing: Text(settings.language == 'ja' ? '日本語' : 'English',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final selected = await showDialog<String>(
                      context: ctx,
                      builder: (dctx) => SimpleDialog(
                        title: Text(l10n.settingsLanguage),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(dctx, 'ja'),
                            child: Text('日本語',
                                style: TextStyle(
                                    fontWeight: settings.language == 'ja' ? FontWeight.bold : FontWeight.normal)),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(dctx, 'en'),
                            child: Text('English',
                                style: TextStyle(
                                    fontWeight: settings.language == 'en' ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ],
                      ),
                    );
                    if (selected != null) {
                      await settings.setLanguage(selected);
                      setS(() {});
                    }
                  },
                ),
                const Divider(),
                // 描画領域初期値（仕様書26）
                const Text('描画領域初期値', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('新規プロジェクト作成時の初期値となります。',
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('描画領域を広くする'),
                  value: enabled,
                  onChanged: (v) {
                    setS(() => enabled = v);
                    settings.setDefaultDrawingArea(enabled: v, scale: scale);
                  },
                ),
                if (enabled) ...[
                  Row(
                    children: [
                      const Text('倍率'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          min: 1.0, max: 10.0,
                          value: scale,
                          divisions: 18,
                          label: '${scale.toStringAsFixed(1)}倍',
                          onChanged: (v) {
                            setS(() => scale = v);
                            settings.setDefaultDrawingArea(enabled: enabled, scale: v);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${scale.toStringAsFixed(1)}倍', textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDetailSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (_, controller) => Consumer<SettingsService>(
          builder: (context, settings, _) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('詳細設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Undo回数'),
                trailing: Text('${settings.undoLimit}回'),
                onTap: () => _showUndoLimitDialog(settings),
              ),
              const ListTile(title: Text('自動保存スロット数'), trailing: Text('3（固定・クラッシュ復元専用）')),
              ListTile(
                title: const Text('ゴミ箱の自動削除'),
                trailing: Text(settings.trashAutoDeleteDays == 0 ? 'OFF' : '${settings.trashAutoDeleteDays}日'),
                onTap: () => _showTrashAutoDeleteDialog(settings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUndoLimitDialog(SettingsService settings) {
    const options = [10, 20, 30, 50, 100, 200];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo回数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((n) => RadioListTile<int>(
            title: Text('$n回'),
            value: n,
            groupValue: settings.undoLimit,
            onChanged: (v) {
              if (v == null) return;
              settings.setUndoLimit(v);
              context.read<UndoManager>().setMaxUndoCount(v);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
      ),
    );
  }

  void _showTrashAutoDeleteDialog(SettingsService settings) {
    const options = {0: 'OFF', 30: '30日', 60: '60日', 90: '90日'};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ゴミ箱の自動削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.entries.map((e) => RadioListTile<int>(
            title: Text(e.value),
            value: e.key,
            groupValue: settings.trashAutoDeleteDays,
            onChanged: (v) {
              if (v == null) return;
              settings.setTrashAutoDelete(v);
              context.read<ProjectService>().sweepExpiredTrash(v);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
      ),
    );
  }
}
