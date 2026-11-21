import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/help/help_screen.dart';
import 'package:niarim/screens/help/guide_hub_screen.dart';
import 'package:niarim/screens/tips/tips_screen.dart';

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
      final first = tester
          .widgetList<ExpansionTile>(find.byType(ExpansionTile))
          .first;
      expect((first.title as Text).data, l10n.helpEraserToolTitle);
      expect(
        find.descendant(
          of: find.byWidget(first),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );
      final list = tester.widget<ListView>(find.byType(ListView));
      final count = list.childrenDelegate.estimatedChildCount! - 1;
      expect(find.text(l10n.helpSearchResultCount(count)), findsOneWidget);
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

  testWidgets(
    'a named tool comes before mentions and its explanation frees the keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
      await tester.enterText(field, l10n.helpPressureCurveTitle);
      await tester.pumpAndSettle();
      final first = tester
          .widgetList<ExpansionTile>(find.byType(ExpansionTile))
          .first;
      expect((first.title as Text).data, l10n.helpPressureCurveTitle);
      final status = find.text(l10n.helpSearchResultCount(3));
      expect(status.hitTestable(), findsOneWidget);
      expect(
        find.ancestor(
          of: status,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(ExpansionTile, l10n.helpPressureCurveTitle),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.helpPressureCurveDesc), findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      await tester.tap(field);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(find.byKey(const Key('helpTutorialButton')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching between Tips and Help preserves the query and open topic in each tab',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GuideHubScreen(),
        ),
      );
      final words = AppLocalizations.of(
        tester.element(find.byType(GuideHubScreen)),
      )!;
      final helpSearch = find.descendant(
        of: find.byType(HelpScreen),
        matching: find.byType(TextField),
      );
      final tipsSearch = find.descendant(
        of: find.byType(TipsScreen),
        matching: find.byType(TextField),
      );
      final tipsTab = find.widgetWithText(Tab, words.tipsScreenTitle);
      final helpTab = find.widgetWithText(Tab, words.helpScreenTitle);
      await tester.enterText(helpSearch, words.helpPressureCurveTitle);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ExpansionTile, words.helpPressureCurveTitle),
      );
      await tester.pumpAndSettle();
      await tester.tap(tipsTab);
      await tester.pumpAndSettle();
      await tester.enterText(tipsSearch, 'レイヤー');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(helpTab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(helpSearch).controller!.text,
        words.helpPressureCurveTitle,
      );
      expect(find.text(words.helpPressureCurveDesc), findsOneWidget);
      await tester.tap(tipsTab);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(tipsSearch).controller!.text, 'レイヤー');
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
