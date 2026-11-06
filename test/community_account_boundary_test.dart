import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_models.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> work(String id, String author, {bool hidden = false}) => {
  'workId': id,
  'authorId': author,
  'title': 'Isolated fixture $id',
  'postedAt': '2026-10-21T00:00:00Z',
  'isNiarimPublished': !hidden,
};
http.Response jsonReply(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
CommunityService serviceFor(MockClient client) => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: client,
      tokenProvider: () async => 'isolated-fixture-token',
      maxGetRetries: 0,
    ),
  ),
);

class HeldReply {
  final started = Completer<void>();
  final reply = Completer<http.Response>();
  Future<http.Response> call(http.Request request) {
    if (!started.isCompleted) started.complete();
    return reply.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'late owner response cannot restore the previous account or hidden works',
    () async {
      final held = HeldReply();
      final service = serviceFor(MockClient(held.call));
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      final pending = service.loadOwnWorks(accountKey: 'old-account');
      await held.started.future;
      service.forgetOwner();
      service.setCurrentUserId('new-owner');
      held.reply.complete(
        jsonReply({
          'authorId': 'old-owner',
          'works': [work('old-private', 'old-owner', hidden: true)],
        }),
      );
      expect(await pending, isNull);
      expect(service.currentUserId, 'new-owner');
      expect(service.byId('old-private'), isNull);
    },
  );
  test(
    'late social response cannot reveal the previous account bookmarks',
    () async {
      final held = HeldReply();
      final service = serviceFor(
        MockClient((request) async {
          if (request.url.path.endsWith('/bookmarks')) {
            return held.call(request);
          }
          if (request.url.path.endsWith('/following')) {
            return jsonReply({'following': []});
          }
          return jsonReply({'reposts': []});
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('old-owner');
      final pending = service.loadSocial();
      await held.started.future;
      service.forgetOwner();
      service.setCurrentUserId('new-owner');
      held.reply.complete(
        jsonReply({
          'works': [work('old-bookmark', 'other')],
        }),
      );
      expect(await pending, isFalse);
      expect(service.bookmarkedIds, isEmpty);
      expect(service.byId('old-bookmark'), isNull);
    },
  );
  test('late bookmark toggle cannot restore state after signing out', () async {
    final held = HeldReply();
    final service = serviceFor(MockClient(held.call));
    addTearDown(service.dispose);
    await service.contentFiltersReady;
    service.setCurrentUserId('old-owner');
    final pending = service.toggleBookmark('known');
    await held.started.future;
    service.forgetOwner();
    held.reply.complete(jsonReply({'bookmarked': true}));
    expect(await pending, isFalse);
    expect(service.currentUserId, isNull);
    expect(service.bookmarkedIds, isEmpty);
  });
  test(
    'late refusal cannot undo the new account bookmark or replace its error',
    () async {
      final held = HeldReply();
      var calls = 0;
      final service = serviceFor(
        MockClient(
          (r) => calls++ == 0
              ? held.call(r)
              : Future.value(jsonReply({'bookmarked': true})),
        ),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('old');
      final pending = service.toggleBookmark('known');
      await held.started.future;
      service.forgetOwner();
      service.setCurrentUserId('new');
      expect(await service.toggleBookmark('known'), isTrue);
      held.reply.complete(jsonReply({'error': 'down'}, status: 500));
      expect(await pending, isFalse);
      expect(service.isBookmarked('known'), isTrue);
      expect(service.lastError, isNull);
    },
  );
  for (final ai in [true, false]) {
    test(
      'late ${ai ? 'AI disclosure' : 'visibility'} response cannot restore old private rows',
      () async {
        final held = HeldReply();
        final service = serviceFor(MockClient(held.call));
        addTearDown(service.dispose);
        await service.contentFiltersReady;
        service.setCurrentUserId('old-owner');
        service.applyServerWork(
          ApiWork.fromJson(
            work('private', 'old-owner', hidden: true),
          ).toCommunityWork(),
        );
        final pending = ai
            ? service.setAiImageVideoDisclosure('private', true)
            : service.setNiarimVisibility('private', true);
        final cancelled = expectLater(
          pending,
          throwsA(isA<CommunityAccountChangedException>()),
        );
        await held.started.future;
        service.forgetOwner();
        service.setCurrentUserId('new-owner');
        held.reply.complete(
          jsonReply({'work': work('private', 'old-owner', hidden: true)}),
        );
        await cancelled;
        expect(service.byId('private'), isNull);
        expect(service.currentUserId, 'new-owner');
      },
    );
  }
  test(
    'signing out removes private copies confirmed by an owner author page',
    () async {
      final service = serviceFor(
        MockClient(
          (r) async => jsonReply({
            'works': [work('private', 'old-owner', hidden: true)],
          }),
        ),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('old-owner');
      expect(await service.refreshAuthorWorks('old-owner'), isTrue);
      expect(service.byId('private'), isNotNull);
      service.forgetOwner();
      expect(service.byId('private'), isNull);
    },
  );
  test(
    'a following response arriving after sign-out leaves no old feed',
    () async {
      final held = HeldReply();
      final service = serviceFor(
        MockClient((r) async {
          final p = r.url.path;
          if (p.endsWith('/bookmarks')) return jsonReply({'works': []});
          if (p.endsWith('/following')) {
            return jsonReply({
              'following': [
                {'niarimUserId': 'fav'},
              ],
            });
          }
          if (p.endsWith('/works')) {
            return jsonReply({
              'works': [work('followed', 'fav')],
            });
          }
          if (p == '/users/old-owner/reposts') return held.call(r);
          return jsonReply({'reposts': []});
        }),
      );
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('old-owner');
      final pending = service.loadSocial();
      await held.started.future;
      service.forgetOwner();
      service.setCurrentUserId('new');
      held.reply.complete(jsonReply({'reposts': []}));
      expect(await pending, isFalse);
      expect(service.favoriteAuthorIds, isEmpty);
      expect(service.favoriteAuthorFeed, isEmpty);
      expect(service.byId('followed'), isNull);
    },
  );
  test(
    'disposing an unknown owner while a request is pending cancels it',
    () async {
      final held = HeldReply();
      final service = serviceFor(MockClient(held.call));
      await service.contentFiltersReady;
      final pending = service.loadOwnWorks();
      await held.started.future;
      service.dispose();
      held.reply.complete(jsonReply({'authorId': 'old-owner', 'works': []}));
      expect(await pending, isNull);
    },
  );
  for (final ranking in [false, true]) {
    test(
      'late ${ranking ? 'ranking' : 'latest'} response is ignored after disposal',
      () async {
        final held = HeldReply();
        final service = serviceFor(MockClient(held.call));
        await service.contentFiltersReady;
        final pending = ranking
            ? service.fetchRanking(RankingPeriod.week)
            : service.refreshFromBackend();
        await held.started.future;
        service.dispose();
        held.reply.complete(
          jsonReply({
            'period': 'weekly',
            'works': [work('late', 'other')],
          }),
        );
        await pending;
        expect(service.byId('late'), isNull);
      },
    );
  }
  test(
    'signing back into the same owner does not revive an earlier request',
    () async {
      final held = HeldReply();
      final service = serviceFor(MockClient(held.call));
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('same');
      final pending = service.loadOwnWorks();
      await held.started.future;
      service.forgetOwner();
      service.setCurrentUserId('same');
      held.reply.complete(
        jsonReply({
          'authorId': 'same',
          'works': [work('old-private', 'same', hidden: true)],
        }),
      );
      expect(await pending, isNull);
      expect(service.byId('old-private'), isNull);
    },
  );
  test(
    'a pending owner author page cannot insert private rows after a switch',
    () async {
      final held = HeldReply();
      final service = serviceFor(MockClient(held.call));
      addTearDown(service.dispose);
      await service.contentFiltersReady;
      service.setCurrentUserId('old');
      final pending = service.refreshAuthorWorks('old');
      await held.started.future;
      service.setCurrentUserId('new');
      held.reply.complete(
        jsonReply({
          'works': [work('late-private', 'old', hidden: true)],
        }),
      );
      expect(await pending, isFalse);
      expect(service.byId('late-private'), isNull);
      expect(service.currentUserId, 'new');
    },
  );
}
