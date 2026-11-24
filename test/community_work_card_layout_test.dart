import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/l10n/community_plaza_labels.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

void main() {
  titleLineStartTests();
  testWidgets(
    'narrow work cards keep scaled text and independent actions reachable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final theme = ThemeService();
      await theme.init();
      addTearDown(theme.dispose);
      final community = CommunityService();
      await community.contentFiltersReady;
      addTearDown(community.dispose);
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
                    home: ChangeNotifierProvider<CommunityService>.value(
                      value: community,
                      child: Scaffold(
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
                  ),
                );
                await tester.pumpAndSettle();
                final scope =
                    '${locale.toLanguageTag()} $variant $width scale$scale';
                expect(tester.takeException(), isNull, reason: scope);
                if (variant == 'private') {
                  expect(find.byType(IconButton), findsNothing, reason: scope);
                  expect(
                    find.text(
                      CommunityPlazaLabels.of(
                        tester.element(find.byType(CommunityWorkGrid)),
                      ).unavailablePlaceholder,
                    ),
                    findsOneWidget,
                    reason: 'Unavailable placeholders are locale-aware',
                  );
                  expect(find.text(work.title), findsNothing, reason: scope);
                  continue;
                }
                final bookmark = find.byKey(
                  const ValueKey('community-bookmark-fixture'),
                );
                await tester.ensureVisible(bookmark);
                await tester.pump();
                expect(bookmark.hitTestable(), findsOneWidget, reason: scope);
                expect(
                  tester.getSize(bookmark).width,
                  greaterThanOrEqualTo(40),
                  reason: scope,
                );
                expect(
                  tester.getSize(bookmark).height,
                  greaterThanOrEqualTo(40),
                  reason: scope,
                );
                expect(
                  tester.widget<IconButton>(bookmark).iconSize,
                  16,
                  reason: scope,
                );
                final tile = tester.getRect(find.byType(Card));
                final buttonRect = tester.getRect(bookmark);
                final menu = find.byKey(
                  const ValueKey('communityMuteMenu-fixture'),
                );
                expect(menu, findsOneWidget, reason: scope);
                final menuRect = tester.getRect(menu);
                final orientationText = find.byKey(
                  const ValueKey('community-orientation-fixture'),
                );
                final orientationIcon = find.byKey(
                  const ValueKey('community-orientation-icon-fixture'),
                );
                // 名前が入る幅では縮めない名前、入らない幅では縦横の印。
                final textShown = orientationText.evaluate().isNotEmpty;
                expect(
                  textShown || orientationIcon.evaluate().isNotEmpty,
                  isTrue,
                  reason: '$scope orientation must show a label or its mark',
                );
                final orientation = textShown
                    ? orientationText
                    : orientationIcon;
                final orientationRect = tester.getRect(orientation);
                expect(
                  orientationRect.right,
                  lessThanOrEqualTo(buttonRect.left + 1),
                  reason: '$scope orientation must precede the actions',
                );
                expect(
                  orientationRect.height,
                  lessThanOrEqualTo(49),
                  reason: '$scope orientation must fit in the action row',
                );
                if (textShown) {
                  final paragraph = tester.renderObject<RenderParagraph>(
                    orientation,
                  );
                  expect(
                    paragraph.didExceedMaxLines,
                    isFalse,
                    reason: '$scope orientation must show the full label',
                  );
                  // 字を縮めて押し込まない（描いた幅が字の本来の幅のまま）。
                  expect(
                    orientationRect.width,
                    greaterThanOrEqualTo(
                      paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
                    ),
                    reason: '$scope orientation label must not be shrunk',
                  );
                }
                // ︙はカードの右端に寄せる。押せる所（丸の外へ6px）がカードの
                // 中に収まる分だけ離す（DISC240：カードの余白4px＋右の余白
                // 6px＋ボタンと丸の差4px）。
                expect(
                  tile.right - menuRect.right,
                  lessThanOrEqualTo(14),
                  reason: scope,
                );
                expect(
                  buttonRect.right,
                  lessThanOrEqualTo(menuRect.left + 1),
                  reason: '$scope bookmark must precede context menu',
                );
                expect(
                  (buttonRect.center.dy - menuRect.center.dy).abs(),
                  lessThan(3),
                  reason: '$scope actions must share the bottom row',
                );
                final titleRect = tester.getRect(find.text(work.title));
                final authorRect = tester.getRect(find.text(work.authorName));
                expect(
                  titleRect.bottom,
                  lessThanOrEqualTo(authorRect.top + 1),
                  reason: '$scope title must be above author',
                );
                expect(
                  authorRect.bottom,
                  lessThanOrEqualTo(buttonRect.top + 1),
                  reason: '$scope author must be above actions',
                );
                final l10n = AppLocalizations.of(
                  tester.element(find.byType(CommunityWorkGrid)),
                )!;
                final bookmarkSemantics = find.ancestor(
                  of: bookmark,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.toggled == true &&
                        widget.properties.label ==
                            l10n.communityWorkDetailBookmarkRemove,
                  ),
                );
                expect(bookmarkSemantics, findsOneWidget, reason: scope);
                expect(
                  tester.getSemantics(bookmarkSemantics).label,
                  contains(l10n.communityWorkDetailBookmarkRemove),
                  reason: scope,
                );
                final authorTarget = find.byKey(
                  const ValueKey('community-author-fixture'),
                );
                expect(
                  tester.getSize(authorTarget).height,
                  greaterThanOrEqualTo(40),
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

  testWidgets(
    'card shows title, author, counts, and independent bookmark/menu controls',
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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
      await tester.pumpAndSettle();
      final menu = find.byKey(
        const ValueKey('communityMuteMenu-layout-sample'),
      );
      final bookmark = find.byKey(
        const ValueKey('community-bookmark-layout-sample'),
      );
      expect(menu, findsOneWidget);
      expect(bookmark, findsOneWidget);
      final thumbnail = tester.getRect(find.byType(AspectRatio));
      expect(tester.getRect(menu).top, greaterThanOrEqualTo(thumbnail.bottom));
      expect(
        tester.getRect(bookmark).top,
        greaterThanOrEqualTo(thumbnail.bottom),
      );
      expect(
        tester.getRect(bookmark).right,
        lessThanOrEqualTo(tester.getRect(menu).left + 1),
      );
      expect(
        (tester.getRect(bookmark).center.dy - tester.getRect(menu).center.dy)
            .abs(),
        lessThan(3),
      );
      expect(
        tester.getRect(find.text(work.title)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text(work.authorName)).top + 1),
      );
      expect(
        tester.getRect(find.text(work.authorName)).bottom,
        lessThanOrEqualTo(tester.getRect(bookmark).top + 1),
      );
      // Both controls use the same 40dp outlined hit area and 16dp glyph.
      final action = tester.widget<IconButton>(bookmark);
      expect(action.iconSize, 16);
      expect(tester.getSize(bookmark), const Size(40, 40));
      final card = tester.getRect(find.byType(Card));
      expect(card.right - tester.getRect(menu).right, lessThanOrEqualTo(10));
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
    },
  );
  testWidgets('compact 320dp cards abbreviate only the visible total', (
    tester,
  ) async {
    final work = CommunityWork(
      id: 'compact-count',
      title: 'A small animation',
      authorId: 'artist',
      authorName: 'Artist',
      viewCount: 0,
      likeCount: 0,
      bookmarkCount: 2684,
      repostCount: 17,
      postedAt: DateTime.utc(2026, 11, 10),
      durationSeconds: 45,
      thumbnailColorIndex: 0,
    );
    for (final width in <double>[134, 143, 158, 170]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: CommunityWorkCard(
                  work: work,
                  isBookmarked: false,
                  onTap: () {},
                  onBookmarkToggle: () {},
                  onMuteToggle: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(width < 160 ? '2.6K' : '2,684'),
        findsOneWidget,
        reason: 'card width $width',
      );
      final total = find.byKey(
        const ValueKey('community-bookmark-count-compact-count'),
      );
      final semantics = tester.widget<Semantics>(total);
      expect(
        semantics.properties.label,
        contains('2,684'),
        reason: 'full value remains accessible at width $width',
      );
      final repost = find.byKey(
        const ValueKey('community-repost-count-compact-count'),
      );
      expect(
        find.descendant(of: repost, matching: find.text('17')),
        findsOneWidget,
      );
      expect(tester.widget<Semantics>(repost).properties.label, 'リポスト数: 17');
      final bookmark = find.byKey(
        const ValueKey('community-bookmark-compact-count'),
      );
      final menu = find.byKey(
        const ValueKey('communityMuteMenu-compact-count'),
      );
      expect(
        tester.getRect(total).bottom,
        lessThanOrEqualTo(tester.getRect(bookmark).top + 1),
      );
      expect(
        tester.getRect(repost).bottom,
        lessThanOrEqualTo(tester.getRect(bookmark).top + 1),
      );
      expect(
        tester.getRect(bookmark).right,
        lessThanOrEqualTo(tester.getRect(menu).left + 1),
      );
      expect(tester.takeException(), isNull, reason: 'card width $width');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

/// A Japanese title does not start a line with a long-vowel mark or a small
/// kana (「最後のメロデ／ィ」 at 390dp, French, twice the text size), the same
/// rule as the cards on Home. The title is still read aloud as written.
void titleLineStartTests() {
  testWidgets('community card titles keep small kana on the line before', (
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
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const titles = [
      '最後のメロディ',
      'ファーストショットのキャッチャーのジャンプショット',
      'ショッピングモールのフェスティバルでキャッチボール',
      'チョコレートシェイクとミルクティーのパーティー',
    ];
    const smallKana = 'ーぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ';
    for (final locale in const [Locale('fr'), Locale('ja')]) {
      for (final width in [320.0, 360.0, 390.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.themeData,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ChangeNotifierProvider<CommunityService>.value(
                value: community,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: CommunityWorkGrid(
                      works: [
                        for (final (i, title) in titles.indexed)
                          CommunityWork(
                            id: 'w$i',
                            title: title,
                            authorId: 'creator',
                            authorName: 'Creator',
                            viewCount: 1,
                            likeCount: 0,
                            bookmarkCount: 1,
                            postedAt: DateTime.utc(2026, 10, 22),
                            durationSeconds: 12,
                            thumbnailColorIndex: 0,
                          ),
                      ],
                      bookmarkedIds: const {},
                      onTapWork: (_) {},
                      onToggleBookmark: (_) {},
                      onTapAuthor: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final title in titles) {
            final paragraphs = tester
                .renderObjectList<RenderParagraph>(
                  find.descendant(
                    of: find.byType(CommunityWorkGrid),
                    matching: find.byType(RichText),
                  ),
                )
                .where(
                  (p) =>
                      p.text
                          .toPlainText(includeSemanticsLabels: false)
                          .replaceAll('⁠', '') ==
                      title,
                );
            expect(paragraphs, isNotEmpty, reason: title);
            for (final paragraph in paragraphs) {
              final lines = ParagraphLines(paragraph);
              for (final at in lines.breaksWithin(0, lines.visible.length)) {
                expect(
                  smallKana.contains(lines.visible[at]),
                  isFalse,
                  reason:
                      '$locale ${width}x$scale: a line starts with '
                      '${lines.visible[at]} in $title',
                );
              }
            }
          }
        }
      }
    }
  });
}
