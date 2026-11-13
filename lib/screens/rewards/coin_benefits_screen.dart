import 'package:flutter/material.dart';

import '../../l10n/reward_navigation_labels.dart';
import 'reward_unlock_screen.dart';
import 'creator_missions_screen.dart';

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
          title: Text(nav['hub']),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: nav['missions']),
              Tab(text: nav['earnTab']),
              Tab(text: nav['exchange']),
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
