import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/help/help_screen.dart';

/// A screen's help button opens Help on its own topic. The topic is an
/// internal Japanese key; what the search box shows is the topic's title in
/// the display language, and the topic is still the one found and opened.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the search box shows the topic in $locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HelpScreen(initialTopic: '新規プロジェクト作成'),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, l10n.helpNewProjectTitle);
      // The entry is listed and opened.
      final tile = tester.widget<ExpansionTile>(
        find.ancestor(
          of: find.text(l10n.helpNewProjectTitle).last,
          matching: find.byType(ExpansionTile),
        ),
      );
      expect(tile.initiallyExpanded, isTrue);
      expect(find.text(l10n.helpNewProjectDesc), findsOneWidget);
    });
  }

  testWidgets('an unknown topic is searched as it is', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HelpScreen(initialTopic: 'brush'),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'brush');
  });
}
