// 報酬・ミッション・累計ログインボーナスの画面で、数と単位がその言語の
// 正しい形（単数・複数と、数の後ろの空白）で出ることを、本物の画面で確かめる。
//
// 以前はコードで「数＋' '＋単位の語」や「{n}を置き換えた複数形の文」を作って
// いたため、英語で「1 coins」「Total 1 days」「1 hours」になっていた。作品広場の
// 滞在ミッション・ウィークリー／マンスリーミッション・ミッション達成の知らせは
// 日本語と英語しか持たず、スペイン語・フランス語でも英語が出ていた。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/community/community_follow_notifications_screen.dart';
import 'package:niarim/screens/rewards/creator_missions_screen.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/coin_history_sheet.dart';
import 'package:niarim/widgets/mission_completion_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'count-unit-account';
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

/// [n]を数に使った応答を返すサーバーの代わり。
CommunityService _serviceWithCounts(int n) => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/me/missions/activity/sync') {
          return _json({'hadMore': false, 'nextWorkCursor': null});
        }
        if (request.method == 'POST') return _json({'visitedToday': true});
        return _json(switch (path) {
          '/me/missions' => {
            'enabled': true,
            'candidateEditSeconds': 0,
            'missions': [
              {
                'id': 'followers_n',
                'kind': 'followers',
                'required': n,
                'progress': 0,
                'coins': n,
                'claimed': false,
                'eligible': false,
                'readyForClaim': false,
                'rewardEnabled': true,
                'perWork': false,
              },
              {
                'id': 'time_n',
                'kind': 'verifiedEditSeconds',
                'required': n * 3600,
                'coins': n,
                'claimed': false,
                'eligible': false,
                'readyForClaim': false,
                'rewardEnabled': true,
                'perWork': false,
              },
            ],
          },
          '/me/missions/grid' => {'missions': [], 'rewardEnabled': true},
          '/me/missions/work-achievements' => {'items': [], 'nextCursor': null},
          '/me/login-bonus' => {
            'totalDays': n,
            'visitedToday': true,
            'dailyCoins': n,
            'dailyClaimed': false,
            'rewardEnabled': true,
            'milestones': [
              {'days': n, 'coins': n, 'claimed': false, 'eligible': false},
            ],
          },
          '/me/missions/recurring' => {
            'enabled': true,
            'missions': [
              {
                'id': 'visit_week_n',
                'period': 'week',
                'requiredDays': n,
                'progressDays': n,
                'coins': n,
                'claimed': false,
                'eligible': false,
              },
            ],
          },
          '/me/missions/plaza' => {
            'enabled': true,
            'missions': [
              {
                'id': 'plaza_day_n',
                'period': 'day',
                'requiredSeconds': n * 3600,
                'progressSeconds': n * 60,
                'coins': n,
                'claimed': false,
                'eligible': false,
              },
            ],
          },
          '/me/missions/activity' => {
            'events': [
              {'eventId': 'f', 'kind': 'followers', 'required': n},
              {
                'eventId': 'b',
                'kind': 'workBookmarks',
                'workTitle': 'Sky',
                'required': n,
              },
              {
                'eventId': 'q',
                'kind': 'qualifiedWorks',
                'required': n,
                'eachWorkBookmarks': n,
              },
              {
                'eventId': 'p',
                'kind': 'qualifiedWorks',
                'required': n,
                'eachWorkBookmarks': 0,
              },
              {'eventId': 'l', 'kind': 'loginMilestone', 'required': n},
            ],
            'nextCursor': null,
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

/// 画面に出ているすべての文字列。
List<String> _shownTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

/// 単位の語を1つの数に付けたときの誤り（「1 coins」等）と、数と単位の間の
/// 空白の抜け（「2coins」等）を探す。
final _unitWords =
    'hours|days|coins|followers|bookmarks|minutes|works|'
    'horas|días|monedas|seguidores|marcadores|minutos|obras|'
    'heures|jours|pièces|abonnés|favoris|œuvres';
final _pluralAfterOne = RegExp(
  '(^|[^0-9])1 ($_unitWords)(?![\\p{L}])',
  unicode: true,
);
final _noSpace = RegExp('[0-9]($_unitWords)', unicode: true);

void _expectNoBrokenUnits(List<String> texts) {
  for (final text in texts) {
    expect(_pluralAfterOne.hasMatch(text), isFalse, reason: '単数のはずが複数形: $text');
    expect(_noSpace.hasMatch(text), isFalse, reason: '数と単位の間に空白が無い: $text');
  }
}

/// 言語ごと・数ごとに画面に出るはずの文言（いずれも1つのTextに丸ごと出る）。
Map<String, List<String>> _missionScreenTexts(int n) {
  final s = n == 1;
  return {
    'en': [
      'Claim all',
      s ? 'Total 1 day' : 'Total 2 days',
      s ? '1 coin each day' : '2 coins each day',
      s ? 'Logged in 1 day' : 'Logged in 2 days',
      s ? '1 coin' : '2 coins',
      s ? 'Visit on 1 day this period' : 'Visit on 2 days this period',
      s ? '1 / 1 day · 1 coin' : '2 / 2 days · 2 coins',
      s
          ? 'Keep Work Plaza open for 1 hour'
          : 'Keep Work Plaza open for 2 hours',
      s ? '1 minute / 1 hour · 1 coin' : '2 minutes / 2 hours · 2 coins',
      'Not yet',
      'Daily',
      'Weekly',
      s ? '1 follower' : '2 followers',
      s
          ? '1 hour of verified creation time'
          : '2 hours of verified creation time',
    ],
    'es': [
      'Reclamar todo',
      s ? 'Total 1 día' : 'Total 2 días',
      s ? '1 moneda al día' : '2 monedas al día',
      s ? '1 día de acceso' : '2 días de acceso',
      s ? '1 moneda' : '2 monedas',
      s ? 'Entra 1 día en este periodo' : 'Entra 2 días en este periodo',
      s ? '1 / 1 día · 1 moneda' : '2 / 2 días · 2 monedas',
      s
          ? 'Mantén abierta la Plaza de Obras 1 hora en total'
          : 'Mantén abierta la Plaza de Obras 2 horas en total',
      s ? '1 minuto / 1 hora · 1 moneda' : '2 minutos / 2 horas · 2 monedas',
      'Sin completar',
      'Diarias',
      'Semanales',
      s ? '1 seguidor' : '2 seguidores',
      s ? '1 hora de creación verificada' : '2 horas de creación verificadas',
    ],
    'fr': [
      'Tout réclamer',
      s ? 'Total : 1 jour' : 'Total : 2 jours',
      s ? '1 pièce par jour' : '2 pièces par jour',
      s ? '1 jour de connexion' : '2 jours de connexion',
      s ? '1 pièce' : '2 pièces',
      s
          ? 'Se connecter 1 jour sur la période'
          : 'Se connecter 2 jours sur la période',
      s ? '1 / 1 jour · 1 pièce' : '2 / 2 jours · 2 pièces',
      s
          ? 'Garder la Place des œuvres ouverte 1 heure au total'
          : 'Garder la Place des œuvres ouverte 2 heures au total',
      s ? '1 minute / 1 heure · 1 pièce' : '2 minutes / 2 heures · 2 pièces',
      'Non atteint',
      'Quotidiennes',
      'Hebdomadaires',
      s ? '1 abonné' : '2 abonnés',
      s ? '1 heure de création vérifiée' : '2 heures de création vérifiées',
    ],
  };
}

Map<String, List<String>> _activityTexts(int n) {
  final s = n == 1;
  return {
    'en': [
      s ? 'Reached 1 follower' : 'Reached 2 followers',
      s ? 'Sky reached 1 bookmark' : 'Sky reached 2 bookmarks',
      s
          ? 'Your published work reached 1 bookmark'
          : 'Your 2 published works each reached 2 bookmarks',
      s ? 'You published 1 work' : 'You published 2 works',
      s ? 'You reached 1 total login day' : 'You reached 2 total login days',
    ],
    'es': [
      s ? 'Alcanzaste 1 seguidor' : 'Alcanzaste 2 seguidores',
      s ? 'Sky alcanzó 1 marcador' : 'Sky alcanzó 2 marcadores',
      s
          ? 'Tu obra alcanzó 1 marcador'
          : 'Tus 2 obras alcanzaron 2 marcadores cada una',
      s ? 'Publicaste 1 obra' : 'Publicaste 2 obras',
      s
          ? '¡Has alcanzado 1 día de acceso!'
          : '¡Has alcanzado 2 días de acceso!',
    ],
    'fr': [
      s ? 'Vous avez atteint 1 abonné' : 'Vous avez atteint 2 abonnés',
      s ? 'Sky a atteint 1 favori' : 'Sky a atteint 2 favoris',
      s
          ? 'Votre œuvre a atteint 1 favori'
          : 'Vos 2 œuvres ont chacune atteint 2 favoris',
      s ? 'Vous avez publié 1 œuvre' : 'Vous avez publié 2 œuvres',
      s
          ? 'Vous avez atteint 1 jour de connexion'
          : 'Vous avez atteint 2 jours de connexion',
    ],
  };
}

Map<String, List<String>> _completionTexts(int n) {
  final s = n == 1;
  return {
    'en': [
      'Mission completed!',
      s ? 'Visit on 1 day this week' : 'Visit on 2 days this week',
      s ? 'Visit on 1 day this month' : 'Visit on 2 days this month',
      s ? 'Visit on 1 day in total' : 'Visit on 2 days in total',
      'Go to Missions',
    ],
    'es': [
      '¡Misión completada!',
      s ? 'Entra 1 día esta semana' : 'Entra 2 días esta semana',
      s ? 'Entra 1 día este mes' : 'Entra 2 días este mes',
      s ? 'Entra 1 día en total' : 'Entra 2 días en total',
      'Ir a Misiones',
    ],
    'fr': [
      'Mission accomplie !',
      s
          ? 'Se connecter 1 jour cette semaine'
          : 'Se connecter 2 jours cette semaine',
      s ? 'Se connecter 1 jour ce mois-ci' : 'Se connecter 2 jours ce mois-ci',
      s ? 'Se connecter 1 jour au total' : 'Se connecter 2 jours au total',
      'Aller aux missions',
    ],
  };
}

Widget _app(String locale, Widget home) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  for (final locale in ['en', 'es', 'fr']) {
    for (final n in [1, 2]) {
      testWidgets('ミッション画面の数と単位（$locale, $n）', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 6000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _SignedIn();
        final community = _serviceWithCounts(n);
        final projects = ProjectService();
        final settings = SettingsService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
              ChangeNotifierProvider<CommunityService>.value(value: community),
              ChangeNotifierProvider<ProjectService>.value(value: projects),
              ChangeNotifierProvider<SettingsService>.value(value: settings),
            ],
            child: _app(locale, const CreatorMissionsScreen()),
          ),
        );
        await _settle(tester);
        await tester.tap(find.byKey(const Key('loginMilestoneExpansion')));
        await tester.pumpAndSettle();
        final texts = _shownTexts(tester);
        for (final expected in _missionScreenTexts(n)[locale]!) {
          expect(texts, contains(expected), reason: '$locale: $texts');
        }
        _expectNoBrokenUnits(texts);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('作品広場の通知の数と単位（$locale, $n）', (tester) async {
        final auth = _SignedIn();
        final community = _serviceWithCounts(n);
        final settings = SettingsService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
              ChangeNotifierProvider<CommunityService>.value(value: community),
              ChangeNotifierProvider<SettingsService>.value(value: settings),
            ],
            child: _app(locale, const CommunityFollowNotificationsScreen()),
          ),
        );
        await _settle(tester);
        final texts = _shownTexts(tester);
        for (final expected in _activityTexts(n)[locale]!) {
          expect(texts, contains(expected), reason: '$locale: $texts');
        }
        _expectNoBrokenUnits(texts);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('特典交換の必要コイン（$locale, $n）', (tester) async {
        final premium = PremiumService();
        final settings = SettingsService();
        final auth = GoogleAuthService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PremiumService>.value(value: premium),
              ChangeNotifierProvider<SettingsService>.value(value: settings),
              ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
            ],
            child: _app(
              locale,
              RewardUnlockScreen(
                priceCatalog: {
                  CoinUnlockTarget.toneCurve: CoinUnlockUnitPrices(
                    perHour: n,
                    perDay: 20,
                    perWeek: 110,
                    perMonth: 450,
                  ),
                },
              ),
            ),
          ),
        );
        await tester.pump();
        final row = find.byKey(const ValueKey('rewardFeature_toneCurve'));
        final coin = {
          'en': n == 1 ? '1 coin' : '2 coins',
          'es': n == 1 ? '1 moneda' : '2 monedas',
          'fr': n == 1 ? '1 pièce' : '2 pièces',
        }[locale]!;
        expect(
          find.descendant(of: row, matching: find.text(coin)),
          findsOneWidget,
        );
        final reference = {
          'en': 'Reference only (not for sale)',
          'es': 'Precio de referencia (aún no canjeable)',
          'fr': 'Prix indicatif (échange pas encore disponible)',
        }[locale]!;
        expect(find.textContaining(reference), findsWidgets);
        _expectNoBrokenUnits(_shownTexts(tester));
      });

      testWidgets('コインの取引履歴（$locale, $n）', (tester) async {
        final owner = ValueNotifier<String?>('owner');
        addTearDown(owner.dispose);
        await tester.pumpWidget(
          _app(
            locale,
            Scaffold(
              body: CoinHistorySheet(
                ownerId: 'owner',
                accountChanges: owner,
                currentAccountId: () => owner.value,
                fetchPage: ({String? cursor, int limit = 20}) async => {
                  'entries': [
                    {
                      'source': 'rewarded-ad',
                      'deltaCoins': n,
                      'occurredAtEpochMs': 1760000000000,
                    },
                    {
                      'source': 'coin-redemption',
                      'deltaCoins': -n,
                      'occurredAtEpochMs': 1760001000000,
                    },
                  ],
                  'nextCursor': null,
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final unit = {
          'en': n == 1 ? '1 coin' : '2 coins',
          'es': n == 1 ? '1 moneda' : '2 monedas',
          'fr': n == 1 ? '1 pièce' : '2 pièces',
        }[locale]!;
        expect(find.text('+$unit'), findsOneWidget);
        expect(find.text('-$unit'), findsOneWidget);
        _expectNoBrokenUnits(_shownTexts(tester));
      });

      testWidgets('ミッション達成の知らせ（$locale, $n）', (tester) async {
        late BuildContext pageContext;
        await tester.pumpWidget(
          _app(
            locale,
            Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        );
        final shown = showServerMissionCompletions(pageContext, {
          'newlyAchieved': [
            {'period': 'week', 'requiredDays': n},
            {'period': 'month', 'requiredDays': n},
            {'period': 'total', 'requiredDays': n},
          ],
        });
        await tester.pumpAndSettle();
        final texts = _shownTexts(tester).join('\n');
        for (final expected in _completionTexts(n)[locale]!) {
          expect(texts, contains(expected), reason: '$locale: $texts');
        }
        _expectNoBrokenUnits(texts.split('\n'));
        await tester.tap(find.byKey(const Key('missionCompletedClose')));
        await tester.pumpAndSettle();
        await shown;
      });
    }
  }
}
