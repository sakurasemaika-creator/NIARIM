import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_ranking_work_list.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture real community list and ranking controls in Japanese', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    final community = CommunityService();
    await community.contentFiltersReady;
    addTearDown(community.dispose);

    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final work = CommunityWork(
      id: 'sample',
      title: 'アニメーション作品・サムネイル表示確認',
      authorId: 'artist',
      authorName: 'アニメ作者',
      viewCount: 1250,
      likeCount: 42,
      bookmarkCount: 18,
      postedAt: DateTime.utc(2026, 11, 10),
      durationSeconds: 120,
      thumbnailColorIndex: 1,
    );

    final boundaryKey = GlobalKey();
    Future<void> render(Widget child) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: theme.themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangeNotifierProvider<CommunityService>.value(
              value: community,
              child: Scaffold(
                appBar: AppBar(title: const Text('作品広場')),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final imageBytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final directory = Directory('build/community-action-captures')
        ..createSync(recursive: true);
      await tester.runAsync(
        () => File('${directory.path}/$name.png').writeAsBytes(imageBytes!),
      );
    }

    for (final bookmarked in [false, true]) {
      await render(
        CommunityWorkGrid(
          works: [work],
          bookmarkedIds: bookmarked ? const {'sample'} : const {},
          onTapWork: (_) {},
          onToggleBookmark: (_) {},
          onTapAuthor: (_) {},
        ),
      );
      final bookmark = find.byKey(const ValueKey('community-bookmark-sample'));
      final menu = find.byKey(const ValueKey('communityMuteMenu-sample'));
      expect(bookmark, findsOneWidget);
      expect(menu, findsOneWidget);
      expect(
        tester.widget<IconButton>(bookmark).iconSize,
        CollectionActionFrame.glyphSize,
      );
      expect(tester.getRect(bookmark).width, CollectionActionFrame.extent);
      expect(tester.getRect(menu).width, CollectionActionFrame.extent);
      await capture(
        bookmarked
            ? 'community_work_bookmarked'
            : 'community_work_unbookmarked',
      );
    }

    for (final layout in CommunityRankingLayout.values) {
      await render(
        CommunityRankingWorkCard(
          work: work,
          rank: 1,
          layout: layout,
          isBookmarked: false,
          onTap: () {},
          onBookmarkToggle: () {},
          onAuthorTap: () {},
          onVisibilityToggle: () {},
        ),
      );
      final bookmark = find.byKey(const ValueKey('community-bookmark-sample'));
      final menu = find.byKey(const ValueKey('communityRankingMenu-sample'));
      expect(bookmark, findsOneWidget);
      expect(menu, findsOneWidget);
      expect(
        tester.widget<IconButton>(bookmark).iconSize,
        CollectionActionFrame.glyphSize,
      );
      await capture('community_ranking_${layout.name}');
    }
  });
}
