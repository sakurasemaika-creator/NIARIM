import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // テーマの差し色を使ったグラデーションヘッダー（固定の濃紺ではなく
          // 選択中テーマに追従する）。
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
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
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/shared');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(
              l10n.homeTabTrash,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/trash');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(
              l10n.homeDrawerAutofillPreset,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/autofill-presets');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(
              l10n.homeDrawerStorage,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/storage');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(
              l10n.homeDrawerSettings,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(
              l10n.homeDrawerHelp,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/help');
            },
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(
              l10n.homeDrawerTips,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/tips');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.workspace_premium_outlined,
              color: scheme.primary,
            ),
            title: Text(
              l10n.homeDrawerPremium,
              style: const TextStyle(fontFamily: 'Kuramubon'),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/premium');
            },
          ),
        ],
      ),
    );
  }
}
