import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/screens/community/community_following_list_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _reply(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, String> _user(String id, String name) => {
  'niarimUserId': id,
  'channelName': name,
};

CommunityService _service(MockClient client) {
  final service = CommunityService(
    api: CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: client,
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
        tokenProvider: () async => 'test',
      ),
    ),
  );
  service.setCurrentUserId('self');
  return service;
}

Widget _app(
  CommunityService service, {
  Widget home = const CommunityFollowingListScreen(),
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: service),
    ChangeNotifierProvider(create: (_) => SettingsService()),
    ChangeNotifierProvider(create: (_) => PremiumService()),
  ],
  child: MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('refreshes only own follows at top without fetching the plaza', (
    tester,
  ) async {
    var callCount = 0;
    final paths = <String>[];
    var name = 'Alice before';
    final service = _service(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/users/self/following') {
          callCount++;
          expect(request.headers['authorization'], isNotNull);
          return _reply({
            'following': [_user('alice', name)],
          });
        }
        fail('Unexpected unrelated request: ${request.url.path}');
      }),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(callCount, 1);
    expect(find.text('Alice before'), findsOneWidget);

    name = 'Alice updated';
    await tester.fling(
      find.byKey(const Key('communityOwnFollowingPullRefresh')),
      const Offset(0, 420),
      950,
    );
    await tester.pumpAndSettle();
    expect(callCount, 2);
    expect(find.text('Alice updated'), findsOneWidget);
    expect(find.text('Alice before'), findsNothing);
    expect(paths, everyElement('/users/self/following'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a swipe started mid-list cannot refresh; next top swipe can', (
    tester,
  ) async {
    var calls = 0;
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/users/self/following') {
          calls++;
          return _reply({
            'following': [
              for (var i = 0; i < 40; i++) _user('user$i', 'User $i'),
            ],
          });
        }
        fail('Unexpected unrelated request: ${request.url.path}');
      }),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(calls, 1);

    final list = find.byKey(const Key('communityOwnFollowingList'));
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    final controller = tester.widget<ListView>(list).controller!;
    expect(controller.offset, greaterThan(100));

    await tester.drag(list, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(controller.offset, greaterThan(0));

    // Even if the drag reaches the top, it started away from the top.
    await tester.drag(list, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(calls, 1);

    await tester.fling(
      find.byKey(const Key('communityOwnFollowingPullRefresh')),
      const Offset(0, 420),
      950,
    );
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens author works without exposing their social lists', (
    tester,
  ) async {
    final requested = <String>[];
    final service = _service(
      MockClient((request) async {
        requested.add(request.url.path);
        switch (request.url.path) {
          case '/users/self/following':
            return _reply({
              'following': [_user('alice', 'Alice')],
            });
          case '/users/alice/works':
            return _reply({'works': <Object>[]});
          case '/users/alice/social-counts':
            return _reply({'followerCount': 4, 'followingCount': 3});
          default:
            fail('Unexpected request: ${request.url.path}');
        }
      }),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityFollowingAuthor_alice')));
    await tester.pumpAndSettle();

    final author = tester.widget<CommunityAuthorWorksScreen>(
      find.byType(CommunityAuthorWorksScreen),
    );
    expect(author.authorId, 'alice');
    expect(author.authorName, 'Alice');
    expect(
      find.byKey(const Key('communityAuthorFollowToggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('communityOwnFollowingListButton')),
      findsNothing,
    );
    expect(requested, isNot(contains('/users/alice/following')));
    expect(requested, isNot(contains('/users/alice/followers')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfollow and re-follow work directly in the private directory', (
    tester,
  ) async {
    var toggleCount = 0;
    final service = _service(
      MockClient((request) async {
        if (request.url.path == '/users/self/following') {
          return _reply({
            'following': [_user('alice', 'Alice')],
          });
        }
        if (request.url.path == '/users/alice/follow') {
          toggleCount++;
          return _reply({'following': toggleCount == 2});
        }
        if (request.url.path == '/users/alice/works') {
          return _reply({'works': <Object>[]});
        }
        if (request.url.path == '/users/alice/reposts') {
          return _reply({'reposts': <Object>[]});
        }
        if (request.url.path == '/users/self/reposts') {
          return _reply({'reposts': <Object>[]});
        }
        fail('Unexpected request: ${request.url.path}');
      }),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityFollowingUnfollow_alice')));
    await tester.pumpAndSettle();

    expect(toggleCount, 1);
    expect(service.favoriteAuthorIds, isEmpty);
    expect(
      find.byKey(const Key('communityFollowingFollow_alice')),
      findsOneWidget,
    );
    expect(find.text('最近フォローを解除したユーザー'), findsOneWidget);

    await tester.tap(find.byKey(const Key('communityFollowingFollow_alice')));
    await tester.pumpAndSettle();
    expect(toggleCount, 2);
    expect(service.favoriteAuthorIds, contains('alice'));
    expect(
      find.byKey(const Key('communityFollowingUnfollow_alice')),
      findsOneWidget,
    );
    expect(find.text('最近フォローを解除したユーザー'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own profile following count opens private following list', (
    tester,
  ) async {
    final requested = <String>[];
    final service = _service(
      MockClient((request) async {
        requested.add(request.url.path);
        switch (request.url.path) {
          case '/users/self/works':
            return _reply({'works': <Object>[]});
          case '/users/self/social-counts':
            return _reply({'followerCount': 2, 'followingCount': 1});
          case '/users/self/following':
            return _reply({
              'following': [_user('alice', 'Alice')],
            });
          case '/users/alice/follow':
            return _reply({'following': false});
          case '/users/self/reposts':
            return _reply({'reposts': <Object>[]});
          default:
            fail('Unexpected request: ${request.url.path}');
        }
      }),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _app(
        service,
        home: const CommunityAuthorWorksScreen(
          authorId: 'self',
          authorName: 'Me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final count = find.byKey(const Key('communityOwnFollowingCountButton'));
    expect(count, findsOneWidget);
    await tester.tap(count);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFollowingListScreen), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(
      requested.where((path) => path == '/users/self/following').length,
      1,
    );

    await tester.tap(find.byKey(const Key('communityFollowingUnfollow_alice')));
    await tester.pumpAndSettle();
    expect(service.favoriteAuthorIds, isEmpty);

    // Returning to the profile updates the same numeric control immediately.
    Navigator.of(tester.element(find.byType(CommunityFollowingListScreen)))
        .pop();
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityAuthorWorksScreen)),
    )!;
    expect(find.text(l10n.communityAuthorFollowingCount(0)), findsOneWidget);
    expect(
      find.byKey(const Key('communityOwnFollowingCountButton')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('other profiles show only non-tappable follow counts', (
    tester,
  ) async {
    final requested = <String>[];
    final service = _service(
      MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.path == '/users/alice/works') {
          return _reply({'works': <Object>[]});
        }
        if (request.url.path == '/users/alice/social-counts') {
          return _reply({'followerCount': 9, 'followingCount': 4});
        }
        fail('Unexpected request: ${request.url.path}');
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      _app(
        service,
        home: const CommunityAuthorWorksScreen(
          authorId: 'alice',
          authorName: 'Alice',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityAuthorWorksScreen)),
    )!;
    expect(find.text(l10n.communityAuthorFollowingCount(4)), findsOneWidget);
    expect(
      find.byKey(const Key('communityOwnFollowingCountButton')),
      findsNothing,
    );
    expect(requested, isNot(contains('/users/alice/following')));
    expect(requested, isNot(contains('/users/alice/followers')));
    expect(tester.takeException(), isNull);
  });
}
