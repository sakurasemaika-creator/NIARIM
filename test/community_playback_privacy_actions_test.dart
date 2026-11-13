import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/screens/community/widgets/community_youtube_player.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/settings_service.dart';

const _id = 'abcdefghijk';
const _secretTitle = 'Private artwork must not be shown';

CommunityWork _work() => CommunityWork(
  id: _id,
  title: _secretTitle,
  authorId: 'different-author',
  authorName: 'Hidden author',
  viewCount: 0,
  likeCount: 0,
  bookmarkCount: 1,
  durationSeconds: 40,
  postedAt: DateTime.utc(2026, 11, 9),
  thumbnailColorIndex: 3,
);

Widget _host({
  required CommunityService community,
  required CommunityPreviewService preview,
  required Widget home,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<CommunityService>.value(value: community),
    ChangeNotifierProvider<CommunityPreviewService>.value(value: preview),
    ChangeNotifierProvider(create: (_) => GoogleAuthService()),
    ChangeNotifierProvider(create: (_) => SettingsService()),
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommunityYoutubePlayer.debugPlayerBuilder = (context, id, playing) =>
        Container(key: Key('mockYouTube-$id-$playing'), color: Colors.black);
  });
  tearDown(() => CommunityYoutubePlayer.debugPlayerBuilder = null);

  for (final blockedStatus in [
    'private',
    'deleted',
    'unavailable',
    'unknown',
  ]) {
    testWidgets(
      'preview cannot open details after video becomes $blockedStatus',
      (tester) async {
        var state = 'available';
        var checks = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/works/$_id/playback-status') {
            checks++;
            return http.Response(
              jsonEncode({'status': state}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
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
        final preview = CommunityPreviewService();
        final work = _work();
        community.applyServerWork(work);
        preview.show(work);
        await tester.pumpWidget(
          _host(
            community: community,
            preview: preview,
            home: const Scaffold(
              body: Stack(children: [CommunityFloatingPreview()]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(checks, greaterThanOrEqualTo(1));
        expect(
          find.byKey(const Key('communityPreviewDetails')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mockYouTube-$_id-true')), findsOneWidget);

        // The public data was cached when the preview was opened.
        // Publication is revoked before the user presses Details.
        state = blockedStatus;
        await tester.tap(find.byKey(const Key('communityPreviewDetails')));
        await tester.pumpAndSettle();
        expect(checks, greaterThanOrEqualTo(2));
        expect(preview.work?.id, _id);
        expect(find.byType(CommunityWorkDetailScreen), findsNothing);
        expect(
          find.byKey(const Key('communityPlaybackStatusPanel')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mockYouTube-$_id-true')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        preview.dispose();
        community.dispose();
      },
    );
  }

  testWidgets('resuming a paused preview rechecks visibility', (tester) async {
    var state = 'available';
    var checks = 0;
    final client = MockClient((request) async {
      checks++;
      return http.Response(
        jsonEncode({'status': state}),
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
    final preview = CommunityPreviewService();
    final work = _work();
    community.applyServerWork(work);
    preview.show(work);
    await tester.pumpWidget(
      _host(
        community: community,
        preview: preview,
        home: const Scaffold(
          body: Stack(children: [CommunityFloatingPreview()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final play = find.byKey(const Key('communityPreviewPlay'));
    await tester.tap(play); // Pause should remain possible without an API call.
    await tester.pump();
    final before = checks;
    state = 'private';
    await tester.tap(play); // Resume must revalidate now.
    await tester.pumpAndSettle();
    expect(checks, greaterThan(before));
    expect(
      find.byKey(const Key('communityPlaybackStatusPanel')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('communityPreviewPlay')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    community.dispose();
  });

  testWidgets('approved detail embeds the official YouTube player surface', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'status': 'available'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
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
    final preview = CommunityPreviewService();
    community.applyServerWork(_work());
    await tester.pumpWidget(
      _host(
        community: community,
        preview: preview,
        home: const CommunityWorkDetailScreen(workId: _id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommunityYoutubePlayer), findsOneWidget);
    expect(find.byKey(const Key('mockYouTube-$_id-false')), findsOneWidget);
    expect(find.text(_secretTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    community.dispose();
  });

  testWidgets('detail hides cached non-owner metadata until freshly approved', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'status': 'private'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
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
    final preview = CommunityPreviewService();
    community.applyServerWork(_work());

    await tester.pumpWidget(
      _host(
        community: community,
        preview: preview,
        home: const CommunityWorkDetailScreen(workId: _id),
      ),
    );
    expect(find.text(_secretTitle), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(_secretTitle), findsNothing);
    expect(find.text('Hidden author'), findsNothing);
    expect(
      find.byKey(const Key('communityPlaybackStatusPanel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    community.dispose();
  });
}
