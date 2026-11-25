// ミッションの画面は、オパールを受け取れるミッションだけを並べる。
//
// 制作時間（`verifiedEditSeconds`）は端末で計った記録で、サーバーは制作時間の
// 検証を有効にしておらず、どれだけ制作してもオパールを受け取れない。それでも
// 一覧にオパールの数つきで15件並んでいた。ランキング
// （`niarimBookmarkRanking`）の報酬は、サーバーが有効にするまで受け取れない
// ので、有効になった行だけを出す（有効になれば一覧に現れる）。
//
// 作品を選んでいないとき（作品ごとのひな形）と、作品を選んだときの両方で
// 確かめる。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/creator_missions_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'hidden-mission-rows';
  @override
  String get email => 'example.invalid';
  @override
  String get displayName => 'Example';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends GoogleAuthService {
  final _user = _Account();
  @override
  GoogleSignInAccount? get account => _user;
  @override
  bool get isConfigured => true;
}

http.Response _json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _mission(
  String id,
  String kind,
  int required, {
  bool rewardEnabled = true,
  bool perWork = false,
  bool eligible = false,
}) => {
  'id': id,
  'kind': kind,
  'required': required,
  'progress': 0,
  'coins': 10,
  'claimed': false,
  'eligible': eligible,
  'readyForClaim': eligible,
  'rewardEnabled': rewardEnabled,
  'perWork': perWork,
};

/// 制作時間（達成して受け取れる見た目の行も含む）・報酬の有効と無効の
/// ランキング（アカウントごと・作品ごと）・フォロワーを返すサーバー。
CommunityService _server() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') return _json({'visitedToday': true});
        return _json(switch (request.url.path) {
          '/me/missions' => {
            'enabled': true,
            'publishedWorkCount': 120,
            'missions': [
              _mission('time_1', 'verifiedEditSeconds', 3600),
              _mission('time_10', 'verifiedEditSeconds', 36000, eligible: true),
              _mission(
                'rank_off',
                'niarimBookmarkRanking',
                10,
                rewardEnabled: false,
              ),
              _mission('rank_on', 'niarimBookmarkRanking', 3),
              _mission(
                'rank_work_off',
                'niarimBookmarkRanking',
                50,
                rewardEnabled: false,
                perWork: true,
              ),
              _mission(
                'rank_work_on',
                'niarimBookmarkRanking',
                20,
                perWork: true,
              ),
              _mission('followers_100', 'followers', 100),
            ],
          },
          '/me/missions/grid' => {'missions': [], 'rewardEnabled': true},
          '/me/missions/work-achievements' => {'items': [], 'nextCursor': null},
          '/me/login-bonus' => {
            'totalDays': 1,
            'visitedToday': true,
            'dailyCoins': 1,
            'dailyClaimed': true,
            'rewardEnabled': true,
            'milestones': [],
          },
          '/me/missions/recurring' => {'enabled': true, 'missions': []},
          '/me/missions/plaza' => {'enabled': true, 'missions': []},
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, {String? workId}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 8000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
        ChangeNotifierProvider<CommunityService>.value(value: _server()),
        ChangeNotifierProvider<ProjectService>.value(value: ProjectService()),
        ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreatorMissionsScreen(workId: workId),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// [id]のミッションの行（作品を選んでいるときの作品ごとの行は[workId]）。
Finder _row(String id, {String? workId}) =>
    find.byKey(ValueKey('mission_$id:${workId ?? "template"}'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  for (final workId in [null, 'work_1']) {
    final where = workId == null ? '作品を選んでいない' : '作品を選んだ';
    testWidgets('制作時間とサーバーが報酬を有効にしていないランキングは出さず、'
        '有効なランキングは出す（$where）', (tester) async {
      await _pump(tester, workId: workId);
      final l10n = lookupAppLocalizations(const Locale('ja'));

      // 一覧そのものは出ている（出ていなければ何も確かめていない）。
      expect(_row('followers_100'), findsOneWidget);
      expect(find.text(l10n.creatorMissionFollowers(100)), findsOneWidget);

      // 制作時間：オパールを受け取れないので、達成して見えても出さない。
      expect(_row('time_1'), findsNothing);
      expect(_row('time_10'), findsNothing);
      expect(find.byKey(const ValueKey('claim_time_10_account')), findsNothing);
      expect(find.text(l10n.creatorMissionTime(1)), findsNothing);
      expect(find.text(l10n.creatorMissionTime(10)), findsNothing);

      // ランキング：サーバーが報酬を有効にした行だけを出す。
      expect(_row('rank_off'), findsNothing);
      expect(_row('rank_work_off', workId: workId), findsNothing);
      expect(find.text(l10n.creatorMissionRank(10)), findsNothing);
      expect(find.text(l10n.creatorMissionRank(50)), findsNothing);
      expect(_row('rank_on'), findsOneWidget);
      expect(_row('rank_work_on', workId: workId), findsOneWidget);
      expect(find.text(l10n.creatorMissionRank(3)), findsOneWidget);
      expect(find.text(l10n.creatorMissionRank(20)), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
