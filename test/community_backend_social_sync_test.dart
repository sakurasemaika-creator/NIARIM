import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// With a backend, the viewer's follows, reposts and bookmarks are the
/// server's: toggles are sent (and undone when refused), the following feed
/// and author pages are fetched, and the viewer's filters (AI images and
/// videos, muted titles, muted tags) apply to every work they bring in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const headers = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> work(
    String id, {
    String author = 'fav',
    String? title,
    bool ai = false,
    List<String> tags = const [],
    String postedAt = '2026-09-01T00:00:00.000Z',
  }) => {
    'workId': id,
    'authorId': author,
    'channelName': 'Channel $author',
    'title': title ?? 'Work $id',
    'postedAt': postedAt,
    'youtubeUrl': 'https://www.youtube.com/watch?v=$id',
    'thumbnailUrl': 'https://example.invalid/t.jpg',
    'viewCount': 1,
    'likeCount': 1,
    'commentCount': 0,
    'bookmarkCount': 0,
    'repostCount': 0,
    'isShort': false,
    'tags': tags,
    'lockedTags': <String>[],
    'isNiarimPublished': true,
    'containsGenerativeAiImageOrVideo': ai,
  };

  final serverWorks = {
    'fav': [
      work('favplain001'),
      work('favai000001', ai: true),
      work('favtitle001', title: 'Big spoiler inside'),
      work('favtag00001', tags: ['gore']),
    ],
    'stranger': [
      work('strange0001', author: 'stranger'),
      work('strangeai01', author: 'stranger', ai: true),
    ],
    'me': [work('mine0000001', author: 'me')],
  };
  final serverReposts = {
    'fav': [
      {
        'repostedAt': '2026-09-10T00:00:00.000Z',
        'work': work('other000001', author: 'other'),
      },
      {
        'repostedAt': '2026-09-09T00:00:00.000Z',
        'work': work('otherai0001', author: 'other', ai: true),
      },
    ],
    'me': [
      {'repostedAt': '2026-09-08T00:00:00.000Z', 'work': work('favplain001')},
    ],
  };

  ({CommunityService service, List<String> calls, Set<String> failing})
  backend() {
    final calls = <String>[];
    // Paths answered with a server error, to check rollbacks.
    final failing = <String>{};
    final client = MockClient((request) async {
      final path = Uri.decodeFull(request.url.path);
      calls.add('${request.method} $path');
      if (failing.contains(path)) {
        return http.Response(
          jsonEncode({'error': 'down'}),
          500,
          headers: headers,
        );
      }
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      Object body;
      if (path == '/works/latest') {
        body = {'works': <Object>[]};
      } else if (path == '/me/works') {
        body = {'authorId': 'me', 'works': serverWorks['me']};
      } else if (path.startsWith('/ranking/')) {
        body = {
          'period': segments.last,
          'works': [work('ranked00001', author: 'stranger')],
        };
      } else if (segments.first == 'users' && segments.length == 3) {
        final user = segments[1];
        body = switch (segments[2]) {
          'works' => {'works': serverWorks[user] ?? <Object>[]},
          'reposts' => {
            'userId': user,
            'reposts': serverReposts[user] ?? <Object>[],
          },
          'bookmarks' => {
            'works': [work('bookmark001', author: 'stranger')],
          },
          'following' => {
            'following': [
              {'niarimUserId': 'fav', 'channelName': 'Fav'},
            ],
          },
          'follow' => {'following': true},
          _ => <String, Object>{},
        };
      } else if (path.endsWith('/bookmark')) {
        body = {'bookmarked': true};
      } else if (path.endsWith('/repost')) {
        body = {'reposted': !path.contains('favplain001')};
      } else {
        body = <String, Object>{};
      }
      return http.Response(jsonEncode(body), 200, headers: headers);
    });
    final service = CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: client,
          tokenProvider: () async => 'token',
          maxGetRetries: 0,
          retryBackoff: Duration.zero,
        ),
      ),
    );
    return (service: service, calls: calls, failing: failing);
  }

  Set<String> feedIds(CommunityService s) =>
      s.favoriteAuthorFeed.map((e) => e.work.id).toSet();

  test(
    'the following feed, reposts and bookmarks come from the server',
    () async {
      final (:service, :calls, failing: _) = backend();
      await service.contentFiltersReady;
      await service.loadOwnWorks();
      expect(await service.loadSocial(), isTrue);

      expect(service.favoriteAuthorIds, {'fav'});
      expect(service.bookmarkedIds, {'bookmark001'});
      expect(feedIds(service), {
        'favplain001',
        'favai000001',
        'favtitle001',
        'favtag00001',
        'other000001',
        'otherai0001',
      });
      final repost = service.favoriteAuthorFeed.firstWhere(
        (e) => e.work.id == 'other000001',
      );
      expect(repost.repostedByAuthorName, 'Fav');
      expect(
        repost.feedTime.isAtSameMomentAs(DateTime.utc(2026, 9, 10)),
        isTrue,
      );
      expect(service.isRepostedBySelf('favplain001'), isTrue);
      expect(calls, contains('GET /users/fav/works'));
      expect(calls, contains('GET /users/fav/reposts'));
      expect(calls, contains('GET /users/me/reposts'));

      // The viewer's filters apply to the server's feed like everywhere.
      await service.setHideGenerativeAiImageVideo(true);
      await service.setMutedWords(['SPOILER']);
      await service.setMutedTags(['#gore']);
      expect(feedIds(service), {'favplain001', 'other000001'});
      await service.setHideGenerativeAiImageVideo(false);
      await service.setMutedWords(const []);
      await service.setMutedTags(const []);

      // Refreshing the latest page (which has none of them) keeps the feed:
      // the server still confirms these works.
      await service.refreshFromBackend();
      expect(feedIds(service), hasLength(6));
      expect(service.byId('bookmark001'), isNotNull);
    },
  );

  test('an author page is fetched and filtered', () async {
    final (:service, :calls, failing: _) = backend();
    await service.contentFiltersReady;
    expect(service.worksByAuthor('stranger'), isEmpty);
    expect(await service.refreshAuthorWorks('stranger'), isTrue);
    expect(calls, contains('GET /users/stranger/works'));
    expect(service.worksByAuthor('stranger').map((w) => w.id), {
      'strange0001',
      'strangeai01',
    });
    await service.setHideGenerativeAiImageVideo(true);
    expect(service.worksByAuthor('stranger').map((w) => w.id), {'strange0001'});
    // Other lists refreshing do not drop the page's works.
    await service.refreshFromBackend();
    expect(service.byId('strange0001'), isNotNull);
  });

  test('follow, repost and bookmark toggles are sent to the server', () async {
    final (:service, :calls, failing: _) = backend();
    await service.contentFiltersReady;
    await service.loadOwnWorks();
    await service.loadSocial();
    await service.refreshAuthorWorks('stranger');

    calls.clear();
    expect(await service.toggleFavoriteAuthor('stranger'), isTrue);
    expect(calls.first, 'POST /users/stranger/follow');
    expect(service.isFavoriteAuthor('stranger'), isTrue);
    // A new follow brings the author's works into the feed.
    expect(feedIds(service), contains('strange0001'));

    calls.clear();
    expect(await service.toggleBookmark('strange0001'), isTrue);
    expect(calls, ['POST /works/strange0001/bookmark']);
    expect(service.isBookmarked('strange0001'), isTrue);

    calls.clear();
    expect(await service.toggleRepost('strange0001'), isTrue);
    expect(calls, ['POST /works/strange0001/repost']);
    expect(service.isRepostedBySelf('strange0001'), isTrue);

    // The server's answer wins: here it says the repost is gone.
    expect(service.isRepostedBySelf('favplain001'), isTrue);
    expect(await service.toggleRepost('favplain001'), isTrue);
    expect(service.isRepostedBySelf('favplain001'), isFalse);
  });

  test('a refused toggle is undone and says why', () async {
    final (:service, calls: _, :failing) = backend();
    await service.contentFiltersReady;
    await service.loadOwnWorks();
    await service.loadSocial();
    failing.add('/users/stranger/follow');
    failing.add('/works/favplain001/bookmark');

    final follow = service.toggleFavoriteAuthor('stranger');
    // Applied at once, before the server answers…
    expect(service.isFavoriteAuthor('stranger'), isTrue);
    expect(await follow, isFalse);
    // …and taken back when it refuses.
    expect(service.isFavoriteAuthor('stranger'), isFalse);
    expect(service.lastError?.statusCode, 500);

    expect(await service.toggleBookmark('favplain001'), isFalse);
    expect(service.isBookmarked('favplain001'), isFalse);
  });

  test('a ranking that fails to load is not the previous one', () async {
    final (:service, calls: _, :failing) = backend();
    await service.contentFiltersReady;
    expect(await service.fetchRanking(RankingPeriod.week), isNotEmpty);
    expect(service.rankedWorks, isNotEmpty);
    failing.add('/ranking/${RankingPeriod.month.pathValue}');
    expect(await service.fetchRanking(RankingPeriod.month), isEmpty);
    expect(service.rankedWorks, isEmpty);
    expect(service.byId('ranked00001'), isNull, reason: 'no longer confirmed');
  });

  test('the poster is recognised from the start on a known account', () async {
    SharedPreferences.setMockInitialValues({
      'community.ownerByAccount.google-1': 'me',
    });
    final (:service, calls: _, failing: _) = backend();
    await service.restoreOwner('google-1');
    expect(service.currentUserId, 'me');
    // Another account learns its own id and remembers it.
    final other = backend().service;
    await other.restoreOwner('google-2');
    expect(other.currentUserId, isNull);
    await other.loadOwnWorks(accountKey: 'google-2');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('community.ownerByAccount.google-2'), 'me');
  });

  test('signing out forgets the viewer\'s social state', () async {
    final (:service, calls: _, failing: _) = backend();
    await service.contentFiltersReady;
    await service.loadOwnWorks();
    await service.loadSocial();
    expect(service.favoriteAuthorIds, isNotEmpty);
    service.forgetOwner();
    expect(service.favoriteAuthorIds, isEmpty);
    expect(service.bookmarkedIds, isEmpty);
    expect(service.favoriteAuthorFeed, isEmpty);
    expect(service.isRepostedBySelf('favplain001'), isFalse);
  });
}
