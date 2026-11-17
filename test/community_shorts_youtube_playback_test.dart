import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
        ColoredBox(key: Key('yt-embedded-$id-$playing'), color: Colors.black);
  });
  tearDown(() => CommunityYoutubePlayer.debugPlayerBuilder = null);

  testWidgets(
    'shorts respond to wheel and keys, and pause under another route',
    (tester) async {
      final works = [
        _work('abcdefghijk', 'First'),
        _work('lmnopqrstuv', 'Second'),
        _work('01234567890', 'Third'),
      ];
      final community = CommunityService();
      for (final work in works) {
        community.applyServerWork(work);
      }
      addTearDown(community.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: community,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CommunityShortsScreen(
              works: works,
              bookmarkedIds: const {},
              onToggleBookmark: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder player(int index, bool playing, {bool skipOffstage = true}) =>
          find.byKey(
            Key('yt-embedded-${works[index].id}-$playing'),
            skipOffstage: skipOffstage,
          );
      expect(player(0, true), findsOneWidget);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: tester.getCenter(player(0, true)),
          scrollDelta: const Offset(0, 35),
        ),
      );
      await tester.pumpAndSettle();
      expect(player(1, true), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(player(2, true), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(player(1, true), findsOneWidget);

      final navigator = Navigator.of(
        tester.element(find.byType(CommunityShortsScreen)),
      );
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(player(1, false, skipOffstage: false), findsOneWidget);
      expect(player(1, true, skipOffstage: false), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(player(1, true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Shorts loads only a freshly approved active YouTube video', (
    tester,
  ) async {
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
      return http.Response(
        jsonEncode({'status': status}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final community = CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: client,
          maxGetRetries: 0,
          retryBackoff: Duration.zero,
        ),
      ),
    );
    community.applyServerWork(first);
    community.applyServerWork(second);
    await tester.pumpWidget(
      ChangeNotifierProvider<CommunityService>.value(
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
      ),
    );
    await tester.pumpAndSettle();
    expect(checks, contains('/works/$firstId/playback-status'));
    expect(find.byKey(const Key('yt-embedded-$firstId-true')), findsOneWidget);
    expect(find.byKey(const Key('yt-embedded-$secondId-true')), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(checks, contains('/works/$secondId/playback-status'));
    expect(find.text('Now private second'), findsNothing);
    expect(find.byKey(const Key('yt-embedded-$secondId-true')), findsNothing);
    expect(
      find.byKey(const Key('communityPlaybackStatusPanel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    community.dispose();
  });
}
