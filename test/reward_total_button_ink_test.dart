// 特典交換の「合計」のカードの3つのボタン（重複・有効期限の確認／目標に
// する／交換する）で、ラベルの字の描かれた所（インク）がボタンの形の中に
// 収まり、ボタンどうしが重ならないことを、本物のフォント・テーマ・スマホの
// 幅で確かめる。
//
// Material 3のボタンは縦の余白が0で、ラベルが2行・3行になるとボタンの高さは
// 行の高さちょうどになる。くらむぼんはアクセント（É）や下に伸びる字（p・j）が
// 行の高さの外へはみ出すので、フランス語の文字2倍では「l'expiration」が枠の
// 下を越え、「Définir comme objectif」と「Échanger les pièces」の字が隣の
// ボタンに食い込んでいた（目標にするボタンと交換するボタンの間に隙間も
// 無かった）。字が単語の途中で切れないかを見る検査（reward_total_reference_
// note_test）では、字がボタンの外へ出ても気づけない。
//
// 同じことが交換の確認（全機能1か月）のボタンでも起きていた：フランス語の
// 文字2倍で「Échanger les pièces」が2行になり、Éのアクセントが塗りの
// ボタンの上の白い地に出て見えず（「Echanger」と読める）、pの下が枠の下に
// はみ出していた。取引履歴・更新のボタンのラベルも枠の下へ5px出ていた。
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/coin_benefit_price_proposal.dart';
import 'package:niarim/models/coin_unlock_quote.dart';
import 'package:niarim/screens/rewards/reward_unlock_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'reward-total-button-ink';
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

CommunityService _server() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.method != 'GET') return _json({'redeemed': false});
        return _json(switch (request.url.path) {
          '/me/rewards' => {
            'balanceCoins': 120,
            'redemptionEnabled': true,
            'entitlements': <Object>[],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

/// 残高60000コインで、全機能1か月を確定価格どおりの見積もりで交換できる
/// サーバー。
CommunityService _redeemableServer() => CommunityService(
  api: CommunityApi(
    NiarimApiClient(
      baseUrl: 'https://example.invalid',
      maxGetRetries: 0,
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async {
        if (request.method != 'GET') return _json({'redeemed': false});
        return _json(switch (request.url.path) {
          '/me/rewards' => {
            'balanceCoins': 60000,
            'redemptionEnabled': true,
            'entitlements': <Object>[],
          },
          '/me/rewards/quote' => {
            'enabled': true,
            'priceCoins': CoinBenefitPriceCatalog.unitCoins(
              CoinUnlockTarget.fullPremium,
              CoinDurationUnit.month,
            ),
            'priceVersion': CoinBenefitPriceCatalog.version,
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

/// [paragraph]の字が実際に描かれる所（段落の左上を原点とする座標）。
/// 字の形はフォントの行の高さの外へはみ出すことがあるので、段落の大きさ
/// ではなく、描いた画素から求める。
Future<Rect?> _inkOf(WidgetTester tester, RenderParagraph paragraph) async {
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  );
  final constraints = paragraph.constraints;
  final widthMatters =
      paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis;
  painter.layout(
    minWidth: constraints.minWidth,
    maxWidth: widthMatters ? constraints.maxWidth : double.infinity,
  );
  // はみ出した字も拾えるよう、周りに余白を取って描く。
  const margin = 64.0;
  final width = (paragraph.size.width + margin * 2).ceil();
  final height = (paragraph.size.height + margin * 2).ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Offset(margin, margin));
  final picture = recorder.endRecording();
  painter.dispose();
  final bytes = await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  });
  return _alphaBounds(
    bytes!,
    width,
    height,
  )?.shift(const Offset(-margin, -margin));
}

Rect? _alphaBounds(Uint8List rgba, int width, int height) {
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  if (right < 0) return null;
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}

/// [button]のラベルの字（インク）のうち、ボタンの形（Material）の外へ出る
/// もの。
Future<List<String>> _inkOutside(
  WidgetTester tester,
  Finder button,
  String tag,
) async {
  final problems = <String>[];
  final shape = tester.getRect(
    find.descendant(of: button, matching: find.byType(Material)).first,
  );
  for (final element
      in find
          .descendant(of: button, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final ink = await _inkOf(tester, paragraph);
    if (ink == null) continue;
    final global = ink.shift(paragraph.localToGlobal(Offset.zero));
    final label = paragraph.text.toPlainText(includeSemanticsLabels: false);
    debugPrint(
      'INK($tag) "$label": '
      'shape ${shape.top.toStringAsFixed(1)}..'
      '${shape.bottom.toStringAsFixed(1)} '
      'ink ${global.top.toStringAsFixed(1)}..'
      '${global.bottom.toStringAsFixed(1)}',
    );
    if (global.top < shape.top ||
        global.bottom > shape.bottom ||
        global.left < shape.left ||
        global.right > shape.right) {
      problems.add(
        '「$label」の字がボタンの外へ出る'
        '（上${(shape.top - global.top).toStringAsFixed(1)}px・'
        '下${(global.bottom - shape.bottom).toStringAsFixed(1)}px）',
      );
    }
  }
  return problems;
}

void main() {
  // 同梱フォントはファイルで1回だけ読む（テストごとに読むと、テストの数だけ
  // フォントが積み上がってメモリが足りなくなり、テストの途中で落ちた）。
  var fontsLoaded = false;
  setUp(() => SharedPreferences.setMockInitialValues({'language': 'ja'}));

  const locales = <String, Locale>{
    'fr': Locale('fr'),
    'es': Locale('es'),
    'en': Locale('en'),
    'ja': Locale('ja'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };
  const buttons = [
    Key('rewardOverlapPreviewButton'),
    Key('rewardSetGoalButton'),
    Key('rewardRedeemButton'),
  ];

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    for (final (width, scale) in [
      (360.0, 1.0),
      (360.0, 1.75),
      (360.0, 2.0),
      (640.0, 2.0),
    ]) {
      testWidgets('合計のボタンの字がボタンの中に収まり、ボタンどうしが重ならない'
          '（$name, 文字$scale倍, ${width.toInt()}dp）', (tester) async {
        if (!fontsLoaded) {
          await loadAppFonts(tester);
          fontsLoaded = true;
        }
        final themes = ThemeService();
        await themes.init();
        addTearDown(themes.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 30000);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final premium = PremiumService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PremiumService>.value(value: premium),
              ChangeNotifierProvider<SettingsService>.value(
                value: SettingsService(),
              ),
              ChangeNotifierProvider<GoogleAuthService>.value(
                value: _SignedIn(),
              ),
              ChangeNotifierProvider<CommunityService>.value(value: _server()),
            ],
            child: MaterialApp(
              locale: locale,
              theme: themes.themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RewardUnlockScreen(),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }

        // 交換の準備ができていない特典を選ぶと、合計は確定価格で、確認のボタンが
        // 押せるようになる。
        for (final target in ['allAds', 'canvasAds']) {
          await tester.tap(find.byKey(ValueKey('rewardFeature_$target')));
        }
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);
        expect(
          find.text(l10n.rewardUnlockFixedPrice),
          findsOneWidget,
          reason: '$name: 確定価格の合計',
        );

        final problems = <String>[];
        Rect? previous;
        for (final key in buttons) {
          final button = find.byKey(key);
          expect(button, findsOneWidget, reason: '$name: $key');
          final shape = tester.getRect(
            find.descendant(of: button, matching: find.byType(Material)).first,
          );
          // 縦に並ぶボタンは重ならず、くっつきもしない（隙間がある）。
          if (previous != null && shape.top <= previous.bottom) {
            problems.add(
              '$key と上のボタンの間に隙間が無い'
              '（${(shape.top - previous.bottom).toStringAsFixed(1)}px）',
            );
          }
          previous = shape;
          for (final problem in await _inkOutside(
            tester,
            button,
            '$name ×$scale ${width.toInt()} $key',
          )) {
            problems.add('$key$problem');
          }
        }
        expect(problems, isEmpty, reason: '$name ×$scale: $problems');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });

      testWidgets('交換の確認・取引履歴・更新など画面のどのボタンも字がボタンの中に'
          '収まる（$name, 文字$scale倍, ${width.toInt()}dp）', (tester) async {
        if (!fontsLoaded) {
          await loadAppFonts(tester);
          fontsLoaded = true;
        }
        final themes = ThemeService();
        await themes.init();
        addTearDown(themes.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 30000);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final premium = PremiumService();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PremiumService>.value(value: premium),
              ChangeNotifierProvider<SettingsService>.value(
                value: SettingsService(),
              ),
              ChangeNotifierProvider<GoogleAuthService>.value(
                value: _SignedIn(),
              ),
              ChangeNotifierProvider<CommunityService>.value(
                value: _redeemableServer(),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              theme: themes.themeData,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RewardUnlockScreen(),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 200));
        }
        final tag = '$name ×$scale ${width.toInt()}';
        final problems = <String>[];
        Future<void> checkAll(String where, Finder within) async {
          final buttons = find.descendant(
            of: within,
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          );
          for (final element in buttons.evaluate().toList()) {
            final button = find.byElementPredicate((e) => e == element);
            for (final problem in await _inkOutside(tester, button, tag)) {
              problems.add('$where: $problem');
            }
          }
        }

        // 交換の画面：取引履歴・更新・期間・会員のボタン。
        expect(find.byKey(const Key('coinHistoryButton')), findsOneWidget);
        await checkAll('交換の画面', find.byType(Scaffold));

        // 全機能1か月を選んで交換の確認を開く。
        await tester.tap(
          find.byKey(const ValueKey('rewardFeature_fullPremium')),
        );
        await tester.pumpAndSettle();
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
        final oneMonth = find.byKey(const ValueKey('rewardDuration_month_1'));
        await tester.ensureVisible(oneMonth);
        await tester.pumpAndSettle();
        await tester.tap(oneMonth);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rewardRedeemButton')));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget, reason: '$tag: 交換の確認');
        expect(
          find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
          findsNWidgets(2),
        );
        await checkAll('交換の確認', dialog);
        await tester.tap(
          find.descendant(of: dialog, matching: find.byType(TextButton)),
        );
        await tester.pumpAndSettle();

        expect(problems, isEmpty, reason: '$tag:\n${problems.join('\n')}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        premium.dispose();
      });
    }
  }
}
