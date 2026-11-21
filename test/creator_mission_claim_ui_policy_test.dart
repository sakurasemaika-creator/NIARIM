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

class _SignedInAuth extends GoogleAuthService {
  final _account = _TestAccount();

  @override
  GoogleSignInAccount get account => _account;
}

class _TestAccount implements GoogleSignInAccount {
  @override
  String get id => 'sample-owner';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('claim button requires achieved, ready, unclaimed and approved', () {
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: false,
        enabled: true,
      ),
      isTrue,
    );
    expect(
      missionClaimActionAllowed(
        eligible: false,
        ready: true,
        claimed: false,
        enabled: true,
      ),
      isFalse,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: false,
        claimed: false,
        enabled: true,
      ),
      isFalse,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: true,
        enabled: true,
      ),
      isFalse,
    );
    expect(
      missionClaimActionAllowed(
        eligible: true,
        ready: true,
        claimed: false,
        enabled: false,
      ),
      isFalse,
    );
  });

  testWidgets('one bulk claim collects ready rewards on later work pages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _SignedInAuth();
    final projects = ProjectService();
    final settings = SettingsService();
    final claims = <(String, String)>[];
    Map<String, Object> milestone(String workId) => {
      'missionId': 'work_reposts_10',
      'workId': workId,
      'workTitle': 'Work $workId',
      'kind': 'workReposts',
      'required': 10,
      'readyForClaim': true,
      'claimed': false,
      'coins': 15,
    };
    final first = milestone('abcdefghijk');
    final second = milestone('lmnopqrstuv');
    final community = CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => 'non-production-test-token',
          maxGetRetries: 0,
          httpClient: MockClient((request) async {
            final isNext = request.url.queryParameters['cursor'] == 'next-page';
            final path = request.url.path;
            if (path == '/me/missions/claim') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              claims.add((
                body['missionId'] as String,
                body['workId'] as String,
              ));
            }
            final data = switch (path) {
              '/me/missions/work-achievements' => {
                'items': isNext ? [first, second] : [first],
                'rewardEnabled': true,
                'nextCursor': isNext ? null : 'next-page',
              },
              '/me/missions/claim' => {'claimed': true, 'awardedCoins': 15},
              '/me/missions' => {'enabled': true, 'missions': []},
              _ => {'missions': [], 'rewardEnabled': false},
            };
            return http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ),
    );
    addTearDown(auth.dispose);
    addTearDown(projects.dispose);
    addTearDown(settings.dispose);
    addTearDown(community.dispose);
    await community.contentFiltersReady;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ChangeNotifierProvider<CommunityService>.value(value: community),
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: const CreatorMissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bulkButton = find.byKey(const Key('missionClaimAllButton'));
    expect(tester.getSize(bulkButton).height, greaterThanOrEqualTo(52));
    final claimButton = find.byKey(
      const ValueKey('claim_work_reposts_10_abcdefghijk'),
    );
    await tester.scrollUntilVisible(
      claimButton,
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    expect(claimButton, findsOneWidget);
    expect(tester.getSize(claimButton).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(bulkButton);
    await tester.pumpAndSettle();
    await tester.tap(bulkButton);
    await tester.pumpAndSettle();
    expect(claims, [
      ('work_reposts_10', 'abcdefghijk'),
      ('work_reposts_10', 'lmnopqrstuv'),
    ]);
    expect(find.text('まとめて受取：2件完了'), findsOneWidget);
  });
}
