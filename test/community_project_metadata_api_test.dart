import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_models.dart';

void main() {
  CommunityApi apiWith(http.Client client, {String? token = 'ID_TOKEN'}) =>
      CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid/api/',
          httpClient: client,
          tokenProvider: () async => token,
          maxGetRetries: 0,
          retryBackoff: Duration.zero,
        ),
      );

  Map<String, dynamic> workJson({bool withMetadata = true}) => {
    'workId': 'abcdefghijk',
    'authorId': 'user_1',
    'channelName': '作者',
    'channelAvatarUrl': '',
    'title': '作品',
    'postedAt': '2026-09-01T00:00:00.000Z',
    'youtubeUrl': 'https://www.youtube.com/watch?v=abcdefghijk',
    'thumbnailUrl': '',
    'viewCount': 1,
    'likeCount': 2,
    'commentCount': 3,
    'bookmarkCount': 4,
    'repostCount': 5,
    'isShort': true,
    'tags': <String>[],
    'lockedTags': <String>[],
    'isNiarimPublished': true,
    if (withMetadata) ...{
      'projectFps': 24,
      'projectFrameCount': 288,
      'projectWorkSeconds': 7380,
      'projectCreatedAt': '2026-08-20T03:04:05.000Z',
      'projectCanvasWidth': 1080,
      'projectCanvasHeight': 1920,
    },
  };

  test('投稿時にNIARIM制作情報をoptionalフィールドとして送れる', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'work': workJson()}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await apiWith(client).createWork(
      youtubeVideoId: 'abcdefghijk',
      youtubeAccessToken: 'YT_TOKEN',
      isShort: true,
      projectFps: 24,
      projectFrameCount: 288,
      projectWorkSeconds: 7380,
      projectCreatedAt: DateTime.utc(2026, 8, 20, 3, 4, 5),
      projectCanvasWidth: 1080,
      projectCanvasHeight: 1920,
    );

    expect(jsonDecode(captured.body), {
      'youtubeVideoId': 'abcdefghijk',
      'youtubeAccessToken': 'YT_TOKEN',
      'isShort': true,
      'isNiarimPublished': true,
      'projectFps': 24,
      'projectFrameCount': 288,
      'projectWorkSeconds': 7380,
      'projectCreatedAt': '2026-08-20T03:04:05.000Z',
      'projectCanvasWidth': 1080,
      'projectCanvasHeight': 1920,
    });
  });

  test('制作情報が無い従来投稿は余分なフィールドを送らない', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'work': workJson(withMetadata: false)}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await apiWith(
      client,
    ).createWork(youtubeVideoId: 'abcdefghijk', youtubeAccessToken: 'YT_TOKEN');

    expect(jsonDecode(captured.body), {
      'youtubeVideoId': 'abcdefghijk',
      'youtubeAccessToken': 'YT_TOKEN',
      'isShort': false,
      'isNiarimPublished': true,
    });
  });

  test('APIの制作情報がCommunityWorkまで欠落せず届き尺も復元される', () async {
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'works': [workJson()],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final dto = (await apiWith(client, token: null).latestWorks()).single;
    expect(dto.projectFps, 24);
    expect(dto.projectFrameCount, 288);
    expect(dto.projectWorkSeconds, 7380);
    expect(dto.projectCanvasWidth, 1080);
    expect(dto.projectCanvasHeight, 1920);
    expect(
      dto.projectCreatedAt?.toUtc().toIso8601String(),
      '2026-08-20T03:04:05.000Z',
    );

    final work = dto.toCommunityWork();
    expect(work.durationSeconds, 12, reason: '288f ÷ 24fps = 12秒');
    expect(work.projectFps, 24);
    expect(work.projectFrameCount, 288);
    expect(work.projectWorkSeconds, 7380);
    expect(work.projectCanvasWidth, 1080);
    expect(work.projectCanvasHeight, 1920);
    expect(
      work.projectCreatedAt?.toUtc().toIso8601String(),
      '2026-08-20T03:04:05.000Z',
    );
  });

  test('FPSかフレーム数が無い古い作品は尺0のまま安全に扱う', () {
    final dto = ApiWork.fromJson(workJson(withMetadata: false));
    expect(dto.toCommunityWork().durationSeconds, 0);
  });
}
