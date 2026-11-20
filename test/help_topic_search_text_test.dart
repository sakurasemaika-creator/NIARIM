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

  testWidgets(
    'multiple keywords search across fields and clear returns focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HelpScreen(),
        ),
      );
      final field = find.byType(TextField);
      final l10n = AppLocalizations.of(tester.element(field))!;
      final tutorial = find.byKey(const Key('helpTutorialButton'));
      final eraser = find.text(l10n.helpEraserToolTitle);
      for (final query in ['消しゴム　ツール', '  ﾂｰﾙ   消しゴム  ']) {
        await tester.enterText(field, query);
        await tester.pumpAndSettle();
        expect(eraser, findsOneWidget);
      }
      await tester.enterText(field, '消しゴム missing-zzzz');
      await tester.pumpAndSettle();
      expect(find.text(l10n.helpNoResults), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.projectListClearSearch));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tutorial, findsOneWidget);
      await tester.enterText(field, '　 ');
      await tester.pumpAndSettle();
      expect(tutorial, findsOneWidget);
    },
  );

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
