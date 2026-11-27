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
import 'package:niarim/screens/rewards/opal_gifts.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/api/niarim_api_exception.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';

import 'helpers/load_app_fonts.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'gift-test-account';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _Account();
}

const _user = 'N0123456789abcdef0123456789abcdef';
final _deadline = DateTime(2026, 12, 8, 23, 59);

Map<String, dynamic> _present(
  String id, {
  bool claimed = false,
  int coins = 300,
  String title = 'メンテナンスのお詫び',
  String body = '12月1日のメンテナンスでご不便をおかけしました。',
  Map<String, dynamic> translations = const {},
}) => {
  'id': id,
  'coins': coins,
  'title': title,
  'body': body,
  'translations': translations,
  'visibleFromEpochMs': 0,
  'claimUntilEpochMs': _deadline.millisecondsSinceEpoch,
  'claimed': claimed,
  'claimedAtEpochMs': null,
};

class _GiftApi extends CommunityApi {
  _GiftApi() : super(NiarimApiClient(baseUrl: 'https://example.invalid'));

  int accountAgeSeconds = 400 * 24 * 3600;
  List<Map<String, dynamic>> presents = [];
  bool failInbox = false;
  int inboxCalls = 0;
  final claims = <String>[];
  Object? claimError;
  Completer<void>? claimGate;
  final redeems = <(String, String)>[];
  Object? redeemError;
  Completer<void>? redeemGate;

  @override
  Future<Map<String, dynamic>> myRewardState() async => {
    'balanceCoins': 1200,
    'entitlements': <Object>[],
    'rewardEarningEnabled': false,
  };

  @override
  Future<Map<String, dynamic>> myGifts() async {
    inboxCalls++;
    if (failInbox) throw const NiarimApiException.network('offline');
    return {
      'niarimUserId': _user,
      'serverNowEpochMs': 0,
      'accountCreatedAtEpochMs': 0,
      'accountAgeSeconds': accountAgeSeconds,
      'presents': [for (final p in presents) Map<String, dynamic>.from(p)],
      'unclaimedCount': presents.where((p) => p['claimed'] == false).length,
    };
  }

  @override
  Future<Map<String, dynamic>> claimPresent(String presentId) async {
    claims.add(presentId);
    await claimGate?.future;
    final error = claimError;
    if (error != null) throw error;
    final present = presents.firstWhere((p) => p['id'] == presentId);
    present['claimed'] = true;
    return {
      'claimed': true,
      'alreadyClaimed': false,
      'presentId': presentId,
      'awardedCoins': present['coins'],
    };
  }

  @override
  Future<Map<String, dynamic>> redeemCoupon({
    required String code,
    required String requestId,
  }) async {
    redeems.add((code, requestId));
    await redeemGate?.future;
    final error = redeemError;
    if (error != null) throw error;
    return {
      'redeemed': true,
      'alreadyRedeemed': false,
      'code': code,
      'awardedCoins': 500,
    };
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  _GiftApi api, {
  Locale locale = const Locale('ja'),
  ThemeData? theme,
  Widget? body,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<GoogleAuthService>.value(value: _Auth()),
          ChangeNotifierProvider<CommunityService>.value(
            value: CommunityService(api: api),
          ),
          ChangeNotifierProvider<PremiumService>.value(value: PremiumService()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(),
              body:
                  body ??
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OpalGiftActions(),
                        TextButton(
                          key: const Key('offerAfterSignIn'),
                          onPressed: () =>
                              maybeOfferOpalCouponAfterSignIn(context),
                          child: const Text('sign-in done'),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

final _captureKey = GlobalKey();

Future<void> _openCoupon(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('opalCouponButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('opalCouponDialog')), findsOneWidget);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final root = Platform.environment['NIARIM_GIFT_CAPTURE_DIR'];
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    opalWalletRevision.value = 0;
  });

  group('API client', () {
    test('sends signed-in, account-scoped gift requests', () async {
      final requests = <http.Request>[];
      final client = NiarimApiClient(
        baseUrl: 'https://api.example',
        tokenProvider: () async => 'id-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/me/gifts/coupons/redeem') {
            return http.Response(
              jsonEncode({
                'error': 'このクーポンはすでに使っています',
                'code': 'COUPON_ALREADY_REDEEMED',
              }),
              409,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'ok': true, 'title': 'お詫び'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final api = CommunityApi(client);
      expect((await api.myGifts())['title'], 'お詫び');
      await api.claimPresent('0mgzabc12deadbeef');
      await expectLater(
        api.redeemCoupon(code: 'ABCD2345', requestId: 'req-1'),
        throwsA(
          isA<NiarimApiException>()
              .having((e) => e.code, 'code', 'COUPON_ALREADY_REDEEMED')
              .having((e) => e.message, 'message', 'このクーポンはすでに使っています'),
        ),
      );
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /me/gifts',
        'POST /me/gifts/presents/0mgzabc12deadbeef/claim',
        'POST /me/gifts/coupons/redeem',
      ]);
      expect(
        requests.every((r) => r.headers['authorization'] == 'Bearer id-token'),
        isTrue,
      );
      expect(jsonDecode(requests.last.body), {
        'code': 'ABCD2345',
        'requestId': 'req-1',
      });
    });

    test('normalises typed codes like the server', () {
      expect(normalizeOpalCouponCode(' abcd-ｅｆｇｈ '), 'ABCDEFGH');
      expect(normalizeOpalCouponCode('ＡＢＣＤ　２３４５'), 'ABCD2345');
      expect(normalizeOpalCouponCode('abcd ー 2345'), 'ABCD2345');
      expect(normalizeOpalCouponCode('ab'), isNull);
      expect(normalizeOpalCouponCode('abcd!234'), isNull);
    });

    test('parses the present box strictly', () {
      final inbox = OpalGiftInbox.fromJson({
        'niarimUserId': _user,
        'accountAgeSeconds': 30,
        'presents': [
          _present(
            '0mgzabc12deadbeef',
            translations: {
              'fr': {'title': 'Désolé', 'body': 'Merci.'},
            },
          ),
          _present('0mgzabc13deadbeef', claimed: true),
        ],
      });
      expect(inbox.unclaimedCount, 1);
      expect(inbox.presents.first.messageFor('fr').title, 'Désolé');
      expect(inbox.presents.first.messageFor('en').title, 'メンテナンスのお詫び');
      expect(
        () => OpalGiftInbox.fromJson({'niarimUserId': _user, 'presents': 1}),
        throwsFormatException,
      );
    });
  });

  group('coupon entry', () {
    testWidgets('redeems with Enter, closes, tells the amount and refreshes', (
      tester,
    ) async {
      final api = _GiftApi();
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      await _openCoupon(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('opalCouponSubmit')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('opalCouponField')),
        'welcome-2027',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.redeems.single.$1, 'WELCOME2027');
      expect(find.byKey(const Key('opalCouponDialog')), findsNothing);
      expect(
        find.text(l10n.opalGiftReceived(l10n.coinAmount(500))),
        findsOneWidget,
      );
      expect(opalWalletRevision.value, 1);
    });

    testWidgets('a second press while sending sends one request', (
      tester,
    ) async {
      final api = _GiftApi()..redeemGate = Completer<void>();
      await _pumpHarness(tester, api);
      await _openCoupon(tester);
      await tester.enterText(
        find.byKey(const Key('opalCouponField')),
        'ABCD2345',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('opalCouponSubmit')),
        warnIfMissed: false,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(api.redeems, hasLength(1));
      api.redeemGate!.complete();
      await tester.pumpAndSettle();
      expect(api.redeems, hasLength(1));
      expect(opalWalletRevision.value, 1);
    });

    testWidgets('shows each refusal inside the dialog and keeps the code', (
      tester,
    ) async {
      final api = _GiftApi();
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      final cases = {
        'COUPON_INVALID_CODE': l10n.opalCouponErrorFormat,
        'COUPON_NOT_FOUND': l10n.opalCouponErrorNotFound,
        'COUPON_ENDED': l10n.opalCouponErrorEnded,
        'COUPON_EXPIRED': l10n.opalCouponErrorExpired,
        'COUPON_NOT_YET_VALID': l10n.opalCouponErrorNotYet,
        'COUPON_LIMIT_REACHED': l10n.opalCouponErrorLimit,
        'COUPON_ALREADY_REDEEMED': l10n.opalCouponErrorUsed,
        'COUPON_NEW_ACCOUNTS_ONLY': l10n.opalCouponErrorNewOnly,
        'COUPON_NOT_ELIGIBLE': l10n.opalCouponErrorNotEligible,
        'COUPON_RATE_LIMITED': l10n.opalCouponErrorRateLimited,
      };
      await _openCoupon(tester);
      await tester.enterText(
        find.byKey(const Key('opalCouponField')),
        'ABCD2345',
      );
      await tester.pump();
      for (final entry in cases.entries) {
        api.redeemError = NiarimApiException(409, 'x', code: entry.key);
        await tester.tap(find.byKey(const Key('opalCouponSubmit')));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
        expect(find.byKey(const Key('opalCouponDialog')), findsOneWidget);
      }
      api.redeemError = const NiarimApiException(
        401,
        'x',
        code: 'UNAUTHORIZED',
      );
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalGiftSignInRequired), findsOneWidget);
      // A malformed code is refused before anything is sent.
      final sent = api.redeems.length;
      await tester.enterText(find.byKey(const Key('opalCouponField')), 'ab!');
      await tester.pump();
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      expect(api.redeems, hasLength(sent));
      expect(find.text(l10n.opalCouponErrorFormat), findsOneWidget);
      expect(opalWalletRevision.value, 0);
    });

    testWidgets('retrying after a lost answer reuses the request id', (
      tester,
    ) async {
      final api = _GiftApi()
        ..redeemError = const NiarimApiException.network('lost');
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      await _openCoupon(tester);
      await tester.enterText(
        find.byKey(const Key('opalCouponField')),
        'abcd-2345',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalGiftClaimFailed), findsOneWidget);
      api.redeemError = null;
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      expect(api.redeems, hasLength(2));
      expect(api.redeems[0].$2, api.redeems[1].$2);
      expect(api.redeems[0].$2, matches(RegExp(r'^[0-9a-f]{32}$')));

      // A definite refusal starts a fresh attempt next time.
      await _openCoupon(tester);
      await tester.enterText(
        find.byKey(const Key('opalCouponField')),
        'WXYZ2345',
      );
      await tester.pump();
      api.redeemError = const NiarimApiException(
        404,
        'x',
        code: 'COUPON_NOT_FOUND',
      );
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      api.redeemError = null;
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      expect(api.redeems[2].$2, isNot(api.redeems[3].$2));
    });

    testWidgets('offers the coupon once, only to a just-created account', (
      tester,
    ) async {
      final api = _GiftApi()..accountAgeSeconds = 400 * 24 * 3600;
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      await tester.tap(find.byKey(const Key('offerAfterSignIn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opalCouponDialog')), findsNothing);

      api.accountAgeSeconds = 20;
      await tester.tap(find.byKey(const Key('offerAfterSignIn')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalCouponOfferTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('opalCouponCancel')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalCouponLater), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$opalCouponOfferShownPrefix$_user'), isTrue);

      await tester.tap(find.byKey(const Key('offerAfterSignIn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opalCouponDialog')), findsNothing);
    });
  });

  group('present box', () {
    testWidgets('badge, deadline, receive once, received state', (
      tester,
    ) async {
      final api = _GiftApi()
        ..presents = [
          _present('0mgzabc12deadbeef'),
          _present('0mgzabc13deadbeef', claimed: true, title: '前回のお詫び'),
        ];
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      final badge = tester.widget<Badge>(
        find.byKey(const Key('opalPresentBadge')),
      );
      expect(badge.isLabelVisible, isTrue);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('opalPresentBoxButton')));
      await tester.pumpAndSettle();
      expect(find.text('メンテナンスのお詫び'), findsOneWidget);
      expect(find.text(l10n.opalGiftClaimUntil(_deadline)), findsNWidgets(2));
      expect(find.byKey(const Key('opalPresentClaimed')), findsOneWidget);

      api.claimGate = Completer<void>();
      await tester.tap(find.byKey(const Key('opalPresentClaim')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('opalPresentClaim')))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const Key('opalPresentClaim')),
        warnIfMissed: false,
      );
      api.claimGate!.complete();
      await tester.pumpAndSettle();
      expect(api.claims, ['0mgzabc12deadbeef']);
      expect(find.byKey(const Key('opalPresentClaim')), findsNothing);
      expect(find.byKey(const Key('opalPresentClaimed')), findsNWidgets(2));
      expect(
        find.text(l10n.opalGiftReceived(l10n.coinAmount(300))),
        findsOneWidget,
      );
      expect(opalWalletRevision.value, 1);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('opalPresentBadge')))
            .isLabelVisible,
        isFalse,
      );
    });

    testWidgets('an expired present is reported and dropped on reload', (
      tester,
    ) async {
      final api = _GiftApi()..presents = [_present('0mgzabc12deadbeef')];
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      await tester.tap(find.byKey(const Key('opalPresentBoxButton')));
      await tester.pumpAndSettle();
      api
        ..claimError = const NiarimApiException(
          409,
          'x',
          code: 'PRESENT_EXPIRED',
        )
        ..presents = [];
      await tester.tap(find.byKey(const Key('opalPresentClaim')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalGiftPresentExpired), findsOneWidget);
      expect(find.byKey(const Key('opalPresentEmpty')), findsOneWidget);
      expect(find.text(l10n.opalGiftPresentEmpty), findsOneWidget);
      expect(opalWalletRevision.value, 0);
    });

    testWidgets('a failed load offers a reload', (tester) async {
      final api = _GiftApi()..failInbox = true;
      await _pumpHarness(tester, api);
      final l10n = appLocalizationsFor(const Locale('ja'));
      await tester.tap(find.byKey(const Key('opalPresentBoxButton')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalGiftLoadFailed), findsOneWidget);
      api
        ..failInbox = false
        ..presents = [_present('0mgzabc12deadbeef')];
      await tester.tap(find.byKey(const Key('opalPresentReload')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opalPresentClaim')), findsOneWidget);
    });
  });

  test('every gift string is translated in all seven languages', () {
    final ja = appLocalizationsFor(const Locale('ja'));
    String all(AppLocalizations l) => [
      l.opalGiftPresentBox,
      l.opalGiftUnclaimedCount(3),
      l.opalGiftPresentEmpty,
      l.opalGiftPresentEmptyHint,
      l.opalGiftClaim,
      l.opalGiftClaimed,
      l.opalGiftClaimUntil(_deadline),
      l.opalGiftReceived(l.coinAmount(2)),
      l.opalGiftPresentExpired,
      l.opalGiftPresentEnded,
      l.opalGiftLoadFailed,
      l.opalGiftReload,
      l.opalGiftClaimFailed,
      l.opalGiftSignInRequired,
      l.opalCouponEnter,
      l.opalCouponIntro,
      l.opalCouponOfferTitle,
      l.opalCouponOfferBody,
      l.opalCouponField,
      l.opalCouponFieldHelper,
      l.opalCouponLater,
      l.opalCouponErrorFormat,
      l.opalCouponErrorNotFound,
      l.opalCouponErrorEnded,
      l.opalCouponErrorExpired,
      l.opalCouponErrorNotYet,
      l.opalCouponErrorLimit,
      l.opalCouponErrorUsed,
      l.opalCouponErrorNewOnly,
      l.opalCouponErrorNotEligible,
      l.opalCouponErrorRateLimited,
      l.rewardUnlockHistoryPresent,
      l.rewardUnlockHistoryCoupon,
    ].join('\n');
    final jaText = all(ja).split('\n');
    for (final locale in AppLocalizations.supportedLocales) {
      final l = appLocalizationsFor(locale);
      final texts = all(l).split('\n');
      expect(
        texts.every((t) => t.trim().isNotEmpty),
        isTrue,
        reason: '$locale',
      );
      expect(texts.any((t) => t.contains('{')), isFalse, reason: '$locale');
      expect(l.opalGiftUnclaimedCount(3), contains('3'));
      expect(l.opalGiftReceived('X'), contains('X'));
      if (locale.languageCode != 'ja') {
        for (var i = 0; i < texts.length; i++) {
          expect(texts[i], isNot(jaText[i]), reason: '$locale #$i');
        }
      }
      for (final text in texts) {
        expect(text, isNot(matches(RegExp('準備中|予定|近日'))));
      }
    }
  });

  testWidgets('captures the coupon entry and the present box (ja, fr)', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final themes = ThemeService();
    await tester.runAsync(themes.init);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    debugDisableShadows = false;
    for (final locale in const [Locale('ja'), Locale('fr')]) {
      final l10n = appLocalizationsFor(locale);
      final api = _GiftApi()
        ..presents = [
          _present(
            '0mgzabc12deadbeef',
            translations: {
              'fr': {
                'title': 'Excuses pour la maintenance',
                'body':
                    'Merci de votre patience pendant la maintenance du 1er décembre.',
              },
            },
          ),
          _present(
            '0mgzabc13deadbeef',
            coins: 1000,
            title: '新規登録ありがとうございます',
            body: 'NIARIMへようこそ。',
            translations: {
              'fr': {
                'title': 'Merci de votre inscription',
                'body': 'Bienvenue sur NIARIM.',
              },
            },
          ),
          _present('0mgzabc14deadbeef', claimed: true, coins: 50),
        ];
      await _pumpHarness(
        tester,
        api,
        locale: locale,
        theme: themes.themeDataFor(locale),
      );
      await tester.pumpAndSettle();
      await _openCoupon(tester);
      await tester.enterText(
        find.byKey(const Key('opalCouponField')),
        'ABCD-2345',
      );
      await tester.pump();
      api.redeemError = const NiarimApiException(
        403,
        'x',
        code: 'COUPON_NEW_ACCOUNTS_ONLY',
      );
      await tester.tap(find.byKey(const Key('opalCouponSubmit')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalCouponErrorNewOnly), findsOneWidget);
      await _capture(tester, 'coupon-entry-${locale.languageCode}');
      await tester.tap(find.byKey(const Key('opalCouponCancel')));
      await tester.pumpAndSettle();

      api.accountAgeSeconds = 5;
      await tester.tap(find.byKey(const Key('offerAfterSignIn')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.opalCouponOfferTitle), findsOneWidget);
      await _capture(tester, 'coupon-offer-${locale.languageCode}');
      await tester.tap(find.byKey(const Key('opalCouponCancel')));
      await tester.pumpAndSettle();
      api.accountAgeSeconds = 400 * 24 * 3600;
      SharedPreferences.setMockInitialValues({});

      await tester.tap(find.byKey(const Key('opalPresentBoxButton')));
      await tester.pumpAndSettle();
      await _capture(tester, 'present-box-${locale.languageCode}');
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      api.presents = [];
      await tester.tap(find.byKey(const Key('opalPresentBoxButton')));
      await tester.pumpAndSettle();
      await _capture(tester, 'present-box-empty-${locale.languageCode}');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    debugDisableShadows = true;
  });

  testWidgets('the wallet carries the coupon and present box entries', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final themes = ThemeService();
    await tester.runAsync(themes.init);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    for (final locale in const [Locale('ja'), Locale('fr')]) {
      final premium = PremiumService();
      final api = _GiftApi()..presents = [_present('0mgzabc12deadbeef')];
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<GoogleAuthService>.value(value: _Auth()),
              ChangeNotifierProvider<CommunityService>.value(
                value: CommunityService(api: api),
              ),
              ChangeNotifierProvider<PremiumService>.value(value: premium),
              ChangeNotifierProvider<SettingsService>.value(
                value: SettingsService(),
              ),
              ChangeNotifierProvider<AdvertisingService>.value(
                value: AdvertisingService(premiumService: premium),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: locale,
              theme: themes.themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RewardUnlockScreen(mode: RewardPageMode.earnCoins),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opalCouponButton')), findsOneWidget);
      expect(find.byKey(const Key('opalPresentBoxButton')), findsOneWidget);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('opalPresentBadge')))
            .isLabelVisible,
        isTrue,
      );
      await _capture(tester, 'wallet-${locale.languageCode}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
