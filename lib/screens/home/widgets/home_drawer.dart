import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/community_service.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/api/community_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/reward_navigation_labels.dart';
import '../../../l10n/creator_mission_labels.dart';
import '../../../config/font_fallback.dart';
import '../../canvas/widgets/canvas_icon_button.dart';

/// Server status alone controls the mission drawer exclamation mark.
bool missionDrawerNeedsAttention(Map<String, dynamic>? result) =>
    result?['hasAchievedUnclaimed'] == true;

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key, this.refreshToken = 0});

  /// Increment when the hamburger menu opens, to refresh achievements after
  /// posting a work or returning from the mission claim screen.
  final int refreshToken;

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  String? _accountId;
  CommunityApi? _lastApi;
  int? _lastRefreshToken;
  Future<Map<String, dynamic>>? _attentionFuture;

  @override
  Widget build(BuildContext context) {
    final accountId = context.watch<GoogleAuthService>().account?.id;
    final api = context.read<CommunityService>().api;
    if (_accountId != accountId || !identical(_lastApi, api) ||
        _lastRefreshToken != widget.refreshToken) {
      _accountId = accountId;
      _lastApi = api;
      _lastRefreshToken = widget.refreshToken;
      // Account isolation: the server resolves the user from the Google token.
      // Offline and signed-out states never display a stale exclamation mark.
      _attentionFuture = accountId != null && api != null
          ? api.myCreatorMissionAttention() : null;
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final menuForeground =
        theme.appBarTheme.foregroundColor ?? scheme.onSurface;
    final drawerBackground = theme.cardTheme.color ?? scheme.surface;
    // Drawer icons follow the current Appearance accent, never a copied
    // default-red swatch. Use a conditional theme-derived outline only when
    // the accent is too close to the drawer surface.
    final iconShadows = CanvasIconButton.actionShadows(
      scheme.primary,
      drawerBackground,
      scheme,
    );
    Widget drawerIcon(IconData icon) =>
        Icon(icon, color: scheme.primary, shadows: iconShadows);
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: drawerBackground,
      child: ListTileTheme(
        data: theme.listTileTheme.copyWith(
          iconColor: scheme.primary,
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
              key: const Key('homeBenefitExchangeMenuItem'),
              leading: drawerIcon(Icons.redeem_outlined),
              title: Text(RewardNavigationLabels.of(context)['exchange'],
                style: const TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                )),
              onTap: () {
                Navigator.pop(context);
                context.push('/rewards');
              },
            ),
            ListTile(
              key: const Key('homeCreatorMissionsMenuItem'),
              leading: drawerIcon(Icons.flag_outlined),
              trailing: _attentionFuture == null ? null
                  : FutureBuilder<Map<String, dynamic>>(
                      future: _attentionFuture,
                      builder: (context, snapshot) {
                        // FutureBuilder may temporarily retain the previous
                        // account's successful snapshot while awaiting a new
                        // Future. Never show the old user's badge during that
                        // handoff or after a new request fails.
                        if (snapshot.connectionState != ConnectionState.done ||
                            snapshot.hasError || !snapshot.hasData ||
                            !missionDrawerNeedsAttention(snapshot.data)) {
                          return const SizedBox.shrink();
                        }
                        final label =
                            CreatorMissionLabels.of(context).get('drawerAttention');
                        return Tooltip(
                          message: label,
                          child: Semantics(
                            label: label,
                            child: CircleAvatar(
                              key: const Key('homeCreatorMissionAttention'),
                              radius: 11,
                              backgroundColor: scheme.primary,
                              child: Text('!',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              title: Text(RewardNavigationLabels.of(context)['missions'],
                style: const TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                )),
              onTap: () {
                Navigator.pop(context);
                context.push('/creator-missions');
              },
            ),
            ListTile(
              key: const Key('homeEarnCoinsMenuItem'),
              leading: drawerIcon(Icons.smart_display_outlined),
              title: Text(RewardNavigationLabels.of(context)['earn'],
                style: const TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                )),
              onTap: () {
                Navigator.pop(context);
                context.push('/earn-coins');
              },
            ),
            ListTile(
              key: const Key('homeMembershipBenefitsMenuItem'),
              leading: drawerIcon(Icons.workspace_premium_outlined),
              title: Text(RewardNavigationLabels.of(context)['membership'],
                style: const TextStyle(
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                )),
              onTap: () {
                Navigator.pop(context);
                context.push('/membership');
              },
            ),
          ],
        ),
      ),
    );
  }
}
