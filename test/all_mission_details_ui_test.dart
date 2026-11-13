import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/screens/rewards/plaza_missions_panel.dart';
import 'package:niarim/screens/rewards/recurring_missions_panel.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'Nmission-info-test';
  @override
  String get email => 'example.invalid';
  @override
  String get displayName => 'Mission Info Example';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends GoogleAuthService {
  final _testUser = _Account();
  @override
  GoogleSignInAccount? get account => _testUser;
  @override
  bool get isConfigured => true;
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('help/exclamation icons stay LEFT of recurring and Plaza '
      'mission titles and open detailed requirements', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = CommunityApi(
      NiarimApiClient(
        baseUrl: 'https://example.invalid',
        tokenProvider: () async => 'non-production-test-token',
        maxGetRetries: 0,
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            return _json({'visitedToday': true, 'totalDays': 2});
          }
          if (request.url.path == '/me/missions/recurring') {
            return _json({
              'enabled': true,
              'missions': [
                {
                  'id': 'visit_week_3',
                  'period': 'week',
                  'requiredDays': 3,
                  'progressDays': 2,
                  'coins': 10,
                  'eligible': false,
                  'claimed': false,
                },
              ],
            });
          }
          if (request.url.path == '/me/missions/plaza') {
            return _json({
              'enabled': true,
              'missions': [
                {
                  'id': 'plaza_day_5m',
                  'period': 'day',
                  'requiredSeconds': 300,
                  'progressSeconds': 600,
                  'coins': 10,
                  'eligible': true,
                  'claimed': false,
                },
              ],
            });
          }
          return _json(<String, Object>{});
        }),
      ),
    );
    final community = CommunityService(api: api);
    await community.contentFiltersReady;
    final auth = _Auth();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
          ChangeNotifierProvider<CommunityService>.value(value: community),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          supportedLocales: const [Locale('ja'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ListView(
              children: const [RecurringMissionsPanel(), PlazaMissionsPanel()],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    final recurring = find.byKey(
      const Key('recurringMissionDetails_visit_week_3'),
    );
    await tester.ensureVisible(recurring);
    await tester.pumpAndSettle();
    expect(recurring, findsOneWidget);
    expect(
      find.descendant(of: recurring, matching: find.byIcon(Icons.help_outline)),
      findsOneWidget,
    );
    expect(
      tester.getCenter(recurring).dx,
      lessThan(tester.getCenter(find.text('週に3日ログイン')).dx),
    );
    await tester.tap(recurring);
    await tester.pumpAndSettle();
    expect(find.textContaining('同じ週（月曜日から日曜日）'), findsOneWidget);
    expect(find.textContaining('1日に複数回ログインしても1日'), findsOneWidget);
    expect(find.textContaining('新しい週・月'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
    );

    await tester.pumpAndSettle();

    final plaza = find.byKey(const Key('plazaMissionDetails_plaza_day_5m'));
    await tester.ensureVisible(plaza);
    await tester.pumpAndSettle();
    expect(plaza, findsOneWidget);
    expect(
      find.descendant(
        of: plaza,
        matching: find.byIcon(Icons.priority_high_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getCenter(plaza).dx,
      lessThan(tester.getCenter(find.text('作品広場を合計5分開く')).dx),
    );
    await tester.tap(plaza);
    await tester.pumpAndSettle();
    expect(find.textContaining('動画を再生したり、画面を操作したり'), findsOneWidget);
    expect(find.textContaining('サーバー時刻に基づく定期通信'), findsOneWidget);
    expect(find.textContaining('同じ期間中に1回限り'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
    );

    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    community.dispose();
  });
}
