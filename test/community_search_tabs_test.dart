import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';

void main() {
  Widget app({String? initialTag, Locale locale = const Locale('ja')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CommunityService()),
        ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CommunityScreen(initialTagFilter: initialTag),
      ),
    );
  }

  Future<void> selectSearch(WidgetTester tester) async {
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(3);
    await tester.pumpAndSettle();
  }

  testWidgets('タグチップ遷移ではタグ検索タブと検索語を自動選択する', (tester) async {
    await tester.pumpWidget(app(initialTag: '手描き'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('communitySearchModeToggle'));
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(of: toggle, matching: find.byIcon(Icons.search)),
      findsOneWidget,
      reason: 'Tag mode offers keyword search as next mode',
    );
    expect(find.byType(SegmentedButton<bool>), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '手描き');
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
    final exact = find.byKey(const Key('communitySearchExactMatch'));
    expect(tester.widget<CheckboxListTile>(exact).value, isTrue);
    expect(find.byKey(const Key('communityTagExactMatch')), findsNothing);
    await tester.tap(exact);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(exact).value, isFalse);
  });

  testWidgets('キーワード/タグ検索を切り替えると古い検索語を持ち越さない', (tester) async {
    await tester.pumpWidget(app(initialTag: '手描き'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('communitySearchModeToggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: toggle, matching: find.byIcon(Icons.sell_outlined)),
      findsOneWidget,
    );
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });
  testWidgets('space-delimited tags must all match by default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final works = buildDummyCommunityWorks();
    final expected = works
        .where(
          (work) => work.tags.contains('手描き') && work.tags.contains('オリジナル'),
        )
        .length;
    expect(expected, greaterThan(0));
    await tester.pumpWidget(app(initialTag: '手描き オリジナル'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsNWidgets(expected));
  });

  testWidgets('keyword search switches between partial and exact matches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await selectSearch(tester);
    await tester.enterText(find.byKey(const Key('communitySearchInput')), '夜明け');
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsWidgets);
    await tester.tap(find.byKey(const Key('communitySearchExactMatch')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsNothing);
  });


  testWidgets('keyword and tag searches respect tags, title and -exclusions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await selectSearch(tester);
    await tester.enterText(
      find.byKey(const Key('communitySearchInput')), '手描き -風景');
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    final keywordCards = tester.widgetList<CommunityWorkCard>(
      find.byType(CommunityWorkCard)).toList();
    expect(keywordCards, isNotEmpty);
    expect(keywordCards.every((card) {
      final w = card.work;
      final terms = [...w.tags, w.title].join(' ').toLowerCase();
      return terms.contains('手描き') && !terms.contains('風景');
    }), isTrue);
    await tester.tap(find.byKey(const Key('communitySearchModeToggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('communitySearchInput')), '手描き');
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    final tagCards = tester.widgetList<CommunityWorkCard>(
      find.byType(CommunityWorkCard)).toList();
    expect(tagCards, isNotEmpty);
    expect(tagCards.every((card) =>
        card.work.tags.any((tag) => tag.contains('手描き'))), isTrue);
  });

  testWidgets('long localized plaza tabs align to the leading edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in [
      const Locale('ja'),
      const Locale('en'),
      const Locale('fr'),
      const Locale('es'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(locale: locale));
      await tester.pumpAndSettle();
      final localizations = AppLocalizations.of(
        tester.element(find.byType(CommunityScreen)),
      )!;
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      if (bar.isScrollable) {
        expect(
          bar.tabAlignment,
          TabAlignment.start,
          reason: '$locale: scrolling tabs must start at the leading edge',
        );
      }
      final first = find.descendant(
        of: find.byType(TabBar),
        matching: find.text(localizations.communityTabNew),
      );
      final rect = tester.getRect(first);
      expect(
        rect.left,
        greaterThanOrEqualTo(0),
        reason: '$locale: first label must be on screen',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(320),
        reason: '$locale: first label must not get clipped',
      );
      final initialBottom = tester.getRect(find.byType(TabBar)).bottom;
      expect(find.byKey(const Key('communitySearchButton')), findsNothing);
      await selectSearch(tester);
      expect(find.byKey(const Key('communitySearchButton')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(
        find.byKey(const Key('communitySearchModeToggle')),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byType(TabBar)).bottom,
        lessThanOrEqualTo(initialBottom + 1),
        reason: '$locale: search must not add an entire mode-control row',
      );
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('search sort and tile-size controls align across languages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final width in [320.0, 390.0, 720.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(app(locale: locale));
        await tester.pumpAndSettle();
        await selectSearch(tester);
        final sorter = tester.getRect(
          find.byKey(const Key('communitySortButton')),
        );
        final size = tester.getRect(
          find.byKey(const Key('communityTileSizeButton')),
        );
        final search = tester.getRect(
          find.byKey(const Key('communitySearchButton')),
        );
        final scope = '${locale.toLanguageTag()} width $width';
        expect(size.left, greaterThanOrEqualTo(sorter.right - 1),
            reason: scope);
        expect(search.left, greaterThanOrEqualTo(size.right - 1),
            reason: scope);
        expect(search.right, lessThanOrEqualTo(width + 0.5), reason: scope);
        expect(search.width, inInclusiveRange(72, 132), reason: scope);
        expect(tester.takeException(), isNull, reason: scope);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
