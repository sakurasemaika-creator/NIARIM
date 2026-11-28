import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_list_controls.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/collection_tile_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_header_quality_test.dart' as quality;

/// 作品広場の「ブックマーク」タブの表示サイズのボタンは1つだけ（利用者の
/// 動きで見つかったこと：上部バーと一覧の上に2つあり、片方は「詳細」、
/// もう片方は「小」に印が付いて食い違っていた）。選んだ大きさはほかの
/// タブと同じく覚える。
void main() {
  testWidgets('the bookmarks tab has one view button shared with the plaza', (
    tester,
  ) async {
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
    await tester.runAsync(() async {
      await community.contentFiltersReady;
      await community.toggleBookmark(community.discoverableWorks.first.id);
    });
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
    expect(find.byType(CommunityWorkViewButton), findsOneWidget);

    await tester.tap(find.byType(Tab).at(4));
    await tester.pumpAndSettle();
    final button = find.byType(CommunityWorkViewButton);
    expect(button, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CommunityWorkViewButton),
      ),
      findsNothing,
    );

    final l10n = AppLocalizations.of(tester.element(button))!;
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.homeViewModeLarge).last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CommunityWorkViewButton>(button).size,
      CollectionViewSize.large,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('community.tileSize.v2'), 'large');

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.homeViewModeDetail).last);
    await tester.pumpAndSettle();
    expect(tester.widget<CommunityWorkViewButton>(button).detail, isTrue);

    // 新着のタブも同じ表示（同じボタンの状態）。
    await tester.tap(find.byType(Tab).at(0));
    await tester.pumpAndSettle();
    final plazaButton = find.byKey(const Key('communityTileSizeButton'));
    expect(plazaButton, findsOneWidget);
    final plaza = tester.widget<CommunityWorkViewButton>(plazaButton);
    expect(plaza.size, CollectionViewSize.large);
    expect(plaza.detail, isTrue);
    expect(find.byType(CommunityScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
