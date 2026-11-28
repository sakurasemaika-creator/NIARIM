import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_header_quality_test.dart' as quality;

/// 作品広場の表示フィルター：「保存」した絞り込みは作品広場を出て戻っても・
/// 起動し直しても残り、絞り込みで一覧が空になったときはその場で外せる
/// （利用者の動きで見つかったこと：保存しても出入りで消え、0件のときに
/// 外す道が無かった）。
void main() {
  const key = 'community.displayFilters.v1';

  Future<void> pumpPlaza(
    WidgetTester tester,
    ThemeService themes,
    CommunityService community,
    CommunityPreviewService preview,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      quality.host(
        themes,
        community,
        preview,
        locale: const Locale('ja'),
        scale: 1,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder badge(WidgetTester tester) =>
      find.byKey(const Key('communityContentFilterActive'));

  testWidgets('saved display filters survive leaving and restarting, '
      'and an empty result offers to clear them', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final themes = ThemeService();
    await themes.init();
    final preview = CommunityPreviewService();
    final community = CommunityService();
    addTearDown(themes.dispose);
    addTearDown(preview.dispose);
    addTearDown(community.dispose);
    await tester.runAsync(() => community.contentFiltersReady);

    await pumpPlaza(tester, themes, community, preview);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityScreen)),
    )!;
    expect(find.byType(CommunityWorkCard), findsWidgets);
    expect(tester.widget<Badge>(badge(tester)).isLabelVisible, isFalse);
    expect(find.byKey(const Key('communityClearFilters')), findsNothing);

    // ブックマーク数1,000,000以上（見本の作品はどれも満たさない）で保存する。
    await tester.tap(find.byKey(const Key('communityContentFilterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityMinimumBookmarks')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(l10n.communityMinimumBookmarksOption('1,000,000')).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
    await tester.pumpAndSettle();

    void expectFilteredEmpty() {
      expect(find.byType(CommunityWorkCard), findsNothing);
      expect(tester.widget<Badge>(badge(tester)).isLabelVisible, isTrue);
      expect(find.text(l10n.communityFilterNoResults), findsOneWidget);
      expect(find.text(l10n.communityEmptyState), findsNothing);
      expect(
        find.byKey(const Key('communityClearFilters')).hitTestable(),
        findsOneWidget,
      );
    }

    expectFilteredEmpty();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), contains('"minimumBookmarks":1000000'));

    // 作品広場を出て、また開く。
    await pumpPlaza(tester, themes, community, preview);
    expectFilteredEmpty();

    // 起動し直す（保存から読む新しいサービス）。
    final restarted = CommunityService();
    addTearDown(restarted.dispose);
    await tester.runAsync(() => restarted.contentFiltersReady);
    await pumpPlaza(tester, themes, restarted, preview);
    expectFilteredEmpty();

    // 空の表示から絞り込みを外すと作品が戻り、覚えも消える。
    await tester.tap(find.byKey(const Key('communityClearFilters')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(find.byType(CommunityWorkCard), findsWidgets);
    expect(tester.widget<Badge>(badge(tester)).isLabelVisible, isFalse);
    expect(find.byKey(const Key('communityClearFilters')), findsNothing);
    expect(prefs.containsKey(key), isFalse);

    await pumpPlaza(tester, themes, restarted, preview);
    expect(find.byType(CommunityWorkCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unreadable saved filter opens the plaza unfiltered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({key: '{not json'});
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final themes = ThemeService();
    await themes.init();
    final preview = CommunityPreviewService();
    final community = CommunityService();
    addTearDown(themes.dispose);
    addTearDown(preview.dispose);
    addTearDown(community.dispose);
    await tester.runAsync(() => community.contentFiltersReady);
    expect(community.displayFilters, isEmpty);
    await pumpPlaza(tester, themes, community, preview);
    expect(find.byType(CommunityWorkCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
