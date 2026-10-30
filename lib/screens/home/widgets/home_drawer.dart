import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/accent_text_theme.dart';
import '../../../config/font_fallback.dart';
import '../../canvas/widgets/canvas_icon_button.dart';
import '../../../widgets/app_tutorial.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final menuForeground =
        theme.appBarTheme.foregroundColor ?? scheme.onSurface;
    final drawerBackground = theme.cardTheme.color ?? scheme.surface;
    // Drawer icons follow the current Appearance accent for text and icons
    // (the header keeps the accent fill), never a copied default-red swatch.
    // Use a conditional theme-derived outline only when that colour is too
    // close to the drawer surface.
    final accentText = AccentTextTheme.of(context);
    final iconShadows = CanvasIconButton.actionShadows(
      accentText,
      drawerBackground,
      scheme,
    );
    Widget drawerIcon(IconData icon) =>
        Icon(icon, color: accentText, shadows: iconShadows);
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: drawerBackground,
      child: ListTileTheme(
        data: theme.listTileTheme.copyWith(
          iconColor: accentText,
          textColor: menuForeground,
          titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
            color: menuForeground,
          ),
        ),
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
              leading: drawerIcon(Icons.share_outlined),
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
              leading: drawerIcon(Icons.delete_outline),
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
              leading: drawerIcon(Icons.palette_outlined),
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
              leading: drawerIcon(Icons.cleaning_services_outlined),
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
              leading: drawerIcon(Icons.settings_outlined),
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
              leading: drawerIcon(Icons.school_outlined),
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
              leading: drawerIcon(Icons.help_outline),
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
              leading: drawerIcon(Icons.lightbulb_outline),
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
              leading: drawerIcon(Icons.workspace_premium_outlined),
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
      ),
    );
  }
}
