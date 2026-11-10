import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/screens/community/widgets/community_youtube_player.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

const _videoId = 'abcdefghijk';
const _title = 'Saved YouTube video';
const _apiBase = 'https://example.invalid';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final pc in [false, true]) {
    for (final isPublic in [true, false]) {
      testWidgets(
        '${pc ? 'PC' : 'SP'} saved work ${isPublic ? 'plays' : 'fails closed'} through the shared YouTube player',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'first_launch': false,
            'language': 'en',
            'force_pc_mode': pc ? 1 : 0,
            firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          });
          tester.view.physicalSize =
              pc ? const Size(1440, 900) : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await loadAppFonts(tester);

          final dir = Directory.systemTemp.createTempSync('saved-yt-');
          const channel = MethodChannel('plugins.flutter.io/path_provider');
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (_) async => dir.path);
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null);
            if (dir.existsSync()) dir.deleteSync(recursive: true);
          });

          CommunityYoutubePlayer.debugPlayerBuilder =
              (context, videoId, playing) => ColoredBox(
                key: Key('saved-youtube-$videoId-$playing'),
                color: Colors.black,
              );
          addTearDown(() => CommunityYoutubePlayer.debugPlayerBuilder = null);

          var visibilityChecks = 0;
          final service = CommunityService(
            api: CommunityApi(NiarimApiClient(
              baseUrl: _apiBase,
              tokenProvider: () async => 'fixture-token',
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/bookmarks')) {
                  return http.Response(jsonEncode({
                    'works': [{
                      'workId': _videoId,
                      'authorId': 'different-author',
                      'channelName': 'Test Creator',
                      'title': _title,
                      'postedAt': '2026-11-10T00:00:00Z',
                      'isNiarimPublished': true,
                    }],
                  }), 200);
                }
                if (request.url.path.endsWith('/following')) {
                  return http.Response('{"following":[]}', 200);
                }
                if (request.url.path.endsWith('/reposts')) {
                  return http.Response('{"reposts":[]}', 200);
                }
                if (request.url.path ==
                    '/works/$_videoId/playback-status') {
                  visibilityChecks++;
                  return http.Response(
                    jsonEncode({
                      'status': isPublic ? 'available' : 'private',
                    }),
                    200,
                  );
                }
                return http.Response('{}', 404);
              }),
              maxGetRetries: 0,
            )),
          );
          addTearDown(service.dispose);
          await service.contentFiltersReady;
          service.setCurrentUserId('bookmarker');

          appRouter.go('/community');
          final providers = await tester.runAsync(buildAppProviders);
          await tester.pumpWidget(MultiProvider(
            providers: [
              ...providers!,
              ChangeNotifierProvider<CommunityService>.value(value: service),
            ],
            child: const NiarimApp(),
          ));
          await tester.pumpAndSettle();
          await tester.runAsync(() => service.loadSocial());
          final bookmarkedTab = find.byKey(const ValueKey('communityTab4'));
          await tester.ensureVisible(bookmarkedTab);
          await tester.tap(bookmarkedTab);
          await tester.pumpAndSettle();

          expect(find.text(_title), findsOneWidget);
          await tester.tap(find.text(_title));
          await tester.pumpAndSettle();

          expect(visibilityChecks, greaterThan(0));
          expect(find.byType(CommunityFloatingPreview), findsOneWidget);
          if (isPublic) {
            expect(
              find.byType(CommunityYoutubePlayer),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('saved-youtube-$_videoId-true')),
              findsOneWidget,
            );
          } else {
            expect(
              find.byType(CommunityYoutubePlayer),
              findsNothing,
            );
            expect(
              find.byKey(const Key('communityPlaybackStatusPanel')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
