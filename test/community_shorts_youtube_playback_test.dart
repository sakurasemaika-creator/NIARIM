import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/screens/community/widgets/community_youtube_player.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';

CommunityWork _work(String id, String title) => CommunityWork(
  id: id,
  title: title,
  authorId: 'user-creator',
  authorName: 'Creator',
  viewCount: 1,
  likeCount: 0,
  bookmarkCount: 0,
  postedAt: DateTime.utc(2026, 11, 10),
  durationSeconds: 30,
  thumbnailColorIndex: 0,
  isShort: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommunityYoutubePlayer.debugPlayerBuilder = (context, id, playing) =>
        ColoredBox(
          key: Key('yt-embedded-$id-$playing'),
          color: Colors.black,
        );
  });
  tearDown(() => CommunityYoutubePlayer.debugPlayerBuilder = null);

  testWidgets('Shorts loads only a freshly approved active YouTube video',
      (tester) async {
    const firstId = 'abcdefghijk';
    const secondId = 'lmnopqrstuv';
    final first = _work(firstId, 'Public first');
    final second = _work(secondId, 'Now private second');
    final checks = <String>[];
    final client = MockClient((request) async {
      checks.add(request.url.path);
      final status = request.url.path.endsWith('/$secondId/playback-status')
          ? 'private'
          : 'available';
      return http.Response(jsonEncode({'status': status}), 200,
          headers: {'content-type': 'application/json'});
    });
    final community = CommunityService(
      api: CommunityApi(NiarimApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: client,
        maxGetRetries: 0,
        retryBackoff: Duration.zero,
      )),
    );
    community.applyServerWork(first);
    community.applyServerWork(second);
    await tester.pumpWidget(ChangeNotifierProvider<CommunityService>.value(
      value: community,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CommunityShortsScreen(
          works: [first, second],
          bookmarkedIds: const <String>{},
          onToggleBookmark: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(checks, contains('/works/$firstId/playback-status'));
    expect(find.byKey(const Key('yt-embedded-$firstId-true')), findsOneWidget);
    expect(find.byKey(const Key('yt-embedded-$secondId-true')), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(checks, contains('/works/$secondId/playback-status'));
    expect(find.text('Now private second'), findsNothing);
    expect(find.byKey(const Key('yt-embedded-$secondId-true')), findsNothing);
    expect(find.byKey(const Key('communityPlaybackStatusPanel')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    community.dispose();
  });
}
