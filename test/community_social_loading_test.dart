import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response reply(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status);
CommunityService serviceFor(MockClient client) => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: client,
      tokenProvider: () async => 'fixture',
      maxGetRetries: 0,
    ),
  ),
);
final work = {
  'workId': 'saved',
  'authorId': 'other',
  'title': 'Saved fixture',
  'postedAt': '2026-10-22T00:00:00Z',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'concurrent social reloads share one request and loading lifecycle',
    () async {
      final held = Completer<http.Response>();
      final started = Completer<void>();
      var calls = 0;
      final service = serviceFor(
        MockClient((r) async {
          if (r.url.path.endsWith('/bookmarks')) {
            calls++;
            started.complete();
            return held.future;
          }
          if (r.url.path.endsWith('/following')) {
            return reply({'following': []});
          }
          return reply({'reposts': []});
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('owner');
      final first = service.loadSocial();
      await started.future;
      final second = service.loadSocial();
      expect(service.isSocialLoading, isTrue);
      expect(service.hasLoadedSocial, isFalse);
      expect(calls, 1);
      held.complete(reply({'works': []}));
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(calls, 1);
      expect(service.isSocialLoading, isFalse);
      expect(service.hasLoadedSocial, isTrue);
      expect(service.socialError, isNull);
    },
  );
  test(
    'failed refresh keeps cached bookmarks and successful retry clears its error',
    () async {
      var fail = false;
      final service = serviceFor(
        MockClient((r) async {
          if (r.url.path.endsWith('/bookmarks')) {
            return fail
                ? reply({'error': 'unavailable'}, status: 503)
                : reply({
                    'works': [work],
                  });
          }
          if (r.url.path.endsWith('/following')) {
            return reply({'following': []});
          }
          return reply({'reposts': []});
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('owner');
      expect(await service.loadSocial(), isTrue);
      fail = true;
      expect(await service.loadSocial(), isFalse);
      expect(service.bookmarkedIds, {'saved'});
      expect(service.bookmarkedWorksForViewer.single.id, 'saved');
      expect(service.socialError, isNotNull);
      expect(service.isSocialLoading, isFalse);
      fail = false;
      expect(await service.loadSocial(), isTrue);
      expect(service.socialError, isNull);
      expect(service.bookmarkedIds, {'saved'});
    },
  );
  test(
    'old account failure cannot end the new account loading state',
    () async {
      final old = Completer<http.Response>(), next = Completer<http.Response>();
      final started = <String>[];
      final service = serviceFor(
        MockClient((r) async {
          if (r.url.path.endsWith('/bookmarks')) {
            started.add(r.url.path);
            return r.url.path.contains('/old/') ? old.future : next.future;
          }
          if (r.url.path.endsWith('/following')) {
            return reply({'following': []});
          }
          return reply({'reposts': []});
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('old');
      final first = service.loadSocial();
      await Future<void>.delayed(Duration.zero);
      expect(started, hasLength(1));
      service.forgetOwner();
      service.setCurrentUserId('new');
      final second = service.loadSocial();
      await Future<void>.delayed(Duration.zero);
      old.complete(reply({'error': 'unavailable'}, status: 503));
      expect(await first, isFalse);
      expect(service.isSocialLoading, isTrue);
      expect(service.hasLoadedSocial, isFalse);
      expect(service.socialError, isNull);
      next.complete(reply({'works': []}));
      expect(await second, isTrue);
      expect(service.isSocialLoading, isFalse);
    },
  );
  test(
    'following-feed failure does not misreport successfully loaded bookmarks',
    () async {
      final service = serviceFor(
        MockClient((r) async {
          if (r.url.path.endsWith('/bookmarks')) {
            return reply({
              'works': [work],
            });
          }
          if (r.url.path.endsWith('/following')) {
            return reply({'following': []});
          }
          return reply({'error': 'feed unavailable'}, status: 503);
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('owner');
      expect(await service.loadSocial(), isFalse);
      expect(service.lastError, isNotNull);
      expect(service.hasLoadedSocial, isTrue);
      expect(service.socialError, isNull);
      expect(service.bookmarkedIds, {'saved'});
    },
  );
}
