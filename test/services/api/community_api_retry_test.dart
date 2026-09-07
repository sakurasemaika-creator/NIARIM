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
      if (attempts == 1) {
        // Simulate the important failure mode: the request may already have reached
        // the backend, but the client never receives its response.
        throw TimeoutException('response lost');
      }
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
}
