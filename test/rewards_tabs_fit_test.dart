// 「オパール・特典」の画面（ミッション・広告を見てオパールGET・特典交換の
// タブ）が、狭い画面・大きな文字でも切れない（DISC147）。
//
// - タブ：名前の幅のまま横に並べてスクロールする`TabBar`だったので、名前が
//   画面に入らないと端のタブが画面の外へ切れていた（仏語360px・文字2倍の
//   「Voir des pubs pour des opales」等。日本語も360px・文字1倍で端が切れる）。
//   所有者の判断3：名前が全部入る幅では名前、1つでも入らない幅ではどのタブも
//   アイコン（名前は長押し・ホバーの吹き出しと読み上げ）。文字は縮めない・
//   省略記号で切らない。
// - ミッションのタブのログインの案内（「Connectez-vous avec Google…」）は
//   余白の無い`Center`の`Text`で、画面の左端（x=0）から始まっていた。
// - ページの中の文はどれも画面の端から8px以上の余白を取る。どの文も行に
//   入る語を途中で折らない（DISC243：韓国語のミッション・特典の文などが
//   「혜택 컴플리트 / 팩」のように語の途中で折れていた。以前はログイン・接続の
//   案内だけを見ていた）。行より広い1語も失敗として数える
//   （所有者の判断、2026-11-22：行より広い1語は短い訳に替える）。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/coin_benefits_screen.dart';
import 'package:niarim/services/advertising_service.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get id => 'rewards-tabs-fit';
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

/// ログインしていない（ミッションのタブはログインの案内を出す）。
class _SignedOut extends GoogleAuthService {
  @override
  GoogleSignInAccount? get account => null;
  @override
  bool get isConfigured => true;
}

http.Response _json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 残高のあるサーバー（広告で稼ぐ・交換ができる）。
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
            'balanceCoins': 60000,
            'redemptionEnabled': true,
            'rewardEarningEnabled': true,
            'rewardedDailyLimit': 5,
            'rewardedDailyRemaining': 3,
            'entitlements': <Object>[],
          },
          _ => <String, Object>{},
        });
      }),
    ),
  ),
);

String _plain(String text) => text
    .replaceAll('⁠', '')
    .replaceAll('​', '')
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET3_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<GlobalKey> pump(
    WidgetTester tester,
    Locale locale, {
    required bool signedIn,
  }) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    SharedPreferences.setMockInitialValues({});
    final root = GlobalKey();
    final premium = PremiumService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<AdvertisingService>(
            create: (_) => AdvertisingService(premiumService: premium),
          ),
          ChangeNotifierProvider<SettingsService>.value(
            value: SettingsService(),
          ),
          ChangeNotifierProvider<GoogleAuthService>.value(
            value: signedIn ? _SignedIn() : _SignedOut(),
          ),
          ChangeNotifierProvider<CommunityService>.value(value: _server()),
          ChangeNotifierProvider<ProjectService>.value(value: ProjectService()),
        ],
        child: RepaintBoundary(
          key: root,
          child: MaterialApp(
            locale: locale,
            theme: ThemeService().themeDataFor(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CoinBenefitsScreen(initialTab: 0),
          ),
        ),
      ),
    );
    await settle(tester);
    return root;
  }

  Future<void> shoot(WidgetTester tester, GlobalKey root, String name) async {
    if (shots == null) return;
    await tester.runAsync(() async {
      final boundary =
          root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$shots/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
      image.dispose();
    });
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);
    final names = [
      l10n.rewardNavigationMissions,
      l10n.rewardNavigationEarnTab,
      l10n.rewardNavigationExchange,
    ];

    testWidgets('reward tabs, login notice and buttons fit ($tag)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final problems = <String>{};
      final tooWide = <String>{};
      final notices = {
        l10n.creatorMissionLogin,
        l10n.creatorMissionOffline,
        l10n.creatorMissionLoadError,
      };
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());

      /// 開いているページ[view]（画面の[viewRect]）の、見えている文。
      void checkPage(String at, Finder view, Rect viewRect) {
        for (final p in textParagraphsIn(view)) {
          final shown = _plain(
            p.text.toPlainText(includeSemanticsLabels: false),
          );
          final rect = MatrixUtils.transformRect(
            p.getTransformTo(null),
            Offset.zero & p.size,
          );
          // 隣のページ・一覧の見えていない所の文は見ない。
          if (rect.right <= viewRect.left ||
              rect.left >= viewRect.right ||
              rect.bottom <= viewRect.top ||
              rect.top >= viewRect.bottom) {
            continue;
          }
          // 画面の端から余白を取る。
          if (rect.left < viewRect.left + 8 ||
              rect.right > viewRect.right - 8) {
            problems.add(
              '$at「$shown」touches the screen edge '
              '(${rect.left.toStringAsFixed(0)}–'
              '${rect.right.toStringAsFixed(0)})',
            );
          }
          // どの文も、行に入る語（韓国語の語・数と単位など）を途中で折らない
          // （DISC243。以前はログイン・接続の案内だけを見て、ほかの文の折れ
          // は名前を出すだけだった）。
          final broken = brokenWordUnits(p);
          final notice = notices.contains(shown);
          for (final word in broken.fits) {
            problems.add('$at「$shown」${notice ? ' (notice)' : ''}: $word');
          }
          tooWide.addAll(broken.tooWide.map((w) => '$at $w'));
          for (final c in ParagraphLines(p).charsOutsideWidth()) {
            problems.add('$at「$shown」runs past its line: $c');
          }
        }
      }

      try {
        for (final signedIn in [false, true]) {
          tester.view.physicalSize = const Size(412, 760);
          tester.view.devicePixelRatio = 1;
          final root = await pump(tester, locale, signedIn: signedIn);
          for (final width in [320.0, 360.0, 412.0]) {
            for (final scale in [1.0, 1.3, 2.0]) {
              tester.view.physicalSize = Size(width, 760);
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              await settle(tester);
              final at =
                  '${signedIn ? 'in' : 'out'} ${width.toInt()}px x$scale';
              final bar = find.byType(TabBar);
              final barRect = tester.getRect(bar);
              final tabs = find.descendant(of: bar, matching: find.byType(Tab));
              if (tabs.evaluate().length != 3) {
                problems.add('$at: ${tabs.evaluate().length} tabs');
              }
              for (var i = 0; i < tabs.evaluate().length; i++) {
                final tab = tabs.at(i);
                final rect = tester.getRect(tab);
                if (rect.left < barRect.left - 0.5 ||
                    rect.right > barRect.right + 0.5) {
                  problems.add(
                    '$at tab「${names[i]}」$rect is cut by the bar $barRect',
                  );
                }
                // 名前を出すタブは名前を全部、アイコンのタブは名前を吹き出しと
                // 読み上げで伝える。
                final texts = textParagraphsIn(tab).toList();
                if (texts.isEmpty) {
                  final tooltip = find.descendant(
                    of: tab,
                    matching: find.byType(Tooltip),
                  );
                  if (tooltip.evaluate().isEmpty ||
                      tester.widget<Tooltip>(tooltip.first).message !=
                          names[i]) {
                    problems.add('$at icon tab「${names[i]}」has no tooltip');
                  }
                  if (find
                      .bySemanticsLabel(RegExp(RegExp.escape(names[i])))
                      .evaluate()
                      .isEmpty) {
                    problems.add('$at icon tab「${names[i]}」is not announced');
                  }
                }
                for (final p in texts) {
                  final shown = _plain(
                    p.text.toPlainText(includeSemanticsLabels: false),
                  );
                  if (shown != names[i] || p.didExceedMaxLines) {
                    problems.add('$at tab「${names[i]}」shows「$shown」');
                  }
                  for (final c in ParagraphLines(p).charsOutsideWidth()) {
                    problems.add('$at tab「${names[i]}」is cut: $c');
                  }
                }
              }
              // 3つのページを順に開き、上から下まで動かしながら見る。
              final controller = DefaultTabController.of(
                tester.element(find.byType(TabBar)),
              );
              for (var page = 0; page < 3; page++) {
                controller.index = page;
                await settle(tester);
                final view = find.byType(TabBarView);
                final viewRect = tester.getRect(view);
                final scrollables = find.descendant(
                  of: view,
                  matching: find.byType(Scrollable),
                );
                // 開いているページの縦の一覧（無ければ動かさない）。
                ScrollPosition? position;
                for (final e in scrollables.evaluate()) {
                  final state = (e as StatefulElement).state as ScrollableState;
                  if (state.position.axis != Axis.vertical) continue;
                  final r = tester.getRect(
                    find.byElementPredicate((x) => x == e),
                  );
                  if (r.left < viewRect.left - 0.5 ||
                      r.right > viewRect.right + 0.5) {
                    continue;
                  }
                  position = state.position;
                  break;
                }
                position?.jumpTo(0);
                await tester.pump();
                while (true) {
                  checkPage('$at page$page', view, viewRect);
                  if (position == null ||
                      position.pixels >= position.maxScrollExtent) {
                    break;
                  }
                  position.jumpTo(
                    (position.pixels + position.viewportDimension * 0.6).clamp(
                      0,
                      position.maxScrollExtent,
                    ),
                  );
                  await tester.pump();
                }
                position?.jumpTo(0);
                await tester.pump();
                if (scale == 2.0 || (scale == 1.0 && width == 360)) {
                  await shoot(
                    tester,
                    root,
                    'DISC147-${signedIn ? 'in' : 'out'}-p$page-$tag-'
                    '${width.toInt()}_x${scale.toString().replaceAll('.', '')}',
                  );
                }
              }
              controller.index = 0;
              await settle(tester);
              for (final error in errors) {
                problems.add('$at ${error.split('\n').first}');
              }
              errors.clear();
            }
          }
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      } finally {
        FlutterError.onError = onError;
        semantics.dispose();
      }
      for (final word in tooWide) {
        problems.add('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
}
