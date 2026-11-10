// 作品広場を開いたまま滞在ミッションを達成したときの知らせ（サーバーの
// /me/missions/plaza/pulseが返すnewlyAchieved）が、その言語の文と数・単位で
// 出ることを、本物の作品広場の画面で確かめる。
//
// 以前はcommunity_screen.dartがダイアログの題・各行・本文・2つのボタンを
// 日本語で直に書き、時間も「'${seconds ~/ 60}分'」とコードでつないでいた
// ため、英語・フランス語等の画面でも「ミッションをクリアしました！」
// 「・デイリー：作品広場を合計10分 開く」と日本語で出ていた。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'plaza-popup-account';
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

/// 作品広場を開くと、最初の滞在の記録でデイリー10分・ウィークリー1時間・
/// マンスリー2時間を達成したと返すサーバー。
CommunityService _server() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      retryBackoff: Duration.zero,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/me/missions/plaza/pulse') {
          return _json({
            'newlyAchieved': [
              {'period': 'day', 'requiredSeconds': 600},
              {'period': 'week', 'requiredSeconds': 3600},
              {'period': 'month', 'requiredSeconds': 7200},
            ],
          });
        }
        if (request.method != 'GET') return _json(<String, Object>{});
        if (path == '/works/latest') return _json({'works': <Object>[]});
        if (path.startsWith('/ranking/')) {
          return _json({'period': path.split('/').last, 'works': <Object>[]});
        }
        return _json(<String, Object>{});
      }),
    ),
  ),
);

/// 言語ごとに出るはずの文（題・各行・本文・ボタン）。
const _expected = <String, List<String>>{
  'ja': [
    'ミッション達成',
    '・デイリー：作品広場を合計10分開く',
    '・ウィークリー：作品広場を合計1時間開く',
    '・マンスリー：作品広場を合計2時間開く',
    'ミッションページで報酬を受け取れます。',
    '閉じる',
    'ミッションページへ',
  ],
  'en': [
    'Mission completed!',
    '・Daily: Keep Work Plaza open for 10 minutes in total',
    '・Weekly: Keep Work Plaza open for 1 hour in total',
    '・Monthly: Keep Work Plaza open for 2 hours in total',
    'Visit Missions to claim your reward.',
    'Close',
    'Go to Missions',
  ],
  'es': [
    '¡Misión completada!',
    '・Misión diaria: Mantén abierta la Plaza de Obras 10 minutos en total',
    '・Misión semanal: Mantén abierta la Plaza de Obras 1 hora en total',
    '・Misión mensual: Mantén abierta la Plaza de Obras 2 horas en total',
    'Ve a Misiones para reclamar tu recompensa.',
    'Cerrar',
    'Ir a Misiones',
  ],
  'ko': [
    '미션 달성',
    '・일일: 작품 광장을 합계 10분 열어 두기',
    '・주간: 작품 광장을 합계 1시간 열어 두기',
    '・월간: 작품 광장을 합계 2시간 열어 두기',
    '미션 페이지에서 보상을 받을 수 있습니다.',
    '닫기',
    '미션 페이지로',
  ],
  'fr': [
    'Mission accomplie !',
    '・Mission quotidienne : Garder la Place des œuvres ouverte 10 minutes '
        'au total',
    '・Mission hebdomadaire : Garder la Place des œuvres ouverte 1 heure '
        'au total',
    '・Mission mensuelle : Garder la Place des œuvres ouverte 2 heures '
        'au total',
    'Rendez-vous dans Missions pour réclamer votre récompense.',
    'Fermer',
    'Aller aux missions',
  ],
  'zh': [
    '任务达成',
    '・每日：累计打开作品广场10分钟',
    '・每周：累计打开作品广场1小时',
    '・每月：累计打开作品广场2小时',
    '可在任务页面领取奖励。',
    '关闭',
    '前往任务页面',
  ],
  'zh_Hant': [
    '任務達成',
    '・每日：累計開啟作品廣場10分鐘',
    '・每週：累計開啟作品廣場1小時',
    '・每月：累計開啟作品廣場2小時',
    '可在任務頁面領取獎勵。',
    '關閉',
    '前往任務頁面',
  ],
};

/// 日本語の仮名・漢字（英語・フランス語の画面に出てはいけない）。
final _cjk = RegExp('[぀-ヿ一-鿿]');

/// 日本語の仮名（中国語の画面に出てはいけない）。
final _kana = RegExp('[぀-ヿ]');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'ja': Locale('ja'),
    'en': Locale('en'),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    testWidgets('作品広場の滞在ミッション達成の知らせがその言語で出る（$name）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const CommunityScreen()),
          GoRoute(
            path: '/rewards',
            builder: (_, _) =>
                const Scaffold(body: Text('rewards-page-for-test')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CommunityService>.value(value: _server()),
            ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
            ChangeNotifierProvider(create: (_) => SettingsService()),
            ChangeNotifierProvider<GoogleAuthService>.value(value: _SignedIn()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget, reason: '$name: 達成の知らせ');
      final texts = [
        for (final text in tester.widgetList<Text>(
          find.descendant(of: dialog, matching: find.byType(Text)),
        ))
          text.data ?? text.textSpan?.toPlainText() ?? '',
      ];
      final shown = texts.join('\n\n').split('\n\n');
      debugPrint('POPUP($name): ${shown.join(' | ')}');

      final l10n = lookupAppLocalizations(locale);
      // 題・本文・ボタンはミッション達成の知らせ（累計ログイン）と同じ文。
      for (final expected in [
        l10n.missionCompletedTitle,
        l10n.missionCompletedBody,
        l10n.commonClose,
        l10n.missionCompletedGoToMissions,
      ]) {
        expect(shown, contains(expected), reason: '$name: $shown');
      }
      // 3つの達成がそれぞれ1行ずつ。
      expect(
        shown.where((line) => line.startsWith('・')),
        hasLength(3),
        reason: '$name: $shown',
      );
      for (final expected in _expected[name]!) {
        expect(shown, contains(expected), reason: '$name: $shown');
      }
      // 行頭の「・」は知らせの箇条書きの印（累計ログインの知らせと同じ）。
      final bodies = [
        for (final line in shown)
          line.startsWith('・') ? line.substring(1) : line,
      ];
      if (name == 'en' || name == 'es' || name == 'fr') {
        for (final line in bodies) {
          expect(_cjk.hasMatch(line), isFalse, reason: '$name: $line');
        }
      }
      if (name == 'ko' || name.startsWith('zh')) {
        for (final line in bodies) {
          expect(_kana.hasMatch(line), isFalse, reason: '$name: $line');
        }
      }

      // 「ミッションページへ」でミッションの画面へ移る（戻れるようにpush）。
      await tester.tap(find.text(l10n.missionCompletedGoToMissions));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('rewards-page-for-test'), findsOneWidget);
      expect(router.canPop(), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
