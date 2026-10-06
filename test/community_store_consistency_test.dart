import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The community store stays consistent with the server: a refused edit
/// undoes only itself, works the server stops confirming leave, the poster's
/// own works stay until they sign out, and nothing is invented for real
/// users.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const headers = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> workJson(
    String id, {
    String authorId = 'user_1',
    String postedAt = '2026-08-01T12:00:00.000Z',
    List<String> tags = const [],
    bool published = true,
    bool ai = false,
    String? youtube,
  }) => {
    'workId': id,
    'authorId': authorId,
    'channelName': 'Author',
    'title': 'Work $id',
    'postedAt': postedAt,
    'youtubeUrl': 'https://www.youtube.com/watch?v=$id',
    'thumbnailUrl': 'https://example.invalid/t.jpg',
    'viewCount': 10,
    'likeCount': 1,
    'commentCount': 0,
    'bookmarkCount': 0,
    'repostCount': 0,
    'isShort': true,
    'tags': tags,
    'lockedTags': <String>[],
    'isNiarimPublished': published,
    'containsGenerativeAiImageOrVideo': ai,
    'youtubePrivacyStatus': ?youtube,
  };

  /// A fake backend whose lists can change between calls and whose PATCH
  /// replies can be held back.
  ({
    CommunityService service,
    List<http.Request> requests,
    Map<String, List<Map<String, dynamic>>> lists,
    Map<String, Future<http.Response> Function(http.Request)> patches,
  })
  backend() {
    final requests = <http.Request>[];
    final lists = <String, List<Map<String, dynamic>>>{
      'latest': [],
      'ranking': [],
      'mine': [],
    };
    final patches = <String, Future<http.Response> Function(http.Request)>{};
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: headers);
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/works/latest') return json({'works': lists['latest']});
      if (path.startsWith('/ranking/')) {
        return json({'period': 'all', 'works': lists['ranking']});
      }
      if (path == '/me/works') {
        return json({'authorId': 'user_1', 'works': lists['mine']});
      }
      final patch = patches[path];
      if (request.method == 'PATCH' && patch != null) return patch(request);
      return json({'error': 'not found'}, 404);
    });
    final api = CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: client,
        tokenProvider: () async => 'ID_TOKEN',
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
      ),
    );
    return (
      service: CommunityService(api: api),
      requests: requests,
      lists: lists,
      patches: patches,
    );
  }

  http.Response reply(Map<String, dynamic> work) =>
      http.Response(jsonEncode({'work': work}), 200, headers: headers);

  test('a refused tag edit undoes only itself, keeping the AI flag set '
      'meanwhile', () async {
    final (:service, requests: _, :lists, :patches) = backend();
    lists['latest'] = [workJson('w')];
    await service.refreshFromBackend();
    service.setCurrentUserId('user_1');
    await service.setHideGenerativeAiImageVideo(true);

    final tagReply = Completer<http.Response>();
    patches['/works/w/tags'] = (_) => tagReply.future;
    patches['/works/w'] = (_) async => reply(workJson('w', ai: true));

    final tagEdit = service.addTag('w', 'x');
    await service.setAiImageVideoDisclosure('w', true);
    tagReply.complete(
      http.Response(
        jsonEncode({'error': 'conflict', 'code': 'TAG_UPDATE_CONFLICT'}),
        409,
        headers: headers,
      ),
    );
    expect(await tagEdit, isFalse);
    final work = service.byId('w')!;
    expect(work.tags, isNot(contains('x')), reason: 'its own change undone');
    expect(work.containsGenerativeAiImageOrVideo, isTrue);
    expect(service.discoverableWorks, isEmpty, reason: 'still hidden as AI');
  });

  test(
    'an edit with nothing to change sends nothing and reports null',
    () async {
      final (:service, :requests, :lists, patches: _) = backend();
      lists['latest'] = [
        workJson('w', tags: ['t']),
      ];
      await service.refreshFromBackend();
      expect(await service.addTag('w', 't'), isNull);
      expect(await service.removeTag('w', 'absent'), isNull);
      expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    },
  );

  test('a ranked work the server stops confirming leaves the store', () async {
    final (:service, requests: _, :lists, patches: _) = backend();
    lists['latest'] = [workJson('new', postedAt: '2026-09-01T00:00:00.000Z')];
    lists['ranking'] = [workJson('old', postedAt: '2026-01-01T00:00:00.000Z')];
    await service.refreshFromBackend();
    await service.fetchRanking(RankingPeriod.all);
    expect(service.discoverableWorks.map((w) => w.id), ['new', 'old']);

    // Hidden by its poster elsewhere: no list returns it any more.
    lists['ranking'] = [];
    await service.fetchRanking(RankingPeriod.all);
    await service.refreshFromBackend();
    expect(service.byId('old'), isNull);
    expect(service.discoverableWorks.map((w) => w.id), ['new']);
  });

  test(
    'the ranking keeps the server\'s order and follows the filters',
    () async {
      final (:service, requests: _, :lists, patches: _) = backend();
      lists['ranking'] = [
        workJson('second', postedAt: '2026-09-02T00:00:00.000Z'),
        workJson('first', postedAt: '2026-09-03T00:00:00.000Z', tags: ['x']),
        workJson('third', postedAt: '2026-09-01T00:00:00.000Z'),
      ];
      await service.fetchRanking(RankingPeriod.week);
      expect(service.rankedWorks.map((w) => w.id), [
        'second',
        'first',
        'third',
      ]);
      await service.setMutedTags(['x']);
      expect(service.rankedWorks.map((w) => w.id), ['second', 'third']);
    },
  );

  test('the poster\'s own works stay, hidden ones included, until they sign '
      'out', () async {
    final (:service, requests: _, :lists, patches: _) = backend();
    lists['mine'] = [
      workJson('hidden', published: false),
      workJson('private', youtube: 'private'),
    ];
    await service.loadOwnWorks();
    expect(service.currentUserId, 'user_1');
    await service.refreshFromBackend();
    expect(service.byId('hidden'), isNotNull);
    expect(service.isOwnWork(service.byId('hidden')!), isTrue);
    expect(
      service.discoverableWorks,
      isEmpty,
      reason: 'hidden and YouTube-private works are not public',
    );

    service.forgetOwner();
    expect(service.currentUserId, isNull);
    expect(service.byId('hidden'), isNull);
    expect(service.byId('private'), isNull);
  });

  test('with a backend no demo reposts or follow notifications are made '
      'up', () async {
    final (:service, requests: _, :lists, patches: _) = backend();
    lists['latest'] = [
      for (var i = 0; i < 12; i++) workJson('w$i', authorId: 'author_${i % 4}'),
    ];
    await service.refreshFromBackend();
    expect(
      [for (var i = 0; i < 12; i++) service.repostCountOf('w$i')],
      [for (var i = 0; i < 12; i++) 0],
    );
    expect(service.followNotifications, isEmpty);
  });
}
