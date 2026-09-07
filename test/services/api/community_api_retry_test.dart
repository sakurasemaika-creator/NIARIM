import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';

void main() {
  test('createWork retries once after a lost response with the same videoId', () async {
    var attempts = 0;
    final requestBodies = <Map<String, dynamic>>[];
    final httpClient = MockClient((request) async {
      attempts++;
      requestBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (attempts == 1) throw TimeoutException('response lost');
      return http.Response(
        jsonEncode({
          'work': {
            'workId': 'abc123DEF_4',
            'authorId': 'author-1',
            'title': 'retry work',
            'postedAt': '2026-09-07T00:00:00.000Z',
            'isNiarimPublished': true,
          },
        }),
        201,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final client = NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: httpClient,
      tokenProvider: () async => 'google-id-token',
      retryBackoff: Duration.zero,
    );
    final api = CommunityApi(client);

    final work = await api.createWork(
      youtubeVideoId: 'abc123DEF_4',
      youtubeAccessToken: 'youtube-token',
      isNiarimPublished: true,
    );

    expect(work.workId, 'abc123DEF_4');
    expect(attempts, 2);
    expect(requestBodies, hasLength(2));
    expect(requestBodies[0]['youtubeVideoId'], 'abc123DEF_4');
    expect(requestBodies[1]['youtubeVideoId'], 'abc123DEF_4');
    expect(requestBodies[1], requestBodies[0]);
    client.close();
  });

  test('visibility PATCH retries once after a lost response with the same desired state', () async {
    var attempts = 0;
    final requestBodies = <Map<String, dynamic>>[];
    final client = NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) async {
        attempts++;
        requestBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        expect(request.method, 'PATCH');
        expect(request.url.path, '/works/abc123DEF_4');
        if (attempts == 1) throw TimeoutException('response lost');
        return http.Response(
          jsonEncode({
            'work': {
              'workId': 'abc123DEF_4',
              'authorId': 'author-1',
              'title': 'visibility work',
              'postedAt': '2026-09-07T00:00:00.000Z',
              'isNiarimPublished': false,
            },
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      tokenProvider: () async => 'google-id-token',
      retryBackoff: Duration.zero,
    );
    final api = CommunityApi(client);

    final work = await api.updateWorkVisibility(
      'abc123DEF_4',
      isNiarimPublished: false,
    );

    expect(work.isNiarimPublished, isFalse);
    expect(attempts, 2);
    expect(requestBodies, hasLength(2));
    expect(requestBodies[0], {'isNiarimPublished': false});
    expect(requestBodies[1], requestBodies[0]);
    client.close();
  });

  test('authenticated request re-evaluates token once after 401', () async {
    var tokenReads = 0;
    var attempts = 0;
    final seenAuthorization = <String?>[];
    final client = NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) async {
        attempts++;
        seenAuthorization.add(request.headers['authorization']);
        if (attempts == 1) {
          return http.Response(
            jsonEncode({'error': 'expired', 'code': 'UNAUTHORIZED'}),
            401,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'works': []}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async {
        tokenReads++;
        return tokenReads == 1 ? 'expired-token' : 'fresh-token';
      },
      retryBackoff: Duration.zero,
    );

    final json = await client.getJson('/me/works', authenticated: true);

    expect(json['works'], isEmpty);
    expect(attempts, 2);
    expect(tokenReads, 2);
    expect(seenAuthorization, ['Bearer expired-token', 'Bearer fresh-token']);
    client.close();
  });

  test('authenticated mutation may retry once after 401 but not after ordinary 4xx', () async {
    var attempts = 0;
    final requestBodies = <String>[];
    final client = NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) async {
        attempts++;
        requestBodies.add(request.body);
        if (attempts == 1) {
          return http.Response(
            jsonEncode({'error': 'expired', 'code': 'UNAUTHORIZED'}),
            401,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'error': 'bad request'}),
          400,
          headers: const {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => attempts == 0 ? 'expired-token' : 'fresh-token',
      retryBackoff: Duration.zero,
    );

    await expectLater(
      client.postJson('/reports', body: const {'workId': 'abc123DEF_4'}),
      throwsA(
        isA<NiarimApiException>().having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
    expect(attempts, 2);
    expect(requestBodies[1], requestBodies[0]);
    client.close();
  });

  test('ordinary POST calls still do not retry by default', () async {
    var attempts = 0;
    final client = NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) async {
        attempts++;
        throw TimeoutException('response lost');
      }),
      retryBackoff: Duration.zero,
    );

    await expectLater(
      client.postJson('/reports', body: const {'workId': 'abc123DEF_4'}),
      throwsA(isA<NiarimApiException>()),
    );
    expect(attempts, 1);
    client.close();
  });

  test('ordinary PATCH calls still do not retry by default', () async {
    var attempts = 0;
    final client = NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) async {
        attempts++;
        throw TimeoutException('response lost');
      }),
      retryBackoff: Duration.zero,
    );

    await expectLater(
      client.patchJson(
        '/works/abc123DEF_4/tags',
        body: const {'action': 'add', 'tag': 'test'},
      ),
      throwsA(isA<NiarimApiException>()),
    );
    expect(attempts, 1);
    client.close();
  });
}
