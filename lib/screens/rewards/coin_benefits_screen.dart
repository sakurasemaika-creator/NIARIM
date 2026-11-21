import 'package:flutter/material.dart';

import '../../l10n/reward_navigation_labels.dart';
import 'reward_unlock_screen.dart';
import 'creator_missions_screen.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/fit_or_icon_tab_bar.dart';

/// Unifies redemption, missions and rewarded ads without mixing their state.
class CoinBenefitsScreen extends StatelessWidget {
  const CoinBenefitsScreen({super.key, this.initialTab = 2, this.workId});

  final int initialTab;
  final String? workId;

  @override
  Widget build(BuildContext context) {
    final nav = RewardNavigationLabels.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: FitOrHideTitle(nav['hub']),
          // 名前が全部入る幅では名前、入らない幅ではどのタブもアイコン（名前は
          // 長押し・ホバーの吹き出しと読み上げ）。名前の幅のまま横に並べて
          // スクロールしていた頃は、仏語・大きな文字で端のタブが画面の外へ
          // 切れた。
          bottom: FitOrIconTabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              FitOrIconTab(icon: Icons.flag_outlined, label: nav['missions']),
              FitOrIconTab(
                icon: Icons.smart_display_outlined,
                label: nav['earnTab'],
              ),
              FitOrIconTab(icon: Icons.redeem_outlined, label: nav['exchange']),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CreatorMissionsScreen(embedded: true, workId: workId),
            const RewardUnlockScreen(
              embedded: true,
              mode: RewardPageMode.earnCoins,
            ),
            const RewardUnlockScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
