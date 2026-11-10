import 'package:flutter/material.dart';

import '../../l10n/reward_navigation_labels.dart';
import 'reward_unlock_screen.dart';
import 'creator_missions_screen.dart';

/// Unifies redemption, missions and rewarded ads without mixing their state.
class CoinBenefitsScreen extends StatelessWidget {
  const CoinBenefitsScreen({super.key, this.initialTab = 0, this.workId});

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
            tabs: [
              Tab(text: nav['exchange']),
              Tab(text: nav['missions']),
              Tab(text: nav['earnTab']),
            ],
          ),
        ),
        body: TabBarView(children: [
          const RewardUnlockScreen(embedded: true),
          CreatorMissionsScreen(embedded: true, workId: workId),
          const RewardUnlockScreen(
            embedded: true,
            mode: RewardPageMode.earnCoins,
          ),
        ]),
      ),
    );
  }
}
