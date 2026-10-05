import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const headers = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> workJson(
    String id, {
    String postedAt = '2026-08-01T12:00:00.000Z',
    List<String> tags = const [],
    bool published = true,
    bool ai = false,
    String authorId = 'user_1',
    String? youtubePrivacyStatus,
  }) => {
    'workId': id,
    'authorId': authorId,
    'channelName': 'Author $authorId',
    'title': 'Work $id',
    'postedAt': postedAt,
    'viewCount': 10,
    'bookmarkCount': 0,
    'isShort': true,
    'tags': tags,
    'lockedTags': <String>[],
    'isNiarimPublished': published,
    'containsGenerativeAiImageOrVideo': ai,
    'youtubePrivacyStatus': ?youtubePrivacyStatus,
  };

  CommunityService make(
    Future<http.Response> Function(http.Request r) handler,
  ) => CommunityService(
    api: CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient(handler),
        tokenProvider: () async => 'ID',
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
      ),
    ),
  );
  http.Response ok(Object body) =>
      http.Response(jsonEncode(body), 200, headers: headers);

  test('A: failed tag edit rollback clobbers a concurrent successful AI flag change', () async {
    final tagReply = Completer<http.Response>();
    final service = make((r) async {
      final p = r.url.path;
      if (p == '/works/latest') return ok({'works': [workJson('w')]});
      if (p == '/works/w/tags') return tagReply.future;
      if (p == '/works/w' && r.method == 'PATCH') {
        return ok({'work': workJson('w', ai: true)});
      }
      return http.Response('{}', 404, headers: headers);
    });
    await service.refreshFromBackend();
    service.setCurrentUserId('user_1');
    await service.setHideGenerativeAiImageVideo(true);
    final tagEdit = service.addTag('w', 'x');
    await service.setAiImageVideoDisclosure('w', true);
    expect(service.byId('w')!.containsGenerativeAiImageOrVideo, isTrue);
    tagReply.complete(http.Response(
        jsonEncode({'error': 'conflict', 'code': 'TAG_UPDATE_CONFLICT'}), 409,
        headers: headers));
    expect(await tagEdit, isFalse);
    debugPrint('A: ai after rollback = ${service.byId('w')!.containsGenerativeAiImageOrVideo}; '
        'discoverable=${service.discoverableWorks.map((w) => w.id).toList()}');
    expect(service.byId('w')!.containsGenerativeAiImageOrVideo, isTrue,
        reason: 'server has the flag ON');
  });

  test('B: hiding an older work through the API + refresh (My Works path) leaves a stale public copy', () async {
    var hidden = false;
    final service = make((r) async {
      final p = r.url.path;
      if (p == '/works/latest') {
        return ok({'works': [workJson('new', postedAt: '2026-09-01T00:00:00.000Z', authorId: 'other')]});
      }
      if (p.startsWith('/ranking/')) {
        return ok({'works': [if (!hidden) workJson('old', postedAt: '2026-01-01T00:00:00.000Z')]});
      }
      if (p == '/works/old' && r.method == 'PATCH') {
        hidden = true;
        return ok({'work': workJson('old', postedAt: '2026-01-01T00:00:00.000Z', published: false)});
      }
      return http.Response('{}', 404, headers: headers);
    });
    await service.refreshFromBackend();
    await service.fetchRanking(RankingPeriod.all);
    expect(service.discoverableWorks.map((w) => w.id), contains('old'));
    // Exactly what CommunityMyWorksScreen._setVisibility does:
    await service.api!.updateWorkVisibility('old', isNiarimPublished: false);
    await service.refreshFromBackend();
    debugPrint('B: discoverable after hide = ${service.discoverableWorks.map((w) => w.id).toList()}');
    expect(service.discoverableWorks.map((w) => w.id), isNot(contains('old')));
  });

  test('C: YouTube-private own work upserted by AI flag change becomes discoverable and survives refresh', () async {
    final service = make((r) async {
      final p = r.url.path;
      if (p == '/works/latest') {
        return ok({'works': [workJson('new', postedAt: '2026-09-01T00:00:00.000Z', authorId: 'other')]});
      }
      if (p == '/works/priv' && r.method == 'PATCH') {
        return ok({'work': workJson('priv', postedAt: '2026-01-01T00:00:00.000Z', ai: true, youtubePrivacyStatus: 'private')});
      }
      return http.Response('{}', 404, headers: headers);
    });
    await service.refreshFromBackend();
    service.setCurrentUserId('user_1');
    await service.setAiImageVideoDisclosure('priv', true);
    await service.refreshFromBackend();
    debugPrint('C: discoverable = ${service.discoverableWorks.map((w) => w.id).toList()}');
    expect(service.discoverableWorks.map((w) => w.id), isNot(contains('priv')));
  });

  test('D: fabricated reposts of real backend works', () async {
    final service = make((r) async {
      if (r.url.path == '/works/latest') {
        return ok({'works': [
          for (var i = 0; i < 12; i++)
            workJson('w$i', postedAt: '2026-09-${(i + 1).toString().padLeft(2, '0')}T00:00:00.000Z', authorId: 'U$i'),
        ]});
      }
      return http.Response('{}', 404, headers: headers);
    });
    await service.refreshFromBackend();
    final counts = {for (final w in service.works) w.id: service.repostCountOf(w.id)};
    debugPrint('D: repost counts = $counts');
    for (var i = 0; i < 12; i++) {
      service.toggleFavoriteAuthor('U$i');
    }
    final reposts = service.favoriteAuthorFeed.where((e) => e.isRepost).map((e) => '${e.repostedByAuthorId}->${e.work.id}').toList();
    debugPrint('D: repost feed entries = $reposts');
    expect(counts.values.every((c) => c == 0), isTrue);
  });
}
