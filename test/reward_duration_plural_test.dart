import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/reward_duration_oracle.dart';

class _Account implements GoogleSignInAccount {
  _Account(this.id);
  @override
  final String id;
  @override
  String get email => '$id@example.invalid';
  @override
  String get displayName => 'Audit $id';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth extends GoogleAuthService {
  _Auth(String id) : _current = _Account(id);
  final GoogleSignInAccount _current;
  @override
  GoogleSignInAccount? get account => _current;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => true;
}

http.Response _reply(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 残高60000コイン・全機能1か月が55000コインで交換できるサーバー。
/// 交換そのもの（POST）が呼ばれたら[redeemCalls]に数える。
CommunityService _redeemableServer(List<String> redeemCalls) =>
    CommunityService(
      api: CommunityApi(
        NiarimApiClient(
          baseUrl: 'https://example.invalid',
          maxGetRetries: 0,
          tokenProvider: () async => 'fixture-token',
          httpClient: MockClient((request) async {
            if (request.method != 'GET') {
              redeemCalls.add('${request.method} ${request.url.path}');
              return _reply({'redeemed': false});
            }
            return switch (request.url.path) {
              '/me/rewards' => _reply({
                'balanceCoins': 60000,
                'redemptionEnabled': true,
                'entitlements': <Object>[],
              }),
              '/me/rewards/quote' => _reply({
                'enabled': true,
                'priceCoins': 55000,
                'priceVersion': 'v3-final-annual550000',
              }),
              _ => _reply(<String, Object>{}),
            };
          }),
        ),
      ),
    );

const _toneCurvePrices = CoinUnlockUnitPrices(
  perHour: 110,
  perDay: 470,
  perWeek: 3520,
  perMonth: 13000,
);

/// [_toneCurvePrices]で[duration]を選んだときの必要コイン（モデルを通さず、
/// 単価×数で求めた値）。
int _expectedToneCurveCoins(CoinUnlockDuration duration) =>
    duration.amount *
    switch (duration.unit) {
      CoinDurationUnit.hour => 110,
      CoinDurationUnit.day => 470,
      CoinDurationUnit.week => 3520,
      CoinDurationUnit.month => 13000,
    };

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Locale locale,
  GoogleAuthService? auth,
  CommunityService? community,
  Map<CoinUnlockTarget, CoinUnlockUnitPrices> priceCatalog = const {},
}) async {
  final premium = PremiumService();
  final settings = SettingsService();
  final authService = auth ?? GoogleAuthService();
  final communityService = community ?? CommunityService();
  await communityService.contentFiltersReady;
  // スマホの縦画面。一覧もシートも一画面に収まらないので、本物と同じく
  // スクロールして操作する。
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(premium.dispose);
  addTearDown(settings.dispose);
  addTearDown(authService.dispose);
  addTearDown(communityService.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PremiumService>.value(value: premium),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<GoogleAuthService>.value(value: authService),
        ChangeNotifierProvider<CommunityService>.value(value: communityService),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RewardUnlockScreen(priceCatalog: priceCatalog),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _durationButton = find.byKey(const Key('rewardDurationButton'));

Finder _option(CoinUnlockDuration duration) => find.byKey(
  ValueKey('rewardDuration_${duration.unit.name}_${duration.amount}'),
);

String _textIn(WidgetTester tester, Finder owner) => tester
    .widget<Text>(find.descendant(of: owner, matching: find.byType(Text)))
    .data!;

String _buttonLabel(WidgetTester tester) => _textIn(tester, _durationButton);

/// 画面の一覧を先頭へ戻してから、[target]が出るまで下へ送る（一覧は画面の
/// 外の行を作らないので、作られていない行は`ensureVisible`では探せない）。
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final list = find.byType(Scrollable).first;
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(target, 120, scrollable: list);
  await tester.pumpAndSettle();
}

/// 期間のシートを開く（どの区分も畳まれた状態で開く）。
Future<void> _openSheet(WidgetTester tester) async {
  await _reveal(tester, _durationButton);
  await tester.tap(_durationButton);
  await tester.pumpAndSettle();
  expect(find.byType(ExpansionTile), findsNWidgets(4));
}

/// 開いたばかりのシートで[unit]の区分を開く。見出しの文言には頼らない
/// （区分は時間・日・週・月の順に並ぶ）。区分を開くと後ろの区分が画面の外へ
/// 出て作られなくなるので、別の区分を見るときはシートを開き直す。
Future<void> _expandGroup(WidgetTester tester, CoinDurationUnit unit) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(ExpansionTile).at(unit.index),
          matching: find.byType(ListTile),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// シートの外（上の幕）を押して、何も選ばずに閉じる。
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(195, 20));
  await tester.pumpAndSettle();
  expect(find.byType(ExpansionTile), findsNothing);
}

/// シートで[duration]を選ぶ（開く→区分を開く→行を押す→シートが閉じる）。
Future<void> _pick(WidgetTester tester, CoinUnlockDuration duration) async {
  await _openSheet(tester);
  await _expandGroup(tester, duration.unit);
  final option = _option(duration);
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
  expect(find.byType(ExpansionTile), findsNothing);
}

/// 画面を外す（サービスを破棄する前に、画面の聞き手を外しておく）。
Future<void> _unmount(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}

/// 特典交換の画面（本物の[RewardUnlockScreen]）に出る交換期間の文言。
///
/// 数と単位をコードでつないでいた頃は、英語が「1hours」、スペイン語が
/// 「1horas」、フランス語が「1heures」になり、交換の確認には「1 months」と
/// 出ていた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('英語で開いた直後の交換期間は「1 hour」', (tester) async {
    await _pumpScreen(tester, locale: const Locale('en'));

    expect(_buttonLabel(tester), '1 hour');
    expect(find.text('1hours'), findsNothing);
    await _unmount(tester);
  });

  for (final language in rewardDurationLanguages) {
    testWidgets('期間のシートの153件すべてが正しい文言で出る（${language.code}）', (tester) async {
      await _pumpScreen(tester, locale: language.locale);

      final shown = <String>[];
      for (final unit in CoinDurationUnit.values) {
        await _openSheet(tester);
        await _expandGroup(tester, unit);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ListTile &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'rewardDuration_',
                ),
          ),
          findsNWidgets(
            offeredRewardDurations.where((d) => d.unit == unit).length,
          ),
          reason: '${language.code} ${unit.name}の区分の件数',
        );
        for (final duration in offeredRewardDurations) {
          if (duration.unit != unit) continue;
          final label = _textIn(tester, _option(duration));
          shown.add(label);
          expect(
            label,
            language.label(duration),
            reason: '${language.code} ${duration.unit.name} ${duration.amount}',
          );
          expect(
            rewardDurationLabelProblem(language, duration, label),
            isNull,
            reason: '${language.code} "$label"',
          );
        }
        await _closeSheet(tester);
      }
      expect(shown, hasLength(153));
      expect(shown.toSet(), hasLength(153), reason: '同じ文言の行がある');
      await _unmount(tester);
    });

    testWidgets('選んだ期間がボタンに正しい文言で出る（${language.code}）', (tester) async {
      await _pumpScreen(
        tester,
        locale: language.locale,
        priceCatalog: const {CoinUnlockTarget.toneCurve: _toneCurvePrices},
      );

      expect(_buttonLabel(tester), language.pinned['hour_1']);
      for (final MapEntry(key: name, value: expected)
          in language.pinned.entries) {
        final [unitName, amount] = name.split('_');
        final duration = CoinUnlockDuration(
          int.parse(amount),
          CoinDurationUnit.values.byName(unitName),
        );
        await _pick(tester, duration);
        expect(
          _buttonLabel(tester),
          expected,
          reason: '${language.code} $name',
        );
        // 選んだ行にチェックが付く（開き直して確かめる）。
        await _openSheet(tester);
        await _expandGroup(tester, duration.unit);
        expect(
          find.descendant(
            of: _option(duration),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
          reason: '${language.code} $name',
        );
        expect(find.byIcon(Icons.check), findsOneWidget);
        await _closeSheet(tester);

        // 文言を変えても、その期間の必要コインは単価×数のまま（日本語・
        // 韓国語は数と「コイン」「코인」の間に空白を入れない）。
        final toneCurve = find.byKey(const ValueKey('rewardFeature_toneCurve'));
        await _reveal(tester, toneCurve);
        expect(
          find.descendant(
            of: toneCurve,
            matching: find.textContaining(
              RegExp('^${_expectedToneCurveCoins(duration)}(?![0-9])'),
            ),
          ),
          findsOneWidget,
          reason: '${language.code} $name',
        );
      }
      await _unmount(tester);
    });

    testWidgets('交換の確認に「1か月」が正しい文言で出る（${language.code}）', (tester) async {
      final redeemCalls = <String>[];
      await _pumpScreen(
        tester,
        locale: language.locale,
        auth: _Auth('redeemer'),
        community: _redeemableServer(redeemCalls),
      );

      final fullPremium = find.byKey(
        const ValueKey('rewardFeature_fullPremium'),
      );
      await _reveal(tester, fullPremium);
      await tester.tap(fullPremium);
      await tester.pumpAndSettle();
      await _pick(tester, const CoinUnlockDuration(1, CoinDurationUnit.month));

      final redeem = find.byKey(const Key('rewardRedeemButton'));
      await _reveal(tester, redeem);
      expect(
        tester.widget<OutlinedButton>(redeem).onPressed,
        isNotNull,
        reason: '残高と価格をサーバーから受け取れば交換できる',
      );
      await tester.tap(redeem);
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
        (dialog.content! as Text).data,
        startsWith(language.redeemConfirmation),
      );

      // 確認だけして交換はしない。
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(redeemCalls, isEmpty);
      await _unmount(tester);
    });
  }

  testWidgets('153件のどれを選んでも、文言と必要コインがモデルの値のまま', (tester) async {
    await _pumpScreen(
      tester,
      locale: const Locale('en'),
      priceCatalog: const {CoinUnlockTarget.toneCurve: _toneCurvePrices},
    );
    final english = rewardDurationLanguages.singleWhere((l) => l.code == 'en');
    final toneCurve = find.byKey(const ValueKey('rewardFeature_toneCurve'));
    await _reveal(tester, toneCurve);
    await tester.tap(toneCurve);
    await tester.pumpAndSettle();
    final total = find.byKey(const Key('rewardTotalCoins'));

    var checked = 0;
    for (final duration in offeredRewardDurations) {
      await _pick(tester, duration);
      final coins = _expectedToneCurveCoins(duration);
      final where = '${duration.unit.name} ${duration.amount}';

      await _reveal(tester, _durationButton);
      expect(_buttonLabel(tester), english.label(duration), reason: where);
      expect(_toneCurvePrices.cost(duration), coins, reason: where);
      await _reveal(tester, toneCurve);
      expect(
        find.descendant(of: toneCurve, matching: find.text('$coins coins')),
        findsOneWidget,
        reason: where,
      );
      await _reveal(tester, total);
      expect(tester.widget<Text>(total).data, '$coins coins', reason: where);
      checked++;
    }
    expect(checked, 153);
    await _unmount(tester);
  });
}
