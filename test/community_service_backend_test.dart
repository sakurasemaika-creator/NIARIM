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
          'period': 'month',
          'works': [work('vid9', '月間1位')],
        }),
        200,
        headers: jsonHeaders,
      );
    });
    final service = CommunityService(api: api(client));
    final works = await service.fetchRanking(RankingPeriod.month);
    expect(paths.single, '/ranking/month');
    expect(works.single.title, '月間1位');
  });
}
