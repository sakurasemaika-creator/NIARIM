import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';

/// `CommunityService`がバックエンドと繋がったときの振る舞い。
///
/// 「デプロイ前でもアプリが一通り動く」ことと「デプロイ後は同じ画面が
/// 実データで動く」ことの両立が要件なので、その両方を検証する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> work(String id, String title) => {
    'workId': id,
    'authorId': 'user_1',
    'channelName': 'サーバー上の作者',
    'channelAvatarUrl': '',
    'title': title,
    'postedAt': '2026-09-01T00:00:00.000Z',
    'youtubeUrl': 'https://www.youtube.com/watch?v=$id',
    'thumbnailUrl': 'https://example.invalid/$id.jpg',
    'viewCount': 100,
    'likeCount': 10,
    'commentCount': 1,
    'bookmarkCount': 2,
    'repostCount': 0,
    'isShort': false,
    'tags': <String>[],
    'lockedTags': <String>[],
    'isNiarimPublished': true,
  };

  CommunityApi api(http.Client client) => CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: client,
      maxGetRetries: 0,
      retryBackoff: Duration.zero,
    ),
  );

  test('APIを渡さなければダミーデータのまま動く（デプロイ前）', () async {
    final service = CommunityService();
    expect(service.isBackendConnected, isFalse);
    expect(service.works, isNotEmpty, reason: 'ダミーデータで画面が作れる');
    // 取得しようとしても何も起きず、一覧はそのまま。
    final before = service.works.length;
    expect(await service.refreshFromBackend(), isFalse);
    expect(service.works, hasLength(before));
  });

  test('APIを渡すとバックエンドの一覧で置き換わる', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'works': [work('vid1', 'サーバー作品1'), work('vid2', 'サーバー作品2')],
        }),
        200,
        headers: jsonHeaders,
      ),
    );
    final service = CommunityService(api: api(client));
    expect(service.isBackendConnected, isTrue);

    expect(await service.refreshFromBackend(), isTrue);
    expect(service.works.map((w) => w.title), ['サーバー作品1', 'サーバー作品2']);
    expect(service.works.first.authorName, 'サーバー上の作者');
    expect(service.lastError, isNull);
    expect(service.isLoading, isFalse);
  });

  test('取得に失敗しても手元の一覧は消さず、理由を残す', () async {
    var succeed = true;
    final client = MockClient((request) async {
      if (succeed) {
        return http.Response(
          jsonEncode({
            'works': [work('vid1', 'サーバー作品1')],
          }),
          200,
          headers: jsonHeaders,
        );
      }
      return http.Response(
        jsonEncode({'error': '一時的に利用できません'}),
        503,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    await service.refreshFromBackend();
    expect(service.works, hasLength(1));

    succeed = false;
    expect(await service.refreshFromBackend(), isFalse);
    expect(service.works, hasLength(1), reason: '失敗しても画面が真っ白にならないよう、古い一覧を残す');
    expect(service.lastError, isNotNull);
    expect(service.lastError!.isServerError, isTrue);
    expect(service.isLoading, isFalse, reason: '失敗しても読み込み中のままにしない');
  });

  test('ランキングはAPI未設定ならダミーの公開作品を返す', () async {
    final service = CommunityService();
    final works = await service.fetchRanking(RankingPeriod.week);
    expect(works, isNotEmpty);
    expect(works.every((w) => w.isNiarimPublished), isTrue);
  });

  test('ランキングはAPI設定時に指定した期間を取りに行く', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({
          'period': 'monthly',
          'works': [work('vid9', '月間1位')],
        }),
        200,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    final works = await service.fetchRanking(RankingPeriod.month);
    expect(paths.single, '/ranking/monthly');
    expect(works.single.title, '月間1位');
  });
  test('新着は25件ずつカーソル取得し、重複を増やさず最後で止まる', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      expect(request.url.queryParameters['limit'], '25');
      final cursor = request.url.queryParameters['cursor'];
      final start = cursor == null ? 0 : int.parse(cursor);
      final end = start == 50 ? 53 : start + 25;
      return http.Response(
        jsonEncode({
          'works': [
            for (var i = start; i < end; i++) work('latest_$i', '新着$i'),
          ],
          'nextCursor': end < 53 ? '$end' : null,
        }),
        200,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    expect(await service.refreshFromBackend(), isTrue);
    expect(service.latestPageWorks, hasLength(25));
    expect(service.hasMoreLatest, isTrue);
    expect(await service.loadMoreLatest(), isTrue);
    expect(service.latestPageWorks, hasLength(50));
    expect(await service.loadMoreLatest(), isTrue);
    expect(service.latestPageWorks, hasLength(53));
    expect(service.hasMoreLatest, isFalse);
    expect(await service.loadMoreLatest(), isFalse);
    expect(seen, hasLength(3));
    expect(seen[1].queryParameters['cursor'], '25');
    expect(seen[2].queryParameters['cursor'], '50');
    expect(service.latestPageWorks.map((w) => w.id).toSet(), hasLength(53));
  });

  test('ランキングはTop50を25件ずつ、並び方向をサーバーへ渡す', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      final cursor = int.parse(request.url.queryParameters['cursor'] ?? '0');
      return http.Response(
        jsonEncode({
          'period': 'monthly',
          'works': [
            for (var i = cursor; i < cursor + 25; i++) work('rank_$i', '順位$i'),
          ],
          'nextCursor': cursor == 0 ? '25' : null,
        }),
        200,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    await service.fetchRanking(
      RankingPeriod.month,
      ascending: true,
      sortBookmarks: true,
    );
    expect(service.rankedWorks, hasLength(25));
    expect(service.hasMoreRanking, isTrue);
    await service.loadMoreRanking(
      RankingPeriod.month,
      ascending: true,
      sortBookmarks: true,
    );
    expect(service.rankedWorks, hasLength(50));
    expect(service.hasMoreRanking, isFalse);
    expect(seen[0].queryParameters['ascending'], 'true');
    expect(seen[0].queryParameters['sort'], 'bookmarks');
    expect(seen[1].queryParameters['cursor'], '25');
    expect(seen, hasLength(2));
  });

  test('検索結果は独立ページ、タグ完全一致条件を次ページへ維持する', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      final cursor = request.url.queryParameters['cursor'];
      final start = cursor == null ? 0 : 25;
      return http.Response(
        jsonEncode({
          'works': [
            for (var i = start; i < start + 25; i++) work('search_$i', '作品$i'),
          ],
          'nextCursor': cursor == null ? 'next' : null,
        }),
        200,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    await service.refreshSearch(query: '手描き', tagMode: true, exact: true);
    expect(service.searchedWorks, hasLength(25));
    expect(service.hasMoreSearch, isTrue);
    await service.loadMoreSearch();
    expect(service.searchedWorks, hasLength(50));
    expect(service.hasMoreSearch, isFalse);
    expect(seen[1].queryParameters['cursor'], 'next');
    for (final uri in seen) {
      expect(uri.queryParameters['q'], '手描き');
      expect(uri.queryParameters['tagMode'], 'true');
      expect(uri.queryParameters['exact'], 'true');
    }
    await service.refreshSearch(query: '別の検索', tagMode: false, exact: false);
    expect(service.searchedWorks, hasLength(25));
    expect(seen.last.queryParameters.containsKey('cursor'), isFalse);
    expect(seen.last.queryParameters.containsKey('tagMode'), isFalse);
  });

  test('作者別投稿は25件単位で追加取得し、初回ページを消さない', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      final cursor = request.url.queryParameters['cursor'];
      final start = cursor == null ? 0 : 25;
      return http.Response(
        jsonEncode({
          'works': [
            for (var i = start; i < start + 25; i++) work('author_$i', '投稿$i'),
          ],
          'nextCursor': cursor == null ? 'author-next' : null,
        }),
        200,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    expect(await service.refreshAuthorWorks('user_1'), isTrue);
    expect(service.worksByAuthor('user_1'), hasLength(25));
    expect(service.hasMoreAuthor('user_1'), isTrue);
    expect(await service.loadMoreAuthorWorks('user_1'), isTrue);
    expect(service.worksByAuthor('user_1'), hasLength(50));
    expect(service.hasMoreAuthor('user_1'), isFalse);
    expect(seen, hasLength(2));
    expect(seen.last.queryParameters['cursor'], 'author-next');
  });
}
