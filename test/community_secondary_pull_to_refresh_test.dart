import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/screens/community/community_my_works_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  const _Account(this.id);
  @override
  final String id;
  @override
  String get email => '$id@example.invalid';
  @override
  String get displayName => 'Author $id';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends GoogleAuthService {
  _Auth(String id) : _current = _Account(id);
  final GoogleSignInAccount _current;
  @override
  GoogleSignInAccount? get account => _current;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => true;
}

http.Response _reply(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> _work(String owner, String title) => {
  'workId': 'video00001',
  'authorId': owner,
  'channelName': owner,
  'title': title,
  'postedAt': '2026-11-01T12:00:00Z',
  'youtubeUrl': 'https://www.youtube.com/watch?v=video00001',
  'thumbnailUrl': 'https://example.invalid/thumb.jpg',
  'viewCount': 1,
  'bookmarkCount': 0,
  'isNiarimPublished': true,
  'tags': <String>[],
  'lockedTags': <String>[],
};

CommunityService _service(MockClient client) => CommunityService(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('author page refreshes only that author at the top', (tester) async {
    var title = 'Original author work';
    var authorFetches = 0;
    final service = _service(MockClient((request) async {
      if (request.url.path == '/users/other/works') {
        authorFetches++;
        return _reply({'works': [_work('other', title)]});
      }
      if (request.url.path == '/users/other/social-counts') {
        return _reply({'followerCount': 1, 'followingCount': 2});
      }
      return _reply({});
    }));
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: service)],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityAuthorWorksScreen(
            authorId: 'other',
            authorName: 'Other',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(authorFetches, 1);
    expect(find.text(title), findsOneWidget);

    title = 'Updated author work';
    await tester.fling(
      find.byKey(const Key('communityAuthorWorksPullRefresh')),
      const Offset(0, 420),
      950,
    );
    await tester.pumpAndSettle();
    expect(authorFetches, 2);
    expect(find.text(title), findsOneWidget);
    expect(find.text('Other'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner bookmarks refresh does not request follows', (tester) async {
    var title = 'Initial bookmark';
    var bookmarkFetches = 0;
    var followFetches = 0;
    final service = _service(MockClient((request) async {
      if (request.url.path == '/users/self/bookmarks') {
        bookmarkFetches++;
        return _reply({'works': [_work('other', title)]});
      }
      if (request.url.path == '/users/self/following') {
        followFetches++;
        return _reply({'following': <Object>[]});
      }
      if (request.url.path == '/users/self/works') {
        return _reply({'works': <Object>[]});
      }
      if (request.url.path == '/users/self/social-counts') {
        return _reply({'followerCount': 0, 'followingCount': 0});
      }
      return _reply({});
    }));
    service.setCurrentUserId('self');
    addTearDown(service.dispose);
    await service.refreshViewerBookmarks();
    expect(bookmarkFetches, 1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: service)],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityAuthorWorksScreen(
            authorId: 'self',
            authorName: 'Self',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CommunityAuthorWorksScreen)),
    )!;
    await tester.tap(find.text(l10n.communityAuthorTabBookmarks));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);

    title = 'Updated bookmark';
    await tester.fling(
      find.byKey(const Key('communityAuthorBookmarksPullRefresh')),
      const Offset(0, 420),
      950,
    );
    await tester.pumpAndSettle();
    expect(bookmarkFetches, 2);
    expect(followFetches, 0);
    expect(find.text(title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner management refreshes its own rows only', (tester) async {
    final auth = _Auth('self');
    var title = 'Original owner title';
    var ownerFetches = 0;
    final service = _service(MockClient((request) async {
      if (request.url.path == '/me/works') {
        ownerFetches++;
        return _reply({
          'authorId': 'self',
          'works': [_work('self', title)],
        });
      }
      return _reply({});
    }));
    addTearDown(auth.dispose);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => PremiumService()),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityMyWorksScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ownerFetches, 1);
    expect(find.text(title), findsOneWidget);

    title = 'Refreshed owner title';
    await tester.fling(
      find.byKey(const Key('communityMyWorksPullRefresh')),
      const Offset(0, 420),
      950,
    );
    await tester.pumpAndSettle();
    expect(ownerFetches, 2);
    expect(find.text(title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
