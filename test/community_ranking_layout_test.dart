import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/l10n/community_ranking_layout_labels.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_ranking_work_list.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_header_quality_test.dart' as quality;
import 'helpers/load_app_fonts.dart';

CommunityWork sample(String id) => CommunityWork(
  id: id,
  title: '手描きアニメの作品タイトル / Animation illustration',
  authorId: 'artist',
  authorName: 'クリエイター / Artist',
  viewCount: 124567,
  likeCount: 42,
  bookmarkCount: 989,
  postedAt: DateTime.utc(2026, 10, 30),
  durationSeconds: 102,
  thumbnailColorIndex: 1,
);

void main() {
  testWidgets('ranking layouts keep ranks off thumbnail and controls usable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await loadAppFonts(tester);
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final width in [320.0, 390.0, 720.0]) {
        for (final layout in CommunityRankingLayout.values) {
          var bookmarkTaps = 0;
          var menuTaps = 0;
          var workTaps = 0;
          tester.view.physicalSize = Size(width, 880);
          await tester.pumpWidget(MaterialApp(
            locale: locale,
            theme: themes.themeData,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CommunityRankingWorkCard(
                    work: sample('rank'),
                    rank: 1,
                    layout: layout,
                    isBookmarked: false,
                    onTap: () => workTaps++,
                    onBookmarkToggle: () => bookmarkTaps++,
                    onAuthorTap: () {},
                    onVisibilityToggle: () => menuTaps++,
                  ),
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final scope = '${locale.toLanguageTag()} $width ${layout.name}';
          expect(tester.takeException(), isNull, reason: scope);
          expect(find.byKey(const ValueKey('communityRankMedal-1')),
              findsOneWidget, reason: scope);
          final thumb = tester.getRect(
            find.byKey(const ValueKey('ranking-duration-rank')),
          );
          expect(thumb.height, greaterThan(0), reason: scope);
          final bookmark = find.byKey(const ValueKey('community-bookmark-rank'));
          final menu = find.byKey(const ValueKey('communityRankingMenu-rank'));
          expect(bookmark, findsOneWidget, reason: scope);
          expect(menu, findsOneWidget, reason: scope);
          await tester.tap(bookmark);
          await tester.pump();
          expect(bookmarkTaps, 1, reason: scope);
          expect(workTaps, 0, reason: scope);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          expect(find.text(
              CommunityRankingLayoutLabels.of(tester.element(menu)).title),
              findsNothing, reason: scope);
          final popup = find.byType(PopupMenuItem<String>);
          expect(popup, findsOneWidget, reason: scope);
          await tester.tap(popup);
          await tester.pumpAndSettle();
          expect(menuTaps, 1, reason: scope);
          expect(workTaps, 0, reason: scope);
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fourth place is a bare number, never an overlay medal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (var rank = 1; rank <= 4; rank++)
              CommunityRankBadge(rank: rank),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    for (final rank in [1, 2, 3]) {
      expect(find.byKey(ValueKey('communityRankMedal-$rank')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('communityRankNumber-4')), findsOneWidget);
    final second = tester.widget<Container>(
      find.byKey(const ValueKey('communityRankMedal-2')),
    );
    final third = tester.widget<Container>(
      find.byKey(const ValueKey('communityRankMedal-3')),
    );
    final first = tester.widget<Container>(
      find.byKey(const ValueKey('communityRankMedal-1')),
    );
    expect((second.decoration as BoxDecoration).color,
        (third.decoration as BoxDecoration).color);
    expect((first.decoration as BoxDecoration).color,
        isNot((second.decoration as BoxDecoration).color));
    expect(find.byKey(const ValueKey('communityRankMedal-4')), findsNothing);
  });

  testWidgets('ranking mode switch is exclusive to ranking and remembered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final themes = ThemeService();
    await themes.init();
    final community = CommunityService();
    final preview = CommunityPreviewService();
    addTearDown(themes.dispose);
    addTearDown(community.dispose);
    addTearDown(preview.dispose);
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: quality.host(
        themes, community, preview,
        locale: const Locale('ja'), scale: 1,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityTileSizeButton')), findsOneWidget);
    expect(find.byKey(const Key('communityRankingLayoutButton')), findsNothing);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    final chooser = find.byKey(const Key('communityRankingLayoutButton'));
    expect(chooser, findsOneWidget);
    expect(find.byKey(const Key('communityTileSizeButton')), findsNothing);
    expect(find.byKey(const Key('communityRankingHorizontalCard')),
        findsWidgets);

    final captureDir = Platform.environment['NIARIM_FIVE_FIXES_CAPTURE'];
    Future<void> capture(String name) async {
      if (captureDir == null) return;
      await tester.runAsync(() async {
        final boundary =
            root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        Directory(captureDir).createSync(recursive: true);
        File('${captureDir}/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await capture('21_ranking_horizontal');
    await tester.tap(chooser);
    await tester.pumpAndSettle();
    final words = CommunityRankingLayoutLabels.of(tester.element(chooser));
    await tester.tap(find.text(words.largeThumbnail).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityRankingLargeThumbnailCard')),
        findsWidgets);
    expect(find.byKey(const Key('communityRankingHorizontalCard')),
        findsNothing);
    await capture('22_ranking_large_thumbnail');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('community.rankingLayout.v1'), 'largeThumbnail');
    await tester.tap(find.byType(Tab).at(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityTileSizeButton')), findsOneWidget);
    expect(find.byKey(const Key('communityRankingLayoutButton')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
