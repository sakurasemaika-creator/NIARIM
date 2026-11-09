import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/screens/community/widgets/community_ranking_work_list.dart';

const a = 'aaaaaaaaaaa';
const b = 'bbbbbbbbbbb';
const c = 'ccccccccccc';
const headers = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> work(String id) => {
  'workId': id,
  'title': 'Original title $id',
  'authorId': 'author-$id',
  'channelName': 'Creator $id',
  'postedAt': '2026-11-09T00:00:00Z',
  'bookmarkCount': 13,
  'isNiarimPublished': true,
  'thumbnailUrl': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hidden ranking entry is removed and remaining ranks compact',
      (tester) async {
    var bIsPrivate = false;
    var rankingReads = 0;
    var visibilityReads = 0;
    final requests = <String>[];
    final httpClient = MockClient((request) async {
      requests.add(request.url.path);
      final path = request.url.path;
      if (path == '/ranking/bookmarks') {
        rankingReads++;
        return http.Response(jsonEncode({
          'period':'bookmarks',
          // A newly fetched snapshot never contains work B if already hidden.
          'works': [
            work(a),
            if (!bIsPrivate) work(b),
            work(c),
          ],
        }), 200, headers: headers);
      }
      if (path == '/ranking/visibility') {
        visibilityReads++;
        final ids = (request.url.queryParameters['ids'] ?? '').split(',');
        return http.Response(jsonEncode({
          'visibility': {
            for (final id in ids) id: id != b || !bIsPrivate,
          }
        }), 200, headers: headers);
      }
      return http.Response('{}', 404, headers: headers);
    });
    final service = CommunityService(api: CommunityApi(NiarimApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: httpClient,
      tokenProvider: () async => null,
      maxGetRetries: 0,
      retryBackoff: Duration.zero,
    )));
    await service.fetchRanking(RankingPeriod.bookmarks);
    expect(service.rankedWorks.map((w) => w.id).toList(), [a,b,c]);
    expect(rankingReads,1);
    bIsPrivate = true;
    expect(await service.validateRankingWorkForOpen(b), isFalse);
    expect(visibilityReads,1);
    final after = service.rankedWorks;
    expect(after.map((w) => w.id).toList(), [a,c]);
    expect(after[1].isUnavailable, isFalse);
    expect(rankingReads,1); // The click guard does not do a second ranking query.

    var taps=0;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value:service,
      child:MaterialApp(
        locale:const Locale('ja'),
        localizationsDelegates:AppLocalizations.localizationsDelegates,
        supportedLocales:AppLocalizations.supportedLocales,
        home:Scaffold(body:SingleChildScrollView(child:
          CommunityRankingWorkList(
            works:after,
            layout:CommunityRankingLayout.horizontal,
            bookmarkedIds:const {},
            onTapWork:(_)=>taps++,
            onToggleBookmark:(_)=>taps++,
            onTapAuthor:(_)=>taps++,
          ),
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ranking-card-bbbbbbbbbbb')),findsNothing);
    expect(find.text('Original title $b'),findsNothing);
    expect(find.text('Creator $b'),findsNothing);
    expect(find.byKey(const ValueKey('community-ranking-card-ccccccccccc')),findsOneWidget);
    expect(find.byKey(const ValueKey('communityRankBadge-2')),findsNothing);
    expect(taps,0);

    // A fresh ranking returns the same compact order, without extra polling.
    await service.fetchRanking(RankingPeriod.bookmarks);
    expect(service.rankedWorks.map((w)=>w.id).toList(),[a,c]);
    expect(rankingReads,2);
    expect(requests.where((p)=>p=='/ranking/visibility').length,1);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
