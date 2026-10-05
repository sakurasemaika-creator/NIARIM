import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/screens/community/widgets/community_floating_preview.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every community surface reads one store of works in CommunityService:
/// fetched pages merge into it by id, edits reach the backend, and the
/// viewer's filters apply to it live.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const headers = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> workJson(
    String id, {
    String postedAt = '2026-08-01T12:00:00.000Z',
    List<String> tags = const [],
    List<String> lockedTags = const [],
    bool published = true,
    String authorId = 'user_1',
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
    'lockedTags': lockedTags,
    'isNiarimPublished': published,
    'containsGenerativeAiImageOrVideo': false,
  };

  /// A backend serving [latest] and [ranking]; tag and visibility PATCHes
  /// are answered by [onPatch] (null replies 409).
  ({CommunityService service, List<http.Request> requests}) backend({
    required List<Map<String, dynamic>> Function() latest,
    List<Map<String, dynamic>> ranking = const [],
    Map<String, dynamic>? Function(http.Request request)? onPatch,
  }) {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      Object? body;
      var status = 200;
      if (path == '/works/latest') {
        body = {'works': latest()};
      } else if (path.startsWith('/ranking/')) {
        body = {'period': path.split('/').last, 'works': ranking};
      } else if (request.method == 'PATCH') {
        final work = onPatch?.call(request);
        if (work == null) {
          status = 409;
          body = {'error': 'conflict', 'code': 'TAG_UPDATE_CONFLICT'};
        } else {
          body = {'work': work};
        }
      } else {
        status = 404;
        body = {'error': 'not found'};
      }
      return http.Response(jsonEncode(body), status, headers: headers);
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
    return (service: CommunityService(api: api), requests: requests);
  }

  group('store', () {
    test('with a backend it starts empty instead of showing dummy works', () {
      final (:service, requests: _) = backend(latest: () => []);
      expect(service.works, isEmpty);
      expect(CommunityService().works, isNotEmpty);
    });

    test('a refresh keeps older ranked works and drops a work that is no '
        'longer public', () async {
      var page = [
        workJson('new1', postedAt: '2026-09-03T00:00:00.000Z'),
        workJson('new2', postedAt: '2026-09-02T00:00:00.000Z'),
        workJson('new3', postedAt: '2026-09-01T00:00:00.000Z'),
      ];
      final (:service, requests: _) = backend(
        latest: () => page,
        ranking: [workJson('old', postedAt: '2026-01-01T00:00:00.000Z')],
      );
      await service.refreshFromBackend();
      await service.fetchRanking(RankingPeriod.all);
      expect(service.works.map((w) => w.id), ['new1', 'new2', 'new3', 'old']);

      // new2 was unpublished: the latest page now skips it.
      page = [page[0], page[2]];
      await service.refreshFromBackend();
      expect(service.works.map((w) => w.id), ['new1', 'new3', 'old']);
      expect(service.byId('old'), isNotNull, reason: 'its detail still opens');
    });

    test('ranked works follow the viewer filters live', () async {
      final (:service, requests: _) = backend(
        latest: () => [],
        ranking: [
          workJson('a', tags: ['spoiler']),
          workJson('b'),
        ],
      );
      final ranked = await service.fetchRanking(RankingPeriod.week);
      expect(ranked.map((w) => w.id), ['a', 'b']);
      await service.setMutedTags(['spoiler']);
      expect(service.discoverableWorks.map((w) => w.id), ['b']);
      expect(
        (await service.fetchRanking(RankingPeriod.week)).map((w) => w.id),
        ['b'],
      );
    });
  });

  group('edits reach the backend', () {
    test('a tag added is sent and the server copy kept; muting it hides the '
        'work', () async {
      final (:service, :requests) = backend(
        latest: () => [workJson('w')],
        onPatch: (request) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return workJson('w', tags: [body['tag'] as String, 'server']);
        },
      );
      await service.refreshFromBackend();
      expect(await service.addTag('w', 'spoiler'), isTrue);
      final patch = requests.singleWhere((r) => r.method == 'PATCH');
      expect(patch.url.path, '/works/w/tags');
      expect(jsonDecode(patch.body), {'action': 'add', 'tag': 'spoiler'});
      expect(service.byId('w')!.tags, ['spoiler', 'server']);
      await service.setMutedTags(['spoiler']);
      expect(service.discoverableWorks, isEmpty);
    });

    test('a refused tag edit is undone and reported', () async {
      final (:service, requests: _) = backend(
        latest: () => [
          workJson('w', tags: ['keep']),
        ],
        onPatch: (_) => null,
      );
      await service.refreshFromBackend();
      final edit = service.removeTag('w', 'keep');
      expect(service.byId('w')!.tags, isEmpty, reason: 'applied at once');
      expect(await edit, isFalse);
      expect(service.byId('w')!.tags, ['keep']);
      expect(service.lastError, isNotNull);
    });

    test('lock and visibility changes are sent', () async {
      final (:service, :requests) = backend(
        latest: () => [
          workJson('w', tags: ['t']),
        ],
        onPatch: (request) => request.url.path.endsWith('/tags')
            ? workJson('w', tags: ['t'], lockedTags: ['t'])
            : workJson('w', tags: ['t'], lockedTags: ['t'], published: false),
      );
      await service.refreshFromBackend();
      expect(await service.toggleTagLock('w', 't'), isTrue);
      expect(await service.toggleNiarimVisibility('w'), isTrue);
      final patches = requests.where((r) => r.method == 'PATCH').toList();
      expect(jsonDecode(patches[0].body), {'action': 'lock', 'tag': 't'});
      expect(patches[1].url.path, '/works/w');
      expect(jsonDecode(patches[1].body), {'isNiarimPublished': false});
      expect(service.byId('w')!.isNiarimPublished, isFalse);
      expect(service.discoverableWorks, isEmpty);
    });
  });

  test('the viewer\'s own bookmarks follow their filters, but keep their '
      'own works', () async {
    final service = CommunityService();
    final own = service.works.firstWhere(
      (w) => w.authorId == kDummySelfAuthorId && w.isNiarimPublished,
    );
    final other = service.works.firstWhere(
      (w) => w.authorId != kDummySelfAuthorId && w.isNiarimPublished,
    );
    service
      ..toggleBookmark(own.id)
      ..toggleBookmark(other.id);
    expect(service.bookmarkedWorksForViewer.map((w) => w.id), [
      other.id,
      own.id,
    ]);
    await service.setMutedWords([own.title, other.title]);
    expect(service.bookmarkedWorksForViewer.map((w) => w.id), [own.id]);
    expect(service.bookmarkedWorksOf(kDummySelfAuthorId).map((w) => w.id), [
      own.id,
    ]);
  });

  group('screens', () {
    Widget host(CommunityService service, Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<CommunityService>.value(value: service),
        ChangeNotifierProvider<SettingsService>(
          create: (_) => SettingsService(),
        ),
        ChangeNotifierProvider<PremiumService>(create: (_) => PremiumService()),
        ChangeNotifierProvider<CommunityPreviewService>(
          create: (_) => CommunityPreviewService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

    testWidgets('with a backend the plaza fetches the latest works and the '
        'selected ranking when it opens', (tester) async {
      final (:service, :requests) = backend(
        latest: () => [workJson('fresh')],
        ranking: [workJson('ranked', postedAt: '2026-01-01T00:00:00.000Z')],
      );
      await tester.pumpWidget(host(service, const CommunityScreen()));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(
        requests.map((r) => r.url.path),
        containsAll(['/works/latest', '/ranking/all']),
      );
      expect(service.byId('fresh'), isNotNull);
      expect(service.byId('ranked'), isNotNull);
    });

    testWidgets('a muted work says it is hidden by the filters, not missing', (
      tester,
    ) async {
      final service = CommunityService();
      final work = service.works.firstWhere(
        (w) => w.authorId != kDummySelfAuthorId && w.isNiarimPublished,
      );
      await service.setMutedWords([work.title]);
      await tester.pumpWidget(
        host(service, CommunityWorkDetailScreen(workId: work.id)),
      );
      await tester.pump();
      expect(find.text('表示フィルターの設定により、この作品は非表示になっています'), findsOneWidget);
      expect(find.text('作品が見つかりませんでした'), findsNothing);
    });

    testWidgets('the poster\'s own shorts keep their hidden works', (
      tester,
    ) async {
      final service = CommunityService();
      final own = service.works.firstWhere(
        (w) => w.authorId == kDummySelfAuthorId,
      );
      await service.toggleNiarimVisibility(own.id);
      if (service.byId(own.id)!.isNiarimPublished) {
        await service.toggleNiarimVisibility(own.id);
      }
      expect(service.byId(own.id)!.isNiarimPublished, isFalse);
      Widget shorts({required bool ownerView}) => host(
        service,
        CommunityShortsScreen(
          works: [service.byId(own.id)!],
          ownerView: ownerView,
          bookmarkedIds: const {},
          onToggleBookmark: (_) {},
        ),
      );
      await tester.pumpWidget(shorts(ownerView: true));
      await tester.pump();
      expect(find.text(own.title), findsOneWidget);
      await tester.pumpWidget(shorts(ownerView: false));
      await tester.pump();
      expect(find.text(own.title), findsNothing);
    });

    testWidgets('the floating preview closes when its work becomes muted', (
      tester,
    ) async {
      final service = CommunityService();
      final preview = CommunityPreviewService();
      final work = service.works.firstWhere(
        (w) => w.authorId != kDummySelfAuthorId && w.isNiarimPublished,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider<CommunityPreviewService>.value(
              value: preview,
            ),
            ChangeNotifierProvider<PremiumService>(
              create: (_) => PremiumService(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Stack(children: [CommunityFloatingPreview()]),
            ),
          ),
        ),
      );
      preview.show(work);
      await tester.pump();
      expect(preview.work?.id, work.id);
      await service.setMutedWords([work.title]);
      await tester.pump();
      await tester.pump();
      expect(preview.work, isNull);
    });
  });
}
