import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/opal_gifts.dart';
import 'package:niarim/screens/rewards/coin_benefits_screen.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:niarim/widgets/icon_notice.dart';

import 'helpers/load_app_fonts.dart';

// 「オパール・特典」の広告で貯めるタブは、残高を読み込めていないだけで
// 「リワード広告は利用できません」と出していた。読み込み中・ログインして
// いない・読み込めなかった・サーバーが止めている・配っている、のそれぞれで
// 正しい状態を出すことを見張る。

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'earn-state-account';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _Account();
}

class _Ads extends AdvertisingService {
  _Ads({required super.premiumService});

  @override
  bool get canOfferRewardedAds => true;
}

const _json = {'content-type': 'application/json; charset=utf-8'};

/// サーバーの`GET /me/rewards`の答え。[gate]があれば、それが終わるまで待つ。
class _Server {
  Map<String, dynamic>? state;
  int failures = 0;
  Completer<void>? gate;
  int rewardRequests = 0;

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/me/gifts') {
      return http.Response(
        jsonEncode({
          'niarimUserId': 'N0123456789abcdef0123456789abcdef',
          'presents': <Object>[],
        }),
        200,
        headers: _json,
      );
    }
    if (request.url.path == '/me/rewards') {
      rewardRequests++;
      await gate?.future;
      if (failures > 0) {
        failures--;
        return http.Response(
          jsonEncode({'error': 'サーバーが混み合っています'}),
          503,
          headers: _json,
        );
      }
      return http.Response(jsonEncode(state), 200, headers: _json);
    }
    return http.Response(
      jsonEncode({'error': 'not found'}),
      404,
      headers: _json,
    );
  }
}

const _enabledState = {
  'balanceCoins': 1200,
  'rewardEarningEnabled': true,
  'rewardedCoinsPerCompletion': 10,
  'rewardedOfferVersion': 'launch-v1-10-coins',
};

const _pausedState = {'balanceCoins': 1200, 'rewardEarningEnabled': false};

final _captureKey = GlobalKey();

class _Harness {
  _Harness({required this.signedIn, required this.server});

  final bool signedIn;
  final _Server server;
  late final http.Client _http = MockClient(server.handle);
  late final NiarimApiClient client = NiarimApiClient(
    baseUrl: 'https://api.example',
    httpClient: _http,
    tokenProvider: () async => 'id-token',
    maxGetRetries: 0,
  );
  late final CommunityService community = CommunityService(
    api: CommunityApi(client),
  );
  final premium = PremiumService();
  final settings = SettingsService();
  final themes = ThemeService();
  late final ads = _Ads(premiumService: premium);
  late final GoogleAuthService auth = signedIn
      ? _SignedIn()
      : GoogleAuthService();

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('ja'),
    RewardPageMode mode = RewardPageMode.earnCoins,
  }) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<GoogleAuthService>.value(value: auth),
            ChangeNotifierProvider<CommunityService>.value(value: community),
            ChangeNotifierProvider<PremiumService>.value(value: premium),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
            ChangeNotifierProvider<AdvertisingService>.value(value: ads),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            theme: themes.themeDataFor(locale),
            scrollBehavior: const AppScrollBehavior(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // 本番と同じく「オパール・特典」のタブの中に出す。
            home: mode == RewardPageMode.earnCoins
                ? const CoinBenefitsScreen(initialTab: 1)
                : RewardUnlockScreen(mode: mode),
          ),
        ),
      ),
    );
    // 最初のフレームの後でアカウントを読み、残高を取りに行く。
    await tester.pump();
    await tester.pump();
  }

  /// 本物の`http`の非同期（MockClientの応答）を進めてから描き直す。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    auth.dispose();
    community.dispose();
    premium.dispose();
    settings.dispose();
    themes.dispose();
    client.close();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final root = Platform.environment['NIARIM_REWARD_STATE_CAPTURE_DIR'];
  if (root == null || root.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$root/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _watch = find.byKey(const Key('rewardWatchAdButton'));
final _paused = find.byKey(const Key('rewardEarningPausedNotice'));
final _failed = find.byKey(const Key('rewardWalletLoadFailed'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    opalWalletRevision.value = 0;
  });

  for (final locale in const [Locale('ja'), Locale('fr')]) {
    final tag = locale.languageCode;
    final l10n = lookupAppLocalizations(locale);

    testWidgets('$tag: loading shows the loading text, not a paused notice', (
      tester,
    ) async {
      _phone(tester);
      await loadAppFonts(tester);
      final server = _Server()
        ..state = _enabledState
        ..gate = Completer<void>();
      final h = _Harness(signedIn: true, server: server);
      await h.pump(tester, locale: locale);
      await h.settle(tester);

      expect(server.rewardRequests, 1);
      expect(find.text(l10n.rewardUnlockLoading), findsOneWidget);
      expect(_paused, findsNothing);
      expect(_failed, findsNothing);
      expect(_watch, findsNothing);
      expect(find.text(l10n.rewardNavigationEarnUnavailable), findsNothing);
      await _capture(tester, '${tag}_1_loading');

      server.gate!.complete();
      await h.settle(tester);
      expect(_watch, findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('$tag: signed out asks to sign in to earn opals', (
      tester,
    ) async {
      _phone(tester);
      await loadAppFonts(tester);
      final server = _Server()..state = _enabledState;
      final h = _Harness(signedIn: false, server: server);
      await h.pump(tester, locale: locale);
      await h.settle(tester);

      expect(server.rewardRequests, 0);
      expect(find.text(l10n.rewardUnlockEarnSignIn), findsOneWidget);
      expect(find.byKey(const Key('rewardsSignInButton')), findsOneWidget);
      expect(_paused, findsNothing);
      expect(_failed, findsNothing);
      expect(_watch, findsNothing);
      expect(find.text(l10n.rewardNavigationEarnUnavailable), findsNothing);
      await _capture(tester, '${tag}_2_signed_out');
      await h.dispose(tester);
    });

    testWidgets('$tag: a failed load shows a caution and retries', (
      tester,
    ) async {
      _phone(tester);
      await loadAppFonts(tester);
      final server = _Server()
        ..state = _enabledState
        ..failures = 1;
      final h = _Harness(signedIn: true, server: server);
      await h.pump(tester, locale: locale);
      await h.settle(tester);

      expect(server.rewardRequests, 1);
      expect(_failed, findsOneWidget);
      expect(
        tester.widget<IconNotice>(_failed).severity,
        NoticeSeverity.caution,
      );
      expect(find.text(l10n.rewardUnlockBalanceLoadFailed), findsOneWidget);
      expect(_paused, findsNothing);
      expect(_watch, findsNothing);
      await _capture(tester, '${tag}_3_load_failed');

      final retry = find.widgetWithText(
        TextButton,
        l10n.rewardUnlockRewardRefresh,
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await h.settle(tester);

      expect(server.rewardRequests, 2);
      expect(_failed, findsNothing);
      expect(find.text(l10n.coinAmount(1200)), findsOneWidget);
      expect(_watch, findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('$tag: a server-side stop says the ads are paused', (
      tester,
    ) async {
      _phone(tester);
      await loadAppFonts(tester);
      final server = _Server()..state = _pausedState;
      final h = _Harness(signedIn: true, server: server);
      await h.pump(tester, locale: locale);
      await h.settle(tester);

      expect(find.text(l10n.coinAmount(1200)), findsOneWidget);
      expect(_paused, findsOneWidget);
      expect(
        find.descendant(
          of: _paused,
          matching: find.text(l10n.rewardNavigationEarnUnavailable),
        ),
        findsOneWidget,
      );
      expect(_failed, findsNothing);
      expect(_watch, findsNothing);
      await _capture(tester, '${tag}_4_server_paused');
      await h.dispose(tester);
    });

    testWidgets('$tag: enabled ads show the earn button', (tester) async {
      _phone(tester);
      await loadAppFonts(tester);
      final server = _Server()..state = _enabledState;
      final h = _Harness(signedIn: true, server: server);
      await h.pump(tester, locale: locale);
      await h.settle(tester);

      expect(_watch, findsOneWidget);
      expect(tester.widget<FilledButton>(_watch).onPressed, isNotNull);
      expect(_paused, findsNothing);
      expect(_failed, findsNothing);
      await _capture(tester, '${tag}_5_enabled');
      await h.dispose(tester);
    });
  }

  testWidgets('the exchange tab keeps the balance sign-in text', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final h = _Harness(signedIn: false, server: _Server());
    await h.pump(tester, mode: RewardPageMode.exchange);
    await h.settle(tester);
    expect(find.text(l10n.rewardUnlockBalanceSignIn), findsOneWidget);
    expect(find.text(l10n.rewardUnlockEarnSignIn), findsNothing);
    await h.dispose(tester);
  });

  test('the paused wording follows the temporary-stop rule', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final text = lookupAppLocalizations(
        locale,
      ).rewardNavigationEarnUnavailable;
      expect(text, isNotEmpty);
    }
    expect(
      lookupAppLocalizations(
        const Locale('ja'),
      ).rewardNavigationEarnUnavailable,
      'リワード広告は一時的に停止しています',
    );
  });
}
