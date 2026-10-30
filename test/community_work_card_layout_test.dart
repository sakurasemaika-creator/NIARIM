import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets(
    'narrow work cards keep scaled text and independent actions reachable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        for (final locale in AppLocalizations.supportedLocales) {
          for (final variant in [
            'plain',
            'private',
            'short',
            'rank',
            'repost',
            'short-rank-repost',
          ]) {
            for (final width in [
              320,
              353,
              354,
              355,
              375,
              449,
              450,
              451,
              560,
              641,
              673,
              674,
              675,
              1440,
            ]) {
              for (final scale in [2.0, 1.0, 1.3]) {
                var cardTaps = 0, bookmarks = 0, authors = 0;
                final work = CommunityWork(
                  id: 'fixture',
                  title: 'A long audit title with 日本語 and français',
                  authorId: 'creator',
                  authorName: 'Audit creator name',
                  viewCount: 1234567,
                  likeCount: 0,
                  bookmarkCount: 99999,
                  postedAt: DateTime.utc(2026, 10, 22),
                  durationSeconds: 12345,
                  thumbnailColorIndex: 0,
                  isShort: variant.contains('short'),
                  isNiarimPublished: variant != 'private',
                );
                tester.view.physicalSize = Size(width.toDouble(), 900);
                await tester.pumpWidget(
                  MaterialApp(
                    theme: theme.themeData,
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: SingleChildScrollView(
                        child: CommunityWorkGrid(
                          works: [work],
                          bookmarkedIds: const {'fixture'},
                          rankNumbers: variant.contains('rank')
                              ? const {'fixture': 123}
                              : null,
                          repostedByNames: variant.contains('repost')
                              ? const {'fixture': 'A very long reposter name'}
                              : null,
                          onTapWork: (_) => cardTaps++,
                          onToggleBookmark: (_) => bookmarks++,
                          onTapAuthor: (_) => authors++,
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final scope =
                    '${locale.toLanguageTag()} $variant $width scale$scale';
                expect(tester.takeException(), isNull, reason: scope);
                if (variant == 'private') {
                  expect(find.byType(IconButton), findsNothing, reason: scope);
                  expect(
                    find.textContaining('deleted', findRichText: true),
                    findsNothing,
                    reason: 'Unavailable placeholders are locale-aware',
                  );
                  continue;
                }
                final bookmark = find.byKey(const ValueKey('community-bookmark-fixture'));
                await tester.ensureVisible(bookmark);
                await tester.pump();
                expect(bookmark.hitTestable(), findsOneWidget, reason: scope);
                expect(
                  tester.getSize(bookmark).width,
                  greaterThanOrEqualTo(48),
                  reason: scope,
                );
                expect(
                  tester.getSize(bookmark).height,
                  greaterThanOrEqualTo(48),
                  reason: scope,
                );
                expect(
                  tester.widget<IconButton>(bookmark).iconSize,
                  48,
                  reason: scope,
                );
                final tile = tester.getRect(find.byType(Card));
                final buttonRect = tester.getRect(bookmark);
                expect(tile.right - buttonRect.right,
                    lessThanOrEqualTo(10), reason: scope);
                final l10n = AppLocalizations.of(
                  tester.element(find.byType(CommunityWorkGrid)),
                )!;
                expect(
                  tester.getSemantics(bookmark).label,
                  contains(l10n.communityWorkDetailBookmarkRemove),
                  reason: scope,
                );
                final authorTarget = find.byKey(
                  const ValueKey('community-author-fixture'),
                );
                expect(
                  tester.getSize(authorTarget).height,
                  greaterThanOrEqualTo(48),
                  reason: scope,
                );
                await tester.tap(bookmark);
                await tester.pump();
                expect(bookmarks, 1, reason: scope);
                expect(cardTaps, 0, reason: scope);
                final creator = find.text(work.authorName);
                await tester.ensureVisible(creator);
                await tester.tap(creator);
                await tester.pump();
                expect(authors, 1, reason: scope);
                expect(cardTaps, 0, reason: scope);
                final title = find.text(work.title);
                await tester.ensureVisible(title);
                await tester.tap(title);
                await tester.pump();
                expect(cardTaps, 1, reason: scope);
              }
            }
          }
        }
      } finally {
        semantics.dispose();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets('thumbnail uses the right-side menu and a bookmark by counts',
      (tester) async {
    final work = CommunityWork(
      id: 'layout-sample',
      title: 'A sample',
      authorId: 'author',
      authorName: 'Artist',
      viewCount: 1234,
      likeCount: 0,
      bookmarkCount: 55,
      postedAt: DateTime.utc(2026, 10, 29),
      durationSeconds: 90,
      thumbnailColorIndex: 2,
    );
    var marks = 0;
    var hidden = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            child: CommunityWorkCard(
              work: work,
              isBookmarked: false,
              onTap: () {},
              onBookmarkToggle: () => marks++,
              onMuteToggle: () => hidden++,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('communityMuteMenu-layout-sample'));
    final bookmark = find.byKey(const ValueKey('community-bookmark-layout-sample'));
    expect(menu, findsOneWidget);
    expect(bookmark, findsOneWidget);
    final thumbnail = tester.getRect(find.byType(AspectRatio));
    expect(tester.getRect(menu).top,
        greaterThanOrEqualTo(thumbnail.bottom));
    expect(tester.getRect(bookmark).top,
        greaterThanOrEqualTo(thumbnail.bottom));
    expect(tester.getRect(menu).left,
        greaterThanOrEqualTo(tester.getRect(bookmark).right - 1),
        reason: 'Menu moves immediately to the bookmark right side');
    // 48dp is twice IconButton's previous default 24dp icon.
    final action = tester.widget<IconButton>(bookmark);
    expect(action.iconSize, 48);
    expect(tester.getSize(bookmark), const Size(56, 56));
    final card = tester.getRect(find.byType(Card));
    expect(card.right - tester.getRect(bookmark).right, lessThanOrEqualTo(10));
    expect(tester.getRect(bookmark).center.dx, greaterThan(card.center.dx));
    expect(
      find.descendant(
        of: find.byType(AspectRatio),
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsNothing,
      reason: 'The central play symbol must not cover the artwork',
    );
    await tester.tap(bookmark);
    await tester.pump();
    expect(marks, 1);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('この作品を非表示にする'));
    await tester.pumpAndSettle();
    expect(hidden, 1);
    expect(tester.takeException(), isNull);
  });
}
