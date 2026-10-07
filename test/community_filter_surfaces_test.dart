import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_post_screen.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The work plaza's viewer filters (「AI画像・AI動画使用」 works hidden, muted
/// titles, muted tags) give the same answer on every surface: new, ranking,
/// following (the followed author's own works and the reposts they made),
/// other authors' pages, bookmarks and Shorts. A tag added or removed after
/// posting moves the work in or out of them at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CommunityWork work(
    String id, {
    required String author,
    String? title,
    List<String> tags = const ['手描き'],
    bool ai = false,
  }) => CommunityWork(
    id: id,
    title: title ?? '作品 $id',
    authorId: author,
    authorName: '作者 $author',
    viewCount: 0,
    likeCount: 0,
    bookmarkCount: 0,
    postedAt: DateTime(2026, 9, 1),
    durationSeconds: 10,
    thumbnailColorIndex: 0,
    tags: tags,
    isShort: true,
    containsGenerativeAiImageOrVideo: ai,
  );

  // author_a (followed) posts two works; author_b posts two more, which the
  // followed author_c reposts, so they reach the following tab only as
  // reposts.
  final plain = work('plain', author: 'author_a');
  final spoiler = work('spoiler', author: 'author_a', title: '最終回ネタバレ注意');
  final gore = work('gore', author: 'author_b', tags: const ['手描き', 'グロ']);
  final ai = work('ai', author: 'author_b', ai: true);
  final reposter = work('c_own', author: 'author_c');

  Future<CommunityService> plaza() async {
    final service = CommunityService();
    await service.contentFiltersReady;
    service.replaceWorksForTest([plain, spoiler, gore, ai, reposter]);
    await service.toggleFavoriteAuthor('author_a');
    await service.toggleFavoriteAuthor('author_c');
    await service.toggleRepost('gore', authorId: 'author_c');
    await service.toggleRepost('ai', authorId: 'author_c');
    for (final w in [plain, spoiler, gore, ai]) {
      await service.toggleBookmark(w.id);
    }
    return service;
  }

  /// Every surface's ids, by surface.
  Map<String, Set<String>> surfaces(CommunityService s) => {
    'new / ranking': s.discoverableWorks.map((w) => w.id).toSet(),
    'following': s.favoriteAuthorFeed
        .where((e) => !e.isRepost)
        .map((e) => e.work.id)
        .toSet(),
    'reposts': s.favoriteAuthorFeed
        .where((e) => e.isRepost)
        .map((e) => e.work.id)
        .toSet(),
    'author_a page': s.worksByAuthor('author_a').map((w) => w.id).toSet(),
    'author_b page': s.worksByAuthor('author_b').map((w) => w.id).toSet(),
    'bookmarks': s.bookmarkedWorksForViewer.map((w) => w.id).toSet(),
  };

  void expectHiddenEverywhere(CommunityService s, String id) {
    for (final MapEntry(:key, :value) in surfaces(s).entries) {
      expect(value, isNot(contains(id)), reason: '$id still on $key');
    }
    expect(s.isDiscoverableForViewer(s.byId(id)!), isFalse, reason: 'detail');
  }

  test('with no filter every surface shows its works', () async {
    final s = await plaza();
    final all = surfaces(s);
    expect(
      all['new / ranking'],
      containsAll(['plain', 'spoiler', 'gore', 'ai']),
    );
    expect(all['following'], {'plain', 'spoiler', 'c_own'});
    expect(all['reposts'], {'gore', 'ai'});
    expect(all['author_b page'], {'gore', 'ai'});
    expect(all['bookmarks'], {'plain', 'spoiler', 'gore', 'ai'});
  });

  test('「AI画像・AI動画使用」 works are hidden on every surface', () async {
    final s = await plaza();
    await s.setHideGenerativeAiImageVideo(true);
    expectHiddenEverywhere(s, 'ai');
    expect(surfaces(s)['reposts'], {'gore'});
  });

  test('a muted title hides the work on every surface', () async {
    final s = await plaza();
    await s.setMutedWords(CommunityService.parseFilterInput('ネタバレ'));
    expectHiddenEverywhere(s, 'spoiler');
    expect(surfaces(s)['following'], {'plain', 'c_own'});
  });

  test('a muted tag hides the work on every surface', () async {
    final s = await plaza();
    await s.setMutedTags(CommunityService.parseFilterInput('#グロ'));
    expectHiddenEverywhere(s, 'gore');
    expect(surfaces(s)['reposts'], {'ai'});
  });

  test('a tag added or removed after posting moves the work at once', () async {
    final s = await plaza();
    await s.setMutedTags(['ホラー']);
    expect(surfaces(s)['following'], contains('plain'));
    expect(await s.addTag('plain', 'ホラー'), isTrue);
    expectHiddenEverywhere(s, 'plain');
    expect(await s.removeTag('plain', 'ホラー'), isTrue);
    for (final MapEntry(:key, :value) in surfaces(s).entries) {
      if (key == 'author_b page' || key == 'reposts') continue;
      expect(value, contains('plain'), reason: 'back on $key');
    }
  });

  test('the poster\'s own management keeps their filtered works', () async {
    final s = CommunityService();
    await s.contentFiltersReady;
    final own = work('own', author: kDummySelfAuthorId, ai: true);
    s.replaceWorksForTest([own]);
    await s.setHideGenerativeAiImageVideo(true);
    expect(s.discoverableWorks, isEmpty);
    expect(
      s.worksByAuthor(kDummySelfAuthorId, includeHidden: true).single.id,
      'own',
    );
  });

  testWidgets('Shorts drop a work as soon as its title or tag is muted', (
    tester,
  ) async {
    final s = await tester.runAsync(plaza);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: s!),
          ChangeNotifierProvider<SettingsService>.value(
            value: SettingsService(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityShortsScreen(
            works: [spoiler, gore, plain],
            bookmarkedIds: const <String>{},
            onToggleBookmark: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(spoiler.title), findsOneWidget);

    await tester.runAsync(() => s.setMutedWords(['ネタバレ']));
    await tester.pumpAndSettle();
    expect(find.text(spoiler.title), findsNothing);
    expect(find.text(gore.title), findsOneWidget);

    await tester.runAsync(() => s.setMutedTags(['グロ']));
    await tester.pumpAndSettle();
    expect(find.text(gore.title), findsNothing);
    expect(find.text(plain.title), findsOneWidget);
  });

  testWidgets(
    'a retained upload keeps its 「AI画像・AI動画使用」 choice across restarts',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'community.pendingUpload.videoId': 'abcdefghijk',
        'community.pendingUpload.title': '保留中の作品',
        'community.pendingUpload.containsGenerativeAiImageOrVideo': true,
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>(
              create: (_) => CommunityService(),
            ),
            ChangeNotifierProvider<GoogleAuthService>(
              create: (_) => GoogleAuthService(),
            ),
            ChangeNotifierProvider<SettingsService>(
              create: (_) => SettingsService(),
            ),
            ChangeNotifierProvider<PremiumService>(
              create: (_) => PremiumService(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CommunityPostScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CommunityPostScreen)),
      )!;
      final aiSwitch = find.widgetWithText(
        SwitchListTile,
        l10n.communityContainsGenerativeAiImageVideo,
      );
      await tester.ensureVisible(aiSwitch);
      expect(tester.widget<SwitchListTile>(aiSwitch).value, isTrue);

      // Changing it while the upload is retained is remembered too.
      await tester.tap(aiSwitch);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          'community.pendingUpload.containsGenerativeAiImageOrVideo',
        ),
        isFalse,
      );
    },
  );

  test('recovery and idempotent replies re-send the chosen AI flag', () {
    final source = File(
      'lib/screens/community/community_post_screen.dart',
    ).readAsStringSync();
    // An already registered work whose stored flag differs is patched
    // before the recovered registration finishes…
    final recovered = source.indexOf('if (work.workId != videoId) continue;');
    final recoveredPatch = source.indexOf(
      'await api.updateWorkAiImageVideoDisclosure(',
      recovered,
    );
    final recoveredFinish = source.indexOf(
      'await _finishRegistration(',
      recovered,
    );
    expect(recovered, greaterThanOrEqualTo(0));
    expect(recoveredPatch, greaterThan(recovered));
    expect(recoveredFinish, greaterThan(recoveredPatch));
    // …and so is a POST /works reply carrying an earlier attempt's flag.
    final post = source.indexOf('await api.createWork(');
    final postPatch = source.indexOf(
      'await api.updateWorkAiImageVideoDisclosure(',
      post,
    );
    expect(post, greaterThan(recoveredFinish));
    expect(postPatch, greaterThan(post));
    expect(
      source,
      contains(
        'registeredWork.containsGenerativeAiImageOrVideo !=\n'
        '          _containsGenerativeAiImageOrVideo',
      ),
    );
  });
}
