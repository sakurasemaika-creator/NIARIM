import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';

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
    // 設定内検索バーあり（項目が増えても検索で到達可能）。
    // 各項目にタイトル・サブタイトルに加えて検索キーワードを持たせ、
    // 部分一致でカテゴリ一覧を絞り込む。
    final entries = [
      (
        icon: Icons.settings,
        title: l10n.settingsBasicTitle,
        subtitle: l10n.settingsBasicSubtitle,
        keywords: 'fps 背景色 言語 描画領域初期値',
        onTap: _showBasicSettings,
        accent: const Color(0xFFFF5C7A),
      ),
      (
        // 容量・重さに影響する設定（Undo回数・ゴミ箱自動削除等）は全て
        // パフォーマンス設定へ統合した（旧「詳細」カテゴリは廃止）。
        icon: Icons.speed,
        title: l10n.settingsPerformanceTitle,
        subtitle: l10n.settingsPerformanceSubtitle,
        keywords:
            '品質 タイルキャッシュ 低品質 中品質 高品質 カスタム オニオンスキン 傾き検知 undo ゴミ箱 削除 performance quality cache',
        onTap: () => context.push('/settings/performance'),
        accent: const Color(0xFF3DDC97),
      ),
      (
        icon: Icons.touch_app,
        title: l10n.settingsGestureTitle,
        subtitle: l10n.settingsGestureSubtitle,
        keywords: 'タップ スワイプ 長押し ペンボタン gesture tap swipe',
        onTap: () => context.push('/settings/gestures'),
        accent: const Color(0xFFFFB020),
      ),
      (
        icon: Icons.keyboard,
        title: l10n.settingsShortcutTitle,
        subtitle: l10n.settingsShortcutSubtitle,
        keywords: 'ショートカット キーボード 左手デバイス キー割り当て shortcut keyboard key',
        onTap: () => context.push('/settings/shortcuts'),
        accent: const Color(0xFF3AA6FF),
      ),
      (
        icon: Icons.edit,
        title: l10n.settingsPenTitle,
        subtitle: l10n.settingsPenSubtitle,
        keywords: '筆圧 傾き ペンボタン 筆圧カーブ pen pressure tilt',
        onTap: () => context.push('/settings/pen'),
        accent: const Color(0xFFB15CFF),
      ),
      (
        icon: Icons.desktop_windows,
        title: l10n.settingsWorkspaceTitle,
        subtitle: l10n.settingsWorkspaceSubtitle,
        keywords: 'ツールバー パネル配置 右利き 左利き dex デックス workspace toolbar panel',
        onTap: () => context.push('/settings/workspace'),
        accent: const Color(0xFF3AA6FF),
      ),
      (
        icon: Icons.format_color_fill,
        title: l10n.settingsBucketTitle,
        subtitle: l10n.settingsBucketSubtitle,
        keywords: 'バケツ 塗り つぶし 許容誤差 拡張 隙間 線の下 bucket fill tolerance expand',
        onTap: () => context.push('/settings/bucket'),
        accent: const Color(0xFFFFB020),
      ),
      (
        icon: Icons.palette,
        title: l10n.settingsThemeTitle,
        subtitle: l10n.settingsThemeSubtitle,
        keywords: 'テーマ 配色 ベースカラー アクセントカラー theme color',
        onTap: () => context.push('/settings/theme'),
        accent: const Color(0xFFFF5C7A),
      ),
      // 無料会員のみ🔒マーク付きで表示
      (
        icon: Icons.water,
        title: isPremium
            ? l10n.settingsWatermarkTitle
            : '${l10n.settingsWatermarkTitle} 🔒',
        subtitle: l10n.settingsWatermarkSubtitle,
        keywords: 'ウォーターマーク premium プレミアム watermark',
        onTap: _showWatermarkSetting,
        accent: const Color(0xFFB15CFF),
      ),
      (
        icon: Icons.import_export,
        title: l10n.settingsTransferTitle,
        subtitle: l10n.settingsTransferSubtitle,
        keywords: '引き継ぎ エクスポート インポート 他端末 niatra transfer export import',
        onTap: () => context.push('/settings/transfer'),
        accent: const Color(0xFF3DDC97),
      ),
      (
        icon: Icons.font_download_outlined,
        title: l10n.settingsFontTitle,
        subtitle: l10n.settingsFontSubtitle,
        keywords: 'フォント ttf otf font',
        onTap: () => context.push('/settings/fonts'),
        accent: const Color(0xFFFFB020),
      ),
    ];
    final filtered = _query.isEmpty
        ? entries
        : entries
              .where(
                (e) =>
                    e.title.toLowerCase().contains(_query) ||
                    e.subtitle.toLowerCase().contains(_query) ||
                    e.keywords.toLowerCase().contains(_query),
              )
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.settingsSearchHint,
                  border: InputBorder.none,
                ),
              )
            : Text(l10n.settingsScreenTitle),
        actions: [
          const HelpButton(),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            tooltip: _showSearch ? l10n.commonClose : l10n.commonSearch,
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchController.clear();
            }),
          ),
        ],
      ),
      body: desktopCentered(
        context,
        filtered.isEmpty
            ? Center(
                child: Text(
                  l10n.settingsNoResults,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final e in filtered)
                    _item(e.icon, e.title, e.subtitle, e.onTap, e.accent),
                  if (_query.isEmpty) ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextButton(
                        onPressed: () => context.push('/settings/license'),
                        child: Text(
                          l10n.settingsTermsLicense,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextButton(
                        onPressed: () =>
                            context.push('/settings/privacy-policy'),
                        child: Text(
                          l10n.privacyPolicyScreenTitle,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
      ),
    );
  }

  // 各項目を独立したカードとして浮かせる（影・角丸・タップ時のインク
  // エフェクトを角丸に沿わせる）。
  Widget _item(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 言語コードから、その言語自身の表記による表示名を返す（言語名は
  /// 現在のUI言語に関わらず、その言語自身の文字で表示する。「日本語」
  /// 「English」「简体中文」「한국어」「繁體中文」「Français」「Español」）。
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
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.settingsBasicSheetTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(l10n.settingsDefaultFps),
                  subtitle: Text(l10n.settingsDefaultFpsSubtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${settings.defaultFps} fps',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    // 新規プロジェクト作成画面のFPS選択肢と統一（8/12/24のみ）。
                    final selected = await showDialog<int>(
                      context: ctx,
                      builder: (dctx) => SimpleDialog(
                        title: Text(l10n.settingsDefaultFps),
                        children: [8, 12, 24]
                            .map(
                              (fps) => SimpleDialogOption(
                                onPressed: () => Navigator.pop(dctx, fps),
                                child: Text(
                                  '$fps fps',
                                  style: TextStyle(
                                    fontWeight: settings.defaultFps == fps
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _languageLabel(l10n, settings.language),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    // 対応言語：日本語・English・简体中文・한국어・繁體中文・
                    // Français・Español。
                    final languages = <String>[
                      'ja',
                      'en',
                      'zh',
                      'ko',
                      'zh_Hant',
                      'fr',
                      'es',
                    ];
                    final selected = await showDialog<String>(
                      context: ctx,
                      builder: (dctx) => SimpleDialog(
                        title: Text(l10n.settingsLanguage),
                        children: [
                          for (final code in languages)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(dctx, code),
                              child: Text(
                                _languageLabel(l10n, code),
                                style: TextStyle(
                                  fontWeight: settings.language == code
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
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
                // 描画領域初期値
                Text(
                  l10n.settingsDrawingAreaTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.settingsDrawingAreaHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                        child: SteppedSlider(
                          min: 1.0,
                          max: 10.0,
                          value: scale,
                          divisions: 18,
                          step: 0.5,
                          label: l10n.settingsScaleValue(
                            scale.toStringAsFixed(1),
                          ),
                          onChanged: (v) {
                            setS(() => scale = v);
                            settings.setDefaultDrawingArea(
                              enabled: enabled,
                              scale: v,
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: EditableSliderValue(
                          text: l10n.settingsScaleValue(
                            scale.toStringAsFixed(1),
                          ),
                          textAlign: TextAlign.center,
                          value: scale,
                          min: 1.0,
                          max: 10.0,
                          isInt: false,
                          onChanged: (v) {
                            setS(() => scale = v.toDouble());
                            settings.setDefaultDrawingArea(
                              enabled: enabled,
                              scale: v.toDouble(),
                            );
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
