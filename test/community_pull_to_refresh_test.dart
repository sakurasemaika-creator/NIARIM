import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// With a backend, pulling down on the plaza takes the works from the server
/// again, so a viewer sees a change the poster made after posting: here the
/// 「AI画像・AI動画使用」 declaration turned on, which the viewer hides.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const headers = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> workJson({required bool ai}) => {
    'workId': 'vid00000001',
    'authorId': 'poster',
    'channelName': 'Poster',
    'title': 'Pulled work',
    'postedAt': '2026-08-01T12:00:00.000Z',
    'youtubeUrl': 'https://www.youtube.com/watch?v=vid00000001',
    'thumbnailUrl': 'https://example.invalid/t.jpg',
    'viewCount': 10,
    'likeCount': 1,
    'commentCount': 0,
    'bookmarkCount': 0,
    'repostCount': 0,
    'isShort': false,
    'tags': <String>[],
    'lockedTags': <String>[],
    'isNiarimPublished': true,
    'containsGenerativeAiImageOrVideo': ai,
  };

  testWidgets('pulling down shows the poster\'s later AI declaration', (
    tester,
  ) async {
    var posterDeclaredAi = false;
    var latestFetches = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      Object body;
      if (path == '/works/latest') {
        latestFetches++;
        body = {
          'works': [workJson(ai: posterDeclaredAi)],
        };
      } else if (path.startsWith('/ranking/')) {
        body = {
          'period': path.split('/').last,
          'works': [workJson(ai: posterDeclaredAi)],
        };
      } else {
        body = {'works': <Object>[]};
      }
      return http.Response(jsonEncode(body), 200, headers: headers);
    });
    final service = CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: client,
          tokenProvider: () async => null,
          maxGetRetries: 0,
          retryBackoff: Duration.zero,
        ),
      ),
    );
    await service.setHideGenerativeAiImageVideo(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(latestFetches, 1);
    expect(find.text('Pulled work'), findsOneWidget);

    // The poster declares it afterwards; nothing changes until the viewer
    // fetches again.
    posterDeclaredAi = true;
    await tester.pump();
    expect(find.text('Pulled work'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('communityPullToRefresh')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(latestFetches, 2);
    expect(service.byId('vid00000001')!.containsGenerativeAiImageOrVideo, true);
    expect(find.text('Pulled work'), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(l10n.communityEmptyState), findsOneWidget);

    // An empty tab can still be pulled down; the declaration taken back
    // brings the work back.
    posterDeclaredAi = false;
    await tester.fling(
      find.byKey(const Key('communityPullToRefresh')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(latestFetches, 3);
    expect(find.text('Pulled work'), findsOneWidget);

    // The ranking tab refreshes the same way.
    await tester.tap(find.text(l10n.communityTabRanking));
    await tester.pumpAndSettle();
    expect(find.text('Pulled work'), findsOneWidget);
    posterDeclaredAi = true;
    await tester.fling(
      find.byKey(const Key('communityPullToRefresh')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pulled work'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a backend there is nothing to pull', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CommunityService()),
          ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityPullToRefresh')), findsNothing);
  });
}
