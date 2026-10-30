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

  testWidgets('plaza cards align small menu and bookmark in one right rail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final card = tester.widget<CommunityWorkCard>(
      find.byType(CommunityWorkCard).first,
    );
    final menu = find.byKey(ValueKey('communityMuteMenu-${card.work.id}'));
    final bookmark = find.byKey(ValueKey('community-bookmark-${card.work.id}'));
    expect(menu, findsOneWidget);
    expect(bookmark, findsOneWidget);
    final menuRect = tester.getRect(menu);
    final bookmarkRect = tester.getRect(bookmark);
    expect((menuRect.center.dx - bookmarkRect.center.dx).abs(), lessThan(3));
    expect(bookmarkRect.top, greaterThanOrEqualTo(menuRect.bottom - 1));
    expect(tester.widget<IconButton>(bookmark).iconSize, 22);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal ranking thumbnails stretch to tile height', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(1);
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('communityRankingHorizontalCard')).first;
    final thumb = find
        .byKey(const Key('communityRankingHorizontalThumbnail'))
        .first;
    expect(
      tester.getSize(thumb).height,
      closeTo(tester.getSize(tile).height, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('タグチップ遷移ではタグ検索タブと検索語を自動選択する', (tester) async {
    await tester.pumpWidget(app(initialTag: '手描き'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('communitySearchModeToggle'));
    expect(toggle, findsOneWidget);
    expect(
      find.byKey(const Key('communitySearchModePill')),
      findsOneWidget,
      reason: 'Tag mode is selectable immediately beside Search',
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
    expect(find.byKey(const Key('communitySearchModePill')), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });
  testWidgets('space-delimited tags must all match by default', (tester) async {
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
    await tester.enterText(
      find.byKey(const Key('communitySearchInput')),
      '夜明け',
    );
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsWidgets);
    await tester.tap(find.byKey(const Key('communitySearchExactMatch')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsNothing);
  });

  testWidgets('keyword and tag searches respect tags, title and -exclusions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await selectSearch(tester);
    await tester.enterText(
      find.byKey(const Key('communitySearchInput')),
      '手描き -風景',
    );
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    final keywordCards = tester
        .widgetList<CommunityWorkCard>(find.byType(CommunityWorkCard))
        .toList();
    expect(keywordCards, isNotEmpty);
    expect(
      keywordCards.every((card) {
        final w = card.work;
        final terms = [...w.tags, w.title].join(' ').toLowerCase();
        return terms.contains('手描き') && !terms.contains('風景');
      }),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('communitySearchModeToggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('communitySearchInput')),
      '手描き',
    );
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    final tagCards = tester
        .widgetList<CommunityWorkCard>(find.byType(CommunityWorkCard))
        .toList();
    expect(tagCards, isNotEmpty);
    expect(
      tagCards.every(
        (card) => card.work.tags.any((tag) => tag.contains('手描き')),
      ),
      isTrue,
    );
  });

  testWidgets('plaza tabs use project-list-style proportional widths', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [320.0, 390.0, 720.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final locale in [const Locale('ja'), const Locale('en')]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app(locale: locale));
        await tester.pumpAndSettle();

        final barFinder = find.byType(TabBar);
        final bar = tester.widget<TabBar>(barFinder);
        expect(bar.isScrollable, isTrue);
        expect(bar.tabAlignment, TabAlignment.start);
        expect(bar.labelPadding, EdgeInsets.zero);

        final context = tester.element(barFinder);
        final theme = Theme.of(context);
        final textStyle =
            theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall!;
        final labels = <String>[];
        final actualWidths = <double>[];
        for (var i = 0; i < 4; i++) {
          final tab = find.byKey(Key('communityTabWidth$i'));
          labels.add(
            tester
                .widget<Text>(
                  find.descendant(of: tab, matching: find.byType(Text)),
                )
                .data!,
          );
          actualWidths.add(tester.getSize(tab).width);
        }
        final naturalWidths = <double>[];
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: textStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.localeOf(context),
            maxLines: 1,
          )..layout();
          naturalWidths.add(painter.width + 32);
          painter.dispose();
        }
        final totalNatural = naturalWidths.reduce((a, b) => a + b);
        final available = tester.getSize(barFinder).width;
        final scrollTabs = totalNatural > available;
        for (var i = 0; i < labels.length; i++) {
          final expected = scrollTabs
              ? naturalWidths[i]
              : available * naturalWidths[i] / totalNatural;
          expect(
            actualWidths[i],
            closeTo(expected, 0.5),
            reason: '$locale at width $width, tab $i',
          );
        }
        if (!scrollTabs) {
          expect(actualWidths.reduce((a, b) => a + b), closeTo(available, 0.5));
        }
        expect(tester.takeException(), isNull);
      }
    }
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
        final mode = tester.getRect(
          find.byKey(const Key('communitySearchModePill')),
        );
        final scope = '${locale.toLanguageTag()} width $width';
        expect(mode.right, lessThanOrEqualTo(search.left), reason: scope);
        expect(mode.left, greaterThanOrEqualTo(size.right - 1), reason: scope);
        expect(
          size.left,
          greaterThanOrEqualTo(sorter.right - 1),
          reason: scope,
        );
        expect(
          search.left,
          greaterThanOrEqualTo(size.right - 1),
          reason: scope,
        );
        expect(search.right, lessThanOrEqualTo(width + 0.5), reason: scope);
        expect(search.width, inInclusiveRange(72, 132), reason: scope);
        expect(tester.takeException(), isNull, reason: scope);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'four tabs isolate Search and prevent ranking filter/reordering',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabs.length, 4);
      // New arrivals retain content filter, but never render search controls.
      expect(
        find.byKey(const Key('communityContentFilterButton')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('communitySearchInput')), findsNothing);
      expect(
        find.byKey(const Key('communitySavedSearchAccordion')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('communitySearchHistoryAccordion')),
        findsNothing,
      );

      bar.controller!.animateTo(1);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('communityContentFilterButton')),
        findsNothing,
      );
      expect(find.byKey(const Key('communitySearchInput')), findsNothing);
      expect(find.byKey(const Key('communitySearchRow')), findsNothing);
      final rankingBefore = tester
          .widgetList(find.byKey(const Key('communityRankingHorizontalCard')))
          .length;
      expect(rankingBefore, greaterThan(0));

      bar.controller!.animateTo(3);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('communitySearchInput')), findsOneWidget);
      expect(
        find.byKey(const Key('communitySavedSearchAccordion')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('communitySearchHistoryAccordion')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('communitySearchExactMatch')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('communitySearchInput')),
        '検索では見つからない文字列',
      );
      await tester.tap(find.byKey(const Key('communitySearchButton')));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityWorkCard), findsNothing);

      bar.controller!.animateTo(1);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('communityRankingHorizontalCard')),
        findsNWidgets(rankingBefore),
        reason: 'Search queries must never renumber the ranking',
      );
      bar.controller!.animateTo(2);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('communityContentFilterButton')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('communitySearchInput')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
