// ランキングのミッション（受取の条件・足りない条件・順位の計算方法）と、
// 期間・作品広場のミッションの「達成条件」ダイアログが、どの言語でもその
// 言語の文で、数と単位をその言語の単数・複数で出すことを本物の画面で確かめる。
//
// これらの文言は日本語と英語だけで足され（スペイン語・フランス語・韓国語では
// 英語が出ていた）、英語でも「1 published works」「1 days」「1 coins」の
// ように、数と単位の語をコードでつないでいた。日本語の画面は、どの行を
// どの条件で出すかを含めて元の作りのままであることも確かめる。
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
  String get id => 'ranking-l10n-account';
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
CommunityService _server(int n) => CommunityService(
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
          Map<String, Object?> extra = const {},
        }) => {
          'id': id,
          'kind': kind,
          'required': required,
          'eachWorkBookmarks': ?each,
          'progress': n,
          'coins': n,
          'claimed': false,
          'eligible': false,
          'readyForClaim': false,
          'rewardEnabled': true,
          'perWork': false,
          ...extra,
        };
        return _json(switch (path) {
          '/me/missions' => {
            'enabled': true,
            'candidateEditSeconds': n * 60,
            'verifiedEditSeconds': n * 60,
            'editTimeVerificationReady': false,
            'publishedWorkCount': n,
            'missions': [
              // 公開作品数・ブックマーク・順位が足りない作品。
              mission(
                'rank_n',
                'niarimBookmarkRanking',
                n,
                extra: {
                  'rankingUnmetConditions': [
                    'communityTooSmall',
                    'notEnoughBookmarks',
                    'rankTooLow',
                  ],
                  'rankingPopulationKnown': true,
                  'rankingMinPublishedWorks': n,
                  'rankingMinBookmarks': n,
                  'rankingWorkBookmarks': n,
                  'rankingEffectiveRankLimit': n,
                  'rankingTopPercent': n,
                },
              ),
              // 作品を選んでいない・公開していない・集計中・圏外。
              mission(
                'rank_other_n',
                'niarimBookmarkRanking',
                n + 1,
                extra: {
                  'progress': 0,
                  'rankingUnmetConditions': [
                    'selectWork',
                    'workNotPublic',
                    'communityNotMeasured',
                    'notRanked',
                  ],
                },
              ),
              mission('bookmarks_n', 'workBookmarks', n),
              mission('works_n', 'qualifiedWorks', n, each: n),
              mission('followers_n', 'followers', n),
              mission('time_n', 'verifiedEditSeconds', n * 3600),
            ],
          },
          '/me/missions/grid' => {'missions': [], 'rewardEnabled': true},
          '/me/missions/work-achievements' => {'items': [], 'nextCursor': null},
          '/me/login-bonus' => {
            'totalDays': n,
            'visitedToday': true,
            'dailyCoins': n,
            'dailyClaimed': true,
            'rewardEnabled': true,
            'milestones': [],
          },
          '/me/missions/recurring' => {
            'enabled': false,
            'missions': [
              for (final period in ['week', 'month'])
                {
                  'id': 'visit_${period}_n',
                  'period': period,
                  'requiredDays': n,
                  'progressDays': n,
                  'coins': n,
                  'claimed': false,
                  'eligible': false,
                },
            ],
          },
          '/me/missions/plaza' => {
            'enabled': false,
            'missions': [
              {
                'id': 'plaza_day_n',
                'period': 'day',
                'requiredSeconds': n * 60,
                'progressSeconds': n * 60,
                'coins': n,
                'claimed': false,
                'eligible': false,
              },
            ],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pump(WidgetTester tester, String locale, int n) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 8000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
        ChangeNotifierProvider<CommunityService>.value(value: _server(n)),
        ChangeNotifierProvider<ProjectService>.value(value: ProjectService()),
        ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CreatorMissionsScreen(),
      ),
    ),
  );
  await _settle(tester);
}

List<String> _texts(WidgetTester tester, [Finder? within]) => [
  for (final text in tester.widgetList<Text>(
    within == null
        ? find.byType(Text)
        : find.descendant(of: within, matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

/// 達成条件のボタンを押して出た文をすべて集め、閉じる。
Future<String> _details(WidgetTester tester, Key key) async {
  final button = find.byKey(key);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget, reason: '$key');
  final text = _texts(tester, dialog).join('\n\n');
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)),
  );
  await tester.pumpAndSettle();
  return text;
}

/// 画面の文・押して出るダイアログの文・ボタンの説明（tooltip）をすべて集める。
Future<List<String>> _everything(WidgetTester tester) async {
  final shown = <String>[
    ..._texts(tester),
    for (final button in tester.widgetList<IconButton>(find.byType(IconButton)))
      ?button.tooltip,
  ];
  for (final key in <Key>[
    const ValueKey('missionDetails_rank_n:template'),
    const ValueKey('missionDetails_rank_other_n:template'),
    const ValueKey('missionDetails_bookmarks_n:template'),
    const ValueKey('missionDetails_works_n:template'),
    const ValueKey('missionDetails_followers_n:template'),
    const ValueKey('missionDetails_time_n:template'),
    const Key('recurringMissionDetails_visit_week_n'),
    const Key('recurringMissionDetails_visit_month_n'),
    const ValueKey('plazaMissionDetails_plaza_day_n'),
  ]) {
    shown.addAll((await _details(tester, key)).split('\n\n'));
  }
  return shown;
}

/// 日本語の仮名と漢字（英語・スペイン語・フランス語・韓国語に出てはいけない）。
final _japanese = RegExp('[぀-ヿ一-鿿]');

/// 日本語と英語だけで足された文の英語（ほかの言語では訳が出るはず）。
const _englishOnly = [
  'Not enough bookmarks',
  'Community too small',
  'Select a work',
  'not currently published',
  'still being counted',
  'not currently in the top',
  'Current rank',
  'Published NIARIM works',
  'Bookmarks on this work',
  'Eligibility:',
  'Required live rank',
  'Server-clock-validated',
  'Local editing activity',
  'has not finished counting',
  'RANK CALCULATION',
  'CLAIM TIMING',
  'WORK BOOKMARKS',
  'MULTIPLE WORKS',
  'FOLLOWERS:',
  'EDITING TIME',
  'CLAIMING:',
  'View mission details',
  'Mission details',
  'CONDITIONS:',
  'CLAIM:',
  'Sign in on',
  'Time is measured',
  'Periods use Japan time',
  'Current open time',
  'Current progress',
  'Goal not yet completed',
  'Goal completed',
  'Already claimed for this period',
  'Coin payouts are currently unavailable',
  'NIARIM bookmark ranking #1',
];

/// 1つの数に複数形の単位の語を付けた誤り（「1 published works」「1 days」等。
/// 間に形容詞などの語が1つ入る形も見る）。フランス語は0も単数だが、
/// ここでは1と2だけを出す。
final _pluralAfterOne = RegExp(
  r'(^|[^0-9.,])1 (?:[\p{L}-]+ )?'
  r'(hours|days|coins|followers|bookmarks|minutes|works|places|'
  r'horas|días|monedas|seguidores|marcadores|minutos|obras|puestos|'
  r'heures|jours|pièces|abonnés|favoris|œuvres|minutes)(?![\p{L}])',
  unicode: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  for (final locale in ['en', 'es', 'fr', 'ko']) {
    for (final n in [1, 2]) {
      testWidgets('ランキング・期間・作品広場のミッションの文（$locale, $n）', (tester) async {
        await _pump(tester, locale, n);
        final shown = await _everything(tester);
        final problems = <String>[
          for (final text in shown)
            if (_japanese.hasMatch(text)) '日本語が出ている: $text',
          if (locale != 'en')
            for (final text in shown)
              for (final english in _englishOnly)
                if (text.contains(english)) '英語のまま（$english）: $text',
          for (final text in shown)
            if (_pluralAfterOne.hasMatch(text)) '1つなのに複数形: $text',
        ];
        expect(problems, isEmpty, reason: problems.join('\n'));
        if (locale == 'en') {
          String c(String one, String other) => '$n ${n == 1 ? one : other}';
          final expected = [
            n == 1
                ? 'NIARIM bookmark ranking #1'
                : 'Top $n on NIARIM bookmark ranking',
            'Community too small: ${c('published work', 'published works')}'
                ' / $n required',
            'Eligibility: at least ${c('published work', 'published works')}'
                ' and ${c('bookmark', 'bookmarks')} on this work',
            'Sign in on ${c('day', 'days')} this week',
            'Sign in on ${c('day', 'days')} this month',
            'Current progress: $n / ${c('day', 'days')}',
          ];
          for (final text in expected) {
            expect(shown, contains(text), reason: shown.join('\n'));
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  // 日本語は元の文のまま、同じ条件で同じ行が出る。
  for (final n in [1, 2]) {
    testWidgets('日本語のランキングの達成条件は元のまま（$n）', (tester) async {
      await _pump(tester, 'ja', n);
      final rank = await _details(
        tester,
        const ValueKey('missionDetails_rank_n:template'),
      );
      final rankLines = [
        n == 1 ? 'ブックマークランキング1位' : 'ブックマークランキング$n位以内',
        '未達成',
        'NIARIM公開作品：現在$n件',
        '対象作品のブックマーク：現在$n件',
        '対象作品の現在順位：$n位',
        '公開作品数が不足：現在$n件／必要$n件',
        'ブックマーク不足：現在$n件／必要$n件',
        '現在$n位／条件は$n位以内（上位割合も適用）',
        '受取条件: NIARIMの公開作品が$n件以上、この作品のブックマークが$n件以上',
        '現在の公開作品数で必要な順位: $n位以内',
        '【順位の計算方法】NIARIMで公開中の自分の作品が対象です。全体の公開作品が'
            '100件以上で、作品のブックマーク数が指定件数以上、かつランキング$n位以内・'
            '全体の上位$n％以内を同時に満たす必要があります。',
        '【受取のタイミング】ランキングは随時更新されます。',
        'この条件の報酬はアカウントにつき1回限りです。',
      ];
      var from = 0;
      for (final line in rankLines) {
        final at = rank.indexOf(line, from);
        expect(at, greaterThanOrEqualTo(0), reason: '「$line」が無い: $rank');
        from = at + line.length;
      }
      expect(rank, isNot(contains('【受取方法】')));

      final other = await _details(
        tester,
        const ValueKey('missionDetails_rank_other_n:template'),
      );
      from = 0;
      for (final line in [
        '公開作品数のサーバー集計がまだ完了していません',
        '作品を選択すると現在の達成状況を確認できます',
        'この作品は現在公開されていません',
        '全体の公開作品数を集計中です。集計が終わるまで受取できません',
        '対象作品が現在のランキング50位以内に入っていません',
        '【受取のタイミング】',
      ]) {
        final at = other.indexOf(line, from);
        expect(at, greaterThanOrEqualTo(0), reason: '「$line」が無い: $other');
        from = at + line.length;
      }
      expect(other, isNot(contains('対象作品の現在順位')));
      expect(other, isNot(contains('受取条件:')));

      final time = await _details(
        tester,
        const ValueKey('missionDetails_time_n:template'),
      );
      expect(time, contains('【制作時間の条件】'));
      expect(time, isNot(contains('【受取方法】')));
      final followers = await _details(
        tester,
        const ValueKey('missionDetails_followers_n:template'),
      );
      expect(followers, contains('【フォロワーの条件】'));
      expect(followers, contains('【受取方法】'));

      final texts = _texts(tester);
      expect(texts, contains('サーバー時刻で検証した制作時間: $n分'));
      expect(texts, contains('制作時間は端末側で偽装可能なため、現在コイン報酬の対象外です。計測した時間は参考値です。'));
      expect(texts, contains('週に$n日ログイン'));
      expect(texts, contains('月に$n日ログイン'));
      final week = await _details(
        tester,
        const Key('recurringMissionDetails_visit_week_n'),
      );
      expect(week, contains('同じ週（月曜日から日曜日）内に、異なる日付で$n日以上ログイン'));
      expect(week, contains('現在の達成日数：$n / $n'));
      expect(week, contains('【受取】条件を満たすと$nコインを受け取れます。'));
      expect(week, contains('コインの受取機能は現在準備中です。'));
      final plaza = await _details(
        tester,
        const ValueKey('plazaMissionDetails_plaza_day_n'),
      );
      expect(plaza, contains('【達成条件】デイリーの期間中、NIARIMの作品広場を開いている時間の合計が$n分以上'));
      expect(plaza, contains('現在の閲覧時間：$n分 / $n分'));
      expect(plaza, contains('まだ達成条件を満たしていません。'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
