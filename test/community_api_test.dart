import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';
import 'package:niarim/services/api/niarim_api_models.dart';

/// 作品広場バックエンド（`backend/`）を叩くAPIクライアント層のテスト。
///
/// サーバーを立てずに、`package:http`のMockClientで**実際に組み立てられた
/// リクエスト**（メソッド・パス・クエリ・ヘッダー・本文）を捕まえて検査する。
/// そのうえで、捕まえたメソッド＋パスが
/// `backend/src/api/handler.ts`のルーティング表に**実在する**ことまで
/// 突き合わせるので、どちらか片方だけ変えるとこのテストが落ちる。
/// バックエンド（`backend/src/lib/response.ts`）が実際に返すヘッダー。
/// charsetまで含めないと`http.Response(String, ...)`が本文をlatin1で
/// エンコードしようとして、日本語のテストデータで例外になる。
const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

void main() {
  /// 直近のリクエストを記録するMockClient。
  ({http.Client client, List<http.Request> requests}) mock(
    Object? Function(http.Request request) respond, {
    int status = 200,
  }) {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final body = respond(request);
      return http.Response(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (client: client, requests: requests);
  }

  CommunityApi apiWith(
    http.Client client, {
    String? token,
    int maxGetRetries = 0,
  }) => CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid/api/',
      httpClient: client,
      tokenProvider: () async => token,
      maxGetRetries: maxGetRetries,
      retryBackoff: Duration.zero,
    ),
  );

  Map<String, dynamic> workJson({
    String id = 'vid00000001',
    bool published = true,
  }) => {
    'workId': id,
    'authorId': 'user_1',
    'channelName': 'テスト作者',
    'channelAvatarUrl': 'https://example.invalid/a.png',
    'title': 'テスト作品',
    'postedAt': '2026-08-01T12:00:00.000Z',
    'youtubeUrl': 'https://www.youtube.com/watch?v=$id',
    'thumbnailUrl': 'https://example.invalid/t.jpg',
    'viewCount': 1200,
    'likeCount': 34,
    'commentCount': 5,
    'bookmarkCount': 7,
    'repostCount': 2,
    'isShort': true,
    'tags': ['作画', '背景'],
    'lockedTags': ['作画'],
    'isNiarimPublished': published,
  };

  group('リクエストの組み立て', () {
    test('ベースURLの末尾スラッシュを重ねない', () async {
      final m = mock((_) => {'works': []});
      await apiWith(m.client).latestWorks();
      expect(m.requests.single.url.path, '/api/works/latest');
      expect(m.requests.single.url.toString(), isNot(contains('//works')));
    });

    test('読み取り系はIDトークンを付けない（閲覧にログインを要求しない）', () async {
      final m = mock((_) => {'works': []});
      await apiWith(m.client, token: 'ID_TOKEN').latestWorks();
      expect(m.requests.single.headers.containsKey('authorization'), isFalse);
    });

    test('書き込み系はIDトークンをBearerで付ける', () async {
      final m = mock((_) => {'bookmarked': true});
      await apiWith(m.client, token: 'ID_TOKEN').toggleBookmark('vid1');
      expect(m.requests.single.headers['authorization'], 'Bearer ID_TOKEN');
    });

    test('本人として読むときだけ読み取り系にもトークンを付ける', () async {
      final m = mock((_) => {'works': []});
      final api = apiWith(m.client, token: 'ID_TOKEN');
      await api.worksByAuthor('user_1');
      await api.worksByAuthor('user_1', asOwner: true);
      expect(m.requests[0].headers.containsKey('authorization'), isFalse);
      expect(m.requests[1].headers['authorization'], 'Bearer ID_TOKEN');
    });

    test('パスに入るIDはURLエンコードする', () async {
      final m = mock((_) => {'workId': 'a/b', 'totalCount': 0, 'users': []});
      await apiWith(m.client).bookmarkers('a/b');
      expect(m.requests.single.url.path, '/api/works/a%2Fb/bookmarkers');
    });

    test('新着一覧のlimit・cursorはクエリに載る（未指定なら載せない）', () async {
      final m = mock((_) => {'works': []});
      final api = apiWith(m.client);
      await api.latestWorks();
      await api.latestWorks(limit: 20, cursor: 'CUR');
      expect(m.requests[0].url.queryParameters, isEmpty);
      expect(m.requests[1].url.queryParameters, {
        'limit': '20',
        'cursor': 'CUR',
      });
    });

    test('投稿はvideoId・アクセストークン・isShortを本文で送る', () async {
      final m = mock((_) => workJson());
      await apiWith(m.client, token: 'T').createWork(
        youtubeVideoId: 'vid00000001',
        youtubeAccessToken: 'YT_TOKEN',
        isShort: true,
      );
      expect(jsonDecode(m.requests.single.body), {
        'youtubeVideoId': 'vid00000001',
        'youtubeAccessToken': 'YT_TOKEN',
        'isShort': true,
      });
    });

    test('タグ更新はlockedTagsを指定したときだけ送る', () async {
      final m = mock((_) => workJson());
      final api = apiWith(m.client, token: 'T');
      await api.updateTags('vid1', tags: ['a', 'b']);
      await api.updateTags('vid1', tags: ['a'], lockedTags: {'a'});
      expect(jsonDecode(m.requests[0].body), {
        'tags': ['a', 'b'],
      });
      expect(jsonDecode(m.requests[1].body), {
        'tags': ['a'],
        'lockedTags': ['a'],
      });
    });
  });

  group('レスポンスの解釈', () {
    test('作品DTOを全フィールド読み取り、画面モデルへ変換できる', () async {
      final m = mock(
        (_) => {
          'works': [workJson()],
        },
      );
      final works = await apiWith(m.client).latestWorks();
      final w = works.single;
      expect(w.workId, 'vid00000001');
      expect(w.channelName, 'テスト作者');
      expect(w.youtubeUrl, contains('vid00000001'));
      expect(w.thumbnailUrl, 'https://example.invalid/t.jpg');
      expect(w.commentCount, 5);
      expect(w.repostCount, 2);
      expect(w.tags, ['作画', '背景']);
      expect(w.lockedTags, {'作画'});
      expect(w.isShort, isTrue);
      expect(w.postedAt.toUtc().toIso8601String(), '2026-08-01T12:00:00.000Z');

      final model = w.toCommunityWork();
      expect(model.id, 'vid00000001');
      expect(model.authorName, 'テスト作者');
      expect(model.bookmarkCount, 7);
      expect(model.isShort, isTrue);
      // 同じ作品なら毎回同じプレースホルダー配色になる。
      expect(
        model.thumbnailColorIndex,
        w.toCommunityWork().thumbnailColorIndex,
      );
    });

    test('期間別ランキングはcomputedAt・windowIdも読む', () async {
      final m = mock(
        (_) => {
          'period': 'week',
          'works': [workJson()],
          'computedAt': '2026-09-01T00:00:00.000Z',
          'windowId': '2026-W35',
        },
      );
      final page = await apiWith(m.client).ranking(RankingPeriod.week);
      expect(m.requests.single.url.path, '/api/ranking/week');
      expect(page.period, 'week');
      expect(page.windowId, '2026-W35');
      expect(page.computedAt, isNotNull);
      expect(page.works, hasLength(1));
    });

    test('累計ランキングはcomputedAtがnullでも壊れない', () async {
      final m = mock(
        (_) => {
          'period': 'all',
          'works': [],
          'computedAt': null,
          'windowId': null,
        },
      );
      final page = await apiWith(m.client).ranking(RankingPeriod.all);
      expect(page.computedAt, isNull);
      expect(page.works, isEmpty);
    });

    test('被ブックマーク一覧は総数と公開ぶんを分けて読む', () async {
      final m = mock(
        (_) => {
          'workId': 'vid1',
          'totalCount': 9,
          'users': [
            {
              'niarimUserId': 'u1',
              'channelName': 'あ',
              'channelAvatarUrl': null,
              'bookmarkedAt': '2026-08-02T00:00:00.000Z',
            },
          ],
        },
      );
      final result = await apiWith(m.client).bookmarkers('vid1');
      expect(result.totalCount, 9, reason: '非公開の人も含んだ実数');
      expect(result.users, hasLength(1), reason: '公開している人だけ');
      expect(result.users.single.displayName, 'あ');
      expect(result.users.single.bookmarkedAt, isNotNull);
    });

    test('フォロワー一覧は非表示人数も読む', () async {
      final m = mock(
        (_) => {
          'targetId': 'u1',
          'totalCount': 5,
          'visibleFollowers': [
            {'niarimUserId': 'u2', 'channelName': 'い'},
          ],
          'hiddenCount': 4,
        },
      );
      final result = await apiWith(m.client).followers('u1');
      expect(result.totalCount, 5);
      expect(result.hiddenCount, 4);
      expect(result.visibleFollowers.single.niarimUserId, 'u2');
    });

    test('チャンネル名が無いユーザーはIDで代用する', () {
      final user = ApiUserRef.fromJson({'niarimUserId': 'u9'});
      expect(user.displayName, 'u9');
    });

    test('通知一覧は未読件数も読む', () async {
      final m = mock(
        (_) => {
          'notifications': [
            {
              'fromUserId': 'u2',
              'fromUserName': 'い',
              'createdAt': '2026-08-03T00:00:00.000Z',
              'read': false,
            },
          ],
          'unreadCount': 1,
        },
      );
      final result = await apiWith(m.client, token: 'T').notifications('u1');
      expect(result.unreadCount, 1);
      expect(result.notifications.single.fromUserName, 'い');
      expect(result.notifications.single.read, isFalse);
    });

    test('トグル系は操作後の状態を返す', () async {
      final bookmark = mock((_) => {'bookmarked': false});
      expect(
        await apiWith(bookmark.client, token: 'T').toggleBookmark('v'),
        isFalse,
      );
      final repost = mock((_) => {'reposted': true});
      expect(
        await apiWith(repost.client, token: 'T').toggleRepost('v'),
        isTrue,
      );
      final follow = mock((_) => {'following': true});
      expect(
        await apiWith(follow.client, token: 'T').toggleFollow('u'),
        isTrue,
      );
    });

    test('型が想定と違っても既定値へ倒して画面を壊さない', () {
      final work = ApiWork.fromJson({
        'workId': 'v1',
        'viewCount': '900', // 文字列で来た
        'likeCount': null,
        'tags': ['ok', 123], // 文字列以外が混ざった
        'postedAt': 'これは日付ではない',
      });
      expect(work.viewCount, 900);
      expect(work.likeCount, 0);
      expect(work.tags, ['ok']);
      expect(work.title, '');
      expect(work.postedAt.millisecondsSinceEpoch, 0);
    });
  });

  group('エラー処理', () {
    test('サーバーのerror・codeを例外へ写す', () async {
      final m = mock(
        (_) => {'error': '1日の投稿上限に達しています', 'code': 'DAILY_LIMIT_EXCEEDED'},
        status: 429,
      );
      await expectLater(
        apiWith(
          m.client,
          token: 'T',
        ).createWork(youtubeVideoId: 'v', youtubeAccessToken: 't'),
        throwsA(
          isA<NiarimApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.code, 'code', 'DAILY_LIMIT_EXCEEDED')
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
              .having((e) => e.message, 'message', contains('投稿上限')),
        ),
      );
    });

    test('401はisUnauthorizedになる', () async {
      final m = mock((_) => {'error': '認証が必要です'}, status: 401);
      await expectLater(
        apiWith(m.client, token: 'T').toggleBookmark('v'),
        throwsA(
          isA<NiarimApiException>().having(
            (e) => e.isUnauthorized,
            'isUnauthorized',
            isTrue,
          ),
        ),
      );
    });

    test('通信自体の失敗はネットワークエラーとして扱う', () async {
      final client = MockClient((_) async => throw const SocketException('圏外'));
      await expectLater(
        apiWith(client).latestWorks(),
        throwsA(
          isA<NiarimApiException>()
              .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
              .having((e) => e.statusCode, 'statusCode', 0),
        ),
      );
    });

    test('charset指定の無い日本語の応答もUTF-8として読める', () async {
      // Content-Typeにcharsetが無いと`http.Response.body`はlatin1へ倒れ、
      // 日本語が化けるか例外になる。バイト列をUTF-8として読んでいるので
      // ここは素通りするはず。
      final client = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"error":"不正なリクエストです","code":"BAD"}'),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      await expectLater(
        apiWith(client).latestWorks(),
        throwsA(
          isA<NiarimApiException>()
              .having((e) => e.message, 'message', '不正なリクエストです')
              .having((e) => e.code, 'code', 'BAD'),
        ),
      );
    });

    test('JSONでない応答も例外にする（画面へ生HTMLを出さない）', () async {
      final client = MockClient(
        (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
      );
      await expectLater(
        apiWith(client).latestWorks(),
        throwsA(
          isA<NiarimApiException>().having(
            (e) => e.isServerError,
            'isServerError',
            isTrue,
          ),
        ),
      );
    });
  });

  group('再試行', () {
    test('GETはサーバー障害のとき投げ直す', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls < 3) {
          return http.Response('{"error":"内部エラー"}', 503, headers: _jsonHeaders);
        }
        return http.Response('{"works":[]}', 200, headers: _jsonHeaders);
      });
      final works = await CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: client,
          maxGetRetries: 2,
          retryBackoff: Duration.zero,
        ),
      ).latestWorks();
      expect(calls, 3);
      expect(works, isEmpty);
    });

    test('GETでも4xxは投げ直さない（何度やっても同じため）', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          '{"error":"不正なリクエスト"}',
          400,
          headers: _jsonHeaders,
        );
      });
      await expectLater(
        CommunityApi(
          NiarimApiClient(
            baseUrl: 'https://example.invalid',
            httpClient: client,
            maxGetRetries: 2,
            retryBackoff: Duration.zero,
          ),
        ).latestWorks(),
        throwsA(isA<NiarimApiException>()),
      );
      expect(calls, 1);
    });

    test('POSTは投げ直さない（二重投稿・二重通報を避ける）', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw const SocketException('切断');
      });
      await expectLater(
        CommunityApi(
          NiarimApiClient(
            baseUrl: 'https://example.invalid',
            httpClient: client,
            tokenProvider: () async => 'T',
            maxGetRetries: 2,
            retryBackoff: Duration.zero,
          ),
        ).reportWork(workId: 'v', reason: '不適切'),
        throwsA(isA<NiarimApiException>()),
      );
      expect(calls, 1, reason: '通報は冪等でないので絶対に投げ直さない');
    });
  });

  test('全メソッドがbackendのルーティング表に実在する', () async {
    // handler.tsの route('METHOD', '/path', ...) を読み取る。
    final handler = File('backend/src/api/handler.ts').readAsStringSync();
    final declared = RegExp(
      r"route\('([A-Z]+)',\s*'([^']+)'",
    ).allMatches(handler).map((m) => '${m.group(1)} ${m.group(2)}').toSet();
    expect(declared, isNotEmpty, reason: 'handler.tsからルートを読めていない');

    // 実際にクライアントの全メソッドを1回ずつ呼び、飛んだ先を集める。
    final seen = <String>{};
    final client = MockClient((request) async {
      seen.add('${request.method} ${Uri.decodeFull(request.url.path)}');
      return http.Response('{}', 200);
    });
    final api = CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: client,
        tokenProvider: () async => 'T',
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
      ),
    );

    await api.latestWorks();
    for (final period in RankingPeriod.values) {
      await api.ranking(period);
    }
    await api.worksByAuthor('U');
    await api.bookmarkers('W');
    await api.bookmarksOf('U');
    await api.followers('U');
    await api.following('U');
    await api.createWork(youtubeVideoId: 'V', youtubeAccessToken: 'T');
    await api.updateWorkVisibility('W', isNiarimPublished: false);
    await api.deleteWork('W');
    await api.updateTags('W', tags: const []);
    await api.toggleBookmark('W');
    await api.toggleRepost('W');
    await api.toggleFollow('U');
    await api.setBookmarksPublic('U', true);
    await api.setFollowersPublic('U', true);
    await api.reportWork(workId: 'W', reason: 'r');
    await api.blockUser('U');
    await api.notifications('U');
    await api.markNotificationsRead('U');
    await api.putPushToken('U', token: 't', platform: 'android');

    /// 実際に飛んだパスを、handler.tsの`{id}`形式のパターンへ戻す。
    String toPattern(String actual) {
      for (final route in declared) {
        final parts = route.split(' ');
        final method = parts[0];
        final path = parts[1];
        final regex = RegExp(
          '^${path.replaceAll(RegExp(r'\{[^}]+\}'), '[^/]+')}\$',
        );
        final actualParts = actual.split(' ');
        if (actualParts[0] == method && regex.hasMatch(actualParts[1])) {
          return route;
        }
      }
      return actual; // 一致するルートが無い＝バックエンドに存在しない
    }

    final matched = seen.map(toPattern).toSet();
    final missing = matched.difference(declared);
    expect(
      missing,
      isEmpty,
      reason:
          'backend/src/api/handler.ts に無いエンドポイントを呼んでいる:\n'
          '${missing.join('\n')}',
    );
    // 21本すべてを1回は呼んでいる（＝未接続のエンドポイントが無い）。
    final untouched = declared.difference(matched);
    expect(
      untouched,
      isEmpty,
      reason:
          'バックエンドにあるのにクライアント層が呼んでいないエンドポイント:\n'
          '${untouched.join('\n')}',
    );
  });
}
