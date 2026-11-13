import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tips/tips_screen.dart';
import 'help_screen.dart';

/// A common shell for the help and tips deep links.
/// 引き出しの項目と、この画面の題名。
///
/// 使い方の最後のページの案内（`tutorialPage6Step3`）と図もこの名前を
/// 出すので、ARBの1つの文言を使う。手書きの言語別の表にすると、言語に
/// よって案内と食い違い、同梱フォントの字の確かめからも外れる。
String guideHubTitle(BuildContext context) =>
    AppLocalizations.of(context)!.homeDrawerTutorial;

class GuideHubScreen extends StatelessWidget {
  const GuideHubScreen({super.key, this.initialTab = 1, this.initialTopic});

  final int initialTab;
  final String? initialTopic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(guideHubTitle(context)),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tipsScreenTitle),
              Tab(text: l10n.helpScreenTitle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const TipsScreen(embedded: true),
            HelpScreen(embedded: true, initialTopic: initialTopic),
          ],
        ),
      ),
    );
  }
}
