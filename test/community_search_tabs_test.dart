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
    await tester.pumpWidget(app(initialTag: '手描き'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communitySearchModeToggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '夜明け');
    await tester.tap(find.byKey(const Key('communitySearchButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsWidgets);
    await tester.tap(find.byKey(const Key('communityContentFilterButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('communityTagExactMatch')));
    await tester.tap(find.byKey(const Key('communityTagExactMatch')));
    await tester.ensureVisible(
      find.byKey(const Key('communityContentFilterSaveButton')),
    );
    await tester.tap(find.byKey(const Key('communityContentFilterSaveButton')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkCard), findsNothing);
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
}
