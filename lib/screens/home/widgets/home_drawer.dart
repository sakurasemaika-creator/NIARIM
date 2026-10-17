import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/font_fallback.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key, this.permanent = false});

  /// 広いPC画面で、ホームの左側へ常に表示する側面パネルとして使うか。
  /// このときは引き出しではないので、項目を押しても閉じる操作をしない
  /// （閉じる操作＝Navigator.popがホーム画面ごと閉じてしまう）。
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    void open(String route) {
      if (!permanent) Navigator.pop(context);
      context.push(route);
    }

    // 側面パネルはScaffoldの外に置くので、状態バー・ナビゲーションバーの
    // 余白を自分で取る（取らないと最後の項目がナビゲーションバーの下に隠れ、
    // 見出しの丸が状態バーの時計と重なる）。
    final inset = permanent ? MediaQuery.paddingOf(context) : EdgeInsets.zero;
    final list = ListView(
      padding: EdgeInsets.only(bottom: inset.bottom),
      children: [
        // テーマの差し色を使ったグラデーションヘッダー（固定の濃紺ではなく
        // 選択中テーマに追従する）。
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            permanent ? 20 + inset.top : 56,
            20,
            20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.secondary],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.movie_creation_outlined,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              // ホーム画面AppBarのNIARIMと同じく、明朝を明示指定し太字・
              // 文字間広めで可読性を上げる。文字色はテーマの差し色（背景の
              // グラデーション）に対して自動でコントラストが確保される
              // onPrimaryを使う（差し色が明るいテーマでも視認性を保つ）。
              Text(
                'NIARIM',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontFamily: 'HakkouMincho',
                  fontFamilyFallback: const ['NotoSerifJP'],
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.homeDrawerAppTagline,
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // メニュー項目名はくらむぼんで統一する。
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(
            l10n.homeTabShared,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/shared'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(
            l10n.homeTabTrash,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/trash'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(
            l10n.homeDrawerAutofillPreset,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/autofill-presets'),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(
            l10n.homeDrawerStorage,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/storage'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(
            l10n.homeDrawerSettings,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/settings'),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(
            l10n.homeDrawerHelp,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/help'),
        ),
        ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: Text(
            l10n.homeDrawerTips,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/tips'),
        ),
        ListTile(
          leading: Icon(
            Icons.workspace_premium_outlined,
            color: scheme.primary,
          ),
          title: Text(
            l10n.homeDrawerPremium,
            style: const TextStyle(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          onTap: () => open('/premium'),
        ),
      ],
    );
    if (!permanent) return Drawer(child: list);
    return Material(
      color: Theme.of(context).drawerTheme.backgroundColor ?? scheme.surface,
      // 横向きで左側に出るナビゲーションバーも避ける。
      child: SafeArea(top: false, right: false, bottom: false, child: list),
    );
  }
}
