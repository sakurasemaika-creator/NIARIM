import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tips/tips_screen.dart';
import 'help_screen.dart';

/// A common shell for the help and tips deep links.
String guideHubTitle(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return switch (locale.languageCode) {
    'ja' => '使い方',
    'es' => 'Cómo se usa',
    'fr' => 'Mode d’emploi',
    'ko' => '사용 방법',
    'zh' => '使用指南',
    _ => 'How to use',
  };
}

class GuideHubScreen extends StatelessWidget {
  const GuideHubScreen({super.key, this.initialTab = 0, this.initialTopic});

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
          bottom: TabBar(tabs: [
            Tab(text: l10n.helpScreenTitle),
            Tab(text: l10n.tipsScreenTitle),
          ]),
        ),
        body: TabBarView(children: [
          HelpScreen(embedded: true, initialTopic: initialTopic),
          const TipsScreen(embedded: true),
        ]),
      ),
    );
  }
}
