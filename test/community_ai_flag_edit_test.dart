import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The poster's 「AI画像・AI動画使用」 declaration can change after posting,
/// only by the poster, and every surface reading CommunityService sees it
/// at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const headers = {'content-type': 'application/json; charset=utf-8'};

  Map<String, dynamic> workJson({
    String id = 'vid00000001',
    String authorId = 'user_1',
    bool ai = false,
    String postedAt = '2026-08-01T12:00:00.000Z',
  }) => {
    'workId': id,
    'authorId': authorId,
    'channelName': 'Author',
    'title': 'Work $id',
    'postedAt': postedAt,
    'youtubeUrl': 'https://www.youtube.com/watch?v=$id',
    'thumbnailUrl': 'https://example.invalid/t.jpg',
    'viewCount': 1,
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

  /// A backend whose latest list is stale (the flag still off) while PATCH
  /// replies with the updated work.
  ({CommunityService service, List<http.Request> requests}) backend({
    List<Map<String, dynamic>>? latest,
  }) {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      Object body;
      if (request.method == 'PATCH' && path.startsWith('/works/')) {
        final patch = jsonDecode(request.body) as Map<String, dynamic>;
        body = {
          'work': workJson(
            id: Uri.decodeComponent(path.split('/').last),
            ai: patch['containsGenerativeAiImageOrVideo'] == true,
            postedAt: '2026-07-01T00:00:00.000Z',
          ),
        };
      } else if (path == '/works/latest') {
        body = {
          'works': latest ?? [workJson()],
        };
      } else if (path == '/me/works') {
        body = {
          'authorId': 'user_1',
          'works': [workJson()],
        };
      } else {
        return http.Response('{}', 404, headers: headers);
      }
      return http.Response(jsonEncode(body), 200, headers: headers);
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

  test('GET /me/works carries the signed-in NIARIM user id', () async {
    final (:service, requests: _) = backend();
    final page = await service.api!.myWorks();
    expect(page.authorId, 'user_1');
    expect(page.works.single.workId, 'vid00000001');
  });

  test(
    'with a backend nothing is the viewer\'s own until the id is known',
    () async {
      final (:service, requests: _) = backend();
      await service.refreshFromBackend();
      final work = service.byId('vid00000001')!;
      expect(service.isOwnWork(work), isFalse);
      service.setCurrentUserId('user_1');
      expect(service.isOwnWork(work), isTrue);
      service.setCurrentUserId('someone_else');
      expect(service.isOwnWork(work), isFalse);
    },
  );

  test('the PATCH reply is applied to the service, not a stale refetch, and '
      'the hide-AI filter follows it everywhere', () async {
    final (:service, :requests) = backend();
    await service.refreshFromBackend();
    service.setCurrentUserId('user_1');
    await service.setHideGenerativeAiImageVideo(true);
    expect(service.discoverableWorks.map((w) => w.id), contains('vid00000001'));

    await service.setAiImageVideoDisclosure('vid00000001', true);

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body), {'containsGenerativeAiImageOrVideo': true});
    expect(
      requests.where((r) => r.url.path == '/works/latest'),
      hasLength(1),
      reason: 'no refetch of the latest list after the change',
    );
    final work = service.byId('vid00000001')!;
    expect(work.containsGenerativeAiImageOrVideo, isTrue);
    expect(service.isDiscoverableForViewer(work), isFalse);
    expect(
      service.discoverableWorks.map((w) => w.id),
      isNot(contains(work.id)),
    );
    expect(service.worksByAuthor('user_1').map((w) => w.id), isEmpty);
    expect(
      service.worksByAuthor('user_1', includeHidden: true).map((w) => w.id),
      contains(work.id),
      reason: 'the poster still manages it',
    );

    await service.setAiImageVideoDisclosure('vid00000001', false);
    expect(service.discoverableWorks.map((w) => w.id), contains(work.id));
  });

  test('a work missing from the latest list is added from the reply', () async {
    final (:service, requests: _) = backend(latest: const []);
    await service.refreshFromBackend();
    expect(service.byId('vid00000009'), isNull);
    await service.setAiImageVideoDisclosure('vid00000009', true);
    expect(
      service.byId('vid00000009')!.containsGenerativeAiImageOrVideo,
      isTrue,
    );
  });

  test('another poster\'s work is refused before any request', () async {
    final (:service, :requests) = backend(
      latest: [workJson(authorId: 'someone_else')],
    );
    await service.refreshFromBackend();
    service.setCurrentUserId('user_1');
    await expectLater(
      service.setAiImageVideoDisclosure('vid00000001', true),
      throwsStateError,
    );
    expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    expect(
      service.byId('vid00000001')!.containsGenerativeAiImageOrVideo,
      isFalse,
    );
  });

  test('without a backend only the dummy self author can change it', () async {
    final service = CommunityService();
    final own = service.works.firstWhere(
      (w) => w.authorId == kDummySelfAuthorId,
    );
    final other = service.works.firstWhere(
      (w) => w.authorId != kDummySelfAuthorId,
    );
    var notified = 0;
    service.addListener(() => notified++);
    final updated = await service.setAiImageVideoDisclosure(
      own.id,
      !own.containsGenerativeAiImageOrVideo,
    );
    expect(
      updated.containsGenerativeAiImageOrVideo,
      !own.containsGenerativeAiImageOrVideo,
    );
    expect(service.byId(own.id), updated);
    expect(notified, greaterThan(0));
    await expectLater(
      service.setAiImageVideoDisclosure(other.id, true),
      throwsStateError,
    );
  });

  group('work detail', () {
    Future<CommunityService> pumpDetail(
      WidgetTester tester,
      CommunityService service,
      String workId,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: service),
            ChangeNotifierProvider<PremiumService>(
              create: (_) => PremiumService(),
            ),
            ChangeNotifierProvider<SettingsService>(
              create: (_) => SettingsService(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CommunityWorkDetailScreen(workId: workId),
          ),
        ),
      );
      await tester.pump();
      return service;
    }

    const switchKey = ValueKey('communityDetailAiImageVideoSwitch');
    const labelKey = ValueKey('communityDetailAiImageVideoLabel');

    testWidgets('the poster changes it from the work detail', (tester) async {
      final service = CommunityService();
      final own = service.works.firstWhere(
        (w) => w.authorId == kDummySelfAuthorId && w.isNiarimPublished,
      );
      await service.setAiImageVideoDisclosure(own.id, false);
      await pumpDetail(tester, service, own.id);
      await tester.ensureVisible(find.byKey(switchKey));
      await tester.tap(find.byKey(switchKey));
      await tester.pump();
      expect(service.byId(own.id)!.containsGenerativeAiImageOrVideo, isTrue);
      expect(tester.widget<Switch>(find.byKey(switchKey)).value, isTrue);
      expect(find.byKey(labelKey), findsNothing);
    });

    testWidgets('the poster still opens their own work while hiding AI '
        'works', (tester) async {
      final service = CommunityService();
      final own = service.works.firstWhere(
        (w) => w.authorId == kDummySelfAuthorId && w.isNiarimPublished,
      );
      await service.setAiImageVideoDisclosure(own.id, true);
      await service.setHideGenerativeAiImageVideo(true);
      await pumpDetail(tester, service, own.id);
      expect(find.byKey(switchKey), findsOneWidget);
    });

    testWidgets('viewers see the declaration but cannot change it', (
      tester,
    ) async {
      final (:service, :requests) = backend(latest: [workJson(ai: true)]);
      await tester.runAsync(service.refreshFromBackend);
      service.setCurrentUserId('someone_else');
      await pumpDetail(tester, service, 'vid00000001');
      expect(find.byKey(switchKey), findsNothing);
      await tester.ensureVisible(find.byKey(labelKey));
      expect(find.byKey(labelKey), findsOneWidget);
      expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    });
  });
}
