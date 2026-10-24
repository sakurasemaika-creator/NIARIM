import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/font_fallback.dart';
import '../../../config/accent_text_theme.dart';
import '../../../widgets/app_tutorial.dart';

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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: BoxDecoration(color: scheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: scheme.onPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
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
                  style: TextStyle(color: scheme.onPrimary, fontSize: 12),
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
            onTap: () {
              Navigator.pop(context);
              context.push('/shared');
            },
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
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
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
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
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
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          // 初回起動に出した使い方（図つきの数ページ）をもう一度見る。
          ListTile(
            key: const Key('homeDrawerTutorial'),
            leading: const Icon(Icons.school_outlined),
            title: Text(
              l10n.homeDrawerTutorial,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              AppTutorial.show(context);
            },
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
            onTap: () {
              Navigator.pop(context);
              context.push('/help');
            },
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
            onTap: () {
              Navigator.pop(context);
              context.push('/tips');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.workspace_premium_outlined,
              color: AccentTextTheme.of(context),
            ),
            title: Text(
              l10n.homeDrawerPremium,
              style: const TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
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
