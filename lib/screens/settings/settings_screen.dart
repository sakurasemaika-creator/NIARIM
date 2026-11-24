import 'widgets/settings_choice_sheet.dart';
import 'widgets/settings_value_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/keep_together_text.dart';
import '../../services/settings_service.dart';
import '../../services/community_notice.dart';
import '../../services/first_use_tooltip_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/app_toast_messenger.dart';
import '../../widgets/responsive.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../../utils/app_locale.dart';
import '../../config/accent_text_theme.dart';
import '../../utils/name_collation.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/grouped_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _supportEmail = 'support@miranima-studio.com';
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      // Compared in the same form as the entries (’ and no-break spaces in
      // French text, ' and plain spaces from the keyboard, any letter case).
      setState(() => _query = foldName(_searchController.text.trim()));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // はじめて使う機能の説明（吹き出し）を、次に使うときにもう一度出す。
  Future<void> _resetFeatureTips() async {
    final l10n = AppLocalizations.of(context)!;
    await context.read<FirstUseTooltipService>().resetAll();
    if (!mounted) return;
    showOwnSnackBar(
      context,
      SnackBar(
        key: const ValueKey('settingsTipsResetNotice'),
        content: Text(l10n.settingsTipsResetDone),
      ),
    );
  }

  Future<void> _showSupport() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsSupportTitle),
        content: const SelectableText(_supportEmail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.commonCopy),
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _supportEmail));
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.qrShareCopiedSnackbar)),
                );
              }
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.settingsSupportForm),
            onPressed: () async {
              var opened = false;
              try {
                opened = await launchUrl(
                  Uri.https('niarim.miranima-studio.com', '/contact/'),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                // The address stays available in the dialog.
              }
              if (!opened && mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.settingsSupportLinkFailed)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountDeletion() async {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).toLanguageTag();
    final uri = Uri.https('niarim.miranima-studio.com', '/account-deletion/', {
      'lang': language == 'zh' ? 'zh-Hans' : language,
    });
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Keep the settings screen available for retry.
    }
    if (!opened && mounted) {
      showOwnSnackBar(
        context,
        SnackBar(
          key: const ValueKey('settingsAccountDeletionLinkNotice'),
          content: Text(l10n.settingsAccountDeletionLinkFailed),
        ),
      );
    }
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
        group: _SettingsGroup.general,
        subtitle: l10n.settingsBasicSubtitle,
        keywords: 'fps 言語 描画領域初期値',
        onTap: _showBasicSettings,
      ),
      (
        // 容量・重さに影響する設定（Undo回数・ゴミ箱自動削除等）は全て
        // パフォーマンス設定へ統合した（旧「詳細」カテゴリは廃止）。
        icon: Icons.speed,
        title: l10n.settingsPerformanceTitle,
        group: _SettingsGroup.general,
        subtitle: l10n.settingsPerformanceSubtitle,
        keywords:
            '品質 タイルキャッシュ 低品質 中品質 高品質 カスタム オニオンスキン 傾き検知 undo ゴミ箱 削除 performance quality cache',
        onTap: () => context.push('/settings/performance'),
      ),
      (
        icon: Icons.touch_app,
        title: l10n.settingsGestureTitle,
        group: _SettingsGroup.drawing,
        subtitle: l10n.settingsGestureSubtitle,
        keywords: 'タップ スワイプ 長押し ペンボタン gesture tap swipe',
        onTap: () => context.push('/settings/gestures'),
      ),
      (
        icon: Icons.keyboard,
        title: l10n.settingsShortcutTitle,
        group: _SettingsGroup.drawing,
        subtitle: l10n.settingsShortcutSubtitle,
        keywords: 'ショートカット キーボード 左手デバイス キー割り当て shortcut keyboard key',
        onTap: () => context.push('/settings/shortcuts'),
      ),
      (
        icon: Icons.edit,
        title: l10n.settingsPenTitle,
        group: _SettingsGroup.drawing,
        subtitle: l10n.settingsPenSubtitle,
        keywords: '筆圧 傾き ペンボタン 筆圧カーブ pen pressure tilt',
        onTap: () => context.push('/settings/pen'),
      ),
      (
        icon: Icons.desktop_windows,
        title: l10n.settingsWorkspaceTitle,
        group: _SettingsGroup.appearance,
        subtitle: l10n.settingsWorkspaceSubtitle,
        keywords: 'ツールバー パネル配置 右利き 左利き dex デックス workspace toolbar panel',
        onTap: () => context.push('/settings/workspace'),
      ),
      (
        icon: Icons.format_color_fill,
        title: l10n.settingsBucketTitle,
        group: _SettingsGroup.drawing,
        subtitle: l10n.settingsBucketSubtitle,
        keywords: 'バケツ 塗り つぶし 許容誤差 拡張 隙間 線の下 bucket fill tolerance expand',
        onTap: () => context.push('/settings/bucket'),
      ),
      (
        // 自動塗りプリセットを制作関連の設定から管理する。
        icon: Icons.auto_fix_high_outlined,
        title: l10n.homeDrawerAutofillPreset,
        group: _SettingsGroup.drawing,
        subtitle: l10n.tipsAutofillPresetTitle,
        keywords: '制作 自動塗り パーツ 色セット プリセット autofill presets',
        onTap: () => context.push('/autofill-presets'),
      ),
      (
        icon: Icons.widgets_outlined,
        title: l10n.widgetSettingsTitle,
        group: _SettingsGroup.appearance,
        subtitle: l10n.widgetSettingsSubtitle,
        keywords: 'ウィジェット ホーム画面 widget home screen 作品 色',
        onTap: () => context.push('/settings/widget'),
      ),
      (
        icon: Icons.palette,
        title: l10n.settingsThemeTitle,
        group: _SettingsGroup.appearance,
        subtitle: l10n.settingsThemeSubtitle,
        keywords: 'テーマ 配色 ベースカラー アクセントカラー theme color',
        onTap: () => context.push('/settings/theme'),
      ),
      (
        icon: Icons.notifications_outlined,
        title: devicePushLabel(l10n),
        group: _SettingsGroup.general,
        subtitle: devicePushDescription(l10n),
        keywords: '通知 プッシュ push notifications',
        onTap: () => context.push(communityNotificationSettingsRoute),
      ),
      // 無料会員はMaterialのlockアイコンで表示
      (
        icon: isPremium ? Icons.water : Icons.lock_outline,
        title: l10n.settingsWatermarkTitle,
        group: _SettingsGroup.general,
        subtitle: l10n.settingsWatermarkSubtitle,
        keywords: 'ウォーターマーク premium プレミアム watermark',
        onTap: _showWatermarkSetting,
      ),
      (
        icon: Icons.import_export,
        title: l10n.settingsTransferTitle,
        group: _SettingsGroup.data,
        subtitle: l10n.settingsTransferSubtitle,
        keywords: '引き継ぎ エクスポート インポート 他端末 niatra transfer export import',
        onTap: () => context.push('/settings/transfer'),
      ),
      (
        icon: Icons.font_download_outlined,
        title: l10n.settingsFontTitle,
        group: _SettingsGroup.appearance,
        subtitle: l10n.settingsFontSubtitle,
        keywords: 'フォント ttf otf font',
        onTap: () => context.push('/settings/fonts'),
      ),
      (
        icon: Icons.lightbulb_outline,
        title: l10n.settingsTipsResetTitle,
        group: _SettingsGroup.data,
        subtitle: l10n.settingsTipsResetSubtitle,
        keywords: '説明 吹き出し ヒント もう一度 再表示 リセット tips hint reset',
        onTap: _resetFeatureTips,
      ),
      (
        icon: Icons.bug_report_outlined,
        title: l10n.settingsErrorLogTitle,
        group: _SettingsGroup.data,
        subtitle: l10n.settingsErrorLogSubtitle,
        keywords: 'エラー 不具合 報告 ログ コピー error log bug report copy',
        onTap: () => context.push('/settings/error-log'),
      ),
      (
        icon: Icons.support_agent_outlined,
        title: l10n.settingsSupportTitle,
        group: _SettingsGroup.data,
        subtitle: _supportEmail,
        keywords: 'サポート メール support contact help',
        onTap: _showSupport,
      ),
      (
        icon: Icons.person_remove_outlined,
        title: l10n.settingsAccountDeletionTitle,
        group: _SettingsGroup.data,
        subtitle: l10n.settingsAccountDeletionSubtitle,
        keywords: 'アカウント 退会 削除 delete account',
        onTap: _openAccountDeletion,
      ),
    ];
    final filtered = _query.isEmpty
        ? entries
        : entries
              .where(
                (e) =>
                    nameMatches(e.title, _query) ||
                    nameMatches(e.subtitle, _query) ||
                    nameMatches(e.keywords, _query),
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
            : FitOrHideTitle(l10n.settingsScreenTitle),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  for (final (i, group) in [
                    for (final g in _SettingsGroup.values)
                      if (filtered.any((e) => e.group == g)) g,
                  ].indexed) ...[
                    if (i > 0) const SizedBox(height: 24),
                    GroupedSheet(
                      title: group.title(l10n),
                      children: [
                        for (final e in filtered)
                          if (e.group == group)
                            SheetRow(
                              icon: e.icon,
                              title: e.title,
                              subtitle: e.subtitle,
                              onTap: e.onTap,
                            ),
                      ],
                    ),
                  ],
                  if (_query.isEmpty) ...[
                    const SizedBox(height: 24),
                    GroupedSheet(
                      children: [
                        SheetRow(
                          title: l10n.settingsTermsLicense,
                          onTap: () => context.push('/settings/license'),
                        ),
                        SheetRow(
                          title: l10n.privacyPolicyScreenTitle,
                          onTap: () => context.push('/settings/privacy-policy'),
                        ),
                      ],
                    ),
                  ],
                ],
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

  /// 言語の名前を、その言語の本文の書体で描く書式。
  TextStyle _languageNameStyle(String code) {
    final locale = localeFromLanguageCode(code);
    return TextStyle(
      fontFamily: bodyFontFamilyFor(locale),
      fontFamilyFallback: bodyFontFallbackFor(locale),
    );
  }

  /// 一覧のダイアログの選択肢：名前と、選んでいるものだけ右端の印。
  Widget _checkedOption(
    BuildContext dialogContext, {
    required bool selected,
    required Widget child,
  }) => Semantics(
    selected: selected,
    child: Row(
      children: [
        Expanded(child: child),
        if (selected)
          Icon(Icons.check, size: 20, color: AccentTextTheme.of(dialogContext))
        else
          const SizedBox(width: 20),
      ],
    ),
  );

  void _showWatermarkSetting() {
    if (!context.read<PremiumService>().isFeatureAvailable(
      PremiumFeature.watermark,
    )) {
      showPremiumBanner(context, feature: PremiumFeature.watermark);
      return;
    }
    context.push('/settings/watermark');
  }

  void _showBasicSettings() {
    final settings = context.read<SettingsService>();
    var enabled = settings.defaultDrawingAreaEnabled;
    var scale = settings.defaultDrawingAreaScale;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final l10n = AppLocalizations.of(ctx)!;
          // シートは中身の高さだけ取る（以前は画面の6割で開き、下半分が
          // 空いていた）。入らない高さ・文字の大きさではシートの中で
          // スクロールする。題・項目名・説明・スイッチ・スライダーの左端を
          // 16pxにそろえる（行は押せる範囲を端まで取り、自分の中で16px空ける）。
          return ScrollableSheetBody(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      l10n.settingsBasicSheetTitle,
                      style: settingsSheetTitleStyle(context),
                    ),
                  ),
                  SettingsValueTile(
                    title: l10n.settingsDefaultFps,
                    subtitle: l10n.settingsDefaultFpsSubtitle,
                    value: l10n.pcStatusFps(settings.defaultFps),
                    onTap: () async {
                      // 新規プロジェクト作成画面のFPS選択肢と統一（8/12/24のみ）。
                      final selected = await showDialog<int>(
                        context: ctx,
                        builder: (dctx) => SimpleDialog(
                          title: Text(l10n.settingsDefaultFps),
                          // 選んでいる値は太字ではなく印で示す（白光明朝は
                          // 太字にしても太くならず、どれを選んでいるか
                          // 見分けられなかった。言語の一覧と同じ形）。
                          children: [
                            for (final fps in const [8, 12, 24])
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(dctx, fps),
                                child: _checkedOption(
                                  dctx,
                                  selected: settings.defaultFps == fps,
                                  child: Text(l10n.pcStatusFps(fps)),
                                ),
                              ),
                          ],
                        ),
                      );
                      if (selected != null) {
                        await settings.setDefaultFps(selected);
                        if (ctx.mounted) setS(() {});
                      }
                    },
                  ),
                  SettingsValueTile(
                    title: l10n.settingsLanguage,
                    value: _languageLabel(l10n, settings.language),
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
                                // 言語の名前はその言語の本文の書体で描く（UIの
                                // 書体で描くと「简体中文」の「简」だけが別の書体・
                                // 太さになった）。選んでいる言語は太字ではなく
                                // 印で示す（白光明朝は太字にしても太くならず、
                                // 中国語・韓国語の名前だけが太く見えた）。
                                child: _checkedOption(
                                  dctx,
                                  selected: settings.language == code,
                                  child: Text(
                                    _languageLabel(l10n, code),
                                    style: _languageNameStyle(code),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                      if (selected != null) {
                        await settings.setLanguage(selected);
                        if (ctx.mounted) setS(() {});
                      }
                    },
                  ),
                  const Divider(height: 25, indent: 16, endIndent: 16),
                  // 描画領域初期値
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.settingsDrawingAreaTitle,
                      style: localizedHeadingStyle(
                        context,
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: messageText(
                      l10n.settingsDrawingAreaHint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(l10n.settingsDrawingAreaWiden),
                    value: enabled,
                    onChanged: (v) {
                      setS(() => enabled = v);
                      settings.setDefaultDrawingArea(enabled: v, scale: scale);
                    },
                  ),
                  if (enabled) ...[
                    LabeledSlider(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      label: l10n.settingsDrawingAreaScale,
                      min: 1.0,
                      max: 10.0,
                      value: scale,
                      divisions: 18,
                      step: 0.5,
                      isInt: false,
                      sliderLabel: l10n.settingsScaleValue(
                        scale.toStringAsFixed(1),
                      ),
                      valueText: l10n.settingsScaleValue(
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
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 設定の一覧のまとまり（上から並べる順）。
enum _SettingsGroup {
  general,
  drawing,
  appearance,
  data;

  String title(AppLocalizations l10n) => switch (this) {
    general => l10n.settingsGroupGeneral,
    drawing => l10n.settingsGroupDrawing,
    appearance => l10n.settingsGroupAppearance,
    data => l10n.settingsGroupDataSupport,
  };
}
