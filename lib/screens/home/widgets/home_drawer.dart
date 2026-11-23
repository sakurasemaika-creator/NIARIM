import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config/accent_text_theme.dart';
import '../../../services/community_service.dart';
import '../../../services/google_auth_service.dart';
import '../../../services/api/community_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/reward_navigation_labels.dart';
import '../../../l10n/creator_mission_labels.dart';
import '../../help/guide_hub_screen.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/line_break.dart';
import '../../canvas/widgets/canvas_icon_button.dart';

/// Server status alone controls the mission drawer exclamation mark.
bool missionDrawerNeedsAttention(Map<String, dynamic>? result) =>
    result?['hasAchievedUnclaimed'] == true;

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key, this.refreshToken = 0});

  /// 画面の幅[screenWidth]での引き出しの幅。外側（押して閉じる幕）に少なく
  /// とも上部バーの高さ（56px）を残す。普通のスマホ（360px以上）とPCは
  /// Materialの既定の304px（以前は320pxの画面でも304pxのままで、外側が約16px
  /// しか残らず、外を押して閉じにくかった）。
  static double widthFor(double screenWidth) {
    final roomy = screenWidth - kToolbarHeight;
    return roomy < 304 ? (roomy < 0 ? 0 : roomy) : 304;
  }

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
    // Isolated library previews can render without an authentication
    // provider. They must behave as signed out, never as another user.
    final accountId = context.watch<GoogleAuthService?>()?.account?.id;
    final api = context.read<CommunityService>().api;
    if (_accountId != accountId ||
        !identical(_lastApi, api) ||
        _lastRefreshToken != widget.refreshToken) {
      _accountId = accountId;
      _lastApi = api;
      _lastRefreshToken = widget.refreshToken;
      // Account isolation: the server resolves the user from the Google token.
      // Offline and signed-out states never display a stale exclamation mark.
      _attentionFuture = accountId != null && api != null
          ? api.myCreatorMissionAttention()
          : null;
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final menuForeground =
        theme.appBarTheme.foregroundColor ?? scheme.onSurface;
    final drawerBackground = theme.cardTheme.color ?? scheme.surface;
    // Drawer icons are icons on the drawer: the Appearance accent text and
    // icon colour (the accent itself unless one is chosen), never a copied
    // default-red swatch. Use a conditional theme-derived outline only when
    // that colour is too close to the drawer surface.
    final iconColor = AccentTextTheme.of(context);
    final iconShadows = CanvasIconButton.actionShadows(
      iconColor,
      drawerBackground,
      scheme,
    );
    Widget drawerIcon(IconData icon) =>
        Icon(icon, color: iconColor, shadows: iconShadows);
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      width: HomeDrawer.widthFor(MediaQuery.sizeOf(context).width),
      backgroundColor: drawerBackground,
      child: ListTileTheme(
        data: theme.listTileTheme.copyWith(
          iconColor: iconColor,
          textColor: menuForeground,
          titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
            color: menuForeground,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              // 横向きで画面の端にボタンの帯・切り欠きがあるときも、見出しの
              // 字は帯の下に描かない（色の帯は端まで。下の行はListTileが
              // 避ける）。帯が無ければ今までどおり。
              padding: EdgeInsets.fromLTRB(
                20 + MediaQuery.paddingOf(context).left,
                56,
                20 + MediaQuery.paddingOf(context).right,
                20,
              ),
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
                  // アプリ名は見出しなので、ほかの見出し・引き出しの項目と同じ
                  // くらむぼん（以前は、今は無いホームの上部バーの「NIARIM」に
                  // そろえた明朝だった）。
                  Text(
                    'NIARIM',
                    style: localizedHeadingStyle(
                      context,
                      TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 韓国語は語の途中で行を変えない（引き出しが狭い画面では
                  // 「제 / 작」と切れた）。読み上げは元の文。
                  Text.rich(
                    TextSpan(
                      text: keepKoreanWordsTogether(l10n.homeDrawerAppTagline),
                      semanticsLabel: l10n.homeDrawerAppTagline,
                    ),
                    style: TextStyle(color: scheme.onPrimary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // コイン・特典 → 契約状態 → 使い方 → 設定 → 容量削減
            ListTile(
              key: const Key('homeCoinBenefitsMenuItem'),
              leading: drawerIcon(Icons.toll_outlined),
              trailing: _attentionFuture == null
                  ? null
                  : FutureBuilder<Map<String, dynamic>>(
                      future: _attentionFuture,
                      builder: (context, snapshot) {
                        // FutureBuilder may temporarily retain the previous
                        // account's successful snapshot while awaiting a new
                        // Future. Never show the old user's badge during that
                        // handoff or after a new request fails.
                        if (snapshot.connectionState != ConnectionState.done ||
                            snapshot.hasError ||
                            !snapshot.hasData ||
                            !missionDrawerNeedsAttention(snapshot.data)) {
                          return const SizedBox.shrink();
                        }
                        final label = CreatorMissionLabels.of(
                          context,
                        ).get('drawerAttention');
                        return Tooltip(
                          message: label,
                          child: Semantics(
                            label: label,
                            child: CircleAvatar(
                              key: const Key('homeCreatorMissionAttention'),
                              radius: 11,
                              backgroundColor: scheme.primary,
                              child: Text(
                                '!',
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
              title: Text(
                RewardNavigationLabels.of(context)['hub'],
                style: localizedHeadingStyle(context, const TextStyle()),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/rewards');
              },
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('homeMembershipBenefitsMenuItem'),
              leading: drawerIcon(Icons.workspace_premium_outlined),
              title: Text(
                RewardNavigationLabels.of(context)['membership'],
                style: localizedHeadingStyle(context, const TextStyle()),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/membership');
              },
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('homeGuideMenuItem'),
              leading: drawerIcon(Icons.menu_book_outlined),
              title: Text(
                guideHubTitle(context),
                style: localizedHeadingStyle(context, const TextStyle()),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/help');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: drawerIcon(Icons.settings_outlined),
              title: Text(
                l10n.homeDrawerSettings,
                style: localizedHeadingStyle(context, const TextStyle()),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: drawerIcon(Icons.cleaning_services_outlined),
              title: Text(
                l10n.homeDrawerStorage,
                style: localizedHeadingStyle(context, const TextStyle()),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/storage');
              },
            ),
          ],
        ),
      ),
    );
  }
}
