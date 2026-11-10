// ミッション画面の行（作品広場の滞在・ウィークリー／マンスリー・累計ログインの
// 節目・クリエイターミッション）で、題と説明の文が単語や数の途中で改行されない
// ことを、本物のフォント・テーマ・スマホの幅で確かめる。
//
// 以前は受け取るボタン（「Réclamer」「Sin completar」等）を行の右端に置いて
// いて、スペイン語・フランス語ではボタンが行の幅の大半を取り、題が35px
// ほどの列に押し込まれて「Man|tén abie|rta」「10|0000 heures」のように
// 単語・数の途中で折り返していた。文字を2倍にすると1文字ずつ縦に並んだ。
//
// 欄の見出し（作品広場の滞在・ウィークリー／マンスリー・累計ログイン）は、
// 先頭のアイコンと右端の更新ボタンの間の216pxに押し込まれていて、文字1.75倍・
// 2倍のフランス語で「Missions heb|domadaires」「hebdomada|ires」と切れていた。
// 見出しはカードの幅いっぱい（296px）まで使えるので、それより狭い語が切れたら
// 配置の誤り。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'mission-row-layout';
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

/// サーバーの定義どおりのミッション（作品広場は5分〜40時間、ウィークリーは
/// 3・5・7日、マンスリーは10・20・25日）に、大きな数の行を1つずつ足した応答。
CommunityService _service() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') return _json({'visitedToday': true});
        return _json(switch (path) {
          '/me/missions' => {
            'enabled': true,
            'candidateEditSeconds': 5400,
            'missions': [
              {
                'id': 'followers_100',
                'kind': 'followers',
                'required': 100,
                'progress': 12,
                'coins': 30,
                'claimed': false,
                'eligible': false,
                'readyForClaim': false,
                'rewardEnabled': true,
                'perWork': false,
              },
              {
                'id': 'time_10',
                'kind': 'verifiedEditSeconds',
                'required': 36000,
                'coins': 10,
                'claimed': false,
                'eligible': true,
                'readyForClaim': true,
                'rewardEnabled': true,
                'perWork': false,
              },
            ],
          },
          '/me/missions/grid' => {'missions': [], 'rewardEnabled': true},
          '/me/missions/work-achievements' => {'items': [], 'nextCursor': null},
          '/me/login-bonus' => {
            'totalDays': 31,
            'visitedToday': true,
            'dailyCoins': 1,
            'dailyClaimed': false,
            'rewardEnabled': true,
            'milestones': [
              {'days': 7, 'coins': 5, 'claimed': true, 'eligible': true},
              {'days': 30, 'coins': 20, 'claimed': false, 'eligible': true},
              {'days': 100, 'coins': 50, 'claimed': false, 'eligible': false},
              {
                'days': 100000,
                'coins': 100000,
                'claimed': false,
                'eligible': false,
              },
            ],
          },
          '/me/missions/recurring' => {
            'enabled': true,
            'missions': [
              for (final (days, coins, progress) in [
                (3, 2, 3),
                (5, 3, 3),
                (7, 4, 3),
              ])
                {
                  'id': 'visit_week_$days',
                  'period': 'week',
                  'requiredDays': days,
                  'progressDays': progress,
                  'coins': coins,
                  'claimed': false,
                  'eligible': progress >= days,
                },
              for (final (days, coins) in [(10, 4), (20, 6), (25, 8)])
                {
                  'id': 'visit_month_$days',
                  'period': 'month',
                  'requiredDays': days,
                  'progressDays': 12,
                  'coins': coins,
                  'claimed': days == 10,
                  'eligible': days <= 12,
                },
            ],
          },
          '/me/missions/plaza' => {
            'enabled': true,
            'missions': [
              for (final (id, period, seconds, coins) in [
                ('day_5m', 'day', 300, 1),
                ('day_15m', 'day', 900, 1),
                ('day_60m', 'day', 3600, 2),
                ('week_6h', 'week', 21600, 4),
                ('month_40h', 'month', 144000, 8),
                ('month_huge', 'month', 360000000, 100000),
              ])
                {
                  'id': 'plaza_$id',
                  'period': period,
                  'requiredSeconds': seconds,
                  'progressSeconds': 1200,
                  'coins': coins,
                  'claimed': false,
                  'eligible': seconds <= 1200,
                },
            ],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

bool _isWordChar(int rune) {
  final char = String.fromCharCode(rune);
  return RegExp(r'[\p{Script=Latin}\p{Nd}]', unicode: true).hasMatch(char);
}

/// 360dpの画面で、行の文が使える幅（一覧の余白32・カードの外と内の余白
/// 32・先頭のアイコンと間40・行の終わりの余白か更新ボタン40を除いた幅）。
/// これより広い語（文字2倍の「hebdomadaires」等）は、どう並べても途中で
/// 切れるので数えない。
const _widestPlaceableWord = 360.0 - 144;

/// 欄の見出しが使える幅（一覧の余白32・カードの外と内の余白32を除いた、
/// カードの中身の幅）。
const _panelContentWidth = 360.0 - 64;

/// [paragraph]の中で、文字（ラテン文字・数字）どうしの間で行が変わる所を
/// 「前の行の最後の語｜次の行の最初の語」の形で返す。
List<String> _breaksInsideWords(
  RenderParagraph paragraph, {
  double widestPlaceableWord = _widestPlaceableWord,
}) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final broken = <String>[];
  double? previousTop;
  for (var i = 0; i < text.length; i++) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final top = boxes.first.top;
    if (previousTop != null &&
        top > previousTop + 1 &&
        i > 0 &&
        _isWordChar(text.codeUnitAt(i - 1)) &&
        _isWordChar(text.codeUnitAt(i))) {
      var start = i - 1;
      while (start > 0 && _isWordChar(text.codeUnitAt(start - 1))) {
        start--;
      }
      var end = i + 1;
      while (end < text.length && _isWordChar(text.codeUnitAt(end))) {
        end++;
      }
      // 語そのものが行に置ける幅より広いなら、どこかで切れるのは避けられ
      // ない。それより狭い語が切れたら配置の誤り（文の列が狭すぎる）。
      final wordWidth = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          )
          .fold<double>(0, (sum, box) => sum + box.right - box.left);
      if (wordWidth <= widestPlaceableWord) {
        broken.add(
          '${text.substring(start, i)}|${text.substring(i, end)}  ($text)',
        );
      }
    }
    previousTop = top;
  }
  return broken;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  for (final locale in ['fr', 'es', 'en', 'ja']) {
    for (final scale in [1.0, 1.3, 1.75, 2.0]) {
      testWidgets('ミッションの行が単語の途中で折り返さない（$locale, 文字$scale倍, 360dp）', (
        tester,
      ) async {
        await loadAppFonts(tester);
        final themes = ThemeService();
        await themes.init();
        addTearDown(themes.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 40000);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final settings = SettingsService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<GoogleAuthService>.value(
                value: _SignedIn(),
              ),
              ChangeNotifierProvider<CommunityService>.value(value: _service()),
              ChangeNotifierProvider<ProjectService>.value(
                value: ProjectService(),
              ),
              ChangeNotifierProvider<SettingsService>.value(value: settings),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              theme: themes.themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CreatorMissionsScreen(),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.tap(find.byKey(const Key('loginMilestoneExpansion')));
        await tester.pumpAndSettle();

        // 3つの欄とクリエイターミッションの行が実際に出ていること（出ていなければ
        // 何も確かめていないことになる）。
        expect(find.byKey(const Key('plazaMissionsPanel')), findsOneWidget);
        expect(find.byKey(const Key('recurringMissionsPanel')), findsOneWidget);
        expect(find.byKey(const Key('loginMilestone100000')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('plazaMission_plaza_month_huge')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mission_followers_100:template')),
          findsOneWidget,
        );

        // 3つの欄の見出しと、それぞれの更新ボタン。
        final l10n = lookupAppLocalizations(Locale(locale));
        final headings = [
          l10n.plazaMissionsTitle,
          l10n.recurringMissionsTitle,
          l10n.loginBonusTitle,
        ];
        for (final panel in [
          'plazaMissionsPanel',
          'recurringMissionsPanel',
          'loginBonusPanel',
        ]) {
          expect(
            find.descendant(
              of: find.byKey(Key(panel)),
              matching: find.byIcon(Icons.refresh),
            ),
            findsOneWidget,
            reason: '$panel: 更新ボタン',
          );
        }

        final broken = <String>[];
        var headingsSeen = 0;
        for (final element in find.byType(RichText).evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final text = paragraph.text.toPlainText();
          final heading = headings.any(text.contains);
          if (heading) headingsSeen++;
          broken.addAll(
            _breaksInsideWords(
              paragraph,
              widestPlaceableWord: heading
                  ? _panelContentWidth
                  : _widestPlaceableWord,
            ),
          );
        }
        expect(headingsSeen, 3, reason: '$locale: 欄の見出しが3つとも出ていない');
        expect(
          broken,
          isEmpty,
          reason: '$locale ×$scale: 単語・数の途中の改行\n${broken.join('\n')}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
