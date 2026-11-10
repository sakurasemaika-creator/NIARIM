// 報酬・ミッション・累計ログインボーナスの画面で、数と単位がその言語の
// 正しい形（単数・複数と、数の後ろの空白）で出ることを、本物の画面で確かめる。
//
// 以前はコードで「数＋' '＋単位の語」や「{n}を置き換えた複数形の文」を作って
// いたため、英語で「1 coins」「Total 1 days」「1 hours」になっていた。作品広場の
// 滞在ミッション・ウィークリー／マンスリーミッション・ミッション達成の知らせは
// 日本語と英語しか持たず、スペイン語・フランス語でも英語が出ていた。特典交換の
// 「重複・有効期限を確認」と交換の確認の文は、どの言語でも日本語のまま
// （日付も「年月日時分」）で、参考合計は「数＋' コイン'」をつないでいた。
//
// フランス語は0も単数（CLDRの`one`）なので、数の無い`one`の文は0のときに
// 「あなたの作品が」のような1つの作品の文になる。0も確かめる。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
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

/// [n]を数に使った応答を返すサーバーの代わり。クリエイターミッションは
/// 画面が出し分ける種類（フォロワー・制作時間・ブックマーク〔作品名あり・
/// なし〕・ランキング・投稿数・各作品のブックマーク）をすべて返す。
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
        Map<String, Object?> mission(
          String id,
          String kind,
          int required, {
          int? each,
        }) => {
          'id': id,
          'kind': kind,
          'required': required,
          'eachWorkBookmarks': ?each,
          'progress': 0,
          'coins': n,
          'claimed': false,
          'eligible': false,
          'readyForClaim': false,
          'rewardEnabled': true,
          'perWork': false,
        };
        return _json(switch (path) {
          '/me/missions' => {
            'enabled': true,
            'candidateEditSeconds': n * 60,
            'missions': [
              mission('followers_n', 'followers', n),
              mission('time_n', 'verifiedEditSeconds', n * 3600),
              mission('bookmarks_n', 'workBookmarks', n),
              mission('rank_n', 'niarimBookmarkRanking', n),
              mission('works_each_n', 'qualifiedWorks', n, each: 3),
              mission('works_n', 'qualifiedWorks', n, each: 0),
            ],
          },
          '/me/missions/grid' => {'missions': [], 'rewardEnabled': true},
          '/me/missions/work-achievements' => {
            'items': [
              {
                'missionId': 'sky_bookmarks_n',
                'workId': 'sky',
                'workTitle': 'Sky',
                'kind': 'workBookmarks',
                'required': n,
                'coins': n,
                'claimed': false,
                'readyForClaim': false,
              },
            ],
            'nextCursor': null,
          },
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
              {'eventId': 'w', 'kind': 'workPublished', 'workTitle': 'Sky'},
              // 'required'の無い（数が読めない）知らせは0作品として出る。
              {
                'eventId': 'z',
                'kind': 'qualifiedWorks',
                'eachWorkBookmarks': 3,
              },
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

/// 日本語の仮名（ほかの言語の画面に出てはいけない）。
final _kana = RegExp('[぀-ヿ]');

/// 漢字・仮名・ハングル（英語・スペイン語・フランス語の画面に出てはいけない。
/// 「2026年11月10日」のような日本語の日付もこれで見つかる）。
final _cjk = RegExp('[぀-ヿ一-鿿가-힯]');

void _expectNoBrokenUnits(List<String> texts) {
  for (final text in texts) {
    expect(_pluralAfterOne.hasMatch(text), isFalse, reason: '単数のはずが複数形: $text');
    expect(_noSpace.hasMatch(text), isFalse, reason: '数と単位の間に空白が無い: $text');
  }
}

/// CLDRの単数（`one`）か。フランス語は0と1、英語・スペイン語は1だけ。
bool _one(String locale, int n) => locale == 'fr' ? n <= 1 : n == 1;

/// 言語ごと・数ごとに画面に出るはずの文言（いずれも1つのTextに丸ごと出る）。
List<String> _missionScreenTexts(String locale, int n) {
  final one = _one(locale, n);
  String c(String singular, String plural) => '$n ${one ? singular : plural}';
  // 作品広場の目標は秒で届く。0秒は「0分」になる。
  final hoursOrMinutes = switch (locale) {
    'en' => n == 0 ? c('minute', 'minutes') : c('hour', 'hours'),
    'es' => n == 0 ? c('minuto', 'minutos') : c('hora', 'horas'),
    _ => n == 0 ? c('minute', 'minutes') : c('heure', 'heures'),
  };
  return switch (locale) {
    'en' => [
      'Claim all',
      'Total ${c('day', 'days')}',
      '${c('coin', 'coins')} each day',
      'Logged in ${c('day', 'days')}',
      c('coin', 'coins'),
      'Sign in on ${c('day', 'days')} this week',
      '$n / ${c('day', 'days')} · ${c('coin', 'coins')}',
      'Keep Work Plaza open for $hoursOrMinutes in total',
      '${c('minute', 'minutes')} / $hoursOrMinutes · ${c('coin', 'coins')}',
      'Not achieved',
      'Daily',
      'Weekly',
      c('follower', 'followers'),
      '${c('hour', 'hours')} of verified creation time',
      n == 0
          ? 'Publish a work'
          : 'A published work reaches ${c('bookmark', 'bookmarks')}',
      n == 0 ? 'Sky is published' : 'Sky reaches ${c('bookmark', 'bookmarks')}',
      n == 1
          ? 'NIARIM bookmark ranking #1'
          : 'Top $n on NIARIM bookmark ranking',
      one ? '$n work reaches 3 bookmarks' : '$n works each reach 3 bookmarks',
      'Publish ${c('work', 'works')}',
      'Server-recorded candidate time: $n min (not reward-verified)',
    ],
    'es' => [
      'Reclamar todo',
      'Total ${c('día', 'días')}',
      '${c('moneda', 'monedas')} al día',
      '${c('día', 'días')} de acceso',
      c('moneda', 'monedas'),
      'Inicia sesión ${c('día', 'días')} esta semana',
      '$n / ${c('día', 'días')} · ${c('moneda', 'monedas')}',
      'Mantén abierta la Plaza de Obras $hoursOrMinutes en total',
      '${c('minuto', 'minutos')} / $hoursOrMinutes · ${c('moneda', 'monedas')}',
      'Sin completar',
      'Diarias',
      'Semanales',
      c('seguidor', 'seguidores'),
      one
          ? '$n hora de creación verificada'
          : '$n horas de creación verificadas',
      n == 0
          ? 'Publicar una obra'
          : 'Una obra alcanza ${c('marcador', 'marcadores')}',
      n == 0 ? 'Sky se publica' : 'Sky alcanza ${c('marcador', 'marcadores')}',
      n == 1
          ? 'Primer puesto en la clasificación de marcadores'
          : 'Entre los primeros $n en marcadores',
      one
          ? '$n obra logra 3 marcadores'
          : '$n obras logran 3 marcadores cada una',
      'Publicar ${c('obra', 'obras')}',
      'Tiempo candidato registrado: $n min (sin verificar)',
    ],
    _ => [
      'Tout réclamer',
      'Total : ${c('jour', 'jours')}',
      '${c('pièce', 'pièces')} par jour',
      '${c('jour', 'jours')} de connexion',
      c('pièce', 'pièces'),
      'Se connecter ${c('jour', 'jours')} cette semaine',
      '$n / ${c('jour', 'jours')} · ${c('pièce', 'pièces')}',
      'Garder la Place des œuvres ouverte $hoursOrMinutes au total',
      '${c('minute', 'minutes')} / $hoursOrMinutes · ${c('pièce', 'pièces')}',
      'Non atteint',
      'Quotidiennes',
      'Hebdomadaires',
      c('abonné', 'abonnés'),
      one ? '$n heure de création vérifiée' : '$n heures de création vérifiées',
      n == 0
          ? 'Publier une œuvre'
          : 'Une œuvre atteint ${c('favori', 'favoris')}',
      n == 0 ? 'Sky est publiée' : 'Sky atteint ${c('favori', 'favoris')}',
      n == 1
          ? '1re place du classement des favoris'
          : 'Top $n du classement des favoris',
      one
          ? '$n œuvre atteint 3 favoris'
          : '$n œuvres atteignent chacune 3 favoris',
      'Publier ${c('œuvre', 'œuvres')}',
      'Temps candidat enregistré : $n min (non vérifié)',
    ],
  };
}

List<String> _activityTexts(String locale, int n) {
  final one = _one(locale, n);
  String c(String singular, String plural) => '$n ${one ? singular : plural}';
  return switch (locale) {
    'en' => [
      'Reached ${c('follower', 'followers')}',
      'Sky reached ${c('bookmark', 'bookmarks')}',
      n == 0
          ? 'You published 0 works'
          : one
          ? 'Your published work reached 1 bookmark'
          : 'Your $n published works each reached ${c('bookmark', 'bookmarks')}',
      'You published ${c('work', 'works')}',
      'You reached ${c('total login day', 'total login days')}',
      'Published Sky',
      'Your 0 published works each reached 3 bookmarks',
    ],
    'es' => [
      'Alcanzaste ${c('seguidor', 'seguidores')}',
      'Sky alcanzó ${c('marcador', 'marcadores')}',
      n == 0
          ? 'Publicaste 0 obras'
          : one
          ? 'Tu obra alcanzó 1 marcador'
          : 'Tus $n obras alcanzaron ${c('marcador', 'marcadores')} cada una',
      'Publicaste ${c('obra', 'obras')}',
      '¡Has alcanzado ${c('día', 'días')} de acceso!',
      'Publicaste Sky',
      'Tus 0 obras alcanzaron 3 marcadores cada una',
    ],
    _ => [
      'Vous avez atteint ${c('abonné', 'abonnés')}',
      'Sky a atteint ${c('favori', 'favoris')}',
      n == 0
          ? 'Vous avez publié 0 œuvre'
          : one
          ? '$n œuvre publiée a atteint ${c('favori', 'favoris')}'
          : 'Vos $n œuvres ont chacune atteint ${c('favori', 'favoris')}',
      'Vous avez publié ${c('œuvre', 'œuvres')}',
      'Vous avez atteint ${c('jour', 'jours')} de connexion',
      'Vous avez publié Sky',
      // フランス語の0は単数。1つの作品の文（「Votre œuvre」）にしない。
      '0 œuvre publiée a atteint 3 favoris',
    ],
  };
}

List<String> _completionTexts(String locale, int n) {
  final one = _one(locale, n);
  String c(String singular, String plural) => '$n ${one ? singular : plural}';
  return switch (locale) {
    'en' => [
      'Mission completed!',
      'Visit on ${c('day', 'days')} this week',
      'Visit on ${c('day', 'days')} this month',
      'Visit on ${c('day', 'days')} in total',
      'Go to Missions',
    ],
    'es' => [
      '¡Misión completada!',
      'Entra ${c('día', 'días')} esta semana',
      'Entra ${c('día', 'días')} este mes',
      'Entra ${c('día', 'días')} en total',
      'Ir a Misiones',
    ],
    _ => [
      'Mission accomplie !',
      'Se connecter ${c('jour', 'jours')} cette semaine',
      'Se connecter ${c('jour', 'jours')} ce mois-ci',
      'Se connecter ${c('jour', 'jours')} au total',
      'Aller aux missions',
    ],
  };
}

Map<String, String> _coinWords(int n) => {
  'en': '$n ${_one('en', n) ? 'coin' : 'coins'}',
  'es': '$n ${_one('es', n) ? 'moneda' : 'monedas'}',
  'fr': '$n ${_one('fr', n) ? 'pièce' : 'pièces'}',
};

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

Future<void> _pumpMissions(
  WidgetTester tester,
  String locale,
  CommunityService community,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 8000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
        ChangeNotifierProvider<CommunityService>.value(value: community),
        ChangeNotifierProvider<ProjectService>.value(value: ProjectService()),
        ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
      ],
      child: _app(locale, const CreatorMissionsScreen()),
    ),
  );
  await _settle(tester);
  await tester.tap(find.byKey(const Key('loginMilestoneExpansion')));
  await tester.pumpAndSettle();
}

/// 残高[balance]・全機能1か月[price]コインで交換でき、[activeUntil]まで
/// コインの全機能を使っているサーバー。
CommunityService _rewardServer({
  required int balance,
  int price = 55000,
  DateTime? activeUntil,
}) => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.method != 'GET') return _json({'redeemed': false});
        return _json(switch (request.url.path) {
          '/me/rewards' => {
            'balanceCoins': balance,
            'redemptionEnabled': true,
            'entitlements': [
              if (activeUntil != null)
                {
                  'feature': 'fullPremium',
                  'status': 'active',
                  'expiresAtEpochMs': activeUntil.millisecondsSinceEpoch,
                },
            ],
          },
          '/me/rewards/quote' => {
            'enabled': true,
            'priceCoins': price,
            'priceVersion': 'v1-test',
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

Future<PremiumService> _pumpRewards(
  WidgetTester tester,
  String locale,
  CommunityService community, {
  Map<CoinUnlockTarget, CoinUnlockUnitPrices> priceCatalog = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 6000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final premium = PremiumService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PremiumService>.value(value: premium),
        ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
        ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
        ChangeNotifierProvider<CommunityService>.value(value: community),
      ],
      child: _app(locale, RewardUnlockScreen(priceCatalog: priceCatalog)),
    ),
  );
  await _settle(tester);
  return premium;
}

/// 期間のシートで1か月を選ぶ。
Future<void> _pickOneMonth(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rewardDurationButton')));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(ExpansionTile).at(CoinDurationUnit.month.index),
          matching: find.byType(ListTile),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('rewardDuration_month_1')));
  await tester.pumpAndSettle();
}

/// 開いているダイアログの題と本文の文字列。
List<String> _dialogTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

/// ARBの文言から、`{x, plural, ...}`ごとに（変数, 選択子→中身）を返す。
/// 入れ子の`plural`も返す。
List<(String, Map<String, String>)> _pluralBlocks(String message) {
  final out = <(String, Map<String, String>)>[];
  final head = RegExp(r'\{\s*(\w+)\s*,\s*plural\s*,');
  var from = 0;
  while (true) {
    final match = head.firstMatch(message.substring(from));
    if (match == null) break;
    final variable = match.group(1)!;
    var i = from + match.end;
    final blockStart = i;
    var depth = 1;
    while (depth > 0) {
      final ch = message[i++];
      if (ch == '{') depth++;
      if (ch == '}') depth--;
    }
    final block = message.substring(blockStart, i - 1);
    final selector = RegExp(r'\s*(=?\w+)\s*\{');
    final branches = <String, String>{};
    out.add((variable, branches));
    var p = 0;
    while (p < block.length) {
      final s = selector.matchAsPrefix(block, p);
      if (s == null) break;
      var q = s.end;
      var d = 1;
      while (d > 0) {
        final ch = block[q++];
        if (ch == '{') d++;
        if (ch == '}') d--;
      }
      final body = block.substring(s.end, q - 1);
      branches[s.group(1)!] = body;
      out.addAll(_pluralBlocks(body));
      p = q;
    }
    from = i;
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  final cases = <(String, int)>[
    for (final locale in ['en', 'es', 'fr'])
      for (final n in [1, 2]) (locale, n),
    // フランス語の0は単数（CLDR）。
    ('fr', 0),
  ];

  for (final (locale, n) in cases) {
    testWidgets('ミッション画面の数と単位（$locale, $n）', (tester) async {
      await _pumpMissions(tester, locale, _serviceWithCounts(n));
      final texts = _shownTexts(tester);
      for (final expected in _missionScreenTexts(locale, n)) {
        expect(texts, contains(expected), reason: '$locale: $texts');
      }
      if (n != 0) _expectNoBrokenUnits(texts);

      // 達成条件のダイアログのコインの行も、その言語の数と単位で出る。
      await tester.tap(
        find.byKey(const ValueKey('missionDetails_followers_n:template')),
      );
      await tester.pumpAndSettle();
      final details = _dialogTexts(tester).join('\n\n').split('\n\n');
      expect(details, contains(_coinWords(n)[locale]), reason: '$details');
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
      for (final expected in _activityTexts(locale, n)) {
        expect(texts, contains(expected), reason: '$locale: $texts');
      }
      if (n != 0) _expectNoBrokenUnits(texts);
      await tester.pumpWidget(const SizedBox.shrink());
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
      final unit = _coinWords(n)[locale]!;
      if (n == 0) {
        // 増減の無い取引には符号を付けない。
        expect(find.text(unit), findsNWidgets(2));
      } else {
        expect(find.text('+$unit'), findsOneWidget);
        expect(find.text('-$unit'), findsOneWidget);
      }
      if (n != 0) _expectNoBrokenUnits(_shownTexts(tester));
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
      for (final expected in _completionTexts(locale, n)) {
        expect(texts, contains(expected), reason: '$locale: $texts');
      }
      if (n != 0) _expectNoBrokenUnits(texts.split('\n'));
      await tester.tap(find.byKey(const Key('missionCompletedClose')));
      await tester.pumpAndSettle();
      await shown;
    });
  }

  for (final locale in ['en', 'es', 'fr']) {
    for (final n in [1, 2]) {
      testWidgets('特典交換の必要コイン・残高・合計（$locale, $n）', (tester) async {
        final premium = await _pumpRewards(
          tester,
          locale,
          _rewardServer(balance: n),
          priceCatalog: {
            CoinUnlockTarget.toneCurve: CoinUnlockUnitPrices(
              perHour: n,
              perDay: 20,
              perWeek: 110,
              perMonth: 450,
            ),
          },
        );
        final coin = _coinWords(n)[locale]!;
        // 残高と、価格の決まったトーンカーブの行の2つ。
        expect(find.text(coin), findsNWidgets(2));
        final row = find.byKey(const ValueKey('rewardFeature_toneCurve'));
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

        // 価格の決まった特典だけを選ぶと、合計はその必要コイン。
        await tester.tap(row);
        await tester.pumpAndSettle();
        final total = find.byKey(const Key('rewardTotalCoins'));
        expect(tester.widget<Text>(total).data, coin);

        expect(find.byKey(const Key('rewardTotalReferenceNote')), findsNothing);

        // 価格の決まっていない特典も選ぶと、参考価格の合計になる。参考価格の
        // 注記は合計の見出しにつながず、下の別の行に出る。
        await tester.tap(find.byKey(const ValueKey('rewardFeature_watermark')));
        await tester.pumpAndSettle();
        const hour = CoinUnlockDuration(1, CoinDurationUnit.hour);
        final referenceTotal =
            CoinBenefitPriceProposal.cost(CoinUnlockTarget.toneCurve, hour) +
            CoinBenefitPriceProposal.cost(CoinUnlockTarget.watermark, hour);
        final l10n = lookupAppLocalizations(Locale(locale));
        expect(
          tester.widget<Text>(total).data,
          l10n.coinAmount(referenceTotal),
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('rewardTotalReferenceNote')))
              .data,
          reference,
        );
        _expectNoBrokenUnits(_shownTexts(tester));
        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });
    }
  }

  for (final locale in ['en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    final appLocale = locale == 'zh_Hant'
        ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
        : Locale(locale);
    testWidgets('重複・有効期限の確認と交換の確認がその言語で出る（$locale）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 6000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final premium = PremiumService();
      final activeUntil = DateTime.now().add(const Duration(days: 9));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<SettingsService>.value(
              value: SettingsService(),
            ),
            ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
            ChangeNotifierProvider<CommunityService>.value(
              value: _rewardServer(balance: 60000, activeUntil: activeUntil),
            ),
          ],
          child: MaterialApp(
            locale: appLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RewardUnlockScreen(),
          ),
        ),
      );
      await _settle(tester);
      final l10n = lookupAppLocalizations(appLocale);
      final foreign = locale == 'ko' || locale.startsWith('zh') ? _kana : _cjk;

      // 単品の特典を2つ選んで、重複・有効期限の確認を開く。
      await tester.tap(find.byKey(const ValueKey('rewardFeature_toneCurve')));
      await tester.tap(find.byKey(const ValueKey('rewardFeature_allAds')));
      await tester.tap(find.byKey(const ValueKey('rewardFeature_canvasAds')));
      await tester.pumpAndSettle();
      final review = find.byKey(const Key('rewardOverlapPreviewButton'));
      final buttonLabel = tester
          .widget<Text>(
            find.descendant(of: review, matching: find.byType(Text)),
          )
          .data!;
      expect(foreign.hasMatch(buttonLabel), isFalse, reason: buttonLabel);
      await tester.tap(review);
      await tester.pumpAndSettle();
      final reviewTexts = _dialogTexts(tester);
      for (final text in reviewTexts) {
        expect(foreign.hasMatch(text), isFalse, reason: '$locale: $text');
      }
      const hour = CoinUnlockDuration(1, CoinDurationUnit.hour);
      final referenceTotal = [
        CoinUnlockTarget.toneCurve,
        CoinUnlockTarget.allAds,
        CoinUnlockTarget.canvasAds,
      ].fold<int>(0, (s, t) => s + CoinBenefitPriceProposal.cost(t, hour));
      final body = reviewTexts.join('\n');
      expect(body, contains(l10n.coinAmount(referenceTotal)));
      expect(body, isNot(contains('$referenceTotal コイン')));
      await tester.tap(find.byKey(const Key('rewardOverlapReviewClose')));
      await tester.pumpAndSettle();

      // 全機能1か月だけにして、交換の確認を開く（利用中なので延長の文が出る）。
      for (final key in ['toneCurve', 'allAds', 'canvasAds', 'fullPremium']) {
        await tester.tap(find.byKey(ValueKey('rewardFeature_$key')));
      }
      await tester.pumpAndSettle();
      await _pickOneMonth(tester);
      // サーバーが決めた価格（全機能1か月）の合計も、その言語の数と単位。
      expect(
        tester.widget<Text>(find.byKey(const Key('rewardTotalCoins'))).data,
        l10n.coinAmount(55000),
      );
      await tester.tap(find.byKey(const Key('rewardRedeemButton')));
      await tester.pumpAndSettle();
      final redeemTexts = _dialogTexts(tester);
      expect(redeemTexts.join('\n'), contains(l10n.coinAmount(55000)));
      for (final text in redeemTexts) {
        expect(foreign.hasMatch(text), isFalse, reason: '$locale: $text');
      }
      // 確認だけして交換はしない。
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      premium.dispose();
    });
  }

  for (final (locale, daily, milestone, coins, spaced) in [
    ('ja', '毎日1コイン', '累計1日達成', '1コイン', RegExp(r'\d コイン')),
    ('ko', '매일 1코인', '누적 1일 달성', '1코인', RegExp(r'\d 코인')),
    ('zh', '每日 1 金币', '累计登录 1 天', '1 金币', RegExp(r'\d金币')),
  ]) {
    testWidgets('累計ログインの毎日のコインと節目のコインが同じ書き方（$locale）', (tester) async {
      await _pumpMissions(tester, locale, _serviceWithCounts(1));
      final texts = _shownTexts(tester);
      final panel = find.byKey(const Key('loginBonusPanel'));
      expect(
        find.descendant(of: panel, matching: find.text(daily)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text(milestone)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text(coins)),
        findsOneWidget,
      );
      for (final text in texts) {
        expect(spaced.hasMatch(text), isFalse, reason: '$locale: $text');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('同じ日本語の文言は、英語でも同じ意味の文言になる', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ja = lookupAppLocalizations(const Locale('ja'));
    // 「受取を確認できませんでした」（失敗とは言い切れない）。
    expect(ja.missionClaimUnconfirmed, ja.loginBonusFailed);
    expect(en.missionClaimUnconfirmed, en.loginBonusFailed);
    // 「未達成」（同じ画面のログインボーナスとクリエイターミッションと揃える）。
    expect(ja.missionNotYet, ja.loginBonusNotYet);
    expect(en.missionNotYet, en.loginBonusNotYet);
    expect(en.missionNotYet, en.creatorMissionNotAchieved);
    // 作品広場の滞在は合計の時間（スペイン語・フランス語・中国語も合計）。
    expect(en.plazaMissionGoal('1 hour'), contains('in total'));
  });

  test('フランス語の単数（0と1）の文は数を含む', () {
    // フランス語のCLDRの`one`は0と1。数を書かない`one`の文（「Votre œuvre」）は
    // 0のときに1つの作品の文になる。gen-l10nは`=1`と`one`を同じ引数に
    // まとめる（Intl.pluralLogicの`one`）ので、`=1`で分けることもできない。
    // 0の文（`=0`）があれば0はそちらへ行くので、数の無い`one`でもよい。
    final data =
        json.decode(File('lib/l10n/app_fr.arb').readAsStringSync())
            as Map<String, dynamic>;
    final numberless = <String>[];
    data.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      for (final (variable, branches) in _pluralBlocks(value)) {
        if (branches.containsKey('=0') || branches.containsKey('zero')) {
          continue;
        }
        for (final selector in ['one', '=1']) {
          final body = branches[selector];
          if (body != null && !body.contains('{$variable}')) {
            numberless.add('$key: $body');
          }
        }
      }
    });
    expect(numberless, isEmpty, reason: numberless.join('\n'));
    // 走査そのものが分岐を拾えていること。
    expect(
      _pluralBlocks(
        data['creatorMissionActivityWorksBookmarks'] as String,
      ).first.$2.keys,
      containsAll(<String>['one', 'other']),
    );
  });
}
