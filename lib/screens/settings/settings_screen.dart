import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/editable_slider_value.dart';
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
        // 容量・重さに影響する設定（Undo回数・ゴミ箱自動削除等）は全て
        // パフォーマンス設定へ統合した（旧「詳細」カテゴリは廃止）。
        icon: Icons.speed, title: l10n.settingsPerformanceTitle, subtitle: l10n.settingsPerformanceSubtitle,
        keywords: '品質 タイルキャッシュ 低品質 中品質 高品質 カスタム オニオンスキン 傾き検知 undo ゴミ箱 削除 performance quality cache',
        onTap: () => context.push('/settings/performance'), accent: const Color(0xFF3DDC97),
      ),
      (
        icon: Icons.touch_app, title: l10n.settingsGestureTitle, subtitle: l10n.settingsGestureSubtitle,
        keywords: 'タップ スワイプ 長押し ペンボタン gesture tap swipe', onTap: () => context.push('/settings/gestures'), accent: const Color(0xFFFFB020),
      ),
      (
        icon: Icons.edit, title: l10n.settingsPenTitle, subtitle: l10n.settingsPenSubtitle,
        keywords: '筆圧 傾き ペンボタン 筆圧カーブ pen pressure tilt', onTap: () => context.push('/settings/pen'), accent: const Color(0xFFB15CFF),
      ),
      (
        icon: Icons.desktop_windows, title: l10n.settingsWorkspaceTitle, subtitle: l10n.settingsWorkspaceSubtitle,
        keywords: 'ツールバー パネル配置 右利き 左利き dex デックス workspace toolbar panel', onTap: () => context.push('/settings/workspace'), accent: const Color(0xFF3AA6FF),
      ),
      (
        icon: Icons.palette, title: l10n.settingsThemeTitle, subtitle: l10n.settingsThemeSubtitle,
        keywords: 'テーマ 配色 ベースカラー アクセントカラー theme color', onTap: () => context.push('/settings/theme'), accent: const Color(0xFFFF5C7A),
      ),
      // 無料会員のみ🔒マーク付きで表示（仕様書08）
      (
        icon: Icons.water, title: isPremium ? l10n.settingsWatermarkTitle : '${l10n.settingsWatermarkTitle} 🔒',
        subtitle: l10n.settingsWatermarkSubtitle, keywords: 'ウォーターマーク premium プレミアム watermark',
        onTap: _showWatermarkSetting, accent: const Color(0xFFB15CFF),
      ),
      (
        icon: Icons.import_export, title: l10n.settingsTransferTitle, subtitle: l10n.settingsTransferSubtitle,
        keywords: '引き継ぎ エクスポート インポート 他端末 niatra transfer export import', onTap: () => context.push('/settings/transfer'), accent: const Color(0xFF3DDC97),
      ),
      (
        icon: Icons.font_download_outlined, title: l10n.settingsFontTitle, subtitle: l10n.settingsFontSubtitle,
        keywords: 'フォント ttf otf font', onTap: () => context.push('/settings/fonts'), accent: const Color(0xFFFFB020),
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
            ? TextField(controller: _searchController, autofocus: true, decoration: InputDecoration(hintText: l10n.settingsSearchHint, border: InputBorder.none))
            : Text(l10n.settingsScreenTitle),
        actions: [
          const HelpButton(),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            tooltip: _showSearch ? l10n.commonClose : l10n.commonSearch,
            onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) _searchController.clear(); }),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        filtered.isEmpty
            ? Center(child: Text(l10n.settingsNoResults, style: const TextStyle(color: Colors.grey)))
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
                        child: Text(l10n.settingsTermsLicense,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextButton(
                        onPressed: () => context.push('/settings/privacy-policy'),
                        child: Text(l10n.privacyPolicyScreenTitle,
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

  /// 言語コードから、その言語自身の表記による表示名を返す（仕様書08＋
  /// タスク#102：言語名は現在のUI言語に関わらず、その言語自身の文字で
  /// 表示する。「日本語」「English」「简体中文」「한국어」「繁體中文」
  /// 「Français」「Español」）。
  String _languageLabel(AppLocalizations l10n, String code) => switch (code) {
        'ja' => l10n.settingsLanguageJapanese,
        'en' => l10n.settingsLanguageEnglish,
        'zh' => l10n.settingsLanguageChinese,
        'ko' => l10n.settingsLanguageKorean,
        'zh_Hant' => l10n.settingsLanguageTraditionalChinese,
        'fr' => l10n.settingsLanguageFrench,
        'es' => l10n.settingsLanguageSpanish,
        _ => code,
      };

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
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${settings.defaultFps} fps', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.chevron_right),
                  ]),
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
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_languageLabel(l10n, settings.language),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: () async {
                    // 対応言語：日本語・English・简体中文・한국어・繁體中文・
                    // Français・Español（仕様書08＋タスク#102）。
                    final languages = <String>['ja', 'en', 'zh', 'ko', 'zh_Hant', 'fr', 'es'];
                    final selected = await showDialog<String>(
                      context: ctx,
                      builder: (dctx) => SimpleDialog(
                        title: Text(l10n.settingsLanguage),
                        children: [
                          for (final code in languages)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(dctx, code),
                              child: Text(_languageLabel(l10n, code),
                                  style: TextStyle(
                                      fontWeight:
                                          settings.language == code ? FontWeight.bold : FontWeight.normal)),
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
                Text(l10n.settingsDrawingAreaTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(l10n.settingsDrawingAreaHint,
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsDrawingAreaWiden),
                  value: enabled,
                  onChanged: (v) {
                    setS(() => enabled = v);
                    settings.setDefaultDrawingArea(enabled: v, scale: scale);
                  },
                ),
                if (enabled) ...[
                  Row(
                    children: [
                      Text(l10n.settingsDrawingAreaScale),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          min: 1.0, max: 10.0,
                          value: scale,
                          divisions: 18,
                          label: l10n.settingsScaleValue(scale.toStringAsFixed(1)),
                          onChanged: (v) {
                            setS(() => scale = v);
                            settings.setDefaultDrawingArea(enabled: enabled, scale: v);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: EditableSliderValue(
                          text: l10n.settingsScaleValue(scale.toStringAsFixed(1)),
                          textAlign: TextAlign.center,
                          value: scale, min: 1.0, max: 10.0, isInt: false,
                          onChanged: (v) {
                            setS(() => scale = v.toDouble());
                            settings.setDefaultDrawingArea(enabled: enabled, scale: v.toDouble());
                          },
                        ),
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

}
