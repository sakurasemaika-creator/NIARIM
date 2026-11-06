import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/help/help_screen.dart';

/// A screen's help button opens Help on its own topic. The topic is an
/// internal Japanese key, so it is not put in the search box: the box stays
/// empty, ready to type in, and the topic's entry is shown on its own and
/// opened, in the display language. Typing searches everything again.
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
      expect(field.controller!.text, isEmpty);
      // The entry alone, opened.
      final tiles = tester.widgetList<ExpansionTile>(
        find.byType(ExpansionTile),
      );
      expect(tiles, hasLength(1));
      expect(tiles.single.initiallyExpanded, isTrue);
      expect(find.text(l10n.helpNewProjectTitle), findsOneWidget);
      expect(find.text(l10n.helpNewProjectDesc), findsOneWidget);
      // Typing searches all the entries again: another tool is found.
      await tester.enterText(find.byType(TextField), l10n.helpEraserToolTitle);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text(l10n.helpEraserToolTitle),
        ),
        findsWidgets,
      );
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
