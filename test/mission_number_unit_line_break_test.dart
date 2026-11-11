// ミッションの画面（作品広場の滞在・ウィークリー／マンスリー・累計ログイン・
// クリエイターミッションの行と、画面の上の制作時間の行）と、作品広場の
// 滞在ミッション達成の知らせで、数と単位（「1コイン」「8코인」「40小時」
// 「10分鐘」）が行の途中で切れないことを、本物のフォント・テーマ・スマホの
// 幅（360dp）・文字1.75倍と2倍で確かめる。
//
// 日本語・中国語・韓国語は字と字の間のどこでも行を変えてよい。数と単位を
// 空白なしでつなぐ書き方（「1コイン」「8金幣」）にしてから、作品広場の行が
// 「20分 / 15分 · 1コイ」「ン」、ウィークリーの行が「12 / 10天 · 4」「金幣」、
// 制作時間の行が「이 기기 제작 시간(참고): 0」「시간」、達成の知らせが
// 「累計開啟作品廣場1小」「時」「合計10」「分開く」と単位の途中や数と単位の
// 間で切れていた（特典交換の画面だけ直してあった）。
import 'dart:async';
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
import 'package:niarim/utils/coin_duration_label.dart';
import 'package:niarim/widgets/mission_completion_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'mission-number-unit';
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

/// 作品広場の滞在（サーバーの定義どおり5分〜40時間、1〜8コイン）。
const _plaza = [
  ('day_5m', 'day', 300, 1),
  ('day_15m', 'day', 900, 1),
  ('day_60m', 'day', 3600, 2),
  ('week_6h', 'week', 21600, 4),
  ('month_40h', 'month', 144000, 8),
];
const _plazaProgress = 1200;

/// ウィークリー（3・5・7日）とマンスリー（10・20・25日）。
const _recurring = [
  ('week', 3, 2, 3),
  ('week', 5, 3, 3),
  ('week', 7, 4, 3),
  ('month', 10, 4, 12),
  ('month', 20, 6, 12),
  ('month', 25, 8, 12),
];

/// 累計ログインの節目（日数・コイン）。
const _milestones = [(7, 5), (30, 20), (100, 50)];

/// クリエイターミッションのコインと、検証済みの制作時間（時間）。
const _creatorCoins = [30, 10, 5];
const _creatorHours = 10;
const _candidateSeconds = 5400;
const _verifiedSeconds = 0;

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
            'candidateEditSeconds': _candidateSeconds,
            'verifiedEditSeconds': _verifiedSeconds,
            'missions': [
              {
                'id': 'followers_100',
                'kind': 'followers',
                'required': 100,
                'progress': 12,
                'coins': _creatorCoins[0],
                'claimed': false,
                'eligible': false,
                'readyForClaim': false,
                'rewardEnabled': true,
                'perWork': false,
              },
              {
                'id': 'time_10',
                'kind': 'verifiedEditSeconds',
                'required': _creatorHours * 3600,
                'coins': _creatorCoins[1],
                'claimed': false,
                'eligible': true,
                'readyForClaim': true,
                'rewardEnabled': true,
                'perWork': false,
              },
              // 作品を選んでいないときのひな形（受け取れない）。
              {
                'id': 'bookmarks_10',
                'kind': 'workBookmarks',
                'required': 10,
                'coins': _creatorCoins[2],
                'perWork': true,
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
              for (final (days, coins) in _milestones)
                {
                  'days': days,
                  'coins': coins,
                  'claimed': days == 7,
                  'eligible': days <= 31,
                },
            ],
          },
          '/me/missions/recurring' => {
            'enabled': true,
            'missions': [
              for (final (period, days, coins, progress) in _recurring)
                {
                  'id': 'visit_${period}_$days',
                  'period': period,
                  'requiredDays': days,
                  'progressDays': progress,
                  'coins': coins,
                  'claimed': false,
                  'eligible': progress >= days,
                },
            ],
          },
          '/me/missions/plaza' => {
            'enabled': true,
            'missions': [
              for (final (id, period, seconds, coins) in _plaza)
                {
                  'id': 'plaza_$id',
                  'period': period,
                  'requiredSeconds': seconds,
                  'progressSeconds': _plazaProgress,
                  'coins': coins,
                  'claimed': false,
                  'eligible': seconds <= _plazaProgress,
                },
            ],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

/// [paragraph]の中で、[phrases]（数と単位）の途中で行が変わる所と、数の
/// すぐ後の字（単位）の前で行が変わる所（「8|코인」「0|시간」「4|金幣」）。
List<String> _numberUnitBreaks(
  RenderParagraph paragraph,
  Iterable<String> phrases,
) {
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  double? top(int i) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    return boxes.isEmpty ? null : boxes.first.top;
  }

  String show(int at) =>
      '${text.substring(0, at)}|${text.substring(at)}'.replaceAll('\n', ' / ');

  final broken = <String>{};
  for (final phrase in phrases) {
    for (final match in phrase.allMatches(text)) {
      // 数の前に別の数字が続いていれば、別の数の一部（「15分」の中の「5分」）。
      if (match.start > 0 && RegExp(r'\d').hasMatch(text[match.start - 1])) {
        continue;
      }
      double? previous;
      for (var i = match.start; i < match.end; i++) {
        final here = top(i);
        if (here == null) continue;
        if (previous != null && here > previous + 1) {
          broken.add('「$phrase」の途中: ${show(i)}');
        }
        previous = here;
      }
    }
  }
  for (var i = 1; i < text.length; i++) {
    if (!RegExp(r'\d').hasMatch(text[i - 1])) continue;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(text[i])) continue;
    final before = top(i - 1);
    final here = top(i);
    if (before != null && here != null && here > before + 1) {
      broken.add('数と単位の間: ${show(i)}');
    }
  }
  return broken.toList();
}

Iterable<RenderParagraph> _paragraphs(Finder within) sync* {
  for (final element
      in find
          .descendant(of: within, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is RenderParagraph && paragraph.attached) yield paragraph;
  }
}

void main() {
  // 同梱フォントはファイルで1回だけ読む（テストごとに読むと、テストの数だけ
  // フォントが積み上がってメモリが足りなくなり、テストの途中で落ちた）。
  var fontsLoaded = false;
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'ja': Locale('ja'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    'fr': Locale('fr'),
    'es': Locale('es'),
    'en': Locale('en'),
  };

  Future<ThemeService> prepare(WidgetTester tester, double scale) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    final themes = ThemeService();
    await themes.init();
    addTearDown(themes.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 30000);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    return themes;
  }

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    for (final scale in [1.75, 2.0]) {
      testWidgets('ミッションの画面の数と単位が途中で切れない（$name, 文字$scale倍, 360dp）', (
        tester,
      ) async {
        final themes = await prepare(tester, scale);
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
              ChangeNotifierProvider<SettingsService>.value(
                value: SettingsService(),
              ),
            ],
            child: MaterialApp(
              locale: locale,
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
        // 3つの欄とクリエイターミッションの行が出ていること。
        expect(find.byKey(const Key('plazaMissionsPanel')), findsOneWidget);
        expect(find.byKey(const Key('recurringMissionsPanel')), findsOneWidget);
        expect(find.byKey(const Key('loginMilestone100')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mission_time_10:template')),
          findsOneWidget,
        );

        final l10n = lookupAppLocalizations(locale);
        final phrases = <String>{
          for (final (_, _, _, coins) in _plaza) l10n.coinAmount(coins),
          for (final (_, _, coins, _) in _recurring) l10n.coinAmount(coins),
          for (final (_, coins) in _milestones) l10n.coinAmount(coins),
          for (final coins in _creatorCoins) l10n.coinAmount(coins),
          l10n.coinAmount(1),
          for (final (_, _, seconds, _) in _plaza)
            missionDurationLabel(l10n, seconds),
          missionDurationLabel(l10n, _plazaProgress),
          l10n.missionDurationHours(_creatorHours),
          l10n.missionDurationHours(0),
          l10n.missionDurationMinutes(_candidateSeconds ~/ 60),
          l10n.missionDurationMinutes(_verifiedSeconds ~/ 60),
        };
        final problems = <String>[];
        var numbersSeen = 0;
        for (final paragraph in _paragraphs(find.byType(Scaffold))) {
          final text = paragraph.text.toPlainText(
            includeSemanticsLabels: false,
          );
          if (RegExp(r'\d').hasMatch(text)) numbersSeen++;
          problems.addAll(_numberUnitBreaks(paragraph, phrases));
        }
        expect(numbersSeen, greaterThan(20), reason: '$name: 数の出る文');
        expect(
          problems,
          isEmpty,
          reason: '$name ×$scale:\n${problems.join('\n')}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('作品広場の滞在ミッション達成の知らせの数と単位が途中で切れない'
          '（$name, 文字$scale倍, 360dp）', (tester) async {
        final themes = await prepare(tester, scale);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: themes.themeData,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.expand()),
          ),
        );
        const achieved = [
          ('day', 300),
          ('day', 600),
          ('week', 3600),
          ('week', 21600),
          ('month', 7200),
          ('month', 144000),
        ];
        unawaited(
          showPlazaMissionCompletions(tester.element(find.byType(Scaffold)), {
            'newlyAchieved': [
              for (final (period, seconds) in achieved)
                {'period': period, 'requiredSeconds': seconds},
            ],
          }),
        );
        await tester.pumpAndSettle();
        final dialog = find.byKey(const Key('missionCompletedDialog'));
        expect(dialog, findsOneWidget, reason: '$name: 達成の知らせ');
        final l10n = lookupAppLocalizations(locale);
        final phrases = {
          for (final (_, seconds) in achieved)
            missionDurationLabel(l10n, seconds),
        };
        final problems = <String>[
          for (final paragraph in _paragraphs(dialog))
            ..._numberUnitBreaks(paragraph, phrases),
        ];
        expect(
          problems,
          isEmpty,
          reason: '$name ×$scale:\n${problems.join('\n')}',
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('missionCompletedClose')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
